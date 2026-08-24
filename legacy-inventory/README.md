# TrustBank CBS — Legacy Screen Inventory

Every UI surface in the legacy WebForms application (1,477 screens), counted **module-wise** and **module × category**, with complexity derived from the code rather than the folder name.

> **Generated:** 2026-08-24 by [scripts/legacy-screen-inventory.py](../../scripts/legacy-screen-inventory.py) — re-run it to refresh; do not hand-edit.  
> **Source scanned:** `E:\adtemp\_del_now\20260606_cbs_source_code\Trust.Bank.Publish` (analysis only, never edited).  
> **Companion docs:** [migration-estimate/00-SUMMARY.md](../migration-estimate/00-SUMMARY.md) (commercial ROM estimate) · [migrated-vs-new.md](../migrated-vs-new.md) (cross-cutting ported/rebuilt/new ledger).  
> **Machine-readable:** `screens.tsv` · `procs-by-screen.tsv` · `shared-procs.tsv` · [`TrustBank-Legacy-Inventory.html`](TrustBank-Legacy-Inventory.html) (filter + sort in the browser) · `TrustBank-Legacy-Inventory.xlsx`.

## 1. At a glance

| | Count |
| --- | ---: |
| Screens total (`.aspx` + `.ascx`) | **1,477** |
| Functional screens (non-report) | **1,075** |
| Reports | **402** |
| Modules (top-level folders) | 20 |
| Distinct stored procedures referenced | 4,186 |
| Lines of markup + code-behind | 2,063,896 |
| Screens with sibling `.js` / `.html` assets | 92 |
| **Migrated to .NET 10 so far** | **8** (0.5%) |
| **Remaining** | **1,469** |

## 2. Module-wise

Screen count, size and migration status per top-level module.

| Module | Screens | Reports | Functional | Lines of code | Distinct procs | Migrated | Remaining |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| RetailBanking | 671 | 22 | 649 | 1,049,978 | 2,056 | 1 | 670 |
| Reports | 362 | 362 | 0 | 352,535 | 1,484 |  | 362 |
| HO | 203 | 5 | 198 | 360,657 | 426 | 5 | 198 |
| Reconciliation | 74 | 0 | 74 | 123,413 | 117 |  | 74 |
| Inventory | 23 | 4 | 19 | 64,786 | 72 |  | 23 |
| EmployeeDemand | 21 | 0 | 21 | 20,822 | 26 |  | 21 |
| Hr | 21 | 0 | 21 | 11,918 | 14 | 1 | 20 |
| Helpdesk | 21 | 2 | 19 | 26,261 | 47 |  | 21 |
| UserControls | 19 | 0 | 19 | 12,916 | 16 |  | 19 |
| Lockers | 15 | 0 | 15 | 28,492 | 64 | 1 | 14 |
| (root) | 13 | 1 | 12 | 1,933 | 6 |  | 13 |
| Config | 8 | 2 | 6 | 3,158 | 4 |  | 8 |
| Authentication | 7 | 0 | 7 | 1,248 | 4 |  | 7 |
| external_api | 5 | 0 | 5 | 1,043 | 0 |  | 5 |
| fp | 5 | 0 | 5 | 1,065 | 9 |  | 5 |
| StatutoryReports | 3 | 3 | 0 | 1,256 | 2 |  | 3 |
| ajax | 2 | 0 | 2 | 237 | 0 |  | 2 |
| Customer360 | 2 | 0 | 2 | 1,027 | 2 |  | 2 |
| CcpcClearing | 1 | 1 | 0 | 246 | 0 |  | 1 |
| ServiceBranch | 1 | 0 | 1 | 905 | 4 |  | 1 |
| **Total** | **1,477** | **402** | **1,075** | **2,063,896** | **4,186** | **8** | **1,469** |

