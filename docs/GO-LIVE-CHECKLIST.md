# Go-live checklist

Redosled za lansiranje. Označi kako ideš.

## 1. Supabase
- [ ] Projekat postoji (`bfnutgejcpqxghyslxur`) ili napravljen nov.
- [ ] SQL Editor: pokreni `supabase/schema.sql`, pa `mig-step-1..5` redom.
- [ ] Kopiraj `Project URL`, `service_role` key, `anon` key.
- [ ] (Ako kreće nova kampanja) tabela `signups` prazna / namespace-ovana.

## 2. Vercel (referral API + dashboard)
- [ ] Deploy ovog repo-a (projekat `nauci-dizajnu-referral`).
- [ ] Env vars (vidi `.env.example`): `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`,
      `DASHBOARD_BASE_URL=https://app.naucidizajn.com`.
- [ ] Custom domen `app.naucidizajn.com` → ovaj projekat (servira `dashboard/index.html`).
- [ ] Test: `POST /api/signup {email,name,ref:"",webinarUrl}` vraća `shareUrl` + `dashboardUrl`
      (NE `undefined/?t=` → znak da `DASHBOARD_BASE_URL` fali).
- [ ] CORS: `api/signup.js` `ALLOWED_ORIGINS` sadrži `https://www.naucidizajn.com` (sadrži ✓).
- [ ] **GOTCHA #8:** dashboard `WEBINAR_LANDING_URL` je `giveaway-maj-2026`. Ako webinar koristi
      isti dashboard — promeni na webinar URL ili napravi campaign-aware.

## 3. AEvent
- [ ] Webinar 9. jul 2026 19h postoji (webinarID `88179186855`).
- [ ] `secret` u landing-u tačan (`UWKciZ4h9DKp92E`) — već je. Ako se promeni, zameni u landing JS.
- [ ] Email sekvence zakazane (confirmation + podsetnici sa Zoom/join linkom).
- [ ] Zoom soba / room podešen; join link ide kroz AEvent emaile + WhatsApp grupu.
- [ ] Test: prijava sa pravim mejlom → stigne AEvent mejl → obriši test registranta
      (`DELETE /api/registrants/{uuid}` sa REST JWT).

## 4. Make + Kit
- [ ] Kit custom fields: `vokativ`, `phone`, `source`, `specificsource`, `ref` (+ `last_name`).
- [ ] Kit tag za July webinar.
- [ ] Make scenario: webhook → Kit add (+ tag). Vidi `docs/MAKE-SCENARIO.md`.
- [ ] Test: prijava → Make izvrši → Kit subscriber sa popunjenim poljima.

## 5. WhatsApp
- [ ] Grupa aktivna; invite link u thank-you-u tačan (`chat.whatsapp.com/HEkDXRydax7HG2mBr19tBf?mode=gi_t`).
- [ ] U grupi (opis/pin) stoji Zoom/join link i raspored podsetnika.

## 6. Webflow
- [ ] `landing-jul-2026.html` paste u landing custom code; `THANKYOU_URL` = tačan slug
      (`/ai-dizajnira-ti-zaradjujes-thank-you`).
- [ ] `thankyou-jul-2026.html` paste u thank-you custom code; `CONFIG.webinarUrl` = živi landing URL.
- [ ] Oba slug-a vraćaju 200 (publish-ovano).
- [ ] **GOTCHA #1:** ako menjaš tekst u tim fajlovima — ASCII-safe (entiteti/`\u`), ne sirov UTF-8.
- [ ] (Opciono) VSL video embed u thank-you `.vsl` blok.

## 7. End-to-end test
- [ ] Otvori landing sa `?source=test&specificsource=e2e&r=` → popuni → submit.
- [ ] AEvent: registrant kreiran, stigao mejl. Make: Kit subscriber. Redirect na thank-you.
- [ ] Thank-you: referral link generisan; WhatsApp dugme vodi u grupu.
- [ ] Dashboard: otvori `app.naucidizajn.com/?t=<token>` → "Pozdrav, <vokativ>!", progress.
- [ ] Obriši test podatke (AEvent registrant + Supabase red).
