# Legacy screens shaped like the State master

> **Generated:** 2026-09-05 by `scripts/state-like-screens.py` - regenerate after each port, do not hand-edit.
> Machine-readable twin: [`state-like-screens.tsv`](state-like-screens.tsv). Full screen census: [`screens.tsv`](screens.tsv).

[`/Hr/State`](../../TflCbs.Modules.Hr.Web/Areas/Hr/Controllers/StateController.cs) is the reference slice for a **single-entity master**: one table, one `Result`-returning service, one form, one view, search modal plus row tokens. This page lists every legacy screen cast in the same mould, so each one is a copy-and-swap rather than a design exercise.

## What qualifies

A screen is on this list only if **all four** hold:

| # | Condition | Why it matters |
|---|-----------|----------------|
| 1 | Category `CRUD master` | It is master data, not a transaction, report or inquiry. |
| 2 | Buttons `uxSave` + `uxUpdate` + `uxDelete` + `uxSearch` | The exact State action bar, so `CbsScreenController`'s save/update/delete/search lifecycle maps one-to-one. |
| 3 | **Writes exactly one entity** | **The primary condition.** One table means one `Repository<T>`, one `Result`-returning service, no cross-table transaction. |
| 4 | No maker-checker scroll | `x_Scroll` writes a second entity and adds an authorize step - a different shape (compare `b_AccHoldingAmount`). |

### How condition 3 is decided

The written set is the union of **every write the screen can reach** - not just the ones visible in the code-behind:

