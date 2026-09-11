# CBS screens — code guide (xnet batch 7)

Working notes for the 13 screens in [`BACKLOG-screens-xnet-7.md`](../BACKLOG-screens-xnet-7.md): where the
code is, how each flow runs, and why it sits where it does. Written to code from, not to read.

Paths are relative to the solution root.

## Contents

- [Study order](#study-order) — the order to read these sections in, which is **not** their numbering
- [0. Shared plumbing](#0-shared-plumbing)
  - [Token rules (get these wrong and you ship a bug)](#token-rules-get-these-wrong-and-you-ship-a-bug)
  - [The access guard, in order](#the-access-guard-in-order)
  - [Two mechanisms it pays to understand](#two-mechanisms-it-pays-to-understand)
  - [Notifications](#notifications)
  - [Service conventions](#service-conventions)
- [0.1 Checklist: building a new master screen](#01-checklist-building-a-new-master-screen)
- [1. Denomination Unit](#1-denomination-unit)
  - [1.1 Files](#11-files)
  - [1.2 Why the code sits where it does](#12-why-the-code-sits-where-it-does)
  - [1.3 The controller](#13-the-controller)
  - [1.4 The view — every idea in 97 lines](#14-the-view-every-idea-in-97-lines)
  - [1.5 Flows](#15-flows)
  - [1.6 The service](#16-the-service)
  - [1.7 Rules](#17-rules)
  - [1.8 Divergences from legacy (all deliberate)](#18-divergences-from-legacy-all-deliberate)
  - [1.9 Gotchas — verified against the live DB (7 Sep 2026)](#19-gotchas-verified-against-the-live-db-7-sep-2026)
  - [1.10 Live data](#110-live-data)
- [2. Denominations](#2-denominations)
  - [2.1 Files](#21-files)
  - [2.2 Why the code sits where it does](#22-why-the-code-sits-where-it-does)
  - [2.3 The controller](#23-the-controller)
  - [2.4 The view](#24-the-view)
  - [2.5 The cascading picker — the thing to copy](#25-the-cascading-picker-the-thing-to-copy)
  - [2.6 Flows](#26-flows)
  - [2.7 The service](#27-the-service)
  - [2.8 Rules](#28-rules)
  - [2.9 Gotchas](#29-gotchas)
- [3. Holding Amount (4 screens)](#3-holding-amount-4-screens)
  - [3.1 Files](#31-files)
  - [3.2 Why the code sits where it does](#32-why-the-code-sits-where-it-does)
  - [3.3 The scroll — how maker-checker actually works](#33-the-scroll-how-maker-checker-actually-works)
  - [3.4 The controller](#34-the-controller)
  - [3.5 The views](#35-the-views)
  - [3.6 Flows](#36-flows)
  - [3.7 The service](#37-the-service)
  - [3.8 Service API](#38-service-api)
  - [3.9 Gotchas](#39-gotchas)
- [4. Direct Credit Outgoing (2 screens)](#4-direct-credit-outgoing-2-screens)
  - [4.1 Files](#41-files)
  - [4.2 Why the code sits where it does](#42-why-the-code-sits-where-it-does)
  - [4.3 ⛔ Posting is deferred — how the refusal is shaped](#43-posting-is-deferred-how-the-refusal-is-shaped)
  - [4.4 The draft invariant — the guard to copy](#44-the-draft-invariant-the-guard-to-copy)
  - [4.5 The controller](#45-the-controller)
  - [4.6 The views](#46-the-views)
  - [4.7 The JavaScript — 229 lines](#47-the-javascript-229-lines)
  - [4.8 Flows](#48-flows)
  - [4.9 The service](#49-the-service)
  - [4.10 Gotchas](#410-gotchas)
- [5. Dormant Re Activation (2 screens)](#5-dormant-re-activation-2-screens)
  - [5.1 Files](#51-files)
  - [5.2 Why the code sits where it does](#52-why-the-code-sits-where-it-does)
  - [5.3 The one case that completes](#53-the-one-case-that-completes)
  - [5.4 The charge is priced by the service, never posted by the form](#54-the-charge-is-priced-by-the-service-never-posted-by-the-form)
  - [5.5 Reject is archive-and-delete, not a status stamp](#55-reject-is-archive-and-delete-not-a-status-stamp)
  - [5.6 The download gate — server-side](#56-the-download-gate-server-side)
  - [5.7 Uploads: FileUploads, not ImageUploads](#57-uploads-fileuploads-not-imageuploads)
  - [5.8 The controller](#58-the-controller)
  - [5.9 The service](#59-the-service)
  - [5.10 Flows](#510-flows)
  - [5.11 Gotchas — three found only by running the screen](#511-gotchas-three-found-only-by-running-the-screen)
- [6. User Creation](#6-user-creation)
  - [6.1 Files](#61-files)
  - [6.2 Why the service is in Core.Authentication](#62-why-the-service-is-in-coreauthentication)
  - [6.3 The controller](#63-the-controller)
  - [6.4 The view](#64-the-view)
  - [6.5 Privilege guard — GetUserLevelsAsync and CanAssignLevel](#65-privilege-guard-getuserlevelsasync-and-canassignlevel)
  - [6.6 The service](#66-the-service)
  - [6.7 Service API](#67-service-api)
  - [6.8 Gotchas](#68-gotchas)
- [7. Signature Image Upload (2 menu rows)](#7-signature-image-upload-2-menu-rows)
  - [7.1 Files](#71-files)
  - [7.2 Three screen keys in one controller](#72-three-screen-keys-in-one-controller)
  - [7.3 Serving an image safely](#73-serving-an-image-safely)
  - [7.4 Limits come from bank variables, resolved in the controller](#74-limits-come-from-bank-variables-resolved-in-the-controller)
  - [7.5 The controller — command dispatch and lanes](#75-the-controller-command-dispatch-and-lanes)
  - [7.6 The views — one partial, rendered twice](#76-the-views-one-partial-rendered-twice)
  - [7.7 The service](#77-the-service)
  - [7.8 The placeholder (menu 2788)](#78-the-placeholder-menu-2788)
  - [7.9 Gotchas](#79-gotchas)
- [Still open](#still-open)

### All 13 menu rows

| Menu | Screen | CBS module | Route | Section |
|---|---|---|---|---|
| 893 | Denomination Unit | Central Administration | `/Bank/DenominationUnit` | [1](#1-denomination-unit) |
| 890 | Denominations | Central Administration | `/Bank/Denomination` | [2](#2-denominations) |
| 2784 | Holding Amount Entry | Retail and Corporate Operations | `/RetailBanking/AccHoldingAmount` | [3](#3-holding-amount-4-screens) |
| 2785 | Holding Amount Authorization | Retail and Corporate Operations | `…/Authorize` | [3](#3-holding-amount-4-screens) |
| 2786 | Holding Amount Release | Retail and Corporate Operations | `…/Release` | [3](#3-holding-amount-4-screens) |
| 2787 | Holding Amount Release Authorization | Retail and Corporate Operations | `…/ReleaseAuthorize` | [3](#3-holding-amount-4-screens) |
| 3287 | Direct Credit Entry | Retail and Corporate Operations | `/RetailBanking/DirectCredit` | [4](#4-direct-credit-outgoing-2-screens) |
| 3288 | Direct Credit Authorization | Retail and Corporate Operations | `…/Authorize` | [4](#4-direct-credit-outgoing-2-screens) |
| 951 | Dormant Re Activation | Retail and Corporate Operations | `/RetailBanking/DormantReactivation` | [5](#5-dormant-re-activation-2-screens) |
| 952 | Dormant Re Activation Authorization | Retail and Corporate Operations | `…/Authorize` | [5](#5-dormant-re-activation-2-screens) |
| 828 | User Creation | Central Administration | `/Administration/User` | [6](#6-user-creation) |
| 998 | Signature Image Upload | Retail and Corporate Operations | `/RetailBanking/Signature` | [7](#7-signature-image-upload-2-menu-rows) |
| 2788 | Signature Image Upload Authorization | Retail and Corporate Operations | `…/Signature/Authorize` | [7](#7-signature-image-upload-2-menu-rows) — **placeholder** |

**CBS module** is the bank-facing module the row hangs under (`a_Module.ModuleName` via `a_ModuleMenuMap`) —
what the user picks in the module chooser. It is a separate axis from the code module the service lives in:
the denomination screens sit under Central Administration but are `TflCbs.Modules.Reference`-backed and
served from `TflCbs.Modules.Bank.Web`, and User Creation's service is in `TflCbs.Core.Authentication`.

### Study order

The sections below are numbered roughly in **build** order (see the backlog's *Suggested order*, which is
sequenced by prerequisites). To **learn** the codebase, sequence instead by what each screen is the first to
introduce:

| # | Study | Guide § | First screen that teaches… | Feels like |
|---|---|---|---|---|
| 1 | **Denomination Unit** | [§1](#1-denomination-unit) | the whole skeleton — controller base class, row tokens, search descriptor, `Result` service, CRUD | ~1 h |
| 2 | **Denominations** | [§2](#2-denominations) | a second picker scoped by the first; screen-specific JS; a frozen record | ~45 m |
| 3 | **Holding Amount** | [§3](#3-holding-amount-4-screens) | **maker-checker** — scrolls, transactions, one controller with four screen keys, the account picker | ~2 h |
| 4 | **Signature Upload** | [§7](#7-signature-image-upload-2-menu-rows) | file **in** and file **out** — serving user bytes safely, screen key as a capability | ~1 h |
| 5 | **User Creation** | [§6](#6-user-creation) | privilege rules, the single password path, indexed grid binding | ~1.5 h |
| 6 | **Direct Credit** | [§4](#4-direct-credit-outgoing-2-screens) | header/detail, JSON grid, CSV import, the **posting boundary** | ~2 h |
| 7 | **Dormant Re Activation** | [§5](#5-dormant-re-activation-2-screens) | nothing new — it **combines** all of the above | ~2 h |

Read [§0 Shared plumbing](#0-shared-plumbing) and [`know-your-code.md` §1 (row tokens)](know-your-code.md#1-row-tokens--the-four-helpers)
first — tokens appear on every screen, and not knowing them makes screen 1 confusing for the wrong reason.

**Why this differs from the numbering**, in two places only. **Signature (§7)** moves up: it is small, needs
nothing beyond screen 1, and sets up the contrast Dormant depends on — `ImageUploads` gates the type going in
and sniffs going out, `FileUploads` gates nothing and pushes the safety onto the serving side (§5.7).
**User Creation (§6)** moves up because it has no scroll and no posting, so it builds on neither §3 nor §4 —
it is an independent axis (privilege and credentials) and it breaks up three heavy transactional screens.

**Dormant last, always.** It is the synthesis: maker-checker (§3), draft invariant and posting refusal (§4),
uploads (§7), a cascade-fed denomination grid (§2). Read first it is overwhelming; read last it is mostly
recognition.

**Short on time?** `1 → 3 → 5` gives ~80% of the patterns: skeleton, maker-checker, then the one that has
everything.

**How to read:** guide section open beside the actual file — this is written to be read *against* the code,
not instead of it. Each `§N.1 Files` table is the list to open. Two things worth doing rather than reading:
after §1, trace one save from the button to the `INSERT` without the guide; after §3, redraw the four-state
table from memory. Everything later assumes both.

---

## 0. Shared plumbing

Five pieces do most of the work. Know these and a master screen is ~150 lines of controller.

| Piece | Where | What it gives you |
|---|---|---|
| `CbsScreenController` | [TflCbs.Framework/Infrastructure/CbsScreenController.cs](../TflCbs.Framework/Infrastructure/CbsScreenController.cs) | `UserId`, `OrgElementId`, `WorkingDate`, token helpers, `SavedOk`/`UpdatedOk`/`DeletedOk`, `RunSearch`, `EditFailed`, `TryLoad` |
| `RowToken` | [TflCbs.Framework/Infrastructure/RowToken.cs](../TflCbs.Framework/Infrastructure/RowToken.cs) | Encrypted opaque ids. Payload `screen\|sessionId\|nonce\|id` via `IDataProtector` |
| `SearchEndpoint` | [TflCbs.Framework/Services/SearchEndpoint.cs](../TflCbs.Framework/Services/SearchEndpoint.cs) | Takes a fetch delegate, tokenizes the `Id` column, decides client vs server paging |
| `CbsAccessMiddleware` | [TflCbs.Framework/Infrastructure/CbsAccessMiddleware.cs](../TflCbs.Framework/Infrastructure/CbsAccessMiddleware.cs) | Global fail-closed guard. Not a filter — you cannot forget it |
| `EditViewModel<TForm>` | [TflCbs.Framework/Models/Shared/EditViewModel.cs](../TflCbs.Framework/Models/Shared/EditViewModel.cs) | `{ Form, IsEditMode }`. Don't write per-screen view models |

### Token rules (get these wrong and you ship a bug)

```csharp
TryOpenRecord(token, out id)   // GET  — resolve only, survives refresh
TryBeginWrite(token, out id)   // POST — resolve only, NOT yet spent
TryConsume(token, out id)      // POST — single-use, records the nonce in session
ProtectId(id)                  // mint a fresh token for the form
```

Order on update: **resolve → validate → consume**. Consuming before validation burns the token on a typo.
Delete has nothing to validate, so it consumes immediately.

### The access guard, in order

```
routing → session → CbsAccessMiddleware:
  authenticated?            no → Auth:LoginUrl?returnUrl=<absolute>
  module selected?          no → chooser
  [CbsAccessScreen(key)] ?? request path
      → UrlNormalizer.Normalize (strip ~, drop query, lowercase)
      → must be in store.Current.AllowedUrls   no → /AccessDenied
  financial year set?       no → /Account/Login?reason=financialyearnotfound
```

`AllowedUrls` comes from the user's `a_UserRights` rows joined to `A_MENUS.NavigateURL`. **A screen with no
menu row is a 403 for everyone**, which is why every screen ships a DbMigrator route-cutover script.

Sub-routes (`/save`, `/search`) are not menu items — that's what `[CbsAccessScreen(ScreenKey)]` is for: it
tells the guard which screen's right governs them. Controller-level covers the common case; override at
action level when one controller hosts two screen rights (Entry vs Authorize).

### Two mechanisms it pays to understand

**The paging probe** (`SearchEndpoint.RunAsync`). Instead of counting then fetching, it does **one** fetch of
up to `cap` rows (default 100, config `Cbs:Search:ClientPagingMaxRows`, hard ceiling 500). If the total came
back under the cap, those rows *are* the whole set — sent once with `ClientPaged = true`, and the widget pages
them in the browser with no further round-trips. Over the cap, the delegate has already sorted them, so the
first `pageSize` rows *are* page 1. The server decides, never the client; a screen may only express a
preference (`SearchDescriptor.ClientPaging`) and a lower ceiling. Turn it off (`ClientPaging = false`) when
rows change minute to minute, or when acting on a stale row would do damage. The cap is bounded because every
cached row of a tokenized grid mints a ~200-byte encrypted token that will probably go unused.

**The session-check cache** (`[CbsCacheSessionCheck]`). A picker dialog fires a request per keystroke, each
re-reading the session table. The attribute lets the guard reuse a **positive** "session still open" verdict
for `Auth:SessionCheckCacheSeconds` (default 30, clamped to 300), keyed by user id + session id, and **only on
GET** — a mis-annotated write can never be served a reused verdict. It caches the answer; it never skips the
check, and every other gate (menu right, financial year) still runs per request. 0 disables the cache, not the
check.

### Notifications

| Situation | Call | UI |
|---|---|---|
| CRUD outcome | `this.NotifySuccess` / `NotifyError`, `SavedOk` etc. | blocking ack modal |
| Client-side guard | `window.cbsNotify.error` | transient toast |

### Service conventions

- Return `Result` / `Result<T>` — **never throw across the boundary**.
- `Repository<T>` + `DataAccess`, no raw SQL and no procs for new master CRUD. Keep a proc only where legacy
  already had one and it is genuinely business logic (pricing, posting).
- Never re-declare `Has`/`Eq`/`Val`/`Paged`/`IsDuplicate`/`IsForeignKey` — `using static
  TflCbs.Abstractions.ServiceQuery;` / `…DbErrors;`. `SharedServiceHelperTests` fails the build on a copy.
- Entity props are UPPERCASE and all nullable (generated).

---

## 0.1 Checklist: building a new master screen

1. **Service** in the owning module. Constructor `(DataAccess data)`. Search / Load / Save / Update / Delete.
2. **Register** it: one `AddScoped<XService>()` in that module's `AddServices`.
3. **Form** class implementing `IRowForm` (gives you `Row`), with `[Required]`/`[Range]` carrying legacy's
   own message text.
4. **Controller** in the Area's web RCL, extending `CbsScreenController`:
   `[Area]`, `[Route]`, `[CbsAccessScreen(ScreenKey)]`, consts `HostUrl` / `ScreenKey` / `Noun`.
5. **View** `Areas/<Area>/Views/<Controller>/Index.cshtml` on `EditViewModel<TForm>`; emit a
   `SearchDescriptor` per grid/picker.
6. **Migration** `NNNN_menu_routes_<screen>.sql` × 3 dialects, with the count assertion. Apply by hand on
   xnet (no journal there).
7. **Tests + demo**: run the `cbs-sync-test-demo` agent; add the route rows to `AccessGuardTests`.
8. **Verify**: `dotnet build TflCbs.Host.Main` → `dotnet test` ×3 → run the app and click it through as
   `ratnesh`/`a` (`administrator` has no modules).

---

## 1. Denomination Unit

`/Bank/DenominationUnit` · menu **893** (module 1, parent 885) · table `g_DenominationUnit` · shipped
2026-09-05 · legacy `HO/MultiCurrency/g_DenominationUnit.aspx` (7 KB + 21 KB).

Two fields: a unit name scoped to a currency ("LRD", "USCENTS"). It is the parent of `g_Denomination` —
the Denominations screen hangs face values off it, and the cash denomination grid on Dormant Re Activation
groups by it. Pure master data: no money, no scroll, no branch scope.

### 1.1 Files

| Path | Role |
|---|---|
| [TflCbs.Modules.Reference/DenominationUnitService.cs](../TflCbs.Modules.Reference/DenominationUnitService.cs) | Service, 224 lines |
| [TflCbs.Modules.Reference/CurrencyService.cs](../TflCbs.Modules.Reference/CurrencyService.cs) | Currency picker source (moved here from TradeFinance) |
| [TflCbs.Modules.Bank.Web/Areas/Bank/Controllers/DenominationUnitController.cs](../TflCbs.Modules.Bank.Web/Areas/Bank/Controllers/DenominationUnitController.cs) | 7 actions, 159 lines |
| [TflCbs.Modules.Bank.Web/Areas/Bank/Views/DenominationUnit/Index.cshtml](../TflCbs.Modules.Bank.Web/Areas/Bank/Views/DenominationUnit/Index.cshtml) | The whole UI, 97 lines |
| [TflCbs.Modules.Bank.Web/Models/Bank/BankModels.cs](../TflCbs.Modules.Bank.Web/Models/Bank/BankModels.cs) | `DenominationUnitForm` (shares the file with `DenominationForm`) |
| [TflCbs.Modules.Reference/ReferenceModule.cs](../TflCbs.Modules.Reference/ReferenceModule.cs) | `AddScoped<DenominationUnitService>()` |
| [TflCbs.Tools.DbMigrator/Migrations/sqlserver/0013_menu_routes_denomination_unit.sql](../TflCbs.Tools.DbMigrator/Migrations/sqlserver/0013_menu_routes_denomination_unit.sql) | Route cutover ×3 dialects |
| [TflCbs.Tests/DenominationUnitServiceTests.cs](../TflCbs.Tests/DenominationUnitServiceTests.cs) | 8 cross-provider tests |

No JavaScript file — the screen emits `SearchDescriptor` JSON and shared `cbs-search.js` does the rest.

One table, `g_DenominationUnit` → entity `G_DENOMINATIONUNIT`:

| Column | Written by | Note |
|---|---|---|
| `DENOMINATIONUNITID` | DB identity | PK; never leaves the server in the clear — row tokens (§0) |
| `DENOMINATIONUNIT` | form | trimmed, stored as entered (case preserved — legacy parity) |
| `CURRENCYID` | picker | FK to `g_Currency`, re-validated server-side on every write |
| `CREATEDBY` / `CREATEDON` | save | never rewritten on update (§1.7) |
| `LASTMODIFIEDBY` / `LASTMODIFIEDON` | update | |
| `PASSEDBY` / `PASSEDON` | **nobody** | left NULL — no Authorize screen (§1.8) |

Read-only companions: `G_CURRENCY` (picker + code display), `G_DENOMINATION` (delete guard).

### 1.2 Why the code sits where it does

**Service in `Modules.Reference`, screen in `Modules.Bank.Web`.** Two independent axes:

- *Which Area serves the URL* — menu 893 sits under Central Administration, so the route is `/Bank/…` and
  `Bank.Web` serves it.
- *Which assembly owns the logic* — `Bank.Web`'s backing **service** module is General, and General is
  platform plumbing (menu, scroll, bank variables), not master data. So the service goes to Reference.

Reference is a **core** module (`ICoreCbsModule`): registered unconditionally, never gated on
`Modules:Enabled`. Its admission rule: no domain behaviour **and** ≥2 domains consume it. Denomination Unit
passes (cash-handling screens in more than one domain). `LockerMake` would not.

That costs exactly one line in [TflCbs.Modules.Bank.Web.csproj](../TflCbs.Modules.Bank.Web/TflCbs.Modules.Bank.Web.csproj):

```xml
<ProjectReference Include="..\TflCbs.Modules.Reference\TflCbs.Modules.Reference.csproj" />
```

`WebModuleBoundaryTests` allows a **core** service reference here and fails the build on a sibling-domain
one. Same split already applies to State/District: HR menu, Reference code.

### 1.3 The controller

159 lines, five actions, one private helper. No `try`, no SQL, no `HttpContext`, no mapper, no antiforgery
attribute — each of those is someone else's job, and knowing whose is most of reading this file.

```csharp
[Area("Bank")]                        // views live in Areas/Bank/Views/DenominationUnit/
[Route("Bank/DenominationUnit")]      // pinned: A_MENUS.NavigateURL holds this exact string
[CbsAccessScreen(ScreenKey)]          // /search, /save, /update, /delete authorize as this screen
public sealed class DenominationUnitController(
    CbsSessionStore store, DenominationUnitService svc, CurrencyService currencies,
    SearchEndpoint searchEndpoint, RowToken tokens)
    : CbsScreenController(store, tokens, searchEndpoint)
{
    private const string HostUrl    = "/Bank/DenominationUnit";   // every success redirects here
    private const string ScreenKey  = "Bank/DenominationUnit";    // access right AND row-token binding
    private const string Noun       = "Denomination unit";        // "… saved successfully."
    protected override string Screen => ScreenKey;                // default for every `screen:` argument
```

`[CbsAccessScreen]` is not decoration. Sub-routes are **not menu items**, so `AllowedUrls` cannot contain them
and the fail-closed guard would refuse every POST without it. `ScreenKey` must be a `const` — attribute
arguments are compile-time.

**One key, two jobs:** the access-guard key *and* the screen stamped inside every row token, so a token minted
here can only ever be spent here.

**Five dependencies, two kinds.** Two services (both core `Reference`) and three framework pieces — and all
three framework pieces go straight to the base constructor. The controller never touches `RowToken` or
`SearchEndpoint` directly; it calls `ProtectId` / `RunSearch`.

`CbsScreenController` holds what was being copy-pasted per screen. It is **not** a template-method engine —
each screen still writes its own actions, which is why this file reads top to bottom:

| Base helper | Used by | What it does |
|---|---|---|
| `TryOpenRecord` / `TryBeginWrite` / `TryConsume` / `ProtectId` | B, F, G | the token rules (§0) |
| `TryLoad` | B | unwraps `Result<T?>`: failure · `null` = already deleted · value |
| `FirstError` | E, F | one message, not a list |
| `EditFailed` | F | notify + **re-mint** + re-render in edit mode |
| `RedirectToRecord` | G | notify + re-mint + reopen the record |
| `SavedOk` / `UpdatedOk` / `DeletedOk` | E, F, G | notify + redirect (PRG) |
| `RunSearch` | C, D | hands a fetch delegate to `SearchEndpoint` |
| `UserId`, `OrgElementId`, `WorkingDate` | E, F | session read here, passed to the service as parameters |

Two things that are absent on purpose:

- **No `[ValidateAntiForgeryToken]`.** `AddCbsFramework` registers `AutoValidateAntiforgeryTokenAttribute`
  globally, so every non-GET is validated whether or not the author remembered. Opt-out, not opt-in.
- **No `try`/`catch`.** Services return `Result`; failure is a value with a message, so there is nothing to
  catch and no path that 500s at the user.

`[Bind(Prefix = "Form")]` on each POST is the bridge to the view: the view's model is `EditViewModel<T>` so it
posts `Form.CurrencyId`, while the action wants a bare `DenominationUnitForm`.

### 1.4 The view — every idea in 97 lines

[Index.cshtml](../TflCbs.Modules.Bank.Web/Areas/Bank/Views/DenominationUnit/Index.cshtml) is the template every
other master screen copies. Two halves: **lines 1–59 build configuration, lines 62–97 are the markup.** No
`.js` file and no hand-typed URL — both deliberate.

| Block | Lines | What it is |
|---|---|---|
| `@model EditViewModel<DenominationUnitForm>` | 2 | `Form` + `IsEditMode`; that one boolean drives the action bar |
| `ViewData["SelectedMenu"]` | 5 | sidebar highlight **and** the card title (line 66) — they cannot drift |
| `searchDescriptor` | 7–26 | the Search modal |
| `currencyPicker` | 29–58 | the picker, carrying its own nested descriptor |
| `<form asp-action="Save">` | 62 | one form, three destinations |

`Url.Action(nameof(DenominationUnitController.SearchData))` — **never a string literal.** Renaming an action is
then a compile error here, not a broken button found by a user.

#### The descriptor is this screen's JavaScript

```csharp
SelectMode       = "navigate",
NavigateTemplate = "/Bank/DenominationUnit?row={token}",
```
```html
<button type="button" data-cbs-search='@Json.Serialize(searchDescriptor)'>Search</button>
```

The view *describes*; shared `cbs-search.js` reads the JSON off the clicked element and does the work. The
screen never calls a function.

`navigate` makes a row click nothing but a URL — refresh, Back and bookmarks all keep working, and opening a
record has exactly one implementation (flow B). `{token}` is substituted with the row's `IdKey` value, which
`SearchEndpoint` has already swapped for a `RowToken`; the primary key never reaches the browser.

| `SelectMode` | Used by | On pick |
|---|---|---|
| `navigate` | the screen's own grid | go to `NavigateTemplate` |
| `callback` | a picker inside a form | write `PickValueKey`/`PickTextKey` into the two inputs, close the dialog |

`Columns` ≠ `Filters`: grid headers vs the filter boxes above them. `GoFilterKey = "CurrencyCode"` is what
routes the → button to an exact resolve by code (flow D).

#### A picker is two inputs pretending to be one

```csharp
ValueName = "Form.CurrencyId",   ValueId = "Form_CurrencyId",    // hidden — what the server binds
TextName  = "Form.CurrencyCode", TextId  = "Form_CurrencyCode",  // visible — what the human reads
ValueValue = Model.Form.CurrencyId > 0 ? Model.Form.CurrencyId.ToString() : null,
TextValue  = Model.Form.CurrencyCode,
```

Dot in the **name** (model binding), underscore in the **id** (CSS selector). Not a style choice — §2.2's
cascade targets `#Form_CurrencyId` by selector, so the pair must follow ASP.NET's own convention.

`ValueValue`/`TextValue` are seeded from the model because a server re-render raises no client selection
event — the same reason flow B calls `FillDisplayTextAsync`. Omit them and every failed save silently empties
the currency box.

`asp-validation-for` points at the **id** (`Form.CurrencyId`), not the display text.

#### The action bar

```html
@if (!Model.IsEditMode) { Save } else { Update  Delete }

<button type="submit" formaction="@Url.Action(nameof(DenominationUnitController.Update))">Update</button>
<button type="submit" formaction="@Url.Action(nameof(DenominationUnitController.Delete))"
        data-cbs-confirm="Delete this denomination unit?">Delete</button>
```

`formaction` overrides the form's target per button, so **one form feeds three actions** and no server code has
to infer intent. (`name="command"` dispatch is the other half of that convention, for when a single action must
handle several commands — §5.7, §7.5.)

`data-cbs-confirm` is a `site.js` behaviour: native confirm, cancel aborts the submit. On Delete only.

Cancel is an `<a>` to `HostUrl` — the blank screen and the cancelled screen are the same page, so there is no
third state to maintain.

#### Ways to get it wrong

1. **Missing `type="button"` on Search** — a button inside a form submits, so Search would save.
2. **Forgetting `ValueValue`/`TextValue`** — the picker empties on every re-render.
3. **Hand-typing an action URL** — survives the rename, breaks at runtime.
4. **Treating `maxlength="50"` as the rule.** It mirrors the column and stops overtyping; the service is the
   enforcement.

### 1.5 Flows

#### A. Open blank — `GET /Bank/DenominationUnit`

```
guard → Index(row: null) → View(new EditViewModel<DenominationUnitForm>())
      → Index.cshtml: _RecordPicker (currency) + text input + [Save] [Search] [Cancel]
```

#### B. Open a record — `GET /Bank/DenominationUnit?row={token}`

```csharp
if (!TryOpenRecord(row, out var idStr) || !int.TryParse(idStr, out var unitId)) return View(vm);
if (!TryLoad(await svc.LoadDenominationUnitAsync(unitId, ct), $"{Noun} already deleted.", out var loaded))
    return View(vm);

vm.IsEditMode = true;                       // action bar flips to Update / Delete
vm.Form.DenominationUnit = loaded.DenominationUnit;
vm.Form.CurrencyId       = loaded.CurrencyId;
vm.Form.Row              = ProtectId(unitId.ToString());   // FRESH token for the write
await FillDisplayTextAsync(vm.Form, ct);    // re-resolve the currency CODE
```

One nullable parameter is the whole branch: no `row` → blank form, `row` → open that record. Two screens,
one action, because they render the same view.

**`TryOpenRecord`, not `TryConsume`** — a GET repeats (F5, Back, a re-requested asset). Every failure path
returns `View(vm)`, i.e. the **blank form plus a message** — never a 404 and never an exception.

`FillDisplayTextAsync` matters: the picker's visible box is display text filled by a client-side selection
event. A server re-render raises no such event, so without it you get an empty currency box next to a
populated hidden `CurrencyId`. Called on open **and** before every re-render.

#### C. Search — `GET /Bank/DenominationUnit/search`

View emits the descriptor onto the button:

```csharp
SelectMode = "navigate",
NavigateTemplate = "/Bank/DenominationUnit?row={token}",
Filters = [ new SearchFilter("DenominationUnit", …), new SearchFilter("CurrencyCode", …) ],
```

```
cbs-search.js opens modal → GET …/search?search.Filters[...]   [CbsCacheSessionCheck]
  → RunSearch(fetch, search, ct)
      → SearchEndpoint: probe-fetch up to 100 rows
          total ≤ 100 → send all, ClientPaged = true (browser pages locally, no more round-trips)
          total > 100 → first page only, server-paged
      → svc.SearchDenominationUnitsAsync → { Id, DenominationUnit, CurrencyCode }
      → SearchEndpoint replaces Id with RowToken.Protect(id, screen)
  → user picks a row → navigate to ?row={token}  → flow B
```

`[CbsCacheSessionCheck]` lets the guard reuse a *positive* session verdict for ≤30 s on GETs only. It
caches the answer, never skips the check.

The controller hands `SearchEndpoint` a **delegate**, not rows — that inversion is what lets the probe decide
client vs server paging without the screen knowing. Filters are read by the names the view declared
(`TryGetValue`, absent = no filter), and a failed fetch degrades to an empty grid, never a 500:

```csharp
return res.IsSuccess ? res.Value : ([], 0);
```

The service does the filtering in memory (`GetAllAsync` currencies into a dictionary, `GetAllAsync` units,
join) — no SQL is assembled, which is what keeps it portable across SQL Server / Postgres / Oracle.

#### D. Currency picker — `GET /Bank/DenominationUnit/search-currencies`

```csharp
var term = r.IsGo ? code : description;     // Go resolves by CODE exactly; dialog browses by description
await currencies.SearchCurrenciesAsync(term, …, exact: r.IsGo);
```
Called with **`tokenizeId: false`** — reference data, so the raw currency id goes to the client and is
re-validated server-side on save. `GoFilterKey = "CurrencyCode"` in the descriptor is what routes Go.

**The rule: tokenize what can be written to, not what is merely selected.** The screen's own grid (C) is
tokenized because each row is a record the user may then update or delete; a currency id is not a capability.
The safety for the untokenized half is the service's `Select a valid Currency.` check on every write.

#### E. Save — `POST /Bank/DenominationUnit/save`

```
FillDisplayTextAsync → ModelState invalid? NotifyError(FirstError()) + re-render
                     → svc.SaveDenominationUnitAsync(name, currencyId, UserId, ct)
                     → fail? NotifyError + re-render   |   ok? SavedOk(HostUrl, Noun)
```

No token work at all — a new record has no id to protect or consume.

**Failure re-renders, success redirects.** Re-render keeps the user's typing, so a refused duplicate is one
edit away from correct instead of retyped; `SavedOk` redirects (PRG) so a refresh cannot save twice.

#### F. Update — `POST /Bank/DenominationUnit/update`

```csharp
if (!TryBeginWrite(form.Row, out var idStr) || !int.TryParse(idStr, out var unitId)) return Redirect(HostUrl);
await FillDisplayTextAsync(form, ct);
if (!ModelState.IsValid) return EditFailed(idStr, form, FirstError());   // re-mints the token
if (!TryConsume(form.Row, out _, MsgAlreadyDone)) return Redirect(HostUrl);
var result = await svc.UpdateDenominationUnitAsync(unitId, form.DenominationUnit!, form.CurrencyId, UserId, ct);
if (!result.IsSuccess) return EditFailed(idStr, form, result.ErrorString);
return UpdatedOk(HostUrl, Noun);
```

**resolve → validate → consume → write.** Swap the middle two and every test still passes — then the first
user who mistypes a name loses the record. `TryBeginWrite` does the same work as `TryOpenRecord` and differs
only in the failure wording ("reopen the record", not "search again"), because the user's next step differs.
`EditFailed` re-mints, which is the only reason it exists; `TryConsume(..., out _, …)` discards the id because
step 1 already produced it — the call is made for the side effect.

#### G. Delete — `POST /Bank/DenominationUnit/delete`

```csharp
if (!TryConsume(form.Row, out var idStr) || !int.TryParse(idStr, out var unitId)) return Redirect(HostUrl);
var result = await svc.DeleteDenominationUnitAsync(unitId, ct);
if (result.IsSuccess) return DeletedOk(HostUrl, Noun);
this.NotifyError(result.ErrorString);
return RedirectToRecord(HostUrl, unitId.ToString());   // reopen with a fresh token after an FK refusal
```

Delete **consumes first**: there is nothing to validate, so the two-step dance would be ceremony. The refusal
is common in practice (six of the eight live units hold denominations), and the token is spent by then — hence
`RedirectToRecord`. **Any path that returns the user to a form after consuming must re-mint;** `EditFailed`
and `RedirectToRecord` exist so nobody has to remember.

### 1.6 The service

224 lines, five public methods, four private helpers, four message constants. The only place that knows what a
denomination unit *is*.

```csharp
Task<Result<(IReadOnlyList<IReadOnlyDictionary<string, object?>> Rows, int Total)>>
    SearchDenominationUnitsAsync(string? denominationUnit, string? currencyCode, string? sort, bool desc,
                                 int page, int pageSize, CancellationToken ct = default,
                                 int? currencyId = null);   // currencyId > 0 → cascade for the Denominations screen
Task<Result<DenominationUnitEdit?>> LoadDenominationUnitAsync(int id, CancellationToken ct = default);
Task<Result> SaveDenominationUnitAsync(string denominationUnit, int currencyId, int userId, CancellationToken ct = default);
Task<Result> UpdateDenominationUnitAsync(int id, string denominationUnit, int currencyId, int userId, CancellationToken ct = default);
Task<Result> DeleteDenominationUnitAsync(int id, CancellationToken ct = default);

public sealed record DenominationUnitEdit(string? DenominationUnit, int CurrencyId);
```

**The `using` list is the contract.** `TflCbs.Entities` + `TflOmniDb.Repository` + two `using static`
helpers — **no ASP.NET**, enforced by the project graph and an arch test. That is why `userId` is a parameter:
the service cannot ask who is logged in. Same for the clock and the branch.

Never re-declare `Has`/`Eq`/`Val`/`Paged`/`IsDuplicate`/`IsForeignKey` privately — `SharedServiceHelperTests`
fails the build on a copy (§0).

```csharp
private Repository<G_DENOMINATIONUNIT> Units => data.Repository<G_DENOMINATIONUNIT>();
private Repository<G_CURRENCY> Currencies => data.Repository<G_CURRENCY>();
private Repository<G_DENOMINATION> Denominations => data.Repository<G_DENOMINATION>();
```

Properties, not fields — the service stays stateless and holds nothing connection-shaped across an `await`.
Three tables for a two-field screen: its own, the currency it validates against, the child it must not orphan.

Generated entities are **UPPERCASE and all-nullable**, which is why `?? 0` / `?? string.Empty` appear
throughout. Not defensive coding — the type system telling the truth about the schema.

#### Search: two `GetAllAsync` calls and a join in C#

No SQL is assembled anywhere in this file. The same code runs on SQL Server, Oracle and PostgreSQL, so hand-
written SQL would mean three dialects and three bugs. Bounded tradeoff: 8 units and a handful of currencies,
one dictionary build per search. **Reconsider the moment this pattern points at a table that grows.**

```csharp
IEnumerable<G_DENOMINATIONUNIT> source = currencyId is > 0
    ? units.Where(u => u.CURRENCYID == currencyId)   // server half of the §2.2 cascade
    : units;

IEnumerable<(int Id, string Unit, string Currency)> q = source.Select(u => (
    Id: u.DENOMINATIONUNITID ?? 0, Unit: u.DENOMINATIONUNIT ?? string.Empty,
    Currency: u.CURRENCYID is int cid && currencyById.TryGetValue(cid, out var code) ? code : string.Empty));
```

The optional last parameter is the whole cascade: screen 1 never passes it, screen 2 always does, one method.
The nullable entity is projected into a **non-nullable tuple immediately**, so nulls are handled once rather
than in every filter and comparer.

```csharp
q = sort?.Trim().ToLowerInvariant() switch
{
    "currencycode" => …,
    _ => … OrderBy(r => r.Unit) …,      // allowlist: an unknown or hostile sort falls here
};
```

Two more controls in the same method: filters apply **only when non-blank** (absent ≠ match-empty), and
`Paged` clamps page size ≤ 0 or > 100 to 15 — `?pageSize=999999` returns a normal page, not the table.
`Total` is the count **before** paging, free because the list is already in memory.

Rows are returned as **dictionaries**, keyed exactly as the view's `SearchColumn` list names them, so
`SearchEndpoint` can swap `Id` for a token without knowing anything about this screen.

#### Load, and the boundary type

```csharp
return Result<DenominationUnitEdit?>.Ok(unit is null ? null : new DenominationUnitEdit(...));
```

`Ok(null)` — **missing is a successful answer** (§1.5 B). Returning `Fail` would show a system error for an
ordinary event. `Update` treats the same null as a *failure*, because "change this" does not tolerate a
missing row while "show me this" does.

`DenominationUnitEdit` is the boundary: the controller never sees a `G_DENOMINATIONUNIT`, so it cannot read
`PASSEDBY` or write `CREATEDON`. The service decides what leaves the module.

#### Writes

```csharp
var name = denominationUnit.Trim();   // stored as entered — legacy parity, casing is a display decision
if (!await CurrencyExistsAsync(currencyId, ct)) return Result.Fail(errorString: SelectCurrency);
```

**That currency check is what makes §1.5 D safe** — the untokenized id came straight from the browser; the
picker is convenience, this is the control.

Save sets four columns only; `PASSEDBY`/`PASSEDON` stay NULL by decision, not omission (§1.8). Update loads
first and mutates (§1.7). Delete constructs an entity carrying **only the key** — the DAL convention.

The four user-facing messages are `const`s **in the service**, because the rule and its wording are the same
thing and the check-and-catch pair must produce identical text from two code paths.

### 1.7 Rules

Three layers, and only the last two are controls:

1. **Form** — `[Required]`, `[StringLength(50)]`, `[Range]` on `DenominationUnitForm`, carrying legacy's own
   message wording. Shape only.
2. **Service** — the table below. This is where the rules live.
3. **Database** — `IsDuplicate` / `IsForeignKey` catch the race a pre-check cannot lock against, and map it to
   the *same message*.

| Rule | Implementation | Message |
|---|---|---|
| Currency must exist | `CurrencyExistsAsync` (`currencyId > 0` + `CountAsync`) | `Select a valid Currency.` |
| No duplicate | `NameExistsAsync(name, currencyId, excludeId)` **and** `catch when (IsDuplicate(ex))` | `Duplicate record already exists.` |
| Not deletable while used | `Denominations.CountAsync(d => d.DENOMINATIONUNITID == id)` **and** `catch when (IsForeignKey(ex))` | `This denomination unit is used by one or more denominations and cannot be deleted.` |
| Update preserves audit | load → mutate → `UpdateAsync` | — |

Why load-then-mutate: `Repository.Update` rewrites **every** column, so building a fresh entity would blank
`CreatedBy`/`CreatedOn` and `PassedBy`/`PassedOn`.

Why check *and* catch: the up-front check gives a readable message; the catch is there because the check is
not a lock — two users saving the same name in the same second both pass it. `IsDuplicate`/`IsForeignKey`
match on message text plus the SQL Server numbers, because three engines throw three exception types with no
common code; the matching is deliberately broad, and a false positive downgrades a raw error to a friendlier
one — the safe direction. §1.9 gotcha 1 is this catch earning its keep on live data.

### 1.8 Divergences from legacy (all deliberate)

| | Legacy | Now |
|---|---|---|
| Record id | `Request("id")` in the query string | encrypted `RowToken`, screen+session bound, single-use on write |
| Search | proc `pr_tr_SB_GetDenominationUnit`, 1 filter | `Repository<T>` in memory, 2 filters |
| Duplicate | no app check, DB exception only | checked first, still caught |
| Update | rewrote `CreatedBy`/`CreatedOn` every time | preserved |
| Pass | button under `?Source=pass` | **not built** — menu 2981 is `IsActive = 0`, so nothing can pass a unit; `PassedBy`/`PassedOn` stay NULL and are preserved on update |

### 1.9 Gotchas — verified against the live DB (7 Sep 2026)

1. **The unique index is on the name alone.** `IX_g_DenominationUnit` is UNIQUE on `DenominationUnit`, not
   `(DenominationUnit, CurrencyId)`. The service checks the pair, so a cross-currency duplicate passes the
   check and is refused by the database instead; `IsDuplicate(ex)` maps it to the same message, so the user
   sees the right thing. **The XML comment claims a looser rule than the DB enforces** — don't extend the
   class from the comment.
2. **There is no FK from `g_Denomination` to `g_DenominationUnit`** on this database. The
   `IsForeignKey(ex)` catch is unreachable here — the up-front `CountAsync` is the only thing preventing 41
   orphaned denominations.
3. **Audit stamp uses `DateTime.Now`**, legacy used the banking **working date** (all 8 live rows read
   `00:00:00`). Sibling Reference masters use `DateTime.Now.Date`; the two denomination masters are the only
   ones stamping a time. `WorkingDate` is already available on `CbsScreenController` if this gets aligned.
4. **Legacy locked a passed record** (`LoadDenomination` disabled Update/Delete when `PassedBy` had a
   value); the port has no such check. Not a live gap — all 8 rows are NULL and menu 2981 is inactive.

### 1.10 Live data

8 units / 41 denominations, `Trustbank_XNETT_ORCL`:

| Id | Unit | Currency | Denominations |
|---|---|---|---|
| 11 | LRD | LRD | 8 |
| 18 | LCENTS | LRD | 5 |
| 25 | LMUTES | LRD | 7 |
| 28 | SLDDOLLAR | LRD | 1 |
| 20 | USDOLLAR | USD | 8 |
| 24 | USCENTS | USD | 5 |
| 26 | USDMUTES | USD | 6 |
| 27 | SUSDOLLAR | USD | 1 |

Menu path in the app: **Central Administration → General Settings → Denomination Unit**.

Clicked through 2026-09-05 as `ratnesh` (Central Administration): menu opens · modal lists all 8 · picker Go
resolves USD → id 2 · save → duplicate refused → update → delete round-trip, DB left as found · deleting a
referenced unit gives the message, not a 500.

#### Verify a change

```
dotnet build TflCbs.Host.Main                                          # must be clean
dotnet test TflCbs.Tests --filter FullyQualifiedName~DenominationUnit  # service
dotnet test TflCbs.ArchTests                                           # boundaries, namespaces
dotnet run --project TflCbs.Host.Main                                  # https://localhost:7225
```

Stop the app before the next build (DLL locks). **After changing the service's public surface, run the
`cbs-sync-test-demo` agent** — `TflCbs.Tests` and `TflCbs.Demo` mirror every service method and the sync is
not optional.

---

## 2. Denominations

`/Bank/Denomination` · menu **890** (module 1, parent 885) · table `g_Denomination` · shipped 2026-09-06 ·
legacy `HO/MultiCurrency/g_Denomination.aspx` (45 KB code-behind) · migration `0014`.

Face values inside a currency + unit: `Denomination`, `SequenceNo`, `Factor`, `DenominationValue`. **Read
§1 first** — this is the same screen with one more dimension. What is new is worth the read: **two pickers,
the second scoped by the first**, plus a read-only grid driven by JavaScript.

### 2.1 Files

| Path | Role |
|---|---|
| [TflCbs.Modules.Reference/DenominationService.cs](../TflCbs.Modules.Reference/DenominationService.cs) | Service, 285 lines |
| [TflCbs.Modules.Bank.Web/Areas/Bank/Controllers/DenominationController.cs](../TflCbs.Modules.Bank.Web/Areas/Bank/Controllers/DenominationController.cs) | 8 actions, 211 lines |
| [TflCbs.Modules.Bank.Web/Areas/Bank/Views/Denomination/Index.cshtml](../TflCbs.Modules.Bank.Web/Areas/Bank/Views/Denomination/Index.cshtml) | Two pickers + read-only per-currency grid, 173 lines |
| [TflCbs.Modules.Bank.Web/wwwroot/js/bank-denomination.js](../TflCbs.Modules.Bank.Web/wwwroot/js/bank-denomination.js) | The per-currency grid, 61 lines |
| `Models/Bank/BankModels.cs` → `DenominationForm` | Same file as `DenominationUnitForm` |

### 2.2 Why the code sits where it does

Same reasoning as §1.2, one step further. The service is in **`TflCbs.Modules.Reference`** for the two
reasons `DenominationUnitService` is: pure CRUD with no domain behaviour, and ≥2 domains consume it — Bank
owns the maintenance screen, RetailBanking's Dormant Re Activation reads the rows to build its cash grid.
That second consumer is not hypothetical here; it is why `TflCbs.Modules.RetailBanking.Web` carries a
reference to `Reference` (§5).

The controller is in **`Bank.Web`** because menu 890 sits under module 1 — the legacy placement axis, not
the code axis. The two travel separately and that is deliberate.

The interesting part is the **constructor**, which injects three services:

```csharp
public sealed class DenominationController(
    CbsSessionStore store,
    DenominationService svc,        // this screen's own master
    DenominationUnitService units,  // the dependent picker's rows  (§1's service, reused whole)
    CurrencyService currencies,     // the parent picker's rows
    SearchEndpoint searchEndpoint,
    RowToken tokens)
    : CbsScreenController(store, tokens, searchEndpoint)
```

Three services, no new method in any of them. `SearchDenominationUnitsAsync` already took an optional
`currencyId` (§1.6) — the cascade's server half was built into §1's service before this screen existed, so
this controller only had to pass the filter through. **A picker's rows come from the service that owns that
master**, never from a bespoke lookup bolted onto the screen's own service. Copy that.

### 2.3 The controller

Eight actions in 211 lines, in §1's order: `Index`, three searches, `Save`, `Update`, `Delete`, plus one
private helper.

```csharp
[Area("Bank")]
[Route("Bank/Denomination")]
[CbsAccessScreen(ScreenKey)]
public sealed class DenominationController(...) : CbsScreenController(store, tokens, searchEndpoint)
{
    private const string HostUrl = "/Bank/Denomination";
    private const string ScreenKey = "Bank/Denomination";
    private const string Noun = "Denomination";
    private const string AlreadyPassed = "Record already passed."; // legacy's own message

    protected override string Screen => ScreenKey;
```

Identical to §1.3 but for one extra constant. `AlreadyPassed` is the first sign of something §1 does not
have: **a state in which this record cannot be edited at all.**

#### `Index` — the same load, plus a freeze

```csharp
vm.IsEditMode = true;
vm.Form.CurrencyId = loaded.CurrencyId;
vm.Form.DenominationUnitId = loaded.DenominationUnitId;
vm.Form.Denomination = loaded.Denomination;
vm.Form.SequenceNo = loaded.SequenceNo;
vm.Form.Row = ProtectId(denominationId.ToString());
await FillDisplayTextAsync(vm.Form, ct);

// Legacy disables every control and every button on a passed record and says so.
if (loaded.IsPassed)
{
    this.NotifyError(AlreadyPassed);
    vm.IsEditMode = false;      // ← Update and Delete disappear from the action bar
}
```

Read the last three lines carefully, because the trick is easy to misread. `IsEditMode = false` does **not**
mean "new record" here — the fields are still populated. It means *render the action bar's non-edit half*,
which on this screen is Save alone. The user sees the data and cannot act on it.

That is the display. **The guard is in the service** — `UpdateDenominationAsync` and
`DeleteDenominationAsync` each re-read `PASSEDBY` and refuse. Do only the view half and a hand-crafted POST
still writes. Do only the service half and the user sees enabled buttons that always fail. Both halves,
always: the view for the user, the service for the attacker.

#### Three search endpoints, three different shapes

| Action | Route | Feeds | `tokenizeId` |
|---|---|---|---|
| `SearchData` | `search` | the screen's own search modal **and** the per-currency grid | default (**true**) |
| `SearchCurrencies` | `search-currencies` | the Currency picker | `false` |
| `SearchUnits` | `search-units` | the Denomination Unit picker | `false` |

The §1.5 C/D rule holds: **tokenize a row you can open; do not tokenize reference data you can only pick.**
A currency id in a picker is re-validated on save (`ValidateAsync` check 3), so hiding it buys nothing and
costs a decrypt per keystroke.

`SearchData` earns its keep twice. Note the fourth filter it reads:

```csharp
r.Filters.TryGetValue("CurrencyCode", out var currencyCode);
r.Filters.TryGetValue("Denomination", out var denominationRaw);
r.Filters.TryGetValue("DenominationUnit", out var unit);
r.Filters.TryGetValue("CurrencyId", out var currencyIdRaw);   // ← not in the descriptor's Filters list
```

`CurrencyId` is not one of the three filters the search modal renders. It is the JavaScript grid's filter
(§2.4), sent by hand. One endpoint serves the modal *and* the grid, because a filter the UI never draws
costs nothing to accept. **Skipped:** a second endpoint for the grid.

#### `Save` / `Update` / `Delete` — §1's shapes, unchanged

`Update` keeps the **resolve → validate → consume** ordering, for the reason in §1.3 and
[`know-your-code.md`](know-your-code.md) §1.3:

```csharp
if (!TryBeginWrite(form.Row, out var idStr) || !int.TryParse(idStr, out var denominationId))
    return Redirect(HostUrl);
await FillDisplayTextAsync(form, ct);
if (!ModelState.IsValid) return EditFailed(idStr, form, FirstError());
if (!TryConsume(form.Row, out _, MsgAlreadyDone)) return Redirect(HostUrl);
```

`Delete` consumes immediately — nothing to validate.

Note what `Update` does **not** do: it never checks `IsPassed`. Deliberate, not an oversight — the service
checks it inside the same load it is about to mutate, so no window exists between check and write. A
controller-side check would be a second, racier copy of the same rule.

#### `FillDisplayTextAsync` — now two pickers

```csharp
private async Task FillDisplayTextAsync(DenominationForm form, CancellationToken ct)
{
    if (form.CurrencyId > 0 && string.IsNullOrWhiteSpace(form.CurrencyCode))             { …look up code… }
    if (form.DenominationUnitId > 0 && string.IsNullOrWhiteSpace(form.DenominationUnit)) { …look up name… }
}
```

Same problem as §1, twice over. A picker posts **two** values — hidden id and visible text — and a server
re-render holding only the id paints an empty box next to a populated hidden field. The user sees a blank
Currency and reasonably re-picks; the id was there all along.

The `string.IsNullOrWhiteSpace` guard is what makes this cheap: when the browser posted the text (the normal
case) there is no database call at all. It fires only where the text is genuinely absent — an edit load, or
a form rebuilt server-side.

### 2.4 The view

173 lines, same two halves as §1.4 — config block (1–105), then markup (108–173). Three things differ from
§1, all worth copying.

#### Two `RecordPickerModel`s, and how they know about each other

The Currency picker is §1's picker verbatim, plus two lines:

```csharp
ClearTargets = ["#Form_DenominationUnitId", "#Form_DenominationUnit"],
OnClearJs    = "cbsDenomCurrencyCleared",
```

`ClearTargets` says: *when the currency is cleared or changed, blank these elements.* Both halves of the
child picker — hidden id and visible text — because a stale unit name next to a cleared id is precisely the
bug this prevents. Same problem `FillDisplayTextAsync` solves on the server, approached from the other side.

`OnClearJs` names a global function to call as well. That is the escape hatch for behaviour the descriptor
cannot express — here, emptying the per-currency grid.

The unit picker carries the other half of the dependency:

```csharp
DependsOn       = new Dictionary<string, string> { ["CurrencyId"] = "#Form_CurrencyId" },
DependsRequired = true,
DependsMessage  = "Select Currency first.",
```

Read `DependsOn` as: *when you fetch my rows, read `#Form_CurrencyId` from the page and send it as a filter
named `CurrencyId`*. That is why `SearchUnits` finds `CurrencyId` in `r.Filters` — the client put it there,
from the DOM, on every request.

`DependsRequired` refuses to open the dialog while the source element is empty, showing `DependsMessage`.
**This is UX, not a control** — see §2.5.

#### The read-only grid, and why it is a separate card

```html
<div id="cbs-denom-existing" class="card" data-search-url="@searchUrl" hidden>
    <div class="card-title">Denominations of this currency</div>
    <table class="table compact">…<tbody id="cbs-denom-existing-rows"></tbody></table>
</div>
```

Three details in one small block:

- **`hidden`** — the grid starts invisible and reveals itself only when rows arrive. An empty table with
  headers reads like a bug; nothing at all reads like "you have not chosen a currency yet".
- **`data-search-url`** — the URL is written by `Url.Action` at render time and handed to JavaScript through
  a data attribute. The script never hardcodes a route, so a route change cannot silently break it.
- **Its own card, outside the `<form>`** — the file says why: `.card-title` uses negative margins that only
  work as a card's first child, and the form card's action bar is sticky. Cosmetic, but the kind of thing
  you would otherwise rediscover by trial and error.

#### The script tag, and the CSP

```razor
@section Scripts {
    <script src="~/_content/TflCbs.Modules.Bank.Web/js/bank-denomination.js" asp-append-version="true"></script>
}
```

**The CBS Content-Security-Policy is `script-src 'self'` with no nonce, so an inline `<script>` is blocked
and fails silently.** Any behaviour beyond what the descriptor expresses goes into a file under
`wwwroot/js/`. The `~/_content/<assembly>/` prefix is how a Razor Class Library's static assets are served;
`asp-append-version` appends a content hash so a deploy busts the browser cache.

#### The JavaScript — 61 lines, and the shape to copy

```javascript
var currency = document.getElementById("Form_CurrencyId");
if (!box || !body || !currency) return;              // 1. not this screen → do nothing

window.cbsDenomCurrencyCleared = clear;              // 2. the OnClearJs hook
currency.addEventListener("change", load);           // 3. react to picks
load();                                              // 4. and run once now
```

Four lines carrying the whole design:

1. **Guard first.** Site-wide scripts run on pages they were not written for. Missing elements → return, no
   console error.
2. **The hook is a global function**, because `OnClearJs` is a string in JSON — it can only name something.
3. **The event is `change` on the hidden input.** `cbs-search.js` fires it after a pick, so this script never
   needs to know the picker exists. Loose coupling for free.
4. **`load()` at the end matters more than it looks.** On an edit load or a validation bounce the currency is
   *already* set and no `change` will ever fire. Without that call the grid is permanently empty on exactly
   the screens where it is most useful.

And the fetch itself:

```javascript
q.set("search.Filters[CurrencyId]", id);
q.set("search.Page", "1");
q.set("search.PageSize", "100");   // a currency has a handful of denominations; one page is all of them
```

`search.Filters[CurrencyId]` is the wire format `SearchRequest` model-binds from — the `search.` prefix is
the action parameter's name. Rows are built with `document.createElement` + `textContent`, never `innerHTML`
with data in it: `textContent` cannot execute markup, so a denomination unit named `<img onerror=…>` renders
as text.

### 2.5 The cascading picker — the thing to copy

The most reusable idea on this screen, so it gets its own section. It exists in **two halves that must both
be present**:

| Half | Where | What it does | Without it |
|---|---|---|---|
| Client | `DependsOn` / `DependsRequired` / `ClearTargets` in the descriptor | won't open without a currency; sends it as a filter; clears the child on change | the user browses every unit of every currency and picks a wrong-currency one |
| **Server** | the first four lines of `SearchUnits` | no currency filter → **empty result**, whatever the client did | a crafted request lists every unit in the bank |

```csharp
r.Filters.TryGetValue("CurrencyId", out var currencyRaw);
if (!int.TryParse(currencyRaw, out var currencyId) || currencyId <= 0)
    return ([], 0);                       // ← the control
```

**`DependsRequired` is UX; the empty result is the control.** And there is a *third* layer, in the service:
`ValidateAsync` check 4 refuses a unit that does not belong to the chosen currency (§2.7). Client
convenience, server scoping, save-time invariant — three layers, because the first two only shape what the
user is *offered*.

Legacy needed none of this: its dropdown did an AutoPostBack and reloaded `g_DenominationUnit WHERE
CurrencyId = …` from the server, so a wrong-currency unit was unreachable by construction. Client-side
pickers buy responsiveness and cost you that guarantee — you have to re-state it explicitly.

### 2.6 Flows

Five of the seven are §1.5's, unchanged: **A** open blank, **C** search, **E** save, **F** update, **G**
delete. Two behave differently.

#### B. Open a record — `GET /Bank/Denomination?row={token}`

§1's flow plus the freeze:

```
token → TryOpenRecord → LoadDenominationAsync(id) → DenominationEdit{…, IsPassed}
                                                          │
                            IsPassed ── true ──→ NotifyError("Record already passed.") + IsEditMode = false
                                     └─ false ─→ normal edit form
```

`ProtectId` still mints a token even for a frozen record. Harmless — the service refuses regardless — and it
keeps the load path single.

#### D. Two pickers, one cascade

```
Currency picker  → search-currencies  → CurrencyService          (no dependency)
      │
      │ pick → cbs-search.js sets #Form_CurrencyId + #Form_CurrencyCode
      │      → fires "change"  ────────────────┬──→ bank-denomination.js reloads the grid
      │      → applies ClearTargets            │       (search?Filters[CurrencyId]=…)
      ↓                                        │
Unit picker      → search-units ──────────────┘
                    reads Filters[CurrencyId] → DenominationUnitService(…, currencyId)
```

One pick drives three things: two form fields, the child picker's future scope, and a grid refresh. None of
them know about each other — all three are downstream of one `change` event on a hidden input.

### 2.7 The service

285 lines, structurally **§1's service with one more join**. Same `using static` header, same repository
properties, same in-memory search, same load-then-mutate update. Read §1.6 for the shared reasoning; what
follows is what is genuinely different.

#### A constant instead of a parameter

```csharp
/// <summary>Legacy's hidden Factor field, seeded "1" and never shown. See the class remarks.</summary>
private const decimal Factor = 1m;
```

`Factor` is a real column and legacy has a real input for it — inside a `style="display:none"` row, seeded
`"1"`, re-seeded to `"1"` after every action. All 41 live rows hold `1.000`. So it is a constant here, and
`DenominationValue` is legacy's own line, `Denomination * Factor`.

That is a judgement call, and it is marked as one:

```
ponytail: hardcoded Factor — take it as a parameter if that field is ever unhidden.
```

The marker's value is that the next person need not re-derive whether the omission was deliberate. **Write
the ceiling down when you cut a corner on purpose.**

#### Two dictionaries, then the join

```csharp
var currencyById = (await Currencies.GetAllAsync(ct)).Where(…).ToDictionary(…);
var unitById     = (await Units.GetAllAsync(ct)).Where(…).ToDictionary(…);
var all          = await Denominations.GetAllAsync(ct);
```

Three whole-table reads, joined in C#. Same tradeoff as §1.6, one table wider: 41 denominations, ~15
currencies, ~10 units — a few kilobytes. Portable across all three engines, no provider-specific join
syntax, readable. **The same warning applies:** reconsider the moment this pattern points at a table that
grows. `g_Denomination` does not; it is a list of banknote values.

The projection is a **six-field tuple** with non-nullable members, built from all-nullable entity columns:

```csharp
IEnumerable<(int Id, string Currency, int Seq, int Denom, string Unit, decimal Value)> q = source
    .Select(d => (
        Id: d.DENOMINATIONID ?? 0,
        Currency: d.CURRENCYID is int cid && currencyById.TryGetValue(cid, out var cc) ? cc : string.Empty,
        …));
```

Every `?? 0`, `?? string.Empty` and failed `TryGetValue` is a decision to **show the row with a blank cell**
rather than drop it or throw. A denomination pointing at a deleted currency still appears in the grid —
which is what you want when you are trying to find and fix it.

#### The sort default is legacy's grid order

```csharp
_ => desc ? q.OrderByDescending(r => r.Seq).ThenBy(r => r.Denom)
          : q.OrderBy(r => r.Seq).ThenByDescending(r => r.Denom),
```

Not alphabetical — `SequenceNo` ascending, then `Denomination` **descending**. That is legacy's own order for
the per-currency grid, and the cash screens read denominations that way. The `switch` is still an
**allowlist**: an unknown `sort` string falls to `_` rather than reaching a property by name.

#### `ValidateAsync` — one method, legacy's order, legacy's messages

Every rule in one place, called by both `Save` and `Update` with `excludeId`:

```csharp
if (await ValidateAsync(currencyId, denominationUnitId, denomination, sequenceNo, excludeId: null, ct) is { } error)
    return Result.Fail(errorString: error);
```

`is { } error` is C#'s "not null, and bind it". The method returns `null` for valid and a message otherwise —
fewer states than a bool plus an out parameter, and it reads as a sentence.

`excludeId` is the entire reason both duplicate checks are written twice:

```csharp
var seqTaken = excludeId is null
    ? await Denominations.CountAsync(d => d.SEQUENCENO == sequenceNo && d.CURRENCYID == currencyId, ct)
    : await Denominations.CountAsync(d => d.SEQUENCENO == sequenceNo && d.CURRENCYID == currencyId
                                          && d.DENOMINATIONID != excludeId, ct);
```

Without it, **opening a record and pressing Update without changing anything reports "Sequence Number
already exists"** — the row colliding with itself. That bug ships constantly. The two expressions are
separate because the repository predicate is a real expression tree, not a string you can append to.

#### Writes

`Save` inserts. `Update` **loads then mutates** — repository UPDATE rewrites every column, so a freshly
constructed entity would blank `CREATEDBY` *and* `PASSEDBY`. `Delete` also loads first, so it can refuse a
passed row before deleting. All three carry the `IsPassed` refusal, and `Save`/`Update` pair `ValidateAsync`
with `catch (…) when (IsDuplicate(ex))` — check for the message, catch for the race (§1.7).

### 2.8 Rules

| # | Check | Message |
|---|---|---|
| 1 | unit chosen | `Select denomination unit.` |
| 2 | denomination > 0 | `Enter valid denomination` |
| 3 | currency exists | `Select a valid Currency.` |
| 4 | **the unit belongs to that currency** | `Select denomination unit.` |
| 5 | sequence number free within the currency | `Sequence Number already exists.` |
| 6 | (denomination, currency, factor, unit) free | `Denomination already exists.` |

Plus, outside `ValidateAsync`: **a passed row cannot be updated or deleted** (`Record already passed.`), and
`Denomination already deleted.` when the row vanished between load and write.

Two notes. Check 4 is the cascade's third layer (§2.5) — legacy got it free from its server-rendered
dropdown. And the messages are legacy's, missing full stop on #2 included: a teller who has read "Enter
valid denomination" for ten years should read it here too.

### 2.9 Gotchas

- **`Factor` is hardcoded to `1m`.** See §2.7. Every live row holds 1.000 and the field is invisible in
  legacy.
- **No in-use check on delete.** Legacy has none and the DB carries no FK to `g_Denomination`. The
  `IsForeignKey` catch is kept for deployments that added one; a *passed* row is still refused.
- **No Authorize screen.** Menu 2982 is `IsActive = 0`, same story as 2981 in §1. But unlike §1, passed rows
  **do** exist in the wild here — so the freeze is live code, not dead code, and it is why `IsPassed` is on
  `DenominationEdit` at all.
- **The grid's `PageSize = 100` is an assumption, not a limit.** A currency with more than 100 denominations
  would silently show the first 100. True of banknotes; false the day someone stores something else here.
- **`ClearTargets` must list both halves of the child picker.** Id and text. Clearing one leaves a display
  that lies.

---

## 3. Holding Amount (4 screens)

One legacy page (`RetailBanking/b_AccHoldingAmount.aspx`, 44 KB) that multiplexed four modes on `?Source=`.
Here: **four routes, four menu rights, one controller, three views.**

| Menu | Mode | Route | Screen key | View |
|---|---|---|---|---|
| 2784 | 1 entry | `/RetailBanking/AccHoldingAmount` | `RetailBanking/AccHoldingAmount` | `Index.cshtml` |
| 2785 | 2 entry authorization | `…/Authorize` | `…/Authorize` | `Authorize.cshtml` |
| 2786 | 3 release | `…/Release` | `…/Release` | `Release.cshtml` |
| 2787 | 4 release authorization | `…/ReleaseAuthorize` | `…/ReleaseAuthorize` | `Authorize.cshtml` **again** |

Table `b_AccHoldingAmount` · scroll source **1145** · migrations `0004` (entry pair) + `0012` (release pair).

**This is the first screen in this guide with maker-checker.** Everything above was one person editing a
master; from here on a second person has to agree. Read §3.3 before the flows.

**Why four routes and not one with a mode parameter:** `AllowedUrls` is derived from `NavigateURL`, so one
route would mean one right — and a user allowed to enter a hold would be allowed to authorize it. Splitting
the routes **is** the maker-checker separation. There is no `if (mode == …)` anywhere in the guard.

### 3.1 Files

| Path | Role |
|---|---|
| [TflCbs.Modules.RetailBanking/HoldingAmountService.cs](../TflCbs.Modules.RetailBanking/HoldingAmountService.cs) | 715 lines — both maker-checker cycles |
| [TflCbs.Modules.RetailBanking/AccountService.cs](../TflCbs.Modules.RetailBanking/AccountService.cs) | Account / COA pickers, account-number format, withdrawable |
| [.../Controllers/AccHoldingAmountController.cs](../TflCbs.Modules.RetailBanking.Web/Areas/RetailBanking/Controllers/AccHoldingAmountController.cs) | 508 lines, 17 actions, four screen keys |
| [.../Views/AccHoldingAmount/Index.cshtml](../TflCbs.Modules.RetailBanking.Web/Areas/RetailBanking/Views/AccHoldingAmount/Index.cshtml) | Entry, 177 lines |
| [.../Views/AccHoldingAmount/Authorize.cshtml](../TflCbs.Modules.RetailBanking.Web/Areas/RetailBanking/Views/AccHoldingAmount/Authorize.cshtml) | **Both** checker screens, 110 lines |
| [.../Views/AccHoldingAmount/Release.cshtml](../TflCbs.Modules.RetailBanking.Web/Areas/RetailBanking/Views/AccHoldingAmount/Release.cshtml) | Release, 103 lines |
| [.../Models/RetailBanking/AccHoldingAmountForm.cs](../TflCbs.Modules.RetailBanking.Web/Models/RetailBanking/AccHoldingAmountForm.cs) | 48 lines — one form for all four screens |
| [.../wwwroot/js/acc-holding-amount.js](../TflCbs.Modules.RetailBanking.Web/wwwroot/js/acc-holding-amount.js) | Account-info refresh, 43 lines |
| [TflCbs.Modules.General.Contracts/IScrollService.cs](../TflCbs.Modules.General.Contracts/IScrollService.cs) | `ScrollSources.HoldingAmount = 1145` |

### 3.2 Why the code sits where it does

`HoldingAmountService` is in **`TflCbs.Modules.RetailBanking`**, a leaf domain module — not in `Reference`,
because it fails the admission rule on both counts: it has real domain behaviour (maker-checker, branch
scope, withheld-amount arithmetic) and only one domain consumes it.

The one edge that leaves the domain is `IScrollService`, taken from **`TflCbs.Modules.General.Contracts`**:

```csharp
public sealed class HoldingAmountService(DataAccess data, IScrollService scrolls)
```

RetailBanking references General's **contracts** assembly, never General's implementation. That is the whole
point of a separate contracts project: the approval mechanism is shared by many domains, so the *interface*
is published and the implementation stays private. `ScrollSources.HoldingAmount = 1145` lives beside the
interface, so a screen cannot invent its own source number.

The controller takes **two** services:

```csharp
public sealed class AccHoldingAmountController(
    CbsSessionStore store, AccountService svc, HoldingAmountService holds,
    SearchEndpoint searchEndpoint, RowToken tokens,
    IWebHostEnvironment env, ILogger<AccHoldingAmountController> logger)
```

`AccountService` owns accounts and charts of account; `HoldingAmountService` owns holds. Same rule as §2.2 —
**a picker's rows come from the service that owns that master.** `env` and `logger` are new, and §3.4
explains what they are for.

### 3.3 The scroll — how maker-checker actually works

`x_Scroll` is the bank's shared approval record. A row in it means "someone did something that needs
approval"; passing it means "someone else agreed".

```csharp
Task<int>  CreateAsync(IUnitOfWork uow, int source, int userId, int orgElementId, DateTime workingDate, ct);
Task       PassAsync  (IUnitOfWork uow, int scrollId, int userId, DateTime workingDate, ct);
Task<bool> IsPassedAsync(int scrollId, ct);
```

Three facts carry every screen from here on:

1. **Unpassed scroll = draft.** `PassedBy1` null or 0 means nothing has been approved yet. The maker can
   still edit or delete it.
2. **`PassedBy1 > 0` = authorized.** From then on the entry is frozen to the maker.
3. **`CreateAsync` takes the `IUnitOfWork`, not the `DataAccess`.** The scroll and the business row are
   written in **one transaction** — a scroll with no entry, or an entry with no scroll, are both corruption.

A hold carries **two** scroll ids:

```
b_AccHoldingAmount
├── ScrollId          → cycle 1: the hold itself      (maker 2784, checker 2785)
└── ReleasedScrollId  → cycle 2: releasing the hold   (maker 2786, checker 2787)
```

**Release is a second maker-checker cycle on the same row, not a delete.** The hold's history stays intact:
you can see who placed it, who approved it, who lifted it and who approved that. Deleting the row would
throw all four away.

That gives four states, and every guard in the service is a question about which one you are in:

| Entry scroll | Release scroll | State | What is allowed |
|---|---|---|---|
| unpassed | — | draft hold | maker: update / delete |
| **passed** | — | hold in force | anyone in branch: release |
| passed | unpassed | release pending | update release / undo release / checker: authorize |
| passed | **passed** | released | nothing — terminal |

### 3.4 The controller

508 lines, 17 actions, four screen keys. The largest controller in this guide and the one worth reading in
full, because the pattern repeats on §4 and §5.

#### The multi-screen pattern — copy this

```csharp
[Route("RetailBanking/AccHoldingAmount")]
[CbsAccessScreen(EntryScreenKey)]        // class-level DEFAULT for every action
public sealed class AccHoldingAmountController(…) : CbsScreenController(store, tokens, searchEndpoint)
{
    private const string EntryScreenKey       = "RetailBanking/AccHoldingAmount";
    private const string AuthScreenKey        = "RetailBanking/AccHoldingAmount/Authorize";
    private const string ReleaseScreenKey     = "RetailBanking/AccHoldingAmount/Release";
    private const string ReleaseAuthScreenKey = "RetailBanking/AccHoldingAmount/ReleaseAuthorize";

    protected override string Screen => EntryScreenKey;   // the DEFAULT for token helpers
```

Two independent defaults, and they are **not** the same mechanism:

- **`[CbsAccessScreen]`** decides *which menu right this action needs*. Class-level sets the default;
  action-level overrides it (most specific metadata wins).
- **`protected override string Screen`** decides *which screen key row tokens are minted and checked under*.
  It has no override attribute — you pass `screen:` per call.

```csharp
[HttpGet("Authorize")]
[CbsAccessScreen(AuthScreenKey)]                                     // ← access
public async Task<IActionResult> Authorize(string? row, CancellationToken ct)
{
    if (!TryOpenRecord(row, out var idStr, screen: AuthScreenKey))    // ← tokens
        …
    form.Row = ProtectId(holdId.ToString(), screen: AuthScreenKey);   // ← tokens, both sides
```

**The rule: on a non-default screen, every token call takes `screen:`, on both sides.** Forget it when
minting and the token is stamped `…/AccHoldingAmount`; the authorize POST then checks against
`…/Authorize` and refuses every submission. Forget it on both sides and it "works" — while silently letting
an entry-screen token be spent on the authorize screen. That is why `know-your-code` §1.6 lists it as one of
the four ways to get tokens wrong.

#### The four checker guards, and why they are in the controller *and* the service

```csharp
// Authorize (2785)
if (edit.IsPassed)             { NotifyError("This hold is already authorized."); return View(form); }
if (edit.CreatedBy == UserId)  { NotifyError("Maker cannot authorize their own entry."); return View(form); }

// ReleaseAuthorize (2787)
if (!edit.IsReleased)          { NotifyError("This hold has not been released."); … }
if (edit.IsReleasePassed)      { NotifyError("This release is already authorized."); … }
if (edit.LastModifiedBy == UserId) { NotifyError("Maker cannot authorize their own release."); … }
```

**Note the maker column differs per cycle: entry checks `CreatedBy`, release checks `LastModifiedBy`.** The
person who released a hold is not necessarily the person who placed it, and the release cycle has to keep
its own maker. Get this wrong and one user can place, release and authorize their own release.

These checks are in the controller so the user gets a clear message on a `GET`, before being shown a form
they cannot submit. **They are repeated in the service** (§3.7 guards) because the controller version is
advisory — it runs on the GET, and nothing stops a POST that skipped it.

#### Search: four modes, one private handler

```csharp
[HttpGet("search-holds")]                          → SearchHoldsAsync(search, mode: 1, EntryScreenKey, ct)
[HttpGet("authorize/search-holds")]                → SearchHoldsAsync(search, mode: 2, AuthScreenKey, ct)
[HttpGet("release/search-holds")]                  → SearchHoldsAsync(search, mode: 3, ReleaseScreenKey, ct)
[HttpGet("release-authorize/search-holds")]        → SearchHoldsAsync(search, mode: 4, ReleaseAuthScreenKey, ct)
```

Four routes so each carries its own `[CbsAccessScreen]`, all four one line long, delegating to one private
method. The mode picks the candidate set; the screen key stamps the tokens the rows carry:

```csharp
var resp = await RunSearch((r, c) => Task.FromResult(res.Value), req, ct, tokenizeId: true, screen: screenKey);
```

`tokenizeId: true` here, unlike the pickers — these rows navigate to a record, so they *are* openable
handles (§1.5 C). And `screen: screenKey` means a token minted in the authorize list can only ever be opened
on the authorize screen.

#### `Fail(res)` — the JSON-endpoint error helper

```csharp
private IActionResult Fail(Result res)
{
    logger.LogError(res.Exception, "Holding amount request failed (ref {Reference}): {Error}", res.Reference, res.ErrorString);
    var msg = env.IsDevelopment() ? (res.Exception?.Message ?? res.ErrorString) : res.ErrorString;
    return StatusCode(500, new { error = msg, reference = res.Reference });
}
```

This is why `env` and `logger` are injected, and it is worth copying onto **any screen with JSON endpoints**.
Three things at once: the real exception reaches the log; the developer sees the real message; production
sees the generic one — and `reference` ties the dialog the user is looking at to the exact
`Logs/cbs-*.log` line. A user reading a reference code over the phone is worth more than a stack trace they
cannot send you.

#### Small helpers that carry real decisions

```csharp
private static string Money(decimal value) => value.ToString("N2", CultureInfo.InvariantCulture);
```

`InvariantCulture`, explicitly. The server's locale must not decide whether the teller sees `1,234.56` or
`1.234,56`.

```csharp
private async Task PrepareWidthsAsync(AccHoldingAmountForm form, CancellationToken ct)
{
    var fmt = await svc.GetAccountNumberFormatAsync(ct);
    if (fmt.IsSuccess) { form.BranchLen = fmt.Value.Branch; form.HeadLen = …; form.AccountLen = …; }
}
```

Account-number segment widths come from `b_AccountNumberFormat` — **bank configuration, not a constant.**
Called on every entry path including the POST re-renders, because a validation bounce that lost the widths
would redraw the picker with the wrong box sizes. The form carries `4 / 5 / 8` as defaults so a config read
failure degrades instead of exploding.

### 3.5 The views

Three views for four screens. The interesting part is which one is shared and why.

#### `Index.cshtml` — the account picker

The entry screen's only new component is `_AccountPicker`, and it is a bigger thing than `_RecordPicker`:

```csharp
var accountPicker = new AccountPickerModel
{
    Mode = AccountPickerModel.ModeCoaAccount,
    Disabled = isEdit,     // the account is fixed once a hold exists; edit changes amount/remarks only
    BranchLen = Model.BranchLen, HeadLen = Model.HeadLen, AccountLen = Model.AccountLen,
    …
    CustomerNameTarget   = "#acc-customer-name",
    BalanceTarget        = "#acc-balance",
    ChartOfAccountTarget = "#acc-coa",
    CoaDescriptor     = new SearchDescriptor { … },   // stage 1: chart of account
    AccountDescriptor = new SearchDescriptor { … },   // stage 2: accounts within it
};
```

Four ideas in one control:

- **Three typed segment boxes** (branch / head / account no) sized by the configured widths, so a teller can
  type a full account number the way it is printed.
- **Two-stage dialog** — pick a chart of account, then an account within it. Two descriptors, one control;
  the cascade is built into the component rather than declared like §2.5.
- **`…Target` selectors fill read-only boxes elsewhere on the page.** The picker writes customer name,
  balance and COA into three inputs it does not own. Declarative, no per-screen JavaScript.
- **`Disabled = isEdit`** — a hold belongs to one account for its whole life. Editing changes the amount and
  the remarks; it never re-points the hold. Enforced again in the service, which simply never reads an
  account id on update.

The action bar is §1.4's shape: `formaction` splits one form into Save / Update / Delete, plus
`data-cbs-confirm` on the destructive one.

#### `Authorize.cshtml` — one view, two screens

This is the reuse worth studying. The file opens by asking which cycle it is rendering:

```csharp
var isRelease = ViewData["IsReleaseCycle"] is true;
var title       = isRelease ? "Holding Amount Release Authorization" : "Holding Amount Authorization";
var hostUrl     = isRelease ? "…/ReleaseAuthorize" : "…/Authorize";
var postAction  = isRelease ? nameof(…DoAuthorizeRelease) : nameof(…DoAuthorize);
var searchAction= isRelease ? nameof(…SearchHoldsForReleaseAuth) : nameof(…SearchHoldsForAuth);
```

Five variables, then one body. The two checker screens differ only in labels, endpoints and one extra
read-only row (`Release Remarks`) — so they are one file, and the controller selects it explicitly:

```csharp
ViewData["IsReleaseCycle"] = true;
…
return View("Authorize", form);        // ReleaseAuthorize renders the Authorize view
```

**Every field is `readonly`.** A checker approves or does not; there is nothing to edit. That is what makes
one view viable for both cycles — a read-only screen has far less surface to diverge.

`hasRecord` gates the whole body:

```razor
@if (!hasRecord)
{
    <p class="muted">Use <strong>Search</strong> to pick a pending @(isRelease ? "release" : "hold") to authorize.</p>
}
```

A checker arrives at an empty screen and must search. There is no "most recent" default, and that is
deliberate: an authorize button next to a pre-loaded record invites approving whatever happens to be in
front of you.

#### `Release.cshtml` — three verbs on one form

The release screen is the only one whose action bar changes shape at runtime:

```razor
@if (hasRecord && !isPending)
{
    <button type="submit" class="btn btn-primary">Release</button>
}
else if (hasRecord)
{
    <button type="submit" formaction="@Url.Action(nameof(…UpdateRelease))">Update</button>
    <button type="submit" formaction="@Url.Action(nameof(…UndoRelease))"
            data-cbs-confirm="Cancel this pending release? The hold stays in force.">Undo Release</button>
}
```

`isPending` is `ViewData["IsReleasePending"]`, set from `edit.IsReleased` — i.e. *a release scroll already
exists but has not been passed*. First visit: **Release**. Second visit: **Update** / **Undo Release**. Same
route, same view, different verbs, driven by the row's state and not by a query parameter.

Note the confirm text on Undo: *"The hold stays in force."* Undoing a release is not undoing the hold, and a
teller pressing a button called "Undo" deserves to be told which thing is being undone.

One legacy quirk is preserved and commented in the file: the amount stays editable on this screen, but only
the **Update** path persists it — pressing Release ignores an edited amount. Legacy behaves that way; it is
kept rather than silently "fixed".

#### The JavaScript — 43 lines, and a different coupling style from §2

```javascript
document.addEventListener("cbs:account-picked", function (e) { fetchInfo(e.detail && e.detail.accountId); });
document.addEventListener("cbs:account-cleared", function () { blank(); });
```

§2's script listened for a DOM `change` event on a hidden input. This one listens for **custom events the
account picker publishes**, carrying a payload (`e.detail.accountId`). Same principle — the screen script
knows nothing about the picker's internals — but a richer contract, because the picker has more to say than
"something changed".

What it fetches is the part the picker cannot know: **Amount Withheld** and **Withdrawable**, which are this
screen's own arithmetic. Everything the picker *does* know (customer name, balance, COA) is filled
declaratively by `…Target` and needs no script at all.

### 3.6 Flows

#### Entry (2784)

```
GET  /                      → NewFormAsync (account-number widths from AccountService)
GET  /?row={token}          → TryOpenRecord → LoadHoldAsync(id, OrgElementId)
                              refuse if edit.IsPassed → PopulateForm + SplitAccountNumber + FillAccountInfo
GET  /search-account-heads  → COA picker, tokenizeId:false, types "78,79,82" (SB/CA/CC)
GET  /search-accounts       → account picker, scoped to OrgElementId, exact when IsGo
GET  /search-holds          → mode 1: the caller's own unpassed holds (tokenized)
GET  /account-info?accountId → { withheld, withdrawable, availableWithdrawal }
POST /save                  → ValidateEntry → SaveHoldAsync
POST /update                → TryBeginWrite → validate → TryConsume → UpdateHoldAsync
POST /delete                → TryConsume → DeleteHoldAsync (deletes the scroll too)
```

`SaveHoldAsync` runs the **unpassed-record guard** first — one in-flight hold per account:

```csharp
var existing = await data.Repository<B_ACCHOLDINGAMOUNT>().WhereAsync(
    h => h.ACCOUNTID == accountId && (h.RELEASEDSCROLLID == null || h.RELEASEDSCROLLID == 0),
    [h => h.SCROLLID!], cancellationToken: ct);
if (existing.Count > 0)
{
    var passed = await LoadScrollPassedAsync(existing.Select(h => h.SCROLLID).ToList(), ct);
    if (existing.Any(h => h.SCROLLID is int sid && passed.TryGetValue(sid, out var p) && p == 0))
        return Result.Fail(errorString: "Unpassed record exists for the selected account.");
}
```

Then the write, in one transaction:

```csharp
await data.ExecuteInTransactionAsync(async uow =>
{
    var scrollId = await scrolls.CreateAsync(uow, ScrollSources.HoldingAmount, userId, orgElementId, workingDate, ct);
    await uow.Repository<B_ACCHOLDINGAMOUNT>().InsertAsync(new B_ACCHOLDINGAMOUNT
    {
        ACCOUNTID = accountId, HOLDAMOUNT = holdAmount, REMARKS = remarks.Trim(),
        SCROLLID = scrollId, CREATEDBY = userId, CREATEDON = workingDate,
        HOLDTYPE = holdType, AVAILABLEBALANCE = availableBalance,
        SOURCEORGELEMENTID = orgElementId, // legacy proc writes it; the release search filters on it
    }, ct);
}, cancellationToken: ct);
```

`uow.Repository<T>()` inside the lambda, **never** `data.Repository<T>()` — the latter would enlist a
different connection and silently escape the transaction.

#### Entry authorization (2785)

```
GET  /Authorize?row={token}   → refuse IsPassed; refuse edit.CreatedBy == UserId
GET  /authorize/search-holds  → mode 2: OTHER users' unpassed holds
POST /authorize               → TryConsume(screen: AuthScreenKey) → AuthorizeHoldAsync
                                → scrolls.PassAsync + audit stamps
```

#### Release (2786) — a second cycle, three verbs

```
GET  /Release?row={token}   → require IsPassed (can't release an unauthorized hold)
                              refuse if IsReleasePassed
                              ViewData["IsReleasePending"] = edit.IsReleased → shows Update / Undo
GET  /release/search-holds  → mode 3: entry scroll passed AND release scroll absent-or-unpassed.
                              NO maker filter — legacy has that test commented out; anyone in branch releases
POST /release               → ReleaseHoldAsync   → creates the SECOND scroll (ReleasedScrollId)
POST /release/update        → UpdateReleaseAsync → amend a pending release (rewrites the amount too)
POST /release/undo          → UndoReleaseAsync   → drop the release scroll; the hold stands
```

#### Release authorization (2787)

```
GET  /ReleaseAuthorize?row={token} → require IsReleased; refuse IsReleasePassed
                                     refuse if edit.LastModifiedBy == UserId
                                     returns View("Authorize", form) + ViewData["IsReleaseCycle"] = true
GET  /release-authorize/search-holds → mode 4
POST /release-authorize             → AuthorizeReleaseAsync (passes the release scroll)
```

### 3.7 The service

715 lines. Same conventions as §1.6 and §2.7 — `Result`, `Repository<T>`, in-memory joins, `using static` —
with three things those screens did not need.

#### Guards that compose, returning `Result?`

```csharp
private async Task<Result?> GuardEditableAsync(B_ACCHOLDINGAMOUNT h, int userId, int orgElementId, CancellationToken ct)
{
    var scroll = …;
    if (scroll is null || scroll.ORGELEMENTID != orgElementId) return Result.Fail(errorString: "Record not found.");
    if ((scroll.PASSEDBY1 ?? 0) > 0)   return Result.Fail(errorString: "Authorized record cannot be modified.");
    if ((h.CREATEDBY ?? 0) != userId)  return Result.Fail(errorString: "Only the maker can modify this entry.");
    return null;                       // ← null means "no objection"
}
```

Used as:

```csharp
var guard = await GuardEditableAsync(h, userId, orgElementId, ct);
if (guard is not null) return guard;
```

Same `null == fine` convention as §2.7's `ValidateAsync`, applied to authorization rather than validation.
And they **stack** — `GuardPendingReleaseAsync` calls `GuardReleasableAsync` and adds two checks:

```
GuardEditableAsync        : branch + unpassed entry scroll + maker
GuardReleasableAsync      : branch + entry scroll PASSED
GuardPendingReleaseAsync  : GuardReleasableAsync + release exists + release scroll unpassed
```

Three guards for four states (§3.3). Writing them as composed methods rather than one `switch` is what keeps
ten write methods honest — each one names the state it requires and cannot forget a branch check, because
the branch check is inside the guard it had to call anyway.

Note the message on a branch mismatch: **`"Record not found."`**, not "wrong branch". A user in another
branch learns nothing about whether the record exists.

#### Explicit column lists

```csharp
private static readonly Expression<Func<B_ACCHOLDINGAMOUNT, object?>>[] SearchColumns =
[
    h => h.ACCHOLDINGAMOUNTID!, h => h.ACCOUNTID!, h => h.HOLDAMOUNT!, h => h.SCROLLID!,
    h => h.CREATEDBY!, h => h.RELEASEDSCROLLID!, h => h.LASTMODIFIEDBY!, h => h.SOURCEORGELEMENTID!,
];
```

Unlike §1 and §2, this service does **not** call `GetAllAsync`. `b_AccHoldingAmount` is transactional and
grows forever, so every read is filtered *and* narrowed to the columns it needs. This is what §1.6's
"reconsider the moment this points at a table that grows" looks like when you actually reconsider.

#### Chunked `IN` lists

```csharp
foreach (var batch in (await UnpassedScrollIdsAsync(orgElementId, ct)).Chunk(500))
{
    var chunk = batch.ToList();
    holds.AddRange(await data.Repository<B_ACCHOLDINGAMOUNT>().WhereAsync(
        h => chunk.Contains(h.RELEASEDSCROLLID), SearchColumns, cancellationToken: ct));
}
```

`Contains` on a list becomes a SQL `IN (…)`, and every engine has a parameter ceiling (SQL Server's is
2,100). `Chunk(500)` keeps the query inside it whatever the branch's backlog looks like. Worth copying
anywhere a candidate-id list is not provably small.

#### `GetWithheldAmountAsync` — the arithmetic the picker cannot do

```csharp
var entryPassed   = h.SCROLLID is int sid && passed.TryGetValue(sid, out var ep) && ep > 0;
if (!entryPassed) continue;                              // draft holds withhold nothing
var rel = h.RELEASEDSCROLLID ?? 0;
var releasePassed = rel > 0 && passed.TryGetValue(rel, out var rp) && rp > 0;
if (releasePassed) continue;                             // released & authorized → no longer withheld
sum += h.HOLDAMOUNT ?? 0m;
```

Read it as a sentence: **money is withheld once the hold is approved, and stops being withheld once the
release is approved.** A hold awaiting authorization withholds nothing (nobody has agreed to it); a release
awaiting authorization still withholds (nobody has agreed to lift it yet). Both `continue`s are decisions,
not defensive coding — one scroll pass in each direction.

#### Writes

Ten of them, all `ExecuteInTransactionAsync`, all taking `orgElementId` **and** `workingDate` from the
controller. Services never read session and never call `DateTime.Now` for a business date. `CreatedOn` is
the **working date** here — unlike the Reference masters, which stamp `DateTime.Now` (§1.9). A bank's
working date is not the wall clock, and a transactional row belongs to the banking day.

`DeleteHoldAsync` deletes the scroll along with the row:

```csharp
await uow.Repository<B_ACCHOLDINGAMOUNT>().DeleteAsync(new B_ACCHOLDINGAMOUNT { ACCHOLDINGAMOUNTID = … }, ct);
if (scrollId is int sid)
    await uow.Repository<X_SCROLL>().DeleteAsync(new X_SCROLL { SCROLLID = sid }, ct);
```

An orphan scroll would sit in the branch's pending list forever, un-passable because the row it referred to
is gone. Whoever creates a scroll owns deleting it.

### 3.8 Service API

```csharp
SearchHoldsAsync(int mode, string? accountNumber, string? name, decimal? amount, int userId, int orgElementId,
                 string? sort, bool desc, int page, int pageSize, ct)   // modes 1..4
LoadHoldAsync(int id, int orgElementId, ct)                → HoldEdit?
SaveHoldAsync(int accountId, decimal holdAmount, string? remarks, int holdType, decimal availableBalance,
              int userId, int orgElementId, DateTime workingDate, ct)
UpdateHoldAsync(int id, decimal holdAmount, string? remarks, int holdType, int userId, int orgElementId, DateTime workingDate, ct)
DeleteHoldAsync(int id, int userId, int orgElementId, ct)
AuthorizeHoldAsync(int id, int userId, int orgElementId, DateTime workingDate, ct)
ReleaseHoldAsync(int id, string? releaseRemarks, int userId, int orgElementId, DateTime workingDate, ct)
UpdateReleaseAsync(int id, decimal amount, string? remarks, int userId, int orgElementId, DateTime workingDate, ct)
UndoReleaseAsync(int id, int userId, int orgElementId, DateTime workingDate, ct)
AuthorizeReleaseAsync(int id, int userId, int orgElementId, DateTime workingDate, ct)
GetWithheldAmountAsync(int accountId, ct) → decimal

public sealed record HoldEdit(int AccHoldingAmountId, int AccountId, int AccountHeadId, string AccountNumber,
    string CustomerName, string ChartOfAccount, decimal Balance, decimal HoldAmount, string? Remarks,
    int HoldType, bool IsPassed, int CreatedBy,
    string? ReleaseRemarks, bool IsReleased, bool IsReleasePassed, int LastModifiedBy);
```

`HoldEdit` carries **four booleans and two maker ids** because the four screens between them need to answer
every question in §3.3's state table. One record, one load method, four screens.

### 3.9 Gotchas

- **Branch scope is the entry's own `SourceOrgElementId`**, not the maker's current branch. This was a real
  defect, found and fixed; the same mistake was then avoided on Direct Credit.
- **The maker column differs per cycle** — `CreatedBy` for the entry, `LastModifiedBy` for the release. Using
  one for both lets a user authorize their own work.
- **`availableWithdrawal` is a placeholder** (`"— (pending)"`): it is `withdrawable − withheld` and the
  withdrawable calculation is deferred. Don't read the blank as a zero.
- **Release does not persist an edited amount; Update does.** Legacy's behaviour, preserved and commented.
- `Fail(res)` logs the exception with `res.Reference` and returns the real message only in Development —
  copy that helper onto any screen with JSON endpoints.
- `SplitAccountNumber` slices the display number by configured widths. **This is the truncation bug from
  §5.11** — safe here because the number is re-sliced from the loaded value, but never rebuild a *stored*
  number from segments for display.
- **`data.Repository<T>()` inside an `ExecuteInTransactionAsync` lambda silently escapes the transaction.**
  Always `uow.Repository<T>()`.

---

## 4. Direct Credit Outgoing (2 screens)

`/RetailBanking/DirectCredit` (**3287**) + `…/Authorize` (**3288**) · tables `x_DirectCredit` +
`x_DirectCreditDetail` · scroll source **2214** · migration `0017` · legacy `x_DirectCredit.aspx` (154 KB,
the largest page in the batch).

One debit account → many beneficiary credits (BBAN, bank, branch, amount). **Three new things** over §3:
a header/detail shape, a client-side grid posted as JSON, and a CSV import. It is also the first screen
that hits the posting boundary head-on.

### 4.1 Files

| Path | Role |
|---|---|
| [TflCbs.Modules.RetailBanking/DirectCreditService.cs](../TflCbs.Modules.RetailBanking/DirectCreditService.cs) | 1008 lines — the largest service here |
| [.../Controllers/DirectCreditController.cs](../TflCbs.Modules.RetailBanking.Web/Areas/RetailBanking/Controllers/DirectCreditController.cs) | 506 lines |
| [.../Views/DirectCredit/Index.cshtml](../TflCbs.Modules.RetailBanking.Web/Areas/RetailBanking/Views/DirectCredit/Index.cshtml) | Entry, 331 lines — two forms |
| [.../Views/DirectCredit/Authorize.cshtml](../TflCbs.Modules.RetailBanking.Web/Areas/RetailBanking/Views/DirectCredit/Authorize.cshtml) | Read-only checker view, 143 lines |
| [.../Models/RetailBanking/DirectCreditForm.cs](../TflCbs.Modules.RetailBanking.Web/Models/RetailBanking/DirectCreditForm.cs) | 69 lines |
| [.../wwwroot/js/direct-credit.js](../TflCbs.Modules.RetailBanking.Web/wwwroot/js/direct-credit.js) | Beneficiary grid → hidden JSON, 229 lines |

### 4.2 Why the code sits where it does

`DirectCreditService` is in **`TflCbs.Modules.RetailBanking`** for §3.2's reasons — real domain behaviour,
one consumer. It takes the same two dependencies:

```csharp
public sealed class DirectCreditService(DataAccess data, IScrollService scrolls)
```

The controller adds nothing structural over §3: two services, `env` + `logger` for the same `Fail(res)`
helper, two screen keys instead of four.

What is new is that **two constants live on the service, not the view**:

```csharp
public const int BbanLength = 18;
public static readonly string[] CsvColumns = [ "Type", "DebitAccountNumber", …, "Address" ];
```

`CsvColumns` is `public static` because the view prints it as user help:

```razor
Columns: @string.Join(", ", DirectCreditService.CsvColumns).
```

One list, used by the parser and by the instructions the user reads. Documentation that cannot drift from
the code, because it *is* the code.

### 4.3 ⛔ Posting is deferred — how the refusal is shaped

The entire authorize method:

```csharp
// ponytail: posting engine deferred (0.1) — the whole method is the guard. Implement by porting
// pr_x_DirectCreditAuth (scroll pass + pr_x_passTransaction) once the engine exists.
public Task<Result> AuthorizeAsync(
    int directCreditId, int userId, int orgElementId, DateTime workingDate, CancellationToken ct = default) =>
    Task.FromResult(NotImplementedYet.PostingRequired());     // → error code "NOTIMPL-POSTING"
```

Read the shape, not just the behaviour. Three decisions:

- **The refusal is in the service, not the controller.** Every caller — this screen, a future API, a test —
  gets the same answer. A controller-side guard would be one route's opinion.
- **It refuses rather than half-succeeding.** Passing the scroll and skipping the ledger would leave an entry
  that reads as authorized and never moved a cent. A screen that loudly cannot finish is safe; one that
  quietly half-finishes is not.
- **The comment names the port.** `pr_x_DirectCreditAuth`, scroll pass + `pr_x_passTransaction`. Whoever
  picks up the posting engine does not have to re-find that.

`grep NOTIMPL-POSTING` is the debt ledger for the whole solution — eight sites across this service and §5's.

**Drafts are the documented exception.** Save/Update/Delete write real rows — header, details, unpassed
scroll — because entry, validation and maker-checker are the bulk of the screen and none of it posts. One
detail makes that safe:

```csharp
// UniqueTranNumber is left NULL on purpose: pr_x_GetNextUniqueTranSeqNo is the posting sequence, and
// burning numbers on entries that never post would gap it.
```

### 4.4 The draft invariant — the guard to copy

An entry may be edited or deleted only while **all** of these hold. Order matters — report the most specific
blocker first:

```csharp
private async Task<Result?> GuardEditableAsync(X_DIRECTCREDIT h, int userId, int orgElementId, CancellationToken ct)
{
    if (!IsInBranch(h, orgElementId))
        return Result.Fail(errorString: "Record not found.");      // 1. branch — and it says nothing more

    if ((scroll?.PASSEDBY1 ?? 0) > 0)
        return Result.Fail(errorString: "Authorized record cannot be modified.");   // 2. checker agreed

    if (await HasLedgerRowsAsync(scrollId, ct))                    // 3. x_Transaction rows exist
        return NotImplementedYet.PostingRequired();                //    unwinding a posting needs the engine

    if ((h.CREATEDBY ?? 0) != userId)
        return Result.Fail(errorString: "Only the maker can modify this entry.");   // 4. maker

    return null;
}
```

Test 3 is the one §3 did not have, and it has a consequence worth knowing: **every entry the legacy app
created has ledger rows, so all historic entries are read-only here.** That is intended, not a migration
gap. The new screen can only edit what the new screen made.

Test 3 also explains why the ordering matters. A posted, unauthorized entry would otherwise fall through to
"Only the maker can modify this entry" — technically true, wholly misleading.

### 4.5 The controller

506 lines. Two screen keys, the §3.4 pattern exactly (`screen:` on every token call outside the entry
screen), plus three things §3 did not need.

#### The mapping pre-check

```csharp
[HttpGet("mapping-info")]
public async Task<IActionResult> MappingInfo([FromQuery] int accountHeadId, CancellationToken ct)
{
    var (currencyId, bankAccountId) = await ResolveMappingAsync(accountHeadId, ct);
    return Json(new { currencyId, bankAccountId, mapped = bankAccountId > 0,
                      message = bankAccountId > 0 ? "" : "Bank Account Mapping not found" });
}
```

A chart of account implies a currency; a currency plus a branch implies a contra bank account in
`b_InwOtwBankAccMapping`. If that mapping is missing, nothing on the screen can ever be saved. Legacy
discovered this at Save; here it is surfaced the moment an account is picked.

Note what the browser is **not** trusted with:

```csharp
var (_, bankAccountId) = await ResolveMappingAsync(form.AccountHeadId, ct);   // in Save AND Update
```

`BankAccountId` is resolved server-side on every write, discarding whatever the endpoint told the client
earlier. **The endpoint exists to warn the user early; the save re-derives the value.** Same pattern as
§2.5's cascade — a client-visible hint plus a server-side control.

#### Beneficiaries in and out of JSON

The grid posts as one hidden field, and both directions are deliberate:

```csharp
private static readonly JsonSerializerOptions JsonOpts = new()
{
    PropertyNameCaseInsensitive = true,                    // IN:  bind whatever casing arrives
    PropertyNamingPolicy = JsonNamingPolicy.CamelCase,      // OUT: the JS and the view read camelCase
};
```

Asymmetric on purpose. Strictness on the way out (one canonical shape the client can rely on); tolerance on
the way in (a round trip through a browser is not worth failing over `BBan` vs `bban`).

```csharp
private static List<DirectCreditService.BeneficiaryRow> ParseBeneficiaries(DirectCreditForm form)
{
    if (string.IsNullOrWhiteSpace(form.BeneficiariesJson)) return [];
    try { … }
    catch (JsonException) { return []; }     // ← malformed JSON = no rows
}
```

**Malformed JSON degrades to an empty list rather than throwing.** The service then refuses with *"Add at
least one credit record."* — a message the user can act on, instead of a 500 from a hand-edited hidden
field. The trust boundary is the service's `Validate`, not the parser.

`PostedBeneficiary` is a private nested class describing exactly the wire shape. Deserializing straight into
`BeneficiaryRow` would tie the service's record layout to the browser's payload; a separate wire type keeps
them free to differ. It also carries `BankName` / `BranchName`, which are **display-only and never trusted
server-side** — they exist so a re-render can redraw the grid without a lookup.

#### The CSV import action

```csharp
[HttpPost("import")]
[RequestSizeLimit(MaxImportBytes)]            // 2 MB — refused before ASP.NET buffers the body
public async Task<IActionResult> Import(IFormFile? file, CancellationToken ct)
```

`[RequestSizeLimit]` is the first line of defence: the request is refused **before** the framework buffers
it, so a 2 GB upload costs nothing. `ValidateUpload` then re-checks the size (the attribute is a pipeline
limit; the check is this action's rule) and takes the **file extension**, not the client-declared content
type:

```csharp
var ext = Path.GetExtension(file.FileName);
if (!string.Equals(ext, ".csv", …) && !string.Equals(ext, ".txt", …))
    error = "Import a .csv file. Excel workbooks are not supported — use Save As → CSV.";
```

`Content-Type` is whatever the client says it is. The extension is not much better as a security control,
but it is a far better *diagnostic* — and the message tells the user exactly what to do, because the most
likely mistake is uploading the `.xlsx` legacy used to accept.

**All-or-nothing:**

```csharp
if (import.Errors.Count > 0)
{
    // Legacy refuses the whole file too — a partly applied import is worse than none.
    this.NotifyError($"The file was not imported:{Environment.NewLine}"
        + string.Join(Environment.NewLine, import.Errors.Take(MaxReportedImportErrors))
        + (import.Errors.Count > MaxReportedImportErrors ? $"… and {…} more." : string.Empty));
    return View(nameof(Index), form);
}
```

The service returns **every** rejection, not the first — someone fixing a 500-row file wants the whole list —
and the modal shows the first 10 with a count of the rest. Both halves matter: all errors collected, a
bounded number displayed.

And on success:

```csharp
this.NotifySuccess($"{import.Beneficiaries.Count} beneficiary record(s) imported. Review and press Save.");
```

**Import fills the form and stops. It never writes.** Legacy did the same. The user still sees, checks and
saves; an import that wrote directly would be a bulk payment nobody looked at.

### 4.6 The views

#### `Index.cshtml` — 331 lines, and **two** forms

The one structural surprise on this screen:

```razor
<form method="post" asp-action="Save">          … the entry form …          </form>

@if (!readOnly)
{
    @* Separate form: a file upload pre-fills the entry form above; it writes nothing. *@
    <form method="post" enctype="multipart/form-data" asp-action="Import"> … </form>
}
```

They must be separate. `enctype="multipart/form-data"` would apply to the whole entry form, and every save
would be sent as a multipart body for no reason. Two forms, two content types, two purposes — and HTML
cannot nest them.

#### `readOnly` — a third state beyond §2's freeze

```csharp
var isEdit   = ViewData["IsEditMode"] is true;
var readOnly = isEdit && !Model.IsEditable;     // IsEditable comes from the service's draft invariant
```

Threaded through the whole view: `Disabled = readOnly` on the account picker, `readonly="@readOnly"` on each
input, the whole beneficiary editor hidden, and the import card gone. **The view's `readOnly` is the same
`GuardEditableAsync` decision, rendered.** The service decides; the view displays; the service decides again
on POST.

#### The draft badge

```razor
@* The draft badge: a saved entry has NOT moved money while posting is deferred. *@
<input class="form-control" value="@(Model.IsPosted ? "Posted" : "Draft — not posted")" readonly />
```

Small, and the most important text on the screen. A saved direct credit looks like a completed one — same
row, same scroll number, same remittance number. Saying so on the screen is what stops someone treating a
draft as done.

#### The beneficiary grid

An editor row (BBAN, name, bank picker, branch picker, amount, address), four buttons
(**Add / Update / Delete / Cancel** — all `type="button"`, so none of them submit), a table, and a footer:

```html
<td colspan="5" class="ta-right">Total Credit</td>
<td id="benTotal">0.00</td>
<td>Difference <span id="benDiff">0.00</span></td>
```

The difference against the debit amount, live. It is a **hint** — the service refuses the save if the totals
disagree — but it is the hint that stops a 200-row file being submitted three times.

Bank and branch use two `_RecordPicker`s in the §2.5 cascade: branch depends on bank.

#### `Authorize.cshtml`

Read-only, `hasRecord`-gated, same shape as §3.5's checker view: the checker searches, reads, and presses
one button that always returns `NOTIMPL-POSTING` today.

### 4.7 The JavaScript — 229 lines

The largest client file in the batch, and the pattern to copy for any editable grid.

```
rows[]  ←→  #BeneficiariesJson (hidden)  ←→  server
   │
   └── render() redraws the table from rows[]; sync() writes JSON on every mutation
```

State lives in a JS array; the hidden field is its serialization; the table is its rendering. **One source
of truth, two projections.** `parseInitial()` reads the hidden field on load, so an edit or a validation
bounce redraws exactly what the server sent.

Two details worth stealing:

```javascript
// "Not selected" is an EMPTY hidden field, never a zero: b_BranchList carries a real
// BranchListId of 0, so a > 0 test would silently refuse a genuine branch.
```

A live-data fact that would have been a bug and is instead a comment. The service agrees, in the same words:

```csharp
// NOT "<= 0": b_BranchList really does carry a BranchListId of 0 (bank 004 / branch 001 on xnet),
// so zero is a selection, not the absence of one. Only a negative id is impossible.
if (b.BankListId < 0 || b.BranchListId < 0)
    return Result.Fail(errorString: "Invalid Bank/Branch Code.");
```

**Whenever `0` is a real id, `> 0` is a bug.** Check both sides.

```javascript
document.addEventListener("cbs:account-picked", function () { … fetch mapping-info … });
if (debitAmount) debitAmount.addEventListener("input", renderTotals);
```

The same event-driven coupling as §3, plus a live recompute on typing.

### 4.8 Flows

```
GET  /                        → blank form
GET  /?row={token}            → LoadAsync(id, OrgElementId); refuse if IsPassed; readOnly if !IsEditable
GET  /search-account-heads    → debit COA picker (78,79,82)
GET  /search-accounts         → debit account picker, own branch
GET  /search-banks            → b_BankList
GET  /search-branches         → branches of the chosen bank (cascade, §2.5)
GET  /search-entries          → maker's own drafts (mode 0) / others' (mode 1 on the authorize route)
GET  /mapping-info?accountHeadId → { currencyId, bankAccountId, mapped, message }
POST /import                  → CSV → parsed, validated, NOT saved (fills the form; user presses Save)
POST /save                    → ParseBeneficiaries → ResolveMapping → SaveAsync (scroll + header + details)
POST /update                  → TryBeginWrite → parse → TryConsume → UpdateAsync (details rewritten wholesale)
POST /delete                  → TryConsume → DeleteAsync
GET  /Authorize?row={token}   → read-only view of the draft
POST /authorize               → TryConsume → AuthorizeAsync → always NOTIMPL-POSTING
```

`UpdateAsync` **deletes and reinserts every beneficiary row**, as legacy's `ProcessDirectCreditDetails`
does. Safe here because the details carry nothing but the values on the form — no external references, no
uploaded bytes. Contrast §5, where the same shortcut would have destroyed uploaded documents.

### 4.9 The service

1008 lines; the parts §1–§3 have not already covered.

#### `Validate` — a static method, and why that matters

```csharp
private static Result? Validate(
    int debitAccountId, int debitAccountHeadId, int debitOrgElementId, decimal debitAmount, int bankAccountId,
    int? chequeNumber, DateTime? chequeDate, IReadOnlyList<BeneficiaryRow> beneficiaries,
    int orgElementId, DateTime workingDate)
```

**`static`**, so it cannot touch the database, the clock or the session — every input is a parameter,
including `workingDate`. That makes the entry rules a pure function: trivially testable, and impossible to
make quietly order-dependent. Both `SaveAsync` and `UpdateAsync` call it first.

The rules, in legacy's order:

| Check | Message |
|---|---|
| bank-account mapping resolved | `Bank Account Mapping not found.` |
| chart of account chosen | `Select a Chart of Account.` |
| debit account chosen | `Select a debit account.` |
| **debit branch == session branch** | `NOTIMPL-IBT` (see below) |
| amount > 0 | `Transfer Amount can not be zero.` |
| cheque number ⇒ cheque date | `Cheque Date can not be blank.` |
| cheque date ⇒ cheque number | `Cheque number can not be blank or zero.` |
| cheque date ≤ working date | `Cheque date can not be greater than working date.` |
| ≥ 1 beneficiary | `Add at least one credit record.` |
| per row: BBAN present, length 18, name, amount > 0, ids ≥ 0 | `BBan Number Not Provided.` etc. |
| **Σ credits == debit** | `Total Credit Amount must be equal to Debit Amount.` |

Cross-branch is refused at the service even though the UI offers no branch choice:

```csharp
// Legacy's uxBranch dropdown lets the debit sit at another branch and then posts it through
// IBTFunctions (a second connection — each branch is its own database on xnet). Refuse it here
// rather than saving a draft nothing can ever authorize. Today the screen offers no branch
// choice, so this guards the service contract, not the UI.
if (debitOrgElementId != orgElementId)
    return NotImplementedYet.InterBranchRequired();
```

**Guard the service contract, not the current UI.** The screen not offering the option today is not a reason
to accept it from a caller.

#### The cheque pair

```csharp
if (chequeNumber is > 0 && chequeDate is null)      → "Cheque Date can not be blank."
if (chequeDate is not null && chequeNumber is null or <= 0) → "Cheque number can not be blank or zero."
```

Both present or both absent. Written as two one-directional checks rather than one XOR because each gets its
own message naming the missing field.

#### Computed, not stored

```csharp
private static string RemittanceNumber(string orgCode, int directCreditId) => …   // branch code + id, padded to 7
```

The remittance number has no column. It is derived on read, so it can never disagree with the row it
identifies. **Do not store what you can compute from a key.**

### 4.10 Gotchas

- **`JsonSerializerOptions` is asymmetric on purpose**: `CamelCase` out, `PropertyNameCaseInsensitive` in.
- **Beneficiary rows post as one hidden JSON field**, not an indexed form array — the same pattern §5 uses
  for denominations and Locker Type uses for rent discounts.
- **`BranchListId` of 0 is a real branch.** `> 0` tests silently refuse it. The service uses `< 0`.
- **`LoadAsync` reports `IsPosted`** from `HasLedgerRowsAsync`, and both views print `Draft — not posted`, so
  nobody mistakes a saved entry for a posted one.
- **Update rewrites all beneficiary rows wholesale.** Fine here; it would be data loss on a table holding
  uploaded bytes (§5.8).
- **`UniqueTranNumber` stays NULL on drafts** — the posting sequence is not burned by entries that never post.
- **Every legacy-created entry is read-only** because it has `x_Transaction` rows. Working as intended.
- The import is capped twice — `[RequestSizeLimit]` before buffering and `ValidateUpload` after — and the
  file is parsed and discarded, never stored.

---

## 5. Dormant Re Activation (2 screens)

`/RetailBanking/DormantReactivation` (**951**) + `…/Authorize` (**952**) · tables `x_DormantReactivation`,
`x_DormantReactivationDocs`, and the two `*Log` archives · scroll source **1191** · migration `0019` ·
legacy `RetailBanking/dormant/x_DormantReActivationv1.aspx` (98 KB).

Reactivates a dormant account: the maker picks the account, the system **prices** a reactivation charge, the
maker uploads two scans and saves a draft; the checker downloads both scans and authorizes — which recovers
the charge and flips `b_Account.AccountStatusCode` to 8 (ACTIVE).

The most involved screen in the batch. It carries everything §3 and §4 introduced **plus** file upload,
file download, a server-side download gate, a priced-not-posted charge, an archive-on-reject, and the one
path in the batch that completes past the posting boundary.

Constants, all `public` on the service: `ModeCash = 61`, `ModeTransfer = 63`, `ChargeTag = "DORMANT"`,
`ActiveStatusCode = 8`, `ActionApprove = 1`, `ActionReject = 2`, and
`DocumentTypes = { 1: Customer ID card, 2: Dormant activation form }`.

### 5.1 Files

| Path | Role |
|---|---|
| [TflCbs.Modules.RetailBanking/DormantReactivationService.cs](../TflCbs.Modules.RetailBanking/DormantReactivationService.cs) | 1106 lines |
| [.../Controllers/DormantReactivationController.cs](../TflCbs.Modules.RetailBanking.Web/Areas/RetailBanking/Controllers/DormantReactivationController.cs) | 556 lines, **three** screen keys |
| [.../Views/DormantReactivation/Index.cshtml](../TflCbs.Modules.RetailBanking.Web/Areas/RetailBanking/Views/DormantReactivation/Index.cshtml) | Entry, multipart |
| [.../Views/DormantReactivation/Authorize.cshtml](../TflCbs.Modules.RetailBanking.Web/Areas/RetailBanking/Views/DormantReactivation/Authorize.cshtml) | Checker: downloads + Authorize/Reject |
| [.../Models/RetailBanking/DormantReactivationForm.cs](../TflCbs.Modules.RetailBanking.Web/Models/RetailBanking/DormantReactivationForm.cs) | Two fixed doc slots, `DenominationsJson`, `AccountNumberDisplay` |
| [.../wwwroot/js/dormant-reactivation.js](../TflCbs.Modules.RetailBanking.Web/wwwroot/js/dormant-reactivation.js) | Account panel, charge, denomination grid |
| [TflCbs.Framework/Services/FileUploads.cs](../TflCbs.Framework/Services/FileUploads.cs) | **No type gate** — see §5.7 |

### 5.2 Why the code sits where it does

`DormantReactivationService` is in `TflCbs.Modules.RetailBanking` for §3.2's reasons. Two placement
decisions are new.

**`FileUploads` is in `TflCbs.Framework/Services`, not in the module.** Upload validation is web plumbing —
`IFormFile`, size caps, filename sanitising — with no banking in it, and it is available to every screen.
The module keeps the banking; the framework keeps the plumbing. (Its image twin `ImageUploads` moved out of
Framework on 2026-09-11 — Signature was its only caller, so it now lives in `SignatureController.cs`; it
comes back here the day a second screen needs it.)

**The denomination grid pulls `TflCbs.Modules.Reference` into `RetailBanking.Web`:**

```
TflCbs.Modules.RetailBanking.Web ──► TflCbs.Modules.Reference     (DenominationService)
```

The **Web RCL** takes the reference, not the service module. `RetailBanking` (the service assembly) stays a
leaf that knows only `Abstractions` + `General.Contracts`. It is the same edge `Hr.Web` already has, and it
is the *second consumer* that admitted Denominations to `Reference` in the first place (§2.2) — the
admission rule paying off rather than being asserted.

### 5.3 The one case that completes

Everything else in §4 refuses at the money boundary. This screen does not, and the reason is worth
understanding because it is the template for every future partial migration.

Legacy's pass does **two separable things**: it recovers the reactivation charge *and* it flips the account
to ACTIVE. When the charge is zero there is nothing to recover — so the reactivation is only the status
change, and it completes.

`AuthorizeAsync`, in exact order:

```csharp
record deleted            → "Record already deleted."
wrong branch              → "Record not found."
maker == checker          → "Maker cannot authorize their own entry."
scroll already passed     → "Record is already authorized."

if (charges > 0m)                                    // the checker's approval limit, per currency and mode
{
    var limit = await GetAuthLimitAsync(userId, e.CURRENCYID ?? 0, e.MODEOFTRANSACTION ?? ModeTransfer, ct);
    if (charges > limit) return Result.Fail(errorString: "Amount is exceeding the approval limit allowed to you.");
}

// Everything below this line would have to move money.
if (await HasLedgerRowsAsync(scrollId, ct))              return NotImplementedYet.PostingRequired();
if (charges > 0m || (e.ISHOLDCHARGES ?? false))          return NotImplementedYet.PostingRequired();
if ((e.ORGELEMENTID ?? 0) != orgElementId)               return NotImplementedYet.PostingRequired(); // inter-branch

// otherwise: ONE transaction
account.ACCOUNTSTATUSCODE = ActiveStatusCode;  account.STATUSCHANGEDATE = workingDate;  …
b_ModificationLog row (old status → new status, entered by maker, passed by checker)
e.ACTIONSTATUS = ActionApprove;  …
await scrolls.PassAsync(uow, scrollId, userId, workingDate, ct);
```

Three things to take from that ordering.

**The limit check runs *before* the posting refusal**, deliberately. They are different problems and only
one is temporary: "you are not allowed to approve this much" is a permanent rule about the checker, while
`NOTIMPL-POSTING` is a note about this codebase. Reversing them would hide a real authorization failure
behind a temporary one, and when the engine lands the limit bug would surface for the first time in
production. A user with **no limit row is capped at 0, not at infinity** — `GetAuthLimitAsync` returns 0
when nothing matches.

**The comment line is load-bearing.** `// Everything below this line would have to move money.` Anyone
adding a check has to decide which side of it they are on.

**The status change is never silent.** A `b_ModificationLog` row records old value, new value, who entered
and who passed. Legacy writes it; keeping it means an account status change is always attributable.

### 5.4 The charge is priced by the service, never posted by the form

The most important security decision on this screen, and it was a real defect before it was a rule.

`SaveAsync` and `UpdateAsync` take **no charge parameter**. They price it themselves:

```csharp
private async Task<Result<(int CurrencyId, decimal Charges)>> PriceAsync(int accountId, int userId, CancellationToken ct)
{
    var account = await GetAccountAsync(accountId, ct);          // balance, head currency, status
    …
    var charge  = await GetChargeAsync(accountId, acc.Balance, userId, ct);   // wraps pr_x_getChargesAmount
    return Result<(int, decimal)>.Ok((acc.CurrencyId, charge.Value!.Amount));
}
```

Why it must be this way: **`AuthorizeAsync` reads the stored `ChargesAmount` to decide whether posting is
required** (§5.3). If the form could set that number, a forged or stale zero would walk an account through
reactivation with the fee never taken — and the audit trail would say a human approved it.

The currency comes from the same place for the same reason: it selects the checker's approval limit.

```csharp
// legacy GetCurrencyId = ISNULL(CurrencyId, (SELECT CurrencyId FROM g_Currency WHERE IsDomestic = 1))
var currencyId = headCurrencyId != 0 ? headCurrencyId : await DomesticCurrencyIdAsync(ct);
```

An account head with no currency of its own **is** domestic. Storing 0 broke `a_UserTranAuthLimit`, which is
currency-keyed — see §5.11 gotcha 1.

The form still *shows* a charge, and `account-info` still returns one. That is display. The rule is:
**anything the authorization decision reads must be derived server-side at write time.**

One more detail in `account-info`:

```csharp
charges     = charge.IsSuccess ? charge.Value!.Amount : 0m,
chargeError = charge.IsSuccess ? string.Empty : charge.ErrorString,
// A failed charge lookup must not silently read as "no charge": say so and let the user retry.
```

A failed pricing call returning `0` would look exactly like a free reactivation. The extra field is what
distinguishes "no charge" from "we could not work out the charge".

### 5.5 Reject is archive-and-delete, not a status stamp

This was found by reading the stored procedure rather than the page, after a first implementation got it
wrong.

`pr_x_dormantReactivationSavev1 @p_mode = 3` copies the entry **and its document bytes** into
`x_DormantReactivationLog` / `x_DormantReactivationDocsLog` with `RejectedBy` / `RejectedOn` /
`ActionStatus` / `ActionRemark` — then falls through into mode 2's delete branch.

```csharp
// The bytes, which the metadata-only list deliberately leaves behind: the log copy is the
// record of what was rejected, so it has to carry them.
var documents = await LoadDocumentsWithBytesAsync(dormantReactivationId, ct);

await data.ExecuteInTransactionAsync(async uow =>
{
    …InsertAsync(new X_DORMANTREACTIVATIONLOG { …, ACTIONSTATUS = ActionReject,
        ACTIONREMARK = actionRemark.Trim(), REJECTEDBY = userId, … });
    // …the doc bytes into X_DORMANTREACTIVATIONDOCSLOG, then delete docs, entry and scroll
});
```

**The first implementation stamped `ACTIONSTATUS` and passed the scroll** — which would have left a rejected
entry alive in the live table and reading as *authorized*. It passed every test that existed.

Two habits come out of this:

- **Read the proc, not the page.** The page called mode 3; only the proc said what mode 3 meant.
- **Note the deliberate double read.** The list load is metadata-only (no bytes — a list must not haul
  megabytes), so the reject path re-reads *with* bytes. The comment says why, because the second read looks
  redundant until you know what the first one omits.

`RejectAsync` requires a remark (`"Action remark cannot be left blank."`) and refuses maker == checker, same
as authorize.

### 5.6 The download gate — server-side

Legacy: *"All documents must be downloaded before saving."* Legacy tracked it in a page field, which a
refresh reset. Here it is session state, written by the download endpoint:

```csharp
private static string SeenKey(int documentId) => $"dormant:doc:{documentId}";
private void MarkDocumentSeen(int documentId) => HttpContext.Session.SetInt32(SeenKey(documentId), 1);
private bool AllDocumentsSeen(IReadOnlyList<ScanDocument> docs) =>
    docs.Count > 0 && docs.All(d => d.Id is int id && HttpContext.Session.GetInt32(SeenKey(id)) == 1);
```

Checked in `DoAuthorize` **before the token is consumed**:

```csharp
// Legacy: "All documents must be downloaded before saving." It gates approval, not rejection —
// a checker who cannot read the scans is exactly who should be able to send the entry back.
if (!isReject && edit is not null && !AllDocumentsSeen(edit.Documents))
{
    this.NotifyError("All documents must be downloaded before authorizing.");
    return RedirectToRecord(AuthHostUrl, id.ToString(), screen: AuthScreenKey);
}

if (!TryConsume(form.Row, out _, MsgAlreadyDone, screen: AuthScreenKey))
    return Redirect(AuthHostUrl);
```

Four decisions in that block:

1. **Server-side.** The view disables the button; the server refuses regardless. Proven by force-enabling it
   in devtools and still being refused.
2. **Recorded by the download endpoint**, not by a "mark as read" call the client makes. The evidence is the
   act itself.
3. **Session-scoped**, so a page reload does not reset it — the bug legacy had.
4. **Before `TryConsume`.** Refusing after consuming would eat the token and force the checker to search for
   the record again just to be told to read the documents. Same principle as the resolve → validate → consume
   ordering in `know-your-code` §1.3.

`ClearDocumentsSeen` runs after a successful authorize or reject, so the flags do not accumulate in a long
session.

#### The document endpoint has its own screen key

```csharp
private const string DocScreenKey = "RetailBanking/DormantReactivation/Document";

[HttpGet("document/{token}")]
[CbsAccessScreen(AuthScreenKey)]                 // access = the authorize right
public async Task<IActionResult> Document(string token, CancellationToken ct)
{
    if (!TryOpenRecord(token, out var idStr, screen: DocScreenKey) || !int.TryParse(idStr, out var documentId))
        return NotFound();
    …
    MarkDocumentSeen(documentId);
    Response.Headers.CacheControl = "no-store";
    return File(bytes, "application/octet-stream", doc.FileName);
}
```

Five things in one small action:

- **Three screen keys, two purposes.** Access uses `AuthScreenKey` (you need the authorize right); tokens use
  `DocScreenKey` (a document token can never be spent as a record token). Different capability, different
  key — the same design as §7's image endpoint.
- **`TryOpenRecord`, not `TryConsume`.** A download is a read and browsers repeat them. Single-use here would
  break the very gate it feeds.
- **Missing and not-your-branch both return `NotFound()`**, so the endpoint cannot be used to enumerate ids.
- **`Cache-Control: no-store`** — a scanned ID card should not sit in a shared workstation's disk cache.
- **`application/octet-stream` + attachment**, always. That is the other half of the "no type gate" decision
  in §5.7, and it is not optional.

### 5.7 Uploads: `FileUploads`, not `ImageUploads`

Two helpers, deliberately different:

| | `ImageUploads` (§7) | `FileUploads` (here) |
|---|---|---|
| Type gate | extension allowlist + magic-byte sniff | **none** |
| Served as | sniffed content type, inline `<img>` | always `application/octet-stream` + attachment |
| Cap | configured, clamped | `MaxDocumentKb = 4096`, clamped by a hard ceiling |

The reason for no gate is recorded in the file itself: legacy's `uxAddScanFile_Click` reads
`PostedFile.InputStream` into a byte array with **no extension test, no content-type test and no size test at
all**. Branches scan whatever their scanner produces — PDFs, and in testing a `.txt`. Narrowing to images
would bounce real documents.

**Accepting any bytes is only safe if they are never interpreted**, so the safety moves to two rules the
doc comment states as non-negotiable:

1. Serving must be `File(bytes, "application/octet-stream", fileName)` — never an inline render, never a
   sniffed type. That is what stops an uploaded `.html` or `.svg` executing under this origin.
2. The size is capped in the helper **and** by a matching `[RequestSizeLimit]` on the action, which refuses
   an oversized body before it is buffered:

```csharp
[HttpPost("save")]
[RequestSizeLimit(2L * MaxDocumentKb * 1024L)]   // both documents in one post
```

The filename is rebuilt rather than trusted — path segments dropped, control characters stripped, length
capped. `..\..\web.config` becomes `web.config`.

**The size cap is the one thing added that legacy did not have, and it is not negotiable.** Preserving legacy
behaviour is not the same as preserving legacy omissions: the type gate was a deliberate product decision,
an unbounded upload is just a missing limit.

### 5.8 The controller

556 lines. Three screen keys (§5.6), the §3.4 pattern, plus two things unique to this screen.

#### `TryReadDocuments` — the merge that avoids destroying uploads

§4's update deletes and reinserts every detail row. Do that here and every re-save without re-picking the
files would **wipe both scanned documents**. So the two slots are merged instead:

```csharp
foreach (var (typeId, file, remarks, storedId) in new[]
{
    (1, form.Doc1File, form.Doc1Remarks, form.Doc1Id),
    (2, form.Doc2File, form.Doc2Remarks, form.Doc2Id),
})
{
    if (file is { Length: > 0 })                       // a new upload replaces
    {
        var read = FileUploads.Read(file, MaxDocumentKb);
        if (!read.IsSuccess) { error = $"{DocumentTypes[typeId]}: {read.ErrorString}"; return false; }
        documents.Add(new ScanDocument(storedId, typeId, read.Value!.FileName, remarks, read.Value.Bytes));
        continue;
    }

    var kept = existing.FirstOrDefault(d => d.ScanDocTypeId == typeId);   // otherwise keep what is stored
    if (kept is not null)
        documents.Add(kept with { Remarks = remarks });                   // …but take the new remark
}
```

Read the two branches as a sentence: **a new file replaces; no new file keeps the stored one, with whatever
remark was typed.** `kept with { Remarks = remarks }` is a record `with`-expression — a copy with one field
changed — which is exactly "same document, new note".

The service completes the merge, distinguishing rows by whether they arrived carrying bytes:

```csharp
foreach (var doc in documents)
    if (doc.Bytes is { Length: > 0 })          // replaced or new
    {
        if (doc.Id is int id) await repo.DeleteAsync(…);
        await InsertDocumentAsync(uow, dormantReactivationId, doc, userId, workingDate, ct);
    }
// Rows dropped on screen: present in the database, absent from the post.
var kept = documents.Where(d => d.Id is not null).Select(d => d.Id!.Value).ToHashSet();
foreach (var old in existing)
    if (old.Id is int oldId && !kept.Contains(oldId)) await repo.DeleteAsync(…);
```

**Bytes present = write it; id only = leave it alone; in the database but not in the post = delete it.**
Three cases, all of them stated. That "Update keeps untouched documents" was verified against the live
database — both rows survived with their exact byte counts.

#### Two fixed slots instead of a grid

Legacy renders a dynamic document grid and then enforces, in code, that it holds exactly one of each type
with no duplicate filename. Two typed slots express the same rule **structurally** — `Doc1File`, `Doc2File`
— so most of that validation has nothing left to catch. The checks are still in `Validate` (§5.9) because
the service must not depend on the shape of one screen's form.

#### Command dispatch: one form, two verbs

```razor
<button type="submit" name="command" value="authorize" disabled="@(!Model.DocumentsDownloaded)">Authorize</button>
<button type="submit" name="command" value="reject" data-cbs-confirm="Reject this dormant re activation?">Reject</button>
```

```csharp
public async Task<IActionResult> DoAuthorize(DormantReactivationForm form, string command, CancellationToken ct)
{
    var isReject = string.Equals(command, "reject", StringComparison.OrdinalIgnoreCase);
```

One action, one token consumption, two outcomes. This is the codebase's command-dispatch POST convention
(`<button name="command" value="…">`), and it fits here because both verbs share every precondition except
the download gate.

### 5.9 The service

1106 lines — the biggest in the batch. The parts not already covered:

#### `Validate` and `ValidateDenominations` are separate on purpose

```csharp
private static Result? Validate(int accountId, int orgElementId, int modeOfTransaction,
                                IReadOnlyList<ScanDocument> documents)
```

Static, pure, and it checks only what the caller supplied: account chosen, branch chosen, mode is cash or
transfer, and legacy's four document rules — exactly two documents, no repeated type, known types, no
repeated filename.

The denomination rule is split out, and the doc comment says why:

> *Split from `Validate` because it tests the charge this service priced, not one the caller passed.*

That is §5.4 showing up in the structure. Rules about caller input and rules about server-derived values are
different kinds of rule and are not mixed.

```csharp
public static bool IsDenominationTotalValid(
    decimal chargesAmount, int modeOfTransaction, IReadOnlyList<DenominationCount>? denominations) =>
    modeOfTransaction != ModeCash            // transfers need no breakdown
    || chargesAmount <= 0m                   // nothing to count
    || (denominations ?? []).Sum(d => d.Denomination * d.Count) == chargesAmount;
```

`public static` for two stated reasons: the screen can pre-check it without a round trip, and a test can
assert it **without needing a real dormant account to exist** — because the charge is priced from the
account, nothing reaches this through `SaveAsync` unless one does. Making one pure rule public is what keeps
that rule testable when everything around it needs a database.

#### Where the cash breakdown goes

Nowhere. It is validated and discarded — there is no table for it until the posting engine lands. That is a
deliberate reduction, recorded rather than silently dropped: the *rule* (legacy's till rule, counts must
total the charge) is kept because a mismatch is a data-entry error worth catching now.

#### The draft invariant, again

`GuardEditableAsync` is §4.4's guard, in the same order, with the same consequence: **every entry the legacy
app created has ledger rows and is read-only here.** Two screens, one shape — which is what makes it a
pattern rather than a coincidence.

Plus one this screen adds, in `SaveAsync` and `UpdateAsync`:

```csharp
if (await HasUnpassedEntryAsync(accountId, dormantReactivationId, ct))
    return Result.Fail(errorString: "Unpassed record exists for the selected account.");
```

One in-flight reactivation per account, legacy's rule, and the same shape as §3's unpassed-hold guard. The
`exceptId` parameter is `excludeId` from §2.7 in another costume — without it an update would collide with
itself.

### 5.10 Flows

```
GET  /                         → blank; enctype="multipart/form-data"
GET  /?row={token}             → LoadAsync; draft invariant as §4.4; readOnly threading as §4.6
GET  /account-info?accountId   → balance, status, dormant date, currency, AND the priced charge
GET  /denominations?currencyId → rows for the cash grid (DenominationService, from Reference)
POST /save | /update | /delete → drafts; UNIQUETRANNO stays NULL (don't burn the posting sequence)
GET  /Authorize?row={token}    → read-only + two Download links + the gate message
GET  /document/{token}         → File(bytes, "application/octet-stream", name) + MarkDocumentSeen
POST /authorize                → command "authorize" | "reject"  (one button pair, one action)
```

### 5.11 Gotchas — three found only by running the screen

These are the three that no test caught, and they are the argument for running the app before calling a
screen done.

1. **Domestic currency stored as 0.** An account head with no currency of its own *is* domestic. Storing 0
   meant `a_UserTranAuthLimit` — which is currency-keyed — matched no row, so **every domestic entry was
   refused as over-limit** no matter who the checker was. The denomination grid would have come back empty
   for the same reason. Fixed with `DomesticCurrencyIdAsync()`.
2. **Customer Name and Chart of Account went blank on any server re-render** (a refused save, a re-opened
   record). They are the account picker's own targets, filled by a selection event that a server re-render
   never raises. The account-info response already carried both, so the script now sets them too.
3. **The account number was truncated to 9 characters** on the authorize screen. It was rebuilt from the
   three picker segments, whose widths come from the bank's configured account-number format — which on this
   database is *narrower* than the 17-character numbers actually stored. Fixed with `AccountNumberDisplay`,
   the number as loaded. **Check any other screen that re-joins those segments for display** (§3.9).

A fourth was caught before the browser, by re-reading the procs: the reject semantics (§5.5) and the
client-trusted charge (§5.4).

Plus:

- **The denomination breakdown is validated, not stored.**
- **Scanned documents accept any file type**, as legacy does; the safety is on the serving side (§5.7).
- **Menu 3106 "Dormant Re Activation Final Authorization"** — a third approval stage, `IsActive = 0`,
  `ModuleId = 0`, pointing at the older non-v1 page — is untouched.

**Still owed by the engine:** charge recovery through `pr_x_transaction` / `pr_x_passTransaction` (cash with
its denomination breakdown, transfer, or held via `pr_b_HoldChargesAmt`), the UTN allocation, and the
inter-branch legs through `Pr_x_InterBranchTransaction`. `AuthorizeAsync` is the single site.

---

## 6. User Creation

`/Administration/User` · menu **828** (Central Administration) · tables `a_User`, `a_UserPolicy`,
`a_UserTranAuthLimit` (+ the mod-log tables) · migration `0015` · legacy `HO/admin/A_User.aspx` (118 KB).

Creates and maintains application users with their per-currency authorisation limits. No maker-checker, no
posting — but the most **privilege-sensitive** screen in the batch, and the only one that writes a
credential. Read §6.2 and §6.6 before changing anything here.

### 6.1 Files

| Path | Role |
|---|---|
| [TflCbs.Core.Authentication/UserAdminService.cs](../TflCbs.Core.Authentication/UserAdminService.cs) | 825 lines — **not** in the Administration module |
| [.../Administration/Controllers/UserController.cs](../TflCbs.Modules.Administration.Web/Areas/Administration/Controllers/UserController.cs) | 283 lines |
| [.../Administration/Views/User/Index.cshtml](../TflCbs.Modules.Administration.Web/Areas/Administration/Views/User/Index.cshtml) | 308 lines — three cascading pickers + limits grid |
| `Models/UserForm.cs` → `UserForm`, `UserLimitInput` | Form state, including the limits rows |

### 6.2 Why the service is in `Core.Authentication`

The one placement decision on this screen, and it is not about layering taste.

Setting a password must go through `AuthenticationService.ApplyNewPasswordAsync` — the single code path that
enforces `b_LoginPolicy` complexity, the last-N reuse rule, the `a_PasswordChangeLog` row, and the
`PASSWORDHASH` / `PASSWORDVERSION` write.

**That method is `internal` on purpose: there must be exactly one hasher.** A second password-writing path
would not fail loudly — it would produce users who log in fine today and cannot be migrated, audited or
policy-checked tomorrow.

`internal` is only reachable from inside the same assembly. So the service lives beside it:

```
TflCbs.Core.Authentication          UserAdminService  ──uses──►  AuthenticationService.ApplyNewPasswordAsync (internal)
TflCbs.Modules.Administration.Web   UserController    ──uses──►  UserAdminService (public)
```

Only the *screen* sits in Administration.Web — which already references that assembly, as `BlockedUsers` and
`ConnectedUsers` do. **Menu placement is unchanged** (828 stays under Central Administration): the URL axis
and the assembly axis travel separately, as always.

Clean break worth knowing: legacy wrote a reversible cipher into `a_User.PASSWORD`. Nothing here touches
that column.

### 6.3 The controller

283 lines, one screen key, the §1.3 shape — with three complications that all come from the same source:
**the view renders more than the form posts.**

#### `USERID` is `decimal`

```csharp
if (!TryOpenRecord(row, out var idStr) || !decimal.TryParse(idStr, out var userId))
```

Row tokens carry the id as a **string** end-to-end precisely so each screen can parse it to its own key
type. `a_User.USERID` is numeric in the database; parsing it as `int` would silently narrow. Every token
call on this screen parses `decimal` — `Index`, `Update`, `Delete`.

#### `FillLookupsAsync` — the merge that keeps a failed post honest

Two things the view renders but the post does not carry: the assignable **level list**, and the currency
rows' **display codes**. Both must be rebuilt on *every* render, including failures:

```csharp
/// Called on every render, including the failure paths — a redisplayed form with an empty level
/// dropdown would look like the user's level had been cleared.
private async Task FillLookupsAsync(UserForm form, decimal? userId, CancellationToken ct)
{
    var levels = await svc.GetUserLevelsAsync(UserId, ct);
    form.LevelOptions = levels.IsSuccess ? levels.Value ?? [] : [];

    var limits = await svc.LoadLimitsAsync(userId, ct);
    …
    // Posted rows win (the administrator's edits); the stored rows only supply the currency list and
    // its codes. On a fresh render there are no posted rows, so the stored ones are used as they are.
    var posted = form.Limits.ToDictionary(l => l.CurrencyId);
    form.Limits = currencyRows.Select(l => posted.TryGetValue(l.CurrencyId, out var p) ? …p… : …l… ).ToList();
}
```

That merge is the interesting part. After a validation failure the administrator's typed limits must
survive, but the currency **list** and its codes must come from the database. So: stored rows supply the
skeleton, posted rows supply the values. Get it backwards and a failed save quietly discards ten minutes of
typing.

Same family of problem as §1's `FillDisplayTextAsync` and §5.8's document merge — **a server-side re-render
has to reconstruct everything the browser was not asked to send back.**

#### The credential is never echoed

```csharp
private async Task<IActionResult> NewFailed(UserForm form, string message, CancellationToken ct)
{
    this.NotifyError(message);
    form.Password = form.ConfirmPassword = null; // never echo a credential back to the browser
    …
}
```

Both failure helpers blank the password before re-rendering. A password bounced back into an HTML field ends
up in the browser's DOM, in a form autofill store, in a screenshot in a support ticket. The administrator
retypes it; that is the correct cost.

#### Password is conditionally required

```csharp
// Save
if (string.IsNullOrEmpty(form.Password))
    ModelState.AddModelError("Form.Password", "'Password' cannot be blank.");

// Update
if (form.ChangePassword && string.IsNullOrEmpty(form.Password))
    ModelState.AddModelError("Form.Password", "'Password' cannot be blank.");
```

Required on create, required on update **only when the "Want to change password" box is ticked**. It cannot
be a `[Required]` attribute on the model, because the rule depends on another field — so it is an explicit
`ModelState` addition before `ModelState.IsValid` is read. That ordering is the whole trick: add your
conditional errors first, then test validity once.

### 6.4 The view

308 lines. Three cascading pickers, a conditional password block, and an indexed grid.

#### A two-level cascade

Branch → Department → Employee. The parent clears **both** children:

```csharp
// Branch picker
ClearTargets = ["#Form_OrgElementDepartmentId", "#Form_DepartmentName",
                "#Form_EmployeeId", "#Form_EmployeeName"],
```

Four selectors — id and text for each child, per §2.4's rule. The children declare what they depend on:

```csharp
// Department picker
DependsOn = new Dictionary<string, string> { ["OrgElementId"] = "#Form_OrgElementId" },

// Employee picker — depends on BOTH
DependsOn = new Dictionary<string, string>
{
    ["OrgElementId"] = "#Form_OrgElementId",
    ["OrgElementDepartmentId"] = "#Form_OrgElementDepartmentId",
},
```

**`DependsOn` is a dictionary, so a picker can depend on more than one field.** Employee is scoped by branch
*and* department. Same descriptor mechanism as §2.5, one level deeper, still no bespoke JavaScript.

And still the same three layers: the client hint (`DependsRequired`), the server filter, and — the one that
actually counts — the save-time re-check in `ValidateAsync` (§6.6), which refuses a department that does not
belong to the branch and an employee who does not belong to either.

#### The empty level dropdown is a security control

```razor
@foreach (var level in Model.Form.LevelOptions) { … }
@if (Model.Form.LevelOptions.Count == 0) { …message… }
```

An actor below Branch Manager gets **no options at all**. That is not a rendering edge case — see §6.5. The
view says so explicitly rather than drawing an empty `<select>` that looks broken.

#### The limits grid — indexed model binding

```razor
<input asp-for="Form.Limits[i].Selected" type="checkbox" />
<input asp-for="Form.Limits[i].CurrencyId" type="hidden" />
<input asp-for="Form.Limits[i].CurrencyCode" type="hidden" />
<td>@Model.Form.Limits[i].CurrencyCode</td>
<td><input asp-for="Form.Limits[i].CashCreditLimit" inputmode="decimal" maxlength="15" /></td>
…
```

**Contrast §4 and §5, which post their grids as hidden JSON.** Both are legitimate; the choice follows the
grid:

| | This screen | §4 beneficiaries / §5 denominations |
|---|---|---|
| Row set | fixed — one per currency, server-generated | dynamic — the user adds and removes rows |
| Posts as | `Form.Limits[0].*`, `Form.Limits[1].*`, … | one hidden JSON field |
| Needs JS | none | a grid script |

**A fixed row set needs no JavaScript at all.** Indexed binding handles it, and the code you do not write is
the code that cannot break. Reach for hidden JSON only when the row *count* is the user's decision.

`CurrencyId` and `CurrencyCode` ride along as hidden inputs so the posted row identifies itself — the server
must not assume row 3 is still the same currency it rendered.

#### `autocomplete="new-password"`

```razor
<input asp-for="Form.Password" type="password" maxlength="50" autocomplete="new-password" />
```

Not `off` — browsers increasingly ignore `off` on password fields. `new-password` is the value that
actually suppresses autofill, and it stops the administrator's own saved credentials being offered while
they create somebody else's account.

### 6.5 Privilege guard — `GetUserLevelsAsync` and `CanAssignLevel`

The rule: a user may only be created at a level **strictly junior** to the actor's own, and System
Administrator is never assignable at all.

```csharp
private const int SystemAdministrator = 126;
private const int Administrator = 50;
private const int BranchManager = 51;

private static bool CanAssignLevel(int actorLevel, int targetLevel) => actorLevel switch
{
    SystemAdministrator => targetLevel != SystemAdministrator,
    Administrator       => targetLevel > Administrator  && targetLevel != SystemAdministrator,
    BranchManager       => targetLevel > BranchManager  && targetLevel != SystemAdministrator,
    _                   => false,        // ← anyone else creates nobody
};
```

Read the comment in the source, because it records a live-data trap:

> *The explicit exclusions matter because System Administrator's CodeId (126) sorts **above** the ordinary
> levels (50–55), so a bare `>` would let a Branch Manager mint one.*

**The ids are `b_Code` CodeIds, not a rank.** They only *look* ordered. `targetLevel > BranchManager` alone
would have made 126 assignable by everyone — a privilege escalation that reads as correct code. Whenever you
compare identifiers as if they were a scale, check the outliers.

Two more properties of the same `switch`:

- **`_ => false`** — the default is refusal. A level the switch does not know assigns nothing.
- **An actor below Branch Manager gets an empty option list**, and `ValidateAsync` refuses on the write path
  too. Legacy bound no dropdown for them, which is a privilege guard rather than a rendering shortcut.
  **Never treat an empty options list as a UI detail** — reproduce it as a rule.

### 6.6 The service

825 lines. Same conventions as everywhere else; three things are specific to writing users.

#### `ValidateAsync` — thirteen checks, in legacy's order

```csharp
login not blank                              → "Enter Login Name."
length within b_LoginPolicy min/max          → "User name length does not match with login policy."
login name free (excluding self)             → "This Login Name is already exist."
branch exists                                → "Select Branch"
department belongs to that branch            → "Select Department"
employee exists                              → "Select Employee"
employee belongs to that branch              → "The selected employee does not belong to the selected branch."
employee.PassedBy is not null                → "The selected employee is not authorized. …"
employee has no user already (excluding self)→ "Employee already having his 'Login Name' and 'Password'"
CanAssignLevel(actorLevel, input.UserLevel)  → "You cannot create a user at this level." / "…not permitted…"
status is Active or Closed                   → "Select Status"
```

The username length rule reads `b_LoginPolicy` rather than hardcoding numbers — the same policy the login
screen enforces, so a user cannot be created with a name they could never type at login.

The employee-authorized check is a nice example of thinking one step past the screen:

```csharp
// Login checks h_Employee.PassedBy as well as a_User.PassedBy, so an unauthorized employee would
// yield a user that can never sign in. Refuse up front instead.
if (employee.PASSEDBY is null)
    return "The selected employee is not authorized. Authorize the employee record first.";
```

Nothing on this screen fails without it. The *login* screen fails, later, with a message nobody can trace
back to here.

`excludeUserId` runs through the duplicate checks, for §2.7's reason: without it, updating a user without
changing anything reports that their own login name is taken.

#### `SaveUserAsync` — one transaction, four writes, and a deliberate exception

```csharp
string? passwordError = null;   // declared outside the try so the catch can report why

await data.ExecuteInTransactionAsync(async uow =>
{
    await uow.Repository<A_USER>().InsertAsync(user, ct);                      // 1
    var newUserId = user.USERID!.Value;

    await uow.Repository<A_USERPOLICY>().InsertAsync(new A_USERPOLICY          // 2
        { USERID = (int)newUserId, LOGINATTEMPT = 0 }, ct);

    var applied = await auth.ApplyNewPasswordAsync(user, …, uow: uow, skipConnectedCheck: true);   // 3
    if (!applied.IsSuccess)
    {
        passwordError = applied.ErrorString;
        throw new PasswordRejectedException();     // ← rolls the whole thing back
    }

    await InsertLimitsAsync(uow, (int)newUserId, input.Limits, actorUserId, now, ct);              // 4
}, cancellationToken: ct);
```

The **throw is the point**. `ApplyNewPasswordAsync` returns a `Result`, and a `Result` cannot roll back a
transaction — only an exception can. So a policy rejection is converted into one, and the message is carried
out in a captured local because the exception itself is a bare marker type. Without that, a password
rejected for complexity would leave **a half-created user with no password** — one that exists, blocks its
login name, and cannot sign in.

This is the sanctioned exception to "services never throw": it throws *inside* its own transaction and
catches it before returning. The boundary still only ever sees a `Result`.

Three legacy defects fixed in this method, each recorded where it was fixed:

- **The `a_UserPolicy` insert is not optional.** Legacy never created one — 588 users on xnet have 444 policy
  rows — and the password path stamps `PasswordLastSet` with an *update*, which silently does nothing when
  the row is missing.
- **`PassedBy` is stamped with the creating administrator.** Login denies a user whose `PassedBy` is null and
  there is no user-authorisation screen in the menu, so a user created here could otherwise never sign in.
- **`LEVEL` and `USERLEVEL` are both written:**

```csharp
// Both columns carry the same b_Code CodeId: LEVEL is what legacy wrote, USERLEVEL is what
// MenuListService reads (LEVEL is a reserved word on Oracle). Writing one and not the
// other produces a user who either has no menu or no legacy identity.
LEVEL = input.UserLevel,
USERLEVEL = input.UserLevel,
```

And one piece of faithfulness that looks like a bug until you read the comment:

```csharp
// Legacy renders these two checkboxes but hardcodes both to 0 on save and on update, so
// the posted values have never had any effect. Kept faithful deliberately.
ISPASSWHILETRANSACTION = false,
ISSELFAUTHORISATIONALLOWED = false,
```

Two checkboxes that have never done anything. Changing that during a migration would be a behaviour change
disguised as a port — so they stay, with the reason written down.

#### Update, and the password that is not touched

```csharp
/// The password is touched ONLY when changePassword is set — legacy wrote the (never pre-filled)
/// password box on every update, which is a bug, not a feature. Changing the password also clears
/// the failed-login counter, as legacy's UpdateUserPolicy did.
```

Legacy wrote whatever was in a box it never pre-filled — so editing a user's *branch* silently reset their
password to blank-ish input. Here the checkbox gates it.

#### `WriteModLogAsync` and delete

`pr_a_SaveUserModLog` (two `INSERT … SELECT`s) is re-expressed as `WriteModLogAsync` — no procs, no raw SQL,
per the codebase rule. `DeleteUserAsync` snapshots the user and its limits into the log tables **first**,
then deletes limits → policy → user in one transaction. Children before parents; the archive before the
delete.

```csharp
catch (Exception ex) when (IsForeignKey(ex)) →
    "This user is referenced elsewhere and cannot be deleted."
```

**That guard is why most real users cannot be deleted at all** — they are referenced by history — and that is
correct. A bank's audit trail must not develop holes because somebody left. Closing the user (status 3) is
the real-world operation.

### 6.7 Service API

```csharp
SearchUsersAsync(…)                          → tokenized grid
LoadUserAsync(decimal userId, ct)            → UserEdit?
GetUserLevelsAsync(int actorUserId, ct)      → IReadOnlyList<UserLevelOption>
LoadLimitsAsync(decimal? userId, ct)         → every g_Currency row, left-joined to this user's limits
SearchBranchesAsync / SearchDepartmentsAsync / SearchEmployeesAsync
SaveUserAsync(UserInput input, int actorUserId, ct)
UpdateUserAsync(decimal userId, UserInput input, bool changePassword, int actorUserId, ct)
DeleteUserAsync(decimal userId, int actorUserId, ct)
```

`LoadLimitsAsync(null)` returns **all currencies unselected** — that is how the new-user grid is built. One
method for both cases, the null meaning "no user yet". `UserInput` is a record carrying the whole form
including `IReadOnlyList<UserLimitRow>`, so the service signature does not grow a parameter per field.

### 6.8 Gotchas

- **`USERID` is `decimal`.** Parse tokens with `decimal.TryParse`, never `int`.
- **Level ids are `b_Code` CodeIds, not ranks** — 126 (SysAdmin) sorts above 50/51. A bare `>` is a privilege
  escalation.
- **An empty level list is a guard, not a UI state.** It is enforced again on the write path.
- **Write `LEVEL` and `USERLEVEL` together**, or the user has a menu but no legacy identity (or the reverse).
- **`a_UserPolicy` must exist** before the password path runs, because that path *updates* it.
- **`PassedBy` must be stamped** or the user can never log in — there is no user-authorisation screen.
- **Never echo a password back** into a re-rendered form.
- **Most users cannot be deleted**, by design. Use status 3 (Closed).

## 7. Signature Image Upload (2 menu rows)

`/RetailBanking/Signature` (**998**) · table `b_Signature` · migration `0016` · legacy
`RetailBanking/b_Signature_V1.aspx` (125 KB). Menu **2788** was also moved off the `.aspx` (migration `0018`)
to a **placeholder** at `…/Signature/Authorize` — that screen is not built.

Attaches **photo** and **signature** images to an account, or in the locker variant (`?FormType=locker`) to a
locker issue. Two independent lanes on one screen; a save touches only the lane whose file was chosen.

The smallest screen here and the one with the most security in it per line. It is the batch's best worked
example of *serving user-supplied bytes safely*, and of why the screen key is not decoration.

### 7.1 Files

| Path | Role |
|---|---|
| [TflCbs.Modules.RetailBanking/SignatureService.cs](../TflCbs.Modules.RetailBanking/SignatureService.cs) | 311 lines |
| [.../Controllers/SignatureController.cs](../TflCbs.Modules.RetailBanking.Web/Areas/RetailBanking/Controllers/SignatureController.cs) | 324 lines, **three** screen keys |
| [.../Views/Signature/Index.cshtml](../TflCbs.Modules.RetailBanking.Web/Areas/RetailBanking/Views/Signature/Index.cshtml) | 156 lines — picker + two lanes |
| [.../Views/Signature/_SignatureLane.cshtml](../TflCbs.Modules.RetailBanking.Web/Areas/RetailBanking/Views/Signature/_SignatureLane.cshtml) | 90 lines — **one partial, rendered twice** |
| [.../Views/Signature/Authorize.cshtml](../TflCbs.Modules.RetailBanking.Web/Areas/RetailBanking/Views/Signature/Authorize.cshtml) | 22 lines — the placeholder |
| `Models/RetailBanking/SignatureForm.cs` | 74 lines, incl. `ImageTokens` |
| `ImageUploads` — in `SignatureController.cs` | Extension allowlist + `Sniff()` |

### 7.2 Three screen keys in one controller

```csharp
private const string ScreenKey      = "RetailBanking/Signature";
private const string ImageScreenKey = "RetailBanking/Signature/Image";      // token namespace only
private const string AuthScreenKey  = "RetailBanking/Signature/Authorize";  // menu 2788
```

Two different jobs, and both matter.

**`ImageScreenKey` is a token namespace, not a menu right.** No menu row points at it. It exists so an image
token cannot be spent as a record token, and vice versa. Different capability, different key — the same
design as §5.6's `DocScreenKey`.

**`AuthScreenKey` is a real menu right, and separating it prevented a live privilege leak.** On this
database **25 users hold the authorization right without the upload right**. Pointing menu 2788 at the
upload route would have added that route to their `AllowedUrls` and handed all 25 upload access.

That is the clearest example in the batch of why screen keys are not decoration: the cheap move (point the
second menu row at the screen that exists) silently widens access, and nothing fails to make you notice.

### 7.3 Serving an image safely

Legacy's `SignaturePreview.aspx` built `WHERE SignatureId = {querystring}` by string concatenation, applied
**no branch filter**, and served any id to anyone signed in. Three separate holes: SQL injection, horizontal
access, and enumeration.

```csharp
[HttpGet("image/{token}")]
public async Task<IActionResult> Image(string token, CancellationToken ct)
{
    if (!TryOpenRecord(token, out var idStr, screen: ImageScreenKey) || !int.TryParse(idStr, out var id))
        return NotFound();                                  // resolve, NOT consume — <img> re-requests
    var res = await signatures.GetImageAsync(id, OrgElementId, ct);   // service re-checks the branch
    if (res.Value is not { } image) return NotFound();       // missing and wrong-branch look identical
    var contentType = ImageUploads.Sniff(image.Bytes);       // sniff again on the way OUT
    if (contentType is null) return NotFound();
    Response.Headers.CacheControl = "no-store";
    return File(image.Bytes, contentType);
}
```

Five things to copy:

1. **Resolve, not consume.** A browser re-requests `<img src>` on every render, on back, on refresh. Consuming
   here would break the page for doing nothing wrong (`know-your-code` §1.6, mistake 1).
2. **The service re-checks the branch.** The token proves the server showed you this row; it is not
   permission (`know-your-code` §1.7). `GetImageAsync(id, OrgElementId, …)` is the access control.
3. **404 for both** missing and not-yours. Different responses would make the endpoint an id oracle.
4. **Sniff on the way out.** The upload path already validated the type — but stored bytes may predate that
   validation, and **the browser must never receive a content type derived from anything a user supplied.**
   `Sniff()` reads the magic bytes; unrecognised bytes are not served at all.
5. **`Cache-Control: no-store`.** A customer's signature should not persist in a shared branch
   workstation's disk cache.

Compare §5.6: that endpoint serves *arbitrary* documents and therefore always uses
`application/octet-stream` + attachment. This one serves *images* and may render them inline — but only
because `ImageUploads` gates the type on the way in **and** `Sniff()` re-derives it on the way out. Inline
rendering is earned by those two checks; it is not the default.

### 7.4 Limits come from bank variables, resolved in the controller

```csharp
private const int DefaultMaxKb = 100;     // SIGNATURE_IMAGE_SIZE
private const int DefaultMaxActive = 4;   // MAX_ACTIVE_SIGN_COUNT

private async Task<(int MaxKb, int MaxActive)> LimitsAsync(CancellationToken ct)
{
    var sizeVar  = await bankVars.GetBankVarAsync("SIGNATURE_IMAGE_SIZE", ct);
    var countVar = await bankVars.GetBankVarAsync("MAX_ACTIVE_SIGN_COUNT", ct);
    return (
        int.TryParse(sizeVar?.Trim(), out var kb) && kb > 0 ? kb : DefaultMaxKb,
        int.TryParse(countVar?.Trim(), out var n) && n > 0 ? n : DefaultMaxActive);
}
```

**Read in the controller, passed down as parameters.** `IBankVars` lives in the framework, and service
modules must not reference the framework — so `SaveAsync` takes `maxActive` as an argument rather than
looking it up. Same discipline as `userId`, `orgElementId` and `workingDate` everywhere else in this guide:
**the service is handed its context; it never fetches it.**

Both fallbacks are to the **default, never to "no limit"**. A blank or mistyped bank variable degrades to
100 KB and 4 active images, not to unbounded. And `ImageUploads` clamps the size again, so a bank variable
of `999999` cannot lift the ceiling.

Sizing is two-layered:

```csharp
[HttpPost("save")]
[RequestSizeLimit(ImageUploads.MaxKbCeiling * 1024L)]   // oversized body refused before buffering
public async Task<IActionResult> Save(SignatureForm form, string command, CancellationToken ct)
```

The framework ceiling bounds the **request** (refused before ASP.NET buffers it); the bank variable bounds
the **file** (a business rule the bank can tune). Neither can be raised past the other.

### 7.5 The controller — command dispatch and lanes

`command` selects everything:

```csharp
var isSignature = string.Equals(command, "saveSignature", StringComparison.OrdinalIgnoreCase);
var kind = isSignature ? ImageKind.Signature : ImageKind.Photo;
var file = isSignature ? form.SignatureFile : form.PhotoFile;
var keep = isSignature ? form.KeepSignatureIds : form.KeepPhotoIds;
```

Four parallel selections from one string, then a single code path. The alternative — two near-identical
actions — would have been two places to fix every future bug.

Then the target, which is how one service serves both lanes:

```csharp
var target = form.IsLockerMode || form.LockerIssueId > 0
    ? SignatureService.SignatureTarget.ForLocker(form.LockerIssueId)
    : SignatureService.SignatureTarget.ForAccount(form.AccountId);
```

**Both conditions are checked**, because the mode can arrive either as `?FormType=locker` or as a non-zero
locker id on a re-render. Checking one would drop the other case.

`SignatureTarget` is a `readonly record struct` with two factories and two computed properties
(`IsLocker`, `IsValid`). It makes "an account **or** a locker issue, never both, never neither" a **type**
rather than a convention two nullable parameters hope everyone honours.

### 7.6 The views — one partial, rendered twice

`Index.cshtml` renders the account picker and then the same partial twice, once per lane. `_SignatureLane`
is 90 lines and carries five decisions worth reading.

#### Each lane is its own `<form>`

```razor
@* One lane (Photo or Signature). Its own multipart POST: a save touches only this lane, so the other
   lane's checkboxes are never submitted and never re-evaluated. *@
<form method="post" enctype="multipart/form-data" asp-action="@nameof(SignatureController.Save)">
```

If both lanes shared a form, saving a photo would post the signature lane's checkboxes too — and any
unticked signature would be deactivated as a side effect of an unrelated save. Separate forms make that
impossible rather than merely unlikely.

The hidden inputs re-carry the target (`AccountId`, `AccountHeadId`, `LockerIssueId`, `IsLockerMode`), since
each form posts alone.

#### `asp-action`, not a hand-written `action=""`

```razor
@* asp-action, not a hand-written action="": the form tag helper is what injects the antiforgery
   token, and without it every save is rejected with 400 before the action runs. *@
```

Worth memorising. The tag helper's side effect *is* the antiforgery token. A literal `action="/…"` looks
identical and fails every POST with a 400 that never reaches your code.

#### Checkboxes: absence means deactivate

```razor
@* Unticking and saving this lane deactivates the row. Ids not posted are
   treated as unticked, which is exactly the legacy grid's behaviour. *@
<input type="checkbox" name="@Model.KeepField" value="@row.SignatureId" checked="@row.IsActive" />
```

Unticked checkboxes **post nothing** — so the server sees a keep-list containing only the ticked ids, and
everything absent from it is deactivated. That is why the lanes must be separate forms: "absent" has to mean
"you unticked it", not "you were on the other lane".

#### The image is a link to itself

```razor
var src = Url.Action(nameof(SignatureController.Image), new { token = form.ImageTokens[row.SignatureId] });
<a href="@src" target="_blank" rel="noopener"><img src="@src" height="90" /></a>
```

Thumbnail and full view from one URL, with no separate preview page — legacy's `SignaturePreview.aspx`
disappears entirely. `form.ImageTokens` is a dictionary the controller pre-mints, one token per row, so **no
id ever appears in markup.** `rel="noopener"` is the standard guard on any `target="_blank"`.

#### The cap is explained where it bites

```razor
@if (Model.AtCap)
{
    <p class="hint">This account already has @form.MaxActive active … images.
       Untick one and save before uploading another.</p>
}
```

Not "error: limit reached" after a failed upload — the instruction, before the attempt, saying exactly what
to do.

### 7.7 The service

311 lines. Two internals carry the whole design.

#### One branch gate, and everything passes through it

```csharp
/// The account a target resolves to, ONLY if it is in the caller's branch; null otherwise. This
/// is the single branch gate every public method above passes through, which is why none of them read
/// b_Signature before calling it.
private async Task<int?> ResolveAccountIdAsync(SignatureTarget target, int orgElementId, CancellationToken ct)
```

A locker issue resolves to its account; an account is itself; then one query checks `ORGELEMENTID`. **Every
public method calls this before touching `b_Signature`.** One gate is auditable — you can prove the branch
check cannot be skipped by reading one method. Four copies of the check are four chances to forget one.

#### `LoadLaneAsync` returns projections — and that dictates how you write

```csharp
/// Every b_Signature row for one target in one lane, WITHOUT the image bytes — a grid of rows must not
/// pull a blob per row through the service when the browser fetches each image by URL.
/// The projection is also why callers must never write one of these rows back whole.
```

The consequence shows up in `SaveAsync`, and it is the sharpest gotcha in this section:

```csharp
// Set-based, one column list, never a whole-entity UpdateAsync: the rows loaded above are
// PROJECTIONS (no SIGNATURE column — see LoadLaneAsync), and writing one back in full would
// put NULL over the image bytes. Bounded by the active cap, so this is a handful of statements at most.
foreach (var id in toDeactivate)
{
    await uow.Repository<B_SIGNATURE>().UpdateWhereAsync(
        s => s.SIGNATUREID == id,
        [(s => s.ISACTIVE, false), (s => s.LASTMODIFIEDBY, userId), (s => s.LASTMODIFIEDON, workingDate)], ct);
}
```

`UpdateAsync(row)` rewrites **every** column (§1.6, §2.7). A projected entity has `SIGNATURE = null`, so a
whole-entity update would blank the image while "deactivating" it — silent, irreversible data loss that
looks like a successful save.

`UpdateWhereAsync` with an explicit column list is the answer: it writes only the three columns named.
**Load-then-mutate is safe on a full entity; on a projection you must write set-based.** The loop is bounded
by the active cap (4), so it is a handful of statements, not an N+1.

#### `SaveAsync` in order

```csharp
target.IsValid                     → "Select an account." / "Select a locker number."
bytes non-empty                    → "Please select a valid image file."
ResolveAccountIdAsync == null      → "The selected record is not available in this branch."
active count >= cap                → "You cannot have more than {cap} active photos/signatures."
                                     (cap = maxActive > 0 ? maxActive : 1 — never unbounded)
── one transaction ──
insert the new row (ISACTIVE = true, ISSIGNATURE = kind == Signature)
deactivate the active rows not in keepActiveIds
```

**Old images are deactivated, never deleted.** A signature is evidence: what the customer's signature looked
like in 2019 still matters when a 2019 cheque is disputed. `ISACTIVE = false` retires it without destroying
it — and it is why the cap counts active rows only.

`var lane = kind == ImageKind.Signature ? "signatures" : "photos";` is computed once so the cap message names
the right lane.

### 7.8 The placeholder (menu 2788)

```csharp
[HttpGet("Authorize")]
[CbsAccessScreen(AuthScreenKey)]
public IActionResult Authorize() => View();
```

Three lines and a 22-line view saying the screen is not built.

Why bother: menu 2788 had to leave the legacy `.aspx` with the rest of the batch. Its options were 404 (a
broken menu entry) or the upload route (§7.2's privilege leak). A placeholder is the third: **the route
exists, the right is separate, and the migration is complete.**

When the real screen is built it replaces this action and needs **no menu change**.
`pr_x_SB_getUnpassedSignature_V1` is its search — unpassed + active + the account's `MAX(SignatureId)`,
branch-scoped, maker ≠ checker — and `PassedBy` is what it stamps.

### 7.9 Gotchas

- **Never `UpdateAsync` a projected entity.** `LoadLaneAsync` omits the blob; a whole-entity write nulls it.
  Use `UpdateWhereAsync` with an explicit column list.
- **Uploads stay unpassed.** There is no `x_Scroll` row for this screen at all — `PassedBy` on `b_Signature`
  is the maker-checker column. Ten existing rows are already in that state, so nothing downstream filters
  on it.
- **The locker lane is selected by `?FormType=locker` *or* a non-zero `LockerIssueId`** — check both.
- **Each lane needs its own form.** Sharing one lets a photo save deactivate signatures.
- **`asp-action`, never a literal `action=""`** — the tag helper injects the antiforgery token.
- **Sniff on the way out**, not just on the way in. Stored bytes can predate the upload gate.
- **`SignatureTarget` is a struct with factories** so "account XOR locker" is a type, not a convention.

---

## Still open

**0.1 — the transaction posting engine.** Legacy posts through `pr_x_transaction` (164 KB) and
`pr_x_passTransaction` (119 KB). Eight guard sites wait on it, all findable with `grep NOTIMPL-POSTING`:
`DirectCreditService.AuthorizeAsync` (the whole method) and `DormantReactivationService.AuthorizeAsync`
(charge recovery, held charges, inter-branch legs, UTN allocation).


