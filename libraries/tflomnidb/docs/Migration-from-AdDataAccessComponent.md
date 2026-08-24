# AdDataAccessComponent → TflOmniDb — Feature Comparison & Migration Guide

`TflOmniDb` is the modern reimplementation of the legacy VB.NET data-access
component **`AdDataAccessComponent`**
(`_Archive\Ad.ProjectLibrary\AdDataAccessComponent\AdDataAccessComponent`).

This document compares the two so a team migrating off the old component knows:

1. **What carries over** (present in both)
2. **What is gone / changed** (legacy idioms with no 1:1 — with pros, cons, and a verdict)
3. **How each old idiom is expressed** in the new API (code mapping)
4. **What is net-new** in TflOmniDb

> Read sections in order, or jump to the **idiom → equivalent** table in §3 if you
> just need the porting cheat-sheet.

---

## 0. At a glance

| | **AdDataAccessComponent** (legacy) | **TflOmniDb** (new) |
|---|---|---|
| Language | VB.NET | C# (net10 leg) + VB output for the scaffolder |
| Runtime | .NET Framework (EntLib 5.0) | .NET 10 (`TflOmniDb`) **and** net48 (`TflOmniDbFx`) |
| Engine | Microsoft Enterprise Library 5.0 Data Block + EntLibContrib (Oracle) | Hand-written dialect layer over `Microsoft.Data.SqlClient` / `Npgsql` / `Oracle.ManagedDataAccess` |
| API shape | **Static methods** on `AdDataAccessComponent` (`Shared`) | **Instance** `DataAccess` + `IRepository<T>` + `IUnitOfWork` |
| Sync/async | **Synchronous only** | **Async-only** (`*Async`, no sync overloads) |
| Providers | **SQL Server, Oracle** (2 client flavors) | **SQL Server, Oracle, PostgreSQL** |
| Entity model | `AdEntity` base + `AdDbColumnInfoAttribute`; **table = class name** | `Entity` base + `[DbTable]` + `[DbColumn]`; table name explicit |
| Result shape | `DataTable` / `DataSet` / `DataRow` / `List(Of entity)` (reflection) | Strongly-typed `T` / `IReadOnlyList<T>` / `IAsyncEnumerable<T>` / dictionaries |
| Filtering | **Raw string `criteria`** WHERE clause | **LINQ predicate** `Expression<Func<T,bool>>` (parameterized) + raw-SQL escape hatch |
| Dependencies | EntLib 5.0, EntLibContrib, `Tssipl.Practices` | Modern ADO.NET providers + `M.E.Logging.Abstractions` |
| Tests | `AdDataAccessComponentTest` (manual) | 521 (net10) / 332 (fx) live + unit tests, 3 live DBs |

**Legacy public surface** (all `Shared` on `AdDataAccessComponent`):
`Insert` · `Update` · `Delete` · `Truncate` · `Retrieve` · `RetrieveByKey` ·
`RetrieveDataTable` · `RetrieveDataRowByKey` · `Select` · `Count` · `Max` ·
`Min` · `MaxPrimaryKeyValue` · `Execute` (SP→DataSet) · `ExecuteNonQuery` /
`ExecuteNonQuerySP` · `ToListOfEntity` / `ToEntity` / `ToDataTable`, plus the
support types `AdConnectionInfo`, `AdDataAccessOptions`, `TransactionManager`.

---

## 1. What is there in BOTH (carried over, modernized)

