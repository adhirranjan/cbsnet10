# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Status

Provider-agnostic data-access layer for a banking application. Targets **SQL
Server, Oracle, and PostgreSQL** and ships in two parallel runtime legs that
share the same product surface:

| Leg | Folder | TFM | C# | Status |
|---|---|---|---|---|
| **Fx** (.NET Framework 4.8) | `TflOmniDbFx*/` | `net48` | 7.3 | Production-shipped, **332 / 332 live tests green** |
| **Net10** (.NET 10) | `TflOmniDb*/` | `net10.0` | latest | Modernized port, **521 / 521 live tests green** (adds streaming, plus bulk-insert, column projection, stored procedures, transient-fault retry, and raw-SQL complex queries that are also on Fx) |

Both legs are fully verified end-to-end against live SQL Server, PostgreSQL,
and Oracle instances — CRUD, transactions, optimistic concurrency, sensitive-
column redaction, filtered queries + paging, SQL-injection guards, dirty-read
hints, bulk insert (`SqlBulkCopy` / Npgsql binary `COPY` / `OracleBulkCopy`),
column projection on `GetAsync` / `GetAllAsync`, stored procedures (multiple
result sets, OUT / INOUT params, return value, scalar / non-query, TVP / array
params), opt-in transient-fault retry (deadlock / connection-error resiliency +
`ExecuteInTransactionAsync`), raw-SQL complex queries (GROUP BY / UNION / EXISTS /
sub-query into POCOs, untyped rows, scalar / EXISTS helpers), and (net10 only)
`IAsyncEnumerable` streaming reads, partial-column / set-based updates, typed scalar
aggregates (`MaxAsync` … `AnyAsync`), and the `UseCommandTimeout` per-scope timeout
override.

The two legs are **independent assemblies** (`TflOmniDbFx.dll` vs `TflOmniDb.dll`)
that share `TflOmniDb.slnx` and `TflOmniDb.runsettings` at the product root. The
outer directory naming (`AdDataAccessComponent`) is historical and doesn't match
the code's namespaces.

### Active development scope (per user directive — STANDING RULE)

- **Work on the net10 (`TflOmniDb*`) projects ONLY. The Fx (`TflOmniDbFx*`) projects are
  frozen.** Do **not** edit, build, test, or otherwise touch any `TflOmniDbFx*` project
  (`TflOmniDbFx`, `TflOmniDbFx.Demo`, `TflOmniDbFx.Tests`) — no new features, no fixes, no
  mirroring. They stay exactly as-is **unless the user explicitly asks** for an Fx change.
  When a change to shared/library code has an Fx-target side (e.g. the scaffolder's
  `--target fx` output), leave that side untouched.
- **Every feature ships with both a test and a demo.** When adding/changing a feature,
  always update `TflOmniDb.Tests` (unit + live-3-DB integration as appropriate) **and** add
  or extend a `TflOmniDb.Demo/Demos/*` entry wired into `Program.cs` — not just the library.

## Repository layout

```
AdDataAccessComponent/TflOmniDb/        ← product umbrella
├── TflOmniDbFx/                        ← Fx library  (net48, legacy non-SDK csproj)
├── TflOmniDbFx.Demo/                   ← Fx demo     (net48 console exe)
├── TflOmniDbFx.Tests/                  ← Fx tests    (net48, xUnit)
├── TflOmniDb/                          ← Net10 library  (net10.0, SDK-style, NRT, records)
├── TflOmniDb.Demo/                     ← Net10 demo     (net10.0 console exe)
├── TflOmniDb.Tests/                    ← Net10 tests    (net10.0, xUnit)
├── TflOmniDb.Benchmarks/               ← Net10 perf benchmarks (BenchmarkDotNet, net10.0)
├── TflOmniDb.Scaffold/                 ← Net10 entity-generator CLI (console, thin shell)
├── TflOmniDb.Scaffold.Web/             ← Net10 entity-generator web UI (Minimal API + static page)
├── TflOmniDbMigration/                 ← Net10 table-migration CLI (console, thin shell over Migration/)
├── TflOmniDb.slnx                      ← solution (hosts both legs in two solution folders)
├── TflOmniDb.runsettings               ← shared runsettings (env vars for the 3 connection strings)
└── CLAUDE.md                           ← this file
```

## Entity generator / scaffolding (net10 only)

Reverse-engineers a database schema into `[DbTable]` / `[DbColumn]`-annotated
entity classes for SQL Server, Oracle, and PostgreSQL. **All logic lives in the
`TflOmniDb` library** under `Scaffolding/`; two thin front-ends call one
`ScaffoldFacade`:
- **`TflOmniDb.Scaffold`** — console CLI (`generate`, `emit-script`, `list-tables`).
  **Run with no arguments for an interactive, menu-driven prompt** (`RunInteractiveAsync`):
  it asks for command, provider, source (live conn / dump), schema, all-tables-vs-single,
  output, namespace, and offers numbered menus for every enum (provider / language / target
  / casing / naming) and Y/N for the boolean flags. Whole-DB generation is just "All tables"
  (omit `--table`). **Tables whose name starts with `_` are skipped by default** in
  whole-schema mode (configurable via `--skip-table-prefix <csv>`, default `_`; opt out with
  `--include-all-tables`) — applies to `generate` and `list-tables`. The filter lives on
  `ScaffoldRequest.TableNameSkipPrefixes` + `ScaffoldFacade.ListTablesAsync(skipPrefixes)`
  (whole-schema only; ignored when a single `--table` is named).
  **Interactive prompt defaults are seeded from an optional `appsettings.json` `"Scaffold"`
  section** (`Command` (the top generate/list/emit menu) / `Provider` / `Source` / `Tables` (all/one) / `Namespace` / `OutputDir` / `Language` / `Target` /
  `Casing` / `Naming` / `Partial` / `SkipUnderscoreColumns` / `SkipUnderscoreTables` /
  `Advanced` (the "configure advanced options" Y/N prompt) / `SkipTablePrefix`, plus a per-provider `Connections` block keyed `SqlServer`/`Oracle`/
  `PostgreSql` with `ConnectionString` (`env:VAR` supported) + `Schema`). The wizard shows the
  configured value as each prompt's default — **Enter accepts it, typing overrides it for that
  run** (the file is never rewritten). The `Choose` menus gained a `(default)` option that Enter
  selects. Binding lives in `ScaffoldDefaults.FromConfiguration` (unit-tested no-DB via
  `ScaffoldDefaultsTests`); a missing file / section ⇒ all-null defaults ⇒ the original
  hard-coded fallbacks. **Config seeds the interactive path only — the flag-driven CLI is
  unchanged.**
- **`TflOmniDb.Scaffold.Web`** — Minimal-API + static page. In the UI the
  air-gap flow is labelled **“Script & paste”** and the connected flow
  **“Direct connection”** (the word *air-gap* is kept only in code/docs). The
  script-&-paste box is the primary UX. Bind to localhost (connected mode takes a
  connection string; nothing is persisted). App-level setting
  **`Scaffold:RequireTable`** (`appsettings.json`, default `true`) makes the
  table name mandatory — single-table generation by default; set it to `false`
  to allow whole-schema generation. A single generated file downloads directly;
  multiple files use per-file / `.zip` download.

