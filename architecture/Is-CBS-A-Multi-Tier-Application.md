# Is TrustBank CBS a Multi-Tier Application?

Decision record and clarification. Companion to
[Why-Modular-Monolith-Not-Microservices.md](Why-Modular-Monolith-Not-Microservices.md) (why the
business layer is not distributed) and [modular-monolith.md](modular-monolith.md) (how it is split).
This document answers a question that is asked often and answered loosely: **is this a three-tier
application — web server, application server, database server?**

> **Short answer.** **Logically, yes** — it is a strictly layered application: presentation,
> business, data access, database, with the separation enforced by the compiler and the build, not
> by convention. **Physically, no — not in the classic sense.** There is no separate application
> server. Presentation and business logic are compiled into one process. The default deployment is
> **two server tiers** (app + database); with the gateway deployed it is **three** (edge + app +
> database) — but the middle tier is a *web* tier, not an *application* tier. The classic
> application-server tier is the one piece we deliberately left out, and §5 explains why.
> Last reviewed 24 August 2026.

---

## 1. The question is really two questions

The phrase "three-tier" is used for two different things, and most disagreements about it are
vocabulary rather than architecture:

| Term | Means | Unit | Question it answers |
|---|---|---|---|
| **Layer** (logical) | A separation of *code responsibilities* | Assembly / namespace | "Can the business logic be changed without touching the UI?" |
| **Tier** (physical) | A separation of *deployment units* | Process / machine | "Do these run on different servers?" |

A system can be three-layer and one-tier (very common, and it is what we are). It can also be
one-layer and three-tier — a big ball of mud copied onto three servers — which is the worst of both.
The valuable property is the **layer** separation; the **tier** separation is a deployment decision
that should be made on its own merits.

We answer each below with what is actually in the repository.

---

## 2. Logically: yes — a strictly layered application

| Layer | What it is here | How the separation is enforced |
|---|---|---|
| **Client** | The browser. Server-rendered Razor plus progressive enhancement (`cbs-search.js`, `cbs-account-picker.js`, `cbs-datepicker.js`, `cbs-idle.js`). No SPA framework, no client-side business rules. | Business decisions never leave the server |
| **Presentation** | Razor Class Libraries: 5 domain `*.Web` RCLs, 2 core RCLs (auth, shell), and `TflCbs.Web.Shared` for layout/partials/assets | Screens live only in RCLs; the host's own `Views/`/`wwwroot/` are empty |
| **Cross-cutting framework** | `TflCbs.Framework` — session, access guard, tokens, search infrastructure, DAL wiring | References **only** `TflCbs.Abstractions`. It cannot reference a screen or a business module — compiler-enforced and arch-tested |
| **Business** | 9 module assemblies: `TflCbs.Modules.*` + `TflCbs.Core.Authentication`, returning `Result`/`Result<T>` | **Zero ASP.NET references.** A service physically cannot touch `HttpContext`, `Session` or a cookie — arch-tested |
| **Data access** | `TflOmniDb`: `Repository<T>`, `DataAccess.QueryAsync`, `ExecuteInTransactionAsync`; entities in `TflCbs.Entities` | Services never build a connection or see a connection string |
| **Database** | SQL Server / Oracle / PostgreSQL | Provider chosen by `DatabaseSelector`; the same business code runs on all three — proven by 149 cross-provider tests |

**The floor is `TflCbs.Abstractions`** — dependency-free, holding `Result<T>`, the module contract and
the four framework ports. Everything above compiles against it, which is what keeps the layering
acyclic.

### The proof that the layering is real

Two observations, neither of which is available in a typical "layered" application where the
separation is only a folder convention:

- **The business layer runs with no web server at all.** `TflCbs.Demo` (a console app) and
  `TflCbs.Tests` reference the same module assemblies and exercise every service method directly.
  If any business rule had leaked into a controller, those would not compile or would not pass.
- **The layering fails the build when crossed.** 94 architecture tests run on every build —
  framework ⊥ screens, namespace == assembly, module isolation, no ASP.NET in a module. The suite
  also guards itself: a meta-check verifies each rule is still capable of failing.

