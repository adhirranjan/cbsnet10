# Gateway → Backend Scheme: why the gateway calls its backends over **HTTPS**

When you run the multi-host topology (gateway + default host + thin hosts), one config choice trips people up: **over what scheme does the YARP gateway reach its backend hosts — HTTP or HTTPS?** The intuitive answer ("they're on the same box, just use HTTP loopback — simpler, no certs") is **wrong for this app**, and the failure is sneaky: the site works in a browser but the gateway reports the backends as down.

This doc explains exactly why, and documents every way to make HTTP work if you ever need it. **Short answer: use HTTPS backends.**

## 1. The topology

```
browser ──HTTPS──► gateway (cbs-gateway :8101) ──?──► backend hosts:
                                                         cbs-default :8111
                                                         cbs-hr      :8121
                                                         cbs-lockers :8131
                                                         cbs-retail  :8141
                                                         cbs-admin   :8151
```

The gateway (YARP) does two things to each backend:
1. **Proxies** browser requests (`/Hr/*` → `cbs-hr`, catch-all → `cbs-default`, …).
2. **Active health checks** — on a timer (every 10s) it calls each backend's `/health/ready` and pulls the backend out of rotation if it stops returning 2xx.

The `?` in the diagram is the scheme of that gateway→backend hop.

## 2. What each backend does on every request

Every CBS backend host (`TflCbs.Host.Main` and the `TflCbs.Host.*` thin hosts) wires this middleware order in `Program.cs`:

```csharp
app.UseCbsForwardedHeaders(builder.Configuration);  // (1) honour X-Forwarded-* from the gateway
...
app.UseHttpsRedirection();                            // (2) redirect http → https
...
app.MapCbsHealthChecks();                             // /health, /health/ready
```

- **`UseHttpsRedirection`** 307-redirects any request whose `Request.Scheme == "http"` to `https://…`.
- **`UseCbsForwardedHeaders`** rewrites `Request.Scheme` (and `Host`) from the `X-Forwarded-Proto` / `X-Forwarded-Host` headers — **but only when those headers are present and come from a trusted peer** (loopback is trusted by default; see [self-signed-cert.md](self-signed-cert.md) / the multi-host doc for `KnownProxies`).

`UseCbsForwardedHeaders` runs **before** `UseHttpsRedirection` on purpose — so the redirect sees the *forwarded* scheme, not the raw hop scheme.

## 3. The asymmetry — two kinds of requests hit a backend

This is the crux. Two very different callers reach a backend, and they differ in **one header**:

| Caller | Carries `X-Forwarded-Proto`? | `Request.Scheme` after (1) | `UseHttpsRedirection` |
|--------|------------------------------|----------------------------|------------------------|
| **Proxied browser request** (user → gateway `https` → backend) | **Yes** — YARP adds `X-Forwarded-Proto: https` | `https` | no-op ✅ |
| **YARP active health probe** (gateway → `…/health/ready`, a direct timer call) | **No** — it's not a proxied request; YARP doesn't add forwarded headers to its own health probe | *(raw hop scheme)* | depends on hop scheme ⚠️ |

A browser request always carries `X-Forwarded-Proto: https` (the scheme the *browser* used to reach the gateway), so the backend always thinks it's https — regardless of whether the gateway→backend hop was http or https. **The health probe does not.**

## 4. Why HTTP backends break (step by step)

Set the gateway destinations to `http://localhost:8110/` (etc.) and watch the health probe:

1. Gateway health-check client calls `http://localhost:8110/health/ready` — a **direct** HTTP request, no `X-Forwarded-Proto`.
2. `UseCbsForwardedHeaders` finds no forwarded header → leaves `Request.Scheme = "http"`.
3. `UseHttpsRedirection` sees `http` → returns **307 Redirect** to `https://…/health/ready`. (The probe never reaches the health endpoint.)
4. YARP's health policy expects a **2xx**; a **307** is a failure. After `ConsecutiveFailures`, the backend is marked **Unhealthy**.
5. The gateway stops routing to it → every request for that cluster returns **503**.

Meanwhile the **browser path still works** (it carries the header), so a quick manual click-through looks fine — until the health checks trip and the cluster drops. That's what makes this failure sneaky: it's not a startup error, it's a delayed 503 from a health subsystem, on a backend that "works when I test it directly."

> The dev topology (`dotnet run`) never hit this because its gateway `appsettings.Development.json` already points at **HTTPS** backend ports (7100/72–75xx) — it just needed `DangerousAcceptAnyServerCertificate` because the ASP.NET dev cert isn't trusted.

## 5. The fix — HTTPS backends (what we use)

Point the gateway destinations at the backends' **HTTPS** ports:

