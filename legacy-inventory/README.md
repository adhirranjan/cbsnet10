# TrustBank CBS — Legacy Screen Inventory

Every UI surface in the legacy WebForms application (692 screens), counted **module-wise** and **module × category**, with complexity derived from the code rather than the folder name.

> **Module means the menu's module.** A screen belongs to the module its `a_Menus` row points at (`a_Menus.MODULEID` → `a_Module.MODULENAME`) — **not** to the folder it sits in. The two disagree constantly: `~/ho/bank/g_State.aspx` lives in the `HO` folder but the menu files it under **Central Administration**. The folder tree gets its own census in §3.

> **Generated:** 2026-09-05 by [scripts/legacy-screen-inventory.py](../../scripts/legacy-screen-inventory.py) — re-run it to refresh; do not hand-edit.  
> **Source scanned:** `E:\adtemp\_del_now\20260904_cbs_source_code_xnet\Trust.Bank.Publish` (analysis only, never edited).  
> **Companion docs:** [state-like-screens.md](state-like-screens.md) (the 78 single-entity masters shaped like `/Hr/State` — the copy-and-swap backlog) · [migration-estimate/00-SUMMARY.md](../migration-estimate/00-SUMMARY.md) (commercial ROM estimate) · [migrated-vs-new.md](../migrated-vs-new.md) (cross-cutting ported/rebuilt/new ledger) · [reports.md](reports.md) (per-report .rpt → proc → menu inventory).  
> **Machine-readable:** `menus.tsv` · `screens.tsv` · `procs-by-screen.tsv` · `shared-procs.tsv` · [`TrustBank-Legacy-Inventory.html`](TrustBank-Legacy-Inventory.html) (filter + sort in the browser) · `TrustBank-Legacy-Inventory.xlsx`.

## 1. At a glance

| | Count |
| --- | ---: |
| Screens total (`.aspx` + `.ascx`) | **692** |
| Functional screens (non-report) | **640** |
| Reports | **52** |
| Modules (`a_Module`, as used by the menu) | 9 |
| Screens reachable from a menu entry | 421 |
| Screens with no `a_Menus` row | 271 |
| Screens exposed under more than one module | 10 |
| Top-level folders | 16 |
| Distinct stored procedures referenced | 2,155 |
| Lines of markup + code-behind | 1,370,345 |
| Screens with sibling `.js` / `.html` assets | 9 |
| **Migrated to .NET 10 so far** | **8** (1.2%) |
| **Remaining** | **684** |

## 2. Module-wise (from `a_Menus` → `a_Module`)

Screen count, size and migration status per **menu module**. A screen is placed by the module of its `a_Menus` row; where several rows in different modules point at the same page, the **lowest `MENUID`** — the original registration — wins, so every screen is counted exactly once and the column adds up to 692. The mirrors are not lost: §2.2 counts a screen in *every* module that exposes it.

### 2.1 Primary module — each screen counted once

| Module | Screens | Reports | Functional | Menu entries | Lines of code | Distinct procs | Migrated | Remaining |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Retail and Corporate Operations | 149 | 23 | 126 | 439 | 406,355 | 1,152 | 1 | 148 |
| (module 0 — not in a_Module) | 136 | 5 | 131 | 231 | 242,506 | 439 | 1 | 135 |
| Central Administration | 85 | 1 | 84 | 102 | 152,658 | 162 | 6 | 79 |
| Trade Finance | 19 | 2 | 17 | 55 | 56,221 | 104 |  | 19 |
| Reconcillation | 17 | 5 | 12 | 19 | 35,145 | 39 |  | 17 |
| Internet Banking | 10 | 1 | 9 | 13 | 12,470 | 41 |  | 10 |
| Inventory | 3 | 3 | 0 | 20 | 3,607 | 20 |  | 3 |
| Treasury | 1 | 1 | 0 | 9 | 1,112 | 9 |  | 1 |
| Loan Origination System | 1 | 0 | 1 | 1 | 1,213 | 4 |  | 1 |
| (not in menu) | 271 | 11 | 260 | 0 | 459,058 | 524 |  | 271 |
| **Total** | **692** | **52** | **640** | **889** | **1,370,345** | **2,155** | **8** | **684** |

