# TflOmniDb — Writing queries without raw SQL

Every query shape you would normally write as SQL, and the TflOmniDb call that replaces it:
**SQL on the left, C# on the right.** Companion to [usage-guide.md](usage-guide.md) (task recipes)
and [api-reference.md](api-reference.md) (signatures). Examples target the **net10** leg; items
marked **net10** have no Fx equivalent.

The goal is not "never type SQL again" — it is that **the query is expressed in C#, so it compiles,
refactors, and runs unchanged on SQL Server, Oracle and PostgreSQL**. §17 is the honest list of
shapes that still need the raw-SQL escape hatch.

---

## Contents

1. [Three layers, and when each is enough](#1-three-layers-and-when-each-is-enough)
2. [Master index — SQL construct → TflOmniDb API](#2-master-index--sql-construct--tflomnidb-api)
3. [The worked schema](#3-the-worked-schema)
4. [SELECT — whole rows](#4-select--whole-rows)
5. [SELECT — fewer columns](#5-select--fewer-columns)
6. [WHERE — the predicate cheat-sheet](#6-where--the-predicate-cheat-sheet)
7. [ORDER BY, TOP, paging](#7-order-by-top-paging)
8. [COUNT, EXISTS, aggregates](#8-count-exists-aggregates)
9. [INSERT](#9-insert)
10. [UPDATE](#10-update)
11. [DELETE](#11-delete)
12. [Transactions, concurrency, locking hints](#12-transactions-concurrency-locking-hints)
13. [JOIN, GROUP BY, DISTINCT — the `SqlQuery` composer](#13-join-group-by-distinct--the-sqlquery-composer)
14. [Dynamic WHERE — retiring dynamic SQL](#14-dynamic-where--retiring-dynamic-sql)
15. [Portable scalar functions — `Fn`](#15-portable-scalar-functions--fn)
16. [Sub-queries, UNION, cursors, procedures](#16-sub-queries-union-cursors-procedures)
17. [Where the no-SQL surface ends](#17-where-the-no-sql-surface-ends)
18. [Gotchas](#18-gotchas)

---

## 1. Three layers, and when each is enough

| Layer | SQL you write | Covers | Provider-portable? |
|---|---|---|---|
| **1. Typed repository** — `IRepository<T>` | **none at all** | Single-table CRUD, filter, order, page, project, count, exists, aggregates, bulk insert, streaming | Yes — the SQL is generated per dialect |
| **2. `SqlQuery` composer** (`TflOmniDb.Query`) | **none on the common path** — columns are `Col` / `Agg` tokens; only `HAVING`, `CASE` and aggregate-alias `ORDER BY` still take a short text fragment | JOIN, GROUP BY, HAVING, DISTINCT, conditional WHERE, paging, scalar, EXISTS | Yes — identifiers auto-quoted, `@p` → `:p` on Oracle, paging per dialect |
| **3. Raw SQL** — `DataAccess.QueryAsync` / `ExecuteNonQueryAsync` | the whole statement | Window functions, CTE, PIVOT, MERGE, UNION, `INSERT…SELECT`, DDL | No — you write dialect-aware text |

Rule of thumb: **stay in layer 1 until the query touches more than one table or groups rows.**
Then move to layer 2. Layer 3 is a deliberate escape hatch, not a fallback to drift into.

All three go through the same pipeline — command logging, sensitive-value redaction, correlation
id, transient-fault retry, `UseDirtyReads()`, `UseCommandTimeout()`. Choosing layer 1 or 2 costs
nothing operationally.

---

## 2. Master index — SQL construct → TflOmniDb API

| SQL | TflOmniDb | Layer | § |
|---|---|---|---|
| `SELECT * FROM t WHERE pk = @id` | `repo.GetAsync(new object[] { id })` | 1 | [4](#4-select--whole-rows) |
| `SELECT * FROM t` | `repo.GetAllAsync()` | 1 | [4](#4-select--whole-rows) |
| `SELECT a, b FROM t` | `repo.GetAllAsync(x => x.A, x => x.B)` | 1 | [5](#5-select--fewer-columns) |
| `SELECT a, b FROM t WHERE …` | `repo.WhereAsync(pred, [x => x.A, x => x.B])` **net10** | 1 | [5](#5-select--fewer-columns) |
| `WHERE … = / <> / < / >` | `repo.WhereAsync(x => x.Col == v)` | 1 | [6](#6-where--the-predicate-cheat-sheet) |
| `WHERE … AND / OR / NOT` | `&&` / `\|\|` / `!` | 1 | [6](#6-where--the-predicate-cheat-sheet) |
| `WHERE c IS NULL` | `x => x.C == null` | 1 | [6](#6-where--the-predicate-cheat-sheet) |
| `WHERE c BETWEEN a AND b` | `x => x.C >= a && x.C <= b` | 1 | [6](#6-where--the-predicate-cheat-sheet) |
| `WHERE c LIKE '%x%'` | `x => x.C!.Contains("x")` | 1 | [6](#6-where--the-predicate-cheat-sheet) |
| `WHERE c IN (…)` | `x => list.Contains(x.C!.Value)` | 1 | [6](#6-where--the-predicate-cheat-sheet) |
| `ORDER BY c DESC` | `orderBy: x => x.C!, descending: true` | 1 | [7](#7-order-by-top-paging) |
| `TOP (n)` / `OFFSET … FETCH` / `LIMIT` | `skip:` / `take:` | 1 | [7](#7-order-by-top-paging) |
| `SELECT COUNT(*)` | `repo.CountAsync(pred)` | 1 | [8](#8-count-exists-aggregates) |
| `IF EXISTS (SELECT 1 …)` | `repo.AnyAsync(pred)` | 1 | [8](#8-count-exists-aggregates) |
| `SELECT MAX/MIN/SUM/AVG(c)` | `repo.MaxAsync<T>(x => x.C, pred)` … **net10** | 1 | [8](#8-count-exists-aggregates) |
| `SELECT MAX(pk)` | `repo.MaxKeyAsync<long>()` **net10** | 1 | [8](#8-count-exists-aggregates) |
| `INSERT` + `SCOPE_IDENTITY()` | `repo.InsertAsync(e)` — id written back into `e` | 1 | [9](#9-insert) |
| `BULK INSERT` / many `INSERT`s | `repo.BulkInsertAsync(rows)` | 1 | [9](#9-insert) |
| `UPDATE t SET <all> WHERE pk` | `repo.UpdateAsync(e)` | 1 | [10](#10-update) |
| `UPDATE t SET a, b WHERE pk` | `repo.UpdateAsync(e, x => x.A, x => x.B)` **net10** | 1 | [10](#10-update) |
| `UPDATE t SET … WHERE <pred>` | `repo.UpdateWhereAsync(pred, assignments)` | 1 | [10](#10-update) |
| `DELETE FROM t WHERE pk` | `repo.DeleteAsync(e)` | 1 | [11](#11-delete) |
| `DELETE FROM t WHERE <pred>` | `repo.DeleteWhereAsync(pred)` | 1 | [11](#11-delete) |
| `BEGIN TRAN … COMMIT` | `using var uow = await data.BeginTransactionAsync()` | 1 | [12](#12-transactions-concurrency-locking-hints) |
| `WHERE … AND VERSION = @v` (concurrency) | `[DbColumn(IsRowVersion = true)]` — automatic | 1 | [12](#12-transactions-concurrency-locking-hints) |
| `WITH (NOLOCK)` | `using (data.UseDirtyReads())` | 1 | [12](#12-transactions-concurrency-locking-hints) |
| `INNER JOIN` / `LEFT JOIN` | `q.InnerJoin<TRight>("b", left, right)` | 2 | [13](#13-join-group-by-distinct--the-sqlquery-composer) |
| `GROUP BY` + `COUNT/SUM/AVG/MIN/MAX` | `.GroupBy(Cols.X)` + `.Select(Agg.Sum(…))` | 2 | [13](#13-join-group-by-distinct--the-sqlquery-composer) |
| `HAVING` | `.Having("COUNT(*) > @n", ("n", 5))` *(fragment)* | 2 | [13](#13-join-group-by-distinct--the-sqlquery-composer) |
| `SELECT DISTINCT` | `.Distinct()` | 2 | [13](#13-join-group-by-distinct--the-sqlquery-composer) |
| `IF @p IS NOT NULL` branch / `sp_executesql` | `.WhereIf(cond, col, "=", v)` | 2 | [14](#14-dynamic-where--retiring-dynamic-sql) |
| `ISNULL` / `NVL` / `COALESCE` | `Fn.Coalesce(a, b)` | 2 | [15](#15-portable-scalar-functions--fn) |
| `GETDATE()` / `SYSDATE` | `Fn.Now()` | 2 | [15](#15-portable-scalar-functions--fn) |
| `a + b` (string concat) | `Fn.Concat(a, b)` | 2 | [15](#15-portable-scalar-functions--fn) |
| `CHARINDEX` / `INSTR` / `POSITION` | `Fn.CharIndex(needle, haystack)` | 2 | [15](#15-portable-scalar-functions--fn) |
| `LEN`, `SUBSTRING`, `CAST` | `Fn.Length` / `Fn.Substring` / `Fn.Cast` | 2 | [15](#15-portable-scalar-functions--fn) |
| `WHERE c IN (SELECT …)` | two-step: read keys, then `Contains` | 1 | [16](#16-sub-queries-union-cursors-procedures) |
| `UNION ALL` | run both, concatenate in C# | 1 | [16](#16-sub-queries-union-cursors-procedures) |
| `DECLARE CURSOR` / `WHILE` fetch loop | `await foreach (var e in repo.StreamAllAsync())` **net10** | 1 | [16](#16-sub-queries-union-cursors-procedures) |
| `EXEC usp_x @a, @b OUTPUT` | `new StoredProcedureCall("usp_x").Input(…).Output(…)` | 1 | [16](#16-sub-queries-union-cursors-procedures) |
| Window fn, CTE, PIVOT, MERGE, `INSERT…SELECT`, DDL | raw SQL — by design | 3 | [17](#17-where-the-no-sql-surface-ends) |

---

## 3. The worked schema

Two tables — `ACCOUNT` and `BRANCH` — in the scaffolder's default shape (unquoted-uppercase
identifiers, `partial` class, nested `Cols` tokens). Everything below uses them.

```sql
CREATE TABLE BRANCH (
    BRANCH_ID    INT          NOT NULL PRIMARY KEY,
    BRANCH_NAME  NVARCHAR(60) NOT NULL,
    REGION       NVARCHAR(30) NULL);

CREATE TABLE ACCOUNT (
    ACCOUNT_ID   BIGINT        NOT NULL IDENTITY PRIMARY KEY,
    BRANCH_ID    INT           NOT NULL REFERENCES BRANCH(BRANCH_ID),
    ACCOUNT_NAME NVARCHAR(100) NOT NULL,
    BALANCE      DECIMAL(19,4) NOT NULL,
    STATUS       INT           NOT NULL,
    OPENED_ON    DATETIME2     NOT NULL,
    VERSION_NO   INT           NOT NULL);
```

The entity is what the scaffolder emits (`dotnet run --project TflOmniDb.Scaffold`), trimmed here:

```csharp
using TflOmniDb.Core;
using TflOmniDb.Query;      // for the nested Cols tokens

[DbTable(TableName = "ACCOUNT")]
public partial class ACCOUNT : Entity
{
    [DbColumn(ColumnName = "ACCOUNT_ID", CoreType = CoreDataType.Int64, AllowDbNull = false,
              IsPrimaryKey = true, KeyGeneration = KeyGenerationStrategy.Identity)]
    public virtual long? ACCOUNT_ID { get; set; }

    [DbColumn(ColumnName = "BRANCH_ID", CoreType = CoreDataType.Int32, AllowDbNull = false,
              IsForeignKey = true, FkTableName = "BRANCH", FkColumnName = "BRANCH_ID")]
    public virtual int? BRANCH_ID { get; set; }

    [DbColumn(ColumnName = "ACCOUNT_NAME", CoreType = CoreDataType.UnicodeString, Size = 100, AllowDbNull = false)]
    public virtual string? ACCOUNT_NAME { get; set; }

    [DbColumn(ColumnName = "BALANCE", CoreType = CoreDataType.Money, AllowDbNull = false)]
    public virtual decimal? BALANCE { get; set; }

    [DbColumn(ColumnName = "STATUS", CoreType = CoreDataType.Int32, AllowDbNull = false)]
    public virtual int? STATUS { get; set; }

    [DbColumn(ColumnName = "OPENED_ON", CoreType = CoreDataType.DateTime, AllowDbNull = false)]
    public virtual DateTime? OPENED_ON { get; set; }

    // App-managed optimistic-concurrency token — see §12.
    [DbColumn(ColumnName = "VERSION_NO", CoreType = CoreDataType.Int32, AllowDbNull = false, IsRowVersion = true)]
    public virtual int? VERSION_NO { get; set; }

    /// <summary>Strongly-typed column tokens for the SqlQuery composer.</summary>
    public static class Cols
    {
        public const string Table = "ACCOUNT";

        public static readonly Col ACCOUNT_ID   = new("ACCOUNT_ID");
        public static readonly Col BRANCH_ID    = new("BRANCH_ID");
        public static readonly Col ACCOUNT_NAME = new("ACCOUNT_NAME");
        public static readonly Col BALANCE      = new("BALANCE");
        public static readonly Col STATUS       = new("STATUS");
        public static readonly Col OPENED_ON    = new("OPENED_ON");
        public static readonly Col VERSION_NO   = new("VERSION_NO");
    }
}
```

`BRANCH` is the same shape with `BRANCH_ID` / `BRANCH_NAME` / `REGION` and its own `Cols`.

One `DataAccess` per connection string, for the life of the process:

```csharp
var data = new DataAccess(new DataAccessOptions
{
    Provider         = DbProvider.SqlServer,   // or Oracle / PostgreSql — nothing below changes
    ConnectionString = cs,
    DefaultSchema    = "dbo",
});

var repo     = data.Repository<ACCOUNT>();
var branches = data.Repository<BRANCH>();
var provider = data.Options.Provider;
```

> Entity properties are `Nullable<T>` so partial rows can materialize. That is why order-by
> selectors carry a `!` (`orderBy: x => x.BALANCE!`) and IN-lists read `x.BRANCH_ID!.Value`.

---

## 4. SELECT — whole rows

**By primary key**

```sql
SELECT * FROM ACCOUNT WHERE ACCOUNT_ID = @id;
```

```csharp
ACCOUNT? a = await repo.GetAsync(new object[] { id });   // null when no row matches
```

Composite key: pass the values in the order the key columns are declared —
`GetAsync(new object[] { orgId, accountId })`.

**All rows**

```sql
SELECT * FROM ACCOUNT;
```

```csharp
IReadOnlyList<ACCOUNT> all = await repo.GetAllAsync();
```

**Filtered rows**

```sql
SELECT * FROM ACCOUNT WHERE STATUS = 1;
```

```csharp
var open = await repo.WhereAsync(x => x.STATUS == 1);
```

**Large result set — stream instead of buffering (net10)**

```sql
-- the T-SQL habit: a cursor, or SELECT everything and loop in the app
```

```csharp
await foreach (var acct in repo.StreamWhereAsync(x => x.STATUS == 1, ct: ct))
    await ProcessAsync(acct);        // O(1) memory, one open reader
```

---

## 5. SELECT — fewer columns

**Projection on a key read / full read**

```sql
SELECT ACCOUNT_ID, ACCOUNT_NAME FROM ACCOUNT;
```

```csharp
var list = await repo.GetAllAsync(x => x.ACCOUNT_ID, x => x.ACCOUNT_NAME);
var one  = await repo.GetAsync(new object[] { id }, x => x.ACCOUNT_NAME);
```

**Projection + filter (net10)** — the column array is the second argument:

```sql
SELECT ACCOUNT_ID, BALANCE FROM ACCOUNT WHERE ACCOUNT_NAME = @n;
```

```csharp
var row = (await repo.WhereAsync(
        x => x.ACCOUNT_NAME == name,
        [x => x.BALANCE],                 // the primary key is always added back
        take: 1))
    .FirstOrDefault();
```

Rules: the primary key is always included (round-trip identity); properties outside the projection
stay at their **default** on the returned entity; each selector must be a plain property access —
a computed expression throws `ArgumentException` (use the composer, §13).

---

## 6. WHERE — the predicate cheat-sheet

Every value in a predicate — literal, captured local, closure field, IN-list item, LIKE pattern —
is bound as a `DbParameter`. Nothing is concatenated, so predicates are injection-safe by
construction.

| SQL | C# predicate |
|---|---|
| `STATUS = 1` | `x => x.STATUS == 1` |
| `STATUS <> 1` | `x => x.STATUS != 1` |
| `BALANCE > 1000` | `x => x.BALANCE > 1000m` |
| `A = 1 AND B = 2` | `x => x.A == 1 && x.B == 2` |
| `A = 1 OR B = 2` | `x => x.A == 1 \|\| x.B == 2` |
| `NOT (STATUS = 9)` | `x => !(x.STATUS == 9)` |
| `BALANCE BETWEEN 10 AND 50` | `x => x.BALANCE >= 10m && x.BALANCE <= 50m` |
| `ACCOUNT_NAME IS NULL` | `x => x.ACCOUNT_NAME == null` |
| `ACCOUNT_NAME IS NOT NULL` | `x => x.ACCOUNT_NAME != null` — or `x => x.OPENED_ON.HasValue` for a nullable value type |
| `ACCOUNT_NAME LIKE 'ACME%'` | `x => x.ACCOUNT_NAME!.StartsWith("ACME")` |
| `ACCOUNT_NAME LIKE '%ACME%'` | `x => x.ACCOUNT_NAME!.Contains("ACME")` |
| `ACCOUNT_NAME LIKE '%LTD'` | `x => x.ACCOUNT_NAME!.EndsWith("LTD")` |
| `BRANCH_ID IN (1,2,3)` | `int[] ids = [1,2,3];` → `x => ids.Contains(x.BRANCH_ID!.Value)` |
| `BRANCH_ID NOT IN (…)` | `x => !ids.Contains(x.BRANCH_ID!.Value)` |
| `BALANCE > MIN_BALANCE` (column vs column) | `x => x.BALANCE > x.MIN_BALANCE` |
| `OPENED_ON >= @from` (a variable) | `x => x.OPENED_ON >= from` — the local is captured and bound |

`Contains` / `StartsWith` / `EndsWith` **escape the LIKE metacharacters** (`%`, `_`, `[`, `]`) in
your argument, so `Contains("50%")` searches for the literal text `50%`. When you genuinely want a
caller-supplied *pattern*, use the composer's `Where(col, "LIKE", pattern)` (§13), which binds the
pattern verbatim.

Not translatable — throws `NotSupportedException`, go to §13 / §17: method calls other than the
four above (`ToUpper()`, `Substring()`, date functions), arithmetic on columns, sub-queries, and a
bare boolean column (write `x => x.IS_ACTIVE == true`, not `x => x.IS_ACTIVE`).

---

## 7. ORDER BY, TOP, paging

```sql
SELECT TOP (10) * FROM ACCOUNT WHERE STATUS = 1 ORDER BY OPENED_ON DESC;
```

```csharp
var latest = await repo.WhereAsync(
    x => x.STATUS == 1,
    orderBy:    x => x.OPENED_ON!,
    descending: true,
    take:       10);
```

```sql
-- page 3, 20 rows per page
SELECT * FROM ACCOUNT ORDER BY ACCOUNT_ID OFFSET 40 ROWS FETCH NEXT 20 ROWS ONLY;   -- SQL Server / Oracle
SELECT * FROM ACCOUNT ORDER BY ACCOUNT_ID LIMIT 20 OFFSET 40;                       -- PostgreSQL
```

```csharp
var page3 = await repo.WhereAsync(predicate: null, skip: 40, take: 20);
```

One call, three dialects: OFFSET/FETCH on SQL Server and Oracle, LIMIT/OFFSET on PostgreSQL. When
`skip` / `take` are set and no `orderBy` is given, the first primary-key column is used so paging
stays deterministic.

---

## 8. COUNT, EXISTS, aggregates

```sql
SELECT COUNT(*) FROM ACCOUNT;
SELECT COUNT(*) FROM ACCOUNT WHERE STATUS = 1;
```

```csharp
long total = await repo.CountAsync();
long open  = await repo.CountAsync(x => x.STATUS == 1);   // long — banking tables outgrow int
```

```sql
IF EXISTS (SELECT 1 FROM ACCOUNT WHERE BALANCE > 1000000) …
```

```csharp
bool any = await repo.AnyAsync(x => x.BALANCE > 1_000_000m);   // cheaper than CountAsync(...) > 0
```

**Scalar aggregates (net10)** — the write-once replacement for the legacy `Max(type, criteria)` /
`MaxPrimaryKeyValue(type)` idiom:

```sql
SELECT MAX(BALANCE) FROM ACCOUNT;
SELECT SUM(BALANCE) FROM ACCOUNT WHERE STATUS = 1;
SELECT MAX(ACCOUNT_ID) FROM ACCOUNT;
```

```csharp
decimal  max  = await repo.MaxAsync<decimal>(x => x.BALANCE);
decimal  sum  = await repo.SumAsync<decimal>(x => x.BALANCE, x => x.STATUS == 1);
long     next = await repo.MaxKeyAsync<long>();                 // single-PK entities only
decimal? none = await repo.MaxAsync<decimal?>(x => x.BALANCE);  // nullable ⇒ null when no rows match
```

`MinAsync` / `AvgAsync` complete the set. An empty result set (or an all-NULL column) yields
`default(TResult)` — ask for a **nullable** `TResult` when "no rows" must be distinguishable from a
real zero. `AVG` follows the engine's native rule: averaging an integer column truncates on SQL
Server and Oracle, so average a decimal column or cast with `Fn.Cast` in the composer.

Aggregates **grouped by a column** are §13.

---

## 9. INSERT

```sql
INSERT INTO ACCOUNT (BRANCH_ID, ACCOUNT_NAME, BALANCE, STATUS, OPENED_ON, VERSION_NO)
VALUES (@b, @n, @bal, @s, @d, 1);
SELECT SCOPE_IDENTITY();
```

```csharp
var a = new ACCOUNT
{
    BRANCH_ID = 7, ACCOUNT_NAME = "ACME LTD", BALANCE = 0m,
    STATUS = 1, OPENED_ON = DateTime.UtcNow, VERSION_NO = 1,
};
await repo.InsertAsync(a);
long id = a.ACCOUNT_ID!.Value;   // identity written straight back into the instance
```

The identity round-trip is dialect-specific under the hood (`SCOPE_IDENTITY()` /
`RETURNING … INTO :ret` / `INSERT … RETURNING`) and identical from C#.

**Many rows** — the provider's bulk path (`SqlBulkCopy` / binary `COPY` / `OracleBulkCopy`), orders
of magnitude faster than a loop above ~50 rows:

```sql
BULK INSERT ACCOUNT FROM '…';   -- or 10 000 INSERT round-trips
```

```csharp
int written = await repo.BulkInsertAsync(rows, new BulkInsertOptions { BatchSize = 5000 });
```

Bulk insert does **not** write generated identity values back into the entities, and it is excluded
from auto-retry (a partial batch can't be replayed). On Oracle it requires unquoted-uppercase table
names.

---

## 10. UPDATE

**Whole row, by primary key**

```sql
UPDATE ACCOUNT SET BRANCH_ID=@b, ACCOUNT_NAME=@n, BALANCE=@bal, STATUS=@s, OPENED_ON=@d,
                   VERSION_NO = VERSION_NO + 1
WHERE ACCOUNT_ID = @id AND VERSION_NO = @v;
```

```csharp
a.BALANCE = 500m;
int rows = await repo.UpdateAsync(a);     // every updatable column; the version is handled for you
```

**Only the columns that changed (net10)** — no prior read needed; a fresh entity carrying the key
(plus the row-version, if the entity has one) is enough:

```sql
UPDATE ACCOUNT SET STATUS = @s, VERSION_NO = VERSION_NO + 1
WHERE ACCOUNT_ID = @id AND VERSION_NO = @v;
```

```csharp
await repo.UpdateAsync(
    new ACCOUNT { ACCOUNT_ID = id, STATUS = 9, VERSION_NO = currentVersion },
    x => x.STATUS);
```

The row-version is **always** enforced on a partial update even when it isn't in the column list —
which is why the instance must carry its current value. A stale value throws `ConcurrencyException`.

**Set-based — many rows, no primary key**

```sql
UPDATE ACCOUNT SET STATUS = 9 WHERE BALANCE = 0 AND OPENED_ON < @cutoff;
```

```csharp
using System.Linq.Expressions;

int affected = await repo.UpdateWhereAsync(
    x => x.BALANCE == 0m && x.OPENED_ON < cutoff,
    new (Expression<Func<ACCOUNT, object?>>, object?)[]
    {
        (x => x.STATUS, 9),
    });
```

`repo.UpdateAsync(predicate, assignments)` is the same method under the `UpdateAsync` name.
Set-based writes carry **no** row-version semantics — they are the deliberate bulk-change tool.

> `SET BALANCE = BALANCE + @amt` (an assignment that references a column) is **not** expressible:
> the assignment value is a bound parameter, not an expression. Either read-modify-write inside a
> transaction (where the row-version protects you), or drop to `data.ExecuteNonQueryAsync` — §17.

---

## 11. DELETE

```sql
DELETE FROM ACCOUNT WHERE ACCOUNT_ID = @id;
```

```csharp
await repo.DeleteAsync(a);        // key read from the entity
```

```sql
DELETE FROM ACCOUNT WHERE STATUS = 9 AND OPENED_ON < @cutoff;
```

```csharp
int purged = await repo.DeleteWhereAsync(x => x.STATUS == 9 && x.OPENED_ON < cutoff);
```

---

## 12. Transactions, concurrency, locking hints

**Explicit transaction**

```sql
BEGIN TRAN;
    UPDATE ACCOUNT SET BALANCE = … WHERE ACCOUNT_ID = @from;
    UPDATE ACCOUNT SET BALANCE = … WHERE ACCOUNT_ID = @to;
COMMIT;
```

```csharp
using var uow = await data.BeginTransactionAsync();
var r = uow.Repository<ACCOUNT>();          // enlisted in the transaction

await r.UpdateAsync(from, x => x.BALANCE);
await r.UpdateAsync(to,   x => x.BALANCE);

await uow.CommitAsync();                    // disposing without committing rolls back
```

**Retryable transaction** — the only safe way to replay multi-statement work after a deadlock:

```csharp
await data.ExecuteInTransactionAsync(async uow =>
{
    var r = uow.Repository<ACCOUNT>();
    // …                                     make this delegate idempotent — it may run twice
});
```

**Optimistic concurrency** — there is no `WHERE VERSION = @v` to write by hand. A column marked
`IsRowVersion = true` is incremented in `SET` and checked in `WHERE` on every update; zero matched
rows throws `ConcurrencyException`. Identical on all three engines — no `ROWVERSION` / `xmin` /
`ORA_ROWSCN` divergence.

**Dirty reads**

```sql
SELECT * FROM ACCOUNT WITH (NOLOCK) WHERE STATUS = 1;
```

```csharp
using (data.UseDirtyReads())                 // WITH(NOLOCK) on SQL Server; no-op on Oracle/PG (MVCC)
{
    var rows = await repo.WhereAsync(x => x.STATUS == 1);
}
```

**Per-scope command timeout (net10)**

```csharp
using (data.UseCommandTimeout(120))          // seconds; 0 = no timeout. Nested scopes shadow + restore
{
    var slow = await repo.CountAsync();
}
```

---

## 13. JOIN, GROUP BY, DISTINCT — the `SqlQuery` composer

The typed repository deliberately generates no joins and no GROUP BY. Those live in
`TflOmniDb.Query.SqlQuery`, which builds the statement from **column tokens**: identifiers are
quoted per dialect, values are bound to auto-named parameters, `@p` becomes `:p` on Oracle, and
paging uses each engine's syntax. It never opens a connection — `ToListAsync(data)` /
`ToListAsync(uow)` hand the built statement to the same pipeline everything else uses.

**INNER JOIN + projection**

```sql
SELECT a.ACCOUNT_NAME, b.BRANCH_NAME
FROM ACCOUNT a
INNER JOIN BRANCH b ON a.BRANCH_ID = b.BRANCH_ID
WHERE a.STATUS = 1
ORDER BY a.ACCOUNT_NAME;
```

```csharp
using TflOmniDb.Query;

public sealed class AccountRow
{
    public string? ACCOUNT_NAME { get; set; }
    public string? BRANCH_NAME { get; set; }
}

var rows = await SqlQuery.From<ACCOUNT>("a", provider)
    .InnerJoin<BRANCH>("b", ACCOUNT.Cols.BRANCH_ID.As("a"), BRANCH.Cols.BRANCH_ID.As("b"))
    .SelectCols(ACCOUNT.Cols.ACCOUNT_NAME.As("a"), BRANCH.Cols.BRANCH_NAME.As("b"))
    .Where(ACCOUNT.Cols.STATUS.As("a"), "=", 1)
    .OrderBy(ACCOUNT.Cols.ACCOUNT_NAME.As("a"))
    .ToListAsync<AccountRow>(data);
```

`From<TEntity>` takes the table name from `[DbTable]`; `InnerJoin<TRight>` takes the joined table
from the right entity's `[DbTable]` and the ON clause from `Col` tokens. `LeftJoin<TRight>` is the
outer-join twin, and a composite ON is `params (Col Left, Col Right)[]`. The **first** `.As("a")`
sets the table alias; a second `.As("Name")` sets the SELECT-list output alias. Target POCOs need
no `[DbTable]`, no key and no base class — columns map to properties by name.

For a view, a derived table, or a mixed-case quoted table, the string overloads
`From(table, alias, provider)` / `InnerJoin("BRANCH b", "b.X = a.X")` stay available.

**GROUP BY + aggregates + HAVING**

```sql
SELECT a.BRANCH_ID, COUNT(*) AS Cnt, SUM(a.BALANCE) AS Total
FROM ACCOUNT a
WHERE a.STATUS = 1
GROUP BY a.BRANCH_ID
HAVING COUNT(*) > 5
ORDER BY Total DESC;
```

```csharp
public sealed class BranchTotal
{
    public int BRANCH_ID { get; set; }
    public int Cnt { get; set; }
    public decimal Total { get; set; }
}

var totals = await SqlQuery.From<ACCOUNT>("a", provider)
    .SelectCols(ACCOUNT.Cols.BRANCH_ID.As("a"))
    .Select(Agg.Count("Cnt"), Agg.Sum(ACCOUNT.Cols.BALANCE.As("a"), "Total"))
    .Where(ACCOUNT.Cols.STATUS.As("a"), "=", 1)
    .GroupBy(ACCOUNT.Cols.BRANCH_ID.As("a"))
    .Having("COUNT(*) > @n", ("n", 5))       // fragment — see the note below
    .OrderBy("Total DESC")                   // aggregate alias — fragment
    .ToListAsync<BranchTotal>(data);
```

`Agg.Count / Sum / Avg / Min / Max` render `FUNC(col) AS alias` with the column quoted per dialect
and the **alias left unquoted**, so an unquoted `ORDER BY Total DESC` matches on all three engines.

> **The two remaining fragments.** `Having(...)` and ordering by an aggregate alias take short text.
> They are still parameterized — bind values as `("n", 5)`, never concatenate — and they are the
> only text in an otherwise token-built query. The typed `Where(Col, op, value)` accepts a
> whitelisted operator only (`=  <>  <  <=  >  >=  LIKE  NOT LIKE`); anything else throws, so the
> operator can't be injected either.

**DISTINCT**

```sql
SELECT DISTINCT REGION FROM BRANCH ORDER BY REGION;
```

```csharp
var regions = await SqlQuery.From<BRANCH>("b", provider)
    .SelectCols(BRANCH.Cols.REGION.As("b"))
    .Distinct()
    .OrderBy(BRANCH.Cols.REGION.As("b"))
    .ToDictionariesAsync(data);
```

Dedup happens in the database — this replaces an in-memory `DistinctBy` over a full table read.
Under `DISTINCT`, every ORDER BY column must also be selected.

**Paging, scalars, EXISTS, streaming**

```csharp
q.Page(skip, take);                                             // OFFSET/FETCH or LIMIT/OFFSET per dialect

decimal total  = await q.ScalarAsync<decimal>(data);            // first column of the first row
bool    exists = await q.ExistsAsync(data);                     // ≥ 1 row?
await foreach (var r in q.StreamAsync<AccountRow>(data)) { }    // net10

var (sql, ps) = q.Build();                                      // inspect / log what was generated
```

`ToListAsync` and `ScalarAsync` also accept an `IUnitOfWork`, which is how a composed query joins
an open transaction. Untyped rows come back from `ToDictionariesAsync` — read them with the
`RowAccess` helpers (`row.GetDecimal("Total")`, `row.Get<int>("Cnt")`) rather than casting `object?`
by hand.

---

## 14. Dynamic WHERE — retiring dynamic SQL

The report pattern that spawns eight near-identical procedures, or an `sp_executesql` string built
at runtime:

```sql
-- the "optional filter" proc
IF @BranchId IS NULL AND @From IS NULL
    SELECT … FROM ACCOUNT
ELSE IF @BranchId IS NOT NULL AND @From IS NULL
    SELECT … FROM ACCOUNT WHERE BRANCH_ID = @BranchId
ELSE IF …

-- or the index-hostile one-liner
WHERE BRANCH_ID = ISNULL(@BranchId, BRANCH_ID)
```

```csharp
var q = SqlQuery.From<ACCOUNT>("a", provider)
    .SelectCols(ACCOUNT.Cols.ACCOUNT_ID.As("a"), ACCOUNT.Cols.BALANCE.As("a"))
    .WhereIf(branchId is not null, ACCOUNT.Cols.BRANCH_ID.As("a"), "=",  branchId)
    .WhereIf(from     is not null, ACCOUNT.Cols.OPENED_ON.As("a"), ">=", from)
    .WhereIf(minBal   is not null, ACCOUNT.Cols.BALANCE.As("a"),   ">=", minBal)
    .OrderBy(ACCOUNT.Cols.ACCOUNT_ID.As("a"))
    .Page(skip, take);

var rows = await q.ToListAsync<AccountRow>(data);
```

An unsupplied filter is **absent from the SQL** — not `col = COALESCE(@p, col)` — so the optimizer
still picks the index. This is the composer's headline feature and the single biggest lever when
porting report procedures.

When the filter varies over a *set* rather than a value, stay in layer 1:
`repo.WhereAsync(x => ids.Contains(x.BRANCH_ID!.Value))`.

---

## 15. Portable scalar functions — `Fn`

`SqlFunctions.For(provider)` (or `q.Fn` on a composer instance) renders the scalar vocabulary that
otherwise pins code to one engine. Each call returns a **SQL fragment string** you place in a
select list or predicate.

| SQL Server | Oracle | PostgreSQL | `Fn` |
|---|---|---|---|
| `ISNULL(a, b)` | `NVL(a, b)` | `COALESCE(a, b)` | `Fn.Coalesce("a", "b")` |
| `a + b` | `a \|\| b` | `a \|\| b` | `Fn.Concat("a", "b")` |
| `GETDATE()` | `SYSTIMESTAMP` | `now()` | `Fn.Now()` |
| `CHARINDEX(n, h)` | `INSTR(h, n)` | `POSITION(n IN h)` | `Fn.CharIndex("n", "h")` |
| `SUBSTRING(e,1,3)` | `SUBSTR(e,1,3)` | `SUBSTRING(e,1,3)` | `Fn.Substring("e", 1, 3)` |
| `LEN(e)` | `LENGTH(e)` | `LENGTH(e)` | `Fn.Length("e")` |
| `UPPER` / `LOWER` / `TRIM` | same | same | `Fn.Upper` / `Fn.Lower` / `Fn.Trim` |
| `CAST(e AS NVARCHAR(50))` | `CAST(e AS NVARCHAR2(50))` | `CAST(e AS VARCHAR(50))` | `Fn.Cast("e", CoreDataType.UnicodeString, size: 50)` |

```csharp
var fn = SqlFunctions.For(provider);
var label = fn.Concat(
    fn.Cast("a.ACCOUNT_NAME", CoreDataType.AnsiString, size: 100),
    "' — '",
    fn.Coalesce("b.REGION", "'n/a'"));

var labelled = await SqlQuery.From<ACCOUNT>("a", provider)
    .InnerJoin<BRANCH>("b", ACCOUNT.Cols.BRANCH_ID.As("a"), BRANCH.Cols.BRANCH_ID.As("b"))
    .Select($"{label} AS Label")
    .ToDictionariesAsync(data);
```

`Fn.CharIndex` is the one worth memorising: Oracle's `INSTR` flips the operand order, which is a
silent wrong-answer bug when a proc is ported by hand. `Fn` also gives you the case-insensitive
comparison the lambda translator can't express — `Where($"{fn.Upper("a.ACCOUNT_NAME")} = @n", ("n", v.ToUpper()))`.

---

## 16. Sub-queries, UNION, cursors, procedures

**`IN (SELECT …)` → two steps.** One extra round-trip buys a portable, index-friendly query:

```sql
SELECT * FROM ACCOUNT WHERE BRANCH_ID IN (SELECT BRANCH_ID FROM BRANCH WHERE REGION = 'EAST');
```

```csharp
var eastIds = (await branches.WhereAsync(x => x.REGION == "EAST", [x => x.BRANCH_ID]))
    .Select(b => b.BRANCH_ID!.Value)
    .ToArray();

var accounts = await repo.WhereAsync(x => eastIds.Contains(x.BRANCH_ID!.Value));
```

Watch the id-list size — a few hundred is fine, tens of thousands wants a join (§13) or raw SQL.
An `EXISTS` sub-query used purely as a filter usually becomes `InnerJoin` + `Distinct()`.

**UNION → concatenate in C#**, when the branches are really separate queries:

```sql
SELECT 'dormant' AS Bucket, COUNT(*) AS N FROM ACCOUNT WHERE STATUS = 9
UNION ALL
SELECT 'open',            COUNT(*)      FROM ACCOUNT WHERE STATUS = 1;
```

```csharp
var buckets = new[]
{
    ("dormant", await repo.CountAsync(x => x.STATUS == 9)),
    ("open",    await repo.CountAsync(x => x.STATUS == 1)),
};
```

If it must be one statement — one snapshot, one round-trip — that is raw SQL (§17).

**Cursor / `WHILE` fetch loop → streaming (net10)**

```sql
DECLARE c CURSOR FOR SELECT …; OPEN c; FETCH NEXT …; WHILE @@FETCH_STATUS = 0 …
```

```csharp
await foreach (var a in repo.StreamWhereAsync(x => x.STATUS == 1, ct: ct))
    await PostAsync(a);
```

**`EXEC` a stored procedure** — still no SQL text, just a described call:

```sql
EXEC usp_Transfer @p_from = 1001, @p_amount = 500, @p_new_balance = @bal OUTPUT;
```

```csharp
var call = new StoredProcedureCall("usp_Transfer")
    .Input("p_from", 1001)
    .Input("p_amount", 500m, CoreDataType.Money)
    .Output("p_new_balance", CoreDataType.Money)
    .ReturnValue();                                   // SQL Server / Oracle only

var r = await data.ExecuteProcedureAsync(call);       // or uow.ExecuteProcedureAsync in a transaction
decimal bal  = r.GetOutput<decimal>("p_new_balance");
var     rows = r.FirstResultSet.ToList<AccountRow>(); // RowAccess maps the raw set to a POCO
```

Parameter names go in **without** the `@` / `:` prefix, in the procedure's declared order
(PostgreSQL binds positionally). Per-engine differences — Oracle REF CURSORs, TVPs, arrays — are in
[usage-guide.md §14](usage-guide.md).

---

## 17. Where the no-SQL surface ends

These are **by design**, not gaps waiting to be filled — the DAL deliberately stops short of being
a query compiler. Each has a supported escape hatch that still gets logging, redaction, correlation
and retry.

| Shape | Why it isn't modelled | Use instead |
|---|---|---|
| Window functions (`ROW_NUMBER`, `OVER`) | dialect-divergent syntax | `data.QueryAsync<TPoco>(sql, ps)` |
| CTE / `WITH` | ditto | `data.QueryAsync<TPoco>` |
| `PIVOT` / `UNPIVOT` | SQL-Server-specific | `data.QueryAsync<TPoco>`, or pivot in C# |
| `MERGE` / upsert | no portable form | `AnyAsync` + insert/update in a transaction, or raw SQL |
| `UNION` in one statement | branch shapes are arbitrary | `data.QueryAsync` / `QueryAsync<T>` |
| `INSERT … SELECT` | crosses read and write | read + `BulkInsertAsync`, or `ExecuteNonQueryAsync` |
| `SET col = col + @x` | assignment values are bound parameters | read-modify-write in a transaction, or `ExecuteNonQueryAsync` |
| Correlated sub-query / `EXISTS` in a predicate | would require expression-tree modelling | two-step (§16), or a composer join |
| `CASE WHEN …` in the SELECT list | arbitrary expression | composer `Select("CASE … AS Bucket")` fragment |
| Function on a column in a predicate (`UPPER(NAME) = @n`) | not translatable from a lambda | composer `Where($"{fn.Upper("a.NAME")} = @n", ("n", v))` |
| DDL, temp tables, table variables | not a schema tool | `ExecuteNonQueryAsync`, or `CreateTableEmitter` / `TflOmniDbMigration` |
| Multi-row `VALUES` insert | covered better elsewhere | `BulkInsertAsync` |

The raw helpers, for reference — all parameterized, all through the normal pipeline:

```csharp
var pocos  = await data.QueryAsync<CustomerSummary>(sql, ps);   // rows → POCO by column name
var rows   = await data.QueryAsync(sql, ps);                    // untyped dictionaries
var scalar = await data.ExecuteScalarAsync<decimal>(sql, ps);
bool any   = await data.ExistsAsync(sql, ps);
int  n     = await data.ExecuteNonQueryAsync(sql, ps);          // UPDATE / INSERT / DELETE / DDL
```

Parameter keys here **do** carry the dialect prefix (`"@id"` on SQL Server / PostgreSQL, `":id"` on
Oracle), and the SQL text is yours to keep portable — that is the whole point of an escape hatch.
Quote identifiers through the dialect when the statement has to run on all three engines.

---

## 18. Gotchas

- **Nullable properties.** Entity properties are `Nullable<T>`, so `orderBy: x => x.BALANCE!` and
  `ids.Contains(x.BRANCH_ID!.Value)` need the null-forgiving `!`. Plain comparisons
  (`x.BALANCE > 100m`) don't.
- **A bare boolean column is not a predicate.** Write `x => x.IS_ACTIVE == true`.
- **LIKE arguments are escaped.** `Contains("50%")` looks for the literal `50%`. Caller-supplied
  patterns belong in the composer's `Where(col, "LIKE", pattern)`.
- **`take` without `orderBy`** silently orders by the first primary-key column. Be explicit when
  the order matters.
- **Projections leave properties at their default**, not at their stored value — never round-trip a
  projected entity through a full `UpdateAsync` (use the partial overload, §10).
- **Aggregate aliases are unquoted on purpose** so `ORDER BY Total DESC` matches across dialects;
  keep them simple identifiers.
- **Identifier casing.** The DAL always quotes, so the name in `[DbColumn]` / `Col` must match the
  catalog exactly. The scaffolder defaults to uppercase — create PostgreSQL tables with quoted
  uppercase names so they line up with Oracle's folding.
- **Oracle bulk insert** needs unquoted-uppercase tables (`OracleBulkCopy` strips quotes).
- **`SqlQuery` never opens a connection.** It builds; `DataAccess` / `IUnitOfWork` execute. Passing
  a `uow` is what puts the composed query inside your transaction.

---

## See also

- [usage-guide.md](usage-guide.md) — task-oriented recipes over the same surface
- [api-reference.md](api-reference.md) — every signature
- [StoredProcMigration.md](StoredProcMigration.md) — the proc-by-proc migration playbook this
  cookbook supports
- [Migration-from-AdDataAccessComponent.md](Migration-from-AdDataAccessComponent.md) — idiom-by-idiom
  port off the legacy DAL
- `TflOmniDb.Demo` — menu #17 `ComplexQuery` (composer vs raw, side by side), #18 `RowAccess`,
  #22 `Aggregates`, plus the filtered-query and column-projection entries
