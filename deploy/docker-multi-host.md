# Deploy with Docker — Multi Host (gateway + default host + thin hosts)

One container per host, wired together with docker-compose. The **gateway container is the only published port**; the browser only ever talks to it.

> Read [docker-single-host.md](docker-single-host.md) first (Dockerfile pattern, config, Data Protection, the `docker/vendor/` DLLs). This doc adds the multi-container specifics. See also [single-sign-on.txt](../single-sign-on.txt) and [port-map.md](../port-map.md).

The repo **ships `compose.multi.yaml`** + the same parameterized Dockerfile (verified: the default host, a thin host, and the gateway all build).

## Deployment checklist (run in order)

1. ☐ **Prerequisites** — Docker + compose; the DB reachable from the container network; **create the two shared SSO tables once** — `CBS_DATAPROTECTIONKEYS`, `CBS_SESSIONREVOCATIONS` (§3).
2. ☐ **Secrets** — `.env` at the solution root: `CBS_SQLSERVER_CONNSTRING=…` **and** `CBS_PUBLIC_HOST=<gateway hostname>` (§5).
3. ☐ **Confirm the three SSO preconditions** (§3) — every app service `KeyRing=TflOmniDb` + `SessionRevocation=TflOmniDb` (same DB, same `ApplicationName`); only the gateway publishes a port.
4. ☐ **Gateway routing** (§4) — cluster Destinations point at the compose **service names** (`http://default:8080/`, …), already wired in `compose.multi.yaml` (§5).
5. ☐ **Production hardening** (§5) — proxy trust is now on by default (`ForwardedHeaders__KnownNetworks` = the bridge pool); optionally tighten it to a **static gateway IP** via `KnownProxies`; terminate real TLS at an edge in front of the gateway; trim services you don't run.
6. ☐ **Build + up + verify** (§6) — `docker compose -f compose.multi.yaml up -d --build`; `… ps` all Up; each backend `/health/ready`; gateway `/gateway/health`; unauth area → 302 login on gateway origin; login once → cross areas no re-login → global logout.

Each step links to its detailed section below.

## 1. Topology (containers on one compose network)

```
browser --HTTPS--> [TLS edge] --HTTP--> [gateway] --HTTP--> default   (login authority, all else)
                                                 \--HTTP--> hr        (/Hr/*)
                                                 \--HTTP--> lockers   (/Lockers/*)
                                                 \--HTTP--> retail    (/RetailBanking/*)
                                                 \--HTTP--> admin     (/Administration/*)
```

- The **TLS edge** (cloud LB / nginx / Caddy / an IIS-hosted YARP) terminates HTTPS and forwards HTTP to the gateway; the gateway container itself speaks **HTTP** on 8080 (no cert baked in). See §5 for the edge + `X-Forwarded-Proto` wiring.
- Containers reach each other by **service name** on the compose network (`default`, `hr`, …), so the gateway's cluster Destinations become `http://<service>:8080/` — no host ports needed for the backends.
- **Only the gateway publishes a port** to the host.
- Deploy any subset: minimum is gateway + default. Add thin hosts to peel modules off.

## 2. One parameterized Dockerfile for all hosts

The committed Dockerfile (see [docker-single-host.md](docker-single-host.md)) is parameterized by a build `ARG PROJECT`, so the **same** Dockerfile builds every container — just pass a different `PROJECT`:

```bash
docker build --build-arg PROJECT=TflCbs.Gateway              -t cbs-gateway:latest .
docker build --build-arg PROJECT=TflCbs.Host.Main             -t trustbank-cbs:latest .
docker build --build-arg PROJECT=TflCbs.Host.Hr             -t cbs-hr:latest .
docker build --build-arg PROJECT=TflCbs.Host.Administration -t cbs-admin:latest .
# ...
```

`compose.multi.yaml` passes `PROJECT` per service, so `docker compose -f compose.multi.yaml up -d --build` builds them all. No separate Dockerfiles. (linux/amd64 aspnet image; the app doesn't hit TflSecurityCrypto's Windows-only paths at runtime.)

**Each image carries a different payload** (the publish output baked into it):