`(not in menu)` is not a module: those are the 271 files in the tree that no `a_Menus` row points at — report bodies invoked by the report selector, popups and pickers opened from code, shared `.ascx` controls, handlers, and pages left behind after a menu entry was retired. They are real work in a migration but they are not screens a user can navigate to, which is exactly why the folder census in §3 is kept alongside this table.

### 2.2 Menu reach — a screen counted in every module that exposes it

10 screens sit in more than one module's menu (the **Head Office** tree, for instance, mirrors most of Retail Banking). This table double-counts them on purpose: it answers "how much does *this* module's menu put in front of a user", so the column sums past the screen total.

| Module | Screens reachable | of which shared with another module | Menu entries | Active entries |
| --- | ---: | ---: | ---: | ---: |
| Retail and Corporate Operations | 151 | 7 | 447 | 87 |
| (module 0 — not in a_Module) | 144 | 10 | 291 | 135 |
| Central Administration | 86 | 4 | 109 | 83 |
| Trade Finance | 21 | 2 | 95 | 21 |
| Reconcillation | 18 | 1 | 26 | 17 |
| Internet Banking | 11 | 1 | 20 | 11 |
| Inventory | 3 | 0 | 20 | 3 |
| Treasury | 1 | 0 | 9 | 1 |
| Loan Origination System | 1 | 0 | 1 | 1 |
| **Total** | **436** | **10** | | |

## 3. Folder-wise and sub-folder-wise

The same screens counted by where the **files** live. This is the axis to use when planning who touches which part of the tree; §2 is the axis to use when planning what a user loses or gains per module.

### 3.1 Top-level folders

| Folder | Sub-folders | Screens | Reports | Functional | Lines of code | Distinct procs | In a menu | Not in a menu |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `RetailBanking` | 25 | 322 | 1 | 321 | 740,757 | 986 | 205 | 117 |
| `HO` | 12 | 147 | 1 | 146 | 282,967 | 296 | 100 | 47 |
| `Reports` | 24 | 46 | 46 | 0 | 112,898 | 722 | 35 | 11 |
| `CBLTemplates` | 1 | 45 | 0 | 45 | 90,913 | 1 | 1 | 44 |
| `UserControls` | 1 | 24 | 0 | 24 | 18,630 | 21 | 0 | 24 |
| `Treasury` | 2 | 23 | 0 | 23 | 32,091 | 69 | 21 | 2 |
| `Inventory` | 1 | 16 | 3 | 13 | 21,504 | 35 | 16 | 0 |
| `Helpdesk` | 1 | 16 | 0 | 16 | 17,792 | 54 | 12 | 4 |
| `HR` | 1 | 16 | 0 | 16 | 9,300 | 11 | 16 | 0 |
| `Reconciliation` | 1 | 16 | 0 | 16 | 35,575 | 36 | 13 | 3 |
| `(root)` | 1 | 10 | 1 | 9 | 1,363 | 3 | 1 | 9 |
| `Lockers` | 1 | 4 | 0 | 4 | 4,551 | 9 | 0 | 4 |
| `Authentication` | 1 | 3 | 0 | 3 | 983 | 3 | 0 | 3 |
| `ajax` | 1 | 2 | 0 | 2 | 260 | 0 | 0 | 2 |
| `CustomerCare` | 1 | 1 | 0 | 1 | 547 | 0 | 0 | 1 |
| `config` | 1 | 1 | 0 | 1 | 214 | 1 | 1 | 0 |
| **Total** | **75** | **692** | **52** | **640** | **1,370,345** | **2,155** | **421** | **271** |

### 3.2 Every sub-folder

All 75 folder / sub-folder pairs. `—` is the folder's own root (files directly in it, not in a child folder). `Menu modules` names the modules whose menu reaches into that sub-folder — where it lists several, the folder is shared and cannot be migrated for one module alone.

