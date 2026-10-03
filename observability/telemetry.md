# Telemetry — what we emit and how to use it

*A reference for developers and operators: which OpenTelemetry (OTel) traces and metrics the CBS emits, where the code lives, how to switch it on for each deployment shape, and how to read the output. New to observability? Start with the [primer](observability-primer.md). It explains logs, metrics and traces, OTLP, and the Grafana stack.*

---

## 1. At a glance

| Signal | Status | Source | Export |
|---|---|---|---|
| **Traces** | ✅ Built | ASP.NET Core requests, HttpClient calls, TflOmniDb DB commands | OTLP (gRPC) |
| **Metrics** | ✅ Built | ASP.NET Core + HttpClient RED metrics, .NET runtime | OTLP (gRPC) |
| **Logs** | ⚠️ Local only | TflOmniLog → Serilog (file / console) | **Not** exported over OTLP yet |
| Custom business metrics | ❌ None | — | — |

Key properties:

- **Off by default.** Nothing is registered unless `Observability:Enabled=true`, so a host that hasn't opted in doesn't pay for it. Only the Docker compose files turn it on.
- **Fails soft.** The OTLP exporter retries in the background and never throws into the request path. If the collector is down, you just get no telemetry; requests still work.
- **One trace across the farm.** The gateway creates the root span and passes the W3C `traceparent` header on, so a request appears as a single `gateway → host → DB` tree.
- **Same on all three database providers.** Database spans come from the DAL's single execution point, so SQL Server, Oracle and PostgreSQL all get them.

---

## 2. Where it lives