## 3. Module × category

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
| RetailBanking | 22 | 4 | 6 | 31 | 10 | 178 | 17 | 278 | 83 | 42 | **671** |
| Reports | 362 |  |  |  |  |  |  |  |  |  | **362** |
| HO | 5 |  | 2 | 6 | 1 | 32 | 4 | 132 | 9 | 12 | **203** |
| Reconciliation |  |  |  | 3 |  | 14 | 2 | 50 | 4 | 1 | **74** |
| Inventory | 4 |  |  | 2 |  | 1 |  | 15 | 1 |  | **23** |
| EmployeeDemand |  |  |  |  |  | 4 |  | 16 | 1 |  | **21** |
| Hr |  |  |  |  |  | 3 |  | 13 | 4 | 1 | **21** |
| Helpdesk | 2 |  |  | 1 |  | 3 |  | 12 | 1 | 2 | **21** |
| UserControls |  | 15 |  |  |  |  |  | 2 |  | 2 | **19** |
| Lockers |  |  |  | 4 |  |  |  | 11 |  |  | **15** |
| (root) | 1 |  | 5 |  |  | 2 |  |  |  | 5 | **13** |
| Config | 2 |  |  | 1 |  |  |  | 3 | 1 | 1 | **8** |
| Authentication |  |  | 3 |  |  | 1 |  |  |  | 3 | **7** |
| external_api |  |  | 5 |  |  |  |  |  |  |  | **5** |
| fp |  |  | 5 |  |  |  |  |  |  |  | **5** |
| StatutoryReports | 3 |  |  |  |  |  |  |  |  |  | **3** |
| ajax |  |  | 2 |  |  |  |  |  |  |  | **2** |
| Customer360 |  |  |  |  |  |  |  |  | 1 | 1 | **2** |
| CcpcClearing | 1 |  |  |  |  |  |  |  |  |  | **1** |
| ServiceBranch |  |  |  |  |  |  |  | 1 |  |  | **1** |
| **Total** | **402** | **19** | **28** | **48** | **11** | **238** | **23** | **533** | **105** | **70** | **1477** |

## 4. Module × complexity

Complexity is scored from measurables — code-behind length, control count, distinct procedures called, grids, wizard, client assets — then banded on the population's quartiles: **Simple** < 4.0, **Medium** 4.0–12.0, **Complex** > 12.0. Reports are shown in their own band.

| Module | Simple | Medium | Complex | Report | Total |
| --- | ---:| ---:| ---:| ---:| ---:|
| RetailBanking | 145 | 282 | 222 | 22 | **671** |
| Reports |  |  |  | 362 | **362** |
| HO | 46 | 103 | 49 | 5 | **203** |
| Reconciliation | 7 | 38 | 29 |  | **74** |
| Inventory | 3 | 7 | 9 | 4 | **23** |
| EmployeeDemand | 1 | 14 | 6 |  | **21** |
| Hr | 9 | 11 | 1 |  | **21** |
| Helpdesk | 4 | 12 | 3 | 2 | **21** |
| UserControls | 10 | 6 | 3 |  | **19** |
| Lockers | 4 | 6 | 5 |  | **15** |
| (root) | 11 | 1 |  | 1 | **13** |
| Config | 5 | 1 |  | 2 | **8** |
| Authentication | 6 | 1 |  |  | **7** |
| external_api | 5 |  |  |  | **5** |
| fp | 3 | 2 |  |  | **5** |
| StatutoryReports |  |  |  | 3 | **3** |
| ajax | 2 |  |  |  | **2** |
| Customer360 | 1 | 1 |  |  | **2** |
| CcpcClearing |  |  |  | 1 | **1** |
| ServiceBranch |  | 1 |  |  | **1** |
| **Total** | **262** | **486** | **327** | **402** | **1477** |

`screens.tsv` also carries `LegacyBucket`, the folder-name-based bucket used by the June 2026 estimate, so the two are comparable: **600 of 1,477 screens (41%) land in a different band once scored from the code.**

