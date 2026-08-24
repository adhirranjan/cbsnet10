# Database migrations — versioned DDL for CBS

Closes finding **#12** of the [architecture review](../architecture-review/ARCHITECTURE-REVIEW.md)
("No DB migration tooling — unrepeatable, un-versioned schema changes for a regulated cutover").

Before: five loose `.sql` files under `sql/` and `db/optimistic-concurrency/`, applied by hand, each
carrying its own `IF NOT EXISTS` guard because nothing tracked what had already run, with the Oracle
half commented out and "run this separately" in the header.

Now: every schema change is a **numbered, immutable script** in
[`TflCbs.Tools.DbMigrator/Migrations/`](../../TflCbs.Tools.DbMigrator/Migrations/), applied by
**DbUp** exactly once per database, in order, and recorded in the **`CbsSchemaVersions`** journal
table. That table is the audit trail: which script, applied when.

---

## The tool

`TflCbs.Tools.DbMigrator` — a standalone console app. It references **no** TflOmniDb, TflCbs.Entities or
Framework code on purpose: it has to run against a database whose schema does *not* yet match the
app's entity model. Scripts are embedded in the assembly, so a deployed migrator can never disagree
with the scripts it was built from.

| Command | What it does | Exit code |
|---|---|---|
| `status` | Lists applied and pending scripts. **Read-only.** | `0` up to date · `2` pending · `1` error |
| `preview` | Prints the SQL that `upgrade` would run. **Read-only.** | `0` / `1` |
| `upgrade` | Applies every pending script in order, journalling each. Prompts for `MIGRATE`. | `0` / `1` |
| `baseline` | Marks pending scripts as applied **without running them**. Prompts for `BASELINE`. | `0` / `1` |

Options: `--provider`, `--connection-string`, `--schema`, `--yes` (skip the prompt, for CI),
`--quiet`, `--help`.

### Configuration

The same keys every CBS host uses — so an environment that already runs a host already configures
the migrator:

```
Database:Provider                      SqlServer | Oracle | PostgreSql
Database:ConnectionStrings:<provider>
Database:Schemas:<provider>            defaults: dbo / (connection default) / public
```

From `appsettings.json` next to the binary, `appsettings.Development.json` (gitignored, local dev
only, never published), or environment variables — `Database__ConnectionStrings__SqlServer=…`, which
is exactly the form compose and the IIS `web.config` `<environmentVariables>` already use.

---

## Running it

### Local development

```powershell
dotnet run --project TflCbs.Tools.DbMigrator -- status
dotnet run --project TflCbs.Tools.DbMigrator -- preview
dotnet run --project TflCbs.Tools.DbMigrator -- upgrade
```

Copy `appsettings.Development.json.example` to `appsettings.Development.json` and fill in the dev
connection string first (see [local-dev-secrets.md](local-dev-secrets.md)).

### As part of a deploy

[`scripts/deploy-cbs.ps1`](../../scripts/deploy-cbs.ps1) **checks** the schema after the build and
before deploying, and warns loudly if the target database is behind. It does not apply DDL unless
you ask:

```powershell
powershell -File scripts\deploy-cbs.ps1                        # check + warn
powershell -File scripts\deploy-cbs.ps1 -Migrate               # check + apply
powershell -File scripts\deploy-cbs.ps1 -SkipMigrationCheck    # don't touch the DB
powershell -File scripts\deploy-cbs.ps1 -MigrateConnectionString "<cs>"
```

An unreachable database is reported as **unknown**, never as up to date.

### IIS (single or multi host)

The migrator publishes like any other project; run it once against the shared database:

```powershell
dotnet publish TflCbs.Tools.DbMigrator -c Release -o D:\publish\migrator
$env:Database__ConnectionStrings__SqlServer = '<connection string>'
D:\publish\migrator\TflCbs.Tools.DbMigrator.exe status
D:\publish\migrator\TflCbs.Tools.DbMigrator.exe upgrade
```

The multi-host shape has five sites against **one** database — migrate once, not per site.

### Docker (single or multi host)

A `cbs-migrate` service is defined in both compose files behind the **`migrate` profile**, so a
plain `docker compose up` never applies DDL:

```bash
docker compose --profile migrate run --rm cbs-migrate status
docker compose --profile migrate run --rm cbs-migrate upgrade --yes

docker compose -f compose.multi.yaml --profile migrate run --rm cbs-migrate status
```

It uses the same `Dockerfile` — the `PROJECT` build arg just selects a different project to publish.

---

## Adopting the migrator on an existing database

The `0001`–`0003` scripts describe changes that were **hand-applied before the migrator existed**, so
an existing CBS database already has them but has no journal. Two ways to reconcile, both correct:

1. **`upgrade`** — the three baseline scripts kept their original `IF NOT EXISTS` / ORA-01430 guards,
   so running them on an already-migrated database is a no-op that simply writes the journal rows.
   This is what was done on the dev database.
2. **`baseline`** — marks them applied without running them. Use this when you don't want the DDL
   executed at all (e.g. a production database you'd rather not touch).

Both leave the database in the same state: journal current, schema unchanged. From `0004` onwards
neither applies — new scripts run exactly once and need no guards.

---

## Authoring a migration

Full rules: [`TflCbs.Tools.DbMigrator/Migrations/README.md`](../../TflCbs.Tools.DbMigrator/Migrations/README.md).
The short version:

- One folder per provider — `Migrations/sqlserver/`, `oracle/`, `postgres/` — because CBS ships
  genuinely different DDL per provider, not one dialect translated at runtime.
- `NNNN_snake_case_name.sql`. The number is the order. The **same number is the same logical change**
  across providers; gaps are fine where a change doesn't apply to a provider.
- **Never edit an applied script.** The journal says `0002` ran; changing its contents gives two
  databases different schemas under the same version. Fix forward with a new number.
- Build the tool after adding a script (they are embedded resources), then `preview`, then `upgrade`.

## Current scripts

| # | Change | SQL Server | Oracle | PostgreSQL |
|---|---|:--:|:--:|:--:|
| 0001 | `a_User.PASSWORDHASH` / `PASSWORDVERSION` (C-2 PBKDF2 passwords) | ✅ | ✅ | ✅ |
| 0002 | `G_STATE.VERSION` optimistic-concurrency counter (H-6) | ✅ | ✅ | ✅ |
| 0003 | `IDX_B_ACCOUNT_ORGID` — branch-scoped account index | — *(equivalent clustered index already exists)* | ✅ | — |

**Verified on two live providers (2026-07-30):**

- **SQL Server** (dev, `Trustbank_MDCC_TEST`) — journal created, both scripts applied, re-run reports
  up to date. Both changes were already present, so the guards made them no-ops — the adopt-an-existing-database
  path above, exercised for real.
- **Oracle** (dev, `192.168.1.161/ORCL`, schema `TFLCBS`) — all three applied and independently
  confirmed against the data dictionary. The identifier-casing caveat these scripts carried is
  **resolved**: the schema uses unquoted UPPERCASE names (`A_USER`, `G_STATE`, `B_ACCOUNT`), exactly
  what the scripts assume. `0001` and `0002` did real work (the columns were genuinely missing on
  Oracle — `A_USER` gained `PASSWORDHASH VARCHAR2(200)` / `PASSWORDVERSION NUMBER`, `G_STATE` gained
  `VERSION NUMBER NOT NULL` with all 44 rows at 0). `0003` found `IDX_B_ACCOUNT_ORGID` already
  present, so its ORA-00955 guard fired and no duplicate index was created — the guard mechanism
  proven on a live instance.

**PostgreSQL is still unverified** — no PostgreSQL connection string is configured for this
environment. Those two scripts keep the lowercase-folding caveat in their headers; check the real
casing before a first apply.

## Known limits

- **No down-migrations.** DbUp is forward-only by design. A bad change is corrected by a new script,
  and a genuine rollback is a database restore — which is the DR posture's job (finding #13), not
  this tool's.
- **No automatic baseline of the legacy schema.** The journal starts at `0001`; it does not
  reproduce the existing TrustBank schema from an empty database. Scripting the current DDL as an
  already-applied `0000` would add that, and is worth doing before the cutover.
- **The migrator is not run automatically at host startup**, deliberately: in the multi-host shapes
  four processes would race to apply DDL to one database on every restart, with the gateway routing
  traffic mid-migration. Migrating is a discrete, approvable step.
