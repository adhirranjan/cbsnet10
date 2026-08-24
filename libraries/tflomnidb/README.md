# TflOmniDb

**Provider-agnostic data-access layer for banking applications.** One attribute-mapped entity model, one
repository API, three engines — **SQL Server, Oracle, PostgreSQL** — with every value bound as a parameter and
no ORM machinery to surprise you.

| Leg | Projects | TFM | Status |
|---|---|---|---|
| **Net10** (active) | `TflOmniDb*` | `net10.0` | 521 / 521 live tests green. Adds streaming, partial/set-based updates, scalar aggregates, per-scope command timeout |
| **Fx** (frozen) | `TflOmniDbFx*` | `net48` | 332 / 332 live tests green. Production-shipped; **do not modify** |

Both legs are verified end-to-end against live SQL Server, PostgreSQL and Oracle instances. They are independent
assemblies (`TflOmniDb.dll` / `TflOmniDbFx.dll`) sharing one solution. The outer folder name
(`AdDataAccessComponent`) is historical and does not match the namespaces.

> **New work targets the Net10 leg only.** The Fx projects are frozen — no features, no fixes, no mirroring —
> unless explicitly requested.

---

## Contents

- [Why this exists](#why-this-exists)
- [Quick start](#quick-start)
- [Referencing the library](#referencing-the-library)
- [Feature map](#feature-map)
- [Components](#components)
- [Tooling](#tooling)
- [Design rules you should know before writing code](#design-rules-you-should-know-before-writing-code)
- [Security guarantees](#security-guarantees)
- [Performance](#performance)
- [Build & test](#build--test)
- [Documentation index](#documentation-index)

---

## Why this exists

The product must run on whichever engine the customer bank already owns. That forces one requirement above all
others: **the same C# has to work on SQL Server, Oracle and PostgreSQL**, without per-engine branches scattered
through the business layer.

TflOmniDb solves that with a deliberately small surface:

- **Attribute-mapped entities.** `[DbTable]` / `[DbColumn]` on plain classes. No fluent configuration, no
  convention magic, no migrations engine.
- **A neutral type system.** `CoreDataType` maps to each engine's native type through a per-dialect type mapper,
  with per-provider escape hatches on the column attribute.
- **Generated, cached, parameterised SQL.** `SqlGenerator` builds the statement set per (entity, dialect, schema)
  once; `ExpressionTranslator` turns LINQ predicates into bound WHERE clauses.
- **An explicit escape hatch.** Joins, GROUP BY, sub-queries and CTEs are *not* generated — you drop to raw SQL or
  the `SqlQuery` composer. This is the design, not a gap: it is what prevents N+1 and cartesian explosions.

What it deliberately is **not**: an ORM. No change tracking, no lazy loading, no navigation properties, no
identity map, no migrations.

---

## Quick start

```csharp
using TflOmniDb.Core;
using TflOmniDb.Providers;
using TflOmniDb.Repository;

// 1 ── the entity: attributes only, properties virtual and nullable
[DbTable(TableName = "WIDGET")]
public class Widget : Entity
{
    [DbColumn(ColumnName = "ID", CoreType = CoreDataType.Int64,
              IsPrimaryKey = true, KeyGeneration = KeyGenerationStrategy.Identity)]
    public virtual long? Id { get; set; }

    [DbColumn(ColumnName = "NAME", CoreType = CoreDataType.UnicodeString, Size = 100)]
    public virtual string? Name { get; set; }

    [DbColumn(ColumnName = "PRICE", CoreType = CoreDataType.Money)]
    public virtual decimal? Price { get; set; }

    [DbColumn(ColumnName = "ROWVER", CoreType = CoreDataType.Int32, IsRowVersion = true)]
    public virtual int? RowVer { get; set; }
}

// 2 ── one DataAccess per connection, typically a singleton
var data = new DataAccess(new DataAccessOptions
{
    Provider         = DbProvider.SqlServer,     // required
    ConnectionString = connectionString,          // required
    DefaultSchema    = "dbo",
});

// 3 ── CRUD
var repo = data.Repository<Widget>();

var w = new Widget { Name = "Sprocket", Price = 49.95m, RowVer = 0 };
await repo.InsertAsync(w);                        // identity written back into w.Id

w.Price = 39.95m;
await repo.UpdateAsync(w);                        // row-version checked + incremented

Widget? found  = await repo.GetAsync([w.Id!]);
var      cheap = await repo.WhereAsync(x => x.Price < 50m, orderBy: x => x.Name!, take: 20);
long     total = await repo.CountAsync(x => x.Price != null);

await repo.DeleteAsync(w);

// 4 ── multi-write atomicity
await using (var uow = await data.BeginTransactionAsync())
{
    await uow.Repository<Widget>().InsertAsync(new Widget { Name = "A", RowVer = 0 });
    await uow.Repository<Widget>().InsertAsync(new Widget { Name = "B", RowVer = 0 });
    await uow.CommitAsync();                      // dispose without commit ⇒ rollback
}
```

Task-oriented recipes for everything else — paging, projections, aggregates, bulk insert, streaming, stored
procedures, retry, dirty reads, timeouts — are in [docs/usage-guide.md](docs/usage-guide.md).

---

## Referencing the library

No NuGet feed; consumers reference the built DLL. TrustBank CBS does this:

```xml
<Reference Include="TflOmniDb">
  <HintPath>..\..\..\_Archive\Ad.ProjectLibrary\AdDataAccessComponent\TflOmniDb\TflOmniDb\bin\Debug\net10.0\TflOmniDb.dll</HintPath>
</Reference>
```

Bare-DLL references carry **no build-order edge** — build `TflOmniDb` first whenever it changes, then the
consumers. Entity assemblies generated by the scaffolder (e.g. `TflCbs.Entities`) reference it the same way, so the
order is: `TflOmniDb` → entities → business layer → host.

**Runtime packages** (net10 leg): `Microsoft.Data.SqlClient` 6.0.2 · `Oracle.ManagedDataAccess.Core` 23.7.0 ·
`Npgsql` 9.0.2 · `Microsoft.Extensions.Logging.Abstractions` 9.0.4.

---

## Feature map

| Area | Capability | Legs |
|---|---|---|
| **CRUD** | `GetAsync` / `GetAllAsync` / `InsertAsync` / `UpdateAsync` / `DeleteAsync` | both |
| | Identity write-back on insert (`SCOPE_IDENTITY` / `RETURNING` / sequence) | both |
| | App-managed optimistic concurrency via `IsRowVersion` → `ConcurrencyException` | both |
| **Reads** | `WhereAsync` — predicate, ordering, paging (OFFSET/FETCH, LIMIT/OFFSET) | both |
| | `CountAsync` (returns `long`) | both |
| | Column projection on `GetAsync` / `GetAllAsync` | both |
| | Projected `WhereAsync` | net10 |
| | `IAsyncEnumerable` streaming: `StreamAllAsync` / `StreamWhereAsync` / `StreamQueryAsync` | net10 |
| **Writes** | `BulkInsertAsync` — `SqlBulkCopy` / binary `COPY` / `OracleBulkCopy` | both |
| | Partial-column `UpdateAsync(entity, cols)` | net10 |
| | Set-based `UpdateWhereAsync` / `DeleteWhereAsync` | net10 |
| **Aggregates** | `MaxAsync` / `MinAsync` / `SumAsync` / `AvgAsync` / `MaxKeyAsync` / `AnyAsync` | net10 |
| **Procedures** | `ExecuteProcedureAsync` (+ scalar / non-query), OUT / INOUT / return value, multiple result sets, TVP / array / PL-SQL table params, Oracle REF CURSOR | both |
| | `StreamProcedureAsync` — first result set as `IAsyncEnumerable<T>` | net10 |
| **Raw SQL** | `QueryAsync<T>` (POCO) / `QueryAsync` (untyped) / `ExecuteScalarAsync` / `ExistsAsync` / `ExecuteNonQueryAsync` | both |
| **Composition** | `SqlQuery` fluent builder + `Fn` cross-dialect scalar functions + typed `Col` / `Agg` tokens | both |
| **Row access** | `RowAccess` null-safe accessors over untyped rows and stored-proc result sets | both |
| **Resiliency** | Opt-in transient-fault retry; `ExecuteInTransactionAsync` retries a whole unit of work | both |
| **Operational** | `UseDirtyReads()`, `UseCommandTimeout()` (net10), `PushCorrelation()`, `SuppressLogging()` / `EnableLogging()` | both / net10 |
| **Logging** | Every command through `CommandLogger`; `IsSensitive` columns and sensitive params redacted | both |
| **Tooling** | Entity scaffolder (CLI + web, connected or air-gapped), cross-provider table migration, BenchmarkDotNet suite | net10 |

Full signatures in [docs/api-reference.md](docs/api-reference.md).

---

## Components

```
TflOmniDb/                    (the net10 library)
├── Core/          Entity, [DbTable], [DbColumn], CoreDataType, KeyGenerationStrategy, DefaultValueKind
├── Metadata/      EntityDescriptor, ColumnDescriptor, MetadataReader  — reflection once per type, cached
├── Dialect/       ISqlDialect + SqlServer/Oracle/Postgres dialects and their type mappers
├── Sql/           SqlGenerator (cached StatementSets), ExpressionTranslator, ColumnSelector, EntityDataReader
├── Providers/     DbProvider, IProviderRuntime, one runtime per engine, FrozenDictionary registry
├── Repository/    DataAccess, Repository<T>, IUnitOfWork, stored-procedure stack, retry, logging, RowAccess
├── Query/         SqlQuery composer, SqlFunctions (Fn), Col / Agg tokens
├── Scaffolding/   schema reading (live + air-gap dump), reverse type mapping, entity emitters
└── Migration/     MigrationFacade, CreateTableEmitter, MigrationColumn — cross-provider table copy
```

A single `GetAsync` call travels: `Repository<T>` → `MetadataReader` (cached descriptor) → `SqlGenerator` (cached
statement set for this dialect + schema) → `IProviderRuntime` (connection, parameter binding) → `CommandLogger` →
ADO.NET. How each layer works, what it caches, and where the extension points are: [docs/components.md](docs/components.md).

---

## Tooling

Three console/web front-ends, all thin shells over library code:

| Tool | Project | What it does |
|---|---|---|
| **Entity scaffolder** | `TflOmniDb.Scaffold` (CLI), `TflOmniDb.Scaffold.Web` (Minimal API + page) | Reverse-engineers a schema into `[DbTable]`/`[DbColumn]` C# or VB entities. Works **connected** or **air-gapped** (emit a script for the DBA, paste their output back). Run the CLI with no arguments for an interactive wizard. |
| **Table migration** | `TflOmniDbMigration` | Copies a table's structure and/or data between databases, across providers. Dry-run preview → confirm → copy → row-count verification. |
| **Benchmarks** | `TflOmniDb.Benchmarks` | BenchmarkDotNet: metadata cache, SQL generation, streaming vs buffered, bulk insert vs loop. |

Flags, config sections, naming axes and worked commands: [docs/tooling.md](docs/tooling.md).

---

## Design rules you should know before writing code

These are not style preferences — violating them produces wrong results or unportable SQL.

1. **Async only.** The repository exposes `*Async` methods and nothing else. No sync overloads exist.
2. **Schema is connection-level**, not per table — `DataAccessOptions.DefaultSchema`. Table names must be
   identical across all three databases.
3. **Identifiers are always quoted**, so casing is preserved on Oracle and PostgreSQL. Create objects with
   **uppercase** names (quoted, on PostgreSQL) to stay portable.
4. **Entity properties are `Nullable<T>` and `virtual`.** Nullable so partial rows materialise; virtual to leave
   the door open for proxy-based change tracking.
5. **Transactions opt in.** `data.Repository<T>()` opens a fresh connection per call. For atomicity use
   `BeginTransactionAsync()` and `uow.Repository<T>()`. Disposing without `CommitAsync` rolls back.
6. **Optimistic concurrency is app-managed.** An `IsRowVersion` integer column is auto-incremented on UPDATE and
   checked in the WHERE clause; zero rows matched ⇒ `ConcurrencyException`. Identical on all three engines — no
   `ROWVERSION` / `xmin` / `ORA_ROWSCN` dependency.
7. **No joins are generated.** Drop to raw SQL or `SqlQuery` for joins, GROUP BY, sub-queries, UNION, CTEs.
8. **Logging is opt-in** (`LoggerFactory`), and **parameter values are off by default** (`LogParameterValues`) —
   banking data is sensitive.
9. **Dirty reads are opt-in and scoped**: `using (data.UseDirtyReads()) { … }` applies `WITH(NOLOCK)` on SQL
   Server, no-op on the MVCC engines.
10. **Retry is off by default.** Set `DataAccessOptions.Retry` to enable it, and understand which paths are
    excluded (see the usage guide) before you do.

---

## Security guarantees

Every caller-influenced value reaches the database as a bound `DbParameter`, never as inlined text:

| Path | How values are bound |
|---|---|
| CRUD (`Insert`/`Update`/`Delete`/`Get`) | Entity property reads via `BuildParameter` |
| `WhereAsync` / `CountAsync` / `Stream*Async` predicates | Every constant, captured local, closure and IN-list item via `ExpressionTranslator.AppendParameter`. LIKE patterns escape `%`, `_`, `[`, `]` and bind the result |
| `QueryAsync` / raw SQL | The parameter dictionary becomes `DbParameter`s. **The SQL text itself is the caller's responsibility** — this is the documented escape hatch |
| Identifiers (table / column / schema) | From compile-time attributes or constructor-time config, then `QuoteIdentifier`. Never from request data |
| Paging integers | `int?` — the CLR type system precludes string content |

`SqlInjectionTests.cs` (8 tests per leg) pins this with malicious payloads across all three dialects. Column
values marked `[DbColumn(IsSensitive = true)]`, and stored-procedure inputs passed with `sensitive: true`, are
redacted in command logs.

---

## Performance

**Cached** (cheap on repeat use): `EntityDescriptor` per type (AppDomain lifetime) · `StatementSet` per
(descriptor, dialect, schema, dirty-reads).

**Per call**: `WhereAsync` / `CountAsync` SQL translation (~10–50 μs — predicates are dynamic) · closure
evaluation inside predicates (~5 μs via a manual fast path, falling back to compiled lambdas only for shapes it
cannot resolve).

**Deliberately absent**, and the reason the profile stays flat: no N+1 (no navigation properties or lazy
loading), no cartesian explosions (no join generation), no change tracking (the repository is stateless), no
materialisation proxies (`PropertyInfo.SetValue` writes directly).

The dominant cost of any call is the network round-trip; DAL CPU overhead is low microseconds per operation.
`TflOmniDb.Benchmarks` measures the claims — including the O(1)-vs-O(n) memory difference between
`StreamAllAsync` and `GetAllAsync`, and bulk insert vs a loop at 100 and 1,000 rows.

---

## Build & test

The solution hosts both legs, so **build it with Visual Studio MSBuild** — the Fx library is a legacy non-SDK
csproj using `PackageReference`, and `dotnet build` does not inject NuGet's target wiring for it:

```powershell
$mb = 'C:\Program Files\Microsoft Visual Studio\18\Enterprise\MSBuild\Current\Bin\MSBuild.exe'
& $mb TflOmniDb.slnx /t:Restore
& $mb TflOmniDb.slnx /p:Configuration=Debug
```

The Net10 projects build fine with `dotnet build` in isolation.

```powershell
# Connection strings — the same keys serve both legs
$env:TFLOMNIDB_SQLSERVER_CONN = '...'
$env:TFLOMNIDB_ORACLE_CONN    = '...'
$env:TFLOMNIDB_POSTGRES_CONN  = '...'

# Net10 — 521 tests
dotnet test TflOmniDb.Tests\TflOmniDb.Tests.csproj --logger 'console;verbosity=minimal'

# Fx — 332 tests, via vstest
& '...\vstest.console.exe' TflOmniDbFx.Tests\bin\Debug\net48\TflOmniDbFx.Tests.dll
```

Connection strings resolve **env var first**, then `App.config` `<appSettings>` in the test project.

**Every feature ships with a test and a demo.** When you change the library, update `TflOmniDb.Tests` (unit +
live-3-DB as appropriate) *and* add or extend a `TflOmniDb.Demo/Demos/*` entry wired into `Program.cs`. The demo
runs every entry against each configured provider in turn and prints a demo × provider matrix; a provider with an
unreachable connection is skipped, not failed.

---

## Documentation index

### Written for this library

| Document | What it covers |
|---|---|
| [docs/api-reference.md](docs/api-reference.md) | Every public type and member: `DataAccess`, `IRepository<T>`, `IUnitOfWork`, options, attributes, enums, stored-procedure stack, `SqlQuery` / `Fn` / `Col` / `Agg`, `RowAccess` |
| [docs/usage-guide.md](docs/usage-guide.md) | Task-oriented recipes: CRUD, transactions, paging, projections, aggregates, bulk insert, streaming, procedures, raw SQL, retry, dirty reads, timeouts, concurrency, logging |
| [docs/components.md](docs/components.md) | Internal architecture: the layers, what each caches, how a call flows end to end, extension points, what is intentionally missing |
| [docs/tooling.md](docs/tooling.md) | Scaffolder (CLI + web, connected + air-gap), table migration, benchmarks |

### Pre-existing references

| Document | What it covers |
|---|---|
| [docs/AdDataAccessComponent-vs-TflOmniDb.md](docs/AdDataAccessComponent-vs-TflOmniDb.md) · [html](docs/AdDataAccessComponent-vs-TflOmniDb.html) | Side-by-side comparison with the legacy Enterprise-Library-based component |
| [docs/Migration-from-AdDataAccessComponent.md](docs/Migration-from-AdDataAccessComponent.md) | Idiom-by-idiom porting cheat-sheet off the legacy DAL |
| [docs/CommandTimeout-and-AdDataAccessOptions.md](docs/CommandTimeout-and-AdDataAccessOptions.md) | Deep-dive on the timeout and the options bag: legacy mechanics, exact precedence, the full `DataAccessOptions` reference, config binding, worked examples |
| [docs/StoredProcMigration.md](docs/StoredProcMigration.md) | Strategy for converting stored procedures to provider-agnostic C# |
| `docs/datatype-mapping-*.txt` / `.pdf` | Schema-conversion tables: `CoreDataType` ↔ CLR ↔ SQL Server ↔ Oracle ↔ PostgreSQL, in several column arrangements (SQL-Server-primary, core-type-primary, with/without PostgreSQL, and a condensed team sheet). Generated by `docs/gen_datatype_mapping.py` and `gen_datatype_mapping_sqlserver.py` |
| [CLAUDE.md](CLAUDE.md) | The working contract for this repository — status, standing rules, per-feature detail |

