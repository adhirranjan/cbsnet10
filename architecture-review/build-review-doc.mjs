// Build the architecture review into .txt, .html, .docx and .pdf from the .md source.
// Offline + zero-install: pure Node for md->html/txt, the repo-vendored `docx` lib for md->docx (Word),
// headless Chrome/Edge for html->pdf. Adapted from docs/architecture/build-arch-doc.mjs.
//   Usage:  node docs/architecture-review/build-review-doc.mjs
// The .md is hand-authored; the other formats are always generated (never hand-edit them).
import { readFileSync, writeFileSync, existsSync, mkdirSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { fileURLToPath, pathToFileURL } from "node:url";
import { dirname, join } from "node:path";
import { tmpdir } from "node:os";
import { createRequire } from "node:module";

const here = dirname(fileURLToPath(import.meta.url));
// Optional CLI: node build-review-doc.mjs [BASE] ["Title"]  — defaults to the architecture review.
const BASE = process.argv[2] || "ARCHITECTURE-REVIEW";
const TITLE = process.argv[3] || "TrustBank CBS — Architecture Review";
const mdPath = join(here, BASE + ".md");
const htmlPath = join(here, BASE + ".html");
const pdfPath = join(here, BASE + ".pdf");
const txtPath = join(here, BASE + ".txt");
const docxPath = join(here, BASE + ".docx");

const md = readFileSync(mdPath, "utf8");

const escapeHtml = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
const inline = (s) =>
    escapeHtml(s)
        .replace(/`([^`]+)`/g, "<code>$1</code>")
        .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
        .replace(/\*([^*]+)\*/g, "<em>$1</em>")
        .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');

const isTableSep = (l) => /^\s*\|?[\s:|-]*-[\s:|-]*\|?\s*$/.test(l) && l.includes("-");
const splitRow = (l) => l.trim().replace(/^\|/, "").replace(/\|$/, "").split("|").map((c) => c.trim());

function mdToHtml(src) {
    const lines = src.split(/\r?\n/);
    const out = [];
    let i = 0;
    while (i < lines.length) {
        const line = lines[i];
        if (line.trim() === "") { i++; continue; }
        if (/^```/.test(line)) {
            i++;
            const buf = [];
            while (i < lines.length && !/^```/.test(lines[i])) { buf.push(lines[i]); i++; }
            i++;
            out.push("<pre><code>" + escapeHtml(buf.join("\n")) + "</code></pre>");
            continue;
        }
        let m = /^(#{1,6})\s+(.*)$/.exec(line);
        if (m) { const n = m[1].length; out.push(`<h${n}>${inline(m[2])}</h${n}>`); i++; continue; }
        if (/^---+\s*$/.test(line)) { out.push("<hr>"); i++; continue; }
        if (/^>\s?/.test(line)) {
            const buf = [];
            while (i < lines.length && /^>\s?/.test(lines[i])) { buf.push(lines[i].replace(/^>\s?/, "")); i++; }
            out.push("<blockquote>" + inline(buf.join(" ")) + "</blockquote>");
            continue;
        }
        if (line.trim().startsWith("|") && i + 1 < lines.length && isTableSep(lines[i + 1])) {
            const head = splitRow(line);
            i += 2;
            const rows = [];
            while (i < lines.length && lines[i].trim().startsWith("|")) { rows.push(splitRow(lines[i])); i++; }
            let t = "<table><thead><tr>" + head.map((c) => `<th>${inline(c)}</th>`).join("") + "</tr></thead><tbody>";
            for (const r of rows) t += "<tr>" + r.map((c) => `<td>${inline(c)}</td>`).join("") + "</tr>";
            t += "</tbody></table>";
            out.push(t);
            continue;
        }
        if (/^[-*]\s+/.test(line)) {
            const buf = [];
            while (i < lines.length && /^[-*]\s+/.test(lines[i])) { buf.push(lines[i].replace(/^[-*]\s+/, "")); i++; }
            out.push("<ul>" + buf.map((x) => `<li>${inline(x)}</li>`).join("") + "</ul>");
            continue;
        }
        if (/^\d+\.\s+/.test(line)) {
            const buf = [];
            while (i < lines.length && /^\d+\.\s+/.test(lines[i])) { buf.push(lines[i].replace(/^\d+\.\s+/, "")); i++; }
            out.push("<ol>" + buf.map((x) => `<li>${inline(x)}</li>`).join("") + "</ol>");
            continue;
        }
        const buf = [];
        while (i < lines.length && lines[i].trim() !== "" && !/^(#{1,6}\s|```|>|[-*]\s|\d+\.\s|---+\s*$)/.test(lines[i]) &&
               !(lines[i].trim().startsWith("|") && i + 1 < lines.length && isTableSep(lines[i + 1]))) {
            buf.push(lines[i]); i++;
        }
        out.push("<p>" + inline(buf.join(" ")) + "</p>");
    }
    return out.join("\n");
}

