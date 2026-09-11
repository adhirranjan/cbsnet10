# Legacy Administration module - screen breakdown

The **85 screens** on the legacy Administration menu module, sliced four ways. Source: [`screens.tsv`](screens.tsv); regenerate with `python scripts/administration-breakdown.py`. Module membership comes from the legacy `a_Menus` -> `a_Module` tables, **not** from the folder a page sits in - only 13 of the 85 live under `HO/Admin`.

## 1. At a glance

| Measure | Value |
| --- | --- |
| Screens on the Administration menu | **85** |
| Active menu rows | 82 |
| Inactive / orphaned menu rows | 3 |
| Screens that write data | 79 (93%) |
| Read-only (inquiry / report) | 6 |
| Total legacy code lines (aspx + vb) | 152,658 |
| Distinct stored-proc calls (sum) | 176 |
| Total effort score | 1,305 |
| Already migrated | 6 |

## 2. By effort tier

Tiers band the inventory's `Score` (code length x controls x grids x procs). This is the axis to plan sprints on - the top two tiers are a fifth of the screens and roughly half the total effort.

| Tier (score) | Screens | Share | Effort | Effort share | Avg lines |
| --- | ---: | ---: | ---: | ---: | ---: |
| Trivial (<4) | 11 | 13% | 36 | 3% | 336 |
| Small (4-8) | 38 | 45% | 217 | 17% | 585 |
| Medium (8-15) | 25 | 29% | 264 | 20% | 1,171 |
| Large (15-40) | 7 | 8% | 170 | 13% | 2,713 |
| Very large (40+) | 4 | 5% | 618 | 47% | 19,605 |

## 3. By functional theme

A domain axis the inventory does not carry - what the screen actually configures. This is the useful unit of work: one theme is one coherent slice of the Administration area, sharing tables, vocabulary and reviewers.

| Theme | Screens | Effort | Complexity mix |
| --- | ---: | ---: | --- |
| Other system configuration | 40 | 296 | Medium&nbsp;29, Simple&nbsp;7, Complex&nbsp;3, Report&nbsp;1 |
| Security & access control | 12 | 132 | Medium&nbsp;8, Complex&nbsp;3, Simple&nbsp;1 |
| Bank, branch & geography masters | 10 | 83 | Medium&nbsp;9, Complex&nbsp;1 |
| Accounting heads & mappings | 6 | 101 | Complex&nbsp;3, Medium&nbsp;3 |
| Charges, fees & tax | 4 | 496 | Complex&nbsp;2, Medium&nbsp;2 |
| Loan & credit scheme setup | 4 | 135 | Complex&nbsp;3, Medium&nbsp;1 |
| NPA & risk classification | 3 | 29 | Medium&nbsp;2, Complex&nbsp;1 |
| Interest & rate configuration | 2 | 15 | Medium&nbsp;2 |
| Alerts, SMS & mobile banking | 2 | 6 | Simple&nbsp;2 |
| Letters & document templates | 1 | 7 | Medium&nbsp;1 |
| Client & KYC configuration | 1 | 4 | Simple&nbsp;1 |

## 4. By screen shape

The build pattern each screen needs, derived from grid and input counts. Shapes matter more than themes for *sequencing*: everything in one shape reuses the same controller/view scaffold and the same reusable components.

| Shape | Screens | Share | Avg score | Avg grids | Avg inputs |
| --- | ---: | ---: | ---: | ---: | ---: |
| Simple master (grid + form) | 39 | 46% | 6.0 | 1.0 | 2 |
| Parent-child grid | 22 | 26% | 8.8 | 2.0 | 6 |
| Wide master (grid + many fields) | 9 | 11% | 15.2 | 1.0 | 13 |
| Multi-grid / matrix | 8 | 9% | 85.7 | 11.9 | 65 |
| Config panel (no grid) | 6 | 7% | 6.8 | 0.0 | 7 |
| Report / parameter screen | 1 | 1% | 14.9 | 0.0 | 1 |

