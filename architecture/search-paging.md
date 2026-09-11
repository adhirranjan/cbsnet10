# Search paging — client vs. server

**Decision record + reference.** 2026-09-01.

How the reusable search picker decides whether to page a result set **in the browser** or **on the server**,
why the decision is made where it is, every case the implementation handles, and what is deliberately left
undone.

> **Live demo:** `/Dev/Paging` (Development only). Six pickers over a real database table, with a server
> round-trip counter. See [§7](#7-the-demo-screen).

---

## 1. The problem

A picker dialog showing 10 rows of 25 was issuing a fresh, unfiltered `SELECT` against the whole table on
every single interaction — the initial Search, and then again on every Next and Prev:

```
10:54:14  SELECT [MODULEID], [MODULECODE], [MODULENAME], … FROM [dbo].[A_MODULE]   -- Search
10:54:15  SELECT [MODULEID], [MODULECODE], [MODULENAME], … FROM [dbo].[A_MODULE]   -- Next
10:55:22  SELECT [MODULEID], [MODULECODE], [MODULENAME], … FROM [dbo].[A_MODULE]   -- Next
10:55:23  SELECT [MODULEID], [MODULECODE], [MODULENAME], … FROM [dbo].[A_MODULE]   -- Prev
```

Nothing between two clicks remembered anything. `ModuleService.SearchModulesAsync` loads every row, filters
and sorts in memory, slices 10 out with `ServiceQuery.Paged`, and returns them — the other 15 rows are
garbage before the response is written. The browser only ever received the current page. So page 2 had to
come from somewhere, and the only place it existed was the database.

**"Already fetched" was never true across requests.** The set existed for the duration of one request.

### 1.1 What that actually cost — and what it did not

Measured on the dev database, per Next/Prev click:

| Query | Rows scanned | Time |
|---|---|---|
| `SELECT … FROM a_Module` (unfiltered) | 25 | **1–3 ms** |
| `SELECT COUNT(*) FROM b_UserLogTime` (per-request session guard) | 201,031 | **37–50 ms** |

The screen query was never the problem. `b_UserLogTime` was a 201k-row **heap** whose only index was
`PK_b_UserLogTime(UserLogTimeId)`, while `AuthenticationService.IsSessionActiveAsync` filters on
`UserId + IsOffLine + SessionId` — so it full-scanned on **every authenticated request**, not just this
dialog. That was fixed separately by migration
[`0005_b_userlogtime_session_index.sql`](../../TflCbs.Tools.DbMigrator/Migrations/sqlserver/0005_b_userlogtime_session_index.sql):
**68,383 → 3 logical reads, 204 ms → 0 ms CPU**.

> Recorded here because the two are easy to confuse. Client paging fixes the *round-trips*; the index fixed
> the *cost per round-trip*. Neither substitutes for the other, and neither is the fix for large tables
> ([§8](#8-what-this-does-not-fix)).

---

## 2. The decision

### 2.1 The row count decides, not the screen

A screen cannot choose the mode, because it does not know the row count until it queries. A picker declared
"client-paged" against a table that later grew to 40,000 rows would either fall over or silently ignore the
declaration.

So the screen expresses a **preference**; the **server** decides from the actual count. This is the same
ask-and-be-clamped shape `ServiceQuery` already uses for page size — the caller asks, the app-level bound
wins.

The browser decides nothing. It answers exactly one question: *do I already hold every row?*

```
SearchDescriptor          →  a preference + an optional lower ceiling   (screen)
Cbs:Search:…MaxRows       →  the app-level maximum                      (config)
SearchEndpoint            →  the decision, from the real row count      (server)
cbs-search.js             →  "do I hold everything?"                    (browser)
```

### 2.2 One query decides it — no count-then-fetch

The obvious implementation is *count, then decide, then fetch* — two round-trips on every search. Instead,
**one probe fetch of up to `cap` rows decides the mode and serves the answer either way**:

- **≤ cap rows** → that *is* the whole set. Return all of it, flag it client-paged.
- **\> cap rows** → the delegate has already sorted them, so the first `pageSize` of them *are* page 1.
  Return that slice, flag it server-paged.

Exactly one call to the fetch delegate in every case. The over-cap path fetches `cap` rows and uses
`pageSize` of them — a bounded waste on the first page only, paid once per dialog, in exchange for never
paying a second round-trip on the common path.

### 2.3 The browser only slices — it never filters or sorts

**This is the load-bearing simplification, and it was a change of direction during design.**

The first sketch had the browser filter and sort its cached set too. That creates a second implementation of
"what matches" and "in what order", in a different language, that must agree with the server *forever*. Two
places they drift:

- **What counts as a match.** C# and JavaScript both have case-insensitive contains, and for ordinary text
  they agree. They differ at the edges — most likely on trimming. If the server trims the typed term and the
  browser does not, `admin ` (trailing space) finds one row on a big table and zero on a small one.
- **What order rows come out in.** The server sorts with `StringComparer.OrdinalIgnoreCase` — strict,
  character by character. JavaScript's `localeCompare` uses language rules and orders digits, leading zeros
  and mixed case differently. Real module codes make this concrete: `0010`, `004`, `12`, `123`, `Admin`,
  `AML`.

And the failure mode is invisible: below the cap the browser would sort, above it the server would. **The day
someone adds the 101st row, every user watches the list silently reorder** — no code changed, no deployment
happened, and you cannot reproduce it on a small test database.

So: **page changes slice locally; filter and sort changes refetch.** The server keeps sole ownership of
matching and ordering, the entire parity class of bug disappears, and the original complaint — Next/Prev
refetching — is still fixed completely. The cost is that changing a filter still costs a request, which it
always did.

Bucket 99 of the demo table seeds those seven awkward codes deliberately, so that if anyone later adds
client-side filtering, the rows that expose the mismatch are already sitting there.

---

## 3. The contract

### 3.1 `SearchDescriptor` — what a screen may ask for

`TflCbs.Framework/Models/Search/SearchDescriptor.cs`

```csharp
/// <summary>
/// Opt <b>out</b> of client-side paging for this search (default <c>true</c> = let the server decide
/// from the row count). Set false when the rows change minute to minute (balances, day-end status),
/// when they should not linger in browser memory after the dialog closes, or when acting on a stale
/// row would do real damage — every page change then goes back to the server, as it always has.
/// </summary>
public bool ClientPaging { get; init; } = true;

/// <summary>
/// Per-call ceiling on how many rows the browser may hold (0 = use the app default from
/// <c>Cbs:Search:ClientPagingMaxRows</c>). Clamped to the app maximum exactly as
/// <c>PageSize</c> is clamped to <c>ServiceQuery.MaxPageSize</c> — the caller asks, the app bound wins.
/// Lower it for a grid whose rows carry <c>RowToken</c>s, since each cached row mints one.
/// </summary>
public int ClientPagingMaxRows { get; init; }
```

Both are additive with safe defaults. An existing screen that sets neither gets client paging automatically,
bounded by the app maximum.

### 3.2 `SearchRequest` / `SearchResponse` — the wire

```csharp
// SearchRequest — sent by the widget
/// <summary>
/// How many rows the client is willing to hold so it can page in the browser instead of asking the
/// server for each page. A <b>hint, not an instruction</b>: the server clamps it to the app-level
/// maximum and ignores it entirely when the result set turns out to be larger (see
/// <c>SearchEndpoint</c>). <c>null</c> = the screen opted out of client paging; <c>&lt;= 0</c> = use
/// the app default. Bound from <c>search.ClientCap</c>.
/// </summary>
public int? ClientCap { get; set; }
```

```csharp
// SearchResponse — returned to the widget
/// <summary>
/// True when <see cref="Rows"/> is the <b>entire</b> result set, not one page of it — the client may
/// then page, and only page, in the browser without asking again. False (the default) means one page,
/// so every page change is a fresh request. The client never decides this; the server does, from the
/// row count.
/// </summary>
public bool ClientPaged { get; init; }
```

### 3.3 Configuration

`TflCbs.Host.Main/appsettings.json`

```jsonc
"Cbs": {
  "Search": {
    // Rows a search result may hold in the browser so the widget can page it locally instead of asking
    // the server per page. The SERVER applies this, from the actual row count; a screen may only lower it
    // (SearchDescriptor.ClientPagingMaxRows) or opt out (ClientPaging=false). Clamped to
    // SearchEndpoint.HardClientPagingMaxRows (500); 0 turns client paging off app-wide.
    "ClientPagingMaxRows": 100
  }
}
```

| Knob | Where | Default | Effect |
|---|---|---|---|
| `SearchDescriptor.ClientPaging` | per screen/picker | `true` | `false` → always server-paged |
| `SearchDescriptor.ClientPagingMaxRows` | per screen/picker | `0` (= app default) | may **lower** the ceiling only |
| `Cbs:Search:ClientPagingMaxRows` | app config | `100` | app maximum; `0` disables app-wide |
| `SearchEndpoint.HardClientPagingMaxRows` | const | `500` | config cannot exceed this |

---

## 4. The server side

`TflCbs.Framework/Services/SearchEndpoint.cs` — the whole decision:

```csharp
public async Task<SearchResponse> RunAsync(
    Func<SearchRequest, CancellationToken, Task<(IReadOnlyList<IReadOnlyDictionary<string, object?>> Rows, int Total)>> fetch,
    string idKey, string screen, SearchRequest req,
    CancellationToken ct = default, bool tokenizeId = true)
{
    var (page, pageSize) = Normalize(req);
    var cap = ResolveCap(req, page);

    if (cap > 0)
    {
        // One probe fetch of up to `cap` rows decides the mode AND serves the answer either way — there
        // is no count-then-fetch double round-trip. Under the cap, these rows ARE the whole set. Over it,
        // the delegate has already sorted them, so the first `pageSize` of them ARE page 1.
        var (probeRows, probeTotal) = await fetch(Rescope(req, page: 1, pageSize: cap), ct);

        return probeTotal <= cap
            ? Build(probeRows, probeTotal, idKey, screen, 1, pageSize, tokenizeId, clientPaged: true)
            : Build([.. probeRows.Take(pageSize)], probeTotal, idKey, screen, 1, pageSize, tokenizeId, clientPaged: false);
    }

    var (rows, total) = await fetch(req, ct);
    return Build(rows, total, idKey, screen, page, pageSize, tokenizeId, clientPaged: false);
}
```

The three exclusions, and the clamp:

```csharp
/// <summary>
/// Rows the browser may hold for this request, or 0 for "server-paged, as before". Zero whenever the
/// screen opted out (<see cref="SearchRequest.ClientCap"/> null), for a "Go" (a one-row exact resolve
/// never needs a cache), and for any page but the first (pages 2+ only ever arrive server-paged, since
/// a client holding the whole set would not have asked).
/// </summary>
private int ResolveCap(SearchRequest req, int page)
{
    if (req.ClientCap is not { } asked || req.IsGo || page != 1)
        return 0;
    return asked <= 0 ? _appClientMax : Math.Min(asked, _appClientMax);
}

private static int ResolveAppMax(IConfiguration config)
{
    var configured = config.GetValue<int?>("Cbs:Search:ClientPagingMaxRows") ?? DefaultClientPagingMaxRows;
    return Math.Clamp(configured, 0, HardClientPagingMaxRows);
}
```

The probe never mutates the model-bound request — screens receive a copy:

```csharp
/// <summary>A copy of the request re-scoped to one page — the bound model itself is never mutated.</summary>
private static SearchRequest Rescope(SearchRequest req, int page, int pageSize) => new()
{
    Q = req.Q, Filters = req.Filters, Sort = req.Sort, Desc = req.Desc,
    Mode = req.Mode, ClientCap = req.ClientCap,
    Page = page, PageSize = pageSize,
};
```

**No screen or service changed.** The fetch delegate contract — return the requested page plus the true
total — is exactly what it always was. `SearchEndpoint` simply chooses what to request.

---

## 5. The client side

`TflCbs.Web.Shared/wwwroot/js/cbs-search.js`

**Ask** (a hint only; omitted entirely when the screen opted out):

```javascript
body.set("search.Page", String(state.page));
body.set("search.PageSize", String(d.pageSize || 10));
// A hint only: the server clamps it, and ignores it when the result set turns out to be bigger.
if (d.clientPaging !== false) body.set("search.ClientCap", String(d.clientPagingMaxRows || 0));

fetchJson(d.dataUrl, body, d.method).then(function (res) {
    // clientPaged => res.rows IS the whole result set, so page it here and stop asking.
    state.all = res.clientPaged ? (res.rows || []) : null;
    if (state.all) { renderCachedPage(); return; }
    …
});
```

**Answer the one question** — this is the entire "mode system", one `if`:

```javascript
// Page change only. Everything else (filters, sort) refetches: the server owns which rows match and
// in what order, so there is exactly one implementation of that and no chance of the browser and the
// server disagreeing as a table grows past the cap.
function gotoPage(n) {
    state.page = n;
    if (state.all) renderCachedPage(); else load();
}

// Slice the cached full set. No request, no spinner — this is the whole point of client paging.
function renderCachedPage() {
    var size = state.d.pageSize || 10;
    var total = state.all.length;
    var pages = Math.max(1, Math.ceil(total / size));
    state.page = Math.min(Math.max(1, state.page), pages);
    state.rows = state.all.slice((state.page - 1) * size, (state.page - 1) * size + size);
    state.totalPages = pages;
    state.hi = state.rows.length ? 0 : -1;
    renderRows({ total: total, page: state.page, totalPages: pages, clientPaged: true });
    if (state.rows.length) bodyEl.focus();
}
```

Only the three **page-change** call sites route through `gotoPage`. Prev, Next, and the go-to-page box:

```javascript
var prev = pageBtn("‹ Prev", page > 1, function () { gotoPage(page - 1); });
var next = pageBtn("Next ›", page < pages, function () { gotoPage(page + 1); });
…
if (n !== page) gotoPage(n);
```

Everything else — the Search button, Clear, a sort-header click, Go — still calls `load()`, which clears
`state.all` and refetches.

The cache lives on `state`, which `close()` nulls. **Reopening the dialog always refetches**; there is no TTL
and no invalidation to get wrong.

Round-trips are counted so the demo can prove the win:

```javascript
window.cbsSearchRequests = (window.cbsSearchRequests || 0) + 1; // /Dev/Paging reads this to show round-trips
document.dispatchEvent(new CustomEvent("cbs-search:fetch", { detail: { url: dataUrl, count: window.cbsSearchRequests } }));
```

---

## 6. Every case

`TflCbs.ArchTests/SearchPagingTests.cs` — 14 cases, all passing. The boundary is the only part of this
feature that can break **silently**: nothing in the UI says which mode happened, so if the boundary moves,
or the cap stops being clamped, or a Go starts dragging a hundred rows back, no screen looks wrong. The
tests are the only signal.

| # | Case | Expected | Test |
|---|---|---|---|
| 1 | 1 row, cap 100 | client-paged, whole set, **1 fetch** | `At_or_under_the_cap_the_whole_set_is_sent_once` |
| 2 | 99 rows, cap 100 | client-paged, whole set, 1 fetch | ″ |
| 3 | **100 rows, cap 100** | client-paged — boundary is *at most*, not *fewer than* | ″ |
| 4 | **101 rows, cap 100** | server-paged, `pageSize` rows, **1 fetch** | `Over_the_cap_it_falls_back_to_one_page` |
| 5 | 5,000 rows, cap 100 | server-paged, `pageSize` rows, 1 fetch | ″ |
| 6 | 500 rows, over cap | returned page 1 is the *real* ids 1–10 | `Over_the_cap_page_one_is_the_real_page_one` |
| 7 | `ClientPaging = false`, only 5 rows | server-paged anyway; asks for a page, not the cap | `A_screen_that_opts_out_is_always_server_paged` |
| 8 | `Mode = "go"`, only 5 rows | never client-paged; must not drag the cap back | `Go_is_never_client_paged` |
| 9 | `Page = 3` | no probe; page passed straight through | `Later_pages_are_never_probed` |
| 10 | Caller asks 25, set is 50 | server-paged — the caller's lower ceiling is honoured | `A_caller_may_lower_the_cap_but_not_raise_it` |
| 11 | Caller asks 100,000 | clamped to the app maximum | ″ |
| 12 | Config sets 10,000 | clamped to `HardClientPagingMaxRows` (500) | `Configuration_cannot_raise_the_cap_past_the_hard_ceiling` |
| 13 | No config key | `DefaultClientPagingMaxRows` (100) | `Absent_configuration_uses_the_documented_default` |
| 14 | Config `0` | client paging off app-wide | `Client_paging_can_be_disabled_app_wide` |
| 15 | Any probe | the bound `SearchRequest` is left untouched | `The_probe_does_not_mutate_the_bound_request` |

Every case also asserts the fetch delegate ran **exactly once** — the point of the probe design.

The boundary cases in bold are the ones a small test database would never reach on its own. That is exactly
why they are asserted rather than demonstrated.

```csharp
[Theory]
[InlineData(1)]
[InlineData(99)]
[InlineData(100)] // the boundary is "at most the cap", not "fewer than"
public async Task At_or_under_the_cap_the_whole_set_is_sent_once(int total)
{
    var (fetch, calls, _) = Source(total);

    var res = await Run(Endpoint(), fetch, Req());

    Assert.True(res.ClientPaged);
    Assert.Equal(total, res.Rows.Count); // the WHOLE set, not one page of it
    Assert.Equal(total, res.Total);
    Assert.Equal(1, calls());
}

[Theory]
[InlineData(101)] // one row over — the case a small test database would never reach
[InlineData(5000)]
public async Task Over_the_cap_it_falls_back_to_one_page(int total)
{
    var (fetch, calls, _) = Source(total);

    var res = await Run(Endpoint(), fetch, Req(pageSize: 10));

    Assert.False(res.ClientPaged);
    Assert.Equal(10, res.Rows.Count);
    Assert.Equal(total, res.Total);
    Assert.Equal(1, calls()); // the probe served page 1 too — no count-then-fetch second trip
}

[Fact]
public async Task A_caller_may_lower_the_cap_but_not_raise_it()
{
    var (lowFetch, _, lowLast) = Source(50);
    var lowered = await Run(Endpoint(), lowFetch, Req(clientCap: 25));
    Assert.False(lowered.ClientPaged);      // 50 rows, but this caller only wanted 25
    Assert.Equal(25, lowLast().PageSize);

    var (highFetch, _, highLast) = Source(50);
    var raised = await Run(Endpoint(), highFetch, Req(clientCap: 100_000));
    Assert.True(raised.ClientPaged);
    Assert.Equal(AppMax, highLast().PageSize); // clamped to the app maximum, not honoured
}
```

---

## 7. The demo screen

`/Dev/Paging` — Development only (404s otherwise), `[CbsSkipMenuCheck]`, sibling of `/Dev/Components`.
That one shows what the components look like; this one shows **how many times they talk to the server**.

Deliberately backed by a **real database table**, not canned in-memory rows — the point is to prove the SQL,
not to draw the UI.

### 7.1 The table

[`scripts/dev-picker-demo-table.sql`](../../scripts/dev-picker-demo-table.sql). **Not a DbMigrator
migration**, so it can never reach a production schema. Run it by hand:

```
sqlcmd -S <server> -d <db> -U <user> -P <pwd> -C -i scripts\dev-picker-demo-table.sql
```

Each `Bucket` value holds exactly that many rows, putting the cap boundary either side of a picker without
touching configuration:

| Bucket | Rows | Mode | What it shows |
|---|---|---|---|
| 99 | 99 | client-paged | Under the cap. One request, then 10 free local pages. |
| 100 | 100 | client-paged | Exactly the cap — the boundary is inclusive. |
| 101 | 101 | server-paged | One row over. A page per request; nothing else changes. |
| 5000 | 5,000 | server-paged | A set worth paging, paged **in the database**. |

Bucket 99 also carries seven deliberately awkward codes — `0010`, `004`, `12`, `123`, `admin`, `Admin`,
`AML` — the leading-zero, bare-digit and same-letters-different-case rows that would expose a filter/sort
mismatch if the browser ever started doing that work ([§2.3](#23-the-browser-only-slices--it-never-filters-or-sorts)).

### 7.2 The six pickers

Same action, same table; only the bucket and the two knobs differ:

```csharp
SearchDescriptor Desc(string title, int bucket, bool clientPaging = true, int maxRows = 0) => new()
{
    Title = title,
    DataUrl = $"/Dev/Paging/search?bucket={bucket}",
    Method = "GET",
    IdKey = "Id",
    Columns = [new SearchColumn("Code", "Code"), new SearchColumn("Name", "Name"), new SearchColumn("Status", "Status")],
    Filters = [new SearchFilter("Name", "Name"), new SearchFilter("Code", "Code")],
    GoFilterKey = "Code",
    PageSize = 10,
    AutoLoad = true,
    SelectMode = "callback",
    PickValueKey = "Id",
    PickTextKey = "Code",
    ClientPaging = clientPaging,
    ClientPagingMaxRows = maxRows,
};

var p99   = Picker("pg99",   Desc("Demo — 99 rows", 99));
var p100  = Picker("pg100",  Desc("Demo — 100 rows", 100));
var p101  = Picker("pg101",  Desc("Demo — 101 rows", 101));
var p5000 = Picker("pg5000", Desc("Demo — 5,000 rows", 5000));
var pOff  = Picker("pgOff",  Desc("Demo — caching off", 99, clientPaging: false));   // opt-out
var pLow  = Picker("pgLow",  Desc("Demo — per-call cap 25", 99, maxRows: 25));       // lower ceiling
```

### 7.3 How to read it

Open a picker, then click **Next** and **Prev** several times, watching the round-trip counter:

- **99 / 100** — the counter does not move after the first request.
- **101 / 5000** — it climbs by one per page.
- **caching off / cap 25** — same 99 rows as the first picker, but the counter climbs. The opt-outs work.
- **Go** — type `D0007` and press Go in any picker: exactly one request, whatever the bucket.

### 7.4 The reference for real server-side paging

`TflCbs.Modules.General/PickerDemoService.cs` is the only service in the solution that is **genuinely
server-paged** — a COUNT plus an `ORDER BY … OFFSET/FETCH` page, both composed with the dialected `SqlQuery`
builder (no hand-written SQL, per the CLAUDE.md rule). The masters still load everything and page in memory.

```csharp
// One builder shape, used twice: once counted, once paged. WhereIf keeps an absent filter out
// of the SQL entirely rather than emitting "(@p IS NULL OR …)", which would defeat the index.
SqlQuery Filtered() => SqlQuery.From<DEV_PICKERDEMO>("d", data.Options.Provider)
    .Where(DEV_PICKERDEMO.Cols.BUCKET.As("d"), "=", bucket)
    .WhereIf(hasCode, DEV_PICKERDEMO.Cols.CODE.As("d"), exact ? "=" : "LIKE", exact ? c : $"%{c}%")
    .WhereIf(hasName, DEV_PICKERDEMO.Cols.NAME.As("d"), "LIKE", $"%{n}%");

var countRow = await Filtered().Select(Agg.Count("Total")).ToDictionariesAsync(data, ct);
var total = countRow.Count == 1 && countRow[0].TryGetValue("Total", out var t) ? Convert.ToInt32(t) : 0;
if (total == 0) return Ok([], 0);

var rows = await Filtered()
    .SelectCols(
        DEV_PICKERDEMO.Cols.DEMOID.As("d").As("Id"),
        DEV_PICKERDEMO.Cols.CODE.As("d").As("Code"),
        DEV_PICKERDEMO.Cols.NAME.As("d").As("Name"),
        DEV_PICKERDEMO.Cols.STATUS.As("d").As("Status"))
    .OrderBy(sortCol.As("d"), desc)
    .Page((page - 1) * pageSize, pageSize)
    .ToDictionariesAsync(data, ct);
```

Verified from the SQL Server plan cache — not merely from a passing test:

```sql
(@tflw0 int)
SELECT d.[DemoId] AS Id, d.[Code] AS Code, d.[Name] AS Name, d.[Status] AS Status
FROM dev_PickerDemo d
WHERE d.[Bucket] = @tflw0
ORDER BY d.[Code] DESC OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY
```

`TflCbs.Tests/PickerDemoServiceTests.cs` covers it against the live database — exact bucket counts, disjoint
page slices, the short last page (bucket 101, page 11 → 1 row), exact-vs-contains resolve, the empty result,
and every sort key on every dialect. **All six skip silently where the table does not exist**; a skip means
"not set up here", never a failure.

---

## 8. What this does **not** fix

**Large tables are exactly as slow as before.** In server mode the real master services still call
`GetAllAsync` and page in memory. Client paging made small sets fast — `a_Module` is 25 rows and took 1 ms;
it was never the problem.

The fix for large tables is pushing the filter into SQL, and it has a genuine blocker: `ServiceQuery.Has`
becomes a SQL `LIKE`, which is **case-sensitive on Oracle and PostgreSQL**. Searching `admin` would stop
finding `Admin`. The TflOmniDb expression translator supports `Contains`/`StartsWith`/`EndsWith` → `LIKE`,
but has no `ToUpper`. Three ways out, none yet chosen:

1. Require a case-insensitive collation on Oracle/PostgreSQL deployments.
2. Emit a provider-specific predicate (`ILIKE` on PostgreSQL, `UPPER()` on Oracle).
3. Persist a lowercase shadow column on the searchable fields and match on that.

`PickerDemoService` is written the way the masters should be written, and its XML doc flags this explicitly —
it is only correct today because SQL Server's default collation is case-insensitive.

### 8.1 Known costs, accepted

- **Token minting.** A tokenized grid mints a `RowToken` (encrypted, ~200 bytes) per cached row, of which the
  user clicks one. At cap 100 that is ~20 KB of waste per search. This is the reason the cap is 100 and the
  hard ceiling 500 — not an arbitrary number. Reference pickers (`tokenizeId: false`) pay none of it.
- **Staleness.** A cached set goes stale while the dialog is open. This is a **display** concern, not a
  correctness one: tokenized ids are session-bound and resolved against live data on use, and reference ids
  are re-validated as FKs on save. A stale pick fails safely.
- **Over-cap first page.** Fetches `cap` rows, uses `pageSize`. Paid once per dialog on the uncommon path.

### 8.2 Not done

- **Cap relative to page size.** A cap of 100 with `PageSize = 50` buys two local pages — barely worth the
  branch. "Client-page while total ≤ 10 × pageSize, clamped to the app max" would degrade better. Not
  implemented; revisit if a screen sets a large page size.
- **The Module picker's Go still contains-matches.** `ModuleService.SearchModulesAsync` has no `exact`
  parameter, so Go on that picker is a browse, not a 0/1 resolve — the only Go call site in the solution that
  is not exact. With live data, typing `12` matches `12` *and* `123`; `REC` matches four codes; `Inv` matches
  `Inv` and `Invoice`. The client copes (>1 row opens the disambiguation dialog) but Go exists to skip it.
  Unrelated to paging; recorded here because it was found alongside.

---

## 9. Files

| File | What changed |
|---|---|
| `TflCbs.Framework/Services/SearchEndpoint.cs` | The decision: probe, cap resolution, clamping, `Rescope` |
| `TflCbs.Framework/Models/Search/SearchRequest.cs` | `+ ClientCap` |
| `TflCbs.Framework/Models/Search/SearchResponse.cs` | `+ ClientPaged` |
| `TflCbs.Framework/Models/Search/SearchDescriptor.cs` | `+ ClientPaging`, `+ ClientPagingMaxRows` |
| `TflCbs.Web.Shared/wwwroot/js/cbs-search.js` | `state.all` cache, `gotoPage`, `renderCachedPage`, round-trip counter |
| `TflCbs.Host.Main/appsettings.json` | `Cbs:Search:ClientPagingMaxRows` |
| `TflCbs.Modules.General/PickerDemoService.cs` | Demo service + hand-written `DEV_PICKERDEMO` entity |
| `TflCbs.Modules.General/GeneralModule.cs` | Registers `PickerDemoService` |
| `TflCbs.Core.Shell.Web/Controllers/PagingDemoController.cs` | `/Dev/Paging` |
| `TflCbs.Core.Shell.Web/Views/PagingDemo/Index.cshtml` | The showcase |
| `TflCbs.ArchTests/SearchPagingTests.cs` | 14 boundary cases |
| `TflCbs.Tests/PickerDemoServiceTests.cs` | 6 live-database cases |
| `scripts/dev-picker-demo-table.sql` | The dummy table |

The entity is hand-written and lives beside its service rather than in `TflCbs.Entities`, which is machine
generated from the real CBS schema — a hand-added class there would be lost on the next regeneration, and
would imply the table belongs to CBS.

**No screen, service or view outside the demo was modified.** Every existing picker gained client paging
without a line of change, because the decision moved into `SearchEndpoint` rather than into the screens.

---

## 10. Verification

| Suite | Result |
|---|---|
| `dotnet build TflCbs.Host.Main` | clean — 0 warnings, 0 errors |
| `node --check cbs-search.js` | OK |
| `dotnet test TflCbs.Tests` | 160 passed |
| `dotnet test TflCbs.ArchTests` | 108 passed (incl. 14 new) |
| `dotnet test TflCbs.IntegrationTests` | 76 passed |

Runtime: app started in Development, `/Dev/Paging` served, generated SQL confirmed from the plan cache, app
stopped.
