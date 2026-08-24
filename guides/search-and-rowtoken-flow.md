# Search modal + RowToken — visual reference

How the reusable search modal round-trips data, and how `RowToken` keeps real primary keys off
the client. Diagrams are [Mermaid](https://mermaid.js.org/) — they render in VS Code (Markdown
Preview / "Markdown Preview Mermaid Support" extension) and on GitHub.

Source of truth:
- Client: [`cbs-search.js`](../../TflCbs.Web.Shared/wwwroot/js/cbs-search.js) (shared RCL — served from `~/_content/TflCbs.Web.Shared/js/`)
- Endpoint: [`SearchEndpoint.cs`](../../TflCbs.Framework/Services/SearchEndpoint.cs)
- Token: [`RowToken.cs`](../../TflCbs.Framework/Infrastructure/RowToken.cs) · single-use set in [`CbsSessionStore.cs`](../../TflCbs.Framework/Services/CbsSessionStore.cs)
- Worked example: [`StateController.cs`](../../TflCbs.Modules.Hr.Web/Areas/Hr/Controllers/StateController.cs) (screen `Hr/State`, backed by `StateService` in `TflCbs.Modules.Reference`)

---

## 1. Search flow — end to end (sequence)

```mermaid
sequenceDiagram
    autonumber
    actor U as User
    participant JS as cbs-search.js<br/>(modal)
    participant MW as CbsAccessMiddleware<br/>(fail-closed)
    participant C as StateController.SearchData
    participant SE as SearchEndpoint
    participant SVC as StateService<br/>(TflCbs.Modules.Reference)
    participant RT as RowToken
    participant DB as SQL

    U->>JS: click [data-cbs-search] trigger
    JS->>JS: open() → renderFilters / renderHead, show #cbs-search
    U->>JS: type filters + press Search
    JS->>JS: load() builds search.Q / Filters[] / Sort / Page / PageSize
    JS->>MW: GET /Hr/State/search?search.*  (X-Requested-With: fetch)
    MW->>MW: screen "Hr/State" in user's menu?
    Note over MW: not authorized → 403 (fail-closed)
    MW->>C: authorized → invoke action
    C->>SE: RunAsync(fetch, idKey="Id", screen="Hr/State", req)
    SE->>SE: Normalize(page, pageSize)
    SE->>SVC: fetch → SearchStatesAsync(q, name, code, cersai, sort, desc, page, size)
    SVC->>DB: Repository<G_STATE> (GetAllAsync) / QueryAsync
    DB-->>SVC: rows + total
    SVC-->>SE: Result<(rows, total)>  → dictionaries
    loop each row
        SE->>RT: Protect(id, "Hr/State")
        RT-->>SE: opaque token → row["Id"] = token
    end
    SE-->>C: SearchResponse { Rows, Total, Page, TotalPages }
    C-->>JS: return Json(resp)  → 200 application/json
    Note over JS: on !ok → parse {error} → throw → status() message
    JS->>JS: r.json() → state.rows / totalPages
    JS->>JS: renderRows() → #cbs-search-body · renderPager() → #cbs-search-pager
    U->>JS: pick a row
    alt navigateTemplate (State screen)
        JS->>C: GET /Hr/State?row=<token>  (Index resolves → edit form)
    else callback (input picker)
        JS->>JS: applyPick() → fill hidden id + text, lock box
    end
```

**Read it as:** the browser owns rendering (no Razor view for `/search`); the server only
filters/pages, swaps each raw PK for a token, and returns JSON. The picked token round-trips back
to `Index` (diagram 3) or fills a form field.

---

## 2. RowToken payload (what's inside the opaque string)

```mermaid
flowchart LR
    subgraph plain["plaintext payload (joined with '|')"]
        direction LR
        S["screen<br/>'Hr/State'"] --- SID["sid<br/>session GUID"] --- J["jti<br/>Guid.NewGuid()"] --- ID["id<br/>real PK (LAST)"]
    end
    plain -->|"_protector.Protect()<br/>AES encrypt + sign"| TOK["opaque token<br/>(to client)"]

    S -.guards.-> G1["no cross-screen reuse"]
    SID -.guards.-> G2["dies on logout / rotation"]
    J -.guards.-> G3["single-use nonce (writes)"]
    ID -.hidden.-> G4["PK never leaves server"]
```

`id` is placed **last** so a string id may itself contain `|` (split limit 4); `screen`/`sid`/`jti`
never contain `|`.

---

## 3. RowToken lifecycle — mint → resolve → consume (state)

```mermaid
stateDiagram-v2
    direction TB
    [*] --> Minted: search Build()<br/>tokens.Protect(id, screen)
    Minted --> Client: embedded in row["Id"] → JSON

    state "READ — TryResolve (validate only)" as Resolve
    state "WRITE — TryConsume (single-use)" as Consume

    Client --> Resolve: GET ?row=token<br/>(Index / reopen)
    Client --> Consume: POST Form.Row=token<br/>(Update / Delete)

    Resolve --> Loaded: decrypt ok · screen ok · sid ok
    Resolve --> Rejected: tampered / wrong-key /<br/>cross-screen / expired session
    Loaded --> Minted: edit form re-mints a fresh token
    note right of Loaded
        reads never spend the nonce →
        a record can be reopened repeatedly
    end note

    Consume --> CheckNonce: TryRead ok
    Consume --> Rejected: invalid token
    CheckNonce --> Spent: ConsumedRowTokens.Add(jti)==true<br/>→ perform write
    CheckNonce --> Replayed: Add==false<br/>(already submitted / double-click)
    Replayed --> Rejected

    Rejected --> [*]: NotifyError → reopen / search again
    Spent --> [*]: write succeeds
```

**Key distinction:**

| Path | Method | Touches nonce? | Why |
|------|--------|----------------|-----|
| Read (`Index`, reopen) | `TryResolve` | No | record can be reopened any number of times |
| Write (`Update`, `Delete`) | `TryConsume` | Yes — `jti` added to session set | single-use: blocks replay + accidental double-submit |

`Update` deliberately validates the token **first** via `TryBeginWrite` (so a `ModelState` failure
re-renders the form without burning it) and only `TryConsume`s once the write actually proceeds — see
[`StateController.cs:89`](../../TflCbs.Modules.Hr.Web/Areas/Hr/Controllers/StateController.cs#L89) and
[`:94`](../../TflCbs.Modules.Hr.Web/Areas/Hr/Controllers/StateController.cs#L94). `TryBeginWrite` /
`TryOpenRecord` are the `CbsScreenController` wrappers over `RowToken.TryResolve`.

> **Not access control.** Tokens secure the *handoff* (PK confidentiality + integrity + single-use).
> Authorization is still enforced separately by `CbsAccessMiddleware` (menu/route guard) and the
> scoped service calls. A valid token is never a substitute for being allowed on the screen.