| Image (`PROJECT`) | Domain web RCL(s) | Rest of the image |
|-------------------|-------------------|-------------------|
| `TflCbs.Host.Main` (default) | **all five** `TflCbs.Modules.*.Web.dll` | full stack — Framework, Web.Shared, Services, Core.Authentication, both core `.Web` RCLs, TflOmniLog, TflCbs.Entities + bare `TflOmniDb`/`TflSecurityCrypto` + ADO.NET drivers |
| `TflCbs.Host.Hr` / `.Lockers` / `.RetailBanking` / `.Administration` | **only that one** domain RCL (e.g. `TflCbs.Modules.Hr.Web.dll`) | same full stack as the default |
| `TflCbs.Gateway` | **none** | minimal — `TflCbs.Gateway.dll` + `Yarp.ReverseProxy.dll` only; no CbsFramework, services, domain RCLs, bare DLLs, or DB drivers |

(Full assembly breakdown of the "full stack": [iis-single-host.md §2](iis-single-host.md). This is why the gateway image is ~349 MB vs ~429 MB for a full host.)

## 3. The three SSO preconditions (same as IIS multi-host)

- **A. Shared DP key ring** — `DataProtection__ApplicationName=TrustBankCBS` + `DataProtection__KeyRing=TflOmniDb` on **every** app container (keys in `CBS_DATAPROTECTIONKEYS`). This is what makes one container's cookie readable by another — no shared volume needed.
- **B. Shared revocation** — `Auth__SessionRevocation=TflOmniDb` on every app container (`CBS_SESSIONREVOCATIONS`) — global logout.
- **C. One origin** — only the gateway is published; the browser sees one host.

Create the two shared tables **once** (DDL in `Framework\Infrastructure\DataProtectionKeyEntity.cs` and `Framework\Auth\SessionRevocation.cs`).

Because keys live in the DB, **none** of the app containers need a persistent volume for Data Protection — they're stateless and restart-safe.

## 4. Gateway config for container networking

Point each YARP cluster at the compose **service name**. The gateway image ships `appsettings.json` with the clusters aimed at `http://localhost:5xxx/` (dev ports) — override the destination **addresses** for the compose network.

> **Use a mounted JSON file, not environment variables.** The cluster + destination keys contain hyphens (`cbs-default`, `hr-host`, … / `default-host`, `hr-thin`, …), so an env override like `ReverseProxy__Clusters__cbs-default__Destinations__default-host__Address` has a **hyphen in its name** — an invalid POSIX env-var name that the **container runtime drops before the app process starts**. (It still shows in `docker inspect` / `docker exec … env`, but never reaches `/proc/1/environ`, so .NET never binds it and YARP keeps the `localhost:5xxx` addresses → **every proxied request 502s**.) JSON keys have no such restriction. *(Verified: a non-hyphen env override like `RateLimit__PermitPerWindow` binds fine; the hyphenated `ReverseProxy__…` ones do not.)*

