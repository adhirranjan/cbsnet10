# TflOmniDb — Components & Internal Architecture

How the library is put together, what each layer owns, what is cached, and where the extension points are.
Written for someone about to change the library rather than call it — callers want
[usage-guide.md](usage-guide.md).

---

## 1. Layer map

```
        ┌──────────────────────────────────────────────────────────────────┐
        │  Query/          SqlQuery · SqlFunctions (Fn) · Col · Agg        │  composition
        └───────────────┬──────────────────────────────────────────────────┘
                        │ generates (sql, parameters), delegates down
        ┌───────────────▼──────────────────────────────────────────────────┐
        │  Repository/    DataAccess · Repository<T> · UnitOfWork          │  execution
        │                 StoredProcedure* · RawQueryExecutor              │
        │                 RetryExecutor · CommandLogger · RowAccess        │
        └───────┬───────────────────────┬──────────────────────┬───────────┘
                │ needs SQL             │ needs a connection   │ needs values
        ┌───────▼─────────┐   ┌─────────▼──────────┐   ┌───────▼───────────┐
        │  Sql/           │   │  Providers/        │   │  Metadata/        │
        │  SqlGenerator   │   │  IProviderRuntime  │   │  EntityDescriptor │
        │  ExpressionTr.  │   │  ProviderRegistry  │   │  ColumnDescriptor │
        └───────┬─────────┘   └─────────┬──────────┘   └───────┬───────────┘
                │ per dialect           │ per engine           │ from attributes
        ┌───────▼───────────────────────▼──────────────────────▼───────────┐
        │  Dialect/  ISqlDialect + SqlServer/Oracle/Postgres + TypeMappers │
        ├──────────────────────────────────────────────────────────────────┤
        │  Core/     Entity · [DbTable] · [DbColumn] · CoreDataType · enums │
        └──────────────────────────────────────────────────────────────────┘

  Scaffolding/  and  Migration/  sit beside this stack and reuse it
  (schema reading, reverse type mapping, raw SQL, bulk copy).
```

---

## 2. What each layer owns

### `Core/` — the vocabulary

`Entity` base, `[DbTable]` / `[DbColumn]`, and the neutral enums `CoreDataType`, `KeyGenerationStrategy`,
`DefaultValueKind`. Provider-neutral by design: nothing here knows what a `NVARCHAR2` is. Per-provider overrides
exist as optional strings on the column attribute (`SqlServerType` / `OracleType` / `PostgresType`) — the escape
hatch when the neutral type is not precise enough.

Two flags carry behaviour rather than shape: `IsRowVersion` (optimistic-concurrency token) and `IsSensitive`
(redact in logs).

### `Metadata/` — attributes → descriptors, once

`MetadataReader.For<T>()` reflects over the type and builds an `EntityDescriptor` (table, key columns, updatable
columns, row-version binding) with a `ColumnDescriptor` per property. **Reflection runs once per `Type` and is
cached for the AppDomain lifetime.**

Validation is fail-fast at descriptor build, not at execution: `Size > 0` for variable-length strings,
`SequenceName` present for `KeyGeneration.Sequence`, at most one `IsRowVersion`. A bad entity therefore throws
`MetadataValidationException` the first time it is touched, not on some later edge-case row.

`ColumnDescriptor.SetValue` owns the read-side coercion — `DBNull` handling and width promotion (e.g. `int` →
`decimal?`), which is why entity properties are nullable.

### `Dialect/` — how each engine spells things

`ISqlDialect` plus three implementations:

| | Quoting | Parameter prefix | Identity return |
|---|---|---|---|
| `SqlServerDialect` | `[name]` | `@p0` | `SCOPE_IDENTITY()` |
| `OracleDialect` | `"name"` | `:p0` | `RETURNING … INTO :ret` |
| `PostgresDialect` | `"name"` | `@p0` | `INSERT … RETURNING` |

Each ships a sibling `*TypeMapper` translating `CoreDataType` to native types. **Identifiers are always quoted** —
that is what preserves casing on Oracle and PostgreSQL, and it is why table/column names must match exactly across
the three databases.