### One request, end to end

```
Browser
  → Kestrel (behind IIS/ANCM or in a container)
  → Routing
  → CbsAccessMiddleware        (fail-closed menu/route guard — Framework)
  → Controller                 (presentation — inside a *.Web RCL)
  → Service                    (business — inside a TflCbs.Modules.* assembly)  ← returns Result<T>
  → Repository<T> / DataAccess (data access — TflOmniDb)
  → Database                   (SQL Server | Oracle | PostgreSQL)
```

Every arrow above is an in-process call except the last one. That is the whole physical story, and
it leads directly to §3.

---

## 3. Physically: how many tiers actually run

The platform ships in four deployment shapes from one codebase. They differ in **tier count**, not in
layering.

### 3.1 Single host (IIS single, Docker single)

```
[ Browser ]  →  [ TflCbs.Host.Main : Kestrel + RCLs + modules + DAL ]  →  [ Database server ]
   client                        ONE process                                    tier 2
                                    tier 1
```

**Two server tiers.** Presentation and business are the same process; the only network boundary
inside the system is the database connection. (Under IIS, the ASP.NET Core Module proxies to Kestrel
— that is a hosting detail within one tier, not a tier of its own.)

### 3.2 Multi host (IIS multi, Docker multi)

```
[ Browser ] → [ TflCbs.Gateway ] → [ Host.Main + 4 thin hosts ] → [ Database server ]
   client       YARP reverse         each: RCLs + its modules          tier 3
                proxy — tier 1              + DAL — tier 2
```

**Three server tiers** — and this is the shape most people mean when they say the system "is
three-tier". But note precisely what the middle boundary is: the gateway is a **pure reverse proxy**
(`TflCbs.Gateway/Program.cs` — YARP, rate limiting, health, tracing; no `CbsFramework` reference, no
DB access, no views). It routes; it does not render and it does not decide.

Each backend host still renders its own HTML *and* runs its own business logic. So the multi-host
shape is a **horizontal split by module**, not a vertical split by tier.

### 3.3 Side by side

| | IIS single | Docker single | IIS multi | Docker multi |
|---|---|---|---|---|
| Server processes | 1 | 1 container | 6 sites | 6 containers |
| Server tiers | 2 | 2 | 3 | 3 |
| Separate *web* tier | No | No | **Yes** (gateway) | **Yes** (gateway) |
| Separate *application* tier | **No** | **No** | **No** | **No** |
| Presentation + business in one process | Yes | Yes | Yes (per host) | Yes (per host) |
| Public network surface | The site | Published port | **Gateway only** | **Gateway port only** |

The row that answers the original question is the fourth one, and it is **No** in every shape.

---

## 4. So — is it three-tier?

- **As layers: yes**, unambiguously, and more strictly than most systems that claim it, because the boundaries fail the build rather than living in a diagram.
- **As tiers: two by default, three with the gateway** — where the third is an *edge/web* tier.
- **As "web server → application server → database server": no.** There is no application-server tier. Presentation and business logic are never in separate processes.

That last point is a deliberate decision, not an omission.

---

## 5. Why there is no separate application server

Note this argument is **different** from the microservices one. A physical application tier would
*not* break ACID — the whole business layer would move across intact and keep its single transaction.
The reasons are these instead.

### 5.1 The tier is largely a historical artifact

The web-server / application-server split comes from the DCOM, CORBA, EJB and .NET Remoting era, when
the web server genuinely could not host business components: it served pages and had to call out to a
component container. ASP.NET Core hosts both natively in one process. Reintroducing the split today
adds a serialization boundary and a network hop to every business call and gains no capability that
the runtime does not already provide.

### 5.2 What it would cost

