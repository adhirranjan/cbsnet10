# TrustBank CBS — Port & Project Map

> **Last updated:** 2026-08-01
> One page: which project runs where, what the gateway routes to it, and the everyday commands. See [architecture-overview.txt](architecture-overview.txt) for the full picture.
>
> **NOTE:** §1–2 are the DEV `dotnet run` ports (5xxx/7xxx). For the DEPLOYED IIS + Docker ports (different, so they all coexist), see §5.

## 1. Runnable hosts (dev `dotnet run` ports)

| Project | Role | HTTP | HTTPS |
|---------|------|------|-------|
| `TflCbs.Gateway` | YARP front door — **the entry point** for the multi-host setup | 5100 | 7100 |
| `TflCbs.Host.Main` | Default/full host — all modules; **login authority**; catch-all backend behind the gateway | 5019 | 7225 |
| `TflCbs.Host.Lockers` | Thin host — Lockers only | 5200 | 7200 |
| `TflCbs.Host.Hr` | Thin host — Hr only (State/District/Taluka, DiscipAction) | 5300 | 7300 |
| `TflCbs.Host.RetailBanking` | Thin host — RetailBanking only | 5400 | 7400 |
| `TflCbs.Host.Administration` | Thin host — Administration only (Module/Role masters) | 5500 | 7500 |

**Port pattern:** HTTP = `5x00`, HTTPS = `7x00`, paired per host (gateway x=1, Lockers 2, Hr 3, RetailBanking 4, Administration 5; the default host predates the pattern at 5019/7225).

## 2. Gateway routing (`TflCbs.Gateway/appsettings.json`)

| Path prefix | Backend |
|-------------|---------|
| `/Lockers/*` + `/_content/TflCbs.Modules.Lockers.Web/*` | Lockers host (5200/7200) |
| `/Hr/*` + `/_content/TflCbs.Modules.Hr.Web/*` | Hr host (5300/7300) |
| `/RetailBanking/*` + `/_content/TflCbs.Modules.RetailBanking.Web/*` | RetailBanking host (5400/7400) |
| `/Administration/*` + `/_content/TflCbs.Modules.Administration.Web/*` | Administration host (5500/7500) |
| everything else (`/Account`, `/Modules`, `/Home`, `/Bank/*`, shared `/_content`, …) | default host (5019/7225) |

Base config targets the HTTP backends; `appsettings.Development.json` overrides every cluster to the HTTPS ports (+ dev-cert trust), so a plain `dotnet run` fronts the whole topology over HTTPS.

## 3. Libraries (no ports — compiled into the hosts)

| Layer | Projects |
|-------|----------|
| Domain web RCLs (screens) | `TflCbs.Modules.{Bank,Hr,Lockers,RetailBanking,Administration}.Web` |
| Core web RCLs | `TflCbs.Core.Authentication.Web` (login/logout), `TflCbs.Core.Shell.Web` (Home/Modules/Error) |
| Shared web assets | `TflCbs.Web.Shared` (layout, partials, `wwwroot` → `/_content/TflCbs.Web.Shared/`) |
| Framework | `TflCbs.Framework` (session, tokens, access guard, search, DataAccess wiring) |
| Services (business modules) | Core, always registered: `TflCbs.Modules.General`, `TflCbs.Modules.Reference`, `TflCbs.Core.Authentication` · Domains, gated by `Modules:Enabled`: `TflCbs.Modules.{Accounts,Administration,Clearing,HR,Lockers,RetailBanking}` · Shared: `TflCbs.Abstractions`, `TflCbs.Modules.General.Contracts` |
| Data / logging | `TflCbs.Entities`, `TflOmniDb` (bare DLL), `TflOmniLog` |
| Tests / demos | `TflCbs.Tests`, `TflCbs.Demo`, `TflCbs.ArchTests`, `TflOmniLog.*` |

## 4. Quick reference

| | |
|---|---|
| **Use the app (multi-host)** | Browse `https://localhost:7100` (gateway), log in, jump modules freely — one login (SSO). |
| **Everyday solo dev** | Run only `TflCbs.Host.Main` ("https" profile) → `https://localhost:7225`. No other processes. |
| **Full cluster** | `scripts\start-cbs-hosts.bat` — stops leftovers, builds once, launches all 6 hosts (default host on the "https (shared-sso)" profile, thin hosts + gateway on "https"), waits for every health endpoint. Manual equivalent: run each project with those profiles in any order (the gateway health-checks and recovers). |
| **Health endpoints** | every host: `/health` (live), `/health/ready` (DB); gateway: `/gateway/health`. |
| **STOP BEFORE BUILDING** | `scripts\stop-cbs-hosts.bat` — stops every CBS host on the ports above (only processes matching our names), then confirms all ports are free. |
| **Login authority rule** | A host whose `Auth:LoginUrl` is an absolute URL on another origin defers login there (thin hosts → gateway); relative `LoginUrl` = serves login itself (the default host). See [single-sign-on.txt](single-sign-on.txt). |