### `Sql/` — statement generation

`SqlGenerator` produces a `StatementSet` (SELECT-by-key, SELECT-all, INSERT, UPDATE, DELETE) per
**(descriptor, dialect, schema, dirty-reads)** and caches it in a `ConcurrentDictionary`. Non-cached builders exist
where the shape varies per call: `BuildSelectWhere`, `BuildCount`, `BuildAggregate`, `BuildUpdatePartial`.

`ExpressionTranslator` converts LINQ predicates to parameterised WHERE clauses. Its supported shapes are a
deliberate whitelist — binary comparisons, boolean composition, null checks, the three `string` methods,
`collection.Contains`, entity member access, captured locals. Anything else throws `NotSupportedException` rather
than guessing. Every constant, closure value and IN-list item is appended via `AppendParameter`; LIKE patterns
escape `%`, `_`, `[`, `]` before binding.

`ColumnSelector` unwraps the compiler-inserted `Convert(...)` around boxed value-type property access, so
`x => x.Id` works when `Id` is `long?`. `EntityDataReader` adapts a `IReadOnlyList<T>` to `IDataReader` for
`SqlBulkCopy`.

### `Providers/` — per-engine runtime

`IProviderRuntime` is the seam: create connection/command, bind parameters, run the bulk-copy fast path, and
classify exceptions via `IsTransient(ex, includeTimeouts)`. `ProviderRegistry` dispatches through a
`FrozenDictionary<DbProvider, IProviderRuntime>` built once at static init (a switch on the Fx leg — same external
behaviour).

`IBulkColumn` (`ColumnName` + `ClrType`) is a small internal seam implemented by both `ColumnDescriptor` and
`MigrationColumn`, so one provider bulk-insert path serves both the typed `Repository<T>` and the runtime
migration path.

### `Repository/` — execution

The largest folder, and the only one callers touch directly.

| Piece | Role |
|---|---|
| `DataAccess` | Connection-level entry point. Owns options, repositories, transactions, raw SQL, procedures, and the ambient scopes |
| `Repository<T>` | Typed CRUD, filtered reads, projections, aggregates, bulk insert, streaming |
| `UnitOfWork` / `IUnitOfWork` | An open connection + transaction; hands out attached repositories |
| `RawQueryExecutor` | The non-entity SQL path (`QueryAsync`, scalar, exists, non-query, streaming) |
| `StoredProcedureCall` / `Binder` / `Executor` / `Result` / `ResultSet` | The procedure stack — fluent description, provider-aware binding, one `do/while NextResult` loop covering all three engines |
| `RetryExecutor` | Exponential backoff with optional full jitter, driven by `IsTransient` |
| `CommandLogger` / `CommandLogging` | Command pairing, correlation id, timing, redaction |
| `PocoMaterializer` | Column→property mapping and `Coerce` (enum, `Guid`, `Nullable<T>` unwrap, invariant `ChangeType`) — shared by `QueryAsync<T>`, `RowAccess` and `ToList<T>()` |
| `RowAccess` | Null-safe extension accessors over untyped rows and result sets |
| `ConcurrencyException`, `DataAccessOptions(Builder)`, `RetryOptions`, `BulkInsertOptions`, `CoreTypeDbType` | Supporting types |

**Ambient scopes** (`UseDirtyReads`, `UseCommandTimeout`, `PushCorrelation`, `SuppressLogging` / `EnableLogging`)
are `AsyncLocal`-based, so they follow the async flow, nest, shadow and restore on dispose. Timeout precedence is
centralised in `DataAccess.ResolveCommandTimeout`; all three executors' `ApplyTimeout` defer to it — the single
place to change if the precedence rule ever moves.

### `Query/` — composition

`SqlQuery`, `SqlFunctions` (`Fn`), and the `Col` / `Agg` tokens. This layer **only generates text and parameters**
and then calls the raw-SQL helpers — it never opens a connection, owns a transaction, parses SQL, or builds an
expression tree. That is what keeps logging, retry, redaction, correlation and dirty-reads working through it for
free. Tokens are structs over strings: no allocation or GC pressure.