| Piece | File | What it does |
|---|---|---|
| Host registration | [`TflCbs.Framework/DependencyInjection/CbsObservabilityExtensions.cs`](../../TflCbs.Framework/DependencyInjection/CbsObservabilityExtensions.cs) | `AddCbsObservability(configuration)` — one call wires tracing + metrics + OTLP export |
| Options | [`TflCbs.Framework/Infrastructure/ObservabilityOptions.cs`](../../TflCbs.Framework/Infrastructure/ObservabilityOptions.cs) | Reads the `Observability` config section over defaults |
| DB spans | [`libs/TflOmniDb/TflOmniDb/Repository/CommandLogger.cs`](../../libs/TflOmniDb/TflOmniDb/Repository/CommandLogger.cs) | `ActivitySource` named `TflOmniDb` (`CommandLogging.ActivitySourceName`); one `db.execute` span per command |
| Gateway | [`TflCbs.Gateway/Program.cs`](../../TflCbs.Gateway/Program.cs) | Its own inline OTel setup (the gateway doesn't reference Framework); same config keys |
| Callers | `Program.cs` of `TflCbs.Host.Main` and every thin host (Hr, Lockers, RetailBanking, Administration, Inventory) | `builder.Services.AddCbsObservability(builder.Configuration);` |
| Dev backend | [`compose.observability.yaml`](../../compose.observability.yaml) | One `grafana/otel-lgtm` container: collector + Tempo + Prometheus + Grafana |
| Packages | [`Directory.Packages.props`](../../Directory.Packages.props) | `OpenTelemetry.*` 1.17.0 (Extensions.Hosting, Exporter.OpenTelemetryProtocol, Instrumentation.AspNetCore/Http/Runtime) |

---

## 3. What gets emitted

### Traces

| Span | Comes from | Notes |
|---|---|---|
| Incoming request | ASP.NET Core instrumentation | Recorded on gateway and hosts; `RecordException = true`, so an unhandled exception is attached to its span |
| Outgoing HTTP | HttpClient instrumentation | On the gateway this is the YARP proxy hop, which also injects `traceparent` |
| `db.execute` (kind *Client*) | TflOmniDb `CommandLogger.ExecuteAsync` | Times the actual command round-trip; nests under the request span; set to status *Error* if the command throws |

Tags on `db.execute`:

| Tag | Value |
|---|---|
| `db.system` | `mssql` / `oracle` / `postgresql` / `other` |
| `db.statement` | The **parameterized** SQL text (the same text the command log already writes) |
| `db.operation` | First SQL keyword, uppercased (`SELECT`, `INSERT`, …) |
| `tfl.command.seq` | The DAL's per-command sequence number (the same one that appears in the SQL debug log) |

**Parameter values never reach a span.** Values travel in `DbParameter`s, not in the SQL text. Masking rules for the log still apply there; spans just don't carry values at all.

**Sampling** is parent-based over a trace-ID ratio (`SamplingRatio`). A child span follows its parent's decision, so the gateway's choice applies all the way down and no trace is kept half-sampled.

### Metrics

- **ASP.NET Core:** request rate, error rate, duration (the RED metrics), per route.
- **HttpClient:** the same metrics for outgoing calls, including the gateway → host hop.
- **Runtime:** GC, heap, thread pool, exceptions.

Resource attributes on every signal:
- `service.name` = `Observability:ServiceName`
- `service.instance.id` = `Observability:HostName`

---

## 4. Configuration

The `Observability` section. Defaults are in `ObservabilityOptions`, and a blank value keeps the default.

| Key | Default | Meaning |
|---|---|---|
| `Enabled` | `false` | Master switch. `false` or absent registers nothing. |
| `ServiceName` | `trustbank-cbs` (gateway: `cbs-gateway`) | OTel `service.name` — separates services in Grafana |
| `HostName` | machine name | OTel `service.instance.id`; also the `Host` dimension on request logs |
| `SamplingRatio` | `1.0` | Head sampling, from 0.0 to 1.0 (values outside are clamped). `1.0` suits dev. |
| `Otlp:Endpoint` | `http://localhost:4317` | Collector endpoint (OTLP gRPC) |

As environment variables (for compose, IIS `web.config` or a shell), use a double underscore: `Observability__Enabled=true`, `Observability__Otlp__Endpoint=http://…:4317`.

What each file sets:
- `TflCbs.Host.Main/appsettings.json` sets `Enabled: false` explicitly, so a local `dotnet run` emits nothing.
- Each thin host's `appsettings.json` sets only `HostName` (`hr-host`, `lockers-host`, …).

---

## 5. How to turn it on

Start the backend first (every shape except the combined compose command below needs it running):

```bash
docker compose -f compose.observability.yaml up -d     # Grafana → http://localhost:3000
```

### Local `dotnet run`

```powershell
$env:Observability__Enabled = "true"
dotnet run --project TflCbs.Host.Main
```

The default endpoint `http://localhost:4317` already points at the container's published port.

### Docker single host / multi-host

Telemetry is **on by default** in both compose files. Bring the app and the backend up together:

```bash
docker compose -f compose.yaml       -f compose.observability.yaml up -d
docker compose -f compose.multi.yaml -f compose.observability.yaml up -d
```

- The app reaches the collector by service name (`http://otel-lgtm:4317`).
- In multi-host, each service gets its own name: `cbs-gateway`, `cbs-default`, `cbs-hr`, `cbs-lockers`, `cbs-retail`, `cbs-admin`, `cbs-inventory`.
- To run without the backend, set `OBSERVABILITY_ENABLED=false`, which silences the exporter.

### IIS (single or farm)

Add the variables to each site's `web.config` `<environmentVariables>`, gateway included:

```xml
<environmentVariable name="Observability__Enabled" value="true" />
<environmentVariable name="Observability__Otlp__Endpoint" value="http://localhost:4317" />
<environmentVariable name="Observability__ServiceName" value="cbs-hr" />
```

> **Watch out:** `dotnet publish` / `deploy-cbs-iis.ps1` regenerate `web.config` and **wipe** these, just as they wipe the connection string. Re-add them after every redeploy. The deploy script does not set them today.

---

## 6. Reading it in Grafana

Open `http://localhost:3000` (dev: anonymous admin).

- **One request's journey:** Explore → **Tempo** → search by service name (or trace ID). The tree shows gateway → host → each `db.execute`, with a duration bar on each span; the slow step is the long bar. Open a DB span to see its `db.statement`.
- **RED / runtime charts:** Explore → **Prometheus**. Examples:
  - `http_server_request_duration_seconds` (histogram: rate, errors via `http_response_status_code`, p95)
  - `http_client_request_duration_seconds`
  - `dotnet_*` runtime series (GC, thread pool, exceptions)
- **Logs → trace:** each log line's correlation ID is the ambient `Activity.Current.Id`, the W3C ID that contains the trace ID. The `Result.Reference` shown to users in error messages is the same value. Copy the trace ID from a log line or error message and look it up in Tempo.

Telemetry in the dev container is **ephemeral**: a restart starts from empty. To keep it, mount a volume at `/data` (commented out in the compose file).

---

## 7. Extending it

- **A new host:** call `builder.Services.AddCbsObservability(builder.Configuration);` in `Program.cs` and give it its own `Observability:HostName`. Nothing else is needed.
- **Custom spans:** create an `ActivitySource` in the module and start activities from it. `AddCbsObservability` only subscribes to the sources it names (ASP.NET Core, HttpClient, `TflOmniDb`), so the new source name must also be added with `.AddSource(...)` there.
- **Custom metrics:** the same pattern with `System.Diagnostics.Metrics.Meter`, plus `.AddMeter(...)` in `AddCbsObservability`. No module has one yet.
- **Module assemblies stay OTel-free.** `System.Diagnostics` is part of the BCL, so a module can emit through `ActivitySource` / `Meter` without referencing any OpenTelemetry package. Only the Framework registration knows about OTLP.

---

## 8. Not built yet

Tracked in [BACKLOG.md](../../BACKLOG.md) (Broader feature backlog):

- **Log export.** Logs stay in local files per node. Shipping them to Loki (or another OTLP log sink) would let you jump from a log line straight to its trace in Grafana.
- **Production back-end.** Today there's only the single dev container.
- **Dashboards and alerting.** No curated dashboards or SLO alerts yet.
- **Business metrics.** No custom metrics yet (logins, maker-checker queue depth, posting throughput).
- **Production `SamplingRatio`.** No value chosen yet.
- **Correlation across browser redirects.** Browsers don't forward `traceparent` across redirects, so a cross-host user journey shows up as separate traces. Join them through the request log's `UserId` / `SessionId` instead (see `RequestLoggingMiddleware`).
