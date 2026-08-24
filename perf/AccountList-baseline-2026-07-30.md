# Step 1 baseline — account list (DB-side filter/sort/page)

**Date:** 2026-07-30 · **Item:** "Performance — DB-side filter/sort/page on large lists (replace
load-all-then-filter)", road-to-100 §9 in
[REMEDIATION-PLAN.md](../architecture-review/REMEDIATION-PLAN.md).

Measured before any code change, per the "measure first" step. Harness:
`TflCbs.Tools.PerfProbe` (read-only; not in `TflCbsNet10Sol.slnx`).

```
dotnet run --project TflCbs.Tools.PerfProbe -- [iterations] [nameTerm] [reverse]
```

Raw runs: [`AccountList-baseline-20260730-163745.md`](AccountList-baseline-20260730-163745.md)
(large→small) and [`AccountList-baseline-20260730-163918.md`](AccountList-baseline-20260730-163918.md)
(small→large, confirms the numbers are not an artefact of measurement order). Post-change runs:
[`…-postchange-sqlserver.md`](AccountList-baseline-20260730-postchange-sqlserver.md) and
[`…-postchange-oracle.md`](AccountList-baseline-20260730-postchange-oracle.md).

## Environment

Dev SQL Server `TSSADSRV\TSSIPL2019`, database `Trustbank_MDCC_TEST` — **already at production
scale, so no seeding was needed**:

| Table | Rows |
|---|---:|
| `B_ACCOUNT` | 1,790,315 (478,179 open) |
| `G_GLOBALCLIENT` | 1,325,437 |
| `G_ACCOUNTHEAD` | 1,695 |
| `B_CODE` | 872 |
| `G_TITLE` | 22 |

55 branches hold open accounts. Three bands measured — branch **14** (20,480 open, the largest),
**43** (7,516, median), **53** (1,392, small).

## Results — one 15-row page, 10 iterations, warmup 2, median ms

| Target | Round-trips | 14 (20,480) | 43 (7,516) | 53 (1,392) |
|---|---:|---:|---:|---:|
| 1 `SearchAccountsAsync` (current) | 24 / 14 / 7 | 501 | 196 | 65 |
| 2 …with a `CustomerName` filter | 24 / 14 / 7 | 469 | 200 | 61 |
| 3 Legacy `pr_b_GetAccountList` (full list, no paging) | 1 | **417** | **134** | **41** |
| 4 DB-paged prototype (`SqlQuery`, 4 joins + OFFSET/FETCH + COUNT) | 2 | 436 | 715 | 715 |
| 5 …with the filter | 2 | 481 | 724 | 712 |

Round-trip counts come from a counting logger; `CommandLogger` emits two entries per command
(`LogStarting` + `LogSuccess`), so the raw count is halved.

## Findings

**1. The load-all diagnosis is confirmed, and it scales with branch size.** Round-trips are
`4 + ceil(distinctClients / 500)` — 24 on the largest branch — and median latency tracks branch
size almost linearly (65 → 196 → 501 ms). One 15-row page materializes the branch's entire open-
account set plus every referenced client.

**2. The filter is free, which is the tell.** Targets 1 and 2 are within noise of each other even
though the filter cuts the result from 20,364 to 6,488 rows. Filtering after materialization costs
nothing *because the expensive work already happened*. A DB-side filter is what makes a filter pay.

