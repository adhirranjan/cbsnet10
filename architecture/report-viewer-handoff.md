# Report viewer handoff: .NET 10 → `TflCbs.ReportViewer`

**Status:** contract v1, agreed 2026-09-24 (Phase 1.1 of [BACKLOG-legacy-app-wide §4.3](../../BACKLOG-legacy-app-wide.md)).
**Scope:** how a .NET 10 screen hands a report to the Crystal viewer app and sends the browser there.
It covers the payload, wire format, endpoints, ticket, security and configuration. The viewer's internals
(Phase 1.2–1.4) and the .NET 10 client (1.5) implement this document; if it changes, bump `version`.

## 1. The two parties

| | .NET 10 CBS (`TflCbs.Host.*`) | `TflCbs.ReportViewer` |
|---|---|---|
| Runtime | .NET 10, Linux or Windows | .NET Framework 4.8 WebForms web site (no project file; IIS compiles it) + Crystal Reports for VS 13.0.x runtime, 64-bit, Windows/IIS only |
| Owns | Access (`CbsAccessMiddleware`), parameter screens, running the proc, the standard header values, **every database read and write** | Loading the `.rpt`, binding the data, the legacy `CrystalViewer.aspx` experience (paging, zoom, print, export formats, page range, paper size) |
| Database | Yes | **None.** No connection string, no credentials (option **b**) |
| In the repo | the solution (`TflCbsNet10Sol.slnx`) | `TflCbs.ReportViewer/` at the repo root, **outside** the `.slnx` and the arch tests (it is not a .NET 10 assembly) |

## 2. Flow

```
Browser            .NET 10 CBS                                  TflCbs.ReportViewer
  │ submit params ──▶ CbsAccessMiddleware (menu route)
  │                   service: run proc → DataSet  (Result<T>)
  │                   build handoff document
  │                   POST {HandoffUrl}/handoff.ashx ────────────▶ check shared key
  │                     gzip XML, streamed                          spool to {SpoolDir}/{ticket}.xml.gz
  │                   ◀──────────────────────────── 200 {"ticket":…,"expiresInSeconds":60}
  │ ◀── 302 {PublicUrl}/open.aspx?t={ticket}
  │ GET open.aspx?t= ────────────────────────────────────────────▶ redeem: take + delete ticket (single use)
  │                                                                 ReadXml spool → session ReportAttributes
  │                                                                 delete spool file
  │ ◀──────────────────────────────────────────── 302 CrystalViewer.aspx   (ticket leaves the URL)
  │ GET CrystalViewer.aspx ──────────────────────────────────────▶ legacy viewer, unchanged
```

- Handoff is **server-to-server only**; report data never passes through the browser.
- `HandoffUrl` (internal address) and `PublicUrl` (the browser-facing address, normally through the
  gateway) are separate settings.
- After redeeming, `open.aspx` redirects straight away, so the ticket stays out of the address bar and
  history. Every viewer response sends `Referrer-Policy: no-referrer`.

## 3. Payload: the handoff document

One XML document, UTF-8, gzip-compressed, sent as the request body. The .NET 10 side writes it with an
`XmlWriter` over a `GZipStream` over the request stream: **streamed, never held whole in memory**.
The viewer decompresses straight to the spool file.

```xml
<reportHandoff version="1">
  <user id="42" loginName="ratnesh" orgElementId="7" />
  <layout path="Reports/RetailBanking/SeedReports/AccountOpenedReport.rpt" binding="firstTable" draftMode="false" />
  <options paperSize="0" paperOrientation="0" showBackButton="true"
           backUrl="https://cbs.example/RetailBanking/AccountRegister?Source=AccountRegisterOpen" />
  <parameters>
    <!-- standard header values: always sent, computed by .NET 10 (§4) -->
    <p name="BankName">Trust Bank Ltd</p>
    <p name="Branch">(001) Head Office</p>
    <p name="ReportNo"></p>
    <p name="ReportTitle">Account Opened Report</p>
    <p name="PrintingDetails">Printed by 'ratnesh' on 24-Sep-2026 at 14:7</p>
    <!-- report parameters -->
    <p name="FromDate">01/09/2026</p>
    <p name="ToDate">24/09/2026</p>
    <p name="AccountCategory"></p>
    <!-- binding="dataSet" reports may also send typed / sub-report parameters: -->
    <!-- <p name="prmDate" type="date" subreport="Header.rpt">2026-09-24</p> -->
  </parameters>
  <data target="main">
    <!-- DataSet.WriteXml(writer, XmlWriteMode.WriteSchema): inline xs:schema + rows -->
  </data>
  <!-- binding="dataSet" only, one per sub-report that gets its own data: -->
  <!-- <data target="subreport" name="Guarantors.rpt"> … </data> -->
</reportHandoff>
```

