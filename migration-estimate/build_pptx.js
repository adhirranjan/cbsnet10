const pptxgen = require("pptxgenjs");

// ---- Palette (Midnight Executive, banking) ----
const NAVY = "1E2761";   // primary dark
const BLUE = "2E75B6";   // supporting blue
const ICE  = "CADCFC";   // light blue
const AMBER = "E8A33D";  // accent (the "likely / recommended" highlight)
const INK  = "1E2761";   // dark text
const GREY = "5A6473";   // muted text
const LIGHT = "F4F7FC";  // light card bg
const WHITE = "FFFFFF";
const GREEN = "2E7D52";  // done / positive

const pres = new pptxgen();
pres.layout = "LAYOUT_WIDE";          // 13.33" x 7.5"
pres.author = "TrustBank CBS Migration";
pres.title = "Legacy CBS → .NET 10 Migration — Management Estimate";
const PW = 13.33, PH = 7.5;

const shadow = () => ({ type: "outer", color: "1E2761", blur: 7, offset: 3, angle: 135, opacity: 0.16 });

// Standard light-slide title block (no accent lines — uses whitespace).
function titleBlock(slide, kicker, title) {
  slide.addText(kicker.toUpperCase(), { x: 0.7, y: 0.42, w: 11.9, h: 0.3, fontSize: 12, bold: true,
    color: BLUE, charSpacing: 3, fontFace: "Arial", margin: 0 });
  slide.addText(title, { x: 0.7, y: 0.72, w: 11.9, h: 0.7, fontSize: 30, bold: true,
    color: NAVY, fontFace: "Georgia", margin: 0 });
}
function footer(slide, n) {
  slide.addText("TrustBank CBS  ·  Migration Estimate (ROM ±40%)  ·  Confidential",
    { x: 0.7, y: 7.06, w: 9, h: 0.3, fontSize: 9, color: GREY, fontFace: "Arial", margin: 0 });
  slide.addText(String(n), { x: 12.4, y: 7.06, w: 0.5, h: 0.3, fontSize: 9, color: GREY, align: "right", margin: 0 });
}
// big stat callout card
function statCard(slide, x, y, w, h, value, label, opts = {}) {
  const fill = opts.fill || WHITE;
  const vcolor = opts.vcolor || NAVY;
  slide.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y, w, h, fill: { color: fill }, rectRadius: 0.08,
    line: opts.line ? { color: opts.line, width: 1 } : { type: "none" }, shadow: shadow() });
  slide.addText(value, { x: x + 0.1, y: y + 0.18, w: w - 0.2, h: h * 0.5, fontSize: opts.vsize || 30, bold: true,
    color: vcolor, align: "center", valign: "middle", fontFace: "Georgia", margin: 0 });
  slide.addText(label, { x: x + 0.15, y: y + h * 0.62, w: w - 0.3, h: h * 0.34, fontSize: 11.5,
    color: opts.lcolor || GREY, align: "center", valign: "top", fontFace: "Arial", margin: 0 });
}

// ============================================================ Slide 1 — Title
let s = pres.addSlide();
s.background = { color: NAVY };
// subtle motif: ice-blue rounded panel block top-right
s.addShape(pres.shapes.RECTANGLE, { x: 0, y: 0, w: 0.22, h: PH, fill: { color: AMBER } });
s.addText("CORE BANKING SYSTEM MODERNISATION", { x: 0.9, y: 1.7, w: 11, h: 0.4, fontSize: 14, bold: true,
  color: ICE, charSpacing: 4, fontFace: "Arial", margin: 0 });
s.addText("Legacy CBS → .NET 10 Migration", { x: 0.9, y: 2.15, w: 11.5, h: 1.0, fontSize: 44, bold: true,
  color: WHITE, fontFace: "Georgia", margin: 0 });
s.addText("Effort, timeline and phasing — estimate for management review",
  { x: 0.9, y: 3.25, w: 11, h: 0.5, fontSize: 19, color: ICE, fontFace: "Arial", margin: 0 });