Two acquisition modes converge on one provider-neutral `SchemaModel`, so the
generator is written once:
- **Connected** — open a live `DbConnection` (`DataAccess.OpenConnectionAsync`),
  query catalog views (`CatalogSql`), map rows to `ColumnSchema`.
- **Air-gap** — `SchemaScriptEmitter` emits a provider SQL script the DBA runs on
  a locked-down server; they paste the pipe-delimited output back;
  `SchemaDumpParser` reads it. (Oracle script prefixes the SQL\*Plus session
  settings; PG uses `\pset`; both NULL-guard concatenation.) The connected reader
  and the dump parser are asserted **byte-identical** by the integration tests
  (run the live script, parse, compare).

Single-table generation is supported in both modes (console `--table`, web Table
field). To pick a table on a large schema, `list-tables` (console command / web
"List tables" button → autocomplete) enumerates the base tables from a live
connection or a pasted dump. The reverse type mappers
invert the dialect `*TypeMapper`s; ambiguous native-type collapses (e.g.
`NVARCHAR(MAX)`→`NClob`, Oracle `RAW(16)`→`Binary`, `NUMBER(1,0)`→`Boolean`,
`(19,4)`→`Money`) resolve by documented heuristic and emit a `// note:` for the
reviewer. What the catalog can't infer is opt-in: `IsSensitive` (`--sensitive`),
`IsRowVersion` (`--rowversion-pattern`).