| Source | Signal |
|--------|--------|
| Code-behind | `.Entity = <var>` (the variable's class name *is* the table), `New <X>BLLC` (X is the table), inline `INSERT`/`UPDATE`/`DELETE`. |
| **Stored procedures** | every `pr_*` the code-behind names is opened from the proc tree and its own `INSERT`/`UPDATE`/`DELETE`/`MERGE` targets are folded in (one level of proc-calls-proc included). |
| Banner comment | the hand-maintained `Tables Affected` block - fallback only, never allowed to override evidence found in code. |

So a screen writing one table inline and a second through a proc is correctly **rejected**, and a screen writing nothing inline but driving one table through a proc is correctly **admitted**.

**Reads never disqualify.** A State dropdown on a District screen is a lookup, not a second entity - it is reported and counted separately below.

**78 screens qualify.** 5 are already ported, so **73 remain**.

| Tier | Shape | Pure | With lookups | Remaining |
|------|-------|-----:|-------------:|----------:|
| **A** | 1-3 plain text fields, no lookup dropdown. | 7 | 3 | 10 |
| **B** | Up to 8 fields, and/or a dropdown or picker. | 15 | 42 | 57 |
| **C** | 9 or more fields on one entity. | 0 | 6 | 6 |
| | **Total** | **22** | **51** | **73** |

*Pure* = writes and reads only its own table, exactly like `g_State`. *With lookups* = writes one table, reads others to populate dropdowns or resolve codes.

### Screens that did not qualify

Of the 336 `CRUD master` screens in the census:

| Reason | Screens |
|--------|--------:|
| not the State button set | 154 |
| writes 4 entities | 35 |
| maker-checker scroll | 30 |
| writes 2 entities | 24 |
| writes 3 entities | 9 |
| writes no detectable table | 6 |

`writes N entities` is now measured across code **and** procs, so a screen whose second write only happens inside a `pr_*` is rejected here rather than slipping through. `writes no detectable table` means neither the code-behind nor any proc it names contains a write - typically a screen driven by a proc the export does not carry.

## Tier A - direct State clones (10)

*1-3 plain text fields, no lookup dropdown.* Copy the State slice and swap the entity: service + form + controller + one view. No new shared components needed.

### -> `(no module yet)` (1 - 0 pure, 1 with lookups)

| Legacy screen | Entity (written) | Fields | Lookup reads | Needs | VB LoC |
|---------------|------------------|-------:|--------------|-------|-------:|
| `Inventory/i_UnitOfMeasurement.aspx` | `i_unitofmeasurement` | 2 | 1: `i_item` | - | 642 |

### -> `Bank / General` (4 - 4 pure, 0 with lookups)

| Legacy screen | Entity (written) | Fields | Lookup reads | Needs | VB LoC |
|---------------|------------------|-------:|--------------|-------|-------:|
| `HO/b_MailInfo.aspx` | `b_mailinfo` | 3 | **pure** | - | 377 |
| `HO/bank/g_Circle.aspx` | `g_circle` | 3 | **pure** | - | 326 |
| `HO/bank/g_Relation.aspx` | `g_relation` | 2 | **pure** | - | 200 |
| `HO/bank/g_Step.aspx` | `g_step` | 2 | **pure** | - | 222 |

### -> `HR` (2 - 2 pure, 0 with lookups)

| Legacy screen | Entity (written) | Fields | Lookup reads | Needs | VB LoC |
|---------------|------------------|-------:|--------------|-------|-------:|
| `HR/h_DiscipAction.aspx` | `h_discipaction` | 1 | **pure** | - | 275 |
| `HR/h_Qualification.aspx` | `h_qualification` | 1 | **pure** | - | 360 |

### -> `RetailBanking` (3 - 1 pure, 2 with lookups)

| Legacy screen | Entity (written) | Fields | Lookup reads | Needs | VB LoC |
|---------------|------------------|-------:|--------------|-------|-------:|
| `RetailBanking/c_Community.aspx` | `c_community` | 1 | **pure** | - | 350 |
| `RetailBanking/Legal/lg_Section.aspx` | `lg_section` | 3 | 2: `lg_suitcase`, `lg_suitcasehistory` | - | 368 |
| `RetailBanking/Legal/lg_ActivityMaster.aspx` | `lg_activitymaster` | 3 | 3: `lg_section`, `lg_suitcase`, `lg_suitcasehistory` | - | 493 |

## Tier B - State plus a lookup (57)

*Up to 8 fields, and/or a dropdown or picker.* The same slice as State plus a lookup load (`_RecordPicker`, `_DatePicker`, or a plain `<select>`). Still one entity, one form, one view.

### -> `(no module yet)` (16 - 2 pure, 14 with lookups)

| Legacy screen | Entity (written) | Fields | Lookup reads | Needs | VB LoC |
|---------------|------------------|-------:|--------------|-------|-------:|
| `Helpdesk/hd_EmailConfig.aspx` | `hd_emailconfig` | 7 | **pure** | - | 631 |
| `Treasury/Masters/tr_Broker.aspx` | `tr_broker` | 4 | **pure** | record picker, date picker | 404 |
| `Treasury/Masters/tr_DealType.aspx` | `tr_dealtype` | 2 | 1: `g_currency` | record picker | 467 |
| `Treasury/Masters/tr_Holiday.aspx` | `tr_holiday` | 1 | 1: `g_currency` | record picker, date picker | 489 |
| `Treasury/Masters/tr_Product.aspx` | `tr_product` | 5 | 1: `b_code` | record picker, date picker | 515 |
| `Treasury/Masters/tr_RateReasonabilitySpread.aspx` | `tr_ratereasonabilityspread` | 7 | 1: `tr_product` | record picker, date picker | 602 |
| `Inventory/i_Depriciation.aspx` | `i_depriciation` | 3 | 2: `b_financialyear`, `g_inventorycategory` | record picker, date picker | 723 |
| `Inventory/i_Object.aspx` | `i_object` | 2 | 2: `g_inventorycategory`, `i_item` | record picker | 607 |
| `Inventory/i_ObjectDetail.aspx` | `i_objectdetail` | 3 | 2: `g_inventorycategory`, `i_item` | record picker | 517 |
| `Treasury/Masters/tr_CurrencyGLMapping.aspx` | `tr_currencyglmapping` | 0 | 2: `g_accounthead`, `g_currency` | record picker | 469 |
| `Treasury/Masters/tr_DealersAddLimit.aspx` | `tr_dealerlimit` | 3 | 2: `a_user`, `a_userinmodule` | record picker, date picker | 543 |
| `Treasury/Masters/tr_DealersLimit.aspx` | `tr_dealerlimit` | 2 | 2: `a_user`, `a_userinmodule` | record picker, date picker | 548 |
| `Treasury/Masters/tr_BankAccounts.aspx` | `tr_bankaccounts` | 3 | 3: `b_account`, `g_accounthead`, `g_globalclient` | record picker | 445 |
| `Treasury/Masters/tr_ClientLimit.aspx` | `tr_clientlimit` | 1 | 4: `g_currency`, `g_globalclient`, `tr_customer` +1 | record picker, date picker | 660 |
| `Reconciliation/re_ReconciliationRollBack.aspx` | `re_oledgerauthentication` | 4 | 6: `b_financialyear`, `b_workingdate`, `g_currency` +3 | record picker | 479 |
| `Inventory/i_Item.aspx` | `i_item` | 3 | 8: `g_inventorycategory`, `i_assetdisposal`, `i_depriciation` +5 | record picker, date picker | 970 |

### -> `Bank / General` (17 - 7 pure, 10 with lookups)

| Legacy screen | Entity (written) | Fields | Lookup reads | Needs | VB LoC |
|---------------|------------------|-------:|--------------|-------|-------:|
| `HO/BG/Bg_CommissionRateMaster.aspx` | `bg_commissionratemaster` | 4 | **pure** | - | 280 |
| `HO/Hr/g_Language.aspx` | `g_language` | 6 | **pure** | 2 lookup | 292 |
| `HO/Hr/h_LeaveType.aspx` | `h_leavetype` | 6 | **pure** | - | 328 |
| `HO/ProjectFormulation/p_FeedbackMaster.aspx` | `p_feedbackmaster` | 6 | **pure** | 2 lookup | 336 |
| `HO/bank/b_ChargesConfig.aspx` | `b_chargesconfig` | 2 | **pure** | record picker | 540 |
| `HO/bank/g_BranchCategory.aspx` | `g_branchcategory` | 4 | **pure** | - | 245 |
| `HO/bank/g_ServiceStatus.aspx` | `g_servicestatus` | 4 | **pure** | - | 216 |
| `HO/BG/Bg_CurrencyGLMapping.aspx` | `td_bg_currencyglmapping` | 2 | 1: `g_currency` | record picker | 343 |
| `HO/MultiCurrency/g_DenominationUnit.aspx` | `g_denominationunit` | 1 | 1: `g_currency` | record picker, date picker | 466 |
| `HO/bank/g_Notes.aspx` | `g_notes` | 2 | 1: `g_accounthead` | record picker | 917 |
| `HO/MultiCurrency/tr_CurrencyGLMapping.aspx` | `tr_currencyglmapping` | 0 | 2: `g_accounthead`, `g_currency` | record picker | 460 |
| `HO/lc/lc_CurrencyGLMapping.aspx` | `lc_currencyglmapping` | 4 | 2: `g_accounthead`, `g_currency` | record picker | 623 |
| `HO/MultiCurrency/tr_CashCurrencyHead.aspx` | `tr_cashcurrencyhead` | 0 | 3: `g_accounthead`, `g_bankvariables`, `g_currency` | record picker | 2229 |
| `HO/ProjectFormulation/p_Document.aspx` | `p_document` | 6 | 3: `p_loanpurpose`, `p_scheme`, `p_schemepurpose` | record picker | 601 |
| `HO/b_CommissionSlab.aspx` | `b_commissionslab` | 5 | 3: `g_globalclient`, `g_ngo`, `g_title` | record picker, date picker | 656 |
| `HO/GlobalClientDocAttach.aspx` | `g_clientdocmap` | 3 | 5: `b_address`, `b_doctypecategory`, `b_documenttype` +2 | record picker | 710 |
| `HO/ProjectFormulation/P_CreditOfficer.aspx` | `p_creditofficer` | 0 | 5: `a_user`, `c_loan`, `h_employee` +2 | record picker, date picker | 699 |

### -> `HR` (5 - 1 pure, 4 with lookups)

| Legacy screen | Entity (written) | Fields | Lookup reads | Needs | VB LoC |
|---------------|------------------|-------:|--------------|-------|-------:|
| `HR/g_Bank.aspx` | `g_bank` | 8 | **pure** | - | 293 |
| `HR/h_ExprHistory.aspx` | `h_exprhistory` | 3 | 1: `vw_h_employee` | record picker, date picker | 371 |
| `HR/h_HonAwardHistory.aspx` | `h_honawardhistory` | 1 | 2: `h_honaward`, `vw_h_employee` | record picker, date picker | 322 |
| `HR/h_PromHistory.aspx` | `h_promhistory` | 0 | 2: `g_designation`, `vw_h_employee` | record picker, date picker | 409 |
| `HR/h_LeaveApplication.aspx` | `h_leaveapplication` | 1 | 3: `h_leavecancellation`, `h_leavetype`, `vw_h_employee` | record picker, date picker | 601 |

### -> `Lockers` (2 - 0 pure, 2 with lookups)

| Legacy screen | Entity (written) | Fields | Lookup reads | Needs | VB LoC |
|---------------|------------------|-------:|--------------|-------|-------:|
| `Lockers/k_LockerReturn.aspx` | `l_lockerreturn` | 6 | 3: `b_account`, `g_orgelement`, `k_lockerreturn` | record picker, date picker, account picker | 640 |
| `Lockers/k_LockerVisiting.aspx` | `l_lockervisiting` | 8 | 9: `b_account`, `b_workingdate`, `g_orgelement` +6 | record picker, date picker, account picker | 805 |

### -> `Reference` (1 - 0 pure, 1 with lookups)

| Legacy screen | Entity (written) | Fields | Lookup reads | Needs | VB LoC |
|---------------|------------------|-------:|--------------|-------|-------:|
| `HO/bank/g_City.aspx` | `g_state` | 4 | 1: `g_city` | record picker | 469 |

### -> `RetailBanking` (16 - 5 pure, 11 with lookups)

| Legacy screen | Entity (written) | Fields | Lookup reads | Needs | VB LoC |
|---------------|------------------|-------:|--------------|-------|-------:|
| `HO/retailBanking/b_BankList.aspx` | `b_banklist` | 4 | **pure** | - | 424 |
| `HO/retailBanking/g_BaseRate.aspx` | `g_baserate` | 2 | **pure** | date picker | 594 |
| `HO/retailBanking/g_PLR.aspx` | `g_plr` | 2 | **pure** | date picker | 594 |
| `RetailBanking/b_DocumentType.aspx` | `b_documenttype` | 6 | **pure** | date picker | 557 |
| `RetailBanking/npa/b_NPAClassMaster.aspx` | `b_npaclassmaster` | 4 | **pure** | - | 1557 |
| `RetailBanking/LC/LCTemplate.aspx` | `lctemplate` | 7 | 1: `b_templateitems` | 2 lookup | 526 |
| `HO/retailBanking/b_Holiday.aspx` | `b_holiday` | 5 | 2: `b_financialyear`, `g_orgelement` | date picker | 1024 |
| `RetailBanking/b_WaiveOff.aspx` | `b_waiveoff` | 3 | 2: `b_applicationconfig`, `g_allowdebittransactionaccountheads` | record picker, date picker, account picker | 635 |
| `RetailBanking/npa/c_NPAMethodMapping.aspx` | `c_npamethodmapping` | 0 | 2: `c_npamethodmaster`, `g_accounthead` | record picker | 919 |
| `RetailBanking/swift/x_SFTBankCode.aspx` | `x_sftbankcode` | 2 | 2: `x_sftcountry`, `x_sftoutward` | record picker | 348 |
| `HO/retailBanking/x_WHTMaster.aspx` | `x_whtmaster` | 4 | 3: `g_accounthead`, `g_bankvariables`, `g_currency` | record picker, date picker | 1066 |
| `RetailBanking/b_SpecialInstruction.aspx` | `b_specialinstruction` | 3 | 4: `b_account`, `g_accounthead`, `g_globalclient` +1 | record picker, date picker, account picker | 1069 |
| `RetailBanking/b_Signature_V1.aspx` | `b_signature` | 7 | 7: `b_account`, `g_accounthead`, `g_globalclient` +4 | record picker, account picker | 2606 |
| `RetailBanking/Account/SiTran.aspx` | `x_fdsitran` | 7 | 9: `b_account`, `b_banklist`, `b_branchlist` +6 | record picker, date picker | 1081 |
| `RetailBanking/Legal/lg_SuitCaseClosing.aspx` | `lg_suitcase` | 4 | 10: `b_account`, `b_applicationconfig`, `b_client` +7 | record picker, date picker | 1458 |
| `RetailBanking/b_SwiftBankAccMap.aspx` | `b_swiftbankaccmap` | 2 | 14: `a_user`, `b_account`, `b_accountagent` +11 | record picker | 687 |

## Tier C - wide single-entity master (6)

*9 or more fields on one entity.* Structurally identical to State, just a longer form - the work is typing, not design.

### -> `(no module yet)` (2 - 0 pure, 2 with lookups)

| Legacy screen | Entity (written) | Fields | Lookup reads | Needs | VB LoC |
|---------------|------------------|-------:|--------------|-------|-------:|
| `Reconciliation/Re_OutPutType.aspx` | `re_outputtype` | 16 | 1: `re_code` | record picker | 1045 |
| `Treasury/Masters/tr_Customer.aspx` | `tr_customer` | 10 | 4: `b_account`, `b_code`, `g_currency` +1 | record picker | 545 |

### -> `Administration` (1 - 0 pure, 1 with lookups)

| Legacy screen | Entity (written) | Fields | Lookup reads | Needs | VB LoC |
|---------------|------------------|-------:|--------------|-------|-------:|
| `HO/Admin/a_CashierLimit.aspx` | `a_cashierlimit` | 24 | 5: `a_role`, `a_userrights`, `a_usertranauthlimit` +2 | record picker | 548 |

### -> `Bank / General` (1 - 0 pure, 1 with lookups)

| Legacy screen | Entity (written) | Fields | Lookup reads | Needs | VB LoC |
|---------------|------------------|-------:|--------------|-------|-------:|
| `HO/bank/g_Designation.aspx` | `g_designation` | 14 | 1: `b_code` | date picker | 665 |

### -> `Lockers` (1 - 0 pure, 1 with lookups)

| Legacy screen | Entity (written) | Fields | Lookup reads | Needs | VB LoC |
|---------------|------------------|-------:|--------------|-------|-------:|
| `Lockers/k_LockerIssue.aspx` | `g_relation` | 16 | 9: `b_account`, `b_workingdate`, `g_bankvariables` +6 | record picker, date picker, account picker | 1667 |

### -> `RetailBanking` (1 - 0 pure, 1 with lookups)

| Legacy screen | Entity (written) | Fields | Lookup reads | Needs | VB LoC |
|---------------|------------------|-------:|--------------|-------|-------:|
| `RetailBanking/LC/LCPurchase.aspx` | `lcpurchase` | 42 | 19: `a_user`, `b_account`, `b_banklist` +16 | record picker, date picker | 2161 |

## Already ported

| Legacy screen | Entity | New route |
|---------------|--------|-----------|
| `HO/Admin/a_Module.aspx` | `a_module` | /Administration/Module |
| `HO/Admin/a_RoleMaster.aspx` | `a_role` | /Administration/Role |
| `HO/bank/g_District.aspx` | `g_state` | /Hr/District |
| `HO/bank/g_State.aspx` | `g_state` | /Hr/State |
| `HO/Admin/a_Menus.aspx` | `a_menus` | /Administration/Menu |

## How to port one

Follow the State slice file for file:

1. **Service** - `TflCbs.Modules.<Module>/<Name>Service.cs`: `Repository<T>` over the entity; `Search...Async` / `Load...Async` / `Save...Async` / `Update...Async` / `Delete...Async`, each returning `Result`/`Result<T>`. No raw SQL, no procs.
2. **Form** - `Models/<Area>/<Name>Models.cs`: an `IRowForm` with `Row`, the fields, and `Version` for optimistic concurrency.
3. **Controller** - `Areas/<Area>/Controllers/<Name>Controller.cs` extending `CbsScreenController`: `[CbsAccessScreen]`, the `search`/`save`/`update`/`delete` actions, row tokens via `TryOpenRecord` / `TryBeginWrite` / `TryConsume`.
4. **View** - `Areas/<Area>/Views/<Name>/Index.cshtml`: one `.card`, a `SearchDescriptor`, the standard action bar.
5. Register the route in the menu cutover migration, then run the **cbs-sync-test-demo** agent to sync `TflCbs.Tests` and `TflCbs.Demo`.

## Caveats

- **63 proc names could not be resolved** against the 5254-file proc export (the code-behind names them, the tree does not carry them). A screen whose only write lives in one of those shows up as `writes no detectable table` and is held back rather than guessed at.
- Proc-calls-proc is followed one level deep. A write hidden two levels down is not seen.
- Dynamic SQL built by string concatenation inside a proc is not evaluated, so a table named only in a `sp_executesql` payload can be missed.
- The tiers measure *form width*, not business rules. A 2-field screen can still hide validation the port has to reproduce - read the code-behind before quoting a number.