**3. The legacy stored procedure beats the C# port at every branch size** — 417 vs 501 ms, 134 vs
196, 41 vs 65 — *while returning the full list* (20,364 rows against the port's 15). Per row
delivered the proc is over a thousand times cheaper. It wins on shape: one `EXEC`, one server-side
join, versus 7–24 client round-trips and an in-memory join. This is the single most actionable
number here, and it points at **round-trip consolidation** rather than paging per se.

**4. The naive DB-paged rewrite is a regression at typical branch sizes.** 1.15× faster on the
largest branch, but **3.6× slower on the median branch and 11× slower on the small one** (715 vs
196/65 ms) — and it is *size-independent*, which is the giveaway. Reversing the measurement order
reproduces it, so it is not plan-cache order or parameter sniffing.

Root cause, from `SET STATISTICS IO`:

| Query | `g_GlobalClient` logical reads | CPU |
|---|---:|---:|
| the `COUNT(*)` half | 2,589 | 93 ms |
| the `ORDER BY … OFFSET/FETCH 15` half | **166,404** | 390 ms |

166,404 reads is a full scan of the 1.32 M-row clustered index — to return 15 rows. The paged
query cannot restrict `g_GlobalClient` before joining, and the optimizer drives from it. Attempted
remedies that **did not** work: `OPTION (RECOMPILE)`, `OPTION (FAST 15)`, and paging the driving
table in a derived table first (all still 166,404). Forcing `OPTION (LOOP JOIN, MAXDOP 1)` is far
worse — 6.9 s and 4 M worktable reads.

Why the legacy proc escapes this: it builds its SQL with `EXEC(@query)` and **literal** predicate
values, so the optimizer gets exact statistics and picks a good join order. The parameterized
equivalent gets a generic estimate. (Its `@p_criteria` string is concatenated straight into dynamic
SQL — a SQL-injection sink, and good reason the C# port dropped the parameter rather than copying it.)

**5. Paging cannot be done on `B_ACCOUNT` alone.** The current code's four in-memory `continue`
guards are load-bearing: on branch 53, **30 of 1,392 open accounts (2.2%)** have a client whose
`TITLEID` has no `G_TITLE` row, and they are dropped *before* paging — which is exactly why `Total`
reads 1,362, not 1,392. Any rewrite must apply the client+title join before the page, so the
"DB-page the single driving table, keep joins in memory" option is off the table on correctness
grounds, not just aesthetics.

**6. Semantics survived the rewrite.** All six prototype cases returned `Total` identical to the
current path (20,364 / 6,488 / 7,392 / 3,252 / 1,362 / 562), including the filtered ones — so
`UPPER(expr) LIKE UPPER(@q)` reproduced C#'s `OrdinalIgnoreCase` on this database. Note SQL Server's
default collation is already case-insensitive, so this confirms the SQL Server leg only; Oracle and
PostgreSQL remain unverified.

**7. `SqlQuery`-in-a-service is already established.** `TflCbs.Core.Authentication.AuthenticationService`
uses `SqlQuery.From<T>` with `InnerJoin<T>`, `SelectCols`, `OrderBy`, `Page` and `ExistsAsync` in
production code today. Step 0's decision is less open than the plan implies.

## Follow-up: the no-DDL option (measured after the index was ruled out)

With the index off the table, the paged rewrite is dead — but the 166k-page scan is caused
specifically by `ORDER BY … OFFSET/FETCH`, not by the joins. Target 6 keeps **one server-side join**
for the branch list (what the proc does) and leaves today's in-memory filter/sort/page untouched.

| Target | Round-trips | 14 (20,480) | 43 (7,516) | 53 (1,392) |
|---|---:|---:|---:|---:|
| 1 current | 24 / 14 / 7 | 526 | 239 | 70 |
| 3 legacy proc (full list) | 1 | 357 | 146 | 49 |
| 4 DB-paged prototype | 2 | 431 | 691 | 693 |
| **6 one join + in-memory page** | **1** | **263** | **114** | **45** |
| 7 …with the filter | 1 | 259 | 112 | 45 |

**It wins everywhere: ~2× faster than the current path at every branch size (2.0× / 2.1× / 1.5×),
and faster than the legacy stored procedure too.** Round-trips drop from 24/14/7 to **1**. Totals
match the current path exactly in all cases (20,364 / 6,488 / 7,392 / 3,252 / 1,362 / 562), so the
INNER-JOIN semantics — including the 30 title-orphan drops — are preserved. A reverse-order run
reproduces it (44 / 140 / 270 ms), with one 1,038 ms outlier on the median branch that did not
recur; worth re-checking under load.

**What it does not fix:** the memory profile. This still materializes the branch's whole result set
per request, so the allocation/LOH concern in §8 of the review stands. It removes the round-trips
and the in-memory join, not the load-all. Genuine DB-side paging still needs the index.

## Shipped (2026-07-30)

`AccountService.LoadAccountsAsync` was converted to the target-6 shape. Post-change measurement of
the **real service method** (probe target 1 now exercises the new code):

| | Round-trips | 14 (20,480) | 43 (7,516) | 53 (1,392) |
|---|---:|---:|---:|---:|
| before | 24 / 14 / 7 | 526 | 239 | 70 |
| **after** | **1** | **330** | **125** | **48** |
| legacy proc, for reference | 1 | 366 | 153 | 46 |

1.6× / 1.9× / 1.5× faster, and at or ahead of the stored procedure. `Total` came back byte-identical
to the pre-change values in all six cases (20,364 / 6,488 / 7,392 / 3,252 / 1,362 / 562), confirming
the join semantics — including the 30 title-orphan drops — survived. 149 service + 90 arch + 23
integration tests pass.

The residual gap to target 6 (330 vs 265 ms on the largest branch) is the extra dictionary re-shaping
pass that preserves the output contract exactly. Worth revisiting only if callers are ever migrated
to a typed row.

## Cross-provider verification

`CBS_PROVIDER=Oracle` runs the whole probe against the Oracle leg (the T-SQL proc target is skipped).

**Oracle — verified equivalent.** Branch 14, same data (20,480 open accounts):

| Target | Round-trips | Oracle | SQL Server | Total (both) |
|---|---:|---:|---:|---|
| shipped `SearchAccountsAsync` | 1 | 6,400 ms | 330 ms | 20,364 |
| …filtered | 1 | 6,275 ms | 320 ms | 6,488 |
| DB-paged prototype | 2 | 7,890 ms | 431 ms | 20,364 |
| …filtered | 2 | 9,876 ms | 481 ms | 6,488 |

Totals match SQL Server exactly, so the shipped implementation is correct on Oracle. It is also the
fastest option there, and the DB-paged prototype shows the *same* regression pattern (worse, not
better) — so parking DB paging holds on Oracle too.

Oracle is ~20× slower in absolute terms across every target including the untouched ones, so this is
the remote test instance (network + missing indexes), not the change. Worth its own look; unrelated
to this item.

**PostgreSQL — not verified.** No PostgreSQL connection string exists in any config in the
repository, so there is nothing to run against. Two things are known from code inspection:

- The shipped implementation routes **every** identifier through `Col`, which quotes per dialect, so
  it carries no case-folding hazard of its own.
- `SqlQuery.From<TEntity>` emits the **table** name unquoted and verbatim by design. PostgreSQL folds
  unquoted identifiers to lower case while the scaffolded tables are upper case. This affects every
  `SqlQuery` caller — including `TflCbs.Core.Authentication.AuthenticationService` — and predates
  this change, but it means "provider-portable" is unproven on PostgreSQL generally, not just here.

### The Oracle `''`-is-NULL trap (found during this verification)

The first version of the change computed the customer name server-side as
`CASE WHEN COALESCE(c.TITLE,'') = '' THEN …`. Oracle treats `''` as NULL, so that test evaluates
`NULL = NULL` → false, the `ELSE` branch returns NULL, and every untitled client silently loses its
name. It was measurable: the filtered Total came back **2,848 instead of 6,488**.

The shipped version computes the name in C# from the joined name parts, which is immune to this. The
same bug was present in the probe's own prototypes and is now fixed there
(`c.TITLE IS NULL OR TRIM(c.TITLE) = ''`), which is why targets 4–7 above read 6,488.

Two independent reasons, then, not to build that expression in SQL: PostgreSQL case folding and
Oracle NULL semantics. Both would have shipped as silent wrong answers on a provider nobody was
testing.

## What this changes about the plan

- **Step 5 (indexes) must move ahead of Step 4 (conversion), not after it.** Converting first would
  ship a regression on 54 of 55 branches. The plan's own premise — that DB paging is faster — does
  not hold on this schema without index/plan work.
- **The target index** is on `B_ACCOUNT(ORGELEMENTID, ACCOUNTSTATUSCODE, ACCOUNTNUMBERFORDISPLAY)`
  covering `CLIENTID, ACCOUNTHEADID, BALANCE, OLDACCOUNTNUMBER, ACCOUNTID`, so the filter and the
  sort become one ordered range scan with a real row goal and the lookups become 15 key seeks.
  `B_ACCOUNT` is clustered on `OrgElementId` alone today, so the sort is unsupported. **Not created
  — DDL on the shared dev DB needs sign-off**, and it belongs with the versioned-migration item.
- **A cheaper win exists and is worth pricing first:** the gap between target 1 and target 3 is
  round-trips, not paging. Batching the 20 chunked client lookups (or driving them from one join)
  would close most of the 501 → 417 ms gap without touching the paging model or needing any DDL.
- **`+1.5` is not collectable from paging alone**, and on this evidence paging is the *hardest*
  third of the Performance 5→8 bundle. Reference-data caching (`G_TITLE` 22 rows, `B_CODE` 872,
  `G_ACCOUNTHEAD` 1,695 — all re-read on every single page view) is far cheaper and removes 3 of
  the 7–24 round-trips outright.

## Incidental

`Col.Render` is `internal`, so service code cannot build a dialect-quoted expression string for a
computed column — the prototype's `CustomerName` expression falls back to unquoted `c.NAME1`. Fine
for the unquoted-uppercase convention, but a real implementation wants a public render helper.
`ExpressionTranslator` also has no `ToUpper`/`ToLower` translation, so case-insensitive contains is
only expressible through `SqlQuery`, never a `Repository<T>` predicate.

---
_Generated from `TflCbs.Tools.PerfProbe` plus `SET STATISTICS IO, TIME` sessions. Read-only
throughout; nothing was written to the database and no index was created._
