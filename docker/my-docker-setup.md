# My Docker Setup — TrustBank CBS (inventory & how to operate)

A practical reference for **what Docker artifacts this repo has and how to work with them**. For the deep deployment walkthroughs see [../deploy/docker-single-host.md](../deploy/docker-single-host.md) and [../deploy/docker-multi-host.md](../deploy/docker-multi-host.md); for ports see [../port-map.md](../port-map.md).

> **One line:** one parameterized `Dockerfile` builds every host; `compose.yaml` runs the app as **one** container (single-host, port 8090), `compose.multi.yaml` runs it as **six** containers behind a gateway (multi-host, port 8091). TLS terminates *outside* the containers.

---

## 1. Files in the repo

| File | Purpose |
|------|---------|
| `Dockerfile` | **One** multi-stage build for **every** host. Parameterized by `ARG PROJECT` — pass `TflCbs.Gateway`, `TflCbs.Host.Main`, `TflCbs.Host.Hr`, … to bake that project's publish output. Installs `curl` (for health checks). Vendors the two external DLLs from `docker/vendor/`. |
| `Dockerfile.dockerignore` | Keeps the build context small (excludes bin/obj, etc.). |
| `compose.yaml` | **Single-host** deployment: 1 app container, host **8090**→8080, FileSystem DP keys (bind mount), `SecurePolicy=Always`. |
| `compose.override.yaml` | **Local-only** overlay for `compose.yaml` (auto-merged) — sets `SecurePolicy=SameAsRequest` + `KnownProxies` so you can browse the single host over plain http and behind the 8092 gateway. |
| `compose.multi.yaml` | **Multi-host** deployment: gateway + default + hr/lockers/retail/admin (6 services). Only the gateway publishes (**8091**). Gateway routing comes from the mounted `docker/gateway.multi.appsettings.json`. |
| `compose.multi.local.yaml` | **Local-only** overlay for `compose.multi.yaml` — sets `SecurePolicy=SameAsRequest` on the app services so login works over plain `http://localhost:8091`. Passed explicitly (`-f … -f …`); **not** auto-merged. |
| `.env` | Secrets/config read by compose (`CBS_SQLSERVER_CONNSTRING`, optionally `CBS_PUBLIC_HOST`). **Not committed** with real values. |
| `docker/gateway.multi.appsettings.json` | Committed. Mounted into the multi-host gateway as `/app/appsettings.Production.json` to point YARP at the compose **service names**. (Must be JSON — env-var overrides with hyphenated keys get dropped; see §7.) |
| `docker/vendor/` | Vendored external DLLs (`TflOmniDb`, `TflSecurityCrypto`) so the build context can stay at the solution root. |

---

## 2. Images

All built from the single `Dockerfile` via `--build-arg PROJECT=…` (compose does this per service).

| Image | ~Size | `PROJECT` | Role |
|-------|------|-----------|------|
| `cbs-gateway:latest` | 349 MB | `TflCbs.Gateway` | YARP reverse proxy (pure — no services/RCLs/DB drivers) |
| `trustbank-cbs:latest` | 429 MB | `TflCbs.Host.Main` | Default/full host — **all** modules, **login authority**. Also the single-host image. |
| `cbs-hr:latest` | 425 MB | `TflCbs.Host.Hr` | Thin host — Hr |
| `cbs-lockers:latest` | 425 MB | `TflCbs.Host.Lockers` | Thin host — Lockers |
| `cbs-retail:latest` | 425 MB | `TflCbs.Host.RetailBanking` | Thin host — RetailBanking |
| `cbs-admin:latest` | 425 MB | `TflCbs.Host.Administration` | Thin host — Administration |
| `redis:7-alpine` | 58 MB | *(pulled)* | Optional dev cache (reference cache); not part of a host |

The 5 app images are the same size — each carries the full stack and differs only in which **one** domain RCL is baked in (the default carries all five). The gateway is ~80 MB smaller.

---

## 3. Containers (when running)

Compose project name = `tflcbsnet10sol` (from the folder). Container names are `tflcbsnet10sol-<service>-1`.

**Single-host** (`compose.yaml`):

| Container | Image | Ports |
|-----------|-------|-------|
| `tflcbsnet10sol-cbs-1` | trustbank-cbs | **8090→8080** |

**Multi-host** (`compose.multi.yaml`):

| Container | Image | Ports |
|-----------|-------|-------|
| `tflcbsnet10sol-gateway-1` | cbs-gateway | **8091→8080 (only published)** |
| `tflcbsnet10sol-default-1` | trustbank-cbs | 8080 (internal) |
| `tflcbsnet10sol-hr-1` | cbs-hr | 8080 (internal) |
| `tflcbsnet10sol-lockers-1` | cbs-lockers | 8080 (internal) |
| `tflcbsnet10sol-retail-1` | cbs-retail | 8080 (internal) |
| `tflcbsnet10sol-admin-1` | cbs-admin | 8080 (internal) |

Backends have **no** published ports — only reachable inside the compose network `tflcbsnet10sol_default` by service name (`http://hr:8080/`, …). Only the gateway is exposed to the host.

**Mounts / volumes in use:**
- single-host `cbs`: bind `./docker-data/dpkeys → /keys` (Data Protection keys persist on the host).
- multi-host `gateway`: bind `./docker/gateway.multi.appsettings.json → /app/appsettings.Production.json` (routing).

---

## 4. The two deployments at a glance