// headline figures strip
s.addText([
  { text: "~10,550", options: { bold: true, color: WHITE, fontSize: 30, fontFace: "Georgia" } },
  { text: " person-days", options: { color: ICE, fontSize: 14 } },
  { text: "       ~2.5–3", options: { bold: true, color: WHITE, fontSize: 30, fontFace: "Georgia" } },
  { text: " years", options: { color: ICE, fontSize: 14 } },
  { text: "       ~20", options: { bold: true, color: WHITE, fontSize: 30, fontFace: "Georgia" } },
  { text: " team", options: { color: ICE, fontSize: 14 } },
], { x: 0.9, y: 4.5, w: 11.5, h: 0.7, fontSize: 14, margin: 0 });
s.addText("Prepared 17 June 2026  ·  Basis: automated scan of the legacy codebase + measured velocity from six delivered pilot screens",
  { x: 0.9, y: 6.45, w: 11.5, h: 0.4, fontSize: 11, italic: true, color: "9FB0D8", fontFace: "Arial", margin: 0 });

// ============================================================ Slide 2 — Executive summary
s = pres.addSlide(); s.background = { color: WHITE };
titleBlock(s, "Executive summary", "A large system — but the hard foundation is already built");
const sy = 1.75;
statCard(s, 0.7, sy, 2.85, 1.7, "~10,550", "person-days likely (~48 person-years)", { vsize: 30 });
statCard(s, 3.72, sy, 2.85, 1.7, "~2.5–3 yr", "indicative delivery window", { vsize: 30 });
statCard(s, 6.74, sy, 2.85, 1.7, "~20", "blended team (dev / QA / BA / PM)", { vsize: 30 });
statCard(s, 9.76, sy, 2.85, 1.7, "Phase 0\n✓ done", "foundation + 6 pilot screens", { vsize: 24, fill: NAVY, vcolor: WHITE, lcolor: ICE });
s.addText([
  { text: "Scope is real: ", options: { bold: true, color: NAVY } },
  { text: "1,458 web screens, ~890 report definitions and 5,317 stored procedures move to the new .NET 10 / C# MVC platform.", options: { color: INK } },
], { x: 0.7, y: 3.75, w: 11.9, h: 0.5, fontSize: 15, fontFace: "Arial", margin: 0 });
s.addText([
  { text: "Already in place (excluded from build figures): ", options: { bold: true, color: NAVY } },
  { text: "application framework, authentication / session, menu + fail-closed access control, multi-database data layer, a library of reusable UI components, and a repeatable per-screen migration recipe — proven on six delivered screens. This foundation is typically 15–20% of such a programme and materially de-risks delivery.", options: { color: INK } },
], { x: 0.7, y: 4.35, w: 11.9, h: 1.1, fontSize: 15, fontFace: "Arial", margin: 0 });
s.addText([
  { text: "Strangler-fig approach ", options: { bold: true, color: NAVY } },
  { text: "→ cut over module-by-module, delivering value early with no big-bang. This is a ROM estimate (±40%); a 4–6 week discovery would firm it to ~±15%.", options: { color: INK } },
], { x: 0.7, y: 5.55, w: 11.9, h: 0.8, fontSize: 15, fontFace: "Arial", margin: 0 });
footer(s, 2);

// ============================================================ Slide 3 — Measured scope
s = pres.addSlide(); s.background = { color: WHITE };
titleBlock(s, "1 · Measured scope", "Counted from an automated scan of the legacy source");
// left: scope stat cards (2x3)
const scope = [
  ["1,458", "ASPX screens (total)"],
  ["1,059", "functional (non-report) screens"],
  ["399", "report screens"],
  ["5,317", "stored procedures"],
  ["1,497", "VB code-behind files"],
  ["19", "reusable user controls (.ascx)"],
];
let cx = 0.7, cy = 1.85, cw = 2.55, ch = 1.25, gap = 0.18;
scope.forEach((it, i) => {
  const col = i % 2, row = Math.floor(i / 2);
  statCard(s, cx + col * (cw + gap), cy + row * (ch + gap), cw, ch, it[0], it[1], { vsize: 23 });
});
// right: complexity column chart
s.addText("Functional screens by complexity", { x: 6.4, y: 1.7, w: 6.2, h: 0.35, fontSize: 14, bold: true,
  color: NAVY, fontFace: "Arial", margin: 0 });
