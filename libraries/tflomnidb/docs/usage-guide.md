# TflOmniDb — Usage Guide

Task-oriented recipes. Signatures live in [api-reference.md](api-reference.md); internals in
[components.md](components.md). Examples target the **net10** leg; anything marked **net10** has no Fx equivalent.

---

## Contents

1. [Setting up `DataAccess`](#1-setting-up-dataaccess)
2. [Defining an entity](#2-defining-an-entity)
3. [CRUD](#3-crud)
4. [Filtering, ordering, paging](#4-filtering-ordering-paging)
5. [Reading fewer columns](#5-reading-fewer-columns)
6. [Targeted updates](#6-targeted-updates)
7. [Scalar aggregates](#7-scalar-aggregates)
8. [Transactions](#8-transactions)
9. [Optimistic concurrency](#9-optimistic-concurrency)
10. [Bulk insert](#10-bulk-insert)
11. [Streaming large reads](#11-streaming-large-reads)
12. [Complex queries — raw SQL](#12-complex-queries--raw-sql)
13. [Composing SQL — `SqlQuery` + `Fn`](#13-composing-sql--sqlquery--fn)
14. [Stored procedures](#14-stored-procedures)
15. [Reading untyped rows safely](#15-reading-untyped-rows-safely)
16. [Transient-fault retry](#16-transient-fault-retry)
17. [Dirty reads](#17-dirty-reads)
18. [Command timeout](#18-command-timeout)
19. [Logging, redaction, correlation](#19-logging-redaction-correlation)
20. [Writing portable SQL across three engines](#20-writing-portable-sql-across-three-engines)
21. [Troubleshooting](#21-troubleshooting)

---

## 1. Setting up `DataAccess`

One instance per connection string, for the life of the process. It is thread-safe and holds no connection.

```csharp
var data = new DataAccess(new DataAccessOptions
{
    Provider              = DbProvider.SqlServer,   // required
    ConnectionString      = cs,                     // required
    DefaultSchema         = "dbo",                  // connection-level, not per table
    CommandTimeoutSeconds = 30,                     // null ⇒ provider default
    LoggerFactory         = loggerFactory,          // null ⇒ nothing is logged
    LogParameterValues    = false,                  // keep false in production
});
```

In DI, register it as a singleton:

```csharp
services.AddSingleton(sp => new DataAccess(new DataAccessOptions
{
    Provider         = Enum.Parse<DbProvider>(cfg["Db:Provider"]!),
    ConnectionString = cfg.GetConnectionString("Cbs")!,
    DefaultSchema    = cfg["Db:Schema"] ?? "dbo",
    LoggerFactory    = sp.GetRequiredService<ILoggerFactory>(),
}));
```

Switching engines is a **configuration** change — no code change, provided your SQL stays inside the typed API or
the `SqlQuery` composer.

---

## 2. Defining an entity

```csharp
[DbTable(TableName = "B_ACCOUNT")]
public partial class B_ACCOUNT : Entity
{
    [DbColumn(ColumnName = "ACCOUNT_ID", CoreType = CoreDataType.Int64,
              IsPrimaryKey = true, KeyGeneration = KeyGenerationStrategy.Identity)]
    public virtual long? ACCOUNT_ID { get; set; }

    [DbColumn(ColumnName = "ACCOUNT_NAME", CoreType = CoreDataType.UnicodeString, Size = 100)]
    public virtual string? ACCOUNT_NAME { get; set; }

    [DbColumn(ColumnName = "BALANCE", CoreType = CoreDataType.Money)]
    public virtual decimal? BALANCE { get; set; }

    [DbColumn(ColumnName = "PIN", CoreType = CoreDataType.AnsiString, Size = 8, IsSensitive = true)]
    public virtual string? PIN { get; set; }          // redacted in command logs

    [DbColumn(ColumnName = "ROW_VER", CoreType = CoreDataType.Int32, IsRowVersion = true)]
    public virtual int? ROW_VER { get; set; }
}
```

Rules that are enforced, not advisory:

- **`Size` > 0 is required** for variable-length strings — otherwise `MetadataValidationException` at first use.
- **`SequenceName` is required** when `KeyGeneration = Sequence`.
- **At most one `IsRowVersion`** column per entity.
- Properties are **nullable** so partial rows (projections) materialise, and **virtual** by convention.
- Table names must be identical across all three databases; the schema comes from `DataAccessOptions`.

Don't hand-write these — generate them with the [scaffolder](tooling.md), which also emits a nested `Cols` class
of typed column tokens.

---

## 3. CRUD

```csharp
var repo = data.Repository<B_ACCOUNT>();

// Insert — identity flows back into the instance
var acc = new B_ACCOUNT { ACCOUNT_NAME = "Ledger", BALANCE = 0m, ROW_VER = 0 };
await repo.InsertAsync(acc);
long id = acc.ACCOUNT_ID!.Value;

// Read by key — keys in declaration order; null when absent
B_ACCOUNT? found = await repo.GetAsync([id]);

// Update — every updatable column
found!.BALANCE = 100m;
int rows = await repo.UpdateAsync(found);

// Delete — key read from the entity
await repo.DeleteAsync(found);
```

Composite keys pass in declaration order: `await repo.GetAsync([branchId, accountNo]);`

---

## 4. Filtering, ordering, paging

```csharp
var page = await repo.WhereAsync(
    x => x.BALANCE > 1000m && x.ACCOUNT_NAME!.StartsWith("A"),
    orderBy: x => x.ACCOUNT_NAME!,
    descending: false,
    skip: 40, take: 20);

long matching = await repo.CountAsync(x => x.BALANCE > 1000m);
bool anyRich  = await repo.AnyAsync(x => x.BALANCE > 1_000_000m);   // net10, cheaper than Count > 0
```

Supported predicate shapes: binary comparisons, `&&` / `||` / `!`, null checks, `string.Contains` / `StartsWith`
/ `EndsWith`, `list.Contains(x.Prop)`, member access on the entity, and captured locals. Anything else throws
`NotSupportedException` — that is the signal to drop to raw SQL or `SqlQuery`.

```csharp
var wanted = new[] { 1L, 2L, 3L };
await repo.WhereAsync(x => wanted.Contains(x.ACCOUNT_ID!.Value));   // IN (@p0, @p1, @p2)
```

Pass `null` for the predicate to page over the whole table. When `skip`/`take` is set without `orderBy`, ordering
falls back to the first PK column so paging is deterministic. LIKE metacharacters (`%`, `_`, `[`, `]`) inside a
`Contains`/`StartsWith` value are escaped and bound — user input is safe here.

---

## 5. Reading fewer columns

```csharp
// Dropdown: only Id + Name off a wide table (PK always included)
var summaries = await repo.GetAllAsync(x => x.ACCOUNT_ID, x => x.ACCOUNT_NAME);

// Single row, two columns
var one = await repo.GetAsync([id], x => x.ACCOUNT_NAME, x => x.BALANCE);

// net10 — filter and project together (columns are the 2nd argument)
var u = (await repo.WhereAsync(x => x.LOGINNAME == login, [x => x.ORGELEMENTID], take: 1))
        .FirstOrDefault();
```

Unprojected properties stay at their CLR default on the returned entity — **do not** persist a projected entity
with `UpdateAsync`, or you will blank every column you did not read. Use a [partial update](#6-targeted-updates)
instead. Each selector must be a simple property access; computed expressions throw `ArgumentException`.

---

## 6. Targeted updates

**net10.** Three write shapes, narrowest first:

```csharp
// Partial-column — no prior read needed; PK + changed columns is enough
await repo.UpdateAsync(new B_ACCOUNT { ACCOUNT_ID = 42, ACCOUNT_NAME = "renamed", ROW_VER = current },
                       x => x.ACCOUNT_NAME);

// Set-based — UPDATE … SET … WHERE <predicate>; many rows, no PK
await repo.UpdateWhereAsync(x => x.BALANCE < 50m, [ (x => x.ACCOUNT_NAME, "dormant") ]);

// Set-based delete
await repo.DeleteWhereAsync(x => x.BALANCE == 0m);
```

The distinction that matters: **partial update always enforces row-version** (incremented in SET, checked in
WHERE, even when not listed among the columns) — so the entity must carry the current version. **Set-based
update/delete has no row-version semantics at all**; it is a blind bulk write. Choose deliberately.

---

## 7. Scalar aggregates

**net10.** The typed replacement for the legacy `Max(type, criteria)` / `MaxPrimaryKeyValue(type)` idiom.

```csharp
decimal  max  = await repo.MaxAsync<decimal>(x => x.BALANCE);
decimal  hi   = await repo.MaxAsync<decimal>(x => x.BALANCE, x => x.STATUS == 1);
decimal  sum  = await repo.SumAsync<decimal>(x => x.BALANCE, x => x.BALANCE >= 30m);
long     next = await repo.MaxKeyAsync<long>();
bool     any  = await repo.AnyAsync(x => x.BALANCE > 999m);

decimal? maybe = await repo.MaxAsync<decimal?>(x => x.BALANCE);   // null ⇒ genuinely no rows
```

Three traps:

- **Empty set ⇒ `default(TResult)`.** `MaxAsync<decimal>` returns `0` for an empty table — indistinguishable from
  a real zero. Use a nullable `TResult` when the difference matters.
- **`SUM` of an `int` column stays `int` on SQL Server.** Pick a wide `TResult` to avoid overflow.
- **`AVG` follows the engine.** An integer column averages to a truncated integer on SQL Server and Oracle. Average
  a decimal column, or cast in raw SQL.

Aggregates work transactionally through `uow.Repository<T>()`.

---

## 8. Transactions

```csharp
await using (var uow = await data.BeginTransactionAsync())
{
    var accounts = uow.Repository<B_ACCOUNT>();
    var journal  = uow.Repository<B_JOURNAL>();

    await accounts.UpdateAsync(debited);
    await accounts.UpdateAsync(credited);
    await journal.InsertAsync(entry);

    await uow.CommitAsync();
}
// Disposing without CommitAsync rolls back — including on an exception.
```

Non-transactional `data.Repository<T>()` opens a **fresh connection per call**, so two calls are two transactions.
For any money movement, use a unit of work.

Raw SQL and stored procedures have transactional counterparts on `IUnitOfWork` (`uow.QueryAsync`,
`uow.ExecuteNonQueryAsync`, `uow.ExecuteProcedureAsync`, …) so they enlist rather than opening their own connection.

---

## 9. Optimistic concurrency

App-managed and identical on all three engines — no `ROWVERSION` / `xmin` / `ORA_ROWSCN` dependency.

```csharp
[DbColumn(ColumnName = "ROW_VER", CoreType = CoreDataType.Int32, IsRowVersion = true)]
public virtual int? ROW_VER { get; set; }
```

The repository increments the column in SET and checks the old value in WHERE. Zero rows matched ⇒
`ConcurrencyException`.

```csharp
try
{
    await repo.UpdateAsync(entity);
}
catch (ConcurrencyException)
{
    // Someone else changed the row since you read it. Re-read, re-apply, or surface a conflict to the user.
}
```

Set an initial value on insert (`ROW_VER = 0`) unless the column has a DB default — `BulkInsertAsync` writes the
entity's value verbatim and will happily insert NULL.

---

## 10. Bulk insert

```csharp
int written = await repo.BulkInsertAsync(rows, new BulkInsertOptions
{
    BatchSize      = 5000,
    TimeoutSeconds = 120,
});
```

Orders of magnitude faster than `InsertAsync` in a loop beyond ~50 rows. Per provider: `SqlBulkCopy` (SQL Server),
binary `COPY` (PostgreSQL), `OracleBulkCopy` (Oracle — synchronous, wrapped in `Task.Run`).

**Limitations to plan around:**

| Limitation | Consequence |
|---|---|
| Identity values are **not** round-tripped | If you need generated ids, use `InsertAsync` per row |
| Row-version inserted verbatim | Set an initial value yourself |
| Oracle requires unquoted-uppercase table names | OCI direct-path strips quotes; `CREATE TABLE "Widget"` is unreachable via bulk — use `InsertAsync` for those |
| Excluded from auto-retry | A partial batch cannot resume |

`EnableTableLock` and `FireTriggers` are SQL-Server-only. When called on a transaction-attached repository the
bulk load enlists in that transaction and rollback discards the rows.

---

## 11. Streaming large reads

**net10.** Constant memory instead of a `List<T>` the size of the result set.

```csharp
await foreach (var row in repo.StreamWhereAsync(x => x.BRANCH_ID == branch, ct: ct))
{
    await WriteToStatementFile(row);
}
```

`StreamAllAsync`, `StreamWhereAsync`, `StreamQueryAsync` and `StreamProcedureAsync` are all backed by one open
reader; the connection stays open for the enumeration, so `await foreach` (deterministic disposal) is mandatory —
do not park an enumerator across requests. Streaming is **excluded from auto-retry**: rows already yielded cannot
be un-yielded. Cancellation mid-stream is honoured.

`TflOmniDb.Benchmarks/StreamingVsBufferedBenchmarks` measures the O(1) vs O(n) claim.

---

## 12. Complex queries — raw SQL

The typed API generates **no joins, GROUP BY or sub-queries** by design. Those are raw SQL, through non-entity
helpers that still route via `CommandLogger` and the retry path.

```csharp
// GROUP BY into a plain POCO — no [DbTable], no PK, no Entity base
public sealed class CustomerSummary
{
    public int CustomerId { get; set; }
    public int OrderCount { get; set; }
    public decimal TotalAmount { get; set; }
}

var rows = await data.QueryAsync<CustomerSummary>(
    "SELECT CustomerId, COUNT(*) AS OrderCount, SUM(Amount) AS TotalAmount FROM Orders GROUP BY CustomerId");

// Untyped rows
var buckets = await data.QueryAsync(
    "SELECT 'low' AS Bucket, COUNT(*) AS N FROM Orders WHERE Amount < @t " +
    "UNION ALL SELECT 'high', COUNT(*) FROM Orders WHERE Amount >= @t",
    new Dictionary<string, object?> { ["@t"] = 60m });

decimal total = await data.ExecuteScalarAsync<decimal>("SELECT SUM(Amount) FROM Orders");
bool     any  = await data.ExistsAsync("SELECT 1 FROM Orders WHERE CustomerId = @id", pars);
int      hit  = await data.ExecuteNonQueryAsync("UPDATE Orders SET Amount = Amount + @b WHERE Id = @id", pars);
```

Mapping for `QueryAsync<T>` is column→property by name, case-insensitive, honouring `[DbColumn(ColumnName=…)]` as
an alias; unmatched columns are ignored.

**Parameter keys carry the dialect prefix** (`"@id"` / `":id"`). **The SQL text is yours to make safe** — never
concatenate user input into it. That is the whole reason the typed API exists.

---

## 13. Composing SQL — `SqlQuery` + `Fn`

A thin, provider-aware layer over the raw-SQL helpers, built for the stored-procedure-to-C# migration. It
generates SQL + bound parameters and delegates to the same pipeline, so logging, retry, redaction and dirty-reads
keep working.

```csharp
using TflOmniDb.Query;

var q = SqlQuery.From("ORDERS", "o", data.Options.Provider)
    .Select("o.CUSTOMER_ID", "COUNT(*) AS ORDER_COUNT")
    .WhereIf(branchId is not null, "o.BRANCH_ID = @branch", ("branch", branchId))
    .WhereIf(from is not null,     "o.ORDER_DATE >= @from",  ("from", from))
    .GroupBy("o.CUSTOMER_ID")
    .Having("COUNT(*) > @min", ("min", 5))
    .OrderBy("ORDER_COUNT DESC")
    .Page(skip, take);

var rows = await q.ToListAsync<CustomerSummary>(data);
```

`WhereIf` is the point of the whole thing: it replaces both the "eight near-identical query branches" report
pattern and runtime dynamic-SQL string building — and unlike `col = COALESCE(@p, col)` it stays index-friendly,
because the predicate is simply absent when the filter is not supplied.

**Typed tokens** avoid string fragments entirely (the scaffolder emits `Cols` per entity):

```csharp
var q = SqlQuery.From<B_ACCOUNT>("a", provider)
    .SelectCols(B_ACCOUNT.Cols.ACCOUNT_ID, B_ACCOUNT.Cols.ACCOUNT_NAME)
    .InnerJoin<B_BRANCH>("b", B_ACCOUNT.Cols.BRANCH_ID.As("a"), B_BRANCH.Cols.BRANCH_ID.As("b"))
    .Where(B_ACCOUNT.Cols.STATUS, "=", 1)
    .OrderBy(B_ACCOUNT.Cols.ACCOUNT_NAME);
```

**Cross-dialect scalars** via `Fn` — this is what pays down the pervasive `ISNULL` / `GETDATE` / `+`-concat tax:

```csharp
var fn = q.Fn;
q.Select(fn.Coalesce("o.NOTE", "''"), fn.Concat("c.FIRST", "' '", "c.LAST"), fn.Now());
```

Placeholders use the neutral `@name` prefix; `Build()` rewrites to the dialect prefix (`@`→`:` on Oracle) and
de-duplicates reused names. **Fragments pass through verbatim** — bind values as parameters, never concatenate.

`Build()` returns `(sql, parameters)` if you want to run or log it yourself. Not modelled: window functions, CTEs,
PIVOT — those stay raw `QueryAsync<T>`.

---

## 14. Stored procedures

```csharp
var call = new StoredProcedureCall("usp_Transfer")            // schema defaults to DefaultSchema
    .Input("p_from", 1001)
    .Input("p_amount", 500m, CoreDataType.Money)
    .Input("p_pin", pin, CoreDataType.AnsiString, size: 8, sensitive: true)   // redacted in logs
    .InputOutput("p_note", "ref", CoreDataType.UnicodeString, size: 50)
    .Output("p_new_balance", CoreDataType.Money)
    .ReturnValue();                                            // SQL Server / Oracle only

StoredProcedureResult r = await data.ExecuteProcedureAsync(call);

decimal bal  = r.GetOutput<decimal>("p_new_balance");
int?    code = r.ReturnValue;
var     rows = r.FirstResultSet;
```

- Parameter names **without** the `@` / `:` prefix; the DAL adds the provider's.
- List them in the procedure's declared order — **PostgreSQL binds positionally**.
- `ExecuteScalarProcedureAsync` / `ExecuteNonQueryProcedureAsync` for the simple cases; the `IUnitOfWork`
  equivalents enlist in a transaction.
- Result sets are **raw/untyped by design** — map them yourself, or use [`RowAccess`](#15-reading-untyped-rows-safely).

Provider differences you must code for:

```csharp
// Oracle: multiple result sets arrive as OUT REF CURSORs
var oracle = new StoredProcedureCall("PR_G_GETSTATEMENT")     // UPPERCASE — the DAL always quotes
    .Input("p_acct", id)
    .Cursor("p_rows");

// Collection parameters: TVP (SQL Server) / assoc array (Oracle) / native array (PostgreSQL)
call.Table("p_ids", dataTable, "dbo.IdList");   // SQL Server needs the pre-created TABLE TYPE
call.Table("p_ids", idArray);                   // Oracle / PostgreSQL
```

`ReturnValue()` on PostgreSQL throws `NotSupportedException` — procedures there return through OUT/INOUT.

**net10** adds `repo.StreamProcedureAsync(call)` → `IAsyncEnumerable<T>` over the **first** result set only.

---

## 15. Reading untyped rows safely

Instead of hand-casting `object?` and guarding four failure modes (null result set, missing row, missing column,
SQL NULL):

```csharp
using TflOmniDb.Repository;   // RowAccess extensions

// On an untyped row
foreach (var row in await data.QueryAsync(sql, pars))
{
    string? name = row.GetString("ACCOUNT_NAME");
    decimal bal  = row.GetDecimal("BALANCE", 0m);       // non-null overload with a fallback
    if (row.IsNull("CLOSED_ON")) { … }
}

// On a stored-proc result — null-safe receiver, so this is fine even if FirstResultSet is null
var first = result.FirstResultSet.FirstRow();
long id   = result.FirstResultSet.Get<long>("ACCOUNT_ID");
var list  = result.FirstResultSet.ToList<AccountRow>();  // buffered SP → POCO
```

`Get<T>` returns `default` for a missing column or SQL NULL (`Get<int>` → `0`, `Get<int?>` → `null`); use
`GetAs<T>` for `byte[]` / `string` where `Convert.ChangeType` would throw.

---

## 16. Transient-fault retry

**Off by default.** Enabling it changes failure semantics, so do it consciously.

```csharp
var options = new DataAccessOptions
{
    Provider = DbProvider.SqlServer,
    ConnectionString = cs,
    Retry = new RetryOptions
    {
        MaxAttempts    = 3,
        BaseDelay      = TimeSpan.FromMilliseconds(200),
        MaxDelay       = TimeSpan.FromSeconds(5),
        RetryOnTimeout = false,        // keep false on write paths
        UseJitter      = true,
    },
};
```

**What retries:** the owned-connection path — single CRUD, `WhereAsync` / `CountAsync` / `QueryAsync`, aggregates,
stored-procedure calls. Each attempt opens a fresh connection.

**What does not:** a single command inside an open transaction, bulk insert, streaming.

**To retry multi-statement work**, wrap it — this is the only safe way:

```csharp
await data.ExecuteInTransactionAsync(async uow =>
{
    await uow.Repository<B_ACCOUNT>().UpdateAsync(debited);
    await uow.Repository<B_ACCOUNT>().UpdateAsync(credited);
    await uow.CommitAsync();
});
// Rolls back and reopens a fresh connection + transaction per attempt — so make the delegate idempotent.
```

**Write safety.** Deadlocks (the engine already rolled back) and pre-send connection errors are always retried.
**Command timeouts are not retried unless `RetryOnTimeout = true`** — a timed-out non-idempotent write may already
have committed on the server, and retrying would double-apply it. Leave it off for writes.

Every retry logs a Warning.

---

## 17. Dirty reads

```csharp
using (data.UseDirtyReads())
{
    var snapshot = await repo.GetAllAsync();   // WITH(NOLOCK) on SQL Server
}
```

No-op on Oracle and PostgreSQL, which are MVCC by design. Scoped to the async flow; nested scopes shadow and
restore. Remember what it buys and costs: fewer blocked readers, at the price of dirty/phantom rows — never for
anything that drives a posting decision.

---

## 18. Command timeout

**net10.** Three levels, narrowest wins:

```csharp
// 1 · instance default
new DataAccessOptions { …, CommandTimeoutSeconds = 30 }

// 2 · per scope (async-flow local; nests, shadows, restores)
using (data.UseCommandTimeout(300))
{
    await repo.QueryAsync(bigReportSql);        // 300s for everything in this scope
}

// 3 · bulk insert has its own
await repo.BulkInsertAsync(rows, new BulkInsertOptions { TimeoutSeconds = 600 });
```

`0` means no timeout. This is the **server-side** timeout — distinct from a client-side `CancellationToken`
deadline; set both if you want a hard bound on a request.

---

## 19. Logging, redaction, correlation

```csharp
var options = new DataAccessOptions
{
    …,
    LoggerFactory      = loggerFactory,
    LogParameterValues = false,                 // default; keep it in production
    MutationLogLevel   = LogLevel.Information,  // INSERT / UPDATE / DELETE / raw writes
    QueryLogLevel      = LogLevel.Debug,        // reads
};
```

With no `LoggerFactory` everything is swallowed by `NullLogger` — logging is opt-in.

```csharp
using (data.PushCorrelation(httpContext.TraceIdentifier))
{
    await repo.InsertAsync(entity);   // every command in this scope carries the correlation id
}

using (data.SuppressLogging()) { await repo.GetAllAsync(); }   // e.g. a noisy poll
```

**Redaction:** columns marked `[DbColumn(IsSensitive = true)]` and procedure inputs passed with `sensitive: true`
are replaced in log output even when `LogParameterValues = true`. `DataAccessOptions.GloballyEnabled` is a
process-wide kill switch.

---

## 20. Writing portable SQL across three engines

Inside the typed API, portability is free. Once you drop to raw SQL it is your problem. What actually bites:

| Concern | Rule |
|---|---|
| **Identifier casing** | The DAL always quotes, so `"Widget"` ≠ `"WIDGET"`. Create objects with **uppercase** names — quoted uppercase on PostgreSQL — so all three agree |
| **Parameter prefix** | `@` on SQL Server / PostgreSQL, `:` on Oracle. `SqlQuery` rewrites it for you; hand-written SQL does not |
| **Scalar functions** | `ISNULL` / `NVL` / `COALESCE`, `+` vs `\|\|`, `LEN` vs `LENGTH`, `CHARINDEX` vs `INSTR` vs `POSITION`. Use `Fn` |
| **Paging** | OFFSET-FETCH (SQL Server 2012+, Oracle 12c+) vs LIMIT-OFFSET (PostgreSQL). The typed API handles it |
| **Booleans** | `BIT` / `NUMBER(1,0)` / `BOOLEAN` — use `CoreDataType.Boolean`, never a literal `1`/`true` in raw SQL |
| **Dates** | `DateTime` binds as `DateTime2` on SQL Server / PostgreSQL, folds to `DbType.DateTime` on Oracle. Never format a date into SQL text |
| **`SELECT 1` vs `EXISTS`** | Oracle needs `FROM DUAL` for a bare select — `AnyAsync` and `ExistsAsync` already use the portable form |
| **Procedures** | Different enough that the call site must know the engine — see [§14](#14-stored-procedures) |

The net10 demo has a no-DB "generated-SQL comparison" entry that prints the three dialects side by side for the
same operation — the fastest way to see what will differ.

---

## 21. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `MetadataValidationException` on first use | A variable-length string column with no `Size`, a `Sequence` key with no `SequenceName`, or two `IsRowVersion` columns |
| `NotSupportedException` from `WhereAsync` | Predicate shape outside the supported set — drop to raw SQL or `SqlQuery` |
| `ArgumentException` from a projection or partial update | Selector is not a simple property access, or it names a PK / read-only / computed column, or the list is empty |
| `ConcurrencyException` | Row changed since you read it — re-read and re-apply. On a partial update, check the entity carries the **current** row-version |
| Update blanked columns you did not set | You persisted a **projected** entity with the full `UpdateAsync`. Use the partial overload |
| Oracle bulk insert cannot find the table | The table was created with a quoted mixed-case name. OCI direct path uppercases — recreate unquoted, or use `InsertAsync` |
| `InvalidOperationException` from `MaxKeyAsync` | Composite or keyless entity — use `MaxAsync` with an explicit selector |
| PostgreSQL procedure throws on `.ReturnValue()` | Not supported there; use an OUT parameter |
| Oracle procedure "not found" | Unquoted-uppercase procedures must be named in UPPERCASE — the DAL always quotes |
| Oracle rejects a `DateTime` parameter | Already handled (`DbType.DateTime` on Oracle). If you bound the parameter by hand, do the same |
| Retry never fires on a timeout | By design — set `RetryOnTimeout = true` only if the operation is idempotent |
| Streaming enumeration throws after a while | The connection is held for the enumeration. Do not park an enumerator across requests, and always `await foreach` |
| Parameter values missing from logs | `LogParameterValues` is `false` by default; sensitive columns stay redacted regardless |
