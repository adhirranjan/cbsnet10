# TflOmniDb — API Reference

The public surface of the **net10** leg (`TflOmniDb.dll`). The Fx leg shares the same product surface minus the
net10-only additions, which are marked **net10** below.

Namespaces: `TflOmniDb.Core` · `TflOmniDb.Metadata` · `TflOmniDb.Dialect` · `TflOmniDb.Providers` ·
`TflOmniDb.Repository` · `TflOmniDb.Query` · `TflOmniDb.Scaffolding` · `TflOmniDb.Migration`.

Orientation: [../README.md](../README.md) · recipes: [usage-guide.md](usage-guide.md) · internals:
[components.md](components.md).

---

## Contents

- [Core — mapping attributes and enums](#core--mapping-attributes-and-enums)
- [`DataAccessOptions`](#dataaccessoptions)
- [`DataAccess`](#dataaccess)
- [`IRepository<T>`](#irepositoryt)
- [`IUnitOfWork`](#iunitofwork)
- [Stored procedures](#stored-procedures)
- [`SqlQuery` composer](#sqlquery-composer)
- [`RowAccess` extensions](#rowaccess-extensions)
- [Options and exception types](#options-and-exception-types)

---

## Core — mapping attributes and enums

### `[DbTable]`

| Property | Type | Notes |
|---|---|---|
| `TableName` | `string?` | DB table name. Casing matters — identifiers are always quoted. Must be identical across all three databases. Schema is **not** here; it is connection-level. |

### `[DbColumn]`

| Property | Type | Default | Notes |
|---|---|---|---|
| `ColumnName` | `string?` | — | DB column name (quoted, so casing matters) |
| `Description` | `string?` | — | Free text; carried into generated entities |
| `Ordinal` | `int` | `0` | Declaration order |
| `CoreType` | `CoreDataType` | — | Neutral type; mapped per dialect |
| `Size` | `int` | `0` | Strings / binary. **Required (> 0) for variable-length strings** — validated at descriptor build |
| `Precision`, `Scale` | `int` | `0` | Decimal / numeric |
| `AllowDbNull` | `bool` | `true` | |
| `IsPrimaryKey` | `bool` | `false` | Multiple columns ⇒ composite key, in declaration order |
| `IsUnique` | `bool` | `false` | |
| `IsReadOnly` | `bool` | `false` | Excluded from INSERT/UPDATE column lists |
| `IsComputed` | `bool` | `false` | Excluded from writes |
| `KeyGeneration` | `KeyGenerationStrategy` | `None` | |
| `SequenceName` | `string?` | — | **Required** when `KeyGeneration = Sequence` |
| `IsForeignKey`, `FkTableName`, `FkColumnName` | `bool` / `string?` | — | Documentation metadata; no constraint generation |
| `DefaultKind` | `DefaultValueKind` | `None` | |
| `DefaultLiteral` | `string?` | — | Used with `DefaultValueKind.Literal` |
| `SqlServerType`, `OracleType`, `PostgresType` | `string?` | — | Per-provider native-type escape hatch |
| `IsRowVersion` | `bool` | `false` | Optimistic-concurrency token. Integer types only. **At most one per entity** |
| `IsSensitive` | `bool` | `false` | Value redacted in command logs |

### `CoreDataType`

`Int16` · `Int32` · `Int64` · `Decimal` · `Money` (canonical `NUMERIC(19,4)` on all three) · `Single` · `Double` ·
`Boolean` · `AnsiString` · `UnicodeString` · `AnsiStringFixed` · `UnicodeStringFixed` · `Date` · `Time` ·
`DateTime` · `DateTimeOffset` · `Clob` · `NClob` · `Blob` · `Binary` · `BinaryFixed` · `Guid` · `Xml`

Per-engine native mappings: see the `datatype-mapping-*` references in this folder.

### `KeyGenerationStrategy`

| Value | Meaning |
|---|---|
| `None` | No generation |
| `Identity` | DB-generated on insert; value written back (`SCOPE_IDENTITY()` / `RETURNING` / identity column) |
| `Sequence` | From a named sequence — `SequenceName` required |
| `Assigned` | Caller supplies the key |

### `DefaultValueKind`

`None` · `Literal` · `CurrentTimestamp` · `CurrentDate` · `NewGuid` · `Zero` · `EmptyString` · `True`

### `Entity`

Base class for all mapped entities. Parameterless-constructible (`where T : Entity, new()`).

### `DbProvider`

`SqlServer` · `Oracle` · `PostgreSql`

---

## `DataAccessOptions`

Constructor-time configuration for one `DataAccess` instance.

| Member | Type | Default | Notes |
|---|---|---|---|
| `Provider` | `DbProvider` | — | **`required init`** |
| `ConnectionString` | `string` | — | **`required init`** |
| `DefaultSchema` | `string?` | `"dbo"` | Connection-level, not per table |
| `CommandTimeoutSeconds` | `int?` | `null` | `null` ⇒ provider default. Server-side timeout |
| `Retry` | `RetryOptions?` | `null` | `null` ⇒ retry disabled |
| `LoggerFactory` | `ILoggerFactory?` | `null` | `null` ⇒ `NullLogger`, everything swallowed |
| `LoggingEnabled` | `bool` | `true` | Per-instance switch |
| `LogParameterValues` | `bool` | `false` | **Off by default** — banking data is sensitive |
| `MutationLogLevel` | `LogLevel` | `Information` | INSERT / UPDATE / DELETE / raw writes |
| `QueryLogLevel` | `LogLevel` | `Debug` | Reads |
| `GloballyEnabled` | `static bool` | `true` | Process-wide kill switch for logging |

`DataAccessOptionsBuilder` binds these from configuration by key prefix.

---

## `DataAccess`

The connection-level entry point. One instance per connection string; typically a singleton.

```csharp
public DataAccess(DataAccessOptions options)
public DataAccessOptions Options { get; }
```

### Repositories and transactions

| Member | Signature |
|---|---|
| `Repository<T>` | `Repository<T> Repository<T>() where T : Entity, new()` |
| `BeginTransactionAsync` | `Task<IUnitOfWork> BeginTransactionAsync(…)` |
| `OpenConnectionAsync` | `Task<DbConnection> OpenConnectionAsync(CancellationToken = default)` |
| `ExecuteInTransactionAsync` | `Task ExecuteInTransactionAsync(Func<IUnitOfWork, Task>)` |
| `ExecuteInTransactionAsync<T>` | `Task<T> ExecuteInTransactionAsync<T>(Func<IUnitOfWork, Task<T>>)` |

`ExecuteInTransactionAsync` is the **only retry-safe way to replay multi-statement work**: each attempt rolls
back, reopens a fresh connection and transaction, and runs the delegate again — so the delegate must be idempotent.

### Raw SQL (non-entity)

| Member | Returns |
|---|---|
| `QueryAsync<TResult>(sql, parameters?, ct)` | `IReadOnlyList<TResult>` — plain POCOs mapped by column→property name (case-insensitive; `[DbColumn(ColumnName=…)]` honoured as an alias). No `[DbTable]`, PK or `Entity` base required |
| `QueryAsync(sql, parameters?, ct)` | `IReadOnlyList<IReadOnlyDictionary<string, object?>>` — untyped rows |
| `ExecuteScalarAsync<TScalar>(sql, parameters?, ct)` | `TScalar?` — first column of first row, coerced |
| `ExistsAsync(sql, parameters?, ct)` | `bool` — true when the SQL yields ≥ 1 row |
| `ExecuteNonQueryAsync(sql, parameters?, ct)` | `int` rows affected — UPDATE / INSERT / DELETE / DDL |
| `StreamQueryAsync<TResult>(sql, parameters?, ct)` **net10** | `IAsyncEnumerable<TResult>` |
| `StreamQueryAsync(sql, parameters?, ct)` **net10** | `IAsyncEnumerable<IReadOnlyDictionary<string, object?>>` |

Parameter keys include the dialect prefix (`"@id"` on SQL Server / PostgreSQL, `":id"` on Oracle). **The SQL text
is the caller's responsibility** — this is the documented escape hatch.

### Bulk copy (non-generic)

```csharp
Task<int> BulkCopyAsync(string schema, string table,
                        IReadOnlyList<MigrationColumn> columns,
                        IEnumerable<object?[]> rows,
                        BulkInsertOptions? options = null, …)
```

The runtime-column entry point behind the migration tool; the typed equivalent is `IRepository<T>.BulkInsertAsync`.

### Stored procedures

| Member | Returns |
|---|---|
| `ExecuteProcedureAsync(call, ct)` | `StoredProcedureResult` |
| `ExecuteScalarProcedureAsync(call, ct)` | `object?` |
| `ExecuteNonQueryProcedureAsync(call, ct)` | `int` rows affected |

### Ambient scopes

All return `IDisposable`; scopes nest, shadow, and restore on dispose (`AsyncLocal`, so they follow the async flow).

| Member | Effect |
|---|---|
| `SuppressLogging()` / `EnableLogging()` | Override `LoggingEnabled` for the scope |
| `PushCorrelation(string correlationId)` | Stamps a correlation id on every command logged in the scope |
| `UseDirtyReads()` | `WITH(NOLOCK)` on SQL Server SELECTs; no-op on Oracle / PostgreSQL (MVCC) |
| `UseCommandTimeout(int seconds)` **net10** | Overrides `CommandTimeoutSeconds` for CRUD, filtered reads, aggregates, raw SQL and procedures in the scope. `0` = no timeout. Bulk insert keeps its own `BulkInsertOptions.TimeoutSeconds` |

---

## `IRepository<T>`

`where T : Entity, new()`. Async only — no sync overloads. Obtain from `data.Repository<T>()` (own connection per
call) or `uow.Repository<T>()` (enlisted in the transaction).

### Reads

```csharp
Task<T?>                GetAsync(object[] keys, CancellationToken ct = default);
Task<T?>                GetAsync(object[] keys, params Expression<Func<T, object?>>[] columns);
Task<IReadOnlyList<T>>  GetAllAsync(CancellationToken ct = default);
Task<IReadOnlyList<T>>  GetAllAsync(params Expression<Func<T, object?>>[] columns);

Task<IReadOnlyList<T>>  WhereAsync(Expression<Func<T, bool>>? predicate = null,
                                   Expression<Func<T, object>>? orderBy = null,
                                   bool descending = false, int? skip = null, int? take = null,
                                   CancellationToken ct = default);

Task<IReadOnlyList<T>>  WhereAsync(Expression<Func<T, bool>> predicate,          // net10 — projected
                                   Expression<Func<T, object?>>[] columns,
                                   Expression<Func<T, object>>? orderBy = null,
                                   bool descending = false, int? skip = null, int? take = null,
                                   CancellationToken ct = default);

Task<long>              CountAsync(Expression<Func<T, bool>>? predicate = null, CancellationToken ct = default);
Task<IReadOnlyList<T>>  QueryAsync(string sql, IDictionary<string, object?>? parameters = null, CancellationToken ct = default);
```

- **Keys** are passed in declaration order. `GetAsync` returns `null` when no row matches.
- **Projections** always include the primary key for round-trip identity; unprojected properties stay at their
  default. Each selector must be a **simple property access** — computed expressions throw `ArgumentException`.
- **Predicate shapes supported**: binary comparisons, boolean composition, null checks, `string.Contains` /
  `StartsWith` / `EndsWith`, `collection.Contains(x.Prop)`, member access on the entity, captured locals. Anything
  else throws `NotSupportedException`.
- **Paging**: when `skip`/`take` is set and `orderBy` is omitted, ordering defaults to the first PK column for
  determinism. SQL Server 2012+ / Oracle 12c+ use OFFSET-FETCH; PostgreSQL uses LIMIT-OFFSET.
- `CountAsync` returns `long` — banking tables outgrow `int`.

### Writes

```csharp
Task    InsertAsync(T entity, CancellationToken ct = default);
Task<int> UpdateAsync(T entity, CancellationToken ct = default);                                  // all updatable columns
Task<int> UpdateAsync(T entity, params Expression<Func<T, object?>>[] columns);                   // net10 — partial
Task<int> UpdateAsync(Expression<Func<T, bool>> predicate,                                        // net10 — set-based alias
                      IReadOnlyList<(Expression<Func<T, object?>> Column, object? Value)> assignments,
                      CancellationToken ct = default);
Task<int> UpdateWhereAsync(Expression<Func<T, bool>> predicate,                                   // net10 — canonical
                      IReadOnlyList<(Expression<Func<T, object?>> Column, object? Value)> assignments,
                      CancellationToken ct = default);
Task<int> DeleteAsync(T entity, CancellationToken ct = default);
Task<int> DeleteWhereAsync(Expression<Func<T, bool>> predicate, CancellationToken ct = default);  // net10
Task<int> BulkInsertAsync(IReadOnlyList<T> entities, BulkInsertOptions? options = null, CancellationToken ct = default);
```

- `InsertAsync` writes a DB-generated identity back into the entity instance.
- **Partial update**: no prior read needed — PK plus the changed columns is enough. A PK / read-only / computed
  selector, or an empty list, throws `ArgumentException`. **Row-version is always enforced** even when not listed,
  so the entity must carry the current version; a stale value throws `ConcurrencyException`.
- **Set-based update/delete**: no PK and **no row-version semantics**. Use for predicate-driven bulk changes.
- `BulkInsertAsync` limitations: identities are **not** round-tripped; row-version columns are inserted verbatim;
  Oracle bulk requires unquoted-uppercase table names (OCI direct path strips quotes). Enlists in the transaction
  when called on a transaction-attached repository.

### Scalar aggregates — **net10**

```csharp
Task<TResult?> MaxAsync<TResult>(Expression<Func<T, object?>> column, Expression<Func<T, bool>>? predicate = null, …);
Task<TResult?> MinAsync<TResult>(…);
Task<TResult?> SumAsync<TResult>(…);
Task<TResult?> AvgAsync<TResult>(…);
Task<TResult?> MaxKeyAsync<TResult>(CancellationToken ct = default);
Task<bool>     AnyAsync(Expression<Func<T, bool>>? predicate = null, CancellationToken ct = default);
```

- Empty set / all-NULL ⇒ `default(TResult)`. Use a **nullable** `TResult` to distinguish "no rows" from a real
  zero.
- `SUM` of an `int` column stays `int` on SQL Server — pick a wide `TResult` to avoid overflow. `AVG` follows the
  engine's native rule (integer column ⇒ truncated integer on SQL Server and Oracle).
- `MaxKeyAsync` requires exactly one PK column; composite or keyless throws `InvalidOperationException`.
- `AnyAsync` emits the portable `SELECT 1 … [WHERE]` form, not `EXISTS(…)` — cheaper than `CountAsync(…) > 0`.

### Streaming — **net10**

```csharp
IAsyncEnumerable<T> StreamAllAsync(CancellationToken ct = default);
IAsyncEnumerable<T> StreamWhereAsync(Expression<Func<T, bool>> predicate, Expression<Func<T, object>>? orderBy = null,
                                     bool descending = false, int? skip = null, int? take = null, CancellationToken ct = default);
IAsyncEnumerable<T> StreamQueryAsync(string sql, IReadOnlyDictionary<string, object?>? parameters = null, CancellationToken ct = default);
IAsyncEnumerable<T> StreamProcedureAsync(StoredProcedureCall call, CancellationToken ct = default);
```

Backed by one open reader; the connection stays open for the enumeration. Pair with `await foreach` so disposal is
deterministic. Mid-stream cancellation works via `[EnumeratorCancellation]`. `StreamProcedureAsync` surfaces only
the **first** result set — no OUT params, no further sets.

---

## `IUnitOfWork`

Returned by `DataAccess.BeginTransactionAsync()`. Disposing **without** `CommitAsync` rolls back.

```csharp
Repository<T> Repository<T>() where T : Entity, new();

Task<StoredProcedureResult> ExecuteProcedureAsync(StoredProcedureCall call, CancellationToken ct = default);
Task<object?>               ExecuteScalarProcedureAsync(StoredProcedureCall call, CancellationToken ct = default);
Task<int>                   ExecuteNonQueryProcedureAsync(StoredProcedureCall call, CancellationToken ct = default);

Task<IReadOnlyList<TResult>> QueryAsync<TResult>(string sql, IReadOnlyDictionary<string, object?>? parameters = null, CancellationToken ct = default) where TResult : new();
Task<IReadOnlyList<IReadOnlyDictionary<string, object?>>> QueryAsync(string sql, …);
Task<TScalar?> ExecuteScalarAsync<TScalar>(string sql, …);
Task<bool>     ExistsAsync(string sql, …);
Task<int>      ExecuteNonQueryAsync(string sql, …);

Task CommitAsync(CancellationToken ct = default);
Task RollbackAsync(CancellationToken ct = default);
```

A single command enlisted in an open transaction is **excluded from auto-retry** — replaying one statement inside
a live transaction is unsafe. Use `DataAccess.ExecuteInTransactionAsync` to retry the whole unit.

---

## Stored procedures

### `StoredProcedureCall` — fluent builder

```csharp
public StoredProcedureCall(string procedureName, string? schema = null)
public string  ProcedureName { get; }
public string? Schema        { get; }

StoredProcedureCall Input(string name, object? value, CoreDataType? type = null, int? size = null, bool sensitive = false);
StoredProcedureCall Output(string name, CoreDataType type, int? size = null, int? precision = null, int? scale = null);
StoredProcedureCall InputOutput(string name, object? value, CoreDataType type, int? size = null, int? precision = null, int? scale = null, bool sensitive = false);
StoredProcedureCall ReturnValue(string name = "RETURN_VALUE");
StoredProcedureCall Cursor(string name);                                    // Oracle REF CURSOR
StoredProcedureCall Table(string name, object tableOrArray, string? typeName = null);
```

- Pass parameter names **without** the `@` / `:` prefix — the DAL adds the provider's.
- List parameters in the procedure's declared order (**PostgreSQL binds positionally**).
- `sensitive: true` redacts the value in command logs, exactly like `[DbColumn(IsSensitive = true)]`.
- Schema-qualified names are dialect-quoted, so an unquoted-uppercase Oracle procedure must be named in
  UPPERCASE: `new StoredProcedureCall("PR_G_AUTHENTICATEUSER")`.

### `StoredProcedureResult`

| Member | Meaning |
|---|---|
| `ResultSets` | All result sets, raw/untyped by design |
| `FirstResultSet` | Convenience for the common single-set case |
| `GetOutput<T>(name)` | OUT / INOUT value by name (prefix stripped) |
| `ReturnValue` | `int?` — SQL Server RETURN / Oracle function result. **PostgreSQL: not supported** |

`StoredProcResultSet` carries `ColumnNames` + `Rows` (`object?[]`) and `AsDictionaries()`. Mapping to types is
yours to do — or use the [`RowAccess`](#rowaccess-extensions) helpers.

### Provider capability matrix

| Feature | SQL Server | Oracle | PostgreSQL |
|---|---|---|---|
| Invocation | `CommandType.StoredProcedure` | same + `BindByName = true` | Npgsql `CALL` |
| Multiple result sets | inline SELECTs | OUT **REF CURSOR** — add `.Cursor("c")` | via OUT/INOUT, not result sets |
| Return value | `.ReturnValue()` | function result via `.ReturnValue()` | **throws `NotSupportedException`** |
| Collection parameter | **TVP** `.Table(name, dataTable, "dbo.Type")` (pre-created TABLE TYPE) | **PL/SQL associative array** `.Table(name, array)` | **native array** `.Table(name, array)` |

Parameter `DbType` binding is provider-aware: `CoreDataType.DateTime` folds to `DbType.DateTime` on Oracle (whose
managed provider rejects `DateTime2`), while SQL Server and PostgreSQL keep full-precision `DateTime2`.

---

## `SqlQuery` composer

Namespace `TflOmniDb.Query`. Generates SQL + bound parameters and **delegates to the raw-SQL pipeline** — logging,
retry, redaction, correlation and `UseDirtyReads` all keep working. It never opens connections or owns
transactions. Not an ORM and not a query compiler: it does not parse SQL, build expression trees, auto-quote
string fragments, or model window functions / CTEs / PIVOT.

### Construction

```csharp
static SqlQuery From(string table, string alias, DbProvider provider);
static SqlQuery From<TEntity>(string alias, DbProvider provider) where TEntity : Entity;   // table from [DbTable]
static SqlQuery FromRaw(string fromBody, DbProvider provider);
DbProvider   Provider { get; }
SqlFunctions Fn       { get; }
```

### Clauses — string fragments

```csharp
SqlQuery Select(params string[] exprs);
SqlQuery InnerJoin(string tableAlias, string on);
SqlQuery LeftJoin(string tableAlias, string on);
SqlQuery Where(string predicate, params (string name, object? value)[] ps);
SqlQuery WhereIf(bool condition, string predicate, params (string name, object? value)[] ps);
SqlQuery GroupBy(params string[] cols);
SqlQuery Having(string predicate, params (string name, object? value)[] ps);
SqlQuery OrderBy(params string[] cols);
SqlQuery Distinct();
SqlQuery Page(int? skip, int? take);
```

`WhereIf` is the headline: conditional predicate composition that replaces both the "eight near-identical
branches" report pattern and runtime dynamic-SQL string building — and stays index-friendly, unlike
`col = COALESCE(@p, col)`. Placeholders use the neutral `@name` prefix; `Build()` rewrites to the dialect prefix
(`@`→`:` on Oracle) and de-duplicates reused names. **Fragments pass through verbatim — bind values as
parameters, never concatenate them.**

### Clauses — typed tokens (refactor-safe, auto-quoted)

```csharp
SqlQuery SelectCols(params Col[] cols);
SqlQuery Select(params Agg[] aggs);
SqlQuery GroupBy(params Col[] cols);
SqlQuery OrderBy(Col col, bool descending = false);
SqlQuery Where(Col col, string op, object? value);
SqlQuery WhereIf(bool condition, Col col, string op, object? value);
SqlQuery InnerJoin<TRight>(string alias, Col left, Col right) where TRight : Entity;
SqlQuery InnerJoin<TRight>(string alias, params (Col Left, Col Right)[] on) where TRight : Entity;
SqlQuery LeftJoin<TRight>(string alias, Col left, Col right) where TRight : Entity;
SqlQuery LeftJoin<TRight>(string alias, params (Col Left, Col Right)[] on) where TRight : Entity;
```

`Col` is a column name + optional alias (`.As("a")` for joins); `Agg` renders `COUNT/SUM/AVG/MIN/MAX(col) AS
alias`. Operators in typed `Where` are whitelisted and the value is bound to an auto-named, letter-leading
parameter (so Oracle accepts it). Identifiers are dialect-quoted; aggregate output aliases are left unquoted so an
unquoted `OrderBy("alias")` matches across dialects. The scaffolder emits a nested `Cols` class per entity
(`B_ACCOUNT.Cols.ACCOUNT_ID`) so columns are compile-checked. Tokens are structs over strings — no expression-tree
or GC overhead.

### `SqlFunctions` (alias `SqlQuery.Fn`)

`SqlFunctions.For(provider)` returns the cross-dialect scalar vocabulary — each method produces a SQL **text
fragment** rendered per dialect:

| Method | SQL Server | Oracle | PostgreSQL |
|---|---|---|---|
| `Coalesce` | `COALESCE` (replaces `ISNULL` / `NVL`) | | |
| `Concat` | `+` | `\|\|` | `\|\|` |
| `Now` | `SYSDATETIME()` | `SYSTIMESTAMP` | `now()` |
| `CharIndex` | `CHARINDEX` | `INSTR` | `POSITION` — operand-order flip hidden |
| `Length` | `LEN` | `LENGTH` | `LENGTH` |
| `Substring`, `Upper`, `Lower`, `Trim`, `Cast(expr, CoreDataType, …)` | rendered per dialect | | |

### Execution

```csharp
(string Sql, IReadOnlyDictionary<string, object?> Parameters) Build();

Task<IReadOnlyList<T>> ToListAsync<T>(DataAccess data, CancellationToken ct = default) where T : new();
Task<IReadOnlyList<T>> ToListAsync<T>(IUnitOfWork uow, CancellationToken ct = default) where T : new();
Task<IReadOnlyList<IReadOnlyDictionary<string, object?>>> ToDictionariesAsync(DataAccess data, …);
Task<TScalar?>         ScalarAsync<TScalar>(DataAccess data, …);
Task<TScalar?>         ScalarAsync<TScalar>(IUnitOfWork uow, …);
Task<bool>             ExistsAsync(DataAccess data, …);
IAsyncEnumerable<T>    StreamAsync<T>(DataAccess data, …) where T : new();      // net10
```

---

## `RowAccess` extensions

Namespace `TflOmniDb.Repository`. Null-safe accessors for the DAL's **untyped** row shapes — what
`DataAccess.QueryAsync(sql)` returns and what `StoredProcResultSet.AsDictionaries()` produces. Typed paths
(`QueryAsync<T>`, `GetAsync`, `GetAllAsync`) already return entities and need none of this.

**On a row (`IReadOnlyDictionary<string, object?>`):**

| Member | Behaviour |
|---|---|
| `Get<T>(col)` | Coerced value; `default` when the column is missing or SQL NULL (`Get<int>` → `0`, `Get<int?>` → `null`) |
| `GetAs<T>(col)` | Reference cast (`as T`) for `byte[]` / `string`, where `ChangeType` would throw |
| `TryGet<T>(col, out value)` | |
| `HasColumn(col)` / `IsNull(col)` | |
| `GetString` / `GetInt32` / `GetInt64` / `GetDecimal` / `GetDouble` / `GetBoolean` / `GetDateTime` / `GetGuid` / `GetBytes` | Nullable, each with a `(col, fallback)` non-null overload |

**On `StoredProcResultSet` (null-safe receiver — works directly on `result.FirstResultSet`):**

`Get<T>(rowIndex, col)` · `Get<T>(col)` (row 0) · `GetAs<T>(…)` · `Row(rowIndex)` / `FirstRow()` (→ a row dict to
chain the typed getters) · `ToList<T>()` / `First<T>()` / `FirstOrDefault<T>()` (map rows to a POCO). The same
three mapping helpers exist on `StoredProcedureResult` over `FirstResultSet`.

Coercion is the shared `PocoMaterializer.Coerce`: enum, `Guid`, `Nullable<T>` unwrap, culture-invariant
`Convert.ChangeType`.

---

## Options and exception types

### `RetryOptions`

| Member | Default | Notes |
|---|---|---|
| `MaxAttempts` | `3` | Total tries, not extra tries |
| `BaseDelay` | `200 ms` | Exponential: `min(MaxDelay, BaseDelay × 2^(n-1))` |
| `MaxDelay` | `5 s` | |
| `RetryOnTimeout` | `false` | **Leave off for write paths** — a timed-out non-idempotent write may have committed |
| `UseJitter` | `true` | Full jitter |

Each retry logs a Warning. Auto-retry covers the **owned-connection** path only: single CRUD, `WhereAsync` /
`CountAsync` / `QueryAsync`, aggregates, and stored-procedure calls. **Excluded**: a single command inside an open
transaction, bulk insert (a partial batch or PG binary `COPY` cannot resume), and streaming (rows already yielded).

`IProviderRuntime.IsTransient(ex, includeTimeouts)` classifies per engine — SQL Server by `SqlException.Number`
(deadlock 1205, transport/Azure-transient set, timeout −2 gated), Oracle by `OracleException.Number` (deadlock 60,
transport set, 25408 safe-replay, 12170/1013 gated), PostgreSQL by `PostgresException.SqlState` (40P01, 40001,
57P0x, 08xxx; 08007 gated) plus bare `NpgsqlException`.

### `BulkInsertOptions` (`init`-only)

| Member | Notes |
|---|---|
| `BatchSize` | `int?` |
| `TimeoutSeconds` | `int?` — independent of `UseCommandTimeout` |
| `KeepIdentities` | `bool` |
| `EnableTableLock` | `bool` — SQL Server only |
| `FireTriggers` | `bool` — SQL Server only |

### Exceptions

| Type | Raised when |
|---|---|
| `ConcurrencyException` | An UPDATE/DELETE guarded by `IsRowVersion` matched zero rows |
| `MetadataValidationException` | Descriptor build failed — e.g. `Size` missing on a variable-length string, `SequenceName` missing for `KeyGeneration.Sequence`, more than one `IsRowVersion` |
| `NotSupportedException` | Unsupported predicate shape; unsupported provider capability (e.g. PostgreSQL return value) |
| `ArgumentException` | A projection / column selector that is not a simple property access; empty partial-update column list; PK / read-only / computed column in a partial update |
| `InvalidOperationException` | `MaxKeyAsync` on a composite-key or keyless entity |
