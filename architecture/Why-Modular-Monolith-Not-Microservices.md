# Why TrustBank CBS is a Modular Monolith, not Microservices

Decision record. Companion to [modular-monolith.md](modular-monolith.md) (what the modular
architecture *is*) and [reusable-boundary.md](reusable-boundary.md) (the horizontal
framework/screen split). This document answers the question those two assume:
**why did we not go to microservices?**

> **Decision.** TrustBank CBS runs as a **modular monolith** — one process, one database, hard
> code-level module boundaries that are enforced by the build. Microservices were considered and
> rejected for this application, not for architecture in general. The rejection is about *this*
> workload: a core banking system whose fundamental unit of work is a multi-module ACID
> transaction. Last reviewed 24 August 2026.

---

## 1. What this application actually is

Any "monolith vs microservices" argument that ignores the workload is decoration. So, the workload:

- **Core banking.** Deposits, withdrawals, transfers, clearing, holds, GL posting, interest runs, day-end. The unit of work is a **balanced set of ledger entries** — it either all lands or none of it does.
- **One bank, one ledger.** Not a multi-tenant SaaS with per-tenant scaling curves. Volumes are a regional/co-operative bank's, not a payment network's.
- **A migration in flight.** ~1,458 legacy screens and ~5,317 stored procedures moving from ASP.NET WebForms / VB.NET / .NET 4.8 to .NET 10 / C# MVC, strangler-fig style, while the legacy system keeps running.
- **Regulated and audited.** Every posting must be explicable after the fact. "The compensating transaction had not yet run" is not an acceptable answer to an auditor.
- **A small team.** Not eight independent teams each wanting their own release cadence.

Every point below follows from that list.

---

## 2. The core argument in one paragraph

Microservices buy **independent deployability and independent scaling**, and they pay for it with
**the loss of the ACID transaction across service boundaries**. In most business applications that
trade is fine, because the operations that span services are not strictly atomic. In core banking
it is exactly inverted: the operations that span modules — a posting, a clearing settlement, day-end
— are *precisely* the ones that must be atomic, and the scaling pressure that would justify the
trade does not exist at our volumes. We would be paying the highest price in the catalogue for the
benefit we need least.

---

## 3. Why microservices are the wrong fit here

### 3.1 The transaction boundary is the whole product

A single posting in TflCbs touches multiple modules: `RetailBanking` (account, holding amount),
`Accounts`, `Clearing`, `General` (maker-checker scroll, process-block check) and the GL. Today that
is one `DataAccess.ExecuteInTransactionAsync` — one connection, one transaction, real ACID
semantics, and a rollback that leaves no trace.

Split those modules into services and the same operation becomes a **saga**: a sequence of local
transactions with compensating actions. The consequences are not theoretical.

- **A compensation is not a rollback.** You cannot un-debit an account. You post a second, visible, reversing entry. The customer's statement now shows a debit and a credit that never should have existed. Multiply by every partial failure.
- **Intermediate states become externally visible.** Between the debit and the credit there is a real window where the books do not balance. Someone will query a balance inside that window.
- **Reconciliation becomes permanent engineering.** Every saga needs a reconciler, an alerting path for stuck sagas, and an operational runbook for manual repair.
- **Idempotency everywhere.** Every service call needs a deduplication key and a store to hold it, because a retried "credit 10,000" that lands twice is a real loss.

That is a large, permanent, correctness-critical body of code — written to solve a problem we do not
have, created purely by the decision to distribute.

### 3.2 One ledger cannot be sharded per module

"Microservices with a shared database" is not microservices; it is a distributed monolith with all
the costs and none of the benefits. Real microservices means a database per service — and here that
collides with the domain:

- `TflCbs.Entities` is a **generated contract over shared tables**. The account master is read by nearly every domain.
- Splitting it means either duplicating master data (and then reconciling the copies) or synchronous cross-service reads (and then you have a distributed monolith with network latency).
- Balances would become eventually consistent. For a ledger, that is not a performance trade-off; it is a correctness defect.

Our own architecture doc already draws this line explicitly: *process separation is not data
separation*. A thin per-module host still reaches the shared database through the same
`DatabaseSelector`, and that is intended.

### 3.3 It would mean two simultaneous rewrites

