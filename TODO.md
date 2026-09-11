# TODO

Task checklist. `//DONE` markers from the original list are kept as ticked boxes.

## Open

- [ ] Avoid paging for less than 100 rows (configurable).
- [ ] Why does stopping the HR module still show HR pages? (IIS multi-host)

## Done

- [x] Entity Builder — hosted on the network at <http://192.168.0.6:4013/>.
- [x] Actual menus from `a_Menus` (no `routecutover.json`) → DbMigrator `0004_menu_routes_cutover.sql`; `RouteCutover` deleted.
- [x] Two docs written: [Why-Modular-Monolith-Not-Microservices.md](architecture/Why-Modular-Monolith-Not-Microservices.md) and [Is-CBS-A-Multi-Tier-Application.md](architecture/Is-CBS-A-Multi-Tier-Application.md).
- [x] Add calendar to the date/time picker.
- [x] `TflCbsServices` split module-wise.

## Handover checklist

- [ ] End-to-end check with Oracle before handover.

## Login / auth backlog

- [ ] RC4 login
- [ ] `MFA_AD_LOGIN_ENABLED`
- [ ] `MFA_QR_AT_LOGIN_ENABLED`
- [ ] `MFA_OTP_AT_LOGIN_ENABLED`
- [ ] `Login.aspx` (tag: new code for payroll)
- [ ] `PR_G_GETLOGINOUTTIME`
