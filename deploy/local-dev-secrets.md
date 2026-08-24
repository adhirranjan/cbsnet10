# Local dev secrets

DB credentials are kept out of source. The committed base `appsettings.json` of every project
carries **no** secrets — its connection strings are empty (`""`).

## Where local dev creds live

Each project's local DB credentials live in a **gitignored** `appsettings.Development.json` next to
its `appsettings.json`. That file is matched by `**/appsettings.Development.json` in `.gitignore`
(and `.dockerignore`), so it never gets committed or copied into an image.

To set up a fresh clone, copy the committed template and fill in your connection string:

```
cp TflCbs.Host.Main/appsettings.Development.json.example TflCbs.Host.Main/appsettings.Development.json
```

A `.example` (safe placeholder values) exists beside each real file:

- Runtime hosts: `TflCbs.Host.Main`, `TflCbs.Host.Hr`, `TflCbs.Host.Lockers`,
  `TflCbs.Host.RetailBanking`, `TflCbs.Host.Administration`
- Console/test: `TflCbs.Tests`, `TflCbs.Demo`, `TflCbs.Tools.PasswordReset`

The console/test projects build config with a manual `ConfigurationBuilder`, so they explicitly
`AddJsonFile("appsettings.Development.json", optional: true)` and copy it to their output dir. If the
file is absent (e.g. CI), the cross-provider test theories simply skip and the tools prompt/skip.

## Production

Production supplies the SQL Server connection string via the
`Database__ConnectionStrings__SqlServer` environment variable (or a secret store) — never a committed
file. Docker already does this: `compose.yaml` / `compose.multi.yaml` map
`Database__ConnectionStrings__SqlServer` from `${CBS_SQLSERVER_CONNSTRING}`, which is set in a
root `.env` (also gitignored). See `docs/deploy/docker-single-host.md`.

## Follow-ups

- **Rotate the `sa` / `sql@2019` password.** It was previously committed in source, so it must be
  treated as compromised and rotated wherever it is used.
- **Least-privilege login (deferred).** Dev currently uses `sa`. Replacing it with a least-privilege
  SQL login scoped to the CBS database is a deferred follow-up.