## 5. Deployment ports (IIS & Docker) — distinct from the dev ports above

The dev `dotnet run` ports (§1–2, 5xxx/7xxx) are for local dev only. The deployed hosts use different, non-clashing ports so IIS and Docker can run side by side. (Redis dev container: 6379.)

### IIS (this machine)

| Deployment | Site | Entry / port(s) | Path |
|------------|------|-----------------|------|
| Single host | `cbs-single` | http 8080 / https 8081 | `D:\publish\single` |
| Multi host | `cbs-gateway` | http 8100 / **https 8101 (PUBLIC)** | `D:\publish\multi\gateway` |
| | `cbs-default` | http 8110 / https 8111 | `D:\publish\multi\default` |
| | `cbs-hr` | http 8120 / https 8121 | `D:\publish\multi\hr` |
| | `cbs-lockers` | http 8130 / https 8131 | `D:\publish\multi\lockers` |
| | `cbs-retail` | http 8140 / https 8141 | `D:\publish\multi\retail` |
| | `cbs-admin` | http 8150 / https 8151 | `D:\publish\multi\admin` |

> **Both** ports are bound on every site: `deploy-cbs-iis.ps1` always creates the site on its http port and *adds* the https binding when `-CertThumbprint` is passed (without it you get http only). The gateway proxies to the backends over **https** — the scheme it writes into the gateway's `appsettings.Production.json` follows whether the cert was supplied. The http backend ports stay reachable directly, so treat them as a bring-up/diagnostic path, not a route anyone should use: only `cbs-gateway` is meant to be public.

### IIS gateways fronting Docker

| Site | Entry / port(s) | Fronts |
|------|-----------------|--------|
| `cbs-docker-gw` | **https 8092 (PUBLIC)** | Docker single-host container (`http://localhost:8090`) — a 2nd YARP instance, one catch-all route, reuses the `TrustBankCBS-SelfSigned` cert. Standalone (its own DP key ring) — no SSO with the IIS farm. See [deploy/docker-single-host.md](deploy/docker-single-host.md). |
| *(RESERVED)* | https 8093 | Future: IIS YARP fronting the Docker multi-host gateway (host 8091). Pattern = one IIS gateway per Docker deployment (single → 8092, multi → 8093). Not built yet; port held so nothing claims it. |

### Docker (host port → container 8080)

| Deployment | Published | File |
|------------|-----------|------|
| Single host | host 8090 → 8080 | `compose.yaml` — browse `http://localhost:8090` (direct HTTP), or `https://localhost:8092` via `cbs-docker-gw` |
| Multi host | gateway (ONLY published) host 8091 → 8080 | `compose.multi.yaml` — browse `http://localhost:8091` (plain HTTP; local `compose.multi.local.yaml` overlay sets `SecurePolicy=SameAsRequest`). Backends have **no** host ports; the gateway reaches them by compose service name at `http://<service>:8080/` (destinations set via the mounted `docker/gateway.multi.appsettings.json`, **not** env vars — hyphenated `ReverseProxy__…` names get dropped). **HTTPS:** terminate TLS **on the gateway** (single hop — `compose.multi.https.yaml`, browse `https://localhost:8091`; verified), or front with a TLS edge / the reserved **8093** IIS gateway (double hop). |

**Why these numbers:** Docker 8090/8091 and IIS 80xx/81xx are all picked to avoid each other AND the dev 5xxx/7xxx — so single+multi and IIS+Docker never clash. (Docker single = 8090; Docker multi gateway = 8091.) The Docker containers are HTTP-only — TLS terminates outside them — so IIS-hosted YARP gateways in the 809x band put HTTPS in front: 8092 fronts the single-host container (built), 8093 reserved for the multi-host gateway (future).

Detail: [deploy/iis-single-host.md](deploy/iis-single-host.md), [deploy/iis-multi-host.md](deploy/iis-multi-host.md), [deploy/docker-single-host.md](deploy/docker-single-host.md), [deploy/docker-multi-host.md](deploy/docker-multi-host.md).
