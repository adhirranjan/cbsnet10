# Deploy to IIS — Single Host (`TflCbs.Host.Main` only)

The simplest production shape: **one IIS website** running the full host (`TflCbs.Host.Main`, all modules on). No gateway, no thin hosts. For the scale-out shape see [iis-multi-host.md](iis-multi-host.md).

> The repo ships no `web.config` / publish profile — `dotnet publish` generates the `web.config`; this doc is the recipe.

## Deployment checklist (run in order)

1. ☐ **Prerequisites** (§1) — IIS role installed; **.NET 10 ASP.NET Core Hosting Bundle (ANCM)** installed *after* IIS; an HTTPS certificate; the DB reachable from the server.
2. ☐ **Publish** (§2) — `dotnet build TflCbs.Entities` → `dotnet publish TflCbs.Host.Main -c Release -o C:\publish\cbs`.
3. ☐ **Production config** (§3) — override the dev connection string; set `ASPNETCORE_ENVIRONMENT=Production` in `web.config` (per-app, never machine-wide); ensure the Data Protection key folder survives redeploys.
4. ☐ **Create the IIS site** (§4) — app pool (**No Managed Code**, **Max Worker Processes = 1**, Load User Profile) + website (https binding + cert) + folder ACLs (Read on all, Modify on `Logs\`/`App_Data\`) for `IIS AppPool\<pool>`.
5. ☐ **Verify** (§5) — `/health` → 200, `/health/ready` → 200 (DB), `/` → login → open a migrated screen (e.g. `/Hr/State`).
6. ☐ **Redeploys** (§6) — drop `app_offline.htm`, copy new output, remove it — keep `Logs\` + the DP key folder out of the wiped path.

Each step links to its detailed section below.

## 1. Prerequisites (on the IIS server)

- Windows Server with the **IIS role** (W3SVC) installed.
- The **.NET 10 ASP.NET Core Hosting Bundle** (installs the ASP.NET Core Module V2 for IIS + the runtime). Install it **after** IIS, then restart IIS (`net stop was /y && net start w3svc`). Without it the site throws `500.19` / `502.5`.
- No URL Rewrite / ARR needed (single host, no proxying).
- Network line-of-sight from this server to the database (SQL Server or Oracle) named in `Database:ConnectionStrings`.
- An HTTPS certificate for the site binding.

## 2. Publish

On the build machine (framework-dependent publish, the default):

```bash
dotnet build TflCbs.Entities                       # only if entities changed
dotnet publish TflCbs.Host.Main -c Release -o C:\publish\cbs
```

What lands in the folder automatically:

- `TflCbs.Host.Main.dll` (the host / composition root) **plus every referenced assembly**. Those references are:

  | Layer | Assembly (dll) |
  |-------|----------------|
  | Composition root | `TflCbs.Host.Main.dll` |
  | Framework / plumbing | `TflCbs.Framework.dll` |
  | Logging | `TflOmniLog.dll` |
  | Business / data | `TflCbsServices.dll`, `TflCbs.Core.Authentication.dll` |
  | Shared web RCL | `TflCbs.Web.Shared.dll` |
  | Core web RCLs (always on) | `TflCbs.Core.Authentication.Web.dll`, `TflCbs.Core.Shell.Web.dll` |
  | Domain web RCLs (module screens) | `TflCbs.Modules.Bank.Web.dll`, `TflCbs.Modules.Hr.Web.dll`, `TflCbs.Modules.Lockers.Web.dll`, `TflCbs.Modules.RetailBanking.Web.dll`, `TflCbs.Modules.Administration.Web.dll` |
  | Entities | `TflCbs.Entities.dll` |

  Each `.Web` RCL carries its **Razor views compiled into the assembly** and ships its static assets (css/js/img) under `wwwroot\_content\<RclName>\` — e.g. `wwwroot\_content\TflCbs.Web.Shared\` (layout, `cbs-*.js`) and `wwwroot\_content\TflCbs.Modules.Lockers.Web\` (`locker-type.js`).
- The **bare-DLL references** — `TflOmniDb.dll`, `TflCbs.Entities.dll`, `TflSecurityCrypto.dll` — publish copies HintPath references. (`TflCbs.Entities` is also a project reference; its DLL is the one bare-referenced.)
- The **ADO.NET driver assemblies** pulled in as NuGet packages: `Microsoft.Data.SqlClient.dll`, `Oracle.ManagedDataAccess.dll`, `Npgsql.dll` (+ their native/runtime dependencies under `runtimes\`).
- `logmasking.json`, `appsettings*.json`, `wwwroot\`.
- A generated `web.config` pointing ANCM at `TflCbs.Host.Main.dll` (in-process hosting — the default, and what we want).

> Self-contained publish also works — add `-r win-x64 --self-contained`. Then the server doesn't need the runtime, only the hosting-bundle module.

## 3. Production config (before first run)

`ASPNETCORE_ENVIRONMENT` will be `Production`, so `appsettings.Development.json` is **not** loaded — every dev-only override disappears. Provide prod values in an `appsettings.Production.json` next to the dll (or as environment variables in `web.config`). Minimum to review:

```json
{
  "Database": {
    "Provider": "SqlServer",
    "ConnectionStrings": {
      "SqlServer": "<PROD connection string — never the dev sa/sql@2019>"
    }
  },
  "Auth": {
    "Cookie": { "SecurePolicy": "Always" }
  },
  "DataProtection": {
    "ApplicationName": "TrustBankCBS",     // already set in appsettings.json; just keep it stable
    "KeyRing": "FileSystem"                // single host: FileSystem is fine — see the note below
  },
  "Cbs": { "Broadcast": "..." }
}
```

- **Connection strings** — the checked-in `appsettings.json` carries dev creds; override them. Prefer a least-privilege SQL login. (Env-var alternative: `Database__ConnectionStrings__SqlServer=...`.)
- **Data Protection keys** — with the default `KeyRing=FileSystem`, keys are written to `App_Data\DataProtection-Keys` under the content root. Those keys encrypt every `CbsAuth` cookie and row token, so **losing them logs everyone out**. For a single host this is fine **as long as that folder survives redeploys** — you do **not** need the shared DB key ring here (that's a *multi-host* concern; one process has nothing to share with). You only need to act **if your deploy process wipes the key folder**:
  - (a) point `KeyRingPath` at a folder **outside** the deployment path and grant the app-pool identity write access, so a clean redeploy can't delete it (lightest option), **or**
  - (b) switch to `KeyRing=TflOmniDb` (keys in the `CBS_DATAPROTECTIONKEYS` table — create it once; DDL in `Framework\Infrastructure\DataProtectionKeyEntity.cs`) if you'd rather have DB-managed keys or expect to grow into multi-host.

  If your redeploy **preserves `App_Data\`**, plain FileSystem needs no change at all. `ApplicationName` is already `"TrustBankCBS"` in `appsettings.json`; keep it stable (if it changes, or if the content-root path changes with `ApplicationName` unset, existing keys stop decrypting).
- `Auth:LoginUrl` stays `/Account/Login` (relative) — the single host serves its own login. `Auth:SessionRevocation=InMemory` is correct for one process (the revoked-session list lives in this process's memory). Note it resets on an app restart — but a restart also drops the in-memory sessions themselves, so this only matters for a forced/admin revocation racing a restart. Use `TflOmniDb` **only** for multi-host.
- `ForwardedHeaders:Enabled=true` is harmless here (no proxy sends the headers) — leave as-is.
- `Modules:Enabled` stays `"*"` (full host).

## 4. Create the IIS site

1. **App pool** `TrustBankCBS`:
   - .NET CLR version: **"No Managed Code"** (ANCM hosts the .NET 10 app)
   - Pipeline: Integrated
   - Identity: ApplicationPoolIdentity (default)
   - Advanced → **Maximum Worker Processes = 1** (**required** — `CbsSessionStore` and row-token single-use nonces are in-memory per process; a web garden would randomly bounce users between memory spaces)
   - Load User Profile = True (needed if using FileSystem DP keys)
2. **Website** `TrustBankCBS`:
   - Physical path: `C:\publish\cbs`
   - Binding: `https` / 443 / your hostname / the certificate (optionally an `http`/80 binding — `UseHttpsRedirection` will bounce it)
   - Application pool: `TrustBankCBS`
3. **Environment** — publish's `web.config` already targets Production by default; to be explicit add inside `<aspNetCore>`:
   ```xml
   <environmentVariables>
     <environmentVariable name="ASPNETCORE_ENVIRONMENT" value="Production" />
   </environmentVariables>
   ```
   Set it **here, in this app's `web.config`** — ANCM applies it to this app's worker process only, so it never collides with other ASP.NET Core apps on the server. Do **not** set `ASPNETCORE_ENVIRONMENT` as a machine-wide/system environment variable: that would flip *every* ASP.NET Core app on the box to the same environment.
4. **Permissions** on `C:\publish\cbs` for the app-pool identity (`IIS AppPool\TrustBankCBS`): Read on everything, plus **write** on:
   - `Logs\` (TflLog rolling files — `TflLog:File:Directory`)
   - `App_Data\` (only if FileSystem DP keys stay under the site)

## 5. First-run verification

1. Browse `https://<host>/health` → **200** "Healthy" (process is up).
2. Browse `https://<host>/health/ready` → **200** (DB reachable; a **503** here means the connection string / firewall / DB login is wrong).
3. Browse `https://<host>/` → login page; sign in; open a migrated screen (e.g. `/Hr/State`) from the menu.
4. Logs: check `Logs\*.log` next to the site. If the site won't start at all, enable stdout in `web.config` (`stdoutLogEnabled="true"`, `stdoutLogFile=".\logs\stdout"`) and check **Event Viewer → Application** for ANCM events.

## 6. Redeploying a new version

1. Drop `app_offline.htm` into the site folder to cleanly stop the app (releases file locks) — or stop the app pool.
2. Copy the new publish output.
3. Remove `app_offline.htm` / start the pool.

Notes:

- An app restart drops in-memory sessions, but users holding a valid `CbsAuth` cookie are transparently re-established by the middleware (session rehydration + menu reload) — **provided the Data Protection keys survived** (§3). In-flight row tokens are lost; users reopen the record.
- Keep `Logs\` and the DP key folder out of the wiped path.

## 7. Operational notes

- **App-pool recycling** — the default daily recycle is tolerable (cookie rehydration), but prefer a fixed off-hours time. Disable overlapped recycle if you see duplicate-process oddities (in-memory stores).
- **Idle timeout** — set to 0 (banking users expect the app warm), or enable Application Initialization (preload) so `/health` warms it.
- **Scaling** — this shape is one process by design. To scale, move to the [multi-host shape](iis-multi-host.md) and scale by module.
- **Monitoring** — poll `/health/ready` from your monitoring tool.
- **Never expose the dev DB switcher or dev screens** — they are Development-environment gated; keep `ASPNETCORE_ENVIRONMENT=Production`.

## 8. Related docs

- [iis-multi-host.md](iis-multi-host.md) — gateway + thin hosts on IIS
- [docker-single-host.md](docker-single-host.md) — same app in a container
- [../port-map.md](../port-map.md) — ports & project map (dev + deploy)
- [../architecture-overview.md](../architecture-overview.md) — what gets deployed