const CSS = `
  :root { color-scheme: light; }
  body { font: 13px/1.6 -apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; color:#1f2430; max-width:980px; margin:24px auto; padding:0 20px; }
  h1 { font-size:26px; border-bottom:3px solid #1E5F74; padding-bottom:8px; color:#12454f; }
  h2 { font-size:19px; margin-top:30px; border-bottom:1px solid #e5e7eb; padding-bottom:4px; color:#12454f; }
  h3 { font-size:15px; margin-top:20px; }
  code { background:#f3f4f6; padding:1px 4px; border-radius:4px; font-family:Consolas,Menlo,monospace; font-size:90%; }
  pre { background:#0f172a; color:#e2e8f0; padding:14px 16px; border-radius:8px; overflow:auto; line-height:1.4; }
  pre code { background:none; color:inherit; padding:0; font-size:12px; }
  table { border-collapse:collapse; width:100%; margin:12px 0; font-size:12px; }
  th,td { border:1px solid #d1d5db; padding:7px 10px; text-align:left; vertical-align:top; }
  th { background:#e3eef1; color:#12454f; }
  tr:nth-child(even) td { background:#fafafa; }
  blockquote { border-left:4px solid #1E5F74; background:#eaf3f5; margin:14px 0; padding:8px 14px; border-radius:0 6px 6px 0; color:#374151; }
  hr { border:none; border-top:1px solid #e5e7eb; margin:26px 0; }
  a { color:#1E5F74; }
  em { color:#475569; }
  @page { margin:16mm; }
`;

const html = `<!doctype html><html lang="en"><head><meta charset="utf-8">
<title>${TITLE}</title><style>${CSS}</style></head>
<body>${mdToHtml(md)}</body></html>`;
writeFileSync(htmlPath, html, "utf8");
console.log("wrote " + htmlPath);

function mdToTxt(src) {
    const lines = src.split(/\r?\n/);
    const out = [];
    let inCode = false;
    const strip = (s) => s.replace(/`([^`]+)`/g, "$1").replace(/\*\*([^*]+)\*\*/g, "$1").replace(/\*([^*]+)\*/g, "$1").replace(/\[([^\]]+)\]\(([^)]+)\)/g, "$1 ($2)");
    for (let i = 0; i < lines.length; i++) {
        const l = lines[i];
        if (/^```/.test(l)) { inCode = !inCode; continue; }
        if (inCode) { out.push("    " + l); continue; }
        if (isTableSep(l) && l.trim().startsWith("|")) continue;
        let m = /^(#{1,6})\s+(.*)$/.exec(l);
        if (m) {
            const text = strip(m[2]);
            out.push("");
            out.push(text);
            if (m[1].length === 1) out.push("=".repeat(text.length));
            else if (m[1].length === 2) out.push("-".repeat(text.length));
            continue;
        }
        if (/^---+\s*$/.test(l)) { out.push("-".repeat(60)); continue; }
        if (l.trim().startsWith("|")) { out.push(strip(l.trim().replace(/^\|/, "").replace(/\|$/, "").split("|").map((c) => c.trim()).join("  |  "))); continue; }
        out.push(strip(l));
    }
    return out.join("\r\n");
}
writeFileSync(txtPath, mdToTxt(md), "utf8");
console.log("wrote " + txtPath);