### 3.1 Elements

| Element / attribute | Legacy source (`ReportAttributes`) | Rule |
|---|---|---|
| `@version` | none | `1`. The viewer rejects versions it does not know with **400** |
| `user@id`, `@loginName`, `@orgElementId` | `SessionHelper.User` | Audit and logging only. **Not** an authorisation input: .NET 10 authorised before handing off |
| `layout@path` | `ReportPath` / `ReportSource.FilePath`, minus `App_Path` | The legacy **app-relative** path (`Reports/…`, but also `HO/…` and `Inventory/…`), relative to the viewer's `LayoutRoot`, forward slashes, must end `.rpt`. The viewer resolves it and **rejects anything that lands outside `LayoutRoot`** (`..`, rooted paths, other extensions) |
| `layout@binding` | which legacy branch set it | `firstTable`: legacy mode A (`ReportPath` + `DataSet.Tables(0)`). `dataSet`: legacy mode B (`ReportSource`: whole DataSet + sub-report sources + typed parameters). The viewer replays the matching branch exactly |
| `layout@draftMode` | `DraftMode` | `true` → `PrintMode.ActiveX` (IE-only, Phase 4); `false` → `PrintMode.Pdf` |
| `options@paperSize`, `@paperOrientation` | `ReportSource.PrintOptions` | The integer values of `CrystalDecisions.Shared.PaperSize` / `PaperOrientation`. `0` = default, meaning "take it from the layout", as legacy does |
| `options@showBackButton`, `@backUrl` | `ShowBackButton`; legacy Back went to `ReportSelector.aspx` | Back returns to the .NET 10 parameter screen. `backUrl` must start with one of the viewer's `AllowedBackUrlPrefixes`, otherwise the button is hidden (no open redirect) |
| `parameters/p` | `ReportParameter` (Hashtable, string values) and `ReportSource.ReportParameterList` | `@name` is required. `@type` is `string` (default), `number` (invariant culture), `date` (`yyyy-MM-dd`) or `bool`. `@subreport` only with `binding="dataSet"`. Mode A values are strings, exactly as legacy passed them (`uxFromDt.Text`) |
| *parameter routing (1.4)* | CrystalViewer applies `ReportSource.ReportParameterList` first, then `ReportParameter` | `firstTable`: every `<p>` becomes a string in `ReportParameter`, as legacy mode A screens did. `dataSet`: the 5 standard header names (§4) go to `ReportParameter`, which legacy's viewer set last; every other `<p>` becomes a typed entry in `ReportParameterList`, with its sub-report |
| `data[@target='main']` | `DataSet` / `ReportSource.DataSource` | A DataSet written **with its schema**. May be empty (3 layouts take no data) |
| `data[@target='subreport']@name` | `ReportSource.SubReports` | The embedded sub-report name as Crystal reports it (`Guarantors.rpt`). Mode B only |
| *deferred to Phase 3* | `AllowSavingStatutoryReport`, `Statutory*`, `MergeReportData` | Not in v1. The pilot report does not use them. They arrive with the callback design and bump the version |

### 3.2 DataSet rules

- **Always `XmlWriteMode.WriteSchema`.** Crystal binds fields by name *and* type, so a schema-less
  DataSet read back as all-string columns breaks numeric and date formatting.
- **DateTime columns are set to `DataSetDateTime.Unspecified` before writing.** The default
  (`UnspecifiedLocal`) writes the sending server's UTC offset, and a viewer host in another time zone
  would shift every date. Legacy never crossed a process boundary, so it never had this problem.
- No `BinaryFormatter` / `RemotingFormat.Binary`: it is gone from .NET 9+, and XML plus gzip compresses about 10×.
- Column names come from the proc as-is: the layout's field list (`rpt-layout-check.tsv`) is the contract.

