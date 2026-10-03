# TrustBank CBS — Architecture Discussion Brief

**Internal briefing note · 3 October 2026 · For a management review of the .NET 10 migration**

*One page of "where we are", one of "what's open", and the decisions we need. Detail lives in the reference documents listed at the end. Previous edition: 21 August 2026. Section 2 lists what has changed since then.*

---

## 1. The position in five lines

- We are migrating TrustBank CBS from **ASP.NET WebForms / VB.NET / .NET 4.8** to **.NET 10 / C# ASP.NET Core MVC** with a **strangler-fig** approach: legacy keeps running and screens cut over one at a time.
- **The migration now targets the xnet codebase** (the Africa/international fork) rather than the India codebase. This was decided in early September. The xnet database was adapted to the code that had already been migrated, so the target was replaced rather than added as a second one. xnet is about **half the size** in screens (692 vs 1,458), so **the June effort estimate is out of date and has to be re-based** (§5).
- **The reusable foundation and the modular-monolith architecture are built.** There are **13 business modules**, each in its own assembly, with boundaries enforced by the build. The platform runs in **four deployment shapes** from one codebase.
- **The first real xnet screens are live against the xnet database.** They include two maker-checker money screens and the first two Crystal reports. Each was checked **row for row against the legacy stored procedures it replaces**, on **both SQL Server and Oracle**.
- **The biggest open item is still the process, not the design.** Git has been initialised but **nothing is committed yet and there is no CI pipeline**. Until that changes, **~1,150 automated tests** run only when someone remembers to run them.

---

## 2. What changed since 21 August

| Area | Change |
|---|---|
| **Target codebase** | Re-based on **xnet**. Entities were regenerated from the xnet database (3,272 tables), and the menu now reads xnet's own menu map. Dev databases: SQL Server `Trustbank_XNETT_ORCL` and Oracle `XNETTN`. |
| **Business modules** | **8 → 13.** Five xnet domains that had no code before were added as boundaries: Inventory, Trade Finance, Internet Banking, Reconciliation and Loan Origination. One of them (Inventory) also got its own thin host, to prove the slices really are isolated. The Clearing module was deleted because nothing called it. |
| **Screens** | A batch of **13 xnet menu entries** was delivered: Holding Amount (4 screens, two maker-checker cycles), Direct Credit, Dormant Re-Activation, Signature Upload, Denominations, Denomination Unit and User Creation. The **14 earlier pilot screens** that are not on the xnet path were **parked**: taken out of the build, kept whole, and to be restored when each is reviewed. |
| **Reports** | **Phase 1 complete.** Crystal Reports stays, but runs **out of process** in a small render-only .NET 4.8 viewer app, with a signed, single-use handoff from CBS. Two reports are live (Account Opened, Chart of Account List). Measured with 100,000 rows: about 1 s to hand off and 0.7 s to the first page. All 871 legacy layouts load in the target Crystal runtime. |
| **Multi-database** | **Oracle joined the automated test matrix.** It immediately exposed two classes of defect that SQL Server had hidden: Oracle cannot bind a .NET `bool` or `Guid`. **Writes to those columns had never worked on Oracle.** Both are fixed with portable column types (INT 0/1 flags, CHAR(36) GUIDs), recorded as standing rules, and checked at screen review. |
| **Legacy parity** | Every batch-7 screen now has a **parity test** that runs the legacy stored procedure and the new C# side by side and compares them row for row. These tests caught real mismatches before users did, for example the branch scoping on three screens. The one rewritten report query runs in **1.2 s, where the proc took 46 s**. |
| **Security & login** | The **MFA stack** (OTP / Active Directory / QR) was rewritten in .NET 10; the vendor's .NET 3.5 assemblies are gone. Password transport moved from RC4 to RSA-OAEP. Session idle policy was fixed: a cookie had made the effective idle timeout **8 hours** instead of 25 minutes. |
| **Solution** | **56 projects** (was 36). The increase comes from the five new domain modules and their screen libraries, plus the nine MFA projects brought into the solution. |

---

## 3. The architectural decisions, and why they were made

**Modular monolith: one process, one database, hard internal boundaries.**

This is the deliberate middle path between the legacy monolith and microservices. For a core banking system it is the defensible choice:

- **Money movement needs transactions.** One database gives real ACID guarantees across a posting. A distributed design would trade that for eventual consistency, plus a class of failure modes we would then have to engineer around. At our volumes there is nothing to gain.
- **It is simple to operate today.** There is one application to deploy, monitor and back up.
- **The boundaries are real.** Modules talk to each other only through published contracts, and **152 automated architecture checks fail the build** if anyone crosses a line. That is what separates this from a conventional monolith: the design cannot quietly erode as the team grows. A meta-check also confirms that each boundary rule can still fail, so a rule cannot pass simply because it has become impossible to break.
- **Scale-out is available without a rewrite.** Because the boundaries are enforced, individual modules already run as separate hosts behind a gateway. That capability is built and demonstrated. We do not need it yet.

**The xnet move proved the architecture.** Swapping the entire legacy target was absorbed mainly by **adapting the database to the code**. The code itself changed only where the schema could not be bent: menu authorisation and one renamed rights table. Five new domain modules were added without touching any existing module.

**Second decision: the horizontal split between framework and screens.** Reusable plumbing lives in one assembly that knows nothing about any screen. That is what keeps the per-screen recipe fast and repeatable, and it is arch-tested too.

**Third decision (new): reports stay on Crystal, kept out of process.** CBS sends the data and the viewer only renders it. Moving all reports to a new engine is estimated at 900–1,250 person-days, so we move only a report that is being changed anyway (§7).

---

## 4. What is proven, with evidence

| Claim | Evidence |
|---|---|
| Boundaries hold | **152 architecture checks**, run on every build |
| Business logic works on SQL Server **and Oracle** | **618 cross-provider service test cases** run against both databases, including full create/update/delete round trips on every batch-7 screen |
| New code matches legacy behaviour | **Parity tests** compare our C# with the legacy stored procedure row for row: menu, holding amount, direct credit, dormant re-activation, signature, denominations and both reports |
| The whole stack works end to end | **244 in-process integration tests**: login, access guard, antiforgery, every batch-7 screen's form fields, row-token replay and tamper refusal, and the report handoff |
| The browser sees what we think it sees | **~100 Playwright browser tests**: strict content-security policy, session and idle timeout, and every reusable component. They found and fixed a date-picker defect that posted the 1st of the month whatever day was picked. |
| Access control is fail-closed | A central guard runs on every request, with a startup assertion that it cannot be ordered away. Both are pinned by tests. |
| No SQL injection surface | All data access is parameterised; raw SQL in new master CRUD is forbidden by a standing rule |
| Rewrites are not slower than legacy | Dated performance reports compare C# with T-SQL on both engines. The rewritten report query runs in 1.2 s; the proc took 46 s. |

---

## 5. Scope and effort: the commercial picture

**The June estimate was built on the India codebase and no longer describes the target.** Measured scope for each:

| | India (June estimate basis) | **xnet (current target)** |
|---|---:|---:|
| Screens (`.aspx` + `.ascx`) | 1,458 | **692** |
| — functional | 1,059 | **640** |
| — report screens | 399 | **52** (fronting **871** Crystal layouts) |
| Distinct stored procedures | 5,317 | **2,155** |
| Lines of markup + code-behind | — | **1.37 million** |

The June figure was **~10,550 person-days (±40%), ~2.5–3 years with ~20 people**. **It should not be quoted for xnet.** The screen count roughly halves, but xnet adds international scope (SWIFT, PAPSS, Treasury) that has not been sized. A re-estimate on the xnet inventory is the first deliverable of the discovery phase (§7).

**The three biggest levers on the new number:** the report engine (a full move costs an extra 900–1,250 pd; keeping Crystal avoids most of it), whether we keep all three databases, and the **posting engine** (interest, GL, day-end, clearing), which is not built yet (§6).

---

## 6. Open risks: what we would want to say before anyone asks

