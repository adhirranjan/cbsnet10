# Observability — a plain-language primer

*What "observability" means, the pieces involved, and the dev setup we use to see it — written for someone new to it. This covers the **backend** (where telemetry is collected and viewed). Wiring the app to emit telemetry is a separate step (Phase 2).*

---

## 1. The problem it solves

Right now, when something goes wrong in production, about all we can do is **read the log files** after the fact. That answers *"what happened for this one request?"* — but it can't answer the questions you actually get asked when running a banking system:

- *Is the app getting slower this week?*
- *Which screen is slow — and is it the app, the gateway, or the database?*
- *What's our error rate right now? Are we about to hit a resource ceiling?*

With only logs you find out about problems from **user complaints**, and there's nothing to **alert** on. **Observability** fixes that by adding two more kinds of signal alongside logs, and a place to chart and alert on them. The industry name for the toolkit is **OpenTelemetry (OTel)** — a vendor-neutral standard for producing this data.

---

## 2. The three pillars

Observability = **logs + metrics + traces**. They answer different questions:

| Pillar | Answers | Everyday analogy | This app |
|---|---|---|---|
| **Logs** | *"What happened?"* (individual events) | A diary — one line per thing that happened | ✅ **We have this** (TflLog) |
| **Metrics** | *"How much / how fast / how often?"* (numbers over time) | A car dashboard — speed, fuel, RPM | ❌ Adding it |
| **Traces** | *"Where did the time go?"* (one request's journey) | A parcel-tracking timeline — each stop and how long it sat | ❌ Adding it |

A bit more on the two new ones:

- **Metrics** are just **numbers sampled over time** — e.g. "requests per second", "95% of requests finished under 200 ms", "2% errored". They're cheap and perfect for **dashboards and alerts** ("page me if error rate > 1%").
- **A trace** is the **story of one request as a tree of timed steps** (each step is a "span"). For us a single request might be: `gateway → the HR host → a database query`. The trace shows each step and exactly how long it took — so you can see *the DB query was the slow part*, not guess.

---

## 3. The moving parts (produce → ship → store → view)

Telemetry flows through four jobs. Think of it like mail:

```
  Your app  ──OTLP──▶  Collector  ──▶  Tempo   (stores traces)   ─┐
 (produces the                 └────▶  Prometheus (stores metrics) ─┴──▶  Grafana
  data)                                                                   (you look here)
```

| Job | What it does | Mail analogy |
|---|---|---|
| **Collector** | Receives all telemetry from the app at one address, then sorts it — traces to the trace store, metrics to the metric store | The post office sorting centre |
| **Tempo** | The **trace** database — stores and lets you search the request "stories" | A filing cabinet for parcel-tracking histories |
| **Prometheus** | The **metrics** database — stores the numbers over time | A ledger of readings |
| **Grafana** | The **UI** — the single web page where you actually *look* at traces and metrics, build dashboards, and set alerts | The front desk where you view everything |

**Why separate pieces?** Because traces and metrics are **different shapes of data** (a trace is a timed tree; a metric is a number over time), each gets a purpose-built store. The Collector unifies *receiving*; Grafana unifies *viewing*. In **production** you'd run these as four separate, independently-scaled services.

**"OTLP"** (mentioned on the arrows) is just the **standard format/protocol** the app uses to send telemetry — like a shipping label everyone understands. Because it's a standard, we can swap any piece later without changing the app.

---

## 4. The dev shortcut: one container instead of four

For **development**, running four services is overkill. Grafana publishes an all-in-one image, **`grafana/otel-lgtm`**, that bundles the Collector + Tempo + Prometheus + Grafana into a **single container**, already wired together. (The name **LGTM** = **L**oki, **G**rafana, **T**empo, **M**imir/Prometheus — the Grafana stack.)

So our dev backend is literally one service. You start it, point the app at it, and open Grafana — nothing to hand-configure.

| Port | What | Use |
|---|---|---|
| **4317** | OTLP over gRPC | where the app (Phase 2) sends telemetry |
| **4318** | OTLP over HTTP | same, HTTP flavour (handy for `curl` tests) |
| **3000** | Grafana web UI | where **you** open a browser to look |

Start / stop it (from the solution root):

```bash
docker compose -f compose.observability.yaml up -d      # start
docker compose -f compose.observability.yaml down        # stop
```

Then open **http://localhost:3000** for Grafana.

---

## 5. How you'll actually use it

Once the app is emitting (Phase 2):

- **See a request's trace:** Grafana → **Explore** → pick the **Tempo** data source → find a recent trace. You'll see the span tree — `gateway → host → database query` — with a duration bar on each, so the slow step is obvious at a glance.
- **See the metrics:** Grafana → **Explore** → **Prometheus** (or a dashboard) → chart request rate, error rate, and latency per endpoint (the "RED" metrics — **R**ate, **E**rrors, **D**uration).
- **Logs and traces line up for free:** our existing log system (TflLog) already tags every log line with the current **trace id** (it's the same value as the `Result.Reference` you already see in error messages). So a log line and its trace point at each other — you can jump from an error log to the exact trace that produced it.

---

## 6. What's built now vs. next

- **Phase 1 (done):** the **backend** (`otel-lgtm`) and this primer. Proven by sending a **synthetic test span** and finding it in Grafana.
- **Phase 2 (done):** the app now emits. A single hook in the database layer (TflOmniDb `CommandLogger`) turns **every** DB call — SQL Server, Oracle, and PostgreSQL alike — into a span; the web hosts and the gateway are wired for traces + RED/runtime metrics; and it's all **config-gated, off by default** (`Observability:Enabled`). The log correlation id already equals the trace id, so logs and traces line up for free. **Verified end-to-end:** exercising the app produces a real **`gateway → host → DB`** trace (the DB call nested under the host request, which is nested under the gateway's proxy span) plus live RED metrics in this same Grafana — proven on the local IIS farm at `https://localhost:8101`.
- **Still ahead (the "ops half"):** a production-grade collector/back-end (not the single dev container), curated dashboards + SLO alerting, and shipping the app **logs** into Loki so a log line deep-links to its trace inside Grafana (the correlation id is already emitted — it just isn't exported to Loki yet).

---

## Glossary

- **OpenTelemetry (OTel)** — the vendor-neutral standard + libraries for producing logs, metrics, and traces.
- **OTLP** — OpenTelemetry Protocol; the wire format the app uses to ship telemetry to the collector (ports 4317/4318).
- **Span** — one timed step in a trace (e.g. "the DB query"). A **trace** is a tree of spans for one request.
- **RED metrics** — **R**ate, **E**rrors, **D**uration — the three highest-value service metrics.
- **Collector** — receives telemetry and routes it to the right stores.
- **Tempo / Prometheus** — the trace store / metrics store.
- **Grafana** — the UI to view traces, metrics, and dashboards, and to alert.
- **LGTM** — Grafana's bundled stack (Loki, Grafana, Tempo, Mimir); `grafana/otel-lgtm` packs it into one dev container.