We are already performing one high-risk transformation: WebForms/VB.NET to .NET 10 MVC, screen by
screen, with the legacy system live beside it. Adding "and also decompose into distributed services"
means the team is simultaneously changing the **UI stack**, the **language**, the **data access
layer** *and* the **consistency model**. When something breaks in that arrangement, nobody can say
which change caused it. Sequencing risk is the cheapest risk control available, and we took it.

### 3.4 The operational bill has no matching benefit

Distribution is not free at rest. It adds, permanently: service discovery, per-service pipelines and
versioning, contract/compatibility testing between services, distributed tracing (because a stack
trace no longer explains anything), network partition handling, per-service secrets and certificate
rotation, and N sets of dashboards and alerts.

For a payment network processing millions of transactions a second, that bill is worth paying. For
one bank's core system, it buys nothing. **We would be adding a full-time platform-operations
workload to a team that should be migrating 1,458 screens.**

### 3.5 New failure modes, in the worst place

In-process, a call between modules cannot time out, cannot be partially applied, and cannot fail
because of a DNS change. Over a network, every one of those becomes possible — and the failure
surface grows with the number of hops. Rendering the menu, evaluating the fail-closed access guard
and validating the session are currently ordinary method calls behind `IMenuSource`,
`IBankVariableSource`, `IBroadcastSource` and `ISessionValidator`. As remote calls they become
things that can be *slow* or *down* on the login path of a bank's core system.

Fail-closed access control has a specific implication here: if the authorization service is
unreachable, the correct behaviour is to **deny**. Distributing the guard therefore converts a
network blip into an outage for everyone — which is the right behaviour, and an excellent reason not
to create the blip in the first place.

### 3.6 Conway's Law points the other way

Microservice boundaries pay off when they match **team** boundaries: separate teams that must ship
without coordinating. We have one team. Splitting one team's codebase across nine deployable
services does not remove coordination — it converts cheap in-repo coordination (a compiler error)
into expensive cross-version coordination (a runtime contract break found in staging, or worse).

### 3.7 Diagnosis and audit get materially harder

At 3am, with a bank's operations blocked, "one stack trace through one process" versus "correlate
nine services' logs by request id and hope the clocks agree" is not a stylistic preference. The same
applies to the regulator's question six months later: *show me exactly what happened to this
transaction*. One transaction log in one database answers it. Nine event streams and a saga history
answer it too — eventually, with effort, and with room for doubt.

---

## 4. Why the modular monolith is the right fit

The decisive point is that **almost every genuine benefit of microservices comes from the
boundaries, not from the network.** We took the boundaries and declined the network.

### 4.1 The boundaries are real — and the build enforces them

This is the difference between a modular monolith and the legacy monolith it replaces. A
conventional monolith degrades because nothing stops a shortcut. Here, something does:

| Rule | Mechanism | If violated |
|---|---|---|
| Modules never reference each other's implementation | `TflCbs.Abstractions` floor + published `*.Contracts` assemblies | Compiler error |
| Framework never references a screen or a service module | Project graph + NetArchTest | Build fails |
| Namespace == assembly (so a `using` names what you couple to) | `NamespaceDisciplineTests` | Build fails |
| Framework talks to modules only via the four ports | `IBroadcastSource`, `IBankVariableSource`, `IMenuSource`, `ISessionValidator` | Build fails |
| Promoted modules stay isolated | `ArchBoundaries.PromotedModules` | Build fails |
| No private copies of shared service helpers | `SharedServiceHelperTests` | Build fails |
| Every deployed module is composed explicitly | `AddCbsModules` startup cross-check | Startup throws |

**94 architecture tests** run on every build, and the suite guards *itself*: a meta-check verifies
each boundary rule is still genuinely capable of failing, so a rule cannot quietly go green by
becoming impossible to violate. That is the property people actually want from microservices —
"the boundary cannot be crossed by accident" — obtained without a network in the middle.

### 4.2 ACID is preserved, for free

Cross-module flows stay in one `ExecuteInTransactionAsync`. No saga, no compensation, no reconciler,
no idempotency store, no partial-failure runbook. The strongest correctness guarantee available is
also, here, the cheapest option.

### 4.3 Independent deployment is available — and already demonstrated

This is the part that removes the usual "but we might need to scale out" objection. Because the
boundaries are enforced, we already ship **four thin per-module hosts** (`TflCbs.Host.Hr`,
`TflCbs.Host.Lockers`, `TflCbs.Host.RetailBanking`, `TflCbs.Host.Administration`) behind a **YARP
gateway** (`TflCbs.Gateway`), composed by configuration (`Modules:Enabled`) from the same codebase,
in **four deployment shapes**: IIS single-host, IIS multi-host, Docker single-host, Docker
multi-host.