## 4. Standard header values

On every render, legacy `CrystalViewer.SetReportOptions` sets five parameters from the database and the
session. Under option (b) the viewer has no database, so **.NET 10 computes them** and sends them as ordinary
`<p>` elements, with the same values and fallbacks:

| Parameter | Legacy logic | .NET 10 source |
|---|---|---|
| `BankName` | `g_BankVariables` `NAME='BANK_NAME'`; on any failure `"[Bank Name not configured]"` | `IBankVariableSource.GetBankVariablesAsync()["BANK_NAME"]`, same fallback text |
| `Branch` | `ReportBranchName` if set, else `"(" & OrgElementCode & ") " & OrgElementName` of the user | caller override, else the session `BussinessUser` |
| `ReportNo` | `ReportTitle` empty and menu found: `A_MENUS.BANKREPORTNO`, else `TRUSTBANKREPORTNO`; otherwise `""` | `A_MENUS` row by menu id |
| `ReportTitle` | `ReportTitle` if set, else `A_MENUS.HEADING` | caller override, else `A_MENUS.HEADING` |
| `PrintingDetails` | `"Printed by '" & LoginName & "' on " & Now.ToString("dd-MMM-yyyy") & " at " & Hour & ":" & Minute` | same format. Minutes are **not** zero-padded (`14:7`); that is legacy output, kept as-is |

`g_ReportSettings` (`reportsettings.LoadReportSettings()`) is also loaded by legacy but never read.
It is not carried over.

## 5. Endpoints

### 5.1 `POST {HandoffUrl}/handoff.ashx`

| | |
|---|---|
| Headers | `X-Cbs-Viewer-Key: <shared key>` · `Content-Type: application/xml` · `Content-Encoding: gzip` |
| Body | the handoff document (§3), gzip, streamed |
| 200 | `{"ticket":"<43 chars base64url>","expiresInSeconds":60}` |
| 400 | unknown `version`, malformed XML, bad `layout@path`, layout file missing |
| 401 | missing or wrong key. Comparison is constant-time |
| 413 | body over the request limit (limits are raised to effectively unbounded; §8) |
| 500 | anything else. The body carries a correlation id only, never data |

The viewer validates the document **after** spooling (parse and check `version`, `layout`, element shape)
and before issuing the ticket, so a bad handoff fails on the server-to-server call, where .NET 10 can
turn it into a `Result` failure, rather than in the user's browser.

### 5.2 `GET {PublicUrl}/open.aspx?t={ticket}`

1. Look up the ticket and **remove it in the same step** (single use). Unknown, used or expired → a
   plain "This report link has expired — run the report again" page. That page has no back link,
   because the ticket that carried `backUrl` is gone.
2. `ReadXml` the spool file into a new `ReportAttributes` in the session. This keeps legacy's
   one-report-per-session rule (`GlobalReportAttributes`), so a new report replaces the previous
   DataSet. Then delete the spool file.
3. `302 CrystalViewer.aspx`.

## 6. Ticket

- **32 random bytes** from a cryptographic RNG, base64url (43 characters). The ticket is a key into the viewer's store, not a signed token.
- The store is in-memory, `{ticket → spool path, user id, login name, created}`.
  *ponytail: in-memory store = single viewer instance (or sticky sessions); a shared store if it ever scales out.*
- **Single use:** removed on redeem, whatever the outcome.
- **Expiry: 60 s** from issue (`TicketSeconds`). A sweep deletes expired tickets and orphaned spool files
  (on each handoff, plus a timer).
- **Not tied to the client IP** (decision 2026-09-24). Single use, 60 s and 256 bits of randomness are the protection.

## 7. Security

- **Access stays fail-closed in .NET 10.** Only a request that passed `CbsAccessMiddleware` for the report's
  menu route can cause a handoff. The viewer trusts the handoff **only** through the shared key, and a browser
  **only** through a ticket.
- **Shared key:** kept in configuration (decision 2026-09-24): the viewer's `web.config`
  (`ReportViewer.SharedKey`) and the .NET 10 `ReportViewer:SharedKey`, with the same value on both sides.
  `CBS_REPORTVIEWER_KEY`, if set, overrides either one. Never logged.
  - `web.config` is committed, so the repo value is a **dev key known to everyone with repo access**. Each
    environment must set its own value in its deployed `web.config` and CBS config.
  - TLS is required outside dev. The handoff endpoint should also be IP-restricted in IIS to the CBS hosts.
