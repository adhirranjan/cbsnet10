# TrustBank CBS — Migrated vs. New
 

## 1. At a Glance

| | Legacy (as found) | New (.NET 10) |
| --- | --- | --- |
| Runtime | .NET Framework 4.8 | **.NET 10**|
| Language | VB.NET | **C#**  |
| Web stack | ASP.NET **WebForms**  | ASP.NET Core **MVC** — Controllers, Razor views, attribute routing |
| Deployment unit | One IIS site, one monolithic web app | **Modular Monolith**; Thin per-module hosts; IIS |
| Business logic | stored procedures  | per-domain **service module assemblies**, **no procs / no raw SQL** |
| Data access | Enterprise Library Data (Microsoft patterns & practices)| **TflOmniDb** — `Repository<T>` + `DataAccess`, async-only|
| Database | SQL Server only | SQL Server · Oracle |
| Observability | ad-hoc (`AdDiagnostics.dll`, log files) | **TflOmniLog** (Serilog) + **OpenTelemetry** traces & metrics over OTLP |

**Counted legacy scope for context:** 1,458 `.aspx` screens (1,059 functional + 399 reports) · 5,317 stored procedures · 1,497 VB code-behind files · 19 reusable controls.

---

## 2. Architecture

| Concern | Legacy | New |
| --- | --- | --- |
| Business-layer structure | more than 5300* procedures | **Modular monolith**: per-domain assemblies, module = bounded domain|
| Screen packaging | `.aspx` files in folders | **Per-domain Razor Class Libraries** (`TflCbs.Modules.<Area>.Web`)|


---

## 3. Framework & web plumbing

| Capability | Legacy | New  |
| --- | --- | --- |
| Search backend | encrypted SQL shipped in the popup URL | **the server owns the query**; only values cross the wire |
| Primary keys on the client | raw PKs in query strings and grid rows | `RowToken` — AES, **single-use** | 
| Database Provider selection | SQL Server, compile-time | `DatabaseSelector` + multi-provider `DataAccess` wiring; |
| Health checks | none | `DatabaseHealthCheck` + endpoints per host | **New** |
| Antiforgery | ViewState/EventValidation | ASP.NET Core antiforgery |
| Login rate limiting | none (DB lockout counters only) | Login rate limiting is built on ASP.NET Core's built-in `Rate Limiting` middleware; the DB lockout policy is kept as the per-account layer | **New** |

---

## 4. Reusable UI components

| Legacy control | New counterpart | 
| --- | --- | 
| `TssiplDatePicker.ascx` | `_DatePicker` + `DatePickerModel` + `cbs-datepicker.js` |
| `TssiplRecordSelector(.ascx)` V1/V2 + `RecordSelector.aspx` | `_RecordPicker` + `RecordPickerModel` + `cbs-search.js` | **Rebuilt** |
| `TssiplSearchBox.ascx` + `RecordSelector.aspx` grid | `_SearchModal` + `SearchDescriptor`/`SearchColumn`/`SearchFilter` + `SearchEndpoint` + `RowToken` | **Rebuilt** |
| `Account.ascx` + COA/Account selectors + `AccountSelector.aspx` | `_AccountPicker` + `AccountPickerModel` + `_AccountSearchModal` + `cbs-account-picker.js` | **Rebuilt** |
| `MainMenu.ascx` + `CollapsablePanelStart/End.ascx` | `_MenuOverlay` / `_MenuGrid` + `MenuService` | **Rebuilt** |
| ad-hoc `alert()` / `MessageBox.aspx` | `_Notification` ack modal + `cbsNotify` toast | **Rebuilt** |


**Components with no legacy counterpart** — all **New**:

| Component | What it does |
| --- | --- |
| `_CommandPalette` + `cbs-command-palette.js` | Ctrl+K quick-access over the session menu, client-side |
| `cbs-idle.js` + `KeepAliveController` | Idle warning at `Cbs:IdleWarnMinutes`, logout at `IdleLogoutMinutes`, keep-alive ping |
| `cbs-uppercase.js` | Uppercase user input |
| `RowToken` | Encrypted row ids|


---

## 5. Data access, entities & business logic

| Concern | Legacy | New |  
| --- | --- | --- | 
| DAL | Enterprise Library Data, `TSSIPL.Practices.EnterpriseLibrary.Data.dll`, `AdDataAccessComponent.dll` | **TflOmniDb** — `Repository<T>` (`GetAsync`/`GetAllAsync`/`Where`/`Count`/`Insert`/`Update`/`Delete`) + `DataAccess.QueryAsync` | **Rebuilt** |
| Database engines | SQL Server | **SQL Server · Oracle · PostgreSQL** — per-provider quoting, param prefixes, identity, paging, dirty-read hints | **New** |
| Sync/async | synchronous | **Async-only**, `CancellationToken` throughout (no sync overloads) | **New** |
| Transactions | proc-level | `BeginTransactionAsync`, `IUnitOfWork`, `ExecuteInTransactionAsync` with transient-failure retry | **Rebuilt** |
| Query composition | string-concatenated SQL | LINQ predicates + typed `Cols` tokens + the shared `ServiceQuery` helpers (`Has`/`Eq`/`Val`/`Paged`, page-size bounds) | **Rebuilt** |

---

## 6. Security, authentication & session

| Concern | Legacy | New | 
| --- | --- | --- | 
| Password storage | legacy reversible/encoded scheme | **PBKDF2 + per-user salt** (`PASSWORDHASH`, `PASSWORDVERSION`)|
| Crypto library | in-app VB routines | `TflSecurityCrypto` — 1:1 VB.NET port, **byte-for-byte output compatible** (3DES, RC4, salted MD5/SHA1/SHA256/384/512, hardware fingerprint, RNGCSP) | **Ported** |
| Cross-host login | n/a | **Internal SSO** — one login recognized on every CBS host;  |


---


## 7. Deployment, hosting & operations

| Concern | Legacy | New | 
| --- | --- | --- | 
| Hosting shapes | 1 (IIS single site) | IIS multi-host |
| Thin per-module hosts | none | each host runs **one** domain + the core modules | 


---

## 8. Technology stack — old → new

| Area | Legacy | New |
| --- | --- | --- |
| Framework | .NET Framework 4.8 | .NET 10 |
| Language | VB.NET | C#  |
| UI | WebForms, ViewState, postbacks, MasterPages, `.ascx` | ASP.NET Core MVC, Razor, Razor Class Libraries, tag helpers |
| Data | Enterprise Library Data, `AdDataAccessComponent` | TflOmniDb (`Microsoft.Data.SqlClient` 7.0.1 · `Oracle.ManagedDataAccess.Core` 23.7.0 · `Npgsql` 9.0.2) |
| Logging | `AdDiagnostics`, EntLib Logging | TflOmniLog → Serilog 4.2 |
| Telemetry | — | OpenTelemetry 1.17 (hosting, OTLP exporter, ASP.NET Core/HTTP/runtime) |
| Proxy | — | YARP 2.3 |

---
