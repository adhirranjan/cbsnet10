# Day One — hands-on setup for new developers

> Get the app running, see the parts catalogue, ship one screen. Everything here already exists in
> the repo — nothing to design, nothing to decide.
>
> Budget: **~30 minutes to a running app**, then your first screen on day two.
> Deeper reading comes later; the links at the end are for when you need them, not now.

---

## 0. Before you start

| Need | Notes |
|---|---|
| .NET 10 SDK | `dotnet --version` should print 10.x |
| Visual Studio 2022 / VS Code / Rider | any of them; the solution is `TflCbsNet10Sol.slnx` |
| SQL Server dev DB access | ask for the connection string — see step 1 |
| Node (for `node --check`) | only needed when you touch JavaScript |

**The legacy app is reference material, not a workspace.** It lives outside this solution
(`Trust.Bank.Publish\`). You read it to learn what a screen did. You never edit it.

---

## 1. Get it running

```bash
# 1. Local DB credentials. This file is gitignored — it must NEVER be committed.
cp TflCbs.Host.Main/appsettings.Development.json.example TflCbs.Host.Main/appsettings.Development.json
#    then fill in the connection string (ask your lead for the dev DB credentials)

# 2. Entities first — TflCbs.Entities is referenced by bare-DLL HintPath, so there is
#    no build-order edge to make this happen automatically.
dotnet build TflCbs.Entities
dotnet build TflCbs.Host.Main

# 3. Run
dotnet run --project TflCbs.Host.Main          # https://localhost:7225  (http://localhost:5019)

# 4. Prove the test suites run for you too
dotnet test TflCbs.Tests              # service/DB tier
dotnet test TflCbs.ArchTests         # architecture boundaries — see section 4
dotnet test TflCbs.IntegrationTests  # real pipeline, in-process
```

**Log in** with any `a_User` account. Every user is currently on the temporary password `a`
(from the password-hashing migration); change-password is at `/Account/ChangePassword`.

> **Stop the app before your next build.** A running instance locks the DLLs and the build fails
> with a confusing file-in-use error. This includes an instance Visual Studio's debugger launched —
> stop the debugger, don't just close the browser tab.

Other runnable hosts (the thin per-module hosts and the gateway) and their ports are in
[`port-map.md`](../port-map.md). You do not need them on day one.

---

## 2. Look before you write — `/Dev/Components`

With the app running, open **`https://localhost:7225/Dev/Components`**.

That page is the parts catalogue: every reusable UI component in the system — record picker, account
picker, date picker, search modal, notifications, action bar — rendered live on dummy data with each
option demonstrated. It is Development-only (404s elsewhere).

Spend ten minutes clicking it. Most "how do I build X?" questions in your first week are answered by
"that component already exists and here is what it looks like". The legacy-control to new-component
mapping is in [`legacy-vs-new-components.md`](../legacy-vs-new-components.md).

---

## 3. Your first screen — copy State and rename it

Read [`building-a-crud-screen.md`](building-a-crud-screen.md). It walks the **State** master
(`/Hr/State`) end to end — the cleanest full-CRUD screen in the repo — and its section 11 is a
checklist for building a new master by renaming it. That checklist is your first task:

1. **Entity** — new table? scaffold it, then `dotnet build TflCbs.Entities` **first**.
2. **Service** — into `TflCbs.Modules.<Domain>/`, returning `Result`/`Result<T>`, shared helpers via
   `using static TflCbs.Abstractions.ServiceQuery;` / `...DbErrors;`.
3. **Register** — one `AddScoped` line in that assembly's `<Domain>Module.AddServices`, *not* in `Program.cs`.
4. **Form model** — `YourThingForm : IRowForm` in the web RCL's `Models/<Area>/`.
5. **Controller** — inherit `CbsScreenController`, copy State's actions.
6. **View** — copy `Areas/Hr/Views/State/Index.cshtml`, adjust fields and columns.
7. **Route cutover** — a DbMigrator migration pointing the screen's `a_Menus.NavigateURL` at `/Area/YourThing`.
8. **Build and verify** (section 5 below).

Everyone ships one Simple master this way before touching anything larger. If the guide fails you
anywhere, that is a bug in the guide — fix it, and the next person is faster.

---

## 4. The rules the build enforces

These are not style preferences — `TflCbs.ArchTests` fails the build on them. Knowing them
now saves you an afternoon of arguing with a red test.

- **Namespace == assembly.** Every type sits under a namespace starting with its own assembly name, so
  a `using` tells you what you are coupling to.
- **Framework and screens stay separate.** `TflCbs.Framework` never references a module or a
  screen RCL. Modules reach the framework through the four ports in `TflCbs.Abstractions`.
- **No private copies of the shared service helpers.** `Has`/`Eq`/`Val`/`Paged`/`IsDuplicate`/
  `IsForeignKey` come from `TflCbs.Abstractions` via `using static`. Need different semantics? Give it
  a different name.
- **No raw SQL or stored procedures for new master CRUD** — use `Repository<T>`. Legacy raw SQL is
  preserved only where it was already migrated that way.
- **Services return `Result`/`Result<T>`** — no throwing across the service boundary, no silent failures.
- **Access is fail-closed** (`CbsAccessMiddleware`). Never widen access or bypass the menu/route guard.
- **Reusable components stay additive with safe defaults** — never break an existing picker to extend it.
- **Every deployed module assembly must be handed to `AddCbsModules`** — startup throws otherwise.

---

## 5. The verification loop

| After you change... | Run |
|---|---|
| C# / Razor | `dotnet build TflCbs.Host.Main` (stop the app first) |
| `TflCbs.Entities` | `dotnet build TflCbs.Entities`, **then** the dependents |
| JavaScript | `node --check <file.js>` |
| A service's public API | the **`cbs-sync-test-demo`** agent, then `dotnet test TflCbs.Tests` |
| A shared UI component | the **`component-demo`** + **`component-docs-sync`** agents |
| UI behaviour | run the app and click it |

---

## 6. First-week friction (all of it avoidable)

- **Build fails with a file-in-use error** — the app is still running. Stop it, including under the debugger.
- **Entity changes don't show up** — you skipped `dotnet build TflCbs.Entities` first.
- **`appsettings.Development.json`** is gitignored and must stay that way; it holds DB credentials.
  Every project has a committed `.example` twin — see [`local-dev-secrets.md`](../deploy/local-dev-secrets.md).
- **Row tokens are strings.** `CbsScreenController`'s token helpers hand you a `string` — parse it to
  your service's PK type at the call site, and watch for `decimal` PKs.
- **Two people editing `TflCbs.Web.Shared` will collide.** The per-module split isolates domain
  code, not the shared layout/partials/wwwroot. Coordinate before touching it.

---

## 7. Where to look next

| Question | Document |
|---|---|
| How is the solution laid out? | [`architecture-overview.md`](../architecture-overview.md) |
| What runs on which port? | [`port-map.md`](../port-map.md) |
| How do I build a screen? | [`building-a-crud-screen.md`](building-a-crud-screen.md) |
| How do search and row tokens work? | [`search-and-rowtoken-flow.md`](search-and-rowtoken-flow.md) |
| Which new component replaces this legacy control? | [`legacy-vs-new-components.md`](../legacy-vs-new-components.md) |
| I need a brand-new module | [`starting-a-new-module.txt`](starting-a-new-module.txt) |
| Why is the codebase split this way? | [`architecture/modular-monolith.md`](../architecture/modular-monolith.md) |
| Everything else | [`docs/README.md`](../README.md) — the full documentation index |