| # | Item | Status | Why it matters |
|---|---|---|---|
| **1** | **No source control history or CI** | **Open: highest priority** | Git is initialised and a team guide exists, but **there are zero commits** and no pipeline. Nothing is recoverable and nothing gates a bad change. The ~1,150 tests catch regressions only when someone runs them by hand. Every other item on this list gets cheaper once this is fixed. |
| **2** | **Posting engine not built** | Deferred by decision | Screens that move money (Direct Credit, Dormant Re-Activation with a charge) save drafts and **refuse to authorise** with an explicit "posting not implemented" message, and the screen tells the user so. Nothing silently half-posts. This is the largest technical piece still ahead and gates most of Retail operations. |
| **3** | Optimistic concurrency | **Regressed to none in the build** | The pattern is built in the data layer, but its only adopter (the State master) was among the parked screens. **Concurrent edits on every live screen are last-writer-wins** until it is rolled out. |
| **4** | Production TLS, DB credentials | Open, ops-owned | Four VAPT reports flagged credentials sent over unencrypted or bare-IP HTTP. Every CBS origin must be `https://<real hostname>` with a trusted certificate; no code change can substitute for that. The shared admin DB login still needs replacing with a least-privilege account. |
| **5** | MFA go-live gates | Built, not yet proven live | The rewritten AD path has not been tested against a real domain controller. QR-at-login needs the mobile app and device keypair, and currently runs on SQL Server only. |
| **6** | Infrastructure as code; observability backend | Deferred by decision | App-side telemetry is built and switched off by default. The collector and dashboards are ops work for after the gate. |

The independent pre-production review scored the solution **62/100** in July and **~77** after remediation (last scored 31 July). It has not been re-scored since the xnet move. Of the two Critical findings, both are closed (the authentication bypass, and reversible password storage; passwords are now PBKDF2).

**The honest summary:** the *structure* is still the system's strongest attribute, and the xnet re-base tested it. The remaining risk is **process (items 1, 4) and one large unbuilt capability (item 2)**, not design.

---

## 7. What we would like decided

1. **Authorise the first commit and a CI pipeline now.** It is a small effort, it removes the largest single risk, and from then on every fix lands behind ~1,150 tests.
2. **Approve a 4–6 week discovery phase on xnet** to turn the inventory into a committed ±15% plan. It replaces the India estimate and sizes the international scope.
3. **Schedule the posting engine.** Decide when it starts and who owns it. Retail money screens can be built up to "draft" ahead of it, but cannot go live without it.
4. **Confirm the report direction:** keep Crystal (out of process), and approve a 2-week trial of DevExpress (first choice) and Telerik on 3 real layouts before any engine move is funded.
5. **Settle the database target:** commit to one engine, or fund keeping all three. SQL Server and Oracle are now both under test; PostgreSQL is supported by the data layer but has no xnet test database.
6. **Name an owner for production TLS certificates and the least-privilege DB account.** This is not development work, and it is a VAPT finding.

---

## Appendix: reference documents

| Document | Audience |
|---|---|
| `architecture-overview.md` | Full engineering reference: every project, why it exists, how a request flows end to end |
| `architecture/TrustBank-CBS-Platform-Architecture.md` | Outward-facing; for an institution evaluating the platform |
| `architecture/Why-Modular-Monolith-Not-Microservices.md` · `architecture/Is-CBS-A-Multi-Tier-Application.md` | The two questions most often asked about the architecture, answered |
| `architecture/diagrams/` | Layered architecture and feature board as `.svg` (pastes into PowerPoint/Word) + `.png` |
| `architecture-review/ARCHITECTURE-REVIEW.md` · `REMEDIATION-PLAN.md` | The independent pre-production review and the gate plan |
| `xnet-variant-impact-analysis.md` · `BACKLOG-xnet-variant.md` | What re-basing on xnet cost and changed |
| `legacy-inventory/README.md` · `legacy-inventory/reports.md` | The xnet scope, counted: screens, procs and reports by module |
| `screens-code-guide-xnet-7.md` | The 13 delivered xnet menu entries, how each is built and verified |
| `architecture/report-viewer-handoff.md` · `BACKLOG-legacy-app-wide.md` §4.3 | The reports design and the report-engine decision note |
| `migration-estimate/` | The June commercial pack (India basis, to be re-based) |
| `port-map.md` | Every host, port and deployment shape on one page |
| `guides/day-one.md` · `guides/building-a-crud-screen.md` · `guides/git-with-gitea.md` | Onboarding: first-day setup, the per-screen recipe, the source-control workflow |

---

*Prepared from the solution as it stands on 3 October 2026. Projects, architecture and integration test counts come from the source tree and test discovery, not estimates. Legacy scope comes from the generated xnet inventory (5 September 2026).*