- **Layout path traversal:** `layout@path` must resolve inside `LayoutRoot` (§3.1).
- **Open redirect:** `backUrl` is used only if it matches `AllowedBackUrlPrefixes` (§3.1).
- **Viewer session:** its own ASP.NET session cookie (`HttpOnly`, `Secure`, `SameSite=Lax`), InProc, a
  **20-minute** timeout (legacy's value, and under CBS's 25-minute server TTL).
  **Known gap:** a CBS logout does not end the viewer session; the report stays visible in that tab until the
  viewer session times out. Revisit in Phase 3 (a logout call into the viewer).
- **Logging:** ticket hash (never the ticket), user id, layout, compressed bytes, row count, and spool / redeem /
  render times. **Never** data values or the key.

## 8. Configuration

| .NET 10 (`ReportViewer` section) | Meaning |
|---|---|
| `HandoffUrl` | internal base URL for `handoff.ashx` |
| `PublicUrl` | browser-facing base URL for `open.aspx` (through the gateway) |
| `SharedKey` | the handoff key; must equal the viewer's `ReportViewer.SharedKey` (`CBS_REPORTVIEWER_KEY` overrides) |
| `TimeoutSeconds` | the `HttpClient` timeout for the handoff (large reports) |

| Viewer (`web.config` `appSettings`) | Meaning |
|---|---|
| `ReportViewer.LayoutRoot` | folder holding the `Reports/` layout tree |
| `ReportViewer.SpoolDir` | temp folder, writable only by the app pool identity |
| `ReportViewer.TicketSeconds` | default `60` |
| `ReportViewer.AllowedBackUrlPrefixes` | `;`-separated list of CBS origins and paths |
| `ReportViewer.SharedKey` | the handoff key (the repo holds the dev value; each environment sets its own). `CBS_REPORTVIEWER_KEY` overrides it if set |
| `httpRuntime maxRequestLength` / `requestLimits maxAllowedContentLength` / `executionTimeout` | raised to effectively unbounded. **No size cap** (legacy had none, §4.3 item 0.6) |

**Deployment note:** the viewer's `web.config` is part of the site's files, so a redeploy that copies the repo's
`web.config` also resets the key to the dev value. Each environment must re-apply its own key after a redeploy, or
set `CBS_REPORTVIEWER_KEY` on the app pool so the key survives redeploys.

## 9. What the .NET 10 side returns to the screen

**Implementation (1.5):** `TflCbs.Framework.Reports.ReportViewer.OpenAsync(ReportRequest)`. The screen sets the layout, binding, data, its own parameters, `ReportId` (the report's menu id, legacy `Request("reportid")`) and `BackUrl`; the client adds the §4 header values (through the `IReportMenuSource` port for the menu row) and the user. `ReportViewerTransport` is the wire half.

The handoff client returns `Result<string>`: the browser URL `{PublicUrl}/open.aspx?t=…`. The controller
answers with a `302` to it. The browser navigates in the **same window**, as legacy's
`Response.Redirect("..\CrystalViewer.aspx")` did, and Back (§3.1) returns to the parameter screen.
Failures come back as `Result` errors and are shown with the usual CRUD acknowledgement modal:
- an empty result (legacy: `DbRecordNotExists`, "no records")
- viewer unreachable
- 4xx or 5xx from the viewer

## 10. Deliberately not in v1

- Statutory save, e-statement, merged report and submit for consolidation: Phase 3, as callbacks into .NET 10.
- Legacy's `IsStatement=1` (e-statement layout: controls hidden, Send E-Statement shown) and `IsHeadRequired=1`
  (header, footer, export and Back hidden) viewer modes. Legacy set them through the viewer URL. They will need
  `<options>` attributes when their screens migrate (Phase 3).
- Ending the viewer session on CBS logout: Phase 3 (§7).
- Streaming rows straight from the data reader into the XML, so .NET 10 never holds the whole DataSet: only if logged sizes ever call for it.
- A shared ticket store for more than one viewer instance.
