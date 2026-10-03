# 0001 — A screen's code lives in the module that owns its data; the legacy menu module is the default owner

- **Status:** Accepted, 2026-09-24
- **Replaces:** the earlier rule "keep legacy menu placement, but don't realign code modules to menu modules"
  (State under the HR menu with Reference code; denominations under Central Administration with Bank.Web +
  Reference code).
- **First applied to:** Denomination Unit (menu 893) and Denominations (menu 890).

## Decision

**The code module is the business area that owns the screen's data. The legacy menu module the screen hangs
under (`a_ModuleMenuMap`) is the default answer.** A Central Administration screen goes in
`TflCbs.Modules.Administration` (+ `.Web`); a Retail and Corporate Operations screen goes in
`TflCbs.Modules.RetailBanking` (+ `.Web`).

Other modules that need the data **read it through `TflCbs.Modules.<Owner>.Contracts`** — read methods only.
Creating, changing and deleting stays inside the owner.

## The three exceptions

1. **Platform and security data stays in core.** Passwords, sessions, login, menus, the maker-checker scroll
   and bank variables stay in `TflCbs.Core.Authentication` / `TflCbs.Modules.General`, whatever the menu.
   User Creation: screen in Administration.Web, service in Core.Authentication.
2. **Ownerless shared masters stay in `TflCbs.Modules.Reference`.** No owning domain *and* read by many
   domains — Currency, State/District/Taluka. The test against `.Contracts`: one clear owner read by a few
   others → `Owner.Contracts` (denominations); no owner, read everywhere → `Reference`.
3. **A screen mapped to more than one menu module gets one named owner**, chosen and written down case by case.

## Guardrails

- **Legacy URLs stay.** Controllers keep their `[Route("…")]` (e.g. `/Bank/Denomination` now served by
  Administration.Web), so `A_MENUS.NavigateURL` and the menu-access guard need no migration.
- **Add a `.Contracts` assembly only when a second module actually reads the data** — not in advance.
- **A contract has no implementation of its own.** A host that runs a consumer must also enable the owner
  module (services only — it need not serve the owner's screens). Enforced by
  `ModuleConfigTests.A_host_that_enables_a_contract_consumer_also_enables_the_contract_owner`, which derives
  the consumer→owner edges from the reference graph and checks every appsettings and compose service.
- **No two domains read each other's contracts.** That compiles, but it tangles the domains. Review it at the
  second contract.
- The sibling-domain arch rules exempt a module's `.Contracts` namespace (`ArchBoundaries.IsContractsOf`,
  `SiblingServiceTypesFor`) — everything else in a sibling stays forbidden.

## Why

- Module boundaries follow business areas, and the legacy CBS modules approximate them well — the standard
  split for a modular monolith, and where a developer who knows legacy looks first.
- One owner per piece of data; reads cross modules through a published surface; writes never do.
- The menu is the *default*, not the definition — it is a navigation decision and sometimes arbitrary (State
  sits under HR), hence the exceptions.

## Consequences

- `TflCbs.Modules.Administration.Contracts` (new): `IDenominationReader.GetByCurrencyAsync`, implemented by
  `DenominationService`, registered by `AdministrationModule`.
- `DenominationUnitService` / `DenominationService` moved Reference → Administration; the two screens moved
  Bank.Web → Administration.Web (`wwwroot/js/denomination.js`). Bank.Web keeps only ReferenceCache.
- RetailBanking.Web (Dormant Re Activation) reads denominations via `IDenominationReader` and no longer
  references Reference. `TflCbs.Host.RetailBanking` and its compose service enable `Administration` (services
  only).
- Earlier placements (State/District/Taluka in Reference under the HR menu) are **not** moved by this record;
  they fall under exception 2.