s.addChart(pres.charts.BAR, [{
  name: "Screens", labels: ["Simple", "Medium", "Complex", "Reports"], values: [121, 751, 187, 399],
}], {
  x: 6.4, y: 2.1, w: 6.3, h: 3.5, barDir: "col",
  chartColors: [BLUE, BLUE, NAVY, AMBER],
  chartColorsOpacity: [100, 100, 100, 100],
  showValue: true, dataLabelPosition: "outEnd", dataLabelColor: INK, dataLabelFontSize: 12, dataLabelFontBold: true,
  catAxisLabelColor: GREY, catAxisLabelFontSize: 12, valAxisHidden: true,
  valGridLine: { style: "none" }, catGridLine: { style: "none" }, showLegend: false,
  barGapWidthPct: 60,
});
s.addText("Largest modules by screen count:  RetailBanking 667  ·  Reports 362  ·  HO 203  ·  Reconciliation 74  ·  Inventory 23  ·  HR / Helpdesk / EmployeeDemand 21 each  ·  Lockers 15",
  { x: 0.7, y: 5.75, w: 11.9, h: 0.6, fontSize: 12, color: GREY, italic: true, fontFace: "Arial", margin: 0 });
footer(s, 3);

// ============================================================ Slide 4 — Effort breakdown
s = pres.addSlide(); s.background = { color: WHITE };
titleBlock(s, "2 · Effort breakdown — likely case", "Bottom-up, calibrated to the six screens already delivered");
const rows = [
  [{ text: "Workstream", options: { bold: true, color: WHITE } },
   { text: "Count", options: { bold: true, color: WHITE, align: "right" } },
   { text: "Rate (pd)", options: { bold: true, color: WHITE, align: "right" } },
   { text: "Effort (pd)", options: { bold: true, color: WHITE, align: "right" } }],
  ["Simple screens (masters, config, lookups, inquiries)", "121", "1.5", "182"],
  ["Medium screens (search/list, multi-tab, dependent pickers)", "751", "4.0", "3,004"],
  ["Complex screens (transactions, maker-checker, batch)", "187", "10.0", "1,870"],
  ["Reports (re-implement)", "399", "2.0", "798"],
  ["Reporting platform setup", "—", "—", "40"],
  ["Core engine procedures (interest, GL, day-end, clearing)", "40", "15.0", "600"],
  ["Data migration + parallel-run tooling", "—", "—", "200"],
  ["Foundation remaining + cross-provider hardening", "—", "—", "240"],
];
const tableData = rows.map((r, i) => {
  if (i === 0) return r.map(c => ({ text: c.text, options: { ...c.options, fill: { color: NAVY }, fontSize: 12, valign: "middle" } }));
  const fill = i % 2 ? WHITE : LIGHT;
  return r.map((c, j) => ({ text: c, options: { color: INK, fill: { color: fill }, fontSize: 12, align: j === 0 ? "left" : "right", valign: "middle" } }));
});
// summary rows
const sumRow = (label, val, strong, accent) => [
  { text: label, options: { bold: strong, color: accent ? WHITE : INK, fill: { color: accent ? GREEN : ICE }, fontSize: 12, valign: "middle" } },
  { text: "", options: { fill: { color: accent ? GREEN : ICE } } },
  { text: "", options: { fill: { color: accent ? GREEN : ICE } } },
  { text: val, options: { bold: true, color: accent ? WHITE : INK, fill: { color: accent ? GREEN : ICE }, fontSize: 12, align: "right", valign: "middle" } },
];
tableData.push(sumRow("Build subtotal", "6,934", true, false));
tableData.push(["QA + UAT (30% of build)", "", "", "2,080"].map((c, j) => ({ text: c, options: { color: INK, fill: { color: WHITE }, fontSize: 12, align: j === 0 ? "left" : "right", valign: "middle" } })));
tableData.push(["PM / BA / DevOps / training / docs (20%)", "", "", "1,387"].map((c, j) => ({ text: c, options: { color: INK, fill: { color: LIGHT }, fontSize: 12, align: j === 0 ? "left" : "right", valign: "middle" } })));
tableData.push(["Security review + performance hardening", "", "", "150"].map((c, j) => ({ text: c, options: { color: INK, fill: { color: WHITE }, fontSize: 12, align: j === 0 ? "left" : "right", valign: "middle" } })));
tableData.push(sumRow("TOTAL — likely  (~48 person-years)", "~10,550", true, true));
s.addTable(tableData, {
  x: 0.7, y: 1.7, w: 11.9, colW: [7.1, 1.3, 1.5, 2.0],
  border: { type: "solid", pt: 0.5, color: "D6DEEC" }, rowH: 0.34,
  margin: [3, 6, 3, 6], fontFace: "Arial", valign: "middle",
});
footer(s, 4);