| Folder | Sub-folder | Screens | Reports | Functional | Lines of code | In a menu | Menu modules |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| `RetailBanking` | — | 108 | 1 | 107 | 152,999 | 91 | (module 0 — not in a_Module), Central Administration, Loan Origination System … |
| `RetailBanking` | `Transaction` | 62 | 0 | 62 | 240,527 | 23 | (module 0 — not in a_Module), Retail and Corporate Operations |
| `RetailBanking` | `Account` | 54 | 0 | 54 | 172,830 | 12 | (module 0 — not in a_Module), Retail and Corporate Operations |
| `RetailBanking` | `PAPPS` | 10 | 0 | 10 | 12,646 | 9 | Retail and Corporate Operations |
| `RetailBanking` | `clearing` | 9 | 0 | 9 | 14,250 | 6 | (module 0 — not in a_Module), Retail and Corporate Operations |
| `RetailBanking` | `swift` | 9 | 0 | 9 | 8,302 | 9 | Central Administration, Retail and Corporate Operations |
| `RetailBanking` | `cash` | 8 | 0 | 8 | 13,069 | 8 | (module 0 — not in a_Module), Central Administration, Retail and Corporate Operations |
| `RetailBanking` | `TDBG` | 8 | 0 | 8 | 25,005 | 8 | Trade Finance |
| `RetailBanking` | `LC` | 6 | 0 | 6 | 25,709 | 6 | Trade Finance |
| `RetailBanking` | `Legal` | 6 | 0 | 6 | 8,145 | 6 | (module 0 — not in a_Module), Retail and Corporate Operations |
| `RetailBanking` | `npa` | 6 | 0 | 6 | 8,225 | 6 | Central Administration, Retail and Corporate Operations |
| `RetailBanking` | `Transaction/FdTransactions` | 5 | 0 | 5 | 11,054 | 1 | Retail and Corporate Operations |
| `RetailBanking` | `Utilities` | 5 | 0 | 5 | 1,040 | 4 | Retail and Corporate Operations |
| `RetailBanking` | `dormant` | 4 | 0 | 4 | 4,305 | 4 | Retail and Corporate Operations |
| `RetailBanking` | `MTS` | 4 | 0 | 4 | 18,288 | 1 | Retail and Corporate Operations |
| `RetailBanking` | `Alerts` | 3 | 0 | 3 | 777 | 1 | (module 0 — not in a_Module) |
| `RetailBanking` | `SI` | 3 | 0 | 3 | 5,661 | 2 | Retail and Corporate Operations |
| `RetailBanking` | `Transaction/userControls` | 3 | 0 | 3 | 2,375 | 0 | — |
| `RetailBanking` | `dd` | 2 | 0 | 2 | 1,055 | 2 | (module 0 — not in a_Module), Retail and Corporate Operations |
| `RetailBanking` | `Insurance` | 2 | 0 | 2 | 4,603 | 2 | Retail and Corporate Operations |
| `RetailBanking` | `ATM` | 1 | 0 | 1 | 2,685 | 1 | (module 0 — not in a_Module) |
| `RetailBanking` | `HPL` | 1 | 0 | 1 | 1,252 | 1 | (module 0 — not in a_Module) |
| `RetailBanking` | `Printing` | 1 | 0 | 1 | 1,424 | 0 | — |
| `RetailBanking` | `SMS` | 1 | 0 | 1 | 3,467 | 1 | (module 0 — not in a_Module) |
| `RetailBanking` | `YearEndActivities` | 1 | 0 | 1 | 1,064 | 1 | Retail and Corporate Operations |
| `HO` | `retailBanking` | 32 | 1 | 31 | 41,115 | 22 | (module 0 — not in a_Module), Central Administration, Retail and Corporate Operations |
| `HO` | — | 29 | 0 | 29 | 118,999 | 14 | (module 0 — not in a_Module), Central Administration, Retail and Corporate Operations |
| `HO` | `ProjectFormulation` | 29 | 0 | 29 | 69,140 | 21 | (module 0 — not in a_Module), Central Administration |
| `HO` | `bank` | 23 | 0 | 23 | 16,730 | 16 | (module 0 — not in a_Module), Central Administration |
| `HO` | `Admin` | 16 | 0 | 16 | 17,004 | 14 | Central Administration, Retail and Corporate Operations |
| `HO` | `Hr` | 5 | 0 | 5 | 7,674 | 4 | Central Administration |
| `HO` | `MultiCurrency` | 5 | 0 | 5 | 5,972 | 4 | (module 0 — not in a_Module), Central Administration |
| `HO` | `Alerts` | 3 | 0 | 3 | 1,347 | 2 | Central Administration |
| `HO` | `BG` | 2 | 0 | 2 | 1,035 | 2 | Trade Finance |
| `HO` | `ECS` | 1 | 0 | 1 | 2,140 | 0 | — |
| `HO` | `lc` | 1 | 0 | 1 | 879 | 1 | Trade Finance |
| `HO` | `retailBanking/ServiceTaxCalculation` | 1 | 0 | 1 | 932 | 0 | — |
| `Reports` | `RetailBanking` | 10 | 10 | 0 | 30,590 | 8 | (module 0 — not in a_Module), Retail and Corporate Operations, Trade Finance |
| `Reports` | — | 7 | 7 | 0 | 2,036 | 1 | (module 0 — not in a_Module), Central Administration, Internet Banking … |
| `Reports` | `Reconciliation` | 5 | 5 | 0 | 2,810 | 5 | Reconcillation |
| `Reports` | `ProjectFormulation` | 2 | 2 | 0 | 620 | 2 | (module 0 — not in a_Module) |
| `Reports` | `RBI Report` | 2 | 2 | 0 | 8,970 | 1 | (module 0 — not in a_Module), Retail and Corporate Operations |
| `Reports` | `RetailBanking/SeedReports` | 2 | 2 | 0 | 21,522 | 2 | Retail and Corporate Operations |
| `Reports` | `Admin` | 1 | 1 | 0 | 1,236 | 1 | Central Administration |
| `Reports` | `CBLReports` | 1 | 1 | 0 | 671 | 1 | Retail and Corporate Operations |
| `Reports` | `CBLReportsV1` | 1 | 1 | 0 | 1,228 | 1 | Retail and Corporate Operations |
| `Reports` | `HelpDesk` | 1 | 1 | 0 | 816 | 1 | Internet Banking |
| `Reports` | `RetailBanking/Account` | 1 | 1 | 0 | 2,337 | 1 | Retail and Corporate Operations |
| `Reports` | `RetailBanking/ATM` | 1 | 1 | 0 | 755 | 1 | Retail and Corporate Operations |
| `Reports` | `RetailBanking/Balancing` | 1 | 1 | 0 | 1,444 | 1 | Retail and Corporate Operations |
| `Reports` | `RetailBanking/CBLReportsV1` | 1 | 1 | 0 | 1,182 | 0 | — |
| `Reports` | `RetailBanking/Clearing` | 1 | 1 | 0 | 2,976 | 1 | Retail and Corporate Operations |
| `Reports` | `RetailBanking/Forex` | 1 | 1 | 0 | 607 | 1 | Retail and Corporate Operations |
| `Reports` | `RetailBanking/HeadOffice` | 1 | 1 | 0 | 3,557 | 1 | Retail and Corporate Operations |
| `Reports` | `RetailBanking/LC` | 1 | 1 | 0 | 1,839 | 1 | Trade Finance |
| `Reports` | `RetailBanking/loan` | 1 | 1 | 0 | 9,396 | 1 | Retail and Corporate Operations |
| `Reports` | `RetailBanking/New RetailBanking Report` | 1 | 1 | 0 | 12,963 | 1 | Retail and Corporate Operations |
| `Reports` | `RetailBanking/STR/Version2` | 1 | 1 | 0 | 1,479 | 0 | — |
| `Reports` | `RetailBanking/TDBG` | 1 | 1 | 0 | 1,754 | 1 | Trade Finance |
| `Reports` | `RetailBanking/Transaction` | 1 | 1 | 0 | 998 | 1 | Retail and Corporate Operations |
| `Reports` | `Treasury` | 1 | 1 | 0 | 1,112 | 1 | Treasury |
| `CBLTemplates` | — | 45 | 0 | 45 | 90,913 | 1 | (module 0 — not in a_Module), Retail and Corporate Operations |
| `UserControls` | — | 24 | 0 | 24 | 18,630 | 0 | — |
| `Treasury` | `Masters` | 13 | 0 | 13 | 10,492 | 12 | (module 0 — not in a_Module), Central Administration |
| `Treasury` | `FX` | 10 | 0 | 10 | 21,599 | 9 | (module 0 — not in a_Module) |
| `Inventory` | — | 16 | 3 | 13 | 21,504 | 16 | (module 0 — not in a_Module), Inventory, Retail and Corporate Operations |
| `Helpdesk` | — | 16 | 0 | 16 | 17,792 | 12 | (module 0 — not in a_Module), Internet Banking |
| `HR` | — | 16 | 0 | 16 | 9,300 | 16 | (module 0 — not in a_Module), Central Administration |
| `Reconciliation` | — | 16 | 0 | 16 | 35,575 | 13 | (module 0 — not in a_Module), Reconcillation |
| `(root)` | — | 10 | 1 | 9 | 1,363 | 1 | Retail and Corporate Operations |
| `Lockers` | — | 4 | 0 | 4 | 4,551 | 0 | — |
| `Authentication` | — | 3 | 0 | 3 | 983 | 0 | — |
| `ajax` | — | 2 | 0 | 2 | 260 | 0 | — |
| `CustomerCare` | — | 1 | 0 | 1 | 547 | 0 | — |
| `config` | — | 1 | 0 | 1 | 214 | 1 | Retail and Corporate Operations |

