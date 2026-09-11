# Switching the migration source to the xnet legacy variant — impact analysis

**Date:** 2026-09-04
**Question:** if we re-base the .NET 10 migration on the **xnet** legacy codebase instead of the existing one, what does it cost us at the level of the **framework, shared UI components, architecture and reusable parts** — what are we missing, and what have we built that is no longer required?

**Scope:** platform-level only. Individual screens are out of scope by design; the screen inventory is small today (24 controllers / 39 views) and is not what makes this decision.

---

## 1. Executive summary

The two legacy trees are **sibling forks of one product, not two versions of it**. They share the same four VB/WebForms projects, the same master page, the same theme set, the same user-control library and the same core administration schema — but only ~32% of source files are common by path, and of the stored procedures only ~23% share a name.

For our .NET 10 platform that splits cleanly three ways:

| Verdict | Weight | What it covers |
|---|---|---|
| **Carries over unchanged** | ~80% of the framework | The whole architecture: framework⊥screens split, modular monolith, `TflCbs.Abstractions` ports, `Result<T>`, `ServiceQuery`/`DbErrors`, `RowToken`, arch tests, host composition, `Modules:Enabled` gating, thin hosts, gateway, Docker/IIS deploy, session model, route-cutover-in-`a_Menus`, record/search/date pickers, VAPT field encryption, notification model |
| **Must be reworked** | 6 concrete framework items | Menu authorization (role- not user-based), admin discriminator, bank-variable shape, broadcast source, account-identity model, multi-currency |
| **No longer required** | 5 projects + ~2,650 entities | The entire MFA stack, OTP/forgot-password, Lockers vertical, India payment-rail and statutory scaffolding, India-only org/user columns |

**The switch is cheap now and gets expensive fast.** Almost all the cost is framework + entity regeneration, not screens — and the framework items are exactly the ones every future screen will build on. If the switch is going to happen, it should happen before the next wave of screens.

**Recommendation:** treat xnet as a **second target of the same framework**, not a replacement. Nothing in the architecture is invalidated by it; six framework seams need to become variant-aware, and one code generation step (entities) needs re-pointing. Hard-forking the solution would throw away work that both variants need.

---

## 2. Method

All findings below are reproducible.