**Naming — two independent axes:** the DB identifier in the attribute is
casing-critical (the DAL always quotes), defaulting to **`--case upper`** (most
portable across all three engines — Oracle folds unquoted DDL to upper, SQL
Server is case-insensitive; **create PostgreSQL tables with quoted uppercase
names** so they match). The C# / VB class &amp; member name is cosmetic, defaulting to
**`--naming upper`** — the class/member matches the table/column name verbatim
(`B_ACCOUNT` → class `B_ACCOUNT`, `ACCOUNT_ID` → property `ACCOUNT_ID`); `pascal`
(`ACCOUNT_BALANCE` → `AccountBalance`) and `verbatim` are also available. `--target net10|fx`
picks the C# output style (net10 = file-scoped ns + nullable strings; fx = braced ns
+ non-nullable strings). Generated **net10** files are self-contained: the `// <auto-generated>`
header turns Roslyn's nullable context off, so the emitter writes `#nullable enable` (else the
nullable strings fail with CS8669) plus `using System;` (so `DateTime`/`Guid` resolve without
the project's `ImplicitUsings`). **`--lang csharp|vbnet`** picks the language (default `csharp`) —
VB emits `Imports` / `<DbColumn(...)>` / `Public Overridable Property … As T?` into `.vb`
files and is orthogonal to `--target` (which only chooses the namespace). The generated
**file name is the DB table name** (`B_ACCOUNT` → `B_ACCOUNT.cs`/`.vb`), not the PascalCase
class. Default `--namespace` is **`TflEntities`** (console + web). Classes are emitted
**`partial` / `Partial` by default** (console `--no-partial` to disable; web checkbox)
so hand-written members live in a sibling file (e.g. `B_ACCOUNT.Custom.cs`) the
generator never overwrites on regeneration. **net10 entities also get a nested
`public static class Cols`** of strongly-typed `TflOmniDb.Query.Col` column tokens
(`B_ACCOUNT.Cols.ACCOUNT_ID`, plus a `Cols.Table` constant) for the `SqlQuery` composer —
the token field name follows `--naming`, the `new Col("…")` argument follows `--case`. **On
by default; net10 target only** (console `--no-column-tokens` / wizard prompt / `Scaffold:EmitColumnTokens`
config; `--target fx` never emits it — the Fx library has no `Col` and the fx output stays untouched).
The web UI exposes only Provider /
Language / Schema / Table; everything else uses these defaults. Generated files can
be copied, downloaded individually (`.cs`/`.vb`), or downloaded together as a `.zip`.

```powershell
# Air-gap: emit a script for the DBA, then generate from their pasted output.
dotnet run --project TflOmniDb.Scaffold -- emit-script --provider oracle --schema OMNIDB --out dump.oracle.sql
dotnet run --project TflOmniDb.Scaffold -- generate --provider oracle --from-dump dump.txt --out ./Entities --target fx

# Connected:
dotnet run --project TflOmniDb.Scaffold -- generate --provider sqlserver \
    --conn env:TFLOMNIDB_SQLSERVER_CONN --schema dbo --out ./Entities --namespace Bank.Entities

# Web UI:
dotnet run --project TflOmniDb.Scaffold.Web   # then open the printed localhost URL
```

## Table migration (net10 only)

Copies a single table's **structure and/or data** from one database to another —
possibly across providers (e.g. SQL Server → Oracle). **All logic lives in the
`TflOmniDb` library** under `Migration/`; the **`TflOmniDbMigration`** console is a
thin interactive shell (mirrors the Scaffold wizard). Reuses the existing schema
reader, reverse type mappers, raw-SQL helpers, and the bulk-copy path.

- **`MigrationFacade`** (public) — two phases: `PrepareAsync(request)` reads the
  source schema, maps columns, emits the CREATE TABLE DDL, and counts source rows
  **without writing** (powers dry-run/preview); `ExecuteAsync(request, plan)` applies
  the destination-exists behaviour, creates the table, bulk-copies the rows, and
  verifies the destination row count. `RunAsync` does both.
- **`MigrationRequest`** — source/dest provider+conn+schema+table, `What`
  (`Structure` / `Data` / `Both`), optional `WhereCriteria` (+ params) for big-table
  subsets, `ExistsBehaviour` (`Fail` / `CreateIfMissing` / `DropAndRecreate` /
  `TruncateThenLoad`), `OracleUppercase` (default true). **Identity/PK values are
  preserved** (`KeepIdentities` is forced on; dest identity columns are emitted
  `GENERATED BY DEFAULT` / `IDENTITY(1,1)`).
- **`CreateTableEmitter`** (public) — the general-purpose CREATE TABLE generator the
  library previously lacked (fills the "DDL generation" gap): columns + nullability +
  preserved identity + table-level PK + best-effort `DEFAULT` translation
  (`DefaultTranslator`), dialect-quoted, **Oracle identifiers uppercased** so
  `OracleBulkCopy` can reach the table. v1 does **not** copy indexes / FKs / check
  constraints / computed columns.
- **`MigrationColumn`** (public, runtime column with no `[DbColumn]` entity) +
  **`MigrationColumnFactory`** — built from a `TableSchema` via the source provider's
  reverse type mapper; ambiguous-mapping notes surface as warnings.
- **Bulk seam**: a small internal `IBulkColumn` (`ColumnName` + `ClrType`) that both
  `ColumnDescriptor` and `MigrationColumn` implement, so the provider bulk-insert path
  serves both the typed `Repository<T>` and the runtime migration path. Public
  **`DataAccess.BulkCopyAsync(schema, table, IReadOnlyList<MigrationColumn>, rows,
  options)`** is the non-generic entry point.
- **Console** (`TflOmniDbMigration`): interactive wizard (source/dest provider + conn
  + schema + table, scope, optional WHERE, exists-behaviour) → **dry-run preview**
  (DDL + column mapping + source count + warnings) → confirm → execute → row-count
  verification. Prompt defaults come from an optional `appsettings.json` `"Migration"`
  section (`Source`/`Dest` legs, each with `Provider`/`Schema`/`Table` + per-provider
  `Connections` keyed `SqlServer`/`Oracle`/`PostgreSql`, `ConnectionString` `env:VAR`
  supported). A newly typed connection string can be **saved back** to appsettings.json
  (`ConnectionStringWriter`, System.Text.Json — verbatim, so `env:NAME` stays a
  reference). Extra features: **emit DDL to a `.sql` file**, and the dry-run preview.

```powershell
# Interactive (no args): wizard → preview → confirm → copy + verify.
dotnet run --project TflOmniDbMigration
```

`TflOmniDb.Scaffold` is intentionally left untouched. Unit-tested no-DB (emitter per
dialect, column factory, config binder, connection-string writer); a gated SQL Server →
Oracle integration test + the net10 demo (#20 `TableMigration`) exercise it live.

## Product surface (same on both legs)

- **`Core/`** — `Entity` base, `[DbTable]` / `[DbColumn]` attributes, neutral
  `CoreDataType` / `KeyGenerationStrategy` / `DefaultValueKind` enums. Provider-
  neutral by design; per-provider type overrides live as optional string
  properties (`SqlServerType`, `OracleType`, `PostgresType`) on the column
  attribute as an escape hatch. `IsRowVersion = true` marks an optimistic-
  concurrency token column. `IsSensitive = true` marks values that get redacted
  in log output.
- **`Metadata/`** — `EntityDescriptor`, `ColumnDescriptor`, `MetadataReader`.
  Reflection runs once per `Type`, cached for the AppDomain lifetime. Validation
  rules fail fast at descriptor build (e.g., `Size > 0` for variable-length
  strings, `SequenceName` required for `KeyGeneration.Sequence`, at most one
  `IsRowVersion` per entity).
- **`Dialect/`** — `ISqlDialect` plus per-provider implementations:
  `SqlServerDialect` (`[name]`, `@p0`, `SCOPE_IDENTITY()`), `OracleDialect`
  (`"name"`, `:p0`, `RETURNING ... INTO :ret`), `PostgresDialect` (`"name"`,
  `@p0`, `INSERT ... RETURNING`). Each ships a sibling `*TypeMapper` translating
  `CoreDataType` to native types.
- **`Sql/`** — `SqlGenerator` produces `StatementSet`s (SELECT-by-key /
  SELECT-all / INSERT / UPDATE / DELETE) per descriptor + dialect + schema.
  Cached. `ExpressionTranslator` converts LINQ predicates to parameterized
  WHERE clauses.
- **`Providers/`** — `DbProvider` enum + `IProviderRuntime` + one runtime per
  provider. On the **net10 leg** `ProviderRegistry` dispatches through a
  `FrozenDictionary<DbProvider, IProviderRuntime>` built once at static init;
  on the **Fx leg** it's a switch statement. Same external behavior.
- **`Repository/`** — `IRepository<T>`, `Repository<T>`, `DataAccess`,
  `IUnitOfWork`, `UnitOfWork`, `CommandLogger`, `ConcurrencyException`,
  `DataAccessOptions`, `DataAccessOptionsBuilder`, `BulkInsertOptions`.

## Bulk insert (both legs)

`IRepository<T>.BulkInsertAsync(IReadOnlyList<T> entities, BulkInsertOptions?, ct)`
takes the provider's fast path — orders of magnitude faster than `InsertAsync`
in a loop for batches > ~50 rows. Per-provider implementations:

| Provider | Underlying API | Async? |
|---|---|---|
| SQL Server | `Microsoft.Data.SqlClient.SqlBulkCopy` + `EntityDataReader` adapter | yes |
| PostgreSQL | `NpgsqlBinaryImporter` (binary `COPY` protocol) | yes |
| Oracle | `Oracle.ManagedDataAccess.Client.OracleBulkCopy` | sync, wrapped in `Task.Run` |

**v1 limitations**:
- Identity columns are NOT round-tripped back into entities. Use
  `InsertAsync` per row if you need the generated Ids.
- Row-version columns are inserted verbatim from the entity — caller's
  responsibility to set an initial value if the DB doesn't default it.
- **Oracle bulk insert only works on tables created with unquoted
  (uppercase) names.** OracleBulkCopy's OCI direct-path API strips quotes
  and uppercases identifiers, so `CREATE TABLE "Widget"` (mixed-case
  quoted) is unreachable via bulk. Use `InsertAsync` for those tables.
  The integration test creates a self-contained `WIDGET` (unquoted) table
  to demonstrate the working path.

`BulkInsertOptions` knobs: `BatchSize`, `TimeoutSeconds`, `KeepIdentities`,
`EnableTableLock` (SqlServer only), `FireTriggers` (SqlServer only).

## Column projection on GetAsync / GetAllAsync (both legs)

`IRepository<T>.GetAsync(object[] keys, params Expression<Func<T, object?>>[] columns)`
and `IRepository<T>.GetAllAsync(params Expression<Func<T, object?>>[] columns)`
emit a SELECT containing only the projected columns plus the PK (always
included for round-trip identity). Properties not in the projection stay at
their default on the returned entity.

```csharp
// Just need Id + Name for a dropdown list — avoid the wide row read.
var summaries = await repo.GetAllAsync(x => x.Id, x => x.Name);
```

**net10 also has a projected `WhereAsync`** — same filter / order / paging as the normal
`WhereAsync`, but the SELECT carries only the chosen columns (+ PK). The column array is the
2nd argument (distinct overload, no ambiguity with the unprojected `WhereAsync`):

```csharp
// filter by login, but only read ORGELEMENTID (+ PK) — not the whole 19-column row
var u = (await repo.WhereAsync(x => x.LOGINNAME == loginName, [x => x.ORGELEMENTID], take: 1))
    .FirstOrDefault();   // u.ORGELEMENTID populated; other properties stay default
```

Limitation: each projection must be a simple property access. Computed
expressions and method calls throw `ArgumentException` — for derived values
drop to `QueryAsync`. The `ColumnSelector` helper unwraps compiler-inserted
`Convert(...)` for boxed value-type access (e.g. `x => x.Id` where Id is
`long?`).

## Targeted updates — partial-column & set-based (net10)

`UpdateAsync(entity)` writes **every** updatable column. Two narrower forms exist for
targeted writes (the `UpdateAsync` overloads are the write-side mirror of the projected
`GetAsync`):

```csharp
// Partial-column: write only the named columns (matched by PK); the rest of the row
// is left as stored. No prior read needed — PK + changed columns is enough.
await repo.UpdateAsync(new Widget { Id = 42, Name = "renamed" }, x => x.Name);

// Set-based: UPDATE ... SET ... WHERE <predicate>, no PK required, multiple rows.
await repo.UpdateAsync(x => x.Price < 50m, [ (x => x.Notes, "on sale") ]);
```

- **Partial** `UpdateAsync(entity, params columns)` (net10: `SqlGenerator.BuildUpdatePartial`,
  not cached — column set varies). Each selector must be a simple property access; a
  PK / read-only / computed column, or an empty list, throws `ArgumentException`. **Row-version
  is always enforced**: if the entity has an `IsRowVersion` column it's incremented in SET and
  checked in WHERE even when not listed, so the entity must carry the current version (a stale
  value throws `ConcurrencyException`).
- **Set-based** `UpdateAsync(predicate, assignments)` is a thin alias of `UpdateWhereAsync`
  (the canonical name) — predicate translated like `WhereAsync` (provider-portable), no PK and
  no row-version semantics. Use it for predicate-driven bulk changes. `DeleteWhereAsync` is the
  delete counterpart.

## Scalar aggregates — `MaxAsync` / `MinAsync` / `SumAsync` / `AvgAsync` / `MaxKeyAsync` / `AnyAsync` (net10)

Thin typed aggregate helpers on `IRepository<T>` — the write-once equivalent of the legacy
`Max(type, criteria)` / `MaxPrimaryKeyValue(type)` idiom. Each builds `SELECT <FUNC>("col")
FROM table [WHERE …]` via `SqlGenerator.BuildAggregate` (column dialect-quoted; the optional
predicate translated by the same `ExpressionTranslator` as `CountAsync`, so it's parameterized,
injection-safe, and provider-portable), then reads the single scalar through the existing
owned-connection + retry path (`DataAccess.DirtyReadsActive` honored).

```csharp
decimal max  = await repo.MaxAsync<decimal>(x => x.Price);                       // whole table
decimal hi   = await repo.MaxAsync<decimal>(x => x.Price, x => x.Status == 1);   // filtered (the Max(type,"criteria") form)
decimal sum  = await repo.SumAsync<decimal>(x => x.Price, x => x.Price >= 30m);
long    next = await repo.MaxKeyAsync<long>();                                   // MaxPrimaryKeyValue shortcut (single-PK only)
bool    any  = await repo.AnyAsync(x => x.Price > 999m);                         // EXISTS-style; cheaper than CountAsync(...) > 0
```

- **`MaxAsync` / `MinAsync` / `SumAsync` / `AvgAsync`** `<TResult>(column, predicate?)` — the column
  selector must be a simple property access (computed expr throws `ArgumentException`; drop to
  `ExecuteScalarAsync` / `SqlQuery` `Agg`). Empty set / all-NULL ⇒ `default(TResult)`; use a **nullable**
  `TResult` (e.g. `MaxAsync<decimal?>`) to distinguish "no rows" from a real default (same idiom as
  `ExecuteScalarAsync`). `SUM` of an `int` column stays `int` on SQL Server — pick a wide `TResult` to
  avoid overflow. `AVG` follows the engine's native rule (integer column ⇒ integer/truncated on SQL
  Server & Oracle) — average a decimal column or cast in raw SQL for a fractional result.
- **`MaxKeyAsync<TResult>()`** — `MAX(pk)`; requires exactly one PK column (composite/keyless throws
  `InvalidOperationException`).
- **`AnyAsync(predicate?)`** — `SELECT 1 FROM table [WHERE …]`, read as a scalar (non-null first cell ⇒
  a row exists). Deliberately the portable `SELECT 1` form, not `EXISTS(...)`, to avoid the Oracle
  `FROM DUAL` split.
- Transactional automatically via `uow.Repository<T>()` (the repo handles the attached transaction).
  Unit-tested no-DB per dialect (`AggregateSqlTests`) + live SQL Server (`SqlServerAggregateTests`);
  demo menu #22 `Aggregates`.

## Stored procedures (both legs)

The DAL executes stored procedures through a non-generic API on `DataAccess`
(and `IUnitOfWork` for the transactional path), since a procedure isn't tied to
one entity. A fluent `StoredProcedureCall` describes the call; the result object
carries everything back:

```csharp
var call = new StoredProcedureCall("usp_Transfer")     // optional schema arg; defaults to DefaultSchema
    .Input("p_from", 1001)
    .Input("p_amount", 500m, CoreDataType.Money)
    .InputOutput("p_note", "ref", CoreDataType.UnicodeString, size: 50)
    .Output("p_new_balance", CoreDataType.Money)
    .ReturnValue();                                     // SQL Server / Oracle only

StoredProcedureResult r = await data.ExecuteProcedureAsync(call);
decimal bal   = r.GetOutput<decimal>("p_new_balance"); // OUT / INOUT by name (prefix stripped)
int?    code  = r.ReturnValue;                          // SQL Server RETURN / Oracle function result
var     rows  = r.FirstResultSet;                       // raw: ColumnNames + Rows (object?[]) + AsDictionaries()
```

- **`DataAccess.ExecuteProcedureAsync`** → full `StoredProcedureResult`
  (`ResultSets` + `Output` + `ReturnValue`). Result sets are **raw/untyped** by
  design (column names + values); map them yourself.
- **`ExecuteScalarProcedureAsync`** / **`ExecuteNonQueryProcedureAsync`** —
  convenience for "returns one value" / "just does work, returns rows-affected".
- **`IUnitOfWork.ExecuteProcedure*Async`** — same three, enlisted in the
  transaction (commit/rollback covers the procedure's writes).
- **net10 only**: `Repository<T>.StreamProcedureAsync(call)` →
  `IAsyncEnumerable<T>` streams the **first** result set materialized into `T`
  (reuses the `StreamQueryAsync` pipeline; OUT params / further sets aren't
  surfaced here).

Pass parameter names **without** the `@` / `:` prefix — the DAL adds the
provider's. List parameters in the procedure's declared order (PostgreSQL binds
positionally). Sensitive inputs (`Input(..., sensitive: true)`) are redacted in
command logs exactly like `[DbColumn(IsSensitive = true)]`. Everything routes
through the same `CommandLogger` (command pairing, correlation id, timeout).

Provider mechanics differ — the call surfaces them and unsupported combinations
throw a clear `NotSupportedException`:

| Feature | SQL Server | Oracle | PostgreSQL |
|---|---|---|---|
| Invocation | `CommandType.StoredProcedure` | same + `BindByName=true` | Npgsql `CALL` |
| Multiple result sets | multiple SELECTs (inline) | OUT **REF CURSOR** params — add `.Cursor("c")` | (procs return via OUT/INOUT, not result sets) |
| Return value | `.ReturnValue()` | function result via `.ReturnValue()` | **not supported** → throws |
| Collection param | **TVP** `.Table(name, dataTable, "dbo.Type")` (needs a pre-created TABLE TYPE) | **PL/SQL assoc array** `.Table(name, array)` (proc declares an index-by type) | **native array** `.Table(name, array)` |

Oracle REF CURSORs are surfaced as reader result sets (one `do/while
NextResult` loop covers all three providers). Schema-qualified names are quoted
via the dialect — honor the Oracle/PG uppercase-naming convention (same as
elsewhere in the DAL; an unquoted-uppercase Oracle proc must be called by its
UPPERCASE name, e.g. `new StoredProcedureCall("PR_G_AUTHENTICATEUSER")`, since the
DAL always quotes). Verified live on all three engines (Fx leg) plus SQL
Server on net10; unit tests pin the type map, name qualification, builder, and
capability guards. **Param `DbType` binding is provider-aware** (`CoreTypeDbType.Map(type,
provider)`): Oracle's managed provider rejects `DbType.DateTime2` on a parameter
(`OracleParameter.DbType` throws *"Value does not fall within the expected range"*), so a
`CoreDataType.DateTime` param folds to `DbType.DateTime` (bound as TIMESTAMP) on Oracle while
SQL Server / PostgreSQL keep the full-precision `DateTime2`.

## Transient-fault retry / resiliency (both legs)

Opt-in retry for transient DB faults (deadlocks, dropped connections, transport
blips). **Off by default** — set `DataAccessOptions.Retry` to a `RetryOptions` to
enable; leaving it `null` preserves today's exact behavior.

```csharp
var options = new DataAccessOptions
{
    Provider = DbProvider.SqlServer,
    ConnectionString = cs,
    Retry = new RetryOptions { MaxAttempts = 3, BaseDelay = TimeSpan.FromMilliseconds(200) },
};
```

`RetryOptions`: `MaxAttempts` (total tries, default 3), `BaseDelay` (200 ms),
`MaxDelay` (5 s), `RetryOnTimeout` (default **false**), `UseJitter` (true).
Backoff is exponential — `min(MaxDelay, BaseDelay × 2^(n-1))` — with optional
full jitter. Each retry logs a Warning.

- **Auto-retry** wraps the **owned-connection** path only: single CRUD,
  `WhereAsync` / `CountAsync` / `QueryAsync`, and stored-procedure calls. Each
  attempt opens a fresh connection.
- **`DataAccess.ExecuteInTransactionAsync(uow => { ... })`** retries an entire
  unit of work — rolling back and reopening a fresh connection + transaction per
  attempt. This is the only safe way to retry multi-statement work (a single
  command inside an open transaction can't be replayed). Make the delegate
  idempotent — it may run more than once.
- **Excluded** from auto-retry: a single command enlisted in an open transaction
  (use `ExecuteInTransactionAsync`), **bulk insert** (a partial batch / PG binary
  `COPY` can't resume), and **streaming** (rows already yielded mid-enumeration).

**Write-safety.** Deadlocks (the engine already rolled back) and pre-send
connection/transport errors are always retried; **command timeouts are NOT
retried unless `RetryOnTimeout = true`** — a timed-out non-idempotent write may
have committed on the server, so retrying could double-apply it. Leave it off for
write paths.

`IProviderRuntime.IsTransient(ex, includeTimeouts)` classifies per engine:
SQL Server by `SqlException.Number` (deadlock 1205, transport/Azure-transient
233/64/53/10061/10053/54/60/40197/40501/40613/49918-20/4060/4221/11001, timeout
-2 gated), Oracle by `OracleException.Number` (deadlock 60; transport
3113/3114/12541/12537/12560/12571/etc.; 25408 safe-replay; 12170/1013 gated),
PostgreSQL by `PostgresException.SqlState` (40P01 deadlock, 40001 serialization,
57P0x shutdown, 08xxx connection; 08007 gated) plus bare `NpgsqlException`
(socket). The lists are the documented/tunable set. Unit-tested deterministically
via `RetryExecutor` + a fake transient predicate; the demo's resiliency entry
forces a real command timeout to show the loop live.

## Complex / ad-hoc queries (both legs)

The typed API deliberately generates **no joins / GROUP BY / sub-queries** (the
"no cartesian explosions… drop to raw SQL" philosophy). Complex reads —
GROUP BY / aggregates, sub-queries, UNION, EXISTS, CTEs — are **raw SQL**, run
through ergonomic non-entity helpers on `DataAccess` (and `IUnitOfWork` for the
transactional path). All route through `CommandLogger` and the owned-connection +
retry path (reads are retry-eligible when `DataAccessOptions.Retry` is set).

```csharp
// GROUP BY → a plain POCO (no [DbTable]/PK/Entity; columns map to props by name)
public sealed class CustomerSummary { public int CustomerId; public int OrderCount; public decimal TotalAmount; }
var rows = await data.QueryAsync<CustomerSummary>(
    "SELECT CustomerId, COUNT(*) AS OrderCount, SUM(Amount) AS TotalAmount FROM Orders GROUP BY CustomerId");

// UNION / ad-hoc → untyped dictionaries
IReadOnlyList<IReadOnlyDictionary<string, object?>> r = await data.QueryAsync(
    "SELECT 'low' AS Bucket, COUNT(*) AS N FROM Orders WHERE Amount < 60 UNION ALL SELECT 'high', COUNT(*) FROM Orders WHERE Amount >= 60");

decimal total = await data.ExecuteScalarAsync<decimal>("SELECT SUM(Amount) FROM Orders");          // scalar
bool any   = await data.ExistsAsync("SELECT 1 FROM Orders WHERE CustomerId = @id", pars);          // EXISTS
int rows   = await data.ExecuteNonQueryAsync("UPDATE Orders SET Amount = Amount + @b WHERE Id = @id", pars); // write
```

- **`QueryAsync<TResult>(sql, params)`** — maps each row to a plain POCO by
  column→property name (case-insensitive); honors `[DbColumn(ColumnName=…)]` as an
  alias. No `[DbTable]` / primary key / `Entity` base required (unlike
  `Repository<T>.QueryAsync`). Columns with no matching property are ignored.
- **`QueryAsync(sql, params)`** — untyped rows (`IReadOnlyDictionary<string,object?>`).
- **`ExecuteScalarAsync<TScalar>(sql, params)`** — first column of first row, coerced.
- **`ExistsAsync(sql, params)`** — true if the SQL yields ≥1 row (pass `SELECT 1 … WHERE …` or a full `EXISTS`).
- **`ExecuteNonQueryAsync(sql, params)`** — raw write (UPDATE / INSERT / DELETE / DDL),
  returns rows-affected. The raw-SQL counterpart of the entity `Repository<T>` writes —
  for targeted partial updates the typed API doesn't generate. Logged at
  `MutationLogLevel`; retry-eligible on the owned-connection path (keep idempotent if
  `Retry` is set). Also on `IUnitOfWork` for the transactional path.
- **net10 only**: `StreamQueryAsync<TResult>` / untyped `StreamQueryAsync` (`IAsyncEnumerable`).

Parameter keys include the provider prefix (`"@id"` / `":id"`). The SQL text is the
caller's responsibility (the documented raw-SQL escape hatch). The SQL itself is
**not** made provider-portable — GROUP BY/UNION/EXISTS are standard, but identifier
quoting and dialect functions differ; quote with the dialect (see the generated-SQL
comparison demo) or write provider-aware text. **Non-goals** (by design): no GROUP
BY/JOIN generation, no EXISTS/`.Any()` inside `WhereAsync`, no fluent query builder.
`PocoMaterializer` is unit-tested via a `DataTableReader`; live coverage across all
three engines via integration tests + the complex-query demo.

## Query composition — `Fn` + `SqlQuery` (both legs, namespace `*.Query`)

A thin, provider-aware layer over the raw-SQL helpers above, built for the
stored-procedure-to-C# migration (see `docs/StoredProcMigration.md`). It generates
SQL + bound parameters and **delegates to the existing `DataAccess` / `IUnitOfWork`
raw-SQL pipeline** — so logging, retry, redaction, correlation, and `UseDirtyReads`
keep working. It never opens connections or owns transactions. **Not an ORM / not a
query compiler**: it doesn't parse SQL, build an expression tree, auto-quote
identifiers, or model window / CTE / PIVOT (those stay raw `QueryAsync<T>`).

- **`SqlFunctions.For(provider)`** (alias `SqlQuery.Fn`) — the cross-dialect scalar
  vocabulary that pays down the pervasive `ISNULL` / `GETDATE` / `+`-concat tax. Each
  method returns a SQL **text fragment** rendered per dialect: `Coalesce` (→ `COALESCE`
  everywhere, replaces `ISNULL`/`NVL`), `Concat` (`+` on SqlServer, `||` on Oracle/PG),
  `Now` (`SYSDATETIME()`/`SYSTIMESTAMP`/`now()`), `CharIndex` (hides the
  `CHARINDEX`/`INSTR`/`POSITION` operand-order flip), `Substring`, `Length`
  (`LEN`/`LENGTH`), `Upper`/`Lower`/`Trim`, and `Cast(expr, CoreDataType, …)`.
- **`SqlQuery.From(table, alias, provider)`** — fluent `Select` / `InnerJoin` / `LeftJoin`
  / `Where` / **`WhereIf`** / `GroupBy` / `Having` / `OrderBy` / `Page`. `WhereIf` is the
  headline: conditional predicate composition that replaces both the "8 near-identical
  branches" report pattern and runtime dynamic-SQL string building (and is index-friendly,
  unlike the `col = COALESCE(@p, col)` idiom). Placeholders use the neutral `@name` prefix;
  `Build()` rewrites them to the dialect prefix (`@`→`:` on Oracle) and dedups reused names.
  Fragments (select / join / predicate) pass through verbatim — bind values as parameters.
- **Typed (token) overloads** — for refactor-safe, auto-quoted column references without string
  fragments: `Col` (a column name + optional alias, `.As("a")` for joins) and `Agg`
  (`Count`/`Sum`/`Avg`/`Min`/`Max`, rendering `FUNC(col) AS alias`). `SqlQuery` gains
  `SelectCols(params Col[])` / `Select(params Agg[])` / `GroupBy(params Col[])` / `OrderBy(Col, desc)`
  and `Where(Col, op, value)` (operator whitelisted; value bound to an auto-named, letter-leading
  parameter so Oracle accepts it). `From<TEntity>(alias, provider)` pulls the table name from the
  entity's `[DbTable]`; **`InnerJoin<TRight>(alias, leftCol, rightCol)` / `LeftJoin<TRight>`** take the
  joined table from `TRight`'s `[DbTable]` and the ON from `Col` tokens (composite ON via
  `params (Col,Col)[]`); the string `InnerJoin(table, on)` stays as the escape hatch for views /
  mixed-case tables. **`Distinct()`** emits `SELECT DISTINCT` (DB-side dedup; ORDER BY cols must be
  selected). The **scaffolder emits a nested `Cols` class of `Col` tokens per entity**
  (`B_ACCOUNT.Cols.ACCOUNT_ID`) so the columns are compile-checked. Identifiers are dialect-quoted;
  aggregate output aliases are left unquoted so an unquoted `OrderBy("alias")` matches across
  dialects. Zero expression-tree / GC overhead (the tokens are structs over strings).
- **Execution:** `ToListAsync<T>` / `ToDictionariesAsync` / `ScalarAsync<T>` / `ExistsAsync`
  taking a `DataAccess` (owned + retry) or `IUnitOfWork` (transactional); net10 adds
  `StreamAsync<T>`. `Build()` returns the `(sql, parameters)` if you want to run it yourself.

Unit-tested with no DB (per-dialect rendering + clause assembly + `WhereIf` + Oracle
prefix rewrite + paging); end-to-end coverage via the SQL Server complex-query
integration test (GROUP BY + `WhereIf` + scalar) and demonstrated live across all three
providers by the net10 **`ComplexQueryDemo`** (menu #17), which shows the composer
(GROUP BY + HAVING, `WhereIf`, INNER JOIN + column projection, typed `Col`/`Agg` tokens,
`Fn`, scalar) alongside the raw-SQL equivalents. The typed-token rendering is unit-tested
in `QueryComposerTests` (`Col` quoting, `Agg`, typed `Where` auto-param + Oracle prefix,
`From<TEntity>`). Also added: raw-write **`ExecuteNonQueryAsync`** on
`DataAccess` / `IUnitOfWork` (above).

## Safe row access — `RowAccess` extensions (both legs, namespace `*.Repository`)

Ergonomic, null-safe accessors for the DAL's **untyped** row shapes, so raw-column results
read cleanly instead of hand-casting `object?` and guarding four failure modes (null result
set, missing row, missing column, SQL NULL). The only untyped row shape is
`IReadOnlyDictionary<string, object?>` — what `DataAccess.QueryAsync(sql)` returns and what
`StoredProcResultSet.AsDictionaries()` produces — so the extensions attach there and on
`StoredProcResultSet`. (Typed paths — `QueryAsync<T>`, `GetAsync`, `GetAllAsync` — already
return entities and need none of this.)

- **On a row (`IReadOnlyDictionary<string, object?>`):** `Get<T>(col)` (coerced; `default`
  if missing/NULL), `GetAs<T>(col)` (reference cast for `byte[]`/`string` — `as T`, where
  `ChangeType` would throw), `TryGet<T>(col, out value)`, `HasColumn(col)`, `IsNull(col)`,
  and typed getters `GetString/GetInt32/GetInt64/GetDecimal/GetDouble/GetBoolean/GetDateTime/
  GetGuid/GetBytes` (nullable, plus `(col, fallback)` non-null overloads).
- **On `StoredProcResultSet` (null-safe receiver — works on `result.FirstResultSet`):**
  `Get<T>(rowIndex, col)` / `Get<T>(col)` (row 0), `GetAs<T>(…)`, `Row(rowIndex)` / `FirstRow()`
  (→ a row dict to chain the typed getters), and **`ToList<T>()` / `First<T>()` /
  `FirstOrDefault<T>()`** mapping rows to a POCO (buffered SP→POCO; gives Fx a
  `StreamProcedureAsync` equivalent). Same three on `StoredProcedureResult` over `FirstResultSet`.

Coercion is the shared `PocoMaterializer.Coerce` (enum / Guid / `Nullable<T>` unwrap /
culture-invariant `Convert.ChangeType`); `PocoMaterializer` gained a buffered
`Map<T>(columns, values)` overload. `Get<T>` returns `default` on missing/NULL (so `Get<int>`
→ `0`, `Get<int?>` → `null`). Unit-tested no-DB on both legs; demonstrated live across all
three providers by the **`RowAccess`** demo (net10 demo menu #18).

## Benchmarks (net10 only)

`TflOmniDb.Benchmarks/` is a separate console project using BenchmarkDotNet.
Covers:

- **MetadataBenchmarks** — `MetadataReader.For<T>()` cold vs warm cache hit.
- **SqlGenerationBenchmarks** — `SqlGenerator.For(desc)` cached lookup,
  `BuildSelectWhere` per-call cost (simple and compound predicates),
  `BuildCount` with no predicate.
- **StreamingVsBufferedBenchmarks** — validates the O(1)-vs-O(n) memory
  claim for `StreamAllAsync` vs `GetAllAsync` against a live SQL Server.
- **BulkInsertVsLoopBenchmarks** — `BulkInsertAsync` vs N × `InsertAsync` for
  100 and 1000 rows.

```powershell
# List all benchmarks:
dotnet run --project TflOmniDb.Benchmarks -c Release -- --list flat

# Run everything:
dotnet run --project TflOmniDb.Benchmarks -c Release -- --filter '*'

# Run just the in-memory ones (no DB needed):
dotnet run --project TflOmniDb.Benchmarks -c Release -- --filter '*Metadata*' '*Generation*'
```

The streaming and bulk-insert benchmarks require `TFLOMNIDB_SQLSERVER_CONN`
in the environment — they spin up their own `BenchWidget` / `BenchBulkWidget`
tables and tear them down on cleanup.

## What's different on the net10 leg

The net10 leg has the same public API plus **additive modern affordances**:

- **`IAsyncEnumerable<T>` streaming reads** on `IRepository<T>`:
  - `StreamAllAsync(ct)` — streams every row, no `List<T>` buffer.
  - `StreamWhereAsync(predicate, orderBy, descending, skip, take, ct)`
  - `StreamQueryAsync(sql, parameters, ct)` — raw-SQL streaming.
  Mid-stream cancellation works via `[EnumeratorCancellation]`. Existing
  `Task<IReadOnlyList<T>>` overloads preserved — streaming is *added*, not a
  replacement.
- **Records** for value-shape types: `EntityDescriptor`, `ColumnDescriptor`,
  `StatementSet`, `GeneratedStatement`, `RowVersionBindingInfo`,
  `InsertIdentityReturn`, `DynamicStatement`.
- **`required init`** on `DataAccessOptions.Provider` and `ConnectionString` —
  compile-time enforcement of the two non-optional knobs.
- **`System.Threading.Lock`** (net9+ ref-typed lock) replaces `object _sync`
  patterns throughout. Same `lock (_sync) { ... }` syntax, better semantics.
- **`FrozenDictionary` for `ProviderRegistry`** — populated-once + read-many
  lookup.
- **`ConfigureAwait(false)`** on every library await.
- **NRT enabled** (`<Nullable>enable</Nullable>` + `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>`).
- **`IsAotCompatible=true` / `IsTrimmable=true`** on the library csproj.
  Surfaces analyzer warnings for unsafe-for-AOT reflection at compile time —
  guardrails for future source-generator work.
- **Modern packages**: `Microsoft.Data.SqlClient` 6.0.2,
  `Oracle.ManagedDataAccess.Core` 23.7.0, `Npgsql` 9.0.2,
  `Microsoft.Extensions.Logging.Abstractions` 9.0.4.

What's deliberately *not* on the net10 leg yet:
- Source generators replacing `MetadataReader` reflection (scoped out — the
  cache already amortizes the one-shot reflection cost per type for the AppDomain
  lifetime). Code is structured so a source generator can drop in later by
  replacing `MetadataReader.For<T>()` with `Metadata<T>.Descriptor` constants.

## Build & test

The solution file lives at the product root:

```powershell
$mb = 'C:\Program Files\Microsoft Visual Studio\18\Enterprise\MSBuild\Current\Bin\MSBuild.exe'
& $mb TflOmniDb.slnx /t:Restore
& $mb TflOmniDb.slnx /p:Configuration=Debug
```

Why VS msbuild specifically: the Fx library is a legacy non-SDK csproj with
`PackageReference`. VS msbuild auto-injects NuGet's target wiring; `dotnet build`
does not, and fails with "Microsoft.Data not found" etc. The Net10 projects
are SDK-style and `dotnet build` works fine for them in isolation, but the
solution build must go through VS msbuild to cover the Fx leg.

### Running tests

```powershell
# Required env vars (same keys serve both legs):
$env:TFLOMNIDB_POSTGRES_CONN  = 'Host=localhost;Port=5432;Database=omnidb;Username=omnidb;Password=devpass'
$env:TFLOMNIDB_SQLSERVER_CONN = 'Server=DBSRV1\TSSIPL2016;Database=Trustbank_SUDAN_UAT;User Id=sa;Password=sql@2016;TrustServerCertificate=true'
$env:TFLOMNIDB_ORACLE_CONN    = 'User Id=omnidb;Password=devpass;Data Source=localhost:1521/FREEPDB1;'

# Fx leg (net48) — 332 tests, via vstest:
$vstest = 'C:\Program Files\Microsoft Visual Studio\18\Enterprise\Common7\IDE\Extensions\TestPlatform\vstest.console.exe'
& $vstest TflOmniDbFx.Tests\bin\Debug\net48\TflOmniDbFx.Tests.dll /Logger:console`;verbosity=minimal

# Net10 leg — 521 tests, via dotnet test:
dotnet test TflOmniDb.Tests\TflOmniDb.Tests.csproj --no-build --logger 'console;verbosity=minimal'
```

Integration-test connection strings come from one of two sources (env var
wins). The helper `*Tests/Fixtures/TestConfig.cs` on each leg checks both:
- Environment variables `TFLOMNIDB_*_CONN` (used by CI, `.runsettings`
  `<EnvironmentVariables>`, and user-level env vars). Names are **product-
  scoped** (no `FX` or `NET10` suffix) — the same keys serve both legs.
- `TflOmniDbFx.Tests/App.config` or `TflOmniDb.Tests/App.config` `<appSettings>`
  (local-dev fallback for when VS Test Explorer's runsettings handling is flaky).

### Demo configuration

- **Fx demo** reads config from `App.config` `<appSettings>` keys prefixed with
  `TflOmniDbFx:` (matches the Fx library's `DataAccessOptionsBuilder.DefaultPrefix`).
  Logging goes through Enterprise Library / AdDiagnostics (.NET Framework-only).
- **Net10 demo** reads config from `appsettings.json` (`Microsoft.Extensions.
  Configuration`) under the `TflOmniDb` section. Logging goes through
  `Microsoft.Extensions.Logging.Console`. It is **multi-provider**: a CSV
  `Providers` (e.g. `"SqlServer,Oracle,PostgreSql"`) plus a per-provider
  `Connections` block (`ConnectionString` + `DefaultSchema`). Each connection
  string resolves **env-var-first** (`TFLOMNIDB_SQLSERVER_CONN` /
  `TFLOMNIDB_ORACLE_CONN` / `TFLOMNIDB_POSTGRES_CONN`, same names as the tests),
  then the config value. **Every demo runs against each active provider in turn**
  (per-demo banner + a demo×provider summary matrix); set `Providers` to one
  value to scope the run to a single engine. A provider with a blank/unreachable
  connection is **skipped** (preflight `OpenConnectionAsync`), not failed.
  `DemoSchema` emits provider-correct DDL so the demos are portable; the
  stored-procedure demo uses each engine's own SP model (T-SQL / Oracle REF
  CURSOR / PG `CALL`); a no-DB "generated-SQL comparison" entry prints the three
  dialects side by side. (The Fx demo stays single-provider.)

## Conventions in play

- Attribute-driven mapping; no fluent / no convention-based mapping. Every
  persisted column declares an `[DbColumn]`.
- Entity property types are typically `Nullable<T>` so all-args constructors can
  accept partial rows; `ColumnDescriptor.SetValue` handles `DBNull` and width
  coercion (e.g., `int` → `decimal?`).
- Properties are `virtual` on entities — door left open for proxy-based change
  tracking later.
- Async-first: the repository exposes only `*Async` methods. No sync overloads.
- Schema is **connection-level** config (`DataAccessOptions.DefaultSchema`,
  defaults to `"dbo"`). Not on the table attribute. Table names must be
  identical across all three databases — see `DbTableAttribute.cs`.
- Identifier casing is preserved on Oracle and PostgreSQL by always quoting.
- **Optimistic concurrency is app-managed.** A column marked `IsRowVersion = true`
  is an integer (Int16/Int32/Int64/Decimal) the repository auto-increments on
  UPDATE and checks in the WHERE clause. Zero matched rows → `ConcurrencyException`.
  Same on all three providers — no dialect-specific RowVersion / xmin / ORA_ROWSCN.
- **Transactions opt in.** Non-transactional `data.Repository<T>()` opens a
  fresh connection per call; for multi-write atomicity wrap in a unit of work:
  `using (var uow = await data.BeginTransactionAsync()) { ... }`. Disposing
  without `CommitAsync` rolls back automatically.
- **Logging is opt-in.** When `DataAccessOptions.LoggerFactory` is null,
  `NullLogger` swallows everything. Set a factory to surface every command at
  Debug and failures at Error. `LogParameterValues = true` includes parameter
  values in the log — off by default because banking data is sensitive.
- **`DirtyReads` is opt-in.** `using (data.UseDirtyReads()) { ... }` applies
  `WITH(NOLOCK)` to SELECTs on SQL Server; no-op on Oracle/PG (which have MVCC
  by design).
- **Command timeout is per-instance, overridable per-scope.**
  `DataAccessOptions.CommandTimeoutSeconds` (null ⇒ provider default) governs every
  command. `using (data.UseCommandTimeout(seconds)) { ... }` (net10) overrides it for
  the current async flow only — CRUD, filtered reads, scalar aggregates, raw SQL, and
  stored procedures inside the scope use that value; nested scopes shadow then restore;
  `0` = no timeout. Same `AsyncLocal` shape as `UseDirtyReads()` (precedence centralized
  in `DataAccess.ResolveCommandTimeout`; the three executors' `ApplyTimeout` all defer to
  it). It's the **server-side** timeout — distinct from a client-side `CancellationToken`
  deadline. Bulk insert keeps its own `BulkInsertOptions.TimeoutSeconds`. Unit-tested
  (`CommandTimeoutScopeTests`) + live both-directions proof (`SqlServerCommandTimeoutTests`);
  demo menu #23 `CommandTimeout`.

## Security guarantees

Every value the caller can influence reaches the database as a **bound
`DbParameter`**, never inlined text:

- **CRUD paths** (`InsertAsync`, `UpdateAsync`, `DeleteAsync`, `GetAsync`):
  values come from entity property reads, bound via `BuildParameter`.
- **`WhereAsync` / `CountAsync` / `Stream*Async` predicates**: every constant,
  captured local, closure, and IN-list item is appended via
  `ExpressionTranslator.AppendParameter`. LIKE patterns escape the LIKE
  metacharacters (`%`, `_`, `[`, `]`) and bind the result as a parameter.
- **`QueryAsync` / `StreamQueryAsync` parameter dictionary**: each value becomes
  a `DbParameter`. The SQL TEXT in raw-SQL calls is the **caller's
  responsibility** — this is the explicit escape hatch.
- **Identifier paths** (table names, column names, schema name): pulled from
  compile-time attribute metadata or constructor-time configuration, then run
  through the dialect's `QuoteIdentifier`. Never sourced from request data.
- **Paging integers**: `int?` for `skip` / `take` — the CLR type system
  precludes string content; `Int32.ToString()` is culture-invariant.

`SqlInjectionTests.cs` (8 tests on each leg) pins this down with malicious
payloads across all three dialects.

## Performance notes

What the DAL caches (cheap on repeat use):

- **`EntityDescriptor` per type** — `MetadataReader` cache, AppDomain lifetime.
- **`StatementSet` per (descriptor, dialect, schema, dirtyReads)** —
  `SqlGenerator` ConcurrentDictionary pin.

What's recomputed per call:

- **`WhereAsync` / `CountAsync` SQL** — translated each call (predicates are
  dynamic). Cost ~10–50 μs per translation, negligible vs. SQL round-trip.
- **Closure values inside predicates** — `ExpressionTranslator.TryEvaluate`
  walks the tree manually for the common shapes (literals, captured-local
  field/property chains, Convert wrappers); ~5 μs per closure. Falls back to
  `Expression.Lambda(...).Compile().DynamicInvoke()` only for arbitrary
  expressions the fast path can't resolve.

What we explicitly DON'T do (sidestepping classic EF pain):

- **No N+1** — no navigation properties, no lazy loading.
- **No cartesian explosions** — no joins. Drop to `QueryAsync` / `StreamQueryAsync` for those.
- **No change tracking** — repository is stateless. Each call constructs fresh entities.
- **No materialization proxies** — `PropertyInfo.SetValue` writes directly.

The dominant cost per CRUD call is the network round-trip; DAL CPU overhead is
in the low microseconds per operation.

## What's still missing

These are net-new work on either leg if requested:

- Schema diff / DDL generation from descriptors.
- Audit-column auto-population (`CreatedBy / CreatedOn / ModifiedBy / ModifiedOn`)
  via an ambient `ICurrentUser`.
- Explicit `DbType` / provider-specific type precision on parameter binding.
- DB-native row-version support (SQL Server `ROWVERSION`, PG `xmin`) — the
  current implementation is app-managed integer only.
- Bulk insert with identity round-trip (current `BulkInsertAsync` is
  fire-and-forget — doesn't write generated Ids back into the entities).
- Oracle bulk insert against mixed-case quoted tables (OracleBulkCopy
  limitation — currently requires Oracle's unquoted-uppercase naming).
- **Net10 leg only**: source generators replacing `MetadataReader` reflection
  for zero-reflection startup + native-AOT compatibility.

Type mappings exercised in live tests across both legs:
- SqlServer: `BIGINT / NVARCHAR / NUMERIC / DATETIME2`
- PostgreSQL: `BIGINT / VARCHAR / CHAR / NUMERIC / TIMESTAMP`
- Oracle: `NUMBER(19,0) / NUMBER(10,0) / NVARCHAR2 / CHAR(n CHAR) / TIMESTAMP`

**Not yet exercised** (no entity uses them): `JSONB`, `BYTEA`, `UUID`,
`TIMESTAMPTZ`, `XML` on PG; `INTERVAL`, `TIMESTAMP WITH TIME ZONE`, `XMLTYPE`,
native `JSON` on Oracle.

If a request lands on any of these, treat it as net-new — confirm the shape
before extending the contracts.