| Capability | Legacy | TflOmniDb |
|---|---|---|
| Insert single row | `Insert(entity[, newId])` | `repo.InsertAsync(entity)` (generated identity written back into the entity) |
| Update by PK | `Update(entity)` | `repo.UpdateAsync(entity)` |
| Update by criteria | `Update(entity, criteria)` | `repo.UpdateWhereAsync(pred, assignments)` |
| Delete by PK | `Delete(entity)` | `repo.DeleteAsync(entity)` |
| Delete by criteria | `Delete(entity, criteria)` | `repo.DeleteWhereAsync(pred)` |
| Get by key | `RetrieveByKey(type, id)` | `repo.GetAsync(new object[] { id })` |
| Get all / filtered list | `Retrieve(type[, criteria])` | `repo.GetAllAsync()` / `repo.WhereAsync(pred, …)` |
| Count | `Count(type[, criteria])` | `repo.CountAsync([pred])` |
| Truncate | `Truncate(type)` | raw `data.ExecuteNonQueryAsync("TRUNCATE …")` |
| Raw SQL → rows | `Select(query)` → `DataSet` | `data.QueryAsync<T>(sql)` / `QueryAsync(sql)` / `StreamQueryAsync` |
| Stored procedure | `Execute(spName, dict)` → `DataSet` | `data.ExecuteProcedureAsync(StoredProcedureCall)` |
| SP non-query | `ExecuteNonQuerySP` | `data.ExecuteNonQueryProcedureAsync` |
| Transactions | `TransactionManager` / pass `DbTransaction` | `using uow = await data.BeginTransactionAsync()` |
| Per-column metadata | `AdDbColumnInfoAttribute` | `[DbColumn]` (richer) |
| Configurable timeout | `AdDataAccessOptions.CommandTimeout` (per-call) | `DataAccessOptions.CommandTimeoutSeconds` (per-instance) + `data.UseCommandTimeout(n)` ambient scope (per-call) |
| Connection by name/string | `AdConnectionInfo` | `DataAccessOptions.ConnectionString` + `Provider` |
| SQL Server + Oracle | yes | yes (+ PostgreSQL) |
| Identity / Oracle sequence | `scope_identity()` + `<table>_seq` convention | dialect `SCOPE_IDENTITY()` / `RETURNING` / `KeyGenerationStrategy.Sequence` |

---

## 2. What is MISSING / changed (legacy idioms with no 1:1 in TflOmniDb)

Each item lists what changed, the **pro**, the **con**, and a **Verdict — who wins
and why**.