## 5. Category x complexity

The inventory's own two axes, crossed. Complexity bands are population quartiles of `Score`: Simple < 4.0, Medium 4.0-12.0, Complex > 12.0; reports band separately.

| Category | Simple | Medium | Complex | Report | Total |
| --- | ---: | ---: | ---: | ---: | ---: |
| CRUD master | 9 | 45 | 13 |  | **67** |
| Transaction / Entry | 1 | 7 | 3 |  | **11** |
| Search / List / Inquiry | 1 | 5 |  |  | **6** |
| Report |  |  |  | 1 | **1** |
| **Total** | **11** | **57** | **16** | **1** | **85** |

## 6. Suggested migration waves

Shape and tier combined into an order of attack. Each wave lands a reusable scaffold the next wave leans on.

| Wave | Screens | Effort | What it needs |
| --- | ---: | ---: | --- |
| Wave 1 - proven scaffold | 32 | 161 | Straight `Repository<T>` CRUD on the shape already shipped for Module/Role. No new components. |
| Wave 2 - remaining masters & parent-child | 38 | 403 | Wave 1's scaffold plus a child grid, the record picker and heavier field sets. |
| Wave 3 - config panels | 6 | 41 | Gridless settings screens (bank/branch variables, access control). Mostly form binding + validation. |
| Wave 4 - matrices & rights | 4 | 67 | Rights/menu matrices. Needs a checkbox-tree component that does not exist yet - build it once here. |
| Wave 5 - reports | 1 | 15 | Parameter screen + export. Blocked on the reporting strategy decision. |
| Wave 6 - the heavies | 4 | 618 | Scheme/LOS/template-designer screens. Each is a project; split before scheduling. |

## 7. Migration status

**6 of 85** carry a `MigratedTo` value.

| Legacy screen | New route |
| --- | --- |
| `HO/Admin/a_Menus.aspx` | `/Administration/Menu` |
| `HO/bank/g_State.aspx` | `/Hr/State` |
| `HO/bank/g_District.aspx` | `/Hr/District` |
| `HO/Admin/a_RoleMaster.aspx` | `/Administration/Role` |
| `HO/Admin/a_Module.aspx` | `/Administration/Module` |
| `HR/h_DiscipActionHistory.aspx` | `/Hr/DiscipActionHistory` |

`/Administration/ConnectedUsers` is also live, ported from `Config/connectedUsers.aspx` - but that page sits on the **Retail Banking** menu in `a_Menus`, so it is not one of these 85 and its `MigratedTo` cell is still blank. Re-run the inventory to pick it up.

## 8. Every screen

Sorted by effort score, descending.

