# Command timeout & the options bag — `AdDataAccessOptions` → `DataAccessOptions`

The deep-dive referenced from
[AdDataAccessComponent-vs-TflOmniDb.md](AdDataAccessComponent-vs-TflOmniDb.md) and
[Migration-from-AdDataAccessComponent.md](Migration-from-AdDataAccessComponent.md) §3a–3b: how the legacy
per-call `CommandTimeout` worked, what replaced it, exactly how precedence resolves, and how the rest of the
old god-options bag decomposed.

**The one-line answer:** the legacy per-call `AdDataAccessOptions.CommandTimeout` became **connection-level
config plus an ambient scope** — `DataAccessOptions.CommandTimeoutSeconds` for the durable default,
`data.UseCommandTimeout(n)` for the one operation that needs more headroom.

---

## Contents

1. [How the legacy component did it](#1-how-the-legacy-component-did-it)
2. [How TflOmniDb does it](#2-how-tflomnidb-does-it)
3. [Precedence, exactly](#3-precedence-exactly)
4. [Where the timeout is applied — and where it isn't](#4-where-the-timeout-is-applied--and-where-it-isnt)
5. [Server-side timeout vs `CancellationToken`](#5-server-side-timeout-vs-cancellationtoken)
6. [The options bag, field by field](#6-the-options-bag-field-by-field)
7. [Binding from configuration](#7-binding-from-configuration)
8. [Worked examples](#8-worked-examples)
9. [Migration map](#9-migration-map)
10. [Gotchas](#10-gotchas)
11. [Coverage](#11-coverage)

---

## 1. How the legacy component did it

`AdDataAccessComponent` carried a single mutable `AdDataAccessOptions` bag through every call —
`Insert` / `Update` / `Delete` / `Select` / `Count` / `Max` / `Execute` all took the same class. Alongside
`Entity`, `Criteria`, `PkValue`, `Query`, `ColumnName`, `StoredProcedureName`, `ConnectionInfo`, `Transaction`
and the `NewPkValue` out-param, it carried **`CommandTimeout`**.

Two consequences shaped the replacement:

- **The timeout was per call.** Every call site could set its own, which sounds flexible and in practice meant
  the value was copy-pasted, drifted between call sites, and was invisible in one place.
- **The fallback was a global.** When the bag left `CommandTimeout` unset, the Enterprise Library configuration
  (`ConfigManager.CommandTimeOut`) supplied it — a process-wide static reached from anywhere.

So the legacy model was *ambient global, overridable per call*. TflOmniDb keeps that shape but makes both halves
explicit and scoped.

---

## 2. How TflOmniDb does it

Two levels, and a third for bulk:

```csharp
// 1 ── durable default: connection-level, set once
var data = new DataAccess(new DataAccessOptions
{
    Provider              = DbProvider.SqlServer,
    ConnectionString      = cs,
    CommandTimeoutSeconds = 60,          // legacy AdDataAccessOptions.CommandTimeout = 60
});

// 2 ── ambient override: this block only
using (data.UseCommandTimeout(300))      // 5 minutes
{
    var report = await data.QueryAsync<Summary>(heavyReportSql);
}                                        // reverts to 60 on dispose

// 3 ── bulk insert has its own knob (different underlying API)
await repo.BulkInsertAsync(rows, new BulkInsertOptions { TimeoutSeconds = 600 });
```

`CommandTimeoutSeconds` sits with the other connection-level settings (`DefaultSchema`, `Retry`, the logging
switches) because it is the same kind of thing: a property of *this connection to this database*, not of one
statement.

`UseCommandTimeout` is the escape hatch for the genuine exception — a nightly report, a large batch read, a slow
procedure — without standing up a second `DataAccess`. It mirrors `UseDirtyReads()` exactly: an
`AsyncLocal<int?>` that flows through `await`, across threads, nests (an inner scope shadows an outer one) and
restores the previous value on dispose.

```csharp
public IDisposable UseCommandTimeout(int seconds)   // net10 leg
```

- `seconds` must be **non-negative** — a negative value throws `ArgumentOutOfRangeException`.
- **`0` means no timeout** (wait indefinitely), matching ADO.NET semantics.
- The scope is process-flow-local, **not** per `DataAccess` instance: the backing field is static, so the scope
  affects any `DataAccess` used inside it. In practice a host has one instance per database, so this is what you
  want — but be aware of it in a multi-database process.

---

## 3. Precedence, exactly

One method decides, and every executor defers to it:

```csharp
internal static int? ResolveCommandTimeout(int? optionsValue) => _commandTimeoutOverride.Value ?? optionsValue;
```

| Scope active? | `CommandTimeoutSeconds` | Effective `DbCommand.CommandTimeout` |
|---|---|---|
| yes (`n`) | anything | **`n`** — the scope always wins |
| yes (`0`) | anything | **no timeout** |
| no | `60` | **60** |
| no | `null` | **provider default** (30 s on SqlClient) — the DAL does not touch `CommandTimeout` at all |

The rule is deliberately dull: **innermost scope wins; otherwise the instance value; otherwise the provider
default.** Because it lives in one place (`DataAccess.ResolveCommandTimeout`), that is also the single line to
change if the rule ever moves — the executors have no opinion of their own.

Nested scopes shadow and restore in order:

```csharp
// instance default: 60
using (data.UseCommandTimeout(300))
{
    // 300 here
    using (data.UseCommandTimeout(10))
    {
        // 10 here
    }
    // back to 300
}
// back to 60
```

---

## 4. Where the timeout is applied — and where it isn't

**Applied.** All three executors call the same resolver:

| Path | Call site |
|---|---|
| Typed CRUD, filtered reads, projections, scalar aggregates | `Repository<T>.ApplyTimeout(cmd)` |
| Raw SQL — `QueryAsync`, `ExecuteScalarAsync`, `ExistsAsync`, `ExecuteNonQueryAsync`, streaming | `RawQueryExecutor` |
| Stored procedures — all three entry points | `StoredProcedureExecutor` |

**Not applied.**

- **Bulk insert** keeps `BulkInsertOptions.TimeoutSeconds`. The provider bulk APIs (`SqlBulkCopy`,
  `NpgsqlBinaryImporter`, `OracleBulkCopy`) expose a separate `BulkCopyTimeout` that is not `DbCommand.CommandTimeout`
  — one knob could not honestly cover both.
- **Enumeration time on a streaming read.** `CommandTimeout` bounds *command execution* — up to the point the
  provider returns the first result — not the time you then spend enumerating the reader. A `StreamAllAsync` that
  takes ten minutes to consume will not trip a 30-second command timeout. Bound that with a `CancellationToken`.

---

## 5. Server-side timeout vs `CancellationToken`

They are different mechanisms and a robust call site often wants both:

| | `CommandTimeout` / `UseCommandTimeout` | `CancellationToken` |
|---|---|---|
| Enforced by | The **provider/server** — it aborts the command | The **client** — it stops waiting |
| Bounds | Command execution | The whole async operation, including enumeration |
| On expiry | A provider timeout exception (SQL Server: `SqlException` number −2) | `OperationCanceledException` |
| Retryable? | Only when `RetryOptions.RetryOnTimeout = true` — **off by default**, because a timed-out non-idempotent write may already have committed on the server | Not a transient fault; never retried |

```csharp
using var cts = new CancellationTokenSource(TimeSpan.FromMinutes(2));
using (data.UseCommandTimeout(90))
{
    var rows = await data.QueryAsync<Summary>(sql, pars, cts.Token);
}
```

Every async method on the DAL takes a `CancellationToken`, so a per-call *client* deadline needs no ambient
scope at all.

---

## 6. The options bag, field by field

`DataAccessOptions` is the durable half of what `AdDataAccessOptions` used to carry. Everything here is
connection-level; nothing here is per call.

| Member | Type | Default | Notes |
|---|---|---|---|
| `Provider` | `DbProvider` | — | **`required init`** on the net10 leg. Carrying it here is what removes `if (provider == SqlServer)` from call sites |
| `ConnectionString` | `string` | — | **`required init`** |
| `DefaultSchema` | `string?` | `"dbo"` | Per-deployment, not per entity — `dbo` in production, a per-tenant schema in QA. Empty/null emits unqualified table names |
| `CommandTimeoutSeconds` | `int?` | `null` | `null` ⇒ provider default. See §3 |
| `Retry` | `RetryOptions?` | `null` | `null` ⇒ **no retry**, unchanged behaviour |
| `LoggerFactory` | `ILoggerFactory?` | `null` | `null` ⇒ `NullLogger` — logging is opt-in |
| `LoggingEnabled` | `bool` | `true` | Per-instance switch for the "starting/completed" entries. Errors log regardless |
| `LogParameterValues` | `bool` | `false` | **Off by default** — values may carry PII or account numbers |
| `MutationLogLevel` | `LogLevel` | `Information` | INSERT / UPDATE / DELETE — high enough to survive a prod filter, so the write trail stays visible |
| `QueryLogLevel` | `LogLevel` | `Debug` | Reads — low enough that high-volume SELECTs don't drown the log |
| `GloballyEnabled` | `static bool` | `true` | **Process-wide** kill switch, ANDed on top of every instance. Designed to be flipped from an admin UI without a restart. An explicit `EnableLogging()` scope still wins over it |

Note the asymmetry that mirrors the timeout design: `LoggingEnabled` is per instance, `GloballyEnabled` is
process-wide, and the `SuppressLogging()` / `EnableLogging()` scopes override both for a block — the same
*durable value + ambient scope* shape.

---

## 7. Binding from configuration

`DataAccessOptionsBuilder` reads the host's **`<appSettings>`** through `System.Configuration.ConfigurationManager`,
under a configurable key prefix (`DefaultPrefix = "TflOmniDb"`):

```csharp
var opts = DataAccessOptionsBuilder.FromAppSettings();          // or FromAppSettings("MyApp:Db")
opts.LoggerFactory = myLoggerFactory;                            // not expressible in config
var data = new DataAccess(opts);
```

| Key (default prefix) | Maps to | Notes |
|---|---|---|
| `TflOmniDb:Provider` | `Provider` | Case-insensitive `SqlServer` / `Oracle` / `PostgreSql`. Absent ⇒ `SqlServer`. Unrecognised ⇒ `ConfigurationErrorsException` |
| `TflOmniDb:ConnectionString` | `ConnectionString` | Absent ⇒ empty string |
| `TflOmniDb:DefaultSchema` | `DefaultSchema` | An **empty-string** value is honoured (unqualified table names) |
| `TflOmniDb:CommandTimeoutSeconds` | `CommandTimeoutSeconds` | Non-numeric values are ignored, leaving the existing value |
| `TflOmniDb:LoggingEnabled` | `LoggingEnabled` | |
| `TflOmniDb:LogParameterValues` | `LogParameterValues` | |
| `TflOmniDb:GloballyEnabled` | `DataAccessOptions.GloballyEnabled` | **Side effect** — assigns the process-wide static, not the instance. Absent ⇒ the static keeps its current value |

**Not bindable**, by nature: `LoggerFactory` (an object), `Retry` (a nested policy), `MutationLogLevel` /
`QueryLogLevel`. Set those programmatically.

`ApplyAppSettings(options, prefix)` patches the **mutable** properties onto an existing instance — safe to layer
config over programmatic defaults, since an absent key leaves its property untouched. It cannot patch `Provider`
or `ConnectionString`: on the net10 leg those are `required init` and only `FromAppSettings` can supply them, at
construction.

> **Which configuration system?** `DataAccessOptionsBuilder` reads `<appSettings>` (app.config / web.config).
> A modern host using `appsettings.json` binds `Microsoft.Extensions.Configuration` itself and constructs
> `DataAccessOptions` directly — which is what `TflOmniDb.Demo` does under its `TflOmniDb` section. Both end at
> the same object; only the reader differs.

---

## 8. Worked examples

**One slow report, everything else normal.** The common case, and the reason the scope exists.

```csharp
using (data.UseCommandTimeout(600))
    return await SqlQuery.From("LEDGER", "l", data.Options.Provider)
        .Select("l.BRANCH_ID", "SUM(l.AMOUNT) AS TOTAL")
        .WhereIf(from is not null, "l.POSTED_ON >= @from", ("from", from))
        .GroupBy("l.BRANCH_ID")
        .ToListAsync<BranchTotal>(data);
```

**A whole transaction with more headroom.** The scope covers everything inside it, including the unit of work.

```csharp
using (data.UseCommandTimeout(120))
await using (var uow = await data.BeginTransactionAsync())
{
    await uow.Repository<B_ACCOUNT>().UpdateAsync(debited);
    await uow.ExecuteNonQueryAsync(slowReconcileSql);
    await uow.CommitAsync();
}
```

**Tighten, don't only loosen.** A scope can also shorten the timeout — useful on a user-facing path that must
fail fast rather than hold a request thread.

```csharp
using (data.UseCommandTimeout(3))
    return await repo.AnyAsync(x => x.STATUS == 1);
```

**Both bounds on a user request.**

```csharp
using (data.UseCommandTimeout(30))                       // server aborts the command at 30s
    return await repo.WhereAsync(predicate, take: 100,
                                 ct: httpContext.RequestAborted);   // client gives up if the caller disconnects
```

**Legacy per-call sites, mechanically.** Wherever the old code set the bag's `CommandTimeout` for one call:

```vb
' legacy
Dim opts As New AdDataAccessOptions()
opts.CommandTimeout = 300
opts.Query = heavySql
AdDataAccess.Execute(opts)
```

```csharp
// TflOmniDb
using (data.UseCommandTimeout(300))
    await data.ExecuteNonQueryAsync(heavySql);
```

**When a second `DataAccess` is still right.** If two workloads have durably different profiles — an OLTP path
and a reporting path — give them separate instances rather than wrapping every reporting call in a scope. Ambient
scopes are for exceptions; durable differences belong in configuration.

---

## 9. Migration map

The rest of the old bag, for completeness (expanded from
[Migration-from-AdDataAccessComponent.md](Migration-from-AdDataAccessComponent.md) §3a):

| `AdDataAccessOptions` field | TflOmniDb home | Kind |
|---|---|---|
| `ConnectionInfo` | `DataAccessOptions.ConnectionString` + `Provider` | durable config |
| `CommandTimeout` | `DataAccessOptions.CommandTimeoutSeconds` + `UseCommandTimeout(n)` | durable config + ambient scope |
| `Entity` / `EntityType` | the `Repository<T>` type parameter and the entity argument | type system |
| `Criteria` (string WHERE) | `Expression<Func<T,bool>>` predicate argument | typed argument |
| `PkValue` | the `keys` argument to `GetAsync` | typed argument |
| `Query` (raw SQL) | the `sql` argument to `QueryAsync` / `ExecuteNonQueryAsync` | typed argument |
| `ColumnName` (for `Max` / `Min`) | the `x => x.Col` selector on `MaxAsync` / `MinAsync` | typed argument |
| `StoredProcedureName` + `StoredProcedureParamList` | `StoredProcedureCall` in, `StoredProcedureResult` out | typed objects |
| `Transaction` | an `IUnitOfWork` from `BeginTransactionAsync` | scope, not a field |
| `NewPkValue` (out) | written back into the entity by `InsertAsync` | return path |
| *(bulk tuning)* | `BulkInsertOptions` | per-operation options |
| *(EntLib `ConfigManager.CommandTimeOut`)* | `DataAccessOptionsBuilder` + `TflOmniDb:CommandTimeoutSeconds` | config binding |

The through-line: **durable config is set once and lives in one object; per-call inputs are strongly-typed
method arguments; genuinely ambient concerns (timeout, dirty reads, correlation, logging) are `using` scopes
that restore themselves.** Nothing is a mutable field poked onto a shared bag.

---

## 10. Gotchas

| Symptom | Cause |
|---|---|
| The scope seems to have no effect | The scope must be entered **before** the `await`, and the operation must run inside it. `using (...) ;` followed by a later call is a no-op. It is also flow-local — starting a fire-and-forget `Task` outside the scope will not carry it |
| `ArgumentOutOfRangeException` from `UseCommandTimeout` | A negative value. `0` is legal and means *no timeout* |
| A scope of `0` hangs forever | That is what `0` means. Pair it with a `CancellationToken` |
| Bulk insert ignores the scope | By design — use `BulkInsertOptions.TimeoutSeconds` |
| A long `await foreach` times out anyway, or doesn't | `CommandTimeout` bounds command execution, not enumeration. Bound long enumerations with a token |
| Timeouts are never retried | Correct by default. `RetryOptions.RetryOnTimeout = true` opts in — do that only for idempotent reads |
| A timeout set in config didn't apply | Check the key prefix (`TflOmniDb:` unless you passed another), and remember non-numeric values are silently ignored. If the host binds `appsettings.json` itself, `DataAccessOptionsBuilder` is not in the picture at all |
| Two databases in one process, wrong timeout | The override is a process-flow static, so a scope entered around calls to *both* instances applies to both |

---

## 11. Coverage

| Level | What |
|---|---|
| Unit, no DB | `CommandTimeoutScopeTests` — precedence, nesting/shadowing, restore on dispose, `0` and negative handling |
| Live | `SqlServerCommandTimeoutTests` — proves it in both directions: a command that times out under a tight scope and completes under a wide one |
| Demo | Menu entry **#23 `CommandTimeout`** in `TflOmniDb.Demo`; the resiliency entry forces a real command timeout to show the retry loop |

---

**See also:** [usage-guide.md §18 Command timeout](usage-guide.md#18-command-timeout) ·
[api-reference.md — `DataAccessOptions`](api-reference.md#dataaccessoptions) ·
[components.md §2 `Repository/`](components.md#2-what-each-layer-owns) for where the resolver sits.