## 4. Module × category

Category is assigned from the screen's own evidence — controls present, whether the code-behind writes, which procedures it calls — with the first matching rule winning:

| Category | Assigned when |
| --- | --- |
| Report | Reports/StatutoryReports module, a ReportViewer/Crystal control, or `report`/`rpt` in the path |
| UserControl | a `.ascx` shared control |
| Handler / API / Ajax | `external_api`/`ajax`/`fp` module, `handler` in the name, or no server controls at all |
| Popup / Dialog | `popup`/`dialog` in the file name |
| Wizard / Multi-tab | `asp:Wizard` or a tab container (`MultiView` alone is the legacy list/edit toggle, not a wizard, so it does not count) |
| Transaction / Entry | posting/voucher/receipt/transfer/cheque path, a maker-checker name, or a writing form with no list |
| Batch / Process | day-end, EOD, batch, generation, closure or scroll in the name |
| CRUD master | has a grid **and** the code-behind writes — the classic list + insert/update/delete master |
| Search / List / Inquiry | has a grid, no writes — read-only listing or enquiry |
| Client-rendered / Other | almost no server controls — the UI is hand-written HTML/JS, so the control-based rules cannot see it. Listed explicitly rather than silently bucketed |

| Module | Report | UserControl | Handler / API / Ajax | Popup / Dialog | Wizard / Multi-tab | Transaction / Entry | Batch / Process | CRUD master | Search / List / Inquiry | Client-rendered / Other | Total |
| --- | ---:| ---:| ---:| ---:| ---:| ---:| ---:| ---:| ---:| ---:| ---:|
| Retail and Corporate Operations | 23 |  |  |  | 2 | 53 | 7 | 47 | 9 | 8 | **149** |
| (module 0 — not in a_Module) | 5 |  |  |  | 4 | 21 | 4 | 87 | 7 | 8 | **136** |
| Central Administration | 1 |  |  |  |  | 11 |  | 67 | 6 |  | **85** |
| Trade Finance | 2 |  |  |  | 2 | 2 |  | 13 |  |  | **19** |
| Reconcillation | 5 |  |  |  |  | 2 | 1 | 8 | 1 |  | **17** |
| Internet Banking | 1 |  |  |  |  | 2 |  | 6 | 1 |  | **10** |
| Inventory | 3 |  |  |  |  |  |  |  |  |  | **3** |
| Treasury | 1 |  |  |  |  |  |  |  |  |  | **1** |
| Loan Origination System |  |  |  |  |  |  |  | 1 |  |  | **1** |
| (not in menu) | 11 | 23 | 11 | 13 | 6 | 58 |  | 107 | 23 | 19 | **271** |
| **Total** | **52** | **23** | **11** | **13** | **14** | **149** | **12** | **336** | **47** | **35** | **692** |