The trigger for building that was not scale — it was **proof**. Each thin host's build output was
measured to contain exactly one domain module. That measurement is the evidence that the modules are
genuinely separable. So the capability microservices would have been bought for is already in hand,
and it did not cost us the transaction.

### 4.4 One thing to operate

One application to deploy, monitor, back up and restore. One connection pool. One log stream. One
process to attach a debugger to. For a bank running its own core system, that is not laziness — it is
a smaller surface for the operations team that has to keep it up.

### 4.5 The door stays open

Rejecting microservices today is not a permanent vow. Because boundaries are enforced and contracts
are explicit, extraction later is a **refactor with a known cost**, not a rewrite. The documented
promotion triggers are: the module must run and deploy on its own; a team needs hard ownership and
internal hiding; monolith build time hurts; the module ships as a package; cross-module calls must be
constrained to a contract. We promote when a trigger fires — never all at once, and never on
fashion.

---

## 5. Head to head, for this application

| Concern | Legacy monolith | Microservices | Modular monolith (chosen) |
|---|---|---|---|
| Cross-module posting | Atomic | Saga + compensation | **Atomic** |
| Boundary enforcement | None — erodes silently | Network + separate repos | **Compiler + 94 arch tests** |
| Consistency of balances | Strong | Eventual | **Strong** |
| Deploy units | 1, all-or-nothing | N, independent | **1 by default; N thin hosts available** |
| Failure modes | In-process only | + partition, timeout, partial write | **In-process only** |
| Operational load | Low | High and permanent | **Low** |
| Diagnosis | One stack trace | Distributed tracing required | **One stack trace** |
| Fits a single team | Yes | Poorly | **Yes** |
| Scale-out path | Rewrite | Native | **Config change (proven)** |
| Migration risk added | — | High (two rewrites at once) | **None (sequenced)** |

---

## 6. What we gave up, honestly

A decision record that lists only advantages is marketing. The real costs of this choice:

- **One runtime blast radius in the default shape.** A bad release affects every module. Mitigated by the thin-host shape, and by the test suites gating the build; not eliminated.
- **One language and runtime for the business layer.** No per-module technology choice. We consider that a benefit today; it is still a constraint.
- **Deployment couples modules by default.** Shipping an HR fix redeploys the process. The multi-host shape exists precisely for the day this stops being acceptable.
- **Schema coupling is real.** Shared tables and a generated `TflCbs.Entities` mean schema changes are a whole-system concern, managed by the versioned migration runner rather than by per-service ownership.
- **Build time grows with the codebase.** It is on the promotion-trigger list for a reason.

None of these costs money that a distributed design would not also charge, plus interest.

---

## 7. When we would revisit this

Concrete triggers, so this stays a decision rather than a dogma. Revisit if **any** of these become
true:

- A single module's load genuinely outgrows one process, and the thin-host + gateway shape is no longer enough.
- The organisation grows into multiple independent teams needing independent release cadence, and in-repo coordination measurably blocks delivery.
- A regulatory or data-residency requirement forces true data isolation for a domain. (Note this is a *database* decision, which is a bigger and separate question from process separation.)
- A module must ship to third parties as a standalone product.

Absent one of those, distributing this system adds cost and removes a correctness guarantee. That is
the whole case.

---

## 8. Summary

- Microservices trade **atomicity** for **independent deployability and scaling**.
- In core banking the atomicity is the product, and the scaling pressure is not there.
- The valuable half of microservices is the **boundary discipline** — and we obtained that with enforced code boundaries that fail the build, not with a network.
- The other half, **independent deployment**, we already have on demand: four thin hosts behind a gateway, four deployment shapes, one codebase.
- So the modular monolith gives us the benefits we want, at a fraction of the cost, while keeping ACID — and keeps the microservices door open as a costed refactor rather than a rewrite.

**See also:** [modular-monolith.md](modular-monolith.md) · [reusable-boundary.md](reusable-boundary.md) · [TrustBank-CBS-Architecture-Brief.md](TrustBank-CBS-Architecture-Brief.md) · [../architecture-overview.md](../architecture-overview.md)
