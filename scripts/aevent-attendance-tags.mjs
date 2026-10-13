// Tagovi prisustva posle webinara: AEvent CSV → Kit (SOP: docs/SOP-POSLE-WEBINARA.md).
//
// Proba (ništa ne upisuje, samo brojke):
//   node --env-file="../naucidizajn-dashboard/.env.local" scripts/aevent-attendance-tags.mjs --csv "C:/put/registrant-download.csv" --webinar "13.10.2026." --pitch 19:52
// Upis (tek kad su brojke proverene):
//   isto + --write
//
// Pravila (13.10.2026, Danilo):
//   No show          Attended != Yes
//   Pogledali pitch  bio prisutan u trenutku kad je rečena cena (--pitch); vreme izlaska = ulazak + ukupno vreme
//   <20%             otišao pre cene i gledao manje od --short minuta (podrazumevano 20)
//   Do pitcha        otišao pre cene, gledao --short+ minuta
// <20% i Do pitcha se NE preklapaju — mejl „bili, izašli pre ponude" ide na oba (Matching any).
// Menja SAMO tagove „Webinar <datum> | No show / <20% / Do pitcha / Pogledali pitch"; tag mora već postojati.
import { readFileSync } from "node:fs";

const args = Object.fromEntries(
  process.argv.slice(2).reduce((acc, a, i, all) => (a.startsWith("--") ? [...acc, [a.slice(2), all[i + 1]?.startsWith("--") || all[i + 1] === undefined ? true : all[i + 1]]] : acc), []),
);
if (!args.csv || !args.webinar || !args.pitch) {
  console.error('Treba: --csv <fajl> --webinar "13.10.2026." --pitch 19:52 [--short 20] [--write]');
  process.exit(1);
}
const KEY = process.env.KIT_API_KEY;
if (!KEY) throw new Error("KIT_API_KEY nije podešen (pokreni sa --env-file na .env.local dashboard-a)");
const H = { "X-Kit-Api-Key": KEY, Accept: "application/json", "Content-Type": "application/json" };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const [ph, pm] = String(args.pitch).split(":").map(Number);
const PITCH = ph * 60 + pm;
const SHORT = Number(args.short ?? 20);

function parse(t) {
  const rows = [];
  let row = [], cur = "", q = false;
  for (let i = 0; i < t.length; i++) {
    const c = t[i];
    if (q) {
      if (c === '"') {
        if (t[i + 1] === '"') { cur += '"'; i++; } else q = false;
      } else cur += c;
    } else if (c === '"') q = true;
    else if (c === ",") { row.push(cur); cur = ""; }
    else if (c === "\n") { row.push(cur.replace(/\r$/, "")); rows.push(row); row = []; cur = ""; }
    else cur += c;
  }
  if (cur || row.length) { row.push(cur); rows.push(row); }
  return rows;
}
const [head, ...rows] = parse(readFileSync(args.csv, "utf8").replace(/^\uFEFF/, ""));
const ix = Object.fromEntries(head.map((h, i) => [h, i]));
for (const col of ["Email", "Attended", "Total Attendance Time", "Join Time", "Webinar Date"]) if (!(col in ix)) throw new Error(`CSV nema kolonu „${col}" — da li je to AEvent „registrant download"?`);
const data = rows.filter((r) => r.length > 3);

const mins = (s) => { const m = /(\d+)H\s*(\d+)M\s*(\d+)S/.exec(s ?? ""); return m ? +m[1] * 60 + +m[2] + +m[3] / 60 : 0; };
const joinMin = (s) => { const m = /(\d+):(\d+)\s*(AM|PM)/.exec(s ?? ""); if (!m) return null; let h = +m[1] % 12; if (m[3] === "PM") h += 12; return h * 60 + +m[2]; };
function classify(r) {
  if (r[ix.Attended] !== "Yes") return "No show";
  const total = mins(r[ix["Total Attendance Time"]]);
  const j = joinMin(r[ix["Join Time"]]);
  if (j !== null && j + total >= PITCH) return "Pogledali pitch";
  if (total < SHORT) return "<20%";
  return "Do pitcha";
}

const dates = [...new Set(data.map((r) => r[ix["Webinar Date"]]))];
console.log("Webinar u CSV-u:", dates.join(" | "), "· redova:", data.length);
if (dates.length !== 1) throw new Error("CSV ima više webinara — skini izveštaj samo za ovaj");
const items = data.map((r) => ({ email: r[ix.Email].trim().toLowerCase(), k: classify(r) })).sort((a, b) => (a.k === "No show") - (b.k === "No show"));
const plan = {};
for (const it of items) plan[it.k] = (plan[it.k] ?? 0) + 1;
console.log("Raspodela:", plan);
if (!args.write) {
  console.log("PROBA — ništa nije upisano. Za upis dodaj --write.");
  process.exit(0);
}

const tags = (await (await fetch("https://api.kit.com/v4/tags?per_page=1000", { headers: H })).json()).tags;
const tagId = {};
for (const k of ["No show", "<20%", "Do pitcha", "Pogledali pitch"]) {
  const name = `Webinar ${args.webinar} | ${k}`;
  const t = tags.find((x) => x.name.trim() === name);
  if (!t) throw new Error(`Nema taga „${name}" u Kit-u — napravi ga pre upisa`);
  tagId[k] = t.id;
}
const done = {}, missing = {};
let n = 0;
for (const it of items) {
  for (let attempt = 0; attempt < 6; attempt++) {
    const r = await fetch(`https://api.kit.com/v4/tags/${tagId[it.k]}/subscribers`, { method: "POST", headers: H, body: JSON.stringify({ email_address: it.email }) });
    if (r.status === 429) { await sleep(15000); continue; }
    if (r.ok) done[it.k] = (done[it.k] ?? 0) + 1;
    else if (r.status === 404 || r.status === 422) missing[it.k] = (missing[it.k] ?? 0) + 1;
    else throw new Error(`Kit ${r.status} ${await r.text()}`);
    break;
  }
  if (++n % 100 === 0) console.log(new Date().toLocaleTimeString("sr-RS"), n, "/", items.length, JSON.stringify(done));
  await sleep(520); // Kit ključ: ~120 zahteva u minuti
}
console.log("GOTOVO", { tagovano: done, nemaUKitu: missing });