| # | Screen | Theme | Shape | Category | Complexity | Lines | Grids | Inputs | Procs | Score |
| ---: | --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| 1 | `HO/ChargesConfig.aspx` | Charges, fees & tax | Multi-grid / matrix | CRUD master | Complex | 60,240 | 61 | 253 | 6 | 464.45 |
| 2 | `HO/retailBanking/d_DepositScheme.aspx` | Loan & credit scheme setup | Multi-grid / matrix | Transaction / Entry | Complex | 8,015 | 3 | 62 | 4 | 59.70 |
| 3 | `HO/ProjectFormulation/p_SchemeDetails.aspx` | Loan & credit scheme setup | Multi-grid / matrix | CRUD master | Complex | 5,427 | 6 | 45 | 15 | 51.79 |
| 4 | `HO/Hr/h_Employee.aspx` | Other system configuration | Multi-grid / matrix | CRUD master | Complex | 4,741 | 8 | 104 | 7 | 42.41 |
| 5 | `RetailBanking/g_AllowDebitTransactionAccountHeads_v1.aspx` | Accounting heads & mappings | Wide master (grid + many fields) | Transaction / Entry | Complex | 4,325 | 1 | 17 | 11 | 36.71 |
| 6 | `HO/Admin/a_userAppAccessRights.aspx` | Security & access control | Multi-grid / matrix | CRUD master | Complex | 2,820 | 8 | 18 | 4 | 26.69 |
| 7 | `HO/bank/g_AccountHead.aspx` | Accounting heads & mappings | Wide master (grid + many fields) | CRUD master | Complex | 2,727 | 1 | 13 | 9 | 24.01 |
| 8 | `HO/Admin/A_User.aspx` | Security & access control | Parent-child grid | CRUD master | Complex | 2,537 | 2 | 15 | 6 | 22.37 |
| 9 | `HO/Admin/a_UserRights.aspx` | Security & access control | Parent-child grid | CRUD master | Complex | 2,057 | 2 | 5 | 13 | 22.27 |
| 10 | `HO/b_ChargesMaster.aspx` | Charges, fees & tax | Wide master (grid + many fields) | CRUD master | Complex | 2,038 | 1 | 16 | 5 | 19.25 |
| 11 | `HO/MultiCurrency/tr_CashCurrencyHead.aspx` | Accounting heads & mappings | Simple master (grid + form) | CRUD master | Complex | 2,491 | 1 | 0 | 1 | 18.22 |
| 12 | `Reports/Admin/AdminReport.aspx` | Other system configuration | Report / parameter screen | Report | Report | 1,236 | 0 | 1 | 12 | 14.90 |
| 13 | `HO/Hr/g_BankDirectors.aspx` | Other system configuration | Multi-grid / matrix | CRUD master | Complex | 1,865 | 3 | 30 | 0 | 14.89 |
| 14 | `RetailBanking/npa/b_NPAClassMaster.aspx` | NPA & risk classification | Parent-child grid | CRUD master | Complex | 1,680 | 2 | 4 | 2 | 14.42 |
| 15 | `HR/h_Transfer.aspx` | Other system configuration | Wide master (grid + many fields) | Transaction / Entry | Complex | 1,779 | 1 | 11 | 0 | 13.74 |
| 16 | `HO/retailBanking/b_Holiday.aspx` | Bank, branch & geography masters | Multi-grid / matrix | CRUD master | Complex | 1,280 | 3 | 5 | 3 | 13.31 |
| 17 | `HO/retailBanking/c_LoanIRChange.aspx` | Loan & credit scheme setup | Multi-grid / matrix | CRUD master | Complex | 1,144 | 3 | 6 | 2 | 12.17 |
| 18 | `HO/Admin/a_RoleOnMenu.aspx` | Security & access control | Config panel (no grid) | Transaction / Entry | Medium | 1,503 | 0 | 3 | 4 | 11.57 |
| 19 | `HO/ProjectFormulation/c_LoanScheme.aspx` | Loan & credit scheme setup | Parent-child grid | CRUD master | Medium | 1,159 | 2 | 8 | 1 | 11.45 |
| 20 | `HO/Admin/a_Menus.aspx` * | Security & access control | Parent-child grid | CRUD master | Medium | 1,266 | 2 | 11 | 2 | 11.20 |
| 21 | `RetailBanking/openingBalance.aspx` | Accounting heads & mappings | Parent-child grid | CRUD master | Medium | 1,145 | 2 | 8 | 4 | 11.11 |
| 22 | `HO/bank/g_OrgElement.aspx` | Other system configuration | Config panel (no grid) | Transaction / Entry | Medium | 1,551 | 0 | 24 | 0 | 10.75 |
| 23 | `HO/MultiCurrency/g_Denomination.aspx` | Bank, branch & geography masters | Parent-child grid | CRUD master | Medium | 1,128 | 2 | 5 | 1 | 10.29 |
| 24 | `HO/bank/g_Notes.aspx` | Bank, branch & geography masters | Simple master (grid + form) | CRUD master | Medium | 1,029 | 1 | 2 | 3 | 9.67 |
| 25 | `RetailBanking/DDPOParameterSetting.aspx` | Other system configuration | Wide master (grid + many fields) | CRUD master | Medium | 1,135 | 1 | 14 | 1 | 9.43 |
| 26 | `HO/Admin/b_AccLevelConfig.aspx` | Other system configuration | Simple master (grid + form) | CRUD master | Medium | 1,109 | 1 | 6 | 2 | 9.35 |
| 27 | `HO/retailBanking/ATMPosTerminalAccMapping.aspx` | Other system configuration | Simple master (grid + form) | CRUD master | Medium | 994 | 1 | 6 | 3 | 9.23 |
| 28 | `HO/bank/g_Designation.aspx` | Other system configuration | Parent-child grid | CRUD master | Medium | 955 | 2 | 14 | 1 | 9.11 |
| 29 | `HO/retailBanking/IntrBkLendingConfig.aspx` | Other system configuration | Simple master (grid + form) | CRUD master | Medium | 998 | 1 | 3 | 2 | 8.96 |
| 30 | `Treasury/Masters/g_Currency.aspx` | Other system configuration | Wide master (grid + many fields) | CRUD master | Medium | 960 | 1 | 8 | 1 | 8.81 |
| 31 | `HO/retailBanking/b_BranchList.aspx` | Bank, branch & geography masters | Parent-child grid | CRUD master | Medium | 796 | 2 | 12 | 2 | 8.45 |
| 32 | `RetailBanking/cash/x_ChestOpening.aspx` | Other system configuration | Simple master (grid + form) | CRUD master | Medium | 1,000 | 1 | 1 | 2 | 8.45 |
| 33 | `RetailBanking/LoanInterestUpdation.aspx` | Interest & rate configuration | Wide master (grid + many fields) | CRUD master | Medium | 921 | 1 | 8 | 2 | 8.27 |
| 34 | `HO/retailBanking/g_ECSMasterData.aspx` | Bank, branch & geography masters | Wide master (grid + many fields) | CRUD master | Medium | 963 | 1 | 7 | 1 | 8.20 |
| 35 | `HO/Admin/a_CashierLimit.aspx` | Security & access control | Wide master (grid + many fields) | CRUD master | Medium | 1,082 | 1 | 24 | 1 | 8.17 |
| 36 | `HR/h_TransferHistory.aspx` | Other system configuration | Simple master (grid + form) | Transaction / Entry | Medium | 615 | 1 | 1 | 5 | 8.04 |
| 37 | `HR/h_Promotion.aspx` | Other system configuration | Simple master (grid + form) | CRUD master | Medium | 660 | 1 | 3 | 4 | 7.89 |
| 38 | `RetailBanking/b_EcsCompany.aspx` | Bank, branch & geography masters | Simple master (grid + form) | CRUD master | Medium | 928 | 1 | 1 | 1 | 7.75 |
| 39 | `RetailBanking/npa/c_NPAMethodMapping.aspx` | NPA & risk classification | Simple master (grid + form) | CRUD master | Medium | 999 | 1 | 0 | 0 | 7.57 |
| 40 | `RetailBanking/npa/b_NPAMaster.aspx` | NPA & risk classification | Parent-child grid | CRUD master | Medium | 701 | 2 | 4 | 1 | 7.23 |
| 41 | `HO/TaxConfig.aspx` | Charges, fees & tax | Simple master (grid + form) | CRUD master | Medium | 864 | 1 | 6 | 1 | 7.19 |
| 42 | `HO/Admin/PasswordPolicyConfig.aspx` | Security & access control | Config panel (no grid) | Transaction / Entry | Medium | 1,086 | 0 | 9 | 0 | 7.14 |
| 43 | `HO/bank/b_GlInterestMapping.aspx` | Interest & rate configuration | Simple master (grid + form) | CRUD master | Medium | 697 | 1 | 0 | 3 | 7.12 |
| 44 | `RetailBanking/b_DocumentType.aspx` | Letters & document templates | Simple master (grid + form) | CRUD master | Medium | 718 | 1 | 6 | 2 | 7.11 |
| 45 | `HO/bank/g_City.aspx` | Bank, branch & geography masters | Parent-child grid | CRUD master | Medium | 663 | 2 | 4 | 1 | 6.97 |
| 46 | `HR/h_PromHistory.aspx` | Other system configuration | Simple master (grid + form) | CRUD master | Medium | 518 | 1 | 0 | 4 | 6.77 |
| 47 | `HO/bank/g_State.aspx` | Bank, branch & geography masters | Parent-child grid | CRUD master | Medium | 623 | 2 | 6 | 1 | 6.68 |
| 48 | `HO/retailBanking/b_BankList.aspx` | Bank, branch & geography masters | Parent-child grid | CRUD master | Medium | 564 | 2 | 4 | 1 | 6.39 |
| 49 | `HR/h_QualificationHistory.aspx` | Other system configuration | Parent-child grid | CRUD master | Medium | 631 | 2 | 5 | 0 | 6.29 |
| 50 | `HO/bank/g_District.aspx` * | Other system configuration | Parent-child grid | CRUD master | Medium | 536 | 2 | 2 | 1 | 6.19 |
| 51 | `HO/bank/g_OrgElementDepartment.aspx` | Other system configuration | Parent-child grid | Search / List / Inquiry | Medium | 566 | 2 | 7 | 0 | 5.93 |
| 52 | `HO/LRA_gateway_accounts.aspx` | Other system configuration | Simple master (grid + form) | Search / List / Inquiry | Medium | 565 | 1 | 2 | 2 | 5.89 |
| 53 | `HR/h_LeaveCancellation.aspx` | Other system configuration | Simple master (grid + form) | CRUD master | Medium | 632 | 1 | 1 | 0 | 5.72 |
| 54 | `HO/bank/g_FormAccountHeadMapping.aspx` | Accounting heads & mappings | Simple master (grid + form) | CRUD master | Medium | 727 | 1 | 6 | 0 | 5.65 |
| 55 | `HO/Admin/a_RoleMaster.aspx` | Security & access control | Simple master (grid + form) | CRUD master | Medium | 555 | 1 | 1 | 1 | 5.51 |
| 56 | `HO/x_ChequeBookChargeConfig.aspx` | Charges, fees & tax | Simple master (grid + form) | Transaction / Entry | Medium | 578 | 1 | 1 | 1 | 5.50 |
| 57 | `HO/MultiCurrency/g_DenominationUnit.aspx` | Bank, branch & geography masters | Simple master (grid + form) | CRUD master | Medium | 573 | 1 | 1 | 1 | 5.43 |
| 58 | `RetailBanking/swift/x_SFTBankCode.aspx` | Other system configuration | Simple master (grid + form) | CRUD master | Medium | 465 | 1 | 2 | 2 | 5.28 |
| 59 | `HR/g_Bank.aspx` | Other system configuration | Parent-child grid | CRUD master | Medium | 453 | 2 | 8 | 0 | 5.27 |
| 60 | `RetailBanking/b_IbtHeadMapping.aspx` | Accounting heads & mappings | Simple master (grid + form) | CRUD master | Medium | 553 | 1 | 1 | 1 | 5.17 |
| 61 | `RetailBanking/g_DebtCollector.aspx` | Other system configuration | Simple master (grid + form) | CRUD master | Medium | 452 | 1 | 1 | 2 | 5.13 |
| 62 | `HO/Hr/g_Language.aspx` | Other system configuration | Parent-child grid | CRUD master | Medium | 467 | 2 | 6 | 0 | 5.07 |
| 63 | `HO/Hr/h_LeaveType.aspx` | Other system configuration | Simple master (grid + form) | CRUD master | Medium | 467 | 1 | 6 | 1 | 4.83 |
| 64 | `HO/bank/g_BranchCategory.aspx` | Other system configuration | Parent-child grid | CRUD master | Medium | 388 | 2 | 4 | 0 | 4.59 |
| 65 | `RetailBanking/LRA_custom_accounts.aspx` * | Other system configuration | Config panel (no grid) | Transaction / Entry | Medium | 617 | 0 | 1 | 1 | 4.55 |
| 66 | `HO/Admin/Audit.aspx` | Security & access control | Config panel (no grid) | Transaction / Entry | Medium | 489 | 0 | 2 | 2 | 4.49 |
| 67 | `HR/h_CourseHistory.aspx` | Other system configuration | Simple master (grid + form) | Search / List / Inquiry | Medium | 523 | 1 | 2 | 0 | 4.49 |
| 68 | `HO/bank/g_ServiceStatus.aspx` | Other system configuration | Parent-child grid | CRUD master | Medium | 369 | 2 | 4 | 0 | 4.48 |
| 69 | `HR/h_ExprHistory.aspx` | Other system configuration | Simple master (grid + form) | CRUD master | Medium | 489 | 1 | 3 | 0 | 4.39 |
| 70 | `HO/Admin/AuditView.aspx` | Security & access control | Simple master (grid + form) | Search / List / Inquiry | Medium | 533 | 1 | 0 | 0 | 4.33 |
| 71 | `HO/bank/g_Title.aspx` | Other system configuration | Parent-child grid | Search / List / Inquiry | Medium | 332 | 2 | 4 | 0 | 4.27 |
| 72 | `HO/Admin/a_Module.aspx` | Security & access control | Simple master (grid + form) | CRUD master | Medium | 467 | 1 | 3 | 0 | 4.16 |
| 73 | `HR/h_DiscipActionHistory.aspx` | Other system configuration | Simple master (grid + form) | CRUD master | Medium | 459 | 1 | 2 | 0 | 4.14 |
| 74 | `HO/bank/g_Relation.aspx` | Other system configuration | Parent-child grid | CRUD master | Medium | 336 | 2 | 2 | 0 | 4.13 |
| 75 | `HR/h_Qualification.aspx` | Other system configuration | Simple master (grid + form) | CRUD master | Simple | 426 | 1 | 1 | 0 | 3.92 |
| 76 | `HR/h_DiscipAction.aspx` | Other system configuration | Simple master (grid + form) | CRUD master | Simple | 340 | 1 | 1 | 1 | 3.91 |
| 77 | `HR/h_HonAwardHistory.aspx` | Other system configuration | Simple master (grid + form) | CRUD master | Simple | 436 | 1 | 1 | 0 | 3.87 |
| 78 | `RetailBanking/c_Community.aspx` | Client & KYC configuration | Simple master (grid + form) | CRUD master | Simple | 430 | 1 | 1 | 0 | 3.85 |
| 79 | `HO/Admin/a_UserInModule.aspx` | Security & access control | Simple master (grid + form) | CRUD master | Simple | 372 | 1 | 3 | 1 | 3.80 |
| 80 | `HO/Alerts/al_AlertsRights.aspx` | Alerts, SMS & mobile banking | Simple master (grid + form) | CRUD master | Simple | 360 | 1 | 4 | 0 | 3.28 |
| 81 | `HR/h_HonAward.aspx` | Other system configuration | Simple master (grid + form) | Search / List / Inquiry | Simple | 332 | 1 | 1 | 0 | 3.23 |
| 82 | `HO/bank/g_Step.aspx` | Other system configuration | Simple master (grid + form) | CRUD master | Simple | 308 | 1 | 2 | 0 | 3.16 |
| 83 | `HR/h_LeaveApproval.aspx` | Other system configuration | Simple master (grid + form) | CRUD master | Simple | 259 | 1 | 1 | 0 | 2.57 |
| 84 | `HO/b_MinorAgeConfig.aspx` | Other system configuration | Config panel (no grid) | Transaction / Entry | Simple | 188 | 0 | 1 | 2 | 2.42 |
| 85 | `HO/Alerts/al_AlertConfig.aspx` | Alerts, SMS & mobile banking | Simple master (grid + form) | CRUD master | Simple | 253 | 1 | 1 | 0 | 2.30 |

`*` = menu row is inactive in `a_Menus`; confirm the screen is still wanted before porting it.