// ============================================================ Slide 5 — Estimate range
s = pres.addSlide(); s.background = { color: WHITE };
titleBlock(s, "3 · Estimate range", "Where the number could land — and what drives it");
s.addChart(pres.charts.BAR, [{
  name: "Person-days", labels: ["Optimistic", "Likely", "Pessimistic"], values: [7400, 10550, 14800],
}], {
  x: 0.7, y: 1.95, w: 5.3, h: 4.4, barDir: "col",
  chartColors: [BLUE, AMBER, NAVY],
  showValue: true, dataLabelPosition: "outEnd", dataLabelColor: INK, dataLabelFontSize: 13, dataLabelFontBold: true,
  catAxisLabelColor: GREY, catAxisLabelFontSize: 13, valAxisHidden: true,
  valGridLine: { style: "none" }, catGridLine: { style: "none" }, showLegend: false,
  barGapWidthPct: 55,
});
const ranges = [
  ["Optimistic", "~7,400 pd · ~34 PY", "Single database, reports rehosted, strong reuse, senior team", BLUE],
  ["Likely", "~10,550 pd · ~48 PY", "Multi-DB, reports re-implemented, normal parallel-run", AMBER],
  ["Pessimistic", "~14,800 pd · ~67 PY", "Multi-DB hardening, full report rebuild, deep parallel-run, scope growth", NAVY],
];
let ry = 1.95;
ranges.forEach((r) => {
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 6.4, y: ry, w: 6.2, h: 1.32, fill: { color: LIGHT }, rectRadius: 0.06, line: { type: "none" } });
  s.addShape(pres.shapes.RECTANGLE, { x: 6.4, y: ry, w: 0.1, h: 1.32, fill: { color: r[3] } });
  s.addText([
    { text: r[0] + "   ", options: { bold: true, color: NAVY, fontSize: 15 } },
    { text: r[1], options: { bold: true, color: r[3], fontSize: 15 } },
  ], { x: 6.65, y: ry + 0.12, w: 5.8, h: 0.4, fontFace: "Arial", margin: 0 });
  s.addText(r[2], { x: 6.65, y: ry + 0.56, w: 5.8, h: 0.7, fontSize: 12, color: GREY, fontFace: "Arial", margin: 0, valign: "top" });
  ry += 1.5;
});
footer(s, 5);

// ============================================================ Slide 6 — Timeline by team
s = pres.addSlide(); s.background = { color: WHITE };
titleBlock(s, "4 · Indicative timeline", "Calendar = likely effort ÷ (team × 220 productive days/yr)");
s.addChart(pres.charts.BAR, [{
  name: "Years", labels: ["Lean — 15", "Balanced — 20", "Accelerated — 25"], values: [3.2, 2.4, 1.9],
}], {
  x: 0.7, y: 1.95, w: 6.6, h: 4.3, barDir: "bar",
  chartColors: [BLUE, AMBER, BLUE],
  showValue: true, dataLabelPosition: "outEnd", dataLabelColor: INK, dataLabelFontSize: 13, dataLabelFontBold: true,
  dataLabelFormatCode: '0.0" yr"',
  catAxisLabelColor: GREY, catAxisLabelFontSize: 13, valAxisHidden: true,
  valGridLine: { style: "none" }, catGridLine: { style: "none" }, showLegend: false,
  barGapWidthPct: 55,
});
// right column: recommendation card
statCard(s, 7.8, 2.05, 4.8, 1.85, "~2.4 years", "Balanced team of ~20 (recommended)", { vsize: 32, fill: NAVY, vcolor: WHITE, lcolor: ICE });
s.addText([
  { text: "Add ramp-up and final UAT / cutover.  ", options: { bold: true, color: NAVY } },
  { text: "A realistic planning window is ", options: { color: INK } },
  { text: "~2.5–3 years at ~20 people", options: { bold: true, color: AMBER } },
  { text: ".", options: { color: INK } },
], { x: 7.8, y: 4.15, w: 4.8, h: 1.0, fontSize: 14, fontFace: "Arial", margin: 0, valign: "top" });
s.addText("More people shortens the calendar but raises coordination cost; ~20 balances throughput and onboarding.",
  { x: 7.8, y: 5.25, w: 4.8, h: 1.0, fontSize: 12, italic: true, color: GREY, fontFace: "Arial", margin: 0, valign: "top" });
