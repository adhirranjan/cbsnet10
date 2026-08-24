# Deploy with Docker — Single Host (`TflCbs.Host.Main` only)

One container running the full host (all modules on). No gateway, no thin hosts. For the multi-container shape see [docker-multi-host.md](docker-multi-host.md).

The repo **ships the build files** (verified: image builds + boots):

| File | Purpose |
|------|---------|
| `Dockerfile` | parameterized by `PROJECT` (serves every host) |
| `Dockerfile.dockerignore` | trims the context |
| `compose.yaml` | this single-host service |
| `compose.multi.yaml` | the multi-host topology |
| `docker/vendor/` | the 2 vendored external DLLs (see §1) |

## Deployment checklist (run in order)

1. ☐ **Prerequisites** — Docker installed; the DB **reachable from a Linux container** (host DB via `host.docker.internal`+static port, or a container/server DB); decide DP-key persistence (`KeyRing=TflOmniDb` + its table, or FileSystem + a volume — §3).
2. ☐ **Secrets** — put the prod connection string in a `.env` at the solution root (`CBS_SQLSERVER_CONNSTRING=…`); never bake it into the image (§3).
3. ☐ **Build + run** (§4) — from the solution root: `docker compose up -d --build` (or `docker build --build-arg PROJECT=TflCbs.Host.Main …` then `docker run`). Pick `Auth__Cookie__SecurePolicy` = `Always` behind a TLS proxy, `SameAsRequest` for bare-http testing (§3).
4. ☐ **Verify** (§5) — `docker logs -f cbs`; `/health` → 200, `/health/ready` → 200 (DB); browse → login → a screen.
5. ☐ **Operate** (§6) — one replica only (in-memory session/nonces); orchestrator liveness→`/health`, readiness→`/health/ready`.

Each step links to its detailed section below.

## 1. Why `docker/vendor/` exists (the one non-obvious thing)

The host csprojs link two **prebuilt external DLLs** by HintPath:

```
TflOmniDb.dll, TflSecurityCrypto.dll  at  ..\..\..\_Archive\...\bin\Debug\net10.0\
```

That `_Archive` path is **above** the repo root (`E:\Adhir\AdWork\_Archive`) **and is ~6 GB** — so it can't be the Docker build context. Instead those two DLLs (~0.5 MB) are **vendored** into the repo:

```
docker/vendor/TflOmniDb/         (TflOmniDb.dll + .deps.json)
docker/vendor/TflSecurityCrypto/ (TflSecurityCrypto.dll + .deps.json)
```

and the Dockerfile stages them into the image at the exact `_Archive` path the HintPaths expect. **Build context stays the solution root.**

> If `TflOmniDb` / `TflSecurityCrypto` are rebuilt, refresh `docker/vendor/` from their `bin\Debug\net10.0` output.

## 2. The Dockerfile (already in the repo; PROJECT-parameterized)

Multi-stage: SDK image builds, ASP.NET runtime image runs. Kestrel serves directly (no IIS). One `ARG PROJECT` selects which host — so the **same** Dockerfile builds the default host, any thin host, or the gateway. Shape:

```dockerfile
ARG PROJECT=TflCbs.Host.Main
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
ARG PROJECT
WORKDIR /src
# stage the vendored DLLs at the depth the HintPaths resolve to (/src/_Archive/...)
COPY docker/vendor/TflOmniDb/         /src/_Archive/.../TflOmniDb/.../net10.0/
COPY docker/vendor/TflSecurityCrypto/ /src/_Archive/.../TflSecurityCrypto/.../net10.0/
COPY . /src/TrustBank.Code/TflCbsNet10Sol/
WORKDIR /src/TrustBank.Code/TflCbsNet10Sol
RUN dotnet build TflCbs.Entities                       # bare-DLL dep — build FIRST
RUN dotnet publish "${PROJECT}" -c Release -o /app --no-self-contained

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
ARG PROJECT
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*                  # for the compose healthcheck
WORKDIR /app
COPY --from=build /app ./
ENV ASPNETCORE_HTTP_PORTS=8080 ASPNETCORE_ENVIRONMENT=Production APP_DLL=${PROJECT}.dll
EXPOSE 8080
ENTRYPOINT ["sh","-c","exec dotnet \"$APP_DLL\""]
```

