# Stored-procedure migration strategy (CBS → provider-agnostic C# on TflOmniDb)

> **Status:** decision record, now **built and verified** — the foundation (§10: all four
> increments) is complete and green on all three engines. §5's API sketches show the
> original design shapes; the as-built surface has since grown (typed `Col`/`Agg` tokens,
> `From<TEntity>` / typed joins, `Distinct`, scalar aggregates, `UseCommandTimeout`) — see
> `CLAUDE.md` for the current reference. The migration playbook (§6–§8) remains the
> operating guide for the proc-by-proc work.

## 1. Goal & context

The production core-banking system (CBS) is **ASP.NET WebForms + VB.NET + SQL Server**,
with **~98% of database logic living in T-SQL stored procedures**. The objective:

- Move that stored-procedure logic into application code so it **runs unchanged on SQL
  Server, Oracle, and PostgreSQL** (TflOmniDb's three targets).
- Do it on **.NET 10 + C#** (decision below), reusing TflOmniDb as the data-access spine.
- The WebForms → modern-UI rewrite and the net48 → net10 platform move are **separate
  workstreams**; the migrated logic is written to be UI-agnostic and framework-agnostic so
  it survives both.

### Decision: .NET 10 + C#

- **C# over VB.NET.** VB is in maintenance mode (frozen language), ASP.NET Core tooling is
  C#-first, WebForms (VB's first-class home) does not exist on modern .NET, and the
  procedural SP logic maps cleanly onto modern C# (pattern matching, `switch` expressions,
  enums, records). The move is incremental — new/migrated code in C#, untouched VB stays via
  interop; no big-bang.
- **net10** is in scope now, not "later." This is a decade-plus system, so longevity and
  minimal long-lived dependencies are weighted heavily.

## 2. Evidence: the CBS proc-library census

Measured across the real library (`20260601_cbs_procs`, comment-stripped keyword
classification):

- **5,316 stored procedures, ~1.8 million lines of T-SQL.**

| Primary split (mutually exclusive) | Count | Share |
|---|---|---|
| **Orchestration** (calls another proc / cursor / explicit `BEGIN TRAN`) | 2,899 | **55%** |
| **Write / CRUD** (writes, no proc-call / cursor / tran) | 1,062 | 20% |
| **Pure read** (SELECT only) | 1,355 | **25%** |

| Orchestration signal (overlapping) | Count | of all |
|---|---|---|
| Calls other procs (`EXEC`) | 2,350 | 44% (316 call 6+) |
| Uses temp tables / table vars | 3,341 | 63% |
| `WHILE` loop | 2,002 | 38% |
| Cursor | 1,272 | 24% |
| `BEGIN/COMMIT/ROLLBACK` | 1,047 | 20% |
| Dynamic SQL (`EXEC()` / `sp_executesql`) | 946 | 18% |

**Read complexity (within the 1,355 pure reads):** simple single-table 403; has JOIN 901
(≥3 joins 585); GROUP BY 135; UNION 96; **window fn 28; CTE 14; PIVOT 2.**

**Portability hazards (across all procs):** `WITH(NOLOCK)` 3,223 (61%); `ISNULL()` 4,541
(85%); date/format funcs `GETDATE/DATEADD/DATEDIFF/CONVERT/CHARINDEX` 3,630 (68%);
`HOLDLOCK/UPDLOCK/XLOCK` **only 3** (outliers, not systemic).

**Scalar/table UDF (`fn_*`) dependency:** **85 procs (2%)** reference UDFs, **17 distinct**
functions (top: `fn_MaskAadharOrPan` ×34, `fn_util_ReplaceSpecialChar` ×18, `fn_cdcf` ×9,
crypto `fn_encryptString`/`fn_decryptString`, `fn_eomonth`). A small, bounded cluster.

### What the census proves

1. **This is an orchestration codebase, not a query codebase.** ~3:1 against a query
   builder being the centerpiece. The bulk of the work is re-expressing procedural T-SQL as
   C# service methods on TflOmniDb (loops, transactions, proc-call graph, temp tables).
