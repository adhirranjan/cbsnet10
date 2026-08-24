// Build the component guide into .txt, .html and .pdf from the .md source of truth.
// Offline + zero-install: pure Node for md->html/txt, headless Chrome/Edge for html->pdf.
//   Usage:  node docs/build-docs.mjs
// The .md is hand-authored; the other three are always generated (never hand-edit them).
import { readFileSync, writeFileSync, existsSync, mkdirSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { fileURLToPath, pathToFileURL } from "node:url";
import { dirname, join } from "node:path";
import { tmpdir } from "node:os";

const here = dirname(fileURLToPath(import.meta.url));
const BASE = "legacy-vs-new-components";
const mdPath = join(here, BASE + ".md");
const htmlPath = join(here, BASE + ".html");
const pdfPath = join(here, BASE + ".pdf");
const txtPath = join(here, BASE + ".txt");

const md = readFileSync(mdPath, "utf8");

// ---------- shared helpers ----------
const escapeHtml = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
// Inline: escape first, then code spans, bold, then links (our content has no nested cases).
const inline = (s) =>
    escapeHtml(s)
        .replace(/`([^`]+)`/g, "<code>$1</code>")
        .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
        .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');

const isTableSep = (l) => /^\s*\|?[\s:|-]*-[\s:|-]*\|?\s*$/.test(l) && l.includes("-");
const splitRow = (l) => l.trim().replace(/^\|/, "").replace(/\|$/, "").split("|").map((c) => c.trim());

// ---------- markdown -> html (construct subset: headings, hr, fences, tables, lists, quotes, paragraphs) ----------
function mdToHtml(src) {
    const lines = src.split(/\r?\n/);
    const out = [];
    let i = 0;
    while (i < lines.length) {
        const line = lines[i];
        if (line.trim() === "") { i++; continue; }

        // fenced code
        if (/^```/.test(line)) {
            i++;
            const buf = [];
            while (i < lines.length && !/^```/.test(lines[i])) { buf.push(lines[i]); i++; }
            i++; // closing fence
            out.push("<pre><code>" + escapeHtml(buf.join("\n")) + "</code></pre>");
            continue;
        }
        // heading
        let m = /^(#{1,6})\s+(.*)$/.exec(line);
        if (m) { const n = m[1].length; out.push(`<h${n}>${inline(m[2])}</h${n}>`); i++; continue; }
        // hr
        if (/^---+\s*$/.test(line)) { out.push("<hr>"); i++; continue; }
        // blockquote
        if (/^>\s?/.test(line)) {
            const buf = [];
            while (i < lines.length && /^>\s?/.test(lines[i])) { buf.push(lines[i].replace(/^>\s?/, "")); i++; }
            out.push("<blockquote>" + inline(buf.join(" ")) + "</blockquote>");
            continue;
        }
        // table (current row + a separator row next)
        if (line.trim().startsWith("|") && i + 1 < lines.length && isTableSep(lines[i + 1])) {
            const head = splitRow(line);
            i += 2; // skip header + separator
            const rows = [];
            while (i < lines.length && lines[i].trim().startsWith("|")) { rows.push(splitRow(lines[i])); i++; }
            let t = "<table><thead><tr>" + head.map((c) => `<th>${inline(c)}</th>`).join("") + "</tr></thead><tbody>";
            for (const r of rows) t += "<tr>" + r.map((c) => `<td>${inline(c)}</td>`).join("") + "</tr>";
            t += "</tbody></table>";
            out.push(t);
            continue;
        }
        // unordered list
        if (/^[-*]\s+/.test(line)) {
            const buf = [];
            while (i < lines.length && /^[-*]\s+/.test(lines[i])) { buf.push(lines[i].replace(/^[-*]\s+/, "")); i++; }
            out.push("<ul>" + buf.map((x) => `<li>${inline(x)}</li>`).join("") + "</ul>");
            continue;
        }
        // ordered list
        if (/^\d+\.\s+/.test(line)) {
            const buf = [];
            while (i < lines.length && /^\d+\.\s+/.test(lines[i])) { buf.push(lines[i].replace(/^\d+\.\s+/, "")); i++; }
            out.push("<ol>" + buf.map((x) => `<li>${inline(x)}</li>`).join("") + "</ol>");
            continue;
        }
        // paragraph
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
  body { font: 13px/1.5 -apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; color:#1f2430; max-width:980px; margin:24px auto; padding:0 20px; }
  h1 { font-size:24px; border-bottom:2px solid #2563eb; padding-bottom:6px; }
  h2 { font-size:19px; margin-top:28px; border-bottom:1px solid #e5e7eb; padding-bottom:4px; }
  h3 { font-size:15px; margin-top:18px; }
  code { background:#f3f4f6; padding:1px 4px; border-radius:4px; font-family:Consolas,Menlo,monospace; font-size:90%; }
  pre { background:#0f172a; color:#e2e8f0; padding:12px 14px; border-radius:8px; overflow:auto; }
  pre code { background:none; color:inherit; padding:0; font-size:12px; }
  table { border-collapse:collapse; width:100%; margin:10px 0; font-size:12px; }
  th,td { border:1px solid #d1d5db; padding:6px 9px; text-align:left; vertical-align:top; }
  th { background:#f1f5f9; }
  tr:nth-child(even) td { background:#fafafa; }
  blockquote { border-left:4px solid #2563eb; background:#eff6ff; margin:12px 0; padding:8px 14px; border-radius:0 6px 6px 0; }
  hr { border:none; border-top:1px solid #e5e7eb; margin:24px 0; }
  a { color:#2563eb; }
  @page { margin:14mm; }
`;

const html = `<!doctype html><html lang="en"><head><meta charset="utf-8">
<title>TrustBank CBS — Legacy → New Component Guide</title><style>${CSS}</style></head>
<body>${mdToHtml(md)}</body></html>`;
writeFileSync(htmlPath, html, "utf8");
console.log("wrote " + htmlPath);

// ---------- markdown -> plain text ----------
function mdToTxt(src) {
    const lines = src.split(/\r?\n/);
    const out = [];
    let inCode = false;
    const strip = (s) => s.replace(/`([^`]+)`/g, "$1").replace(/\*\*([^*]+)\*\*/g, "$1").replace(/\[([^\]]+)\]\(([^)]+)\)/g, "$1 ($2)");
    for (let i = 0; i < lines.length; i++) {
        const l = lines[i];
        if (/^```/.test(l)) { inCode = !inCode; continue; }
        if (inCode) { out.push("    " + l); continue; }
        if (isTableSep(l) && l.trim().startsWith("|")) continue; // drop table rule
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

// ---------- html -> pdf (headless Chrome/Edge; fresh profile so it works even if a browser is open) ----------
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
const profile = join(tmpdir(), "cbs-docs-chrome");
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
    process.exit(1);
}
