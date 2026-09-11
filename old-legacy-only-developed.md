# Built from the old legacy, absent in xnet

**Date:** 2026-09-07
**Question:** what have we already built in .NET 10 whose legacy counterpart exists in the **20260606** tree but **not** in the **xnet** tree?

This is the "if we re-base on xnet, what becomes orphaned" list, restricted to work that actually exists in the solution today. It is the concrete inventory behind [§7 of the xnet impact analysis](xnet-variant-impact-analysis.md) (2026-09-04), re-verified and extended with the batch-7 work that landed after that date.

> **Not the same as "wasted".** Almost every item here is *shipped and working* against the current target. It becomes dead weight only if xnet replaces the 20260606 tree rather than joining it. Nothing here should be deleted on the strength of this list.

## Method

- **Source:** case-insensitive `find` / `grep -ril` over `E:\adtemp\_del_now\20260606_cbs_source_code\Trust.Bank.Publish\` and `…\20260904_cbs_source_code_xnet\Trust.Bank.Publish\`.
- **Database:** the table/menu findings are carried from [xnet-variant-impact-analysis.md §5.4–5.6](xnet-variant-impact-analysis.md), which queried the live xnet catalogue.
- **Our side:** the legacy `.aspx` paths named in controller/service XML docs and in the `DbMigrator` route-cutover scripts, resolved back against both trees.

A screen counts as **old-only** when the page is absent from the xnet tree *and* has no `a_Menus` row there.

---

## 1. The list

| # | What we built | Legacy source (20260606) | xnet | Weight |
|---|---|---|:--:|---|
| 1 | **The whole MFA stack** — 9 `libs/tssipl_mfa_*_net` projects (OTP · Active Directory · QR, clients + 2 servers + 2 wire-contract test projects), `MfaOtpService`, `MfaQrService`, the QR login view + `cbs-qr-login.js`, migrations `0006_mfa_otp` / `0007_mfa_qr` | `login_otp_verify.aspx` (+`_handler`), `qrlogin_register.aspx`, `Authentication/qrlogin/`, `Bin/tssipl_mfa_otp.dll` | ❌ no MFA assemblies, **0** source references, no `a_UserLoginType` / `mfa_otp` tables | **2,629 LOC** + the `net10.0-windows` AD deployable |
| 2 | **OTP forgot-password** — `ForgotPasswordService` + its `AccountController` actions | `HO/Admin/ForgotPassword.aspx` | ❌ page absent, `cbs_otp` absent (`sms_buffer` / `sms_template` do exist, so an SMS path stays possible) | 1 service |
| 3 | **Broadcast / marquee** — the `IBroadcastSource` framework port, `BroadcastService`, `SystemNotificationController`, the marquee footer | `config/b_MarqueeAlert.aspx` | ❌ page absent (**0** refs), `b_MarqueeAlert` table absent, no menu row | 1 of the four framework ports |
| 4 | **Blocked users** — `BlockedUsersController` | `config/updateBlockedUser.aspx` | ❌ page absent, no menu row | 1 screen |
| 5 | **Taluka** — `TalukaController` on `TflCbs.Modules.Reference` | `HO/Bank/g_Taluka.aspx` | ❌ page absent, no menu row — **but the `g_Taluka` table exists**, so the entity and service survive; only the screen is orphaned | 1 screen |
| 6 | **The Lockers vertical** — `TflCbs.Modules.Lockers` + `.Web` + `TflCbs.Host.Lockers`, `LockerTypeController` | 25 locker pages incl. `Lockers/k_LockerType.aspx` | ❌ xnet ships **4** locker pages (Issue · Notation · Return · Visiting), no LockerType; `a_Module` row 11 "Lockers" is **inactive with 0 menus** | **987 LOC** + a thin host |
| 7 | **User-based menu authorization** — `MenuListService`'s non-admin path reads `a_UserMenu` | `a_UserMenu` image table + the proc that builds it | ❌ no `a_UserMenu`, no equivalent proc; xnet is **role-based** (`a_Role` → `a_RoleOnMenu`, 6,040 grants) | **blocking** — the access-control spine |
| 8 | **User-switch session tracking** — `ShellSessionService` writes `b_UserSwitchLogTime` | same table | ❌ absent | feature drops |
| 9 | **Branch login-window check** — `GeneralService` reads `a_BrLoginAccessTime` | same table | ❌ absent | feature drops |
| 10 | **External-module handoff** — `ModulesController`'s hand-off to an external module | `Authentication/external_module_handler.aspx` + `external_modules` | ❌ **0** refs | 1 endpoint (ours is deliberately *not* a port of the legacy protocol) |
| 11 | **The file-download endpoint** — `DownloadController` + `FileDownloads` | `download.aspx` + `FileExtRstrct.config` | ❌ neither present | 1 endpoint (again deliberately not a port — legacy took the path from the query string) |

## 2. Partial — the component survives, the legacy handler does not

| What we built | Old | xnet | Note |
|---|:--:|:--:|---|
| `_AccountPicker` / `AccountPickerModel` / `cbs-account-picker.js` | ✅ | ⚠️ | `js/lib-trustbank/recordselector/accountSelectorWin.html` is in **both**, so the picker's lineage and contract survive; only the server page `RetailBanking/Transaction/userControls/AccountSelector.aspx` is old-only |
| `AlertService` / `AlertsController` | ✅ | ✅ | `Alertviewer.aspx` and all three `al_*` tables exist in xnet (`al_AlertsRights_` is **renamed**, not absent). Only two alert *targets* — `EMIAlert.aspx`, `RetailBanking/Alerts/InvstMatAccAlert.aspx` — are old-only |

## 3. Entity columns our code names that xnet lacks

These break at compile time on entity regeneration, so they are listed to be found before the build finds them.

| Table | Columns |
|---|---|
| `a_User` | `USERLEVEL` *(used by the User Creation privilege filter)*, `PASSEDBY`, `PASSEDON` |
| `g_OrgElement` | `IFSCCODE`, `PAN`, `TAN`, `GSTN`, `GSTNSTATECODE`, `LBRCODE`, `BRANCHTYPE`, `ISCOMPUTERIZED` |
| `g_BankVariables` | `TAG`, `SUBTAG`, `INPUTTYPE`, `LENGTH`, `LENGTHTYPE`, `CRITERIA`, `DEFAULTVALUES`, `DEPENDENCY`, `EXAMPLE`, `NOTES` |
| `a_UserRights` | `ISREPORT`, `USERRIGHTSCONSID` |
| `a_Menus` | `ISDLS` |

## 4. What is deliberately **not** on this list

Checked and ruled out, because the reason each looks old-only turns out to be something else:

- **Bank/branch variables.** `g_BankVariables` / `g_BranchVariables` exist in xnet with column drift (§3). `BankVariableService`, `IBankVariableSource` and `IReferenceCache` stand.
- **The screens from batch 7 onward.** Signature, Direct Credit, Dormant Reactivation, Holding Amount, Denomination + Denomination Unit, Employer Master, Commission Rate, BG Currency GL Mapping are all **xnet-sourced** — several have no counterpart in the 20260606 tree at all. They are the opposite of this list.
- **Everything in §8 of the impact analysis** — architecture, composition, session/access, `Result<T>`, pickers, route cutover, observability. Schema-independent or present in both.
- **The three legacy user-control families** the reusable components were ported from (`RecordSelector` / `TssiplSearchBox` / `TssiplDatePicker`) — all present in xnet with the same contract.

## 5. Totals

| | Count |
|---|---:|
| Screens orphaned | **4** (Marquee alert · Blocked users · Taluka · Locker Type) |
| Services / endpoints orphaned | **6** (ForgotPassword · Broadcast · user-switch · login-window · external-module handoff · download) |
| Projects orphaned | **12** (9 MFA + Lockers module + Lockers RCL + Lockers host) |
| C# LOC orphaned | **~3,600** |
| Framework ports needing a new source | **1 of 4** (`IBroadcastSource`); a 2nd (`IMenuSource`) needs reworking, not replacing |

Set against ~56 projects, that is the shape the impact analysis predicted: the cost is concentrated in one optional security stack and one vertical slice, and the architecture is untouched.