| | Single-host | Multi-host |
|---|---|---|
| Compose file | `compose.yaml` (+ `compose.override.yaml`) | `compose.multi.yaml` (+ `compose.multi.local.yaml`) |
| Containers | 1 | 6 (gateway + 5 hosts) |
| Browse | `http://localhost:8090` (or `https://localhost:8092` via the IIS `cbs-docker-gw`) | `http://localhost:8091` |
| Modules | all in one container | split — default = all, thin hosts = one each |
| DP key ring | **FileSystem** (bind mount) — standalone | **TflOmniDb** (shared DB) — SSO across all containers |
| Login | served locally | thin hosts **defer** to the gateway (login authority = default) |
| HTTPS | via IIS gateway 8092, or a TLS edge | via a TLS edge / reserved 8093 (see [../deploy/docker-multi-host.md](../deploy/docker-multi-host.md)) |

---

## 5. Everyday commands (this project)

All from the solution root. The `.env` is picked up automatically.

**Single-host**
```bash
docker compose up -d --build          # build + start (compose.yaml + compose.override.yaml auto-merged)
docker compose ps                     # status
docker compose logs -f cbs            # follow logs
docker compose down                   # stop + remove
```

**Multi-host** (note: two `-f` flags — the local overlay is NOT auto-merged)
```bash
docker compose -f compose.multi.yaml -f compose.multi.local.yaml up -d --build
docker compose -f compose.multi.yaml ps
docker compose -f compose.multi.yaml logs -f gateway
docker compose -f compose.multi.yaml -f compose.multi.local.yaml down
```

**Health checks**
```bash
curl http://localhost:8090/health/ready                         # single host (DB-ready)
curl http://localhost:8091/gateway/health                       # multi gateway liveness
docker compose -f compose.multi.yaml exec hr curl -fsS http://localhost:8080/health/ready   # a backend, from inside
```

**After changing a config file** (env, mounted appsettings, overlay): recreate the affected service —
```bash
docker compose -f compose.multi.yaml -f compose.multi.local.yaml up -d gateway   # just the gateway
```
Editing a **bind-mounted** file (e.g. `docker/gateway.multi.appsettings.json`) still needs a recreate/restart — the app reads it at startup.

---

## 6. Data, DB & SSO specifics

- **Database:** the connection string comes from `.env` (`CBS_SQLSERVER_CONNSTRING`). It targets the SQL Server **named instance** by name so SQL Browser resolves the (dynamic) port; use the server **IP** so the container needs no name resolution.
- **Single-host Data Protection:** `KeyRing=FileSystem` + bind mount `./docker-data/dpkeys` → keys survive `down`/redeploy (no forced re-login). Standalone identity — no SSO with anything else.
- **Multi-host SSO:** every app container shares `KeyRing=TflOmniDb` + `ApplicationName=TrustBankCBS` + the `CBS_SESSIONREVOCATIONS` table → one container's cookie is valid on the others, and global logout revokes everywhere. The two shared tables (`CBS_DATAPROTECTIONKEYS`, `CBS_SESSIONREVOCATIONS`) must exist once in the DB.
- **Single active session** is DB-backed and shared across **every** deployment on that DB (IIS + Docker) — a user can be logged into only one at a time.

---

## 7. Project-specific gotchas

- **Gateway routing must be JSON, not env vars.** The cluster/destination keys have hyphens (`cbs-default`, `default-host`, …); env-var names with hyphens are invalid POSIX names that the container runtime **drops before the app starts**, so a `ReverseProxy__Clusters__cbs-default__…` override never binds and YARP keeps the baked-in `localhost:5xxx` addresses → **502**. That's why routing lives in the mounted `docker/gateway.multi.appsettings.json`.
- **Plain-http login needs `SecurePolicy=SameAsRequest`.** The committed compose keeps `Always` (for behind-TLS); the local overlays relax it so the auth cookie round-trips over plain http. Remove the overlay once you put real TLS in front.
- **Containers are HTTP-only.** No cert baked in; TLS terminates at an edge (IIS `cbs-docker-gw` 8092 for single-host, or a TLS edge/8093 for multi). `UseHttpsRedirection` is inert in the container (no https port), so health probes over http return 200 (no redirect trap).
- **DLL-lock rule doesn't apply to Docker.** The "stop the app before building" rule is for the IIS/`dotnet run` hosts on Windows; Docker builds are isolated, so single-host and multi-host can build/run without freeing local DLL locks.

---

## 8. Cleanup

```bash
docker compose down                                    # stop single-host
docker compose -f compose.multi.yaml down              # stop multi-host (+ its containers/network)
docker image rm cbs-gateway:latest cbs-hr:latest …     # remove images (optional)
docker system df                                       # see reclaimable space
docker system prune                                    # remove stopped containers, unused networks, dangling images
docker builder prune                                   # reclaim build cache
```
Local throwaway files to delete when done testing: `compose.override.yaml`, `compose.multi.local.yaml`, `.env`, `docker-data/`. Keep the committed ones: `Dockerfile`, `compose.yaml`, `compose.multi.yaml`, `docker/`.

---

## 9. Related docs
- [../deploy/docker-single-host.md](../deploy/docker-single-host.md) — single-host walkthrough
- [../deploy/docker-multi-host.md](../deploy/docker-multi-host.md) — multi-host walkthrough
- [docker-cheatsheet.md](docker-cheatsheet.md) — Docker terminology & commands (general)
- [../port-map.md](../port-map.md) — all ports (dev + deploy)