## 5. Module × complexity

Complexity is scored from measurables — code-behind length, control count, distinct procedures called, grids, wizard, client assets — then banded on the population's quartiles: **Simple** < 4.0, **Medium** 4.0–12.0, **Complex** > 12.0. Reports are shown in their own band.

| Module | Simple | Medium | Complex | Report | Total |
| --- | ---:| ---:| ---:| ---:| ---:|
| Retail and Corporate Operations | 15 | 46 | 65 | 23 | **149** |
| (module 0 — not in a_Module) | 14 | 60 | 57 | 5 | **136** |
| Central Administration | 11 | 57 | 16 | 1 | **85** |
| Trade Finance |  | 4 | 13 | 2 | **19** |
| Reconcillation | 1 | 3 | 8 | 5 | **17** |
| Internet Banking |  | 7 | 2 | 1 | **10** |
| Inventory |  |  |  | 3 | **3** |
| Treasury |  |  |  | 1 | **1** |
| Loan Origination System |  | 1 |  |  | **1** |
| (not in menu) | 72 | 98 | 90 | 11 | **271** |
| **Total** | **113** | **276** | **251** | **52** | **692** |

`screens.tsv` also carries `LegacyBucket`, the folder-name-based bucket used by the June 2026 estimate (which was built against the India tree, not this one), so the two are comparable: **354 of 692 screens (51%) land in a different band once scored from the code.**