- **Codebase:** file-list `comm` diffs (case-insensitive, excluding `obj/`, `bin/`, binaries) and `stat`-size comparison of common files, over
  `E:\adtemp\_del_now\20260606_cbs_source_code\` (existing) and `E:\adtemp\_del_now\20260904_cbs_source_code_xnet\` (xnet).
- **Database:** live `sqlcmd` against `192.168.0.13\SQLSERVER_2024 / Trustbank_XNETT_ORCL` (credentials per `docs/xnet-legacy-codebase.txt`), read-only catalogue queries against `sys.tables` / `sys.columns` / `sys.procedures` plus `a_Menus` / `a_Module`.
- **Our side:** `TableName = "…"` and `Repository<T>` extraction across `TflCbs.Entities`, `TflCbs.Modules.General`, `TflCbs.Core.Authentication`, `TflCbs.Framework`.

> One discrepancy worth recording: `docs/xnet-legacy-codebase.txt` names `Trustbank_XNETT_ORCL`, and that is the database the procedure dump and this analysis came from. The application's own `Web.Config` points at **`Trustbank_XNETT_DEV`** with different credentials. Confirm which is authoritative before anyone codes against it.

---

## 3. What the xnet variant is

| | 20260606 (current source) | 20260904 xnet |
|---|---|---|
| Market | India | Africa / international |
| Regulator artefacts | RBI returns, CKYC, AADHAAR | **CBL** (Central Bank of Lesotho) templates — daily/weekly/monthly/quarterly/semi-annual/annual/as-and-when |
| Payment rails | SFMS NEFT/RTGS, CTS, IFTAS, ATM, ECS/e-Mandate | **PAPSS**, **SWIFT MT103**, **MTS**, **LRA ePay**, **Orange Money wallet**, Inlaks account mapping |
| Extra domains | PACS, Customer360, ServiceBranch, EmployeeDemand, CCPC Clearing, AgriLoan | **Treasury/FX**, **Trade Finance (LC + BG)**, **MultiCurrency**, Internet Banking, TDBG |
| Product model | conventional | conventional **+ Islamic** (93 source files; `ucEmiChart_Islamic.ascx`, `_x_LoanSettlement_Islamic_*`) |
| Deployment fingerprint | `DBSRV1\TSSIPL2016`, `Trustbank_Urban_SingleDB` | `192.168.0.13\SQLSERVER_2024`; `Web.Config.bak` also carries `Trustbank_Sudan_Master` |

Both trees carry edits into September 2026. Neither is a snapshot of the other.

---

## 4. Codebase comparison

### 4.1 Volume

| Measure | 20260606 | xnet |
|---|---:|---:|
| Files (all) | 15,033 | 12,514 |
| Source files (excl. `obj`/`bin`/binaries) | 13,483 | 10,935 |
| Common source paths (case-insensitive) | **4,278** shared | |
| …of which **content differs** | **892** | 489 `.vb`, 182 `.aspx`, 15 `.js`, 11 `.ascx` |
| Source only in that tree | 9,205 | 6,657 |
| `.rpt` (Crystal) only in that tree | 930 | 166 |

So roughly one third of files exist in both, and one fifth of *those* have diverged. This is a fork, and it has been diverging for years.

### 4.2 Structure — what is identical

These are the parts our platform was reverse-engineered from, and they survive the switch:

- **`MasterPages/Base.master`** — same guard model (`IsLoginRequired`, `IsDayBeginRequired`, `IsModuleRequired`, `IsFinancialYearRequired`, `IsDayEndLogSubmissionCheckRequired`, `PageCaption`, `SearchBox*`, `ConnectionStringName`, `IsUseStoredProcedure`). This is the model `CbsAccessMiddleware` and `CbsScreenController` implement, and it is unchanged.
- **`App_Themes`** — identical set (`Bank_Theme2`, `bank_theme1`).
- **`App_Code`** — same shape, small delta (xnet adds `AutoRecovery.vb`, `ChargesTagConfiguration.vb`, `DailyAccureTheme.vb`; drops `IFTASFunctions.vb`, `ImpersonateUser.vb`, `Json.vb`, `Transaction.vb`).
- **User-control library** — the reusable controls we ported all exist in xnet: `RecordSelector` / `TssiplRecordSelector` / `TssiplRecordSelectorV2`, `TssiplSearchBox`, `TssiplDatePicker`, `ActionButtons`, `AdTabControl`, `CollapsablePanel*`, `Alerts`, `MainMenu`, `PasswordPolicy`, `AdReportParameters`, `ucEmiChart`, `ClientAccountsInfo`, `DDPO`.
- **Login contract** — xnet's `Login.aspx.vb` builds the same `<loginInfo>` XML blob from `Request.ServerVariables`, so the `<REMOTE_HOST>` element our `LoginInfo` parser depends on is present and unchanged.

### 4.3 Structure — what differs

**Reusable controls that exist only in xnet** (i.e. gaps in our shared component set):

| Control | What it is | Our counterpart |
|---|---|---|
| `TssiplMoneyControl.ascx` | Currency-aware money input with spinner, disabled-state handling | **none** |
| `AccountParamInfo.ascx` | Account identity header: Account No, **Old A/c No.**, **NUBAN**, **Old NUBAN** | **none** (we render account no only) |
| `TransactionViewer.ascx` | Embeddable transaction viewer | **none** |
| `SecurityInfo.ascx` | Loan security summary | **none** |
| `ucEmiChart_Islamic.ascx` | Islamic profit schedule alongside conventional EMI | **none** |

**Base master extras in xnet:** `IsSubHeadRequired`, `IsMenuStyleSwitcherRequired`, `IsModuleBreadcrumbRequired` — three shell features (per-user menu style, module breadcrumb, sub-header) with no equivalent in `_Layout.cshtml` / `_MenuOverlay.cshtml`. Backed by `a_User.MenuStyle` and `pr_a_UpdateMenuStyle`.

**Base master properties that xnet drops:** `AccountNumberLength`, `BranchCodeLength`, `BranchHeadCodeLength`, `HeadCodeLength`. This is significant — see §6.4.

### 4.4 Binary dependencies

| Only in 20260606 (35 assemblies) | Only in xnet (12 assemblies) |
|---|---|
| `tssipl_mfa_otp`, `tssipl_mfa_ad_client`, `tssipl_mfa_qr_client` | `tssipl_api_papss_client_lib`, `tssipl_api_swift_client_lib`, `tfl_api_ibll_swift_aeg_client` |
| `Tssipl.PaymentAdapter.*` (11 assemblies: SFMS, NEFT, RTGS, Swift, ISO20022, PapssISO20022, MQManager) | `tssipl_api_mts_client_lib`, `tfl_api_lra_epay_client_lib`, `tssipl_api_omwallet_client_lib` |
| `TrustBank.CTS.YBL`, `Tssipl.Bank.IFTASCaller`, `TssOds`, `XbrlSymmEncrypt` | `tfl_api_ibll_acmap_inlaks_client_lib`, `tssipl_meta_tfs_lib` |
| `EPPlus`, `ClosedXML`, `Spire.XLS`, `Spire.Pdf`, `PdfiumViewer`, `QRCoder`, `JWT` | `Ad.Docx.Core`, `Ad.Docx.Template` |
| `TssiplCBSHttpModule`, `TrustBank.ProcessManager.*` | |

Two things to read out of this table:

1. **xnet has no MFA at all.** No `tssipl_mfa_*` assembly, zero source references to MFA/OTP/AD/QR (against 23 files in the current tree). Confirmed at the schema level too — see §5.3.
2. **xnet's integrations are thin HTTP API clients, not an in-process message adapter.** That is architecturally *closer* to where we are going, not further.

---

## 5. Database comparison

### 5.1 Headline

| Measure | `Trustbank_XNETT_ORCL` |
|---|---:|
| Tables (excl. `*_Backup` mirrors) | 2,059 |
| Stored procedures | 5,282 |
| Views / functions | 27 / 21 |
| Menus (`a_Menus`) — total / active / with URL | 1,103 / 813 / 736 |
| Roles / role-on-menu grants | 139 / 6,040 |
| Users | 588 |

Every core table carries `msrepl_tran_version` → the schema comes from a **replicated** source. *(Correction, measured 2026-09-05: on this dev copy nothing is actually published — 0 tables with `is_published`, and `sys.databases.is_published = 0`. The columns are residue. Whether the **production** xnet database publishes these tables is still open.)* Nearly every table also carries `_OldId` / `_OldOrgId` → this database is itself the product of an earlier data migration whose lineage is still modelled in the schema. Neither fact is represented anywhere in our stack today.

### 5.2 Stored procedures

Names normalised (lower-cased, `NNN_` prefixes stripped):

| | 20260606 dump | xnet dump |
|---|---:|---:|
| Scripted procedures | 5,282 | 5,241 |
| **Common names** | **1,235** | ~23% |
| Only in that tree | 4,047 | 4,006 |

469 of the xnet-only procedures are named for CBL / PAPSS / SWIFT / Treasury / FX / MultiCurrency / LRA / MTS. 20 procedures could not be scripted at all — they are **encrypted** in the source database (`_report.log`), including `pr_a_GetloadMenus` and `pr_a_ResponsibilityRightsToUserRights`, i.e. two of the menu/rights procedures. Those will have to be reconstructed from behaviour, exactly as was done for the current tree.

Our "no stored procedures for new master CRUD" rule means this number is mostly informational — but it does size the *reverse-engineering* effort for anything not pure CRUD.

### 5.3 Schema vs `TflCbs.Entities`

`TflCbs.Entities` holds **3,681 generated tables** from the India database.

| | Count |
|---|---:|
| Entity tables that **exist** in xnet | **1,022** |
| Entity tables **absent** from xnet | **2,659** |
| xnet tables with **no entity** | **1,037** |

Entities must be regenerated against the xnet database. That is a code-generation run, not hand work — but ~2,659 generated classes become dead and ~1,037 new ones appear.

### 5.4 Core platform tables — present / missing

Every table our **core** modules (`TflCbs.Modules.General`, `TflCbs.Core.Authentication`) actually read:

| Table | xnet | Consumer | Consequence |
|---|:--:|---|---|
| `a_Menus` | ✅ | MenuListService, route cutover | fine — `NavigateURL` present, migration `0004` applies |
| `a_Module`, `a_UserInModule` | ✅ | module chooser | fine |
| `a_User` | ✅ | everything | **column drift** — see §5.5 |
| `a_UserRights` | ✅ | rights | fine (extra `ModuleId`) |
| `g_BankVariables`, `g_BranchVariables` | ✅ | BankVars, ReferenceCache | **column drift** — see §5.5 |
| `g_OrgElement` | ✅ | branch list | drift (India-only columns absent) |
| `b_WorkingDate`, `b_DayEndParamLog` | ✅ | working date, day-end guard | fine |
| `g_BlockedProcesses` | ✅ | `IProcessBlockCheck` | fine |
| `x_Scroll` | ✅ | maker-checker `IScrollService` | fine (+2 slip-number columns) |
| `b_UserLogTime` | ✅ | session, already-connected gate | fine — **all 12 of our columns present** |
| `b_Code`, `sys_config` | ✅ | lookups | fine |
| `al_Alerts`, `al_ProcessedAlerts`, `al_UserAlertMappings` | ✅ | AlertService | fine |
| `g_State`, `g_District`, `g_Taluka` | ✅ | `TflCbs.Modules.Reference` | **fine — the whole Reference core module survives** |
| `a_UserMenu` | ❌ | **MenuListService (non-admin path)** | **blocking — see §6.1** |
| `b_MarqueeAlert` | ❌ | **BroadcastService / `IBroadcastSource`** | **blocking — see §6.3** |
| `a_BrLoginAccessTime` | ❌ | GeneralService login-window check | feature drops |
| `al_AlertsRights_` | ❌ | AlertService | renamed → `al_AlertsRights` (no trailing underscore) |
| `a_UserLoginType`, `mfa_otp` | ❌ | MfaOtpService, MfaQrService | MFA not applicable |
| `cbs_otp` | ❌ | ForgotPasswordService | OTP reset not applicable |
| `b_UserSwitchLogTime` | ❌ | ShellSessionService user-switch | feature drops |

### 5.5 Column drift on tables that do exist

| Table | Ours | xnet | Columns we have that xnet lacks | Notable xnet extras |
|---|---:|---:|---|---|
| `a_User` | 20 | 25 | **`USERLEVEL`**, `PASSEDBY`, `PASSEDON` | `Level`, `MenuStyle`, `EnquiryLevelId`, `PostingLevelId`, `isAllowOtherBrApproval`, `id`, `_OldId`, `_OldOrgId` |
| `g_BankVariables` | 18 | 11 | `TAG`, `SUBTAG`, `INPUTTYPE`, `LENGTH`, `LENGTHTYPE`, `CRITERIA`, `DEFAULTVALUES`, `DEPENDENCY`, `EXAMPLE`, `NOTES` | `_OldId`, `_OldOrgId` |
| `g_OrgElement` | 28 | 23 | `IFSCCODE`, `PAN`, `TAN`, `GSTN`, `GSTNSTATECODE`, `LBRCODE`, `BRANCHTYPE`, `ISCOMPUTERIZED` | `_OldId`, `_OldOrgId` |
| `a_UserRights` | 11 | 14 | `ISREPORT`, `USERRIGHTSCONSID` | `ModuleId`, `UserRightsPreAuthDetailsId` |
| `a_Menus` | 18 | 19 | `ISDLS` | `IsAllowOtherBrMenu` |
| `a_UserPolicy` | — | 7 | — | no `PASSWORDVERSION` / salt columns → migration `0001` must run |
| `b_UserLogTime`, `b_WorkingDate`, `x_Scroll` | — | — | **none** | `_OldId`, `_OldOrgId` |

### 5.6 Module and menu shape

`a_Module` rows with live menus in xnet:

| Module | Active menus | Our module |
|---|---:|---|
| Retail and Corporate Operations | 539 | `TflCbs.Modules.RetailBanking` ✅ |
| *(ModuleId 0 — unassigned)* | 298 | mostly Treasury / Trade Finance / Inventory / LOS screens |
| Central Administration | 122 | `Administration` + `HR` ✅ (HR menus live here, as in the current tree) |
| **Trade Finance** | 70 | **none** |
| Reconciliation | 24 | none |
| Inventory | 22 | none |
| Internet Banking | 17 | none |
| **Treasury** | 10 | **none** |
| Loan Origination System | 1 | none |
| **Lockers** *(module 11, inactive)* | **0** | `TflCbs.Modules.Lockers` ⚠️ |

Menu authorization is **role-based**: `a_Role` (139) → `a_RoleOnMenu` (6,040 grants) → `a_Menus`. There is no `a_UserMenu` image table and no procedure that builds one; the menu procedures are `pr_a_getRoleOnMenuPopulateMenus`, `pr_a_getUserRightsPopulateMenus`, `pr_a_GetModulesWiseRolesOnMenu`, `pr_a_getResponsibilityMenus`.

Cross-check against the screens we have already migrated (`DbMigrator` `0004`/`0008`): **7 of 11 have a live menu in xnet**; `config/b_MarqueeAlert.aspx`, `config/updateBlockedUser.aspx`, `HO/bank/g_Taluka.aspx` and `Lockers/k_LockerType.aspx` do not.

---

## 6. What we are missing

Six framework-level gaps. Nothing here breaks the architecture; each is a seam that has to stop assuming the India shape.

### 6.1 Menu authorization is role-based, not user-based — *blocking*

`MenuListService` reads the precomputed `A_USERMENU` image table for non-admin users. **That table does not exist in xnet.** Authorization there is `a_Role` → `a_RoleOnMenu` (6,040 grants across 139 roles).

This is not cosmetic: `CbsAccessMiddleware` is our fail-closed guard, and its allow-list comes from this query. Until it is reworked, **every non-admin user sees an empty menu and is denied every route**.

*Shape of the fix:* `IMenuSource` (in `TflCbs.Abstractions`) is already the right seam — it returns `MenuListRow`. Add a second implementation behind it that resolves via `a_RoleOnMenu`, selected by configuration. No caller changes.

### 6.2 The admin discriminator moved — *blocking*

`MenuListService` branches on `a_User.USERLEVEL == 126`. xnet's `a_User` has **`Level`**, not `USERLEVEL` (the India database carries both; the migration deliberately chose the non-reserved spelling to stay Oracle-safe). Ships with §6.1.

### 6.3 Broadcast has no source table

`BroadcastService` (behind `IBroadcastSource`) reads `b_MarqueeAlert`; xnet has no such table and zero `MarqueeAlert` references in source. The port already degrades to `FrameworkPortDefaults`, so this **fails soft** — but the marquee silently disappears. Either map it onto `al_Alerts`/`al_AlertLog` or accept the no-op.

### 6.4 Account identity: 3-segment is an India assumption

`AccountPickerModel` hardcodes `BranchLen = 4`, `HeadLen = 5`, `AccountLen = 8`, and `_AccountPicker` renders three typed segment boxes — a direct port of the legacy composite driven by `Base.master`'s `AccountNumberLength` / `BranchCodeLength` / `HeadCodeLength`.

**xnet has zero references to any of those three properties** (the current tree has 141). Instead it carries multiple identifiers per account — Account Number, **Old A/c No.**, **NUBAN**, **Old NUBAN** — surfaced by `AccountParamInfo.ascx`, and 100 source files touch IBAN/BBAN/NUBAN/BIC (against 9 in the current tree).

*Shape of the fix:* add an identity mode to `AccountPickerModel` (segmented vs single-key-plus-aliases) and keep the segment lengths configuration-driven rather than defaulted constants. **Additive with safe defaults** — the existing India behaviour stays the default, per our reusable-component rule.

### 6.5 Multi-currency is absent from the entire framework

`grep -ri currency` over `TflCbs.Framework` + `TflCbs.Web.Shared` returns **nothing relevant**. xnet has 364 source files touching currency/exchange-rate, a Currency Master, Currency GL Mapping, LC Currency GL Mapping, a `HO/MultiCurrency` area, Treasury/FX, and a dedicated `TssiplMoneyControl.ascx`.

This is the largest single gap, and it is genuinely framework-level, not screen-level: every amount field, every total, every posting line needs a currency and most need a base-currency counterpart. Retro-fitting it after another twenty screens are written costs several times what it costs now.

*Shape of the fix:* a `MoneyModel` + `_MoneyInput` reusable component (the `TssiplMoneyControl` counterpart) and a currency-resolution service on the framework side, plus a currency dimension on the account picker's result. Design it now even if it ships later.

### 6.6 Smaller gaps

| Gap | Impact |
|---|---|
| Shell: menu-style switcher, module breadcrumb, sub-header (`a_User.MenuStyle`, `pr_a_UpdateMenuStyle`) | three shell features absent from `_Layout` / `_MenuOverlay` |
| Islamic profit model (93 source files, `ucEmiChart_Islamic`) | any shared amortisation/EMI component needs a second mode |
| Reusable controls `TransactionViewer`, `SecurityInfo`, `AccountParamInfo` | three shared components with no counterpart |
| `msrepl_tran_version` on core tables | Residue on the dev copy (nothing published there), but `Repository<T>` writes and TflOmniDb's row-version handling must still be verified against the **production** publisher before any write goes near it |
| `a_BrLoginAccessTime` absent | branch login-time-window check drops |
| `al_AlertsRights_` → `al_AlertsRights` | one entity rename |
| Trade Finance (70 menus), Treasury (10), Internet Banking (17), Reconciliation (24), Inventory (22) | five domains with no module in the modular monolith — see §8 |

---

## 7. What we no longer need

### 7.1 The whole MFA stack — 5 projects

`libs/tssipl_mfa_otp_net`, `tssipl_mfa_ad_client_net`, `tssipl_mfa_ad_api_net`, `tssipl_mfa_qr_client_net`, `tssipl_mfa_qr_api_net`, plus `tssipl_mfa_{ad,qr}_tests_net`.

xnet has **no MFA assemblies, no MFA source references, and no `a_UserLoginType` / `mfa_otp` tables**. Downstream, this also retires:

- `MfaOtpService`, `MfaQrService` (`TflCbs.Core.Authentication`)
- `cbs-qr-login.js`, the QR login view
- `DbMigrator` migrations `0006_mfa_otp`, `0007_mfa_qr`
- the `net10.0-windows` Active Directory API deployable and its Linux-container isolation rationale
- the client/server wire-contract tests that "fail every login" if they drift

That is a meaningful maintenance burden gone — and it is the single biggest item in `BACKLOG-legacy-app-wide.md` §1.10.

**Do not delete it.** xnet's login is the *original, simpler* one (5.5 KB against 31 KB); MFA is a feature the India deployment gained. If xnet ever needs it, it is ours and it works. Park it, don't remove it.

### 7.2 OTP-based forgot-password

`ForgotPasswordService` depends on `cbs_otp` — absent. `sms_buffer` / `sms_template` do exist, so an SMS path remains possible; the OTP table would have to be created.

### 7.3 The Lockers vertical

xnet ships 4 locker pages (against 15) and `a_Module` row 11 "Lockers" is **inactive with zero menus**. `TflCbs.Modules.Lockers`, `TflCbs.Modules.Lockers.Web` and `TflCbs.Host.Lockers` have no reachable screens.

Its architectural value survives the switch — it is the Phase-B promotion template and the proof that a fully isolated vertical slice works — but as shipped functionality it is dead weight. Keep the projects as the reference implementation; drop `Lockers` from `Modules:Enabled` and from the deployed host set.

### 7.4 India payment rails and statutory scaffolding

The `Tssipl.PaymentAdapter.*` SFMS/NEFT/RTGS/ISO20022 stack, CTS/YBL, IFTAS, ATM, AADHAAR/CKYC, ECS e-Mandate and the RBI report family have no counterpart in xnet. We have not migrated these screens, so the cost is confined to:

- **2,659 of 3,681 generated entities** become dead on regeneration
- `TflCbs.Modules.Clearing` no longer exists (deleted 2026-09-10, uncalled CTS/CCPC sample) — xnet's inward/outward clearing starts from a fresh module
- `TflCbs.Modules.Accounts` needs re-verifying against a schema where only ~28% of tables carried over

### 7.5 India-only columns to drop from entities

`g_OrgElement`: `IFSCCODE`, `PAN`, `TAN`, `GSTN`, `GSTNSTATECODE`, `LBRCODE`, `BRANCHTYPE`, `ISCOMPUTERIZED`.
`a_User`: `PASSEDBY`, `PASSEDON`. `a_UserRights`: `ISREPORT`, `USERRIGHTSCONSID`. `a_Menus`: `ISDLS`.

These fall out of entity regeneration automatically; they are listed so that any service or view referencing them is found before the build breaks.

### 7.6 Four route-cutover entries

`config/b_MarqueeAlert.aspx`, `config/updateBlockedUser.aspx`, `HO/bank/g_Taluka.aspx`, `Lockers/k_LockerType.aspx` have no menu row in xnet — migrations `0004`/`0008` would update zero rows for them.

---

## 8. What is untouched — and why that matters most

Nothing in the following list changes, and it is the great majority of what has been built:

- **Architecture.** The horizontal framework⊥screens split and the vertical modular monolith both hold. `TflCbs.Abstractions` and its four ports (`IBroadcastSource`, `IBankVariableSource`, `IMenuSource`, `ISessionValidator`) are exactly the seams that absorb §6.1–6.3 — which is the strongest evidence available that the boundary was drawn in the right place. The arch tests, namespace discipline and `ArchBoundaries.PromotedModules` all still apply.
- **Composition and hosting.** `AddCbsModules`, the deployed-assembly cross-check, `Modules:Enabled` gating, thin hosts, the gateway, IIS and Docker single/multi shapes.
- **Data/business conventions.** `Result` / `Result<T>`, `Repository<T>` + `DataAccess.QueryAsync`, `ServiceQuery`, `DbErrors`, no-raw-SQL-for-new-CRUD.
- **Session and access.** `b_UserLogTime` carries all 12 columns we use; the `<REMOTE_HOST>` `LoginInfo` contract is byte-identical; the four-clock idle policy, `CbsSessionStore`, `CbsSessionOptions.Resolve`, `CbsAuthCookie` and `CbsAccessMiddleware`'s fail-closed model all stand. Only the *source* of the allow-list changes (§6.1).
- **Route cutover in the database.** `a_Menus.NavigateURL` exists; migration `0004`'s mechanism is unchanged.
- **Reusable components.** `_RecordPicker` / `RecordPickerModel` / `cbs-search.js` / `SearchDescriptor`, `_SearchModal`, `_DatePicker` / `cbs-datepicker.js`, `RowToken`, `_ActionBar`, `_Notification` (blocking-ack vs toast), `_CommandPalette`, `_ShortcutHelp`, `cbs-form-guard`, `cbs-uppercase`, `cbs-secure-post`, `cbs-idle`, `cbs-theme` — every legacy control they were ported from exists in xnet, with the same contract.
- **Field encryption.** xnet's `Web.Config` carries `vapt_donot_encrypt_record_selector_query_in_url`, so the VAPT URL/field-encryption concept is native there too — `_FieldEncryption` and `FieldEncryptionKeyStore` stand.
- **Reference core module.** `g_State` / `g_District` / `g_Taluka` all present. The admission rule (no domain behaviour + ≥2 consumers) is unaffected.
- **Observability, caching, health checks, data protection.** `IReferenceCache`, `DatabaseHealthCheck`, `TflOmniDbXmlRepository`, `RequestLoggingMiddleware`, OTel wiring — all schema-independent (`DataProtectionKeys` is created by us, not inherited).

---

## 9. Effort and risk

| Work item | Size | Risk | Note |
|---|---|---|---|
| Regenerate `TflCbs.Entities` against xnet | S | Low | code-gen run; 2,659 classes drop, 1,037 appear |
| Rework menu authorization to `a_RoleOnMenu` (§6.1, §6.2) | **M** | **High** | blocking; two encrypted procs to reverse-engineer |
| Bank-variable service against the 11-column shape (§5.5) | S | Med | our extra 10 columns disappear; simplification, but touches `ReferenceCache` |
| Broadcast: map or no-op (§6.3) | S | Low | port already degrades safely |
| Account identity mode on `_AccountPicker` (§6.4) | M | Med | must stay additive with safe defaults |
| **Multi-currency foundation (§6.5)** | **L** | **High** | cheapest now, compounding later |
| Shell extras: menu style, breadcrumb, sub-header (§6.6) | S | Low | |
| Verify writes under transactional replication (§5.1) | S | **High** | must be settled before production writes |
| Re-scope `Clearing` / `Accounts` to xnet schema | M | Med | |
| Retire MFA / OTP / Lockers from the enabled set | S | Low | park, don't delete |
| Confirm `_ORCL` vs `_DEV` database authority | XS | — | do this first |

**Screens are not on this list**, and that is the point: 24 controllers / 39 views is a week, not a quarter. The decision is about the framework, and the framework's cost is front-loaded.

---

## 10. Options

**A. Re-base on xnet (single target).** Point entities and all module services at the xnet schema; park MFA, OTP, Lockers and the India rails. Cleanest codebase; abandons the India variant, which is the tree with the larger active screen inventory.

**B. Keep the India target, treat xnet as a second deployment of the same framework. — *recommended*.** Make the six seams in §6 variant-aware behind the existing `TflCbs.Abstractions` ports; select the implementation by configuration. The ports already exist for exactly this. Cost is roughly A plus the configuration switching, and it keeps both markets on one platform — which is what a modular monolith is for.

**C. Fork the solution.** Rejected: 80% of the framework is common, and every future framework fix would need doing twice.

Under B, the sequence is: confirm the database → regenerate entities → menu authorization → account identity + multi-currency foundation → everything else.

---

## 11. Open questions

1. `Trustbank_XNETT_ORCL` or `Trustbank_XNETT_DEV` — which is authoritative? (`docs/xnet-legacy-codebase.txt` says one, `Web.Config` says the other.)
2. Is xnet a *replacement* target or an *additional* one? Option B assumes additional.
3. Is transactional replication also present in the target production database, or only in this dev copy?
4. Are Treasury, Trade Finance, Internet Banking, Reconciliation and Inventory in migration scope? Together that is ~143 active menus and five new modules.
5. Do the 20 encrypted procedures exist in unencrypted form anywhere — particularly `pr_a_GetloadMenus` and `pr_a_ResponsibilityRightsToUserRights`?
6. Is Islamic product support in scope, or conventional-only for the first release?