2. **The reads are join-heavy but not exotic.** The high-ceiling shapes (window/CTE/pivot)
   are **~44 procs total (~3% of reads)** — they stay raw SQL. A thin composer + raw SQL
   covers the read surface; **linq2db's high ceiling is not justified.**
3. **The systemic portability tax is the scalar-function / null vocabulary** (85% ISNULL,
   68% date/format) — paid down once with a small `Fn` helper layer, not 5,000 times.
4. **The dominant risk is call-graph coupling (44%)** — migrate clusters, not single procs.

## 3. Tool decision

| Option | Verdict |
|---|---|
| **linq2db** | **No.** Its justification was a high-ceiling read surface (~44 procs). Brings a parallel execution stack that bypasses the TflOmniDb pipeline (logging/retry/redaction) and is ORM-ish (against this project's no-ORM philosophy). |
| **SqlKata** | **No.** Maintenance has gone quiet; not worth a long-lived external dependency for a read slice this regular. |
| **Raw SQL + thin in-house composer + `Fn` layer** | **Yes.** Zero external dependency, rides the existing pipeline natively, AOT-clean for the net10 leg, and ~90% of the machinery already exists (`SqlGenerator.BuildSelectWhere`, `ExpressionTranslator`, `RawQueryExecutor`, `PocoMaterializer`, per-dialect `*TypeMapper`). |

## 4. Target architecture

```
C# service method (one per migrated proc / proc-cluster)
   │  builds query with ↓            builds expressions with ↓
   ├──────── SqlQuery (composer) ─────── Fn (function helpers) ────┐
   │                                                               │
   └─ .ToListAsync<T>(data) ─→ DataAccess.QueryAsync<T>(sql,params)  ← existing pipeline
                                 (CommandLogger · Retry · redaction · UseDirtyReads · correlation)
```

- **Reads (proc-#1 shape + the 946 dynamic-SQL procs):** `SqlQuery` composer + `Fn`,
  executed through the existing raw-SQL helpers.
- **~44 exotic reads (window/CTE/pivot):** raw `data.QueryAsync<T>(sql, params)` — same as today.
- **Orchestration (the ~75%):** plain C# service methods on TflOmniDb — `ExecuteInTransactionAsync`
  for atomic multi-step work, `GetAsync`/scalar/exists for lookups, `enum`s for the magic-number
  business codes, `foreach` for cursors, method calls for `EXEC`.

Crucially, the composer and `Fn` **produce SQL + bound parameters and delegate to
`DataAccess`/`IUnitOfWork`** — they never open connections or own transactions. So logging,
transient-fault retry, sensitive-column redaction, correlation IDs, and `UseDirtyReads` keep
working with no extra wiring.

## 5. API shapes to build

### 5.1 `SqlFunctions` / `Fn` — provider-bound scalar-function vocabulary

A tiny facade, bound to the active `ISqlDialect`, returning **SQL text fragments** rendered
per dialect. Pays down the 85%-ISNULL / 68%-date tax once.

```csharp
var fn = SqlFunctions.For(provider);     // or dialect.Fn
fn.Coalesce("c.ShortName", "''");        // ISNULL → COALESCE / NVL
fn.Concat("a", "' '", "b");              // a + b → a || b
fn.CharIndex("'x'", "a.code");           // CHARINDEX(n,h) → INSTR(h,n) / POSITION(n IN h)   (arg order flips!)
fn.Now(); fn.Substring(...); fn.Length(...); fn.DateAdd(...); fn.DateDiff(...);
fn.Cast("a.balance", CoreDataType.Money);// CAST via the dialect's *TypeMapper
```

| `Fn` method | SQL Server | PostgreSQL | Oracle |
|---|---|---|---|
| `Coalesce(a,b)` ← `ISNULL` | `ISNULL(a,b)` | `COALESCE(a,b)` | `NVL(a,b)` |
| `Now()` ← `GETDATE()` | `SYSDATETIME()` | `now()` | `SYSTIMESTAMP` |
| `Concat(a,b)` ← `a + b` | `a + b` | `a \|\| b` | `a \|\| b` |
| `CharIndex(n,h)` | `CHARINDEX(n,h)` | `POSITION(n IN h)` | `INSTR(h,n)` |
| `Substring/Length` | `SUBSTRING/LEN` | `SUBSTRING/LENGTH` | `SUBSTR/LENGTH` |
| `DateAdd/DateDiff` | `DATEADD/DATEDIFF` | interval math | interval math |

### 5.2 `SqlQuery` — thin conditional-predicate composer

Assembles `FROM/JOIN/WHERE(+conditional)/GROUP BY/HAVING/ORDER BY/paging`, collects
parameters, normalizes the placeholder prefix per dialect (`@id` → `:id` on Oracle), and
feeds the DAL. Headline feature: **`WhereIf`** (covers both the proc-#1 optional-filter idiom
and the 946 dynamic-SQL procs).

```csharp
public sealed class SqlQuery
{
    static SqlQuery From(string table, string alias, DbProvider provider);
    SqlQuery Select(params string[] exprs);
    SqlQuery InnerJoin(string tableAlias, string on);
    SqlQuery LeftJoin (string tableAlias, string on);
    SqlQuery Where  (string predicate, params (string name, object? value)[] ps);
    SqlQuery WhereIf(bool cond, string predicate, params (string,object?)[] ps);  // ← key
    SqlQuery GroupBy(params string[] cols);
    SqlQuery Having (string predicate, params (string,object?)[] ps);
    SqlQuery OrderBy(params string[] cols);
    SqlQuery Page(int? skip, int? take);   // dialect paging via ISqlDialect (OFFSET/FETCH vs LIMIT)

    (string Sql, IReadOnlyDictionary<string,object?> Parameters) Build();

    Task<IReadOnlyList<T>> ToListAsync<T>(DataAccess data,  CancellationToken ct = default) where T : new();
    Task<IReadOnlyList<T>> ToListAsync<T>(IUnitOfWork uow,  CancellationToken ct = default) where T : new();
    Task<TScalar?>         ScalarAsync<TScalar>(DataAccess data, …);
    Task<TScalar?>         ScalarAsync<TScalar>(IUnitOfWork uow, …);
    Task<bool>             ExistsAsync(DataAccess data, …);
    IAsyncEnumerable<T>    StreamAsync<T>(DataAccess data, …);   // net10 only
}
```

Predicate / join / select fragments are passed through **verbatim** (caller's responsibility,
same contract as today's raw SQL); the composer adds conditional composition, parameter
binding/dedup-by-name, dialect paging, and the `Fn` vocabulary. Result POCOs need **no
`[DbTable]`/PK** — they ride `QueryAsync<T>` + `PocoMaterializer`.

### 5.3 `ExecuteNonQueryAsync` — the one missing primitive

The dry-run surfaced the only genuine DAL gap: raw **reads** exist (`QueryAsync` /
`ExecuteScalarAsync` / `ExistsAsync`) but there is **no raw non-query write helper** for the
targeted `UPDATE/INSERT/DELETE` text that SP migration needs constantly.

```csharp
// DataAccess (owned connection + retry-eligible) and IUnitOfWork (transactional):
Task<int> ExecuteNonQueryAsync(string sql,
    IReadOnlyDictionary<string,object?>? parameters = null, CancellationToken ct = default);
```

Mirror `RawQueryExecutor` structurally (owned-vs-transaction + `CommandLogger` + retry),
returning rows-affected. Both legs (net10 + Fx).

## 6. Migration rules (derived from the dry-run)

- **Set-based work stays set-based SQL.** Never rewrite an `UPDATE…JOIN` / `MERGE` / cursor as
  fetch-loop-update in C# — that turns one round trip into thousands. Move *control flow* to
  C#; keep set operations in SQL.
- **`WITH(NOLOCK)` → `using (data.UseDirtyReads())`.** SQL Server applies the hint; no-op on
  Oracle/PG (MVCC). Decide read-consistency consciously.
- **Optional filters → `WhereIf`**, not `col = COALESCE(@p, col)` (the COALESCE idiom is
  non-SARGable; `WhereIf` omits the predicate → index-friendly).
- **Scalar UDFs → C# functions** (17 of them; e.g. `fn_MaskAadharOrPan` → `Mask.AadharOrPan`,
  which also ties into `[DbColumn(IsSensitive=true)]` redaction). Crypto UDFs become C# crypto.
- **Date/number *formatting* leaves SQL** (`CONVERT(...,105/106)`, `REPLACE`) → format in C#
  at the presentation edge (`dob?.ToString("dd-MM-yyyy")`). It is non-portable and does not
  belong in a data layer.
- **Magic-number business codes → shared `enum`s / `const` module** (the procs re-declare
  overlapping constants — centralize once).
- **`EXEC other_proc` → method call**; **transaction nesting (`@p_IsNestedCalling`/`@@TRANCOUNT`)
  → transaction ownership** (own via `ExecuteInTransactionAsync`, or participate by passing the
  `IUnitOfWork`).

## 7. Migration playbook

- **Triage by name.** Prefixes are functional modules (`pr_x_` core/txn, `pr_ccpc_`/`pr_cl_`
  clearing, `pr_atm_PRIZM_` ATM, `pr_rp_` reports, `pr_kyc_`, `pr_bw_` batch, `pr_g_` session…).
  The **`_r_` infix marks reports/reads** → composer/raw path; everything else → C# service
  methods.
- **Migrate clusters, not single procs** (44% call other procs; 316 call 6+). Either move a
  call-graph cluster together, or stand up a C#↔SQL-proc bridge and **strangler-fig** module by
  module, leaving the SP callable during transition.
- **Characterization tests first.** Before touching a proc, pin its current behavior with tests
  on the **live 3-DB harness** (the existing env-gated `[SkippableFact]` infrastructure across
  SQL Server / Oracle / PostgreSQL). The real cost is re-verifying decades of accreted business
  rules, not translating SQL.
- **Scale reality:** 5,316 procs / 1.8M lines is a multi-year effort. The TflOmniDb foundation
  already covers what the data demands (provider-agnostic CRUD, transactions, retry, raw-SQL
  helpers, redaction, 3-DB tests). The net-new pieces are §5.1–5.3.

## 8. Scope guardrails (keep it thin — never an ORM)

**`SqlQuery` does:** clause assembly, conditional composition, parameter collection + prefix
normalization, dialect paging, and the `Fn` vocabulary — then delegates to existing helpers.

**`SqlQuery` does NOT:** parse/validate SQL, build a LINQ/expression-tree AST, auto-quote
arbitrary identifiers, generate joins from navigation, do change tracking, or attempt
window/CTE/PIVOT. Those ~44 reads drop to raw `QueryAsync<T>`. This hard boundary keeps the
composer a few hundred lines, not a perennial query compiler.

## 9. Dry-run validation (two real procs)

- **`pr_b_r_GetLoanAccountList`** (read): composer + `Fn` covered FROM/3 joins/BETWEEN/optional
  filter/ORDER BY; `ROW_NUMBER` → C# index; `#temp` + correlated `TOP 1` → portable `GROUP BY`
  derived join (removed non-portable `TOP`). Surfaced two latent bugs (duplicate
  `LoanAgainstType = 1201`; name concat used `name2` twice, never `name3`) and one dead param.
- **`pr_apy_RegisterAccountPass`** (orchestration): `op_code` multiplexer → two C# methods;
  `BEGIN/COMMIT/ROLLBACK` + `EXEC…@error` → `ExecuteInTransactionAsync` + a throwing callee;
  `GETDATE()` → `fn.Now()`; UDF masking + `CONVERT` date formatting → C#. Surfaced a
  transaction-nesting bug (forces `@p_IsNestedCalling=1` immediately before checking it →
  a nested call rolls back the outer transaction).

Outcome: the design held up; it forced exactly **one** new primitive (`ExecuteNonQueryAsync`)
plus the two migration rules (UDFs→C#, formatting→C#) — no redesign.

## 10. Next implementation increment

Build order (each self-contained, both legs unless noted, mirroring existing feature structure
with unit + 3-DB integration tests + a demo entry + CLAUDE.md):

1. **`ExecuteNonQueryAsync`** on `DataAccess` + `IUnitOfWork` (smallest, proven-needed). ✅ **DONE**
   — both legs (`RawQueryExecutor` → `DataAccess`/`IUnitOfWork`/`UnitOfWork`), logged at
   `MutationLogLevel`, retry-eligible on the owned path; verified against live SQL Server
   (owned-connection UPDATE + transactional INSERT-with-rollback) on net10 and Fx; CLAUDE.md updated.
2. **`SqlFunctions` / `Fn`** facade (per-dialect, unit-tested by rendering assertions). ✅ **DONE**
   — both legs (`*.Query.SqlFunctions`); `Coalesce`/`Concat`/`Now`/`CharIndex`/`Substring`/
   `Length`/`Upper`/`Lower`/`Trim`/`Cast`; unit-tested across the 3 dialects.
3. **`SqlQuery`** composer (rides the raw-SQL helpers; net10 adds `StreamAsync`). ✅ **DONE**
   — both legs (`*.Query.SqlQuery`): `Select`/`InnerJoin`/`LeftJoin`/`Where`/`WhereIf`/`GroupBy`/
   `Having`/`OrderBy`/`Page` → `Build()` (dialect prefix rewrite + param dedup) → `ToListAsync`/
   `ToDictionariesAsync`/`ScalarAsync`/`ExistsAsync` (+ net10 `StreamAsync`). Unit-tested no-DB
   + end-to-end against live SQL Server. Suites: **net10 407/407, Fx 324/324** green.
4. **A pilot module migration** — one `_r_` read + one small orchestration proc — as the first
   strangler slice, with characterization tests on the live 3-DB harness. ✅ **DONE** —
   `TflOmniDb.Tests/Migration/PilotMigration.cs` (the migrated service methods: a join +
   `WhereIf` + `Fn` read, and an `ExecuteInTransactionAsync` orchestration with atomic
   rollback) + `PilotMigrationTests.cs` (self-contained portable `TflPilot*` schema, seeded
   and exercised end-to-end). **Green on SQL Server, Oracle, and PostgreSQL** (net10
   suite 410/410).

### Caveats the pilot surfaced (add to the migration checklist)

- **Don't name parameters after SQL reserved words.** Oracle rejects bind variables like
  `:from` / `:to` with **ORA-01745**. Use `@fromDt` / `@toDt` etc. (CBS's `@p_`-prefixed
  convention already avoids this.)
- **Match string column types to string literals on Oracle.** Concatenating an `NVARCHAR2`
  column with a plain `VARCHAR2` literal (`' '`, `CASE` labels) raises **ORA-12704**
  (character-set mismatch). Keep the column and literals the same charset, or `N'…'`-prefix
  the literals (not portable — prefer matching types).
- **Raw `ExecuteNonQueryAsync` writes carry the dialect parameter prefix themselves.** The
  composer normalizes `@`→`:` for *reads* automatically; raw writes don't, so migrated write
  code computes the prefix (`provider == Oracle ? ":" : "@"`). A future `UpdateBuilder` could
  absorb this the way `SqlQuery` does for reads.

## Status

The migration **foundation is complete and verified**: `ExecuteNonQueryAsync`,
`SqlFunctions`/`Fn`, `SqlQuery`, and a green 3-DB pilot. Suites: **net10 521/521, Fx 332/332**
(the per-increment counts above are the historical values at each milestone).
The remaining work is the migration itself — proc clusters, module by module, behind a
strangler bridge, each with characterization tests on the live 3-DB harness, using
`PilotMigration` as the template.

Tooling added since the pilot that the migration should lean on:

- **Typed `Col`/`Agg` tokens + scaffolder-emitted `Cols` classes** — compile-checked column
  references for the composer (replaces string fragments in migrated reads).
- **Typed scalar aggregates** `MaxAsync`/`MinAsync`/`SumAsync`/`AvgAsync`/`MaxKeyAsync`/`AnyAsync`
  (each with an optional predicate) — covers the very common `SELECT MAX/SUM/EXISTS` proc bodies
  without raw SQL.
- **Partial-column & set-based `UpdateAsync`** — the targeted `UPDATE t SET c=… WHERE …`
  shape most write procs reduce to.
- **`UseCommandTimeout(seconds)`** — per-operation server-side timeout scope for the
  long-running report/batch procs (the legacy per-call `CommandTimeout` ergonomics).
- **`RowAccess`** — null-safe typed getters over untyped rows / SP result sets (incl.
  buffered SP→POCO `ToList<T>()`).
