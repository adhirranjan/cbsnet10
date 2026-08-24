# Definition of Done — a migrated screen

> What "finished" means for one screen, and what a reviewer checks before accepting it.
> The build tutorial is [`building-a-crud-screen.md`](building-a-crud-screen.md); this is the gate at
> the other end of it.
>
> **Scope:** one migrated screen (a master, config or inquiry screen). Transaction and maker-checker
> screens carry extra rules that belong with their own domain lead.

---

## 0. The one-line test

> **A migrated screen is done when the legacy `.aspx` link opens the new screen, it does what the old
> one did, and nothing about it needed a special explanation.**

Everything below is that sentence, itemised.

---

## 1. Author's gate — before you request review

Do not open a review until all of these are green. A reviewer's time is the scarce resource, not yours.

- [ ] `dotnet build TflCbs.Host.Main` — clean, **zero new warnings** (stop the running app first).
- [ ] `dotnet test TflCbs.Tests` — passing.
- [ ] `dotnet test TflCbs.ArchTests` — passing (this is the one that catches boundary breaks).
- [ ] `node --check <file>` for every JavaScript file you touched.
- [ ] You ran the screen and exercised **every** action: search, open, save, update, delete, cancel.
- [ ] You opened the **legacy** screen side by side and compared field for field.

## 2. Parity — this is a migration, not a redesign

- [ ] Every field on the legacy screen exists here, or its absence is a **deliberate, stated** decision
      in the PR description. Silently dropped fields are the most common defect in this programme.
- [ ] Validation matches the legacy screen's — required fields, lengths, allowed characters.
- [ ] Legacy-screen behaviour that looks like a bug is **reproduced and flagged**, not silently fixed.
      Bug-for-bug parity is the default; breaking it is a decision someone signs off on.
- [ ] Labels, column order and screen title match the legacy screen. Users are being retrained on
      nothing.
- [ ] The legacy stored procedure's logic is fully accounted for — every branch, not just the happy path.

## 3. Service layer

- [ ] Lives in `TflCbs.Modules.<Domain>/`, namespace matching the assembly.
- [ ] Every public method returns **`Result`/`Result<T>`**. No exceptions cross the service boundary.
- [ ] **`Repository<T>` only** — no raw SQL, no stored procedure for new master CRUD.
- [ ] Shared helpers come from `using static TflCbs.Abstractions.ServiceQuery;` / `...DbErrors;` —
      **no private copy** of `Has`/`Eq`/`Val`/`Paged`/`IsDuplicate`/`IsForeignKey`.
- [ ] Updates use the **partial** `UpdateAsync(entity, s => s.Col, ...)`, or a deliberate
      load-mutate-save. The full overload rewrites every mapped column and blanks what you didn't set.
- [ ] Duplicate-key and foreign-key violations are turned into a **readable message** via `DbErrors`,
      not surfaced as a raw provider error.
- [ ] Registered with one `AddScoped` line in that assembly's `<Domain>Module.AddServices` — **not** in
      `Program.cs`.

## 4. Controller

- [ ] Inherits `CbsScreenController`, in the web RCL of the screen's **menu area** (not necessarily its
      data domain).
- [ ] `[CbsAccessScreen("<Area>/<Screen>")]` present, covering **every** action — including `save`,
      `update`, `delete` and `search`. An unguarded POST is an access hole.
- [ ] Real primary keys never reach the client. Row tokens only: `TryOpenRecord`/`TryBeginWrite` to
      read, `TryConsume` to write, and a **fresh `ProtectId`** on every redisplay.
- [ ] Token ids are strings — parsed to the service's PK type at the call site (watch `decimal` PKs).
- [ ] Every `Result` is handled: success and failure both produce a user-visible outcome.
- [ ] If the table has a row-version column, the form carries `int Version` and a concurrency conflict
      shows a real message rather than silently overwriting.

## 5. View & client

- [ ] Reuses the existing components — record picker, account picker, date picker, search modal. A
      hand-rolled equivalent of something on `/Dev/Components` is a reject.
- [ ] **No inline `<script>`, no inline `style=`, no `onclick=`** — the CSP is strict (`script-src`/
      `style-src 'self'`, no `unsafe-inline`). Inline anything silently fails at runtime.
- [ ] POSTs use the command-dispatch idiom: `<button name="command" value="...">`.
- [ ] Server CRUD outcomes use the blocking ack modal; client-side guards use a transient toast.
- [ ] Text inputs uppercase by default (`cbs-uppercase.js`); `cbs-keep-case` only where the legacy
      screen genuinely preserved case.
- [ ] Client assets kebab-case; no new JavaScript library added for something the existing helpers do.

## 6. Access & cutover

- [ ] The screen's `a_Menus.NavigateURL` is set to the new route by a **DbMigrator migration** (one
      per provider, applied with `-- upgrade`), and you **verified the menu link opens the new screen**.
      `AllowedUrls` is derived from that column, so a row still holding `~/x.aspx` means the screen is
      unreachable in production and is not done.
- [ ] Each row points at its own screen only. `AllowedUrls` comes from these URLs, so pointing a row at
      a different screen's route grants its holders that screen.
- [ ] You confirmed the screen is **denied** to a user without the menu entry. Fail-closed is only real
      if someone checked it.

## 7. Tests & docs

- [ ] Service public API added/changed/removed → the **`cbs-sync-test-demo`** agent has been run, and
      `TflCbs.Tests` passes.
- [ ] A shared UI component was touched → the **`component-demo`** and **`component-docs-sync`** agents
      have been run.
- [ ] `CHANGELOG.md` has its one line: `[YYYY-MM-DD] feat: <screen> migrated`.
- [ ] The PR description names the **legacy screen and stored procedure** this replaces. Six months on,
      that is the only way anyone reconstructs what was ported.

---

## Automatic reject — no discussion needed

These are cheap to spot and expensive to leave in. A reviewer stops at the first one.

| Reject | Why |
|---|---|
| Raw SQL or a stored procedure for new master CRUD | `Repository<T>` only — a hard project rule |
| A service method that throws instead of returning `Result` | Callers have no error path |
| A real primary key in markup, a URL or a hidden field | Row tokens exist precisely to prevent this |
| A missing or partial `[CbsAccessScreen]` | Unguarded actions bypass the fail-closed guard |
| Inline script, inline style or an `onclick=` handler | Blocked by the CSP; it will not run |
| A private copy of `Has`/`Eq`/`Val`/`IsDuplicate`/... | Fails `SharedServiceHelperTests`; the reason they were extracted |
| A new screen whose `a_Menus.NavigateURL` still holds `~/x.aspx` | Nobody can reach it |
| A field on the legacy screen that quietly vanished | The single most common parity defect |
| A new NuGet package for something already solved here | Ask before adding a dependency |

---

## Reviewer's 60-second smoke test

If you only have a minute, do this — it catches most of what matters:

1. Open the **legacy** screen and the new one side by side. Count the fields. They should match.
2. Save an invalid record. You should get a readable message, not a stack trace and not silence.
3. Save a duplicate. Same.
4. Open a record, then open a second one. The row token must have changed.
5. Search `grep` the diff for `SELECT `, `<script`, `onclick=`, `style="`. All four should be absent.
