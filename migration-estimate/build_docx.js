const fs = require("fs");
const { Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
        AlignmentType, LevelFormat, HeadingLevel, BorderStyle, WidthType, ShadingType,
        Header, Footer, PageNumber } = require("docx");

const NAVY = "1F3864", BLUE = "2E75B6", GREY = "595959", LIGHT = "D9E1F2", GREEN = "E2EFDA";

const H = (t, lvl) => new Paragraph({ heading: lvl, children: [new TextRun(t)] });
const P = (t, opts = {}) => new Paragraph({ spacing: { after: 120 }, children: [new TextRun({ text: t, ...opts })] });
function runs(t) {
  return String(t).split(/(\*\*[^*]+\*\*)/).filter(Boolean)
    .map(s => s.startsWith("**") ? new TextRun({ text: s.slice(2, -2), bold: true }) : new TextRun(s));
}
const bullet = (t) => new Paragraph({ numbering: { reference: "b", level: 0 }, spacing: { after: 60 }, children: runs(t) });
const border = { style: BorderStyle.SINGLE, size: 1, color: "BFBFBF" };
const borders = { top: border, bottom: border, left: border, right: border };
function cell(text, w, { bold = false, fill = null, align = AlignmentType.LEFT, color = null } = {}) {
  return new TableCell({
    borders, width: { size: w, type: WidthType.DXA },
    shading: fill ? { fill, type: ShadingType.CLEAR } : undefined,
    margins: { top: 60, bottom: 60, left: 110, right: 110 },
    children: [new Paragraph({ alignment: align, children: [new TextRun({ text: String(text), bold, color })] })],
  });
}
const table = (widths, rows) => new Table({ width: { size: widths.reduce((a, b) => a + b, 0), type: WidthType.DXA }, columnWidths: widths, rows: rows.map(r => new TableRow({ children: r })) });
const hc = (t, w, align = AlignmentType.LEFT) => cell(t, w, { bold: true, fill: NAVY, color: "FFFFFF", align });
const dataRows = (pairs, w0, w1) => pairs.map(([a, b], i) => [cell(a, w0, { fill: i % 2 ? null : LIGHT }), cell(b, w1, { align: AlignmentType.RIGHT, fill: i % 2 ? null : LIGHT })]);

const eff = [
  ["Simple screens (masters, config, lookups, inquiries)", "121", "1.5", "182"],
  ["Medium screens (search/list, multi-tab, dependent pickers)", "751", "4.0", "3,004"],
  ["Complex screens (transactions, maker-checker, calc, batch)", "187", "10.0", "1,870"],
  ["Reports (re-implement)", "399", "2.0", "798"],
  ["Reporting platform setup", "—", "—", "40"],
  ["Core engine procedures (interest, balance, day-end, GL, clearing)", "40", "15.0", "600"],
  ["Data migration + parallel-run tooling", "—", "—", "200"],
  ["Foundation remaining + cross-provider hardening", "—", "—", "240"],
];
const W4 = [4760, 1300, 1300, 2000];