footer(s, 6);

// ============================================================ Slide 7 — Phased roadmap
s = pres.addSlide(); s.background = { color: WHITE };
titleBlock(s, "5 · Phased roadmap", "Strangler-fig — module-by-module, value delivered early");
const phases = [
  ["0", "Foundation", "Framework, reusable components, pilot screens, recipe", GREEN, "DONE"],
  ["1", "Discovery", "Screen-by-screen inventory → firm estimate to ±15% (4–6 wks)", BLUE, ""],
  ["2", "Masters & config", "HO, Config, Lockers, HR — quick wins, prove velocity", BLUE, ""],
  ["3", "Reporting platform", "Report engine + reports (parallel workstream)", BLUE, ""],
  ["4", "RetailBanking txns", "The bulk: deposits → loans → clearing → cash → day-end", NAVY, ""],
  ["5", "Remaining modules", "Reconciliation, Inventory, Helpdesk, Customer360", BLUE, ""],
  ["6", "Migrate & cut over", "Data migration, parallel run, cutover, hardening, training", NAVY, ""],
];
// two rows of cards: 4 on top, 3 on bottom (sized to fit 4 across the content width)
const cardW = 2.74, cardH = 2.0, gx = 0.295, gy = 0.3;
const x0 = 0.7, y0 = 1.95, topCount = 4;
phases.forEach((p, i) => {
  const col = i < topCount ? i : i - topCount;
  const px = x0 + col * (cardW + gx);
  const py = i < topCount ? y0 : y0 + cardH + gy;
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: px, y: py, w: cardW, h: cardH, fill: { color: LIGHT }, rectRadius: 0.06, line: { type: "none" }, shadow: shadow() });
  // number badge
  s.addShape(pres.shapes.OVAL, { x: px + 0.18, y: py + 0.2, w: 0.56, h: 0.56, fill: { color: p[3] } });
  s.addText(p[0], { x: px + 0.18, y: py + 0.2, w: 0.56, h: 0.56, fontSize: 19, bold: true, color: WHITE, align: "center", valign: "middle", fontFace: "Georgia", margin: 0 });
  if (p[4]) s.addText(p[4], { x: px + cardW - 1.0, y: py + 0.24, w: 0.85, h: 0.28, fontSize: 9.5, bold: true, color: GREEN, align: "right", fontFace: "Arial", margin: 0 });
  s.addText("Phase " + p[0], { x: px + 0.84, y: py + 0.2, w: cardW - 1.0, h: 0.26, fontSize: 9.5, bold: true, color: BLUE, charSpacing: 1, fontFace: "Arial", margin: 0 });
  s.addText(p[1], { x: px + 0.84, y: py + 0.45, w: cardW - 1.0, h: 0.5, fontSize: 13, bold: true, color: NAVY, fontFace: "Arial", margin: 0, valign: "top" });
  s.addText(p[2], { x: px + 0.2, y: py + 1.05, w: cardW - 0.4, h: 0.85, fontSize: 10.5, color: GREY, fontFace: "Arial", margin: 0, valign: "top" });
});
footer(s, 7);