- Base image is `linux/amd64`. TflSecurityCrypto's machine-fingerprint / licensing paths are Windows-only, but the CBS app doesn't hit them at runtime, so the Linux ASP.NET image is fine. **Verified: the image boots and `/health` returns 200 on `linux/amd64`.**
- The image bakes the full-host publish output — `TflCbs.Host.Main.dll` + all five domain `.Web` RCLs + the Framework/Shared/Services/Core stack + `TflCbs.Entities` + the bare `TflOmniDb`/`TflSecurityCrypto` DLLs + ADO.NET drivers. See the full per-assembly list in [iis-single-host.md §2](iis-single-host.md). (For per-image differences across hosts, see [docker-multi-host.md §2](docker-multi-host.md).)

`Dockerfile.dockerignore` (context = solution root) trims outputs:

```
**/bin
**/obj
**/Logs
**/App_Data
**/.git
```

## 3. Config (do **not** bake secrets into the image)

TLS terminates **outside** the container (a reverse proxy / load balancer / cloud LB). Inside, the app speaks plain HTTP on 8080. Pass production settings as environment variables (double-underscore = config nesting):

```bash
Database__Provider=SqlServer
Database__ConnectionStrings__SqlServer=<prod connection string>
DataProtection__ApplicationName=TrustBankCBS
DataProtection__KeyRing=TflOmniDb            # keys survive container restarts
Auth__SessionRevocation=InMemory             # one process = fine
Auth__Cookie__SecurePolicy=Always
ForwardedHeaders__Enabled=true               # if a proxy/LB fronts it
ForwardedHeaders__KnownProxies__0=<proxy-ip>
Modules__Enabled=*
```

**Data Protection — the container-critical point:** the default `KeyRing=FileSystem` writes to `App_Data/DataProtection-Keys` **inside** the container, which is ephemeral — every redeploy/restart mints a new key and invalidates all `CbsAuth` cookies + row tokens. Fix by **either**:

- (a) `KeyRing=TflOmniDb` — keys in the **`CBS_DATAPROTECTIONKEYS`** table. **Create it once** first (DDL in `TflCbs.Framework/Infrastructure/DataProtectionKeyEntity.cs`); no volume needed, but it does need the DB. Pick this if you already run multi-host or want DB-managed keys.
- (b) `KeyRing=FileSystem` + a persistent **volume / bind mount** at `DataProtection__KeyRingPath`. **This is what the committed `compose.yaml` uses:** `KeyRing=FileSystem`, `KeyRingPath=/keys`, and a **bind mount** `./docker-data/dpkeys:/keys` (host folder ↔ container path) — so the keys live on the host and survive `docker compose down`/redeploy, with no DB dependency for keys.

**Connection strings:** never the checked-in dev `sa/sql@2019`. Inject at runtime. The DB must be reachable from the container network (a container DB, a host DB via `host.docker.internal`, or a real server).

### HTTPS, redirects & the `Secure` cookie (read this — it bites)

The app runs `UseCbsForwardedHeaders` → `UseHttpsRedirection`. Inside the container it listens on **plain HTTP:8080 with no HTTPS port**, so `UseHttpsRedirection` can't find a target port and **no-ops** — HTTP passes straight through (that's why `/health` and the app answer over http). *If* you ever give the container an HTTPS port, http would then 307-redirect.

Because TLS terminates **at a proxy in front**, the app only knows the original request was HTTPS if the proxy tells it:

- Set `ForwardedHeaders__Enabled=true` **and trust the proxy** — `ForwardedHeaders__KnownProxies__0=<proxy IP>` (or a `KnownNetworks` subnet). In Docker the immediate peer is the bridge/proxy container IP, **not loopback**, so the framework's default loopback trust is **not** enough — an unset `KnownProxies` means `X-Forwarded-Proto` is ignored and the app thinks every request is http.