const doc = new Document({
  styles: {
    default: { document: { run: { font: "Arial", size: 21 } } },
    paragraphStyles: [
      { id: "Title", name: "Title", basedOn: "Normal", next: "Normal", run: { size: 40, bold: true, color: NAVY }, paragraph: { spacing: { after: 120 } } },
      { id: "Heading1", name: "Heading 1", basedOn: "Normal", next: "Normal", quickFormat: true, run: { size: 28, bold: true, color: NAVY }, paragraph: { spacing: { before: 260, after: 140 }, outlineLevel: 0 } },
      { id: "Heading2", name: "Heading 2", basedOn: "Normal", next: "Normal", quickFormat: true, run: { size: 23, bold: true, color: BLUE }, paragraph: { spacing: { before: 180, after: 100 }, outlineLevel: 1 } },
    ],
  },
  numbering: { config: [{ reference: "b", levels: [{ level: 0, format: LevelFormat.BULLET, text: "•", alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 460, hanging: 260 } } } }] }] },
  sections: [{
    properties: { page: { size: { width: 12240, height: 15840 }, margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 } } },
    headers: { default: new Header({ children: [new Paragraph({ alignment: AlignmentType.RIGHT, children: [new TextRun({ text: "TrustBank CBS — Migration Estimate", color: GREY, size: 16 })] })] }) },
    footers: { default: new Footer({ children: [new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ text: "Confidential — ROM estimate ±40%  ·  Page ", color: GREY, size: 16 }), new TextRun({ children: [PageNumber.CURRENT], color: GREY, size: 16 })] })] }) },
    children: [
      new Paragraph({ style: "Title", children: [new TextRun("Legacy CBS → .NET 10 Migration")] }),
      P("Estimated effort, timeline, and phasing for management review", { color: GREY, size: 24 }),
      P("Prepared 17 June 2026  ·  Basis: automated scan of the legacy codebase + velocity from delivered pilot screens", { color: GREY, italics: true, size: 18 }),
      new Paragraph({ border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: BLUE, space: 1 } }, children: [] }),

      H("Executive summary", HeadingLevel.HEADING_1),
      P("TrustBank CBS is a large core-banking system — 1,458 web screens, ~890 report definitions, and 5,317 stored procedures. Migrating it to the new .NET 10 / C# MVC platform is estimated at roughly 10,550 person-days (~48 person-years), most likely delivered over 2.5–3 years with a team of about 20 (developers, QA, BA, PM)."),
      P("The reusable foundation — application framework, authentication/session, menu and fail-closed access control, multi-database data-access layer, a library of reusable UI components, and a repeatable per-screen migration recipe — is already built and proven on six delivered screens. That work (typically 15–20% of such a programme) is excluded from the build figures below and materially de-risks delivery; the strangler-fig approach lets us cut over module-by-module rather than in a single big-bang."),
      P("This is a Rough Order of Magnitude (ROM) estimate, accurate to about ±40%. A focused 4–6 week discovery (the attached screen-by-screen inventory) would firm it to roughly ±15% and produce a committed Phase-1 budget."),
      new Paragraph({ spacing: { before: 80, after: 120 }, children: [] }),
      table([3120, 3120, 3120], [
        [hc("Likely effort", 3120, AlignmentType.CENTER), hc("Indicative timeline", 3120, AlignmentType.CENTER), hc("Team size", 3120, AlignmentType.CENTER)],
        [cell("~10,550 person-days (~48 PY)", 3120, { align: AlignmentType.CENTER, fill: GREEN }),
         cell("~2.5–3 years", 3120, { align: AlignmentType.CENTER, fill: GREEN }),
         cell("~20 (incl. QA / BA / PM)", 3120, { align: AlignmentType.CENTER, fill: GREEN })],
      ]),

      H("1. Measured scope", HeadingLevel.HEADING_1),
      P("Counts come from an automated scan of the legacy source (Trust.Bank.Publish and the SQL procedure set):"),
      table([6360, 3000], [
        [hc("Artifact", 6360), hc("Count", 3000, AlignmentType.RIGHT)],
        ...dataRows([
          ["ASPX screens (total)", "1,458"], ["  — of which Reports", "399"], ["  — functional (non-report) screens", "1,059"],
          ["Report definitions (.rdlc / .rpt)", "892"], ["Reusable user controls (.ascx)", "19"],
          ["Stored procedures (.sql)", "5,317"], ["VB code-behind files", "1,497"],
        ], 6360, 3000),
      ]),
      P("Largest modules by screen count: RetailBanking 667, Reports 362, HO 203, Reconciliation 74, Inventory 23, HR / Helpdesk / EmployeeDemand 21 each, Lockers 15.", { size: 18, color: GREY }),

      H("2. Method and assumptions", HeadingLevel.HEADING_1),
      P("Bottom-up: each functional screen is classified Simple / Medium / Complex and costed at a per-screen rate calibrated to the six screens already delivered; reports are costed separately; cross-cutting workstreams are added explicitly. Calendar = total effort ÷ (team size × 220 productive days per year)."),
      H("Key assumptions", HeadingLevel.HEADING_2),
      bullet("**Foundation already built** (excluded from build figures): framework, auth/session, menu + access guard, multi-provider data layer, reusable components (record / account / date pickers, search modal, notifications, opaque row tokens), the per-screen recipe, and six reference screens."),
      bullet("Stored procedures are migrated **with their consuming screen** (master CRUD → repository pattern; heavy transactional logic → C# service); only shared “engine” procedures are a separate line."),
      bullet("A blended team of developers, QA, business analysts, and project management."),
      bullet("Strangler-fig coexistence → incremental, module-by-module cutover (value delivered early, no big-bang)."),

      H("3. Effort breakdown (likely case)", HeadingLevel.HEADING_1),
      table(W4, [
        [hc("Workstream", W4[0]), hc("Count", W4[1], AlignmentType.RIGHT), hc("Rate (pd)", W4[2], AlignmentType.RIGHT), hc("Effort (pd)", W4[3], AlignmentType.RIGHT)],
        ...eff.map((r, i) => [cell(r[0], W4[0], { fill: i % 2 ? null : LIGHT }), cell(r[1], W4[1], { align: AlignmentType.RIGHT, fill: i % 2 ? null : LIGHT }), cell(r[2], W4[2], { align: AlignmentType.RIGHT, fill: i % 2 ? null : LIGHT }), cell(r[3], W4[3], { align: AlignmentType.RIGHT, fill: i % 2 ? null : LIGHT })]),
        [cell("Build subtotal", W4[0], { bold: true, fill: LIGHT }), cell("", W4[1], { fill: LIGHT }), cell("", W4[2], { fill: LIGHT }), cell("6,934", W4[3], { bold: true, align: AlignmentType.RIGHT, fill: LIGHT })],
        [cell("QA + UAT (30% of build)", W4[0]), cell("", W4[1]), cell("", W4[2]), cell("2,080", W4[3], { align: AlignmentType.RIGHT })],
        [cell("PM / BA / DevOps / training / docs (20% of build)", W4[0]), cell("", W4[1]), cell("", W4[2]), cell("1,387", W4[3], { align: AlignmentType.RIGHT })],
        [cell("Security review + performance hardening", W4[0]), cell("", W4[1]), cell("", W4[2]), cell("150", W4[3], { align: AlignmentType.RIGHT })],
        [cell("TOTAL — likely", W4[0], { bold: true, fill: GREEN }), cell("", W4[1], { fill: GREEN }), cell("", W4[2], { fill: GREEN }), cell("~10,550 pd  (~48 PY)", W4[3], { bold: true, align: AlignmentType.RIGHT, fill: GREEN })],
      ]),

      H("4. Estimate range", HeadingLevel.HEADING_1),
      table([2400, 4560, 1200, 1200], [
        [hc("Scenario", 2400), hc("Drivers", 4560), hc("pd", 1200, AlignmentType.RIGHT), hc("PY", 1200, AlignmentType.RIGHT)],
        [cell("Optimistic", 2400, { fill: LIGHT }), cell("Single-DB, reports rehosted, strong reuse, senior team", 4560, { fill: LIGHT }), cell("~7,400", 1200, { align: AlignmentType.RIGHT, fill: LIGHT }), cell("~34", 1200, { align: AlignmentType.RIGHT, fill: LIGHT })],
        [cell("Likely", 2400), cell("Multi-DB, reports re-implemented, normal parallel-run", 4560), cell("~10,550", 1200, { align: AlignmentType.RIGHT }), cell("~48", 1200, { align: AlignmentType.RIGHT })],
        [cell("Pessimistic", 2400, { fill: LIGHT }), cell("Multi-DB hardening, full report rebuild, deep parallel-run, scope growth", 4560, { fill: LIGHT }), cell("~14,800", 1200, { align: AlignmentType.RIGHT, fill: LIGHT }), cell("~67", 1200, { align: AlignmentType.RIGHT, fill: LIGHT })],
      ]),

      H("5. Indicative timeline by team size (likely effort)", HeadingLevel.HEADING_1),
      table([4680, 2340, 2340], [
        [hc("Team (incl. QA / BA / PM)", 4680), hc("People", 2340, AlignmentType.RIGHT), hc("Duration", 2340, AlignmentType.RIGHT)],
        [cell("Lean", 4680, { fill: LIGHT }), cell("15", 2340, { align: AlignmentType.RIGHT, fill: LIGHT }), cell("~3.2 years", 2340, { align: AlignmentType.RIGHT, fill: LIGHT })],
        [cell("Balanced (recommended)", 4680), cell("20", 2340, { align: AlignmentType.RIGHT }), cell("~2.4 years", 2340, { align: AlignmentType.RIGHT })],
        [cell("Accelerated", 4680, { fill: LIGHT }), cell("25", 2340, { align: AlignmentType.RIGHT, fill: LIGHT }), cell("~1.9 years", 2340, { align: AlignmentType.RIGHT, fill: LIGHT })],
      ]),
      P("Add ramp-up and final UAT/cutover — a realistic window is ~2.5–3 years at ~20 people.", { size: 18, color: GREY }),

      H("6. Phased roadmap", HeadingLevel.HEADING_1),
      bullet("**Phase 0 — done:** foundation, reusable components, pilot screens, migration recipe."),
      bullet("**Phase 1 — Discovery & inventory (4–6 weeks):** screen-by-screen catalogue → firm the estimate to ±15%."),
      bullet("**Phase 2 — Masters & config** (HO, Config, Lockers, HR): quick wins, prove velocity."),
      bullet("**Phase 3 — Reporting platform + reports** (parallel workstream)."),
      bullet("**Phase 4 — RetailBanking transactions** (the bulk), by sub-module: deposits → loans → clearing → cash → day-end."),
      bullet("**Phase 5 — Reconciliation, Inventory, Helpdesk, EmployeeDemand, Customer360.**"),
      bullet("**Phase 6 — Data migration, parallel run, cutover, hardening, training.**"),

      H("7. Key risks and cost drivers", HeadingLevel.HEADING_1),
      bullet("**Cross-provider SQL (Oracle / PostgreSQL):** raw-SQL screens are written in SQL-Server dialect; a single-database target removes ~120–150 pd and de-risks delivery."),
      bullet("**Reports (362 screens + 892 definitions):** “rehost” vs “rebuild” swings the total by ~500–700 pd — the single biggest decision."),
      bullet("**5,317 stored procedures** indicate deep embedded business logic (interest, GL, day-end) — the highest-risk, highest-value engines; require senior attention and rigorous parallel-run validation."),
      bullet("**Banking correctness & compliance** mandate reconciliation and likely regulator sign-off, which lengthens UAT."),

      H("8. Recommendation", HeadingLevel.HEADING_1),
      P("Approve a 4–6 week discovery phase now. It converts this ROM into a committed plan (±15%), confirms the per-screen complexity in the attached inventory, settles the reports and database-target decisions, and produces a firm Phase-1 budget — all before any large build commitment. The proven foundation means the team can begin delivering migrated screens in Phase 2 immediately afterward."),
      P("Supporting workbook: TrustBank-Migration-Estimate.xlsx (editable assumptions, module inventory, and the full 1,458-screen list).", { size: 18, color: GREY, italics: true }),
    ],
  }],
});

Packer.toBuffer(doc).then(b => { fs.writeFileSync(__dirname + "/TrustBank-Migration-Estimate.docx", b); console.log("docx written"); });