```jsonc
// gateway appsettings.Production.json
"ReverseProxy": { "Clusters": {
  "cbs-default":         { "Destinations": { "default-host":        { "Address": "https://localhost:8111/" } } },
  "hr-host":             { "Destinations": { "hr-thin":             { "Address": "https://localhost:8121/" } } },
  "lockers-host":        { "Destinations": { "lockers-thin":        { "Address": "https://localhost:8131/" } } },
  "retailbanking-host":  { "Destinations": { "retailbanking-thin":  { "Address": "https://localhost:8141/" } } },
  "administration-host": { "Destinations": { "administration-thin": { "Address": "https://localhost:8151/" } } }
}}
```

Now:
- The backend receives the request (and the health probe) over **https** → `Request.Scheme == "https"` regardless of any header → `UseHttpsRedirection` **never fires** → `/health/ready` returns **200**. Health checks are green.
- The gateway must **trust the backend's certificate**. Our single self-signed cert is installed in **`LocalMachine\Root`** (see [self-signed-cert.md](self-signed-cert.md)), and .NET's HTTP client validates against the machine store on Windows — so the gateway trusts it, hostname `localhost` matches the cert SAN, and **no `DangerousAcceptAnyServerCertificate` is needed** (that flag disables cert validation entirely and is dev-only).

> **Reuse the destination *key*.** The base `appsettings.json` names each destination (`default-host`, `hr-thin`, …). Keep the same key in the Production override so you *replace the Address* — a new key would *add a second destination* and YARP would load-balance onto the (dead) dev-port one.

**Cost:** zero code changes, active health checks stay on, it matches the dev topology, and it's actually *more* secure (the internal hop is encrypted too). The only prerequisite — a trusted cert — you already have.

## 6. Alternatives — making HTTP-loopback backends work (NOT used here)

If you ever deliberately want plain-HTTP backends (e.g. a proxy that terminates TLS and you don't want internal TLS), the *only* thing to solve is the health-probe 307. Options, best-to-worst for this codebase:

### (a) Drop `UseHttpsRedirection()` on the backends — cleanest, but a code change
A host that **always** sits behind a TLS-terminating gateway arguably shouldn't self-redirect at all: the gateway owns TLS, the backend speaks plain HTTP internally, and `ForwardedHeaders` still sets `Request.Scheme = https` for URL/cookie generation (so `returnUrl` and the `Secure` cookie flag stay correct).

```csharp
// Program.cs — remove (or guard) this line on backends that only run behind the gateway:
// app.UseHttpsRedirection();
```
- **Pro:** HTTP loopback works, active health checks intact, simplest runtime.
- **Con:** a code change; the host no longer forces HTTPS if hit **directly** (fine behind a gateway, weaker standalone). If the *same* project also runs standalone (e.g. `TflCbs.Host.Main` as `cbs-single`), you'd need to gate it by config.

### (b) Disable active health checks — config-only, but you lose proactive detection
```jsonc
"Clusters": { "hr-host": { "HealthCheck": { "Active": { "Enabled": false } } } }
```
- **Pro:** no code change; no HTTP probe → no 307. Browser requests still work.
- **Con:** the gateway no longer proactively pulls a dead backend out; it discovers failure **passively** — a real user request fails and returns 502/retries. Slower failover, worse observability.

### (c) Exclude `/health` from the redirect — surgical code change
```csharp
app.UseWhen(
    ctx => !ctx.Request.Path.StartsWithSegments("/health"),
    branch => branch.UseHttpsRedirection());
```
- **Pro:** keeps HTTPS-redirect for real traffic **and** active health checks over HTTP.
- **Con:** a code change on every backend; easy to forget on a new host.

### What does *not* work
- **Injecting `X-Forwarded-Proto: https` onto YARP's health probe** — there's no clean per-cluster knob to add a header to the active health request.
- **Teaching the probe to treat 307 as healthy** — requires a custom `IActiveHealthCheckPolicy`; more work than just using HTTPS.

## 7. Decision matrix

| Approach | Code change? | Active health checks | Internal hop encrypted | Verdict |
|----------|:------------:|:--------------------:|:----------------------:|---------|
| **HTTPS backends** | No | ✅ | ✅ | **Use this** |
| Drop `UseHttpsRedirection` | Yes | ✅ | ✗ | OK if hosts are gateway-only |
| Disable active health checks | No | ✗ | ✗ | Last resort |
| `UseWhen` exclude `/health` | Yes | ✅ | ✗ | Works, more moving parts |

## 8. Related

- [iis-multi-host.md](iis-multi-host.md) — the multi-host deploy (uses these HTTPS destinations)
- [self-signed-cert.md](self-signed-cert.md) — the trusted cert the gateway validates against
- [single-sign-on.txt](../single-sign-on.txt) — why the gateway exists (one origin for cross-host SSO)