Mount a small `appsettings.Production.json` (Production env loads it; it merges over the image's `appsettings.json` by key) — exactly what `compose.multi.yaml` does via `docker/gateway.multi.appsettings.json`:

```json
{
  "ReverseProxy": {
    "Clusters": {
      "cbs-default":         { "Destinations": { "default-host":         { "Address": "http://default:8080/" } } },
      "hr-host":             { "Destinations": { "hr-thin":              { "Address": "http://hr:8080/" } } },
      "lockers-host":        { "Destinations": { "lockers-thin":         { "Address": "http://lockers:8080/" } } },
      "retailbanking-host":  { "Destinations": { "retailbanking-thin":   { "Address": "http://retail:8080/" } } },
      "administration-host": { "Destinations": { "administration-thin":  { "Address": "http://admin:8080/" } } }
    }
  }
}
```
```yaml
# gateway service in compose.multi.yaml
volumes:
  - ./docker/gateway.multi.appsettings.json:/app/appsettings.Production.json:ro
```

Keep the destination **keys** identical to the image's `appsettings.json` (`default-host`, `hr-thin`, …) so this **replaces** each address (one destination per cluster). Drop the clusters/routes for hosts you don't deploy.

## 5. `compose.multi.yaml` (committed at the solution root)

The repo ships `compose.multi.yaml` with all six services (gateway + default + hr/lockers/retail/admin), each using the parameterized Dockerfile with its `PROJECT` arg. The load-bearing bits already wired in it:

- **gateway** — the only published port (`8091:8080` — host 8091 avoids the IIS ports 8080/8081 + 81xx and the single-host container's 8090; put a TLS edge in front for real HTTPS — see below); its ReverseProxy cluster destinations are overridden to the service names (`http://default:8080/`, `http://hr:8080/`, …) via a **mounted `appsettings.Production.json`** (`docker/gateway.multi.appsettings.json`, §4).
- **default** — `Auth__LoginUrl=/Account/Login` (relative — the login authority); `Modules__Enabled=*`.
- **each thin host** — `Auth__LoginUrl=https://${CBS_PUBLIC_HOST}/Account/Login` (absolute — defers to the gateway); `Modules__Enabled` = its domain + `General` + `Authentication` + `Misc` + `Accounts`.
- **every app service** — `DataProtection__KeyRing=TflOmniDb`, `Auth__SessionRevocation=TflOmniDb`, `Auth__Cookie__SecurePolicy=Always`, `ForwardedHeaders__Enabled=true` + `ForwardedHeaders__KnownNetworks__0=172.16.0.0/12` (so the gateway's `X-Forwarded-*` is actually trusted — see §5), `Auth__AllowedReturnHosts__0=${CBS_PUBLIC_HOST}` (shared via a YAML anchor). **`CBS_PUBLIC_HOST` must include the port** (`localhost:8091`) — it feeds both `Auth__LoginUrl`, which needs a full origin, and the return-host allowlist, which is matched against `Uri.Authority`. Until 2026-08-01 the allowlist was compared against `Uri.Host`, so the ported value never matched and **every cross-host deep link silently landed on `/Modules` after login**; the comparison now uses the authority, which makes this variable correct for both uses.

> **Plain-HTTP testing caveat.** Every app service ships `Auth__Cookie__SecurePolicy=Always`, so the auth cookie is only ever returned over HTTPS. Over a bare `http://localhost:8091` you can verify health and the unauthenticated **302 → login** redirect, but **not a full login round-trip** — the browser won't send the `Secure` cookie back over http. For a real login you need TLS in front of the gateway (below), or temporarily set `Auth__Cookie__SecurePolicy=SameAsRequest` for the http test.

Set two things before `up` (via a `.env` file at the solution root):

```bash
CBS_SQLSERVER_CONNSTRING=<prod connection string>
CBS_PUBLIC_HOST=<the hostname browsers use for the gateway>
```

**Production hardening to add:**

- **Tighten proxy trust from a subnet to an address (optional).** Since 2026-07-31 the compose file **already trusts the gateway** — `ForwardedHeaders__KnownNetworks__0=172.16.0.0/12` (Docker's default bridge pool) in the shared anchor, because a compose service's IP is **dynamic** and there is no stable address to pin. That is safe here (only the gateway publishes a port, so the only peers in range are this stack's own services) but a range trusts *every* peer in it. Where you can give the gateway a **static IP** on a user-defined network (`networks.ipam`), prefer pinning exactly that peer: set `ForwardedHeaders__KnownProxies__0=<gateway-static-ip>` and blank the range with `ForwardedHeaders__KnownNetworks__0=""` (an empty entry is skipped, not a parse error). `compose.multi.https.yaml` does exactly this. If your daemon uses custom `default-address-pools`, adjust the CIDR to match.
  - **Without *some* trust, the backend ignores the gateway's `X-Forwarded-Proto`/`-Host`** — it trusts only loopback, and the gateway is a **peer container**, not loopback — so redirects and returnUrls carry the internal `service:8080` origin.
  - **It also decides whose IP every per-client control sees.** `Connection.RemoteIpAddress` stays the
    *gateway's* without it, which collapses three things onto one identity: the **login rate limiter**
    (`Security:LoginRateLimit`) throttles the whole bank as a single bucket rather than per workstation;
    the same-workstation force-logout (which lets a user reclaim their own stale `b_UserLogTime` row after
    a crash) can no longer tell workstations apart; and if the bank ever sets
    `b_LoginPolicy.RemoteHostLoginAttempt > 0`, the IP lockout would count every user's failed attempts
    against one shared "host" and could block **everyone at once**.
  - **A malformed entry fails the host at startup** (both lists), rather than being skipped — a silently
    dropped entry would leave you reading a trust list that isn't in force.
  - **A *missing* entry is detected at runtime.** If an `X-Forwarded-For` arrives from a peer this host
    doesn't trust, the header is discarded and the host logs one `Security`-category warning per start
    (`grep` for `X-Forwarded-For arrived`). It stays silent when the trust is correct, and when nothing is
    proxying to the host at all — so seeing it means the trust list needs fixing, not tuning.
- **TLS** — two shapes (see below): put an **edge proxy in front** of the gateway (extra hop), or **terminate TLS on the gateway itself** (single hop — recommended, since the gateway is already the one entry proxy).
- Trim services you don't run (and the matching gateway routes/clusters).

### 5.1 HTTPS on the gateway (single-hop TLS — verified)

The cleanest HTTPS: give the **gateway** container a cert so TLS terminates at the one entry proxy; it then forwards `X-Forwarded-Proto=https` to the backends in the single internal hop. No second proxy, no forwarded-header chain to untangle.

A local overlay (`compose.multi.https.yaml`, passed as a 2nd `-f`) that does this:

```yaml
networks:
  cbsmulti: { ipam: { config: [ { subnet: 172.30.0.0/16 } ] } }
services:
  gateway:
    networks: { cbsmulti: { ipv4_address: 172.30.0.10 } }   # static IP so backends can trust exactly this peer
    ports: !override [ "8091:8443" ]                          # publish the https port (replace, don't append)
    environment:
      ASPNETCORE_URLS: "http://+:8080;https://+:8443"          # keep http 8080 for the internal healthcheck
      Kestrel__Certificates__Default__Path: /certs/gw.pfx
      Kestrel__Certificates__Default__Password: "${CBS_GW_CERT_PASSWORD}"
    volumes: [ "./certs/gw.pfx:/certs/gw.pfx:ro" ]
  # Pin exactly this peer and blank the base's subnet trust (an empty entry is skipped, not an error).
  default: { networks: [cbsmulti], environment: { ForwardedHeaders__KnownProxies__0: "172.30.0.10", ForwardedHeaders__KnownNetworks__0: "" } }
  hr:      { networks: [cbsmulti], environment: { ForwardedHeaders__KnownProxies__0: "172.30.0.10", ForwardedHeaders__KnownNetworks__0: "" } }
  # …lockers / retail / admin the same…
```

Prereqs: a PKCS#12 `certs/gw.pfx` (a self-signed cert with an **exportable** key works locally — `New-SelfSignedCertificate … -KeyExportPolicy Exportable` then `Export-PfxCertificate`) and, in `.env`, `CBS_GW_CERT_PASSWORD=<pfx pw>` + `CBS_PUBLIC_HOST=localhost:8091`. Keep `SecurePolicy=Always` (do **not** also apply the plain-http overlay). Then:

```bash
docker compose -f compose.multi.yaml -f compose.multi.https.yaml up -d
curl -k https://localhost:8091/gateway/health          # 200 over TLS
```

Verified end-to-end: browse `https://localhost:8091`; the auth cookie comes back `Secure`; an unauth `GET /Hr/State` → **302** to `…/Account/Login?returnUrl=https%3A%2F%2Flocalhost%3A8091%2FHr%2FState` (thin-host https deferral + the backend building the **public https** returnUrl — proof the `KnownProxies` trust works); login once → cross containers → global logout, all over HTTPS.

**Alternative — edge proxy in front (double hop).** An IIS-hosted YARP (the reserved **8093**, reuses your existing cert) or nginx / Caddy / a cloud LB terminates TLS and forwards HTTP to the gateway on 8091. Functionally equivalent; pick by environment (IIS on this Windows box, Caddy/nginx for Linux/cloud). Costs an extra hop and needs the `X-Forwarded-*` chain handled at each proxy, which is why single-hop TLS on the gateway is preferred.

## 6. Build, run, verify

```bash
docker compose -f compose.multi.yaml build
docker compose -f compose.multi.yaml up -d
docker compose -f compose.multi.yaml ps      # all services Up
```

Verify (same sequence as IIS multi-host, through the gateway only):

1. `docker compose -f compose.multi.yaml exec hr curl -f http://localhost:8080/health/ready` — each backend healthy.
2. `curl -f https://<public-host>/gateway/health` — gateway healthy.
3. Unauth GET `https://<public-host>/Administration/Module` → **302** to login with returnUrl on the **gateway** origin (not a backend).
4. Log in once → screen renders, **no re-login**.
5. Cross to `/Hr/State`, `/Lockers/...` → no re-login (shared key ring).
6. Global logout → re-hit any area → 302 to login (revocation works).

> Steps 1–3 also work over a bare `http://localhost:8091`. Steps 4–6 (login) need real TLS in front of the gateway — or a temporary `Auth__Cookie__SecurePolicy=SameAsRequest` — because `Always` won't return the auth cookie over http (§5 caveat). The verify URLs above assume the TLS edge is in place.

## 7. Troubleshooting (container-specific; see IIS multi-host for the rest)

| Symptom | Fix |
|---------|-----|
| Re-login on every host jump | Missing shared key ring: every app container needs the **same** `DataProtection__ApplicationName` and `KeyRing=TflOmniDb` → same DB. (Container FileSystem keys are per-container and ephemeral — never use FileSystem for multi-host.) |
| 502 from the gateway for one area | Wrong cluster destination service name/port, or that container is down. `docker compose logs <service>`; curl its `/health/ready` from inside. |
| **Every** proxied area 502s (gateway + backends all healthy) | The gateway's destination overrides aren't binding, so YARP still targets the baked-in `http://localhost:5xxx/`. Almost always because they were set as **env vars** — the hyphenated names (`ReverseProxy__Clusters__cbs-default__…`) are dropped before the app starts (invalid POSIX names; visible in `docker inspect` but not `/proc/1/environ`). Use the **mounted `appsettings.Production.json`** instead (§4). Check the gateway logs for `Connection refused (localhost:5019)`. |
| returnUrl shows an internal `service:8080` address | The backend isn't trusting the gateway: `ForwardedHeaders__Enabled` off, or neither `KnownNetworks` (CIDR range — the compose default, §5) nor `KnownProxies` (exact IP) covers the gateway's actual address. Check it with `docker network inspect` and confirm it falls inside the configured range. |
| Login throttles the whole stack at once (429s for everyone) | Same root cause as the row above — an untrusted proxy leaves every backend seeing the *gateway's* IP, so the login rate limiter's per-client partition becomes one shared bucket. Fix the trust, not the limit. |
| A host won't start: "ForwardedHeaders:KnownNetworks contains …" | A malformed trust entry now fails startup by design. CIDR needs `address/prefixLength`, and the address must be the **network** (`172.30.0.0/16`, not `172.30.0.10/16` — the message names the correction; to trust one address use `KnownProxies`). |
| Login never completes / loops over plain http | `SecurePolicy=Always` won't return the auth cookie over http. Put TLS in front, or use `SameAsRequest` for the test (§5 caveat). |
| Default host login redirects to itself forever (Linux only) | Stale image from before the `AccountController` URI-scheme fix: a relative `Auth:LoginUrl` parsed as `file://` on Linux and deferred to itself. Rebuild from current source (the fix requires an http/https scheme to defer). |
| Everyone logged out after `docker compose up` redeploy | You were on FileSystem keys without a volume. Switch to `KeyRing=TflOmniDb`. |
| Thin host 500 on `/Modules` or login | Missing `Misc`/`Accounts` in that service's `Modules__Enabled`. |
| DB unreachable from containers | Add the DB to the compose network, or use `host.docker.internal` / a real server reachable from the container network. |

## 8. Related docs

- [docker-single-host.md](docker-single-host.md) — the Dockerfile/config basics
- [iis-multi-host.md](iis-multi-host.md) — same topology on IIS/Windows
- [single-sign-on.txt](../single-sign-on.txt) — the SSO mechanism in depth
- [port-map.md](../port-map.md) — ports & routing table (dev + deploy)
