# Deploy to IIS — Multi Host (gateway + default host + thin hosts)

The scale-out shape: the YARP **gateway is the one public origin**; behind it the default host and up to four thin per-module hosts each run as their own IIS site. All hosts share one identity via cross-host SSO.

> Read [iis-single-host.md](iis-single-host.md) first — this doc only adds the multi-host specifics. See also [single-sign-on.txt](../single-sign-on.txt) and [port-map.md](../port-map.md).

## Deployment checklist (run in order)

1. ☐ **Prerequisites** — the single-host prereqs (§ that doc) on the box (IIS + Hosting Bundle + cert); **create the two shared SSO tables once** — `CBS_DATAPROTECTIONKEYS`, `CBS_SESSIONREVOCATIONS` (§2).
2. ☐ **Publish** each host you'll run (gateway + default + thin hosts) to its own folder (§3).
3. ☐ **Per-host config** (§3) — **default** = login authority (relative `LoginUrl`) + `KeyRing=TflOmniDb` + `SessionRevocation=TflOmniDb` + trimmed `Modules:Enabled`; **thin hosts** = absolute `LoginUrl`→gateway + `Misc`/`Accounts` in `Modules:Enabled`; **all** = `Cookie:SecurePolicy=Always`, `ForwardedHeaders:Enabled`.
4. ☐ **Gateway config** (§4) — cluster Destinations → the backends' **HTTPS** ports (not http — [gateway-backend-scheme.md](gateway-backend-scheme.md)); gateway trusts the cert via `LocalMachine\Root`.
5. ☐ **Create one IIS site per host** (§5) — app pool (No Managed Code, **1 worker**) + **HTTPS-only** binding + the shared cert; `ASPNETCORE_ENVIRONMENT=Production` in **each** site's `web.config`.
6. ☐ **Verify** (§6) — each backend `/health/ready` 200 → gateway `/gateway/health` 200 → unauth area → **302** to login on the **gateway** origin → login once → cross areas with no re-login → global logout revokes everywhere.

Each step links to its detailed section below.

## 1. The topology

```
Public HTTPS  ->  GATEWAY (TflCbs.Gateway)  ->  backends (private):
   path /Hr/*             -> Host.Hr
   path /Lockers/*        -> Host.Lockers
   path /RetailBanking/*  -> Host.RetailBanking
   path /Administration/* -> Host.Administration
   (each also routes /_content/TflCbs.Modules.<Area>.Web/*)
   everything else        -> default host (TflCbs.Host.Main)
```

Deploy exactly the hosts you need. The **minimum viable multi-host is the gateway + the default host**; add thin hosts to peel modules off. You do not have to run all six.

**Login authority:** one host mints the `CbsAuth` cookie (the default host). Thin hosts **defer** login to the gateway (`Auth:LoginUrl`) and only **validate** the cookie. Do not stand up two login authorities.

## 2. The three preconditions for cross-host SSO

Every participating host **must** agree on all three, or a cookie minted by one host won't be honoured by another:

| # | Precondition | Config |
|---|--------------|--------|
| A | **Shared Data Protection key ring** — lets any host *decrypt* any other host's cookie. FileSystem keys do **not** work across hosts unless the folder is literally shared — use TflOmniDb. | `DataProtection: { ApplicationName: "TrustBankCBS", KeyRing: "TflOmniDb" }` (same on every host; keys in `CBS_DATAPROTECTIONKEYS`) |
| B | **Shared revocation store** — a logout on any host kills the session everywhere within the ~30s cache window. | `Auth: { SessionRevocation: "TflOmniDb" }` (keys in `CBS_SESSIONREVOCATIONS`) |
| C | **One origin** — the gateway is the only origin the browser sees, so the cookie has a single domain. Backends are reached only via the gateway. | (topology) |

Create the two shared tables **once** (DDL in `Framework\Infrastructure\DataProtectionKeyEntity.cs` and `Framework\Auth\SessionRevocation.cs`; SQL Server + Oracle both provided).

## 3. Per-host production config

Publish each project separately:

```bash
dotnet publish TflCbs.Gateway             -c Release -o D:\publish\multi\gateway
dotnet publish TflCbs.Host.Main            -c Release -o D:\publish\multi\default
dotnet publish TflCbs.Host.Hr             -c Release -o D:\publish\multi\hr
dotnet publish TflCbs.Host.Lockers        -c Release -o D:\publish\multi\lockers
dotnet publish TflCbs.Host.RetailBanking  -c Release -o D:\publish\multi\retail
dotnet publish TflCbs.Host.Administration -c Release -o D:\publish\multi\admin
```

> **Layout on this server.** These paths/ports are chosen to **coexist with the already-deployed single host** (`cbs-single`, `D:\publish\single`, 8080/8081) — see §5. Build `TflCbs.Entities` first if entities changed (bare-DLL HintPath).

**What each publish folder contains** (they are deliberately different):

| Host | Domain web RCL(s) it carries | Also carries |
|------|------------------------------|--------------|
| Default (`TflCbs.Host.Main`) | **all five on disk** — `TflCbs.Modules.{Bank,Hr,Lockers,RetailBanking,Administration}.Web.dll` — but *which actually run* is set by **`Modules:Enabled`** (trim to core + un-peeled; see note ↓) | full stack: `TflCbs.Framework`, `TflCbs.Web.Shared`, `TflCbsServices`, `TflCbs.Core.Authentication`, `TflCbs.Core.{Authentication,Shell}.Web`, `TflOmniLog`, `TflCbs.Entities` + bare `TflOmniDb`/`TflSecurityCrypto` + ADO.NET drivers |
| `Host.Hr` | **only** `TflCbs.Modules.Hr.Web.dll` | same full stack as above (Framework, Web.Shared, Services, Core.Authentication, both core `.Web` RCLs, TflOmniLog, TflCbs.Entities, bare DLLs, drivers) |
| `Host.Lockers` | **only** `TflCbs.Modules.Lockers.Web.dll` | " |
| `Host.RetailBanking` | **only** `TflCbs.Modules.RetailBanking.Web.dll` | " |
| `Host.Administration` | **only** `TflCbs.Modules.Administration.Web.dll` | " |
| `TflCbs.Gateway` | **none** | minimal: `TflCbs.Gateway.dll` + `Yarp.ReverseProxy.dll` only — **no** CbsFramework, services, domain RCLs, bare DLLs, or DB drivers (it's a pure proxy) |

(For the full breakdown of the "full stack" assemblies, see [iis-single-host.md §2](iis-single-host.md).)

> **"Carries the DLL" ≠ "serves that module".** The table above is what lands **on disk** — and the default host is the *same `TflCbs.Host.Main` project as the single host*, so it ships all five domain RCLs. But three independent layers decide whether a module actually runs there:
>
> | Layer | Controlled by | Default host, for a peeled module (e.g. Hr) |
> |-------|---------------|---------------------------------------------|
> | On disk | `.csproj` ProjectReference | present (`TflCbs.Modules.Hr.Web.dll`) |
> | Active at runtime | `Modules:Enabled` + the `if (ModuleOn(...)) AddApplicationPart(...)` gate in `Program.cs` | **only if enabled** |
> | Receives traffic | the **gateway** routing table | **never** — `/Hr/*` routes to `Host.Hr` |
>
> In multi-host the default host is the **catch-all + core host**: the gateway peels off only `/Hr`, `/Lockers`, `/RetailBanking`, `/Administration`, and **everything else falls through to it** — `/Account/Login` (it's the login authority), `/`, `/Home`, `/Modules`, `/Error`, and any area **not** peeled into a thin host (e.g. `/Bank/ReferenceCache`). So it's genuinely needed — for *those* responsibilities, not for the peeled modules.
>
> **Recommendation — trim `Modules:Enabled` on the default host** to core + the un-peeled domains only (below), so it doesn't waste startup/memory activating Hr/Lockers/etc. controllers that the gateway never routes to it. The DLLs still sit unused on disk (harmless); to drop them too you'd remove those ProjectReferences from `TflCbs.Host.Main.csproj` — but that would stop it being the single-host full app, so it's left in.

**Default host (`TflCbs.Host.Main`) — the login authority + catch-all:**

```jsonc
"DataProtection": { "ApplicationName": "TrustBankCBS", "KeyRing": "TflOmniDb" },
"Auth": {
  "LoginUrl": "/Account/Login",              // relative — serves its own login
  "SessionRevocation": "TflOmniDb",
  // AUTHORITY (host AND port), e.g. "cbs.bank.local:8101" — matched against Uri.Authority.
  // Omit the port only when it is the scheme default (443 for https), because Uri.Authority
  // omits it too. Host alone will NOT match a ported origin.
  "AllowedReturnHosts": [ "<public-gateway-host>:<gateway-port>" ],
  "Cookie": { "SecurePolicy": "Always" }
},
"ForwardedHeaders": { "Enabled": true, "KnownProxies": [ "<gateway-ip>" ] },
// core + only the domains NOT peeled into a thin host (Bank has no thin host).
// Use "*" only if you deliberately want the default host to also serve the peeled areas.
"Modules": { "Enabled": [ "General", "Bank", "Authentication", "Misc", "Accounts" ] },
"Database": { "ConnectionStrings": { "SqlServer": "<prod>" } }
```

**Each thin host (`Host.Hr` / `Lockers` / `RetailBanking` / `Administration`):**

```jsonc
"DataProtection": { "ApplicationName": "TrustBankCBS", "KeyRing": "TflOmniDb" },
"Auth": {
  "LoginUrl": "https://<public-gateway-host>/Account/Login",  // ABSOLUTE — defers to authority
  "SessionRevocation": "TflOmniDb",
  // Dead config on a thin host — it defers to the authority before ever evaluating the
  // guard. Only the authority (above) needs it. Harmless, kept for symmetry.
  "AllowedReturnHosts": [ "<public-gateway-host>:<gateway-port>" ],
  "Cookie": { "SecurePolicy": "Always" }
},
"ForwardedHeaders": { "Enabled": true, "KnownProxies": [ "<gateway-ip>" ] },
"Modules": { "Enabled": [ "<Domain>", "General", "Authentication", "Misc", "Accounts" ] },
"Database": { "ConnectionStrings": { "SqlServer": "<prod>" } }
```

> `Misc` + `Accounts` are **required** — the core shell/login controllers inject their services; without them the host 500s rendering `/Modules` or login.

> **`Auth:LoginUrl` and `Auth:AllowedReturnHosts` are now set by the deploy script** (2026-08-01). They used to be manual, and the committed thin-host default points at the **dev** gateway (`http://localhost:5100`), so a deployed farm passed every health check and still could not log anyone in — the 302 went to a port nothing listens on. `deploy-cbs-iis.ps1 -Mode multi` now derives both from the same topology + scheme it uses for the YARP destinations, and **merges** them into each site's `appsettings.Production.json` (your connection string in that file is preserved). Pass **`-PublicHost <hostname>`** — it defaults to `localhost`, which is correct only for a local bring-up, because this value ends up in a 302 sent to a **user's browser**: a remote client redirected to `localhost` lands on its own machine. The script warns when it is left at the default.

`ForwardedHeaders:KnownProxies` **must** list the gateway's IP in production — it is how each backend learns the real gateway origin (so returnUrls and cookie `Secure` flags are correct) without letting arbitrary clients spoof the `X-Forwarded-*` headers. (Dev leaves it loopback-default.) On an IIS farm the gateway's address is stable, so pin it here; `ForwardedHeaders:KnownNetworks` (CIDR array, e.g. `"10.20.0.0/24"`) exists for the case where it isn't — prefer the exact IP, since a range trusts every peer in it.

It is **not only** about URLs: an untrusted proxy's `X-Forwarded-For` is discarded, so `Connection.RemoteIpAddress` stays the gateway's on every backend. That collapses each per-client control onto one identity — the **login rate limiter** (`Security:LoginRateLimit`) throttles all users as a single bucket, the DB's per-IP lockout (`b_LoginPolicy.RemoteHostLoginAttempt`) counts everyone's failures against one row, and request logs name the gateway as the caller. A malformed entry in either list now **fails the host at startup** rather than being silently skipped, and a *missing* one is caught at runtime: a backend that receives an `X-Forwarded-For` from an untrusted peer discards it and logs one `Security`-category warning per host start (`X-Forwarded-For arrived …`). Since an IIS site's trust list is hand-maintained — and anything placed in `web.config` `<environmentVariables>` is wiped when a publish regenerates that file (the `appsettings.Production.json` route in §3 survives) — that warning is the cheapest way to notice a farm running without it.

## 4. Gateway config (`TflCbs.Gateway/appsettings.json`)

The gateway is a plain YARP reverse proxy (no CbsFramework, no DB). Its `ReverseProxy` section maps each `/<Area>/*` route to a cluster; each cluster's Destination is a **backend address**. The dev config points at `http://localhost:5x00/` (the `dotnet run` ports) — for the IIS layout point each cluster at its site's **HTTPS port** (§5):

```jsonc
"Clusters": {
  "cbs-default":         { "Destinations": { "default-host":        { "Address": "https://localhost:8111/" } } },
  "hr-host":             { "Destinations": { "hr-thin":             { "Address": "https://localhost:8121/" } } },
  "lockers-host":        { "Destinations": { "lockers-thin":        { "Address": "https://localhost:8131/" } } },
  "retailbanking-host":  { "Destinations": { "retailbanking-thin":  { "Address": "https://localhost:8141/" } } },
  "administration-host": { "Destinations": { "administration-thin": { "Address": "https://localhost:8151/" } } }
}
```

- **Use the backends' HTTPS ports** — **not** plain HTTP. Backends run `UseHttpsRedirection`, and YARP's *active health check* is a direct call with no `X-Forwarded-Proto`, so an HTTP probe gets 307'd → the backend is marked Unhealthy → 503 (proxied browser requests still work, so it's a sneaky failure). HTTPS backends avoid it entirely. **Full explanation: [gateway-backend-scheme.md](gateway-backend-scheme.md).**
- The gateway **validates the backend cert** against `LocalMachine\Root`, where our self-signed cert already lives (see [self-signed-cert.md](self-signed-cert.md)) — so **no `DangerousAcceptAnyServerCertificate`** (that dev-only flag disables validation). `localhost` is in the cert SAN, so the name matches.
- **Keep the base config's destination *keys*** (`default-host`, `hr-thin`, `lockers-thin`, `retailbanking-thin`, `administration-thin`) in the override so you *replace the Address* — a new key would *add* a second (dead, dev-port) destination.
- Backends can also be separate machines — the destination Address just has to be reachable from the gateway.
- Each cluster active health-checks `/health/ready` (already configured, 10s interval).
- `RateLimit` (`PermitPerWindow`/`WindowSeconds`, default 600/60) is per-client-IP at the gateway.
- Only deploy the clusters/routes for the hosts you actually run; drop the rest so the gateway doesn't health-check dead backends.

## 5. IIS sites

Create **one IIS site per published host**, each with its own app pool ("No Managed Code", **Maximum Worker Processes = 1** — the single-process rule from the single-host doc applies to *every* host: in-memory session/nonce stores).

Layout — non-default ports, chosen to **coexist with the single host** (`cbs-single` on 8080/8081 stays untouched):

Bind each site **HTTPS-only**; the HTTP column is reserved (unused).

| Site / app pool | HTTPS (bound) | HTTP (reserved) | Path | Exposure |
|-----------------|---------------|-----------------|------|----------|
| `cbs-gateway` | **8101** | 8100 | `D:\publish\multi\gateway` | **PUBLIC** (entry: `https://<host>:8101`) |
| `cbs-default` | **8111** | 8110 | `D:\publish\multi\default` | private (login authority) |
| `cbs-hr` | **8121** | 8120 | `D:\publish\multi\hr` | private |
| `cbs-lockers` | **8131** | 8130 | `D:\publish\multi\lockers` | private |
| `cbs-retail` | **8141** | 8140 | `D:\publish\multi\retail` | private |
| `cbs-admin` | **8151** | 8150 | `D:\publish\multi\admin` | private |

- **Only the gateway is public** — expose `https://<host>:8101`; firewall the backend ports (811x–815x) off from outside.
- **The gateway's cluster Destinations use the backends' HTTPS ports** (the **bold** column: 8111/8121/8131/8141/8151) — matching §4. Bind each backend site **HTTPS-only** (the HTTP column is reserved but unused); this also sidesteps the HTTP health-check 307 issue ([gateway-backend-scheme.md](gateway-backend-scheme.md)).
- **Reuse the single self-signed cert** (SAN: `localhost` + the machine name + `127.0.0.1`) on every HTTPS binding — [self-signed-cert.md](self-signed-cert.md). The `cbs-single` cert already covers these hostnames.
- The gateway needs no ASP.NET Core hosting extras beyond the hosting bundle; it is itself an ASP.NET Core app hosted by ANCM like the others.
- Per-host `Logs\` write permission for each app-pool identity.
- **Environment per site** — set `ASPNETCORE_ENVIRONMENT=Production` in **each site's own `web.config`** (as in [iis-single-host.md §4](iis-single-host.md)), never as a machine-wide/system variable. With all six sites co-located on one box, a system-level variable would flip every one of them at once — the per-app `web.config` keeps each isolated. (Data Protection keys are the opposite: they are *deliberately shared* across the hosts via `KeyRing=TflOmniDb` — §2 — so don't try to isolate those.)

## 6. Verification (through the gateway only)

1. Each backend directly (HTTPS): `curl -k https://localhost:8121/health/ready` (hr), `…:8111` (default), `…:8131/8141/8151` → 200.
2. Gateway health: `curl -k https://<host>:8101/gateway/health` → 200.
3. Through the gateway, unauthenticated GET a thin-host screen: `https://<host>:8101/Administration/Module` → **302** to the central login (returnUrl points at the **gateway** origin `…:8101` — if it points at a backend port like `:8150`, `ForwardedHeaders`/`KnownProxies` is wrong).
4. Log in once → land on the requested screen, **no re-login**.
5. Navigate across areas (`/Hr/State`, `/Lockers/...`, `/RetailBanking/...`) — all served without re-login (shared key ring working).
6. Global logout → re-hit any area → 302 back to login (revocation working).

## 7. Troubleshooting (multi-host specific)

| Symptom | Fix |
|---------|-----|
| Re-login every time you cross hosts | Not a shared key ring. Every host needs the **same** `DataProtection:ApplicationName` **and** `KeyRing=TflOmniDb` pointing at the **same** DB. Confirm `CBS_DATAPROTECTIONKEYS` has rows. |
| returnUrl / redirects show a backend port instead of the gateway | `ForwardedHeaders:Enabled` must be true **and** `KnownProxies` must include the gateway IP on that backend. |
| Thin host 500s on `/Modules` or `/Account/Login` | Missing `Misc`/`Accounts` in that host's `Modules:Enabled`. |
| Logout doesn't propagate | `Auth:SessionRevocation` must be `TflOmniDb` on every host (not `InMemory`). |
| 502 at the gateway for one area | That backend is down or its cluster Destination Address is wrong; check `/health/ready` on the backend directly. If you switched the destination to **http**, the active health check gets 307'd and the backend is marked unhealthy — use HTTPS ([gateway-backend-scheme.md](gateway-backend-scheme.md)). |
| Redirect loop at login | Two login authorities, or a thin host's `Auth:LoginUrl` points at itself. Only the default host has a relative `LoginUrl`; thin hosts point at the gateway. |

## 8. Related docs

- [iis-single-host.md](iis-single-host.md) — start here (publish, app pool, web.config)
- [gateway-backend-scheme.md](gateway-backend-scheme.md) — why the gateway calls backends over HTTPS
- [self-signed-cert.md](self-signed-cert.md) — the cert reused on every binding
- [docker-multi-host.md](docker-multi-host.md) — same topology in containers
- [single-sign-on.txt](../single-sign-on.txt) — the SSO mechanism in depth
- [port-map.md](../port-map.md) — ports & routing table (dev + deploy)