## 6. Biggest screens

The 20 highest-scoring screens — where the migration effort concentrates.

| Screen | Module | Folder | Category | Code lines | Controls | Procs | Score |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: |
| `HO/ChargesConfig.aspx` | Central Administration | `HO` | CRUD master | 60,240 | 1411 | 6 | 464.45 |
| `Reports/RetailBanking/ReportOptions.aspx` | Retail and Corporate Operations | `Reports` | Report | 25,134 | 702 | 197 | 282.13 |
| `Reports/RetailBanking/SeedReports/SeedReportOptions.aspx` | Retail and Corporate Operations | `Reports` | Report | 21,077 | 739 | 201 | 261.97 |
| `RetailBanking/Account/c_LoanV1.aspx` | (not in menu) | `RetailBanking` | Wizard / Multi-tab | 26,006 | 869 | 37 | 218.69 |
| `RetailBanking/Account/c_Loan.aspx` | Retail and Corporate Operations | `RetailBanking` | Wizard / Multi-tab | 25,231 | 837 | 36 | 213.98 |
| `Reports/RetailBanking/New RetailBanking Report/ReportSettings.aspx` | Retail and Corporate Operations | `Reports` | Report | 12,963 | 276 | 139 | 173.09 |
| `RetailBanking/Account/c_Loan_Islamic.aspx` | (not in menu) | `RetailBanking` | Wizard / Multi-tab | 19,023 | 696 | 26 | 159.07 |
| `HO/b_ClientV2.aspx` | Retail and Corporate Operations | `HO` | CRUD master | 18,358 | 702 | 14 | 140.43 |
| `RetailBanking/Transaction/x_BranchToBranchTransactionTrf_v1.aspx` | (not in menu) | `RetailBanking` | Transaction / Entry | 16,716 | 267 | 30 | 133.03 |
| `RetailBanking/Transaction/x_BranchToBranchTransactionTrf.aspx` | Retail and Corporate Operations | `RetailBanking` | Transaction / Entry | 16,676 | 267 | 29 | 132.16 |
| `HO/b_ClientCKYCR_V1.aspx` | (not in menu) | `HO` | CRUD master | 16,048 | 413 | 11 | 116.39 |
| `RetailBanking/Account/depositAccount.aspx` | Retail and Corporate Operations | `RetailBanking` | Transaction / Entry | 15,430 | 453 | 23 | 115.58 |
| `RetailBanking/Transaction/x_BranchToBranchTransactionCash_v1.aspx` | Retail and Corporate Operations | `RetailBanking` | Transaction / Entry | 14,806 | 206 | 24 | 115.37 |
| `RetailBanking/Account/DepositAccountv1.aspx` | (not in menu) | `RetailBanking` | Wizard / Multi-tab | 12,617 | 455 | 27 | 113.23 |
| `Reports/RetailBanking/loan/ReportOptions.aspx` | Retail and Corporate Operations | `Reports` | Report | 9,396 | 193 | 72 | 100.17 |
| `RetailBanking/Transaction/x_Transaction.aspx` | Retail and Corporate Operations | `RetailBanking` | Transaction / Entry | 12,428 | 229 | 20 | 97.9 |
| `RetailBanking/Transaction/x_BatchTransaction.aspx` | Retail and Corporate Operations | `RetailBanking` | Transaction / Entry | 13,992 | 110 | 0 | 96.23 |
| `HO/ProjectFormulation/p_Applicant.aspx` | (module 0 — not in a_Module) | `HO` | Wizard / Multi-tab | 10,852 | 527 | 13 | 96.13 |
| `RetailBanking/Transaction/x_TransferV2.aspx` | (module 0 — not in a_Module) | `RetailBanking` | Transaction / Entry | 11,633 | 277 | 23 | 95.84 |
| `HO/ProjectFormulation/p_LoanCase_v1.aspx` | (module 0 — not in a_Module) | `HO` | Wizard / Multi-tab | 10,748 | 421 | 27 | 95.62 |

