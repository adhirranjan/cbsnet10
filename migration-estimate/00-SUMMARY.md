# Legacy CBS → .NET 10 Migration — Estimate (one-page summary)

**Prepared 17 June 2026 · ROM estimate (±40%) · Confidential**
Basis: automated scan of the legacy codebase + measured velocity from six delivered pilot screens.

## Headline

| Likely effort | Indicative timeline | Team |
|---|---|---|
| **~10,550 person-days (~48 person-years)** | **~2.5–3 years** | **~20 (dev / QA / BA / PM)** |

## Measured scope (counted, not guessed)

- **1,458** ASPX screens — of which **1,059** functional + **399** reports
- **5,317** stored procedures · **1,497** VB code-behind files · **19** reusable controls
- Functional screens by complexity: Simple **121** · Medium **751** · Complex **187**
- Largest modules: RetailBanking 667 · Reports 362 · HO 203 · Reconciliation 74

## Why this is achievable

The reusable **foundation is already built and proven on six delivered screens** — framework, auth/session, menu + fail-closed access control, multi-database data layer, reusable UI components, and a repeatable per-screen recipe. That work (typically 15–20% of such a programme) is **excluded from the build figures** and materially de-risks delivery. The **strangler-fig** approach cuts over module-by-module — value early, no big-bang.

## Effort breakdown (likely)

| Workstream | Effort (pd) |
|---|---:|
| Simple / Medium / Complex screens | 182 / 3,004 / 1,870 |
| Reports (re-implement) + platform | 838 |
| Core engine procedures (interest, GL, day-end, clearing) | 600 |
| Data migration + parallel-run tooling | 200 |
| Foundation remaining + cross-provider hardening | 240 |
| **Build subtotal** | **6,934** |
| QA + UAT (30%) · PM/BA/DevOps (20%) · Security | 2,080 · 1,387 · 150 |
| **TOTAL — likely** | **~10,550 (~48 PY)** |

## Range & timeline

- **Optimistic** ~7,400 pd (~34 PY) · **Likely** ~10,550 pd (~48 PY) · **Pessimistic** ~14,800 pd (~67 PY)
- By team: 15 → ~3.2 yr · **20 → ~2.4 yr (recommended)** · 25 → ~1.9 yr (add ramp-up + UAT ⇒ plan ~2.5–3 yr)

## Top cost drivers

1. **Database target** — single-DB removes ~120–150 pd; multi-provider (Oracle/PostgreSQL) adds hardening.
2. **Reports: rehost vs rebuild** — swings the total by ~500–700 pd (the single biggest lever).
3. **5,317 stored procedures** — deep embedded logic; highest-risk engines, need senior attention + parallel-run.
4. **Banking compliance** — reconciliation + likely regulator sign-off lengthen UAT.

## Recommendation

**Approve a 4–6 week discovery phase now.** It converts this ROM into a committed plan (±15%), settles the reports and database-target decisions, and produces a firm Phase-1 budget — before any large build commitment. The proven foundation means the team can begin migrating screens immediately afterward.

---

## Deliverables in this pack

| File | Purpose |
|---|---|
| `00-SUMMARY.md` | This one-page summary + slide outline |
| `TrustBank-Migration-Estimate.docx` | Full management report (8 sections) |
| `TrustBank-Migration-Estimate.pptx` | 9-slide management deck |
| `TrustBank-Migration-Estimate.xlsx` | Editable assumptions, module inventory, full 1,458-screen list |
| `screens-raw.tsv` | Raw screen inventory (Module / SubArea / Screen / path) |
| `procs-raw.txt` | Raw stored-procedure list (5,317) |

## Slide deck outline (`.pptx`)

1. **Title** — Legacy CBS → .NET 10 Migration; headline figures
2. **Executive summary** — scope, foundation-already-built, strangler-fig
3. **Measured scope** — counts + complexity column chart
4. **Effort breakdown** — full workstream table → ~10,550 pd
5. **Estimate range** — optimistic / likely / pessimistic + drivers
6. **Indicative timeline** — duration by team size (15 / 20 / 25)
7. **Phased roadmap** — Phase 0 (done) → Phase 6 (cutover)
8. **Key risks & cost drivers** — DB target, reports, procedures, compliance
9. **Recommendation** — approve 4–6 week discovery