try {
    const req = createRequire(join(here, "..", "migration-estimate", "build_docx.js"));
    const {
        Document, Packer, Paragraph, TextRun, ExternalHyperlink, Table, TableRow, TableCell,
        AlignmentType, HeadingLevel, BorderStyle, WidthType, ShadingType, Footer, PageNumber,
    } = req("docx");

    const NAVY = "1E5F74", CODEBG = "0F172A", CODEFG = "E2E8F0", HEADBG = "E3EEF1", ZEBRA = "FAFAFA";
    const thin = { style: BorderStyle.SINGLE, size: 1, color: "D1D5DB" };
    const cellBorders = { top: thin, bottom: thin, left: thin, right: thin };

    const inlineRuns = (s, base = {}) => {
        const runs = [];
        const re = /(\*\*([^*]+)\*\*)|(\*([^*]+)\*)|(`([^`]+)`)|(\[([^\]]+)\]\(([^)]+)\))/g;
        let last = 0, m;
        while ((m = re.exec(s))) {
            if (m.index > last) runs.push(new TextRun({ text: s.slice(last, m.index), ...base }));
            if (m[1]) runs.push(new TextRun({ text: m[2], bold: true, ...base }));
            else if (m[3]) runs.push(new TextRun({ text: m[4], italics: true, ...base }));
            else if (m[5]) runs.push(new TextRun({ text: m[6], font: "Consolas", ...base }));
            else if (m[7]) runs.push(new ExternalHyperlink({ link: m[9], children: [new TextRun({ text: m[8], style: "Hyperlink", ...base })] }));
            last = re.lastIndex;
        }
        if (last < s.length) runs.push(new TextRun({ text: s.slice(last), ...base }));
        return runs.length ? runs : [new TextRun({ text: s, ...base })];
    };

    const headingFor = (n) => [HeadingLevel.HEADING_1, HeadingLevel.HEADING_2, HeadingLevel.HEADING_3,
        HeadingLevel.HEADING_4, HeadingLevel.HEADING_5, HeadingLevel.HEADING_6][n - 1];

    const mdCell = (text, { header = false, zebra = false, pct = 50 } = {}) => new TableCell({
        borders: cellBorders, width: { size: pct, type: WidthType.PERCENTAGE },
        shading: header ? { fill: NAVY, type: ShadingType.CLEAR, color: "auto" }
            : zebra ? { fill: ZEBRA, type: ShadingType.CLEAR, color: "auto" } : undefined,
        margins: { top: 60, bottom: 60, left: 110, right: 110 },
        children: [new Paragraph({ children: inlineRuns(text, header ? { bold: true, color: "FFFFFF" } : {}) })],
    });

    function mdToDocx(src) {
        const lines = src.split(/\r?\n/);
        const out = [];
        let i = 0;
        while (i < lines.length) {
            const line = lines[i];
            if (line.trim() === "") { i++; continue; }
            if (/^```/.test(line)) {
                i++;
                const buf = [];
                while (i < lines.length && !/^```/.test(lines[i])) { buf.push(lines[i]); i++; }
                i++;
                buf.forEach((b) => out.push(new Paragraph({
                    shading: { fill: CODEBG, type: ShadingType.CLEAR, color: "auto" },
                    spacing: { after: 0, before: 0, line: 240 },
                    children: [new TextRun({ text: b || " ", font: "Consolas", size: 15, color: CODEFG })],
                })));
                out.push(new Paragraph({ spacing: { after: 120 }, children: [] }));
                continue;
            }
            let m = /^(#{1,6})\s+(.*)$/.exec(line);
            if (m) { out.push(new Paragraph({ heading: headingFor(m[1].length), children: inlineRuns(m[2]) })); i++; continue; }
            if (/^---+\s*$/.test(line)) {
                out.push(new Paragraph({ border: { bottom: { style: BorderStyle.SINGLE, size: 4, color: "E5E7EB", space: 1 } }, spacing: { after: 160 }, children: [] }));
                i++; continue;
            }
            if (/^>\s?/.test(line)) {
                const buf = [];
                while (i < lines.length && /^>\s?/.test(lines[i])) { buf.push(lines[i].replace(/^>\s?/, "")); i++; }
                out.push(new Paragraph({
                    border: { left: { style: BorderStyle.SINGLE, size: 12, color: NAVY, space: 8 } },
                    shading: { fill: HEADBG, type: ShadingType.CLEAR, color: "auto" },
                    spacing: { after: 120 }, indent: { left: 200 },
                    children: inlineRuns(buf.join(" "), { italics: true }),
                }));
                continue;
            }
            if (line.trim().startsWith("|") && i + 1 < lines.length && isTableSep(lines[i + 1])) {
                const head = splitRow(line);
                i += 2;
                const bodyRows = [];
                while (i < lines.length && lines[i].trim().startsWith("|")) { bodyRows.push(splitRow(lines[i])); i++; }
                const pct = Math.floor(100 / head.length);
                const rows = [new TableRow({ tableHeader: true, children: head.map((c) => mdCell(c, { header: true, pct })) })];
                bodyRows.forEach((r, k) => rows.push(new TableRow({
                    children: head.map((_, ci) => mdCell(r[ci] ?? "", { zebra: k % 2 === 1, pct })),
                })));
                out.push(new Table({ width: { size: 100, type: WidthType.PERCENTAGE }, rows }));
                out.push(new Paragraph({ spacing: { after: 120 }, children: [] }));
                continue;
            }
            if (/^[-*]\s+/.test(line)) {
                while (i < lines.length && /^[-*]\s+/.test(lines[i])) {
                    out.push(new Paragraph({ bullet: { level: 0 }, spacing: { after: 60 }, children: inlineRuns(lines[i].replace(/^[-*]\s+/, "")) }));
                    i++;
                }
                continue;
            }
            if (/^\d+\.\s+/.test(line)) {
                while (i < lines.length && /^\d+\.\s+/.test(lines[i])) {
                    const mm = /^(\d+)\.\s+(.*)$/.exec(lines[i]);
                    out.push(new Paragraph({ spacing: { after: 60 }, indent: { left: 360, hanging: 240 }, children: inlineRuns(mm[1] + ". " + mm[2]) }));
                    i++;
                }
                continue;
            }
            const buf = [];
            while (i < lines.length && lines[i].trim() !== "" && !/^(#{1,6}\s|```|>|[-*]\s|\d+\.\s|---+\s*$)/.test(lines[i]) &&
                   !(lines[i].trim().startsWith("|") && i + 1 < lines.length && isTableSep(lines[i + 1]))) {
                buf.push(lines[i]); i++;
            }
            out.push(new Paragraph({ spacing: { after: 120 }, children: inlineRuns(buf.join(" ")) }));
        }
        return out;
    }

    const doc = new Document({
        creator: "TrustBank CBS",
        title: TITLE,
        styles: {
            default: { document: { run: { font: "Calibri", size: 21 } } },
            paragraphStyles: [
                { id: "Heading1", name: "Heading 1", basedOn: "Normal", next: "Normal", quickFormat: true, run: { size: 32, bold: true, color: NAVY }, paragraph: { spacing: { before: 240, after: 120 }, border: { bottom: { style: BorderStyle.SINGLE, size: 8, color: NAVY, space: 4 } } } },
                { id: "Heading2", name: "Heading 2", basedOn: "Normal", next: "Normal", quickFormat: true, run: { size: 26, bold: true, color: NAVY }, paragraph: { spacing: { before: 280, after: 100 }, border: { bottom: { style: BorderStyle.SINGLE, size: 4, color: "E5E7EB", space: 3 } } } },
                { id: "Heading3", name: "Heading 3", basedOn: "Normal", next: "Normal", quickFormat: true, run: { size: 23, bold: true, color: "1F2430" }, paragraph: { spacing: { before: 200, after: 80 } } },
            ],
        },
        sections: [{
            properties: { page: { margin: { top: 1000, bottom: 1000, left: 1100, right: 1100 } } },
            footers: { default: new Footer({ children: [new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ text: "TrustBank CBS — Architecture Review    ", size: 16, color: "888888" }), new TextRun({ children: ["Page ", PageNumber.CURRENT], size: 16, color: "888888" })] })] }) },
            children: mdToDocx(md),
        }],
    });

    const buf = await Packer.toBuffer(doc);
    writeFileSync(docxPath, buf);
    console.log("wrote " + docxPath);
} catch (e) {
    console.error("DOCX step skipped (" + (e.message || e) + "). The .html/.txt were still written.");
}

const browsers = [
    "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
    "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe",
    "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe",
    "C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe",
];
const browser = browsers.find((p) => existsSync(p));
if (!browser) {
    console.error("No Chrome/Edge found — wrote .html and .txt; open the .html and Print to PDF manually.");
    process.exit(0);
}
const profile = join(tmpdir(), "cbs-review-doc-chrome");
mkdirSync(profile, { recursive: true });
const args = [
    "--headless=new", "--disable-gpu", "--no-pdf-header-footer",
    `--user-data-dir=${profile}`,
    `--print-to-pdf=${pdfPath}`,
    pathToFileURL(htmlPath).href,
];
try {
    execFileSync(browser, args, { stdio: "inherit", timeout: 120000 });
    console.log("wrote " + pdfPath + "  (via " + browser.split("\\").pop() + ")");
} catch (e) {
    console.error("PDF step failed (" + (e.message || e) + "). The .html + .txt were still written.");
}