## 7. Shared stored procedures

472 procedures are called by more than one screen. Each is a migration lever: convert it once and every calling screen moves closer. Full list in `shared-procs.tsv`; the top 20 by reach:

| Procedure | Screens | Modules |
| --- | ---: | --- |
| `pr_x_gettargetcurrencyvalue` | 51 | (module 0 — not in a_Module), (not in menu), Retail and Corporate Operations, Trade Finance |
| `pr_x_scrollsave` | 28 | (module 0 — not in a_Module), (not in menu), Central Administration, Retail and Corporate Operations … |
| `pr_x_getaccountdetails` | 25 | (module 0 — not in a_Module), (not in menu), Retail and Corporate Operations |
| `pr_x_calculationofservicetaxcommon` | 21 | (module 0 — not in a_Module), (not in menu), Central Administration, Retail and Corporate Operations |
| `pr_x_getnextuniquetranseqno` | 19 | (module 0 — not in a_Module), (not in menu), Central Administration, Retail and Corporate Operations |
| `pr_b_lockunlockaccount` | 18 | (module 0 — not in a_Module), (not in menu), Retail and Corporate Operations |
| `pr_x_getaccounts` | 18 | (module 0 — not in a_Module), (not in menu), Retail and Corporate Operations |
| `pr_x_transaction` | 17 | (module 0 — not in a_Module), (not in menu), Retail and Corporate Operations |
| `pr_re_getbankname` | 16 | (not in menu), Reconcillation, Retail and Corporate Operations |
| `pr_x_deletetransaction` | 16 | (module 0 — not in a_Module), (not in menu), Retail and Corporate Operations |
| `pr_x_getrsqdailydepositclientaccountnumber` | 16 | (module 0 — not in a_Module), (not in menu), Retail and Corporate Operations |
| `pr_re_getaccountnumberwithbalanceamount` | 15 | (not in menu), Reconcillation |
| `pr_g_getaccounthead` | 14 | (module 0 — not in a_Module), (not in menu), Central Administration, Retail and Corporate Operations |
| `pr_x_passtransaction` | 14 | (module 0 — not in a_Module), (not in menu), Retail and Corporate Operations |
| `pr_g_getcity` | 13 | (module 0 — not in a_Module), (not in menu), Loan Origination System, Retail and Corporate Operations |
| `pr_x_interbranchtransaction` | 13 | (module 0 — not in a_Module), (not in menu), Retail and Corporate Operations |
| `pr_b_getjointnames` | 12 | (module 0 — not in a_Module), (not in menu), Retail and Corporate Operations |
| `pr_b_isaccountlocked` | 12 | (module 0 — not in a_Module), (not in menu), Retail and Corporate Operations |
| `pr_x_getrsqdailydepositagentnumber` | 12 | (not in menu), Retail and Corporate Operations |
| `pr_x_getrsqtransactionaccountnumber` | 12 | (module 0 — not in a_Module), (not in menu), Retail and Corporate Operations |