- **Serialize → network → deserialize on every call.** Today a controller calls `AccountService` as a method. Across a tier it becomes an HTTP or gRPC round trip with a DTO on each side.
- **A duplicate object model.** Wire DTOs beside the existing service contracts, plus mapping code, plus tests for the mapping.
- **New failure modes on every screen.** An in-process call cannot time out or half-succeed. A remote one can, so every call site needs a timeout, a retry policy and a "the app tier is down" path.
- **Version coupling across a wire.** The web tier and app tier can now be deployed at different versions, which means contract compatibility testing forever.
- **Harder diagnosis.** One stack trace becomes two logs plus a correlation id.

### 5.3 What it would buy — and where we already have it

This is the honest part of the argument: the motives for an app tier are real, we just satisfy them
another way.

| Motive for an app-server tier | How TrustBank CBS satisfies it |
|---|---|
| Keep the internet-facing box out of the internal network (DMZ) | **`TflCbs.Gateway`** is exactly that boundary: a pure proxy with rate limiting, the only published port. Hosts and the database stay internal. |
| Scale business logic independently of the UI | **Thin per-module hosts** behind the gateway, composed by `Modules:Enabled` from the same codebase. Already built and running. |
| Reuse business logic outside the web app | The module assemblies have **zero ASP.NET dependencies** and are already consumed by `TflCbs.Demo` and `TflCbs.Tests`. A batch job or console tool references them directly. |
| Keep a clean, testable business boundary | `Result`/`Result<T>` service contracts + 149 cross-provider tests — obtained without a network. |

### 5.4 The one thing we genuinely give up

**In the single-host shape, the internet-facing process holds the database credentials.** A true app
tier would keep them off the web-facing box. We accept this and mitigate it by other means: the
gateway shape keeps hosts off the public network entirely; connection strings are never committed
(supplied per site via IIS `<environmentVariables>` or container environment); and production
isolation is handled as network hardening rather than as an application tier.

That is the real trade, stated plainly. It is a network-topology mitigation, not an application-
architecture one, and anyone reviewing this should know that.

---

## 6. If a true application tier were ever required

The cost is bounded, and that is the point of the layering. Because the business modules are already
free of ASP.NET, extracting them is a **refactor with a known shape**, not a rewrite:

1. Host the module assemblies in a minimal API process — they need no web plumbing changes.
2. Keep the existing service interfaces; add HTTP/gRPC client implementations behind them.
3. Register the clients in the web tier instead of the concrete services. Controllers do not change.
4. Add what §5.2 lists: DTOs, timeouts, retries, contract tests, correlation.

Steps 1–3 are small. Step 4 is the permanent cost, and it is the reason we have not taken it.

**Triggers that would justify it:** a regulatory requirement that no internet-facing process may hold
database credentials; a mandated physical DMZ that the gateway does not satisfy; or a non-web
consumer that cannot reference .NET assemblies and needs a network API of its own.

---

## 7. Verdict

| Question | Answer |
|---|---|
| Is it layered? | **Yes** — client, presentation, framework, business, data access, database; enforced by 94 arch tests |
| Is the business layer independent of the web? | **Yes** — zero ASP.NET references, runs headless in `TflCbs.Demo` and `TflCbs.Tests` |
| Is it multi-tier physically? | **Two** server tiers by default; **three** with the gateway |
| Is there a web server tier? | Only in the multi-host shape — `TflCbs.Gateway` |
| Is there an application server tier? | **No — deliberately** |
| Is the database a separate tier? | **Yes**, always |
| Could an app tier be added? | Yes, as a bounded refactor — see §6 |

**In one line:** TrustBank CBS is a **strictly layered, two-to-three tier application** — three-layer
in the sense that matters for maintainability, and short of the classic three-*tier* server split by
choice, because the application-server tier costs a network hop on every call to deliver benefits we
already obtain from the gateway and the thin hosts.

**See also:** [Why-Modular-Monolith-Not-Microservices.md](Why-Modular-Monolith-Not-Microservices.md) · [modular-monolith.md](modular-monolith.md) · [reusable-boundary.md](reusable-boundary.md) · [../port-map.md](../port-map.md) · [../architecture-overview.md](../architecture-overview.md)
