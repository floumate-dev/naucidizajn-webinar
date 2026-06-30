# naucidizajn-webinar

Funnel za webinar **"AI dizajnira, ti zarađuješ"** (Nauči Dizajn) — 9. jul 2026, 19h Beograd.

Landing + thank-you (Webflow) · AEvent registracija/attendance · Make → Kit · referral sistem
(Supabase + Vercel) · WhatsApp grupa.

## 👉 Počni odavde

**Ako si AI asistent (Claude) ili novi developer — pročitaj [`CLAUDE.md`](./CLAUDE.md) prvi.**
Tamo je ceo sistem: arhitektura, sve integracije sa tačnim vrednostima, i "gotchas".

## Struktura

| Folder | Šta |
|---|---|
| [`webflow/`](./webflow) | `landing-jul-2026.html` + `thankyou-jul-2026.html` — paste u Webflow custom code (ASCII-safe). |
| [`api/`](./api) | `signup.js` — Vercel serverless za referral (Supabase upsert). |
| [`supabase/`](./supabase) | Schema + migracije za `signups` tabelu. |
| [`dashboard/`](./dashboard) | Standalone referral dashboard (Vercel). |
| [`docs/`](./docs) | Deep-dive: arhitektura, AEvent, Make scenario, go-live checklist. |

## Deploy (ukratko)

1. Supabase: `schema.sql` + `mig-step-*.sql` u SQL Editor.
2. Vercel: deploy + env (`.env.example`) + `app.naucidizajn.com` na dashboard.
3. AEvent: webinar + email sekvence + Zoom soba (secret već u landing-u).
4. Make: scenario webhook → Kit (+ Kit custom fields/tag).
5. Webflow: paste oba HTML fajla, publish.

Pun redosled + provere: [`docs/GO-LIVE-CHECKLIST.md`](./docs/GO-LIVE-CHECKLIST.md).

## ⚠️ Tajne

Nikad ne commituj `.env.local`, `service_role` key, Kit secret, Vercel token, AEvent REST JWT.
Vidi `.env.example`. (AEvent client `secret` i Make webhook URL SU u landing-u — to su public
client-side vrednosti, već vidljive u Webflow source-u.)