> **Scorecard: TflOmniDb wins 9, legacy "wins" 0, situational 1.**
> *(#5 closed — typed `MaxAsync`/`MinAsync`/`SumAsync`/`AvgAsync`/`MaxKeyAsync`/`AnyAsync` now ship.)*

### 1. Static-method facade → instance `DataAccess` + `Repository<T>`
- **Pro:** testable/mockable (`IRepository<T>`), DI-friendly, per-instance config; no hidden global state.
- **Con:** every call site changes; callers must obtain/inject a `DataAccess`.
- **Verdict — TflOmniDb wins.** Testability + no global state outweigh a one-time, mechanical call-site edit.

### 2. Synchronous API → async-only (`*Async`)
- **Pro:** non-blocking I/O, scales under load, first-class cancellation.
- **Con:** forces `async`/`await` up the chain; blocking with `.GetAwaiter().GetResult()` risks deadlock.
- **Verdict — TflOmniDb wins** for any server/web workload (the target here). *Legacy is only simpler for a throwaway sync console app* — not this product.

### 3. `DataTable`/`DataSet`/`DataRow` shapes → typed `T` / dict rows
(`RetrieveDataTable`, `RetrieveDataRowByKey`, `Select`→`DataSet`, `ToDataTable`, `ToListOfEntity`, `ToEntity` removed.)
- **Pro:** compile-time typed results, lower memory, no `DataTable` overhead; dictionaries + `RowAccess` cover the untyped case.
- **Con:** grid/`DataSet`-bound code must be rewritten; no drop-in `DataTable` return.
- **Verdict — Situational.** TflOmniDb wins on safety/perf/clarity, **but legacy wins for legacy UI** that data-binds straight to `DataTable`/`DataSet` — those call sites carry real rewrite cost and are the main migration friction.

### 4. Raw-string `criteria` WHERE → parameterized LINQ predicates
(Legacy concatenates `where {criteria}` / `{pk} = {id}` directly — a SQL-injection vector.)
- **Pro:** injection-safe (everything bound), compile-checked columns, provider-portable.
- **Con:** handwritten SQL fragments must be re-expressed; exotic SQL drops to the raw escape hatch.
- **Verdict — TflOmniDb wins decisively.** The legacy string-concat path is an active SQL-injection hole; safety is non-negotiable in a banking DAL.

### 5. `Max`/`Min`/`MaxPrimaryKeyValue` helpers → typed `repo.MaxAsync(col)` (+ raw scalar / `SqlQuery` `Agg`)
- **Pro:** thin typed aggregate helpers now exist on `IRepository<T>` —
  `MaxAsync` / `MinAsync` / `SumAsync` / `AvgAsync` / `MaxKeyAsync` (the
  `MaxPrimaryKeyValue` shortcut) / `AnyAsync`, each with an optional LINQ
  predicate (the `Max(type, "criteria")` form). Built on the same
  `ExpressionTranslator` + dialect-quoting as `CountAsync`, so they're
  injection-safe and provider-portable; the general raw-scalar / `SqlQuery` `Agg`
  path remains for any aggregate the helpers don't cover.
- **Con:** none material — the one-liner gap is closed.
- **Verdict — TflOmniDb wins (gap closed).** Was the one mild legacy ergonomic
  edge; the typed helpers match the terse legacy call (`repo.MaxAsync<decimal>(x => x.Bal, x => x.Status == 1)`)
  while staying parameterized. See the **Scalar aggregates** section in `CLAUDE.md`.

### 6. Table name = class name → explicit `[DbTable("NAME")]`
- **Pro:** decouples C# class name from DB table; rename either side independently.
- **Con:** every entity must be re-annotated.
- **Verdict — TflOmniDb wins.** Explicit mapping avoids breakage when a class is renamed/refactored; the re-annotation cost is absorbed by the scaffolder.

### 7. `AdDbColumnInfoAttribute` FK/ordinal/unique/precision metadata not carried
(`IsForeignKey`/`FkColumnName`/`FkTableName`, `ColumnOrdinal`, `IsUnique`, `NumericPrecision/Scale`, `ColumnDescription`, `ProviderSpecificDataType`.)
- **Pro:** leaner attribute focused on what the DAL actually uses; adds `IsRowVersion` (concurrency) + `IsSensitive` (security) instead.
- **Con:** code/tools reading FK/ordinal/unique metadata off the attribute lose it.
- **Verdict — TflOmniDb wins** for the DAL's job (it never used FK/ordinal at runtime). *Legacy wins only if you used the attribute as a schema-metadata catalog* — rare; move that to the scaffolder's schema model.

### 8. `System.Data.OracleClient` legacy client dropped → `Oracle.ManagedDataAccess` only
- **Pro:** supported, managed (no native OCI install), modern Oracle features.
- **Con:** environments pinned to the old unmanaged client must switch drivers.
- **Verdict — TflOmniDb wins.** `System.Data.OracleClient` is Microsoft-deprecated; staying on it was already a liability.

### 9. EntLib auto `DiscoverParameters` for SPs → explicit `StoredProcedureCall` params
- **Pro:** removes a per-call metadata round-trip; explicit, fast, uniform across all 3 providers.
- **Con:** caller declares each parameter (name/type/direction) in order — more upfront code.
- **Verdict — TflOmniDb wins on correctness/perf** (no hidden round-trip, no reliance on `DiscoverParameters` quirks). *Legacy wins purely on brevity* for quick, low-volume SP calls.

### 10. Implicit EntLib config → explicit `DataAccessOptions` / `appsettings.json`
(`ConfigManager.ConnectionStringName` / `CommandTimeOut` DAAB section gone.)
- **Pro:** no EntLib/DAAB dependency; modern config + env-var resolution; explicit per-instance connection.
- **Con:** existing `app.config` DAAB sections must be migrated.
- **Verdict — TflOmniDb wins.** Dropping the EntLib dependency is a core goal of the rewrite; config migration is one-time.

> **Note:** the legacy `TransactionManager.Rollback()` actually calls `Commit()` (a
> real bug). TflOmniDb's `IUnitOfWork` rolls back correctly on
> dispose-without-commit — a behavioral fix, not just a rename.

**Bottom line:** TflOmniDb is the stronger component on every axis that matters for a
multi-provider banking DAL (safety, async scale, testability, supported drivers). With
#5 closed (typed aggregate helpers now ship), the only remaining places the legacy idiom
is *more convenient* are direct `DataTable` UI binding (#3) and one-line SP calls (#9) —
neither a capability gap.

---

## 3. How each AdDataAccessComponent idiom is achieved in TflOmniDb

**Setup once:**

```csharp
var data = new DataAccess(new DataAccessOptions
{
    Provider = DbProvider.SqlServer,
    ConnectionString = cs,
    DefaultSchema = "dbo",
});
var repo = data.Repository<Account>();
```

| Legacy call | TflOmniDb equivalent |
|---|---|
| `Insert(acct, newId)` | `await repo.InsertAsync(acct);` *(generated PK written back into `acct`)* |
| `Update(acct)` | `await repo.UpdateAsync(acct);` |
| `Update(acct, "STATUS=1")` (criteria) | `await repo.UpdateWhereAsync(x => x.Status == 1, [ (x => x.Col, val) ]);` |
| partial-column update | `await repo.UpdateAsync(acct, x => x.Name);` *(net10 partial-column)* |
| `Delete(acct)` | `await repo.DeleteAsync(acct);` |
| `Delete(acct, "AGE>90")` | `await repo.DeleteWhereAsync(x => x.Age > 90);` |
| `RetrieveByKey(GetType(Account), id)` | `var a = await repo.GetAsync(new object[] { id });` |
| `Retrieve(GetType(Account))` | `var all = await repo.GetAllAsync();` |
| `Retrieve(type, "BAL>100")` | `var rows = await repo.WhereAsync(x => x.Bal > 100);` |
| `Count(type, "BAL>100")` | `await repo.CountAsync(x => x.Bal > 100);` |
| `Max(type, "BAL")` | `await repo.MaxAsync<decimal>(x => x.Bal);` *(+ optional predicate; `MinAsync`/`SumAsync`/`AvgAsync` too)*. Raw `data.ExecuteScalarAsync<decimal>("SELECT MAX(\"BAL\") FROM …")` / `SqlQuery…Select(Agg.Max(col))` stay for other aggregates |
| `Max(type, "BAL", "STATUS=1")` | `await repo.MaxAsync<decimal>(x => x.Bal, x => x.Status == 1);` *(parameterized predicate)* |
| `MaxPrimaryKeyValue(type)` | `await repo.MaxKeyAsync<long>();` *(single-PK shortcut)* |
| `Count(type) > 0` / existence | `await repo.AnyAsync(x => x.Status == 1);` *(short-circuits; cheaper than `CountAsync(...) > 0`)* |
| `Truncate(type)` | `await data.ExecuteNonQueryAsync("TRUNCATE TABLE …");` |
| `Select("SELECT …")` → `DataSet` | `await data.QueryAsync<Poco>(sql, pars)` (typed) or `QueryAsync(sql, pars)` (dict rows) |
| read into `DataTable` / loop rows | `QueryAsync(...)` + `row.GetString("COL")` / `row.GetInt32(...)` (`RowAccess`) |
| `Execute(spName, dict)` → `DataSet` + OUT back | `var r = await data.ExecuteProcedureAsync(new StoredProcedureCall(sp).Input(...).Output(...)); r.GetOutput<T>(name); r.FirstResultSet;` |
| `ExecuteNonQuerySP(options)` | `await data.ExecuteNonQueryProcedureAsync(call);` |
| `Dim tx = tm.BeginTran(ci)` … pass `tx` | `using var uow = await data.BeginTransactionAsync(); var r = uow.Repository<T>(); … await uow.CommitAsync();` |
| `AdConnectionInfo("Name")` (config conn) | `DataAccessOptions { ConnectionString = …, Provider = … }` from `appsettings.json` |
| `<AdDbColumnInfo(IsPrimaryKey:=True, DbType:=…)>` | `[DbColumn("ID", IsPrimaryKey = true, …)]` |
| entity class `Account` (table = name) | `[DbTable("ACCOUNT")] public class Account : Entity { … }` *(scaffolder generates)* |

**Re-annotating entities.** The legacy `AdEntity` + `AdDbColumnInfoAttribute` classes
can be regenerated automatically by **`TflOmniDb.Scaffold`** (reverse-engineers a live
DB or a pasted schema dump into `[DbTable]`/`[DbColumn]` entities, C# or VB). This is
the recommended path rather than hand-porting each entity.

**Identity round-trip preserved.** Legacy `Insert(entity, ByRef newId)` →
`InsertAsync` writes the generated key back into the entity (so the `newId` pattern
maps cleanly). For Oracle, the legacy `<table>_seq` convention maps to
`[DbColumn(KeyGeneration = KeyGenerationStrategy.Sequence, SequenceName = "…")]`.

### 3a. `AdDataAccessOptions` → split by concern (no god-options bag)

Legacy `AdDataAccessOptions` was a single mutable bag carrying **everything** a call
might need — `Entity` / `EntityType`, `Criteria`, `PkValue`, `Query`, `ColumnName`,
`StoredProcedureName` + `StoredProcedureParamList`, `ConnectionInfo`, `Transaction`,
`CommandTimeout`, and the `NewPkValue` out-param — and the same class was reused by
`Insert` / `Update` / `Delete` / `Select` / `Count` / `Max` / `Execute`. TflOmniDb has
**no equivalent single object**; it decomposes the bag along its real seams:

| `AdDataAccessOptions` field | Where it lives in TflOmniDb |
|---|---|
| `ConnectionInfo`, `CommandTimeout` (durable, per-connection config) | `DataAccessOptions` (built once, passed to `new DataAccess(...)`) |
| `Entity` / `EntityType` | the `Repository<T>` type parameter + the entity argument |
| `Criteria` (string WHERE) | a typed `Expression<Func<T,bool>>` predicate argument |
| `PkValue` | `repo.GetAsync(new object[] { id })` key argument |
| `Query` (raw SQL) | the `sql` argument to `QueryAsync` / `ExecuteNonQueryAsync` |
| `ColumnName` (for `Max`/`Min`) | the `x => x.Col` selector on `MaxAsync` / `MinAsync` |
| `StoredProcedureName` + `StoredProcedureParamList` | a fluent `StoredProcedureCall` (in) + `StoredProcedureResult` (out) |
| `Transaction` | an `IUnitOfWork` from `BeginTransactionAsync` (not a field you pass) |
| `NewPkValue` (out) | written back into the entity by `InsertAsync` |
| (bulk-copy tuning) | `BulkInsertOptions` |

The net effect: **durable config is set once** on `DataAccessOptions`; **per-call inputs
are strongly-typed method arguments** instead of properties poked onto a shared bag.

### 3b. `CommandTimeout` → `DataAccessOptions.CommandTimeoutSeconds`

> Full treatment (legacy mechanics, precedence, worked examples):
> [CommandTimeout-and-AdDataAccessOptions.md](CommandTimeout-and-AdDataAccessOptions.md)

```csharp
var data = new DataAccess(new DataAccessOptions
{
    Provider = DbProvider.SqlServer,
    ConnectionString = cs,
    CommandTimeoutSeconds = 60,   // legacy AdDataAccessOptions.CommandTimeout = 60
});
```

- **Applied to every command** the DAL issues — CRUD (`Repository.ApplyTimeout`),
  raw SQL (`RawQueryExecutor`), and stored procedures (`StoredProcedureExecutor`) all
  set `DbCommand.CommandTimeout` from this value. `null` ⇒ the provider default (30 s on
  SqlClient).
- **Bindable from config** instead of the EntLib `ConfigManager.CommandTimeOut`: the
  key `TflOmniDb:CommandTimeoutSeconds` in `appsettings.json` is read by
  `DataAccessOptionsBuilder`.
- **Bulk insert** has its own knob — `BulkInsertOptions.TimeoutSeconds` — because the
  bulk-copy APIs use a separate `BulkCopyTimeout`.
- **Per-call override (`UseCommandTimeout`):** the instance `CommandTimeoutSeconds` is
  connection-level (one setting covers every operation, like `DefaultSchema` / `Retry` /
  logging), but the legacy **per-call** timeout maps directly onto an ambient scope —
  `data.UseCommandTimeout(seconds)` (mirrors `UseDirtyReads()`):

  ```csharp
  using (data.UseCommandTimeout(300))      // 5 min, just this block
      await data.QueryAsync<Summary>(heavyReportSql);   // reverts on dispose
  ```

  It overrides the instance value for CRUD, filtered reads, scalar aggregates, raw SQL,
  and stored procedures inside the scope (async-flow-local; nested scopes shadow then
  restore; `0` = no timeout). This is the **server-side** command timeout, distinct from a
  client-side `CancellationToken` deadline — every async method also takes a `CancellationToken`,
  so `new CancellationTokenSource(timeout).Token` gives a per-call client cancel when that's what
  you want. Constructing a second `DataAccess` still works for durable two-tier configs; bulk
  insert keeps its own `BulkInsertOptions.TimeoutSeconds`.

---

## 4. What is EXTRA in TflOmniDb (net-new, no legacy equivalent)

**Provider & platform**
- **PostgreSQL** support (3rd engine); dual runtime legs (net10 + net48).
- Hand-written dialect layer (no EntLib dependency) with per-provider type mappers.

**Query / read**
- **LINQ predicates** with full parameterization + LIKE-escaping + a SQL-injection test suite.
- **Filtered paging & ordering** (`WhereAsync(pred, orderBy, descending, skip, take)`).
- **Column projection** on `GetAsync` / `GetAllAsync` / `WhereAsync` (read only the needed columns).
- **`IAsyncEnumerable<T>` streaming** reads (`StreamAllAsync` / `StreamWhereAsync` / `StreamQueryAsync`) — net10.
- **Raw-SQL helpers**: typed `QueryAsync<T>` (POCO mapping), untyped dict rows, `ExecuteScalarAsync<T>`, `ExistsAsync`, `ExecuteNonQueryAsync`.
- **Typed scalar aggregates** (net10): `MaxAsync` / `MinAsync` / `MaxKeyAsync` reach parity with legacy `Max` / `Min` / `MaxPrimaryKeyValue`; **`SumAsync` / `AvgAsync` / `AnyAsync` are net-new** (legacy had no SUM/AVG/EXISTS helper) — each with an optional parameterized predicate.
- **`Fn` + `SqlQuery` composer** — cross-dialect function vocabulary + fluent SELECT/JOIN/WHERE/`WhereIf`/GROUP BY/HAVING/paging with typed `Col`/`Agg` tokens.
- **`RowAccess`** null-safe typed accessors for untyped rows / SP result sets.

**Write / safety**
- **Bulk insert** fast path (`SqlBulkCopy` / Npgsql binary COPY / `OracleBulkCopy`).
- **Set-based & partial-column updates** (`UpdateWhereAsync`, `UpdateAsync(entity, cols)`).
- **Optimistic concurrency** via an `IsRowVersion` integer token → `ConcurrencyException`.
- **Transient-fault retry / resiliency** (`RetryOptions`, `ExecuteInTransactionAsync`).
- **`UseDirtyReads()`** scope (`WITH(NOLOCK)` on SQL Server; no-op on MVCC engines).
- **`UseCommandTimeout(seconds)`** scope (net10) — per-operation server-side timeout override
  (async-flow-local, mirrors `UseDirtyReads`); restores the legacy per-call timeout ergonomics
  on top of the connection-level `CommandTimeoutSeconds`.
- **Sensitive-column redaction** (`IsSensitive`) in command logs.

**Stored procedures (richer than legacy `Execute`)**
- Typed OUT/INOUT/return-value, multiple result sets, Oracle REF CURSOR, TVP /
  PL/SQL assoc array / PG native array params, provider-aware `DbType` binding,
  `StreamProcedureAsync` (net10).

**Tooling**
- **`TflOmniDb.Scaffold`** (CLI + Web UI) — reverse-engineer schema → entities (the migration accelerator for legacy `AdEntity` classes).
- **`TflOmniDbMigration`** — cross-provider single-table structure/data copy.
- **`TflOmniDb.Benchmarks`** — BenchmarkDotNet perf suite.

**Engineering**
- Structured logging (`CommandLogger`, correlation ids), descriptor/SQL caching,
  records / `required init` / `FrozenDictionary` / NRT / AOT-trim flags (net10),
  521/332 live-verified tests across 3 engines.