### `Scaffolding/` and `Migration/`

Both are library code with thin console/web front-ends, so the logic is testable without a UI.

- **Scaffolding** — two acquisition modes (live catalog read vs air-gapped script/dump) converge on one
  provider-neutral `SchemaModel`, so the generator is written once. Reverse type mappers invert the dialect
  `*TypeMapper`s. The connected reader and the dump parser are asserted **byte-identical** by integration tests
  (run the live script, parse it, compare).
- **Migration** — `MigrationFacade` splits into `PrepareAsync` (read schema, map columns, emit DDL, count source
  rows, **no writes** — this powers the dry-run preview) and `ExecuteAsync` (apply exists-behaviour, create,
  bulk-copy, verify count). `CreateTableEmitter` is the general-purpose CREATE TABLE generator the library
  previously lacked.

---

## 3. Life of a call

**`repo.GetAsync([42])`**

1. `Repository<T>` asks `MetadataReader.For<T>()` → cached `EntityDescriptor`.
2. Asks `SqlGenerator.For(descriptor, dialect, schema, dirtyReads)` → cached `StatementSet`; takes `SelectByKey`.
3. `ProviderRegistry` → the engine's `IProviderRuntime`; opens an owned connection (or reuses the unit of work's).
4. Key values bound as `DbParameter`s.
5. `CommandLogger` records the command (redacting sensitive values) at `QueryLogLevel`.
6. Executed inside `RetryExecutor` **if** `Retry` is set and this is the owned-connection path.
7. Row materialised via `ColumnDescriptor.SetValue` per column; connection returned to the pool.

**`repo.WhereAsync(x => x.BALANCE > min, take: 20)`** — same, except step 2 calls `BuildSelectWhere`, which is
**not** cached (predicates are dynamic) and costs ~10–50 μs, and `ExpressionTranslator` binds `min` as a parameter
by walking the closure.

**`data.QueryAsync<T>(sql, pars)`** — skips metadata and generation entirely: `RawQueryExecutor` binds the
dictionary, logs, retries if eligible, and hands rows to `PocoMaterializer`.

---

## 4. Caching

| Cached | Key | Lifetime |
|---|---|---|
| `EntityDescriptor` | `Type` | AppDomain |
| `StatementSet` | (descriptor, dialect, schema, dirty-reads) | AppDomain |
| `IProviderRuntime` | `DbProvider` | Static init (`FrozenDictionary`) |

**Recomputed per call:** `WhereAsync` / `CountAsync` / aggregate / partial-update SQL (dynamic shapes), and closure
values inside predicates (~5 μs via `ExpressionTranslator.TryEvaluate`'s manual walk for the common shapes —
literals, captured-local field/property chains, `Convert` wrappers — falling back to
`Expression.Lambda(...).Compile().DynamicInvoke()` only when the fast path cannot resolve it).

Measured by `TflOmniDb.Benchmarks`: `MetadataBenchmarks` (cold vs warm), `SqlGenerationBenchmarks` (cached lookup
vs per-call `BuildSelectWhere` / `BuildCount`).

---

## 5. Deliberate non-goals

Each of these is a decision, not a backlog item:

| Not implemented | Why |
|---|---|
| Joins / GROUP BY / sub-query generation | Prevents cartesian explosions and unreadable generated SQL. Raw SQL or `SqlQuery` instead |
| Navigation properties, lazy loading | The N+1 source. Absent by construction |
| Change tracking, identity map | The repository is stateless; each call constructs fresh entities |
| Materialisation proxies | `PropertyInfo.SetValue` writes directly |
| Fluent / convention-based mapping | Every persisted column declares a `[DbColumn]`; mapping is greppable |
| Sync overloads | Async-first, no sync-over-async traps |
| `EXISTS` / `.Any()` inside `WhereAsync` | Would require sub-query generation |
| DB-native row versioning (`ROWVERSION`, `xmin`, `ORA_ROWSCN`) | App-managed integer works identically on all three engines |

---

## 6. Extension points