- **`Auth__Cookie__SecurePolicy=Always`** marks `CbsAuth` `Secure`, so browsers send it only over HTTPS. Correct **behind a TLS proxy**. But hit the container **directly over plain HTTP** (e.g. `http://localhost:8090`, no proxy) and the browser **drops the Secure cookie → login loops**. For plain-HTTP local testing use `Auth__Cookie__SecurePolicy=SameAsRequest`. *(The committed `compose.yaml` sets `Always`, assuming a TLS proxy — override it for bare-http testing.)*

## 4. Build & run

From the **solution root** (context = `.`):

```bash
docker build --build-arg PROJECT=TflCbs.Host.Main -t trustbank-cbs:latest .

docker run -d --name cbs -p 8090:8080 \
  -e Database__ConnectionStrings__SqlServer="<prod>" \
  -e DataProtection__KeyRing=FileSystem -e DataProtection__KeyRingPath=/keys \
  -v "$PWD/docker-data/dpkeys:/keys" \
  -e Auth__Cookie__SecurePolicy=SameAsRequest \
  trustbank-cbs:latest
# ^ host 8090 (avoids the IIS 8080/8081 + 81xx ports) -> container 8080.
#   FileSystem DP keys on a bind mount so they persist across restarts.
#   SameAsRequest so login works over plain http://localhost:8090;
#   behind a TLS proxy use Always + ForwardedHeaders (see §3).
```

Or with compose (`compose.yaml` is in the repo; set the connection string via a `.env` file — it reads `${CBS_SQLSERVER_CONNSTRING}`):

```bash
docker compose up -d --build
```

The committed `compose.yaml` publishes **host port 8090** (→ container 8080, so it doesn't clash with the IIS sites on 8080/8081 + 81xx), and wires `ASPNETCORE_ENVIRONMENT=Production`, `DataProtection__KeyRing=FileSystem` + `KeyRingPath=/keys` on a **bind mount** (`./docker-data/dpkeys:/keys`), `Auth__Cookie__SecurePolicy=Always`, and a curl `/health/ready` healthcheck (curl is in the runtime image). `Always` assumes a TLS proxy fronts the container — for bare-http `docker compose up` + browsing `http://localhost:8090`, override `Auth__Cookie__SecurePolicy=SameAsRequest` (see §3) or login will loop.

## 5. Verify

```bash
docker logs -f cbs                      # watch startup
curl http://localhost:8090/health       # 200 Healthy (liveness)   [host port 8090]
curl http://localhost:8090/health/ready # 200 (DB reachable; 503 = DB config)
```

Then browse `http://localhost:8090/` → login → a migrated screen (`/Hr/State`). **Login over plain http needs `SecurePolicy=SameAsRequest`** (see §3) — with `Always` the browser drops the `Secure` cookie and login loops.

App logs also stream to stdout (`docker logs`) and to `/app/Logs` inside the container — mount a volume there if you want them on the host.

## 6. Scaling & limits

- Run **one replica** of this image. `CbsSessionStore` + row-token nonces are in-memory per process, so two replicas behind a naive LB would bounce a user between two memory spaces (broken sessions) unless you add sticky sessions. To scale properly, move to the [multi-host shape](docker-multi-host.md) and scale per module.
- Persisted Data Protection keys (FileSystem on a bind mount — as the committed compose does — or `KeyRing=TflOmniDb`) mean even a single replica survives restarts without logging everyone out.
- Health: point your orchestrator's liveness at `/health` and readiness at `/health/ready`.

## 7. Related docs

- [docker-multi-host.md](docker-multi-host.md) — gateway + thin hosts with compose
- [iis-single-host.md](iis-single-host.md) — same app on IIS/Windows
- [../port-map.md](../port-map.md) — ports & project map
- [../architecture-overview.md](../architecture-overview.md) — what gets deployed