// ============================================================ Slide 8 — Risks
s = pres.addSlide(); s.background = { color: WHITE };
titleBlock(s, "6 · Key risks & cost drivers", "Where the estimate swings — manage these deliberately");
const risks = [
  ["Database target", "Raw-SQL screens use SQL-Server dialect. A single-DB target removes ~120–150 pd and de-risks delivery; multi-provider (Oracle / PostgreSQL) adds hardening.", AMBER],
  ["Reports: rehost vs rebuild", "362 report screens + 892 definitions. The rehost-vs-rebuild decision swings the total by ~500–700 pd — the single biggest lever.", BLUE],
  ["5,317 stored procedures", "Deep embedded logic (interest, GL, day-end). The highest-risk, highest-value engines — need senior attention and rigorous parallel-run validation.", NAVY],
  ["Banking correctness & compliance", "Reconciliation and likely regulator sign-off mandate extended UAT and parallel running before each cutover.", BLUE],
];
let yy = 1.85;
risks.forEach((r, i) => {
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 0.7, y: yy, w: 11.9, h: 1.18, fill: { color: i % 2 ? WHITE : LIGHT }, rectRadius: 0.05, line: { color: "E2E8F4", width: 1 } });
  s.addShape(pres.shapes.OVAL, { x: 0.95, y: yy + 0.32, w: 0.54, h: 0.54, fill: { color: r[2] } });
  s.addText(String(i + 1), { x: 0.95, y: yy + 0.32, w: 0.54, h: 0.54, fontSize: 18, bold: true, color: WHITE, align: "center", valign: "middle", fontFace: "Georgia", margin: 0 });
  s.addText(r[0], { x: 1.7, y: yy + 0.16, w: 10.6, h: 0.4, fontSize: 15, bold: true, color: NAVY, fontFace: "Arial", margin: 0 });
  s.addText(r[1], { x: 1.7, y: yy + 0.54, w: 10.7, h: 0.6, fontSize: 12, color: GREY, fontFace: "Arial", margin: 0, valign: "top" });
  yy += 1.3;
});
footer(s, 8);

// ============================================================ Slide 9 — Recommendation
s = pres.addSlide(); s.background = { color: NAVY };
s.addShape(pres.shapes.RECTANGLE, { x: 0, y: 0, w: 0.22, h: PH, fill: { color: AMBER } });
s.addText("RECOMMENDATION", { x: 0.9, y: 0.85, w: 11, h: 0.4, fontSize: 14, bold: true, color: ICE, charSpacing: 4, fontFace: "Arial", margin: 0 });
s.addText("Approve a 4–6 week discovery phase now", { x: 0.9, y: 1.3, w: 11.5, h: 0.9, fontSize: 32, bold: true, color: WHITE, fontFace: "Georgia", margin: 0 });
s.addText([
  { text: "Discovery converts this ROM into a committed plan (±15%): it confirms per-screen complexity in the attached inventory, settles the ", options: { color: ICE } },
  { text: "reports", options: { bold: true, color: WHITE } },
  { text: " and ", options: { color: ICE } },
  { text: "database-target", options: { bold: true, color: WHITE } },
  { text: " decisions, and produces a firm Phase-1 budget — all before any large build commitment.", options: { color: ICE } },
], { x: 0.9, y: 2.45, w: 11.4, h: 1.1, fontSize: 16, fontFace: "Arial", margin: 0, valign: "top" });
// three takeaway cards
const takeaways = [
  ["Low-risk start", "Proven foundation + 6 delivered screens; the team begins migrating in Phase 2 immediately after discovery."],
  ["Early value", "Strangler-fig cutover, module-by-module — no big-bang, benefits realised throughout."],
  ["Decision-ready", "Editable workbook + full 1,458-screen inventory accompany this deck for due diligence."],
];
takeaways.forEach((t, i) => {
  const px = 0.9 + i * 3.93;
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: px, y: 3.95, w: 3.7, h: 1.95, fill: { color: "2A3A6E" }, rectRadius: 0.07, line: { type: "none" } });
  s.addShape(pres.shapes.RECTANGLE, { x: px, y: 3.95, w: 3.7, h: 0.09, fill: { color: AMBER } });
  s.addText(t[0], { x: px + 0.22, y: 4.18, w: 3.3, h: 0.4, fontSize: 16, bold: true, color: WHITE, fontFace: "Arial", margin: 0 });
  s.addText(t[1], { x: px + 0.22, y: 4.62, w: 3.3, h: 1.2, fontSize: 12, color: ICE, fontFace: "Arial", margin: 0, valign: "top" });
});
s.addText("Supporting pack:  TrustBank-Migration-Estimate.docx (full report)  ·  TrustBank-Migration-Estimate.xlsx (editable assumptions + 1,458-screen inventory)",
  { x: 0.9, y: 6.55, w: 11.5, h: 0.4, fontSize: 11, italic: true, color: "9FB0D8", fontFace: "Arial", margin: 0 });

pres.writeFile({ fileName: __dirname + "/TrustBank-Migration-Estimate.pptx" }).then(f => console.log("pptx written:", f));