| To add… | Touch |
|---|---|
| A new provider | `DbProvider`, a `ISqlDialect` + `*TypeMapper`, an `IProviderRuntime` (incl. `IsTransient` and the bulk path), register in `ProviderRegistry`; a reverse type mapper + `CatalogSql` + script emitter if it should scaffold |
| A new `CoreDataType` | The enum, all three `*TypeMapper`s, all three reverse mappers, `CoreTypeDbType.Map`, and the `datatype-mapping-*` reference docs |
| A new predicate shape | `ExpressionTranslator` — and add a per-dialect unit test; the whitelist is the safety property |
| A new statement kind | `SqlGenerator` (decide cached vs per-call), the dialect if the syntax differs, then `Repository<T>` |
| A new scalar function in `Fn` | `SqlFunctions` with a rendering per dialect + `QueryComposerTests` |
| A new transient error code | The provider runtime's `IsTransient` list; verify with `RetryExecutor`'s fake-predicate tests |

**Standing rule for any of these:** every feature ships with a **test and a demo** — update `TflOmniDb.Tests`
(unit + live-3-DB as appropriate) *and* add or extend a `TflOmniDb.Demo/Demos/*` entry wired into `Program.cs`.
And do not touch the frozen `TflOmniDbFx*` projects.

---

## 7. Test topology

| Suite | Covers |
|---|---|
| Unit (no DB) | Dialect rendering, SQL generation per dialect, expression translation, metadata validation, retry loop with a fake transient predicate, composer rendering (`QueryComposerTests`), aggregates (`AggregateSqlTests`), timeout scopes (`CommandTimeoutScopeTests`), scaffolder emitters/parsers, migration emitter + column factory + config binder |
| Live integration | CRUD, transactions, concurrency, redaction, filtered queries + paging, dirty-read hints, bulk insert, projections, procedures (multi-set, OUT/INOUT, return value, TVP/array), raw-SQL complex queries, streaming, partial/set-based updates, aggregates, command timeout — run against SQL Server, PostgreSQL and Oracle |
| `SqlInjectionTests` | 8 tests per leg: malicious payloads across all three dialects |
| Benchmarks | Metadata cache, SQL generation, streaming vs buffered, bulk vs loop |

Net10: 521 tests. Fx: 332. Connection strings resolve env-var-first (`TFLOMNIDB_*_CONN`), then the test project's
`App.config`.

---

## 8. Known gaps

Net-new work if requested — confirm the shape before extending contracts:

- Schema diff / DDL generation from descriptors (`CreateTableEmitter` covers only the migration case: no indexes,
  FKs, check constraints or computed columns).
- Audit-column auto-population (`CreatedBy` / `CreatedOn` / …) via an ambient `ICurrentUser`.
- Explicit `DbType` / provider-specific precision on parameter binding.
- DB-native row-version support.
- Bulk insert with identity round-trip.
- Oracle bulk insert against mixed-case quoted tables (an `OracleBulkCopy` / OCI limitation).
- **net10 only:** source generators replacing `MetadataReader` reflection for zero-reflection startup and native
  AOT. The code is already shaped for it — a generator would replace `MetadataReader.For<T>()` with
  `Metadata<T>.Descriptor` constants. (`IsAotCompatible` / `IsTrimmable` are already set on the library csproj, so
  unsafe-for-AOT reflection surfaces as analyzer warnings today.)

**Type mappings exercised live:** SQL Server `BIGINT / NVARCHAR / NUMERIC / DATETIME2`; PostgreSQL
`BIGINT / VARCHAR / CHAR / NUMERIC / TIMESTAMP`; Oracle `NUMBER(19,0) / NUMBER(10,0) / NVARCHAR2 / CHAR(n CHAR) /
TIMESTAMP`. **Not yet exercised** (no entity uses them): `JSONB`, `BYTEA`, `UUID`, `TIMESTAMPTZ`, `XML` on
PostgreSQL; `INTERVAL`, `TIMESTAMP WITH TIME ZONE`, `XMLTYPE`, native `JSON` on Oracle.