## 5. Biggest screens

The 20 highest-scoring screens — where the migration effort concentrates.

| Screen | Module | Category | Code lines | Controls | Procs | Score |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| `RetailBanking/Account/c_Loan.aspx` | RetailBanking | Wizard / Multi-tab | 38,279 | 1133 | 54 | 319.39 |
| `Reports/RetailBanking/ReportOptions.aspx` | Reports | Report | 28,354 | 938 | 205 | 314.71 |
| `RetailBanking/Account/AgriLTMTLoan.aspx` | RetailBanking | Wizard / Multi-tab | 30,103 | 881 | 41 | 250.01 |
| `HO/b_ClientCKYCR_V3.aspx` | HO | CRUD master | 33,608 | 701 | 41 | 240.98 |
| `Reports/RetailBanking/New RetailBanking Report/ReportSettings.aspx` | Reports | Report | 19,899 | 448 | 172 | 237.07 |
| `HO/ProjectFormulation/p_SchemeDetailsV1.aspx` | HO | CRUD master | 23,524 | 348 | 16 | 176.95 |
| `HO/b_ClientCKYCR_V1.aspx` | HO | CRUD master | 22,979 | 544 | 23 | 168.2 |
| `HO/ProjectFormulation/p_SchemeDetails.aspx` | HO | CRUD master | 22,029 | 310 | 14 | 165.35 |
| `RetailBanking/Transaction/x_LoanFDSettlement.aspx` | RetailBanking | Transaction / Entry | 17,751 | 436 | 51 | 159.84 |
| `RetailBanking/Transaction/x_FDRAutoTransferTransaction.aspx` | RetailBanking | Transaction / Entry | 14,161 | 231 | 62 | 136.15 |
| `RetailBanking/Account/depositAccount.aspx` | RetailBanking | Wizard / Multi-tab | 15,610 | 507 | 28 | 131.85 |
| `RetailBanking/Transaction/x_FDRenewalTransaction.aspx` | RetailBanking | Transaction / Entry | 13,104 | 205 | 61 | 126.66 |
| `RetailBanking/Transaction/x_ManyToManyTransactionIBT_V1.aspx` | RetailBanking | Transaction / Entry | 13,194 | 228 | 46 | 124.41 |
| `RetailBanking/Account/c_LoanSecurity.aspx` | RetailBanking | CRUD master | 15,396 | 44 | 32 | 123.75 |
| `Lockers/k_LockerIssue.aspx` | Lockers | CRUD master | 13,211 | 289 | 30 | 115.74 |
| `RetailBanking/loanRepayment.aspx` | RetailBanking | Transaction / Entry | 13,846 | 267 | 23 | 113.68 |
| `HO/b_ClientV1.aspx` | HO | CRUD master | 15,453 | 356 | 12 | 113.41 |
| `RetailBanking/c_LoanDisbursement.aspx` | RetailBanking | CRUD master | 13,530 | 234 | 27 | 112.49 |
| `HO/ProjectFormulation/p_LoanCase_v1.aspx` | HO | Wizard / Multi-tab | 12,879 | 434 | 28 | 111.45 |
| `RetailBanking/Transaction/x_TransactionOtherDetails.aspx` | RetailBanking | Transaction / Entry | 7,240 | 473 | 38 | 111.03 |

## 6. Shared stored procedures

832 procedures are called by more than one screen. Each is a migration lever: convert it once and every calling screen moves closer. Full list in `shared-procs.tsv`; the top 20 by reach:

