# Know your code — CBS coding help & FAQ

Answers to "how does this actually work, and how do I not break it" for the .NET 10 CBS codebase.
Companion to [`screens-code-guide-xnet-7.md`](screens-code-guide-xnet-7.md), which is per-screen; **this
file is per-mechanism** and grows as questions come up.

**Adding an entry:** one `##` section per mechanism, numbered, with a line in the Contents. End each section
with a *Cheat sheet* and a *Ways to get it wrong* list — those two are what people come back for.

## Contents

- [1. Row tokens — the four helpers](#1-row-tokens--the-four-helpers)
  - [1.1 What a token actually is](#11-what-a-token-actually-is)
  - [1.2 The four methods](#12-the-four-methods)
  - [1.3 The order on an update, and why](#13-the-order-on-an-update-and-why)
  - [1.4 The re-mint rule](#14-the-re-mint-rule)
  - [1.5 Cheat sheet](#15-cheat-sheet)
  - [1.6 Four ways to get it wrong](#16-four-ways-to-get-it-wrong)
  - [1.7 What tokens are not](#17-what-tokens-are-not)
- [2. Portable column types — the two banned SQL Server types](#2-portable-column-types--the-two-banned-sql-server-types)
  - [2.1 The rule](#21-the-rule)
  - [2.2 Why, and how both were found](#22-why-and-how-both-were-found)
  - [2.3 Where the translation happens now](#23-where-the-translation-happens-now)
  - [2.4 Cheat sheet](#24-cheat-sheet)
  - [2.5 Five ways to get it wrong](#25-five-ways-to-get-it-wrong)

---

## 1. Row tokens — the four helpers

```csharp
TryOpenRecord(token, out id)   // GET  — resolve only, survives refresh
TryBeginWrite(token, out id)   // POST — resolve only, NOT yet spent
TryConsume(token, out id)      // POST — single-use, records the nonce in session
ProtectId(id)                  // mint a fresh token for the form
```

Source: [`RowToken.cs`](../TflCbs.Framework/Infrastructure/RowToken.cs) and
[`CbsScreenController.cs`](../TflCbs.Framework/Infrastructure/CbsScreenController.cs).

### 1.1 What a token actually is

When the search modal lists denomination units, each row has to carry *which* row it is. The obvious way is
the real database id:

```
/Bank/DenominationUnit?id=18
```

That is exactly what legacy did (`Request("id")`). The problem: anyone can type `?id=19` and open a record
they were never shown, and nothing stops them replaying that URL tomorrow.

So the server hands out a **token** instead — a scrambled string that stands in for the id:

```
/Bank/DenominationUnit?row=CfDJ8Hk...long...encrypted...string
```

Inside that string, encrypted so the browser can neither read nor fake it, are **four** things:

```
screen | sessionId | nonce | id
  |          |         |      └── the real row id (18)
  |          |         └───────── a random one-time serial number for THIS token
  |          └─────────────────── which login session it was made for
  └────────────────────────────── which screen it was made for
```

Encryption is `IDataProtector` (AES + tamper detection + managed key rotation). Change one character and it
fails to decrypt. That is why all four fields can be trusted once it opens.

**Reading a token = three checks:** does it decrypt · was it made for *this* screen · was it made for *this*
session. Any failure means invalid — and the user is told so, no exception is thrown.

> The id is placed **last** in the payload on purpose, so a string id may itself contain `|`. Screen, session
> and nonce never do.

### 1.2 The four methods

All four are thin wrappers over the same reader. What differs is **whether the token is used up**, and
**which message the user sees on failure**.

#### `ProtectId(id)` — make a token

```csharp
vm.Form.Row = ProtectId(unitId.ToString());
```

Takes a real id, returns a fresh token with a brand-new random nonce. Call it whenever you put an editable
record on screen. Every call produces a *different* token, even for the same row.

#### `TryOpenRecord(token, out id)` — GET, just look

```csharp
if (!TryOpenRecord(row, out var idStr) || !int.TryParse(idStr, out var unitId))
    return View(vm);
```

Checks the token, gives you the id, and **leaves it usable**.

Why not spend it? Because reads repeat constantly: the user presses F5, hits Back, or the browser
re-requests an `<img>`. If opening a record burned the token, a refresh would throw the user out with "this
link expired" for doing nothing wrong.

Failure message: *"That link is invalid or has expired. Please search again."*

#### `TryBeginWrite(token, out id)` — POST, get the id but don't spend it yet

```csharp
if (!TryBeginWrite(form.Row, out var idStr) || !int.TryParse(idStr, out var unitId))
    return Redirect(HostUrl);
```

Identical checking to `TryOpenRecord`; the only difference is the wording on failure (*"…Please reopen the
record."* — on a POST the user did not arrive from a search).

It exists for one reason: on an update you need the id **before** you know whether the form is valid. Spend
the token here and a validation failure would cost the user the record.

#### `TryConsume(token, out id)` — POST, spend it

```csharp
if (!TryConsume(form.Row, out _, MsgAlreadyDone))
    return Redirect(HostUrl);
```

Same three checks **plus** one more step: the nonce is recorded in the session as used. A second attempt
with the same token fails, even though the token is still cryptographically perfect.

That single-use property is what stops:

- **double-click on Save** — two requests arrive, the second is refused;
- **back button then re-submit** — same token, already spent;
- **replay** — someone re-sending a captured request.

Failure message: *"This action was already submitted. Please reopen the record."*

### 1.3 The order on an update, and why

```csharp
// 1. resolve — I need the id, but don't spend the token yet
if (!TryBeginWrite(form.Row, out var idStr) || !int.TryParse(idStr, out var unitId))
    return Redirect(HostUrl);

// 2. validate — if this fails, EditFailed re-renders with a NEW token
if (!ModelState.IsValid)
    return EditFailed(idStr, form, FirstError());

// 3. consume — past the point of no return, spend it
if (!TryConsume(form.Row, out _, MsgAlreadyDone))
    return Redirect(HostUrl);

// 4. the actual write
var result = await svc.UpdateDenominationUnitAsync(unitId, ...);
```

**resolve → validate → consume.** Swap steps 2 and 3 and the screen still works in testing — but the first
user who mistypes a field loses the record and has to search for it again.

Delete skips step 2 entirely and consumes immediately: there is nothing to validate.

### 1.4 The re-mint rule

A consumed token is dead. So **any time you send the user back to a form after consuming, mint a new one** —
otherwise their retry fails for a reason they cannot see.

```csharp
var result = await holds.UpdateHoldAsync(...);
if (!result.IsSuccess)
{
    this.NotifyError(result.ErrorString);
    form.Row = ProtectId(holdId.ToString());  // ← prior token consumed; issue a fresh one
    return View(nameof(Index), form);
}
```

`EditFailed(...)` and `RedirectToRecord(...)` already do this for you — that is their whole purpose. Reach
for them instead of hand-rolling the re-render.

### 1.5 Cheat sheet

| Situation | Call | Spends the token? |
|---|---|---|
| GET, opening a record from a search | `TryOpenRecord` | no |
| GET, serving a file or image by token | `TryOpenRecord` | no — the browser re-requests |
| POST, need the id before validating | `TryBeginWrite` | no |
| POST, about to write / authorize / delete | `TryConsume` | **yes** |
| Rendering an editable form | `ProtectId` | n/a — creates one |
| Re-rendering after a failed write | `ProtectId` (via `EditFailed`) | n/a — creates one |

Every helper takes an optional `screen:` argument. It defaults to the controller's `Screen` property; pass
it explicitly on any controller that hosts more than one screen key.

The id is a **string** end-to-end, on purpose — primary keys differ per table. Parse it at the call site:
`int` for Denomination Unit, `decimal` for User (`a_User.USERID` is numeric). Parsing a decimal key as `int`
would silently narrow it.

### 1.6 Four ways to get it wrong

1. **Consuming on a GET.** Refresh breaks the page.
2. **Consuming before validating.** A typo costs the user the record.
3. **Forgetting to re-mint after a failed write.** The retry mysteriously fails.
4. **Forgetting `screen:` on a multi-screen controller.** On Holding Amount the default screen is Entry, so
   an Authorize-screen token must say so on **both** sides:
   ```csharp
   form.Row = ProtectId(holdId.ToString(), screen: AuthScreenKey);
   TryConsume(form.Row, out var idStr, screen: AuthScreenKey);
   ```
   Miss it on one side and the screen check fails — every authorize post is refused.

A related design point worth copying: Signature gives its image endpoint its **own** key
(`RetailBanking/Signature/Image`) so an image token can never be spent as a record token. Different
capability, different key.

### 1.7 What tokens are not

They are **not** permission. A token proves only "the server showed you this row, on this screen, in this
session". Access is enforced separately:

- `CbsAccessMiddleware` checks the menu right (fail-closed, derived from `a_UserRights`);
- the service re-checks branch scope (`LoadHoldAsync(id, OrgElementId)`) and maker/checker rules on every
  call.

Tokens secure the **handoff**. The guard and the service are the access control.

---

## 2. Portable column types — the two banned SQL Server types

```
flag  →  INT holding 0/1        never BIT, NUMBER(1), BOOLEAN
GUID  →  CHAR(36) UPPERCASE     never UNIQUEIDENTIFIER, RAW(16), UUID
```

SQL Server, Oracle and PostgreSQL are all production targets. A column type only one of them can bind is a
defect — and, as below, a defect the read path hides.

Sources: [`ParameterValue.cs`](../libs/TflOmniDb/TflOmniDb/Repository/ParameterValue.cs), the migration
scripts `scripts/bit-to-int.sqlserver.sql` and `scripts/guid-to-char36.{sqlserver.sql,oracle-verify.sql}`,
and the full rationale in [`xnet-scripts-sqlserver.sql`](xnet-scripts-sqlserver.sql).

### 2.1 The rule

| | SQL Server | Oracle | PostgreSQL | Entity property | `CoreDataType` |
|---|---|---|---|---|---|
| flag | `INT` | `NUMBER(10,0)` | `INTEGER` | `int?` | `Int32` |
| GUID | `CHAR(36)` | `CHAR(36 CHAR)` | `CHAR(36)` | `string?` | `AnsiStringFixed` |

In code:

```csharp
if (user.ALLOWOTHERBRANCHAPPROVAL == 1)                  // not == true, not ?? false
    …

row.GUID = Guid.NewGuid().ToString().ToUpperInvariant();  // never .ToString() alone
```

This applies to **new** tables too, not only conversions. Declare the portable type from the start; in SQL
Server a GUID default is `DEFAULT (CONVERT(char(36), newid()))`.

> The TflOmniDb datatype-mapping docs map `BIT` → `Boolean` → `NUMBER(1,0)` → `BOOLEAN`. That is the
> **library default**, not this project's convention. `INT` wins here.

### 2.2 Why, and how both were found

Oracle's managed provider cannot bind either CLR type:

- a CLR `bool` parameter → **ORA-00932**, inconsistent datatypes;
- a CLR `Guid` parameter → `DbType.Guid` → **`ArgumentException`**.

Both were invisible for months because **the read path coerces**. `ColumnDescriptor.SetValue` and
`PocoMaterializer` run `Convert.ChangeType` and `Guid.Parse`, so `NUMBER(10,0)` reads back into a `bool?`
and `CHAR(36)` into a `Guid?` quite happily. Every read test passed. Every *write* of those columns had
been failing on Oracle since the port, and nothing said so.

That is the general lesson, not a footnote: **a read-only test suite proves nothing about the write path on
a second provider.** Screen coverage in this repo is therefore round-trip — create, search, update, search,
delete — see [screens-code-guide-xnet-7.md → Cross-provider verification](screens-code-guide-xnet-7.md#cross-provider-verification).

### 2.3 Where the translation happens now

Nowhere, for flags and GUIDs — that is the point. What the code holds is what the column holds, on all three
providers, so there is no conversion left to get wrong.

The DAL keeps two narrow adjustments, both in `ParameterValue`, and both exist for cases the convention does
**not** cover:

```csharp
Normalize(provider, value)          // a stray CLR bool → 1/0 on Oracle; null → DBNull
TypeForNull(provider, value, col)   // SQL Server only: a null parameter is typed from its
                                    // ColumnDescriptor, because ADO.NET infers nvarchar from
                                    // DBNull and SQL Server refuses nvarchar → binary (Msg 257)
```

`TypeForNull` is deliberately SQL-Server-only: declaring the mapped `DbType` on Oracle breaks every insert,
because ODP.NET rejects `DbType.Guid` and `DbType.DateTime2` outright. Covered by `ParameterTypingTests`
(no database needed).

### 2.4 Cheat sheet

| You are… | Do this |
|---|---|
| adding a flag column | `INT` (`NUMBER(10,0)` / `INTEGER`); entity `int?` |
| adding a GUID column | `CHAR(36)`; entity `string?`; SQL Server default `CONVERT(char(36), newid())` |
| reading a flag | `x.ISACTIVE == 1` |
| writing a flag | `1` / `0` |
| writing a GUID | `Guid.NewGuid().ToString().ToUpperInvariant()` |
| binding a checkbox | `bool` lives in the Razor view model only — convert in the controller |
| converting an existing column | run the script, regenerate the entity, then fix the call sites (the build finds them) |

### 2.5 Five ways to get it wrong

1. **`.ToString()` without `.ToUpperInvariant()`.** It writes lowercase; every `CHAR(36)` comparison against
   an existing row then fails to match. Nothing throws — the row is simply never found.
2. **`== true` or `?? false` on a flag.** Does not compile against `int?`, which is the good case; what does
   compile is a sloppy `!= 0`, which quietly accepts 2.
3. **Declaring `bool` on a new service DTO.** It works on SQL Server and dies on Oracle at the first write.
   Keep `bool` in the view model, `int` from the controller inwards.
4. **Trusting a green test run.** A provider whose connection string is empty is *skipped*, not failed, and
   a read-only test passes on a write path that has never worked.
5. **Assuming `INT` enforces 0/1.** `BIT` did; `INT` does not, on any provider. No `CHECK (col IN (0,1))`
   exists on these columns yet — still open.