## 8. Migration status

Read straight from the menu rows: `A_MENUS.NavigateURL` holds the new MVC route and `_NavigateURL_SQL` the pre-migration legacy value, so a row where the two differ is a cut-over screen. The database is the route map. **8 of 692 screens** have a new route today.

| Legacy screen | Module | Folder | Category | New route |
| --- | --- | --- | --- | --- |
| `HO/Admin/a_Menus.aspx` | Central Administration | `HO` | CRUD master | `/Administration/Menu` |
| `HO/Admin/a_Module.aspx` | Central Administration | `HO` | CRUD master | `/Administration/Module` |
| `HO/Admin/a_RoleMaster.aspx` | Central Administration | `HO` | CRUD master | `/Administration/Role` |
| `HO/bank/g_District.aspx` | Central Administration | `HO` | CRUD master | `/Hr/District` |
| `HO/bank/g_State.aspx` | Central Administration | `HO` | CRUD master | `/Hr/State` |
| `HR/h_DiscipActionHistory.aspx` | Central Administration | `HR` | CRUD master | `/Hr/DiscipActionHistory` |
| `RetailBanking/b_AccHoldingAmount.aspx` | (module 0 — not in a_Module) | `RetailBanking` | CRUD master | `/RetailBanking/AccHoldingAmount · /RetailBanking/AccHoldingAmount/Authorize` |
| `config/connectedUsers.aspx` | Retail and Corporate Operations | `config` | Search / List / Inquiry | `/Administration/ConnectedUsers` |

Screens rebuilt without a menu-route entry (login, menu, module chooser) are not counted here — the migration is the only machine-checkable source, and padding it by hand would defeat the point. Five screens we have built are **deliberately** absent, and [docs/xnet-menu-routes-cutover.sql](../xnet-menu-routes-cutover.sql) says why: `/Hr/Taluka`, `/Lockers/LockerType`, `/Administration/SystemNotification` and `/Administration/BlockedUsers` have no `a_Menus` row in xnet at all, and `/Bank/ReferenceCache` has no legacy counterpart — it is ours. The `RELEASE`/`RELEASEPASS` modes of `~/retailbanking/b_AccHoldingAmount.aspx` are also still legacy; only `ENTRY`/`ENTRYPASS` are migrated.

## 9. Caveats

- Category and complexity are **heuristics over static signals**, meant to size and route work, not to replace a screen-by-screen walkthrough in discovery.
- Module membership is read from `a_Menus` as it stands in the scanned database — the menu is live data, so a re-run after menu maintenance can move screens between modules. `menus.tsv` is the cache the report was built from (1,103 rows); `--refresh-menus` re-reads it.
- 81 of 970 menu rows whose `NAVIGATEURL` names an `.aspx`/`.ascx` point at a file that is **not in the scanned tree** — retired pages the menu row outlived, or pages published from a different tree. They add nothing to the counts here, but they are the first thing to check before declaring a module complete.
- Being in a menu is not the same as being reachable: 77 menued screens have no active (`ISACTIVE = 1`) entry, and role rights (`a_RoleOnMenu`) narrow it further — this scan does not model rights.
- Report bodies (RDL/Crystal definitions) are out of scope; only the `.aspx` hosting them is counted.
- Procedure references are the `pr_*` names appearing in the code-behind. Procedures reached indirectly (built at runtime, or via the compiled BLL) are invisible to a static scan, so `Distinct procs` is a floor.