| Procedure | Screens | Modules |
| --- | ---: | --- |
| `pr_g_getconsbranches` | 179 | HO, Helpdesk, Inventory, Lockers … |
| `pr_x_getglobalclient` | 39 | HO, Lockers, Reports, RetailBanking |
| `pr_re_sb_fwgetaccount` | 36 | Reconciliation, Reports |
| `pr_x_getservicebranch` | 35 | Reconciliation, Reports, RetailBanking |
| `pr_x_calculationofservicetaxcommon` | 34 | Lockers, RetailBanking, UserControls |
| `pr_re_getaccountnumberwithbalanceamount` | 27 | Reconciliation, Reports |
| `pr_b_getchargesamount` | 26 | Lockers, Reports, RetailBanking |
| `pr_re_fwgetaccountformat` | 26 | Reconciliation, Reports |
| `pr_re_getbankname` | 25 | Reconciliation, Reports |
| `pr_x_scrollsave` | 24 | HO, Inventory, RetailBanking |
| `pr_x_getaccountdetails` | 22 | Lockers, RetailBanking |
| `pr_g_rupeesinwords` | 21 | HO, Reports, RetailBanking |
| `pr_x_getaccounts` | 21 | Reports, RetailBanking, UserControls |
| `pr_c_getchagestype` | 18 | RetailBanking |
| `pr_g_getcity` | 16 | EmployeeDemand, HO, RetailBanking |
| `pr_cts_getcellconstringname` | 15 | Reports, RetailBanking |
| `pr_b_getmonthlastworkingdate` | 14 | RetailBanking |
| `pr_b_lockunlockaccount` | 14 | RetailBanking |
| `pr_ft_getifsccode` | 14 | Inventory, RetailBanking |
| `pr_g_getaccountheadv2` | 14 | RetailBanking |

## 7. Migration status

Joined from the A_MENUS cutover migration [0004_menu_routes_cutover.sql](../../TflCbs.Tools.DbMigrator/Migrations/sqlserver/0004_menu_routes_cutover.sql), which retired the old `config/routecutover.json` map and made the menu row the single source of truth. **8 of 1,477 screens** have a new route today.

| Legacy screen | Module | Category | New route |
| --- | --- | --- | --- |
| `HO/Admin/a_Module.aspx` | HO | CRUD master | `/Administration/Module` |
| `HO/Admin/a_RoleMaster.aspx` | HO | CRUD master | `/Administration/Role` |
| `HO/Bank/g_District.aspx` | HO | CRUD master | `/Hr/District` |
| `HO/Bank/g_State.aspx` | HO | CRUD master | `/Hr/State` |
| `HO/Bank/g_Taluka.aspx` | HO | CRUD master | `/Hr/Taluka` |
| `Hr/h_DiscipActionHistory.aspx` | Hr | CRUD master | `/Hr/DiscipActionHistory` |
| `Lockers/k_LockerType.aspx` | Lockers | CRUD master | `/Lockers/LockerType` |
| `RetailBanking/b_AccHoldingAmount.aspx` | RetailBanking | CRUD master | `/RetailBanking/AccHoldingAmount · /RetailBanking/AccHoldingAmount/Authorize` |

Screens rebuilt without a menu-route entry (login, menu, module chooser) are not counted here — the migration is the only machine-checkable source, and padding it by hand would defeat the point. Two cases are un-migrated **on purpose** and documented in that script: `~/ho/GlobalClientDocAttach.aspx` (no controller exists) and the `RELEASE`/`RELEASEPASS` modes of `~/retailbanking/b_AccHoldingAmount.aspx` (only `ENTRY`/`ENTRYPASS` are migrated).

## 8. Caveats

- Category and complexity are **heuristics over static signals**, meant to size and route work, not to replace a screen-by-screen walkthrough in discovery.
- A screen counted here is not necessarily reachable: dead pages left in the tree still have files. Confirming reachability needs the menu tables (`a_Module` / rights), which this scan deliberately does not touch.
- Report bodies (RDL/Crystal definitions) are out of scope; only the `.aspx` hosting them is counted.
- Procedure references are the `pr_*` names appearing in the code-behind. Procedures reached indirectly (built at runtime, or via the compiled BLL) are invisible to a static scan, so `Distinct procs` is a floor.
