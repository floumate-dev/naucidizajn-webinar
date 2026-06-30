# CLAUDE.md — Nauči Dizajn webinar funnel (jul 2026)

> Ovo je master kontekst za AI asistenta (Claude) i developera. Pročitaj ceo fajl
> pre rada. Sadrži arhitekturu, sve integracije sa tačnim vrednostima, i "gotchas"
> koji su skupo otkriveni. Posle čitanja znaš ceo sistem i možeš da radiš.

---

## 1. Šta je ovo

Funnel za **besplatan Zoom webinar** "AI dizajnira, ti zarađuješ" (Nauči Dizajn, vlasnik
Nikola Tripković). Termin: **četvrtak 9. jul 2026, 19h po Beogradu** (CEST = 17:00 UTC).

Tok: posetilac sa reklame → landing → popuni prijavu (ime, email, telefon) → registruje se
u **AEvent** (za attendance/watch-time) + šalje u **Make** (Kit + tracking) → redirect na
thank-you gde dobija **personalni referral link** + poziv da uđe u **WhatsApp grupu**.

Stack: **Webflow** (landing + thank-you, custom code) · **AEvent** (webinar hosting +
attendance + email sekvence) · **Make** (orkestracija → Kit) · **ConvertKit/Kit** (email lista) ·
**Supabase + Vercel** (referral sistem) · **WhatsApp** (Zoom link + podsetnici).

---

## 2. Mapa repo-a

```
webflow/
  landing-jul-2026.html      ← AKTUELNO. Ceo landing, paste u Webflow custom code. ASCII-safe.
  thankyou-jul-2026.html     ← AKTUELNO. Ceo thank-you, paste u Webflow custom code. ASCII-safe.
  _legacy/                   ← STARI direct-Kit flow (april/giveaway). Referenca, NE koristi se.
    landing-head.html
    thankyou-embed.html
api/
  signup.js                  ← Vercel serverless: POST /api/signup. Referral upsert u Supabase
                               (+ opciono Kit). Deploy: nauci-dizajnu-referral.vercel.app
supabase/
  schema.sql                 ← osnovna tabela `signups` + funkcije (pokreni jednom)
  mig-step-*.sql             ← migracije (last_name, get_dashboard, get_leaderboard, mask emails)
dashboard/
  index.html                 ← standalone referral dashboard (Vercel, app.naucidizajn.com)
docs/
  ARCHITECTURE.md            ← detaljan data-flow dijagram
  AEVENT.md                  ← AEvent integracija (secret, endpointi, REST token, attendance)
  MAKE-SCENARIO.md           ← Make scenario korak-po-korak
  GO-LIVE-CHECKLIST.md       ← šta mora pre lansiranja
.env.example                 ← Vercel env template (bez pravih tajni)
```

---

## 3. Tačne vrednosti (single source of truth)

| Stvar | Vrednost |
|---|---|
| Landing URL | `https://www.naucidizajn.com/ai-dizajnira-ti-zaradjujes-webinar-jul-2026` |
| Thank-you URL | `https://www.naucidizajn.com/ai-dizajnira-ti-zaradjujes-thank-you` |
| Thank-you slug (u landing JS) | `/ai-dizajnira-ti-zaradjujes-thank-you` |
| Webinar termin | 9. jul 2026, 19:00 Europe/Belgrade (CEST, 17:00 UTC) |
| Make webhook | `https://hook.eu2.make.com/n0sdfhr9jf1drjk85bjfnmkb2fh0eeqg` |
| AEvent tenant | `42253777` |
| AEvent `wtl` / webinarTimeline | `FLnvhOvvnBywf8g` |
| AEvent `webinarID` | `88179186855` (uuid `UGOzC1jrzHGcJoS`) |
| AEvent registration endpoint | `https://42253777.aevent.online/api-registration` |
| AEvent `secret` (client-side, public) | `UWKciZ4h9DKp92E` |
| AEvent REST API base | `https://42253777.aevent.online/api/` |
| WhatsApp grupa | `https://chat.whatsapp.com/LwhLYsmwuODLi06Nz19b5A?s=cl&p=i&mlu=0` |
| Referral API | `https://nauci-dizajnu-referral.vercel.app/api/signup` |
| Dashboard | `https://app.naucidizajn.com/?t=<token>` |
| Supabase project | `https://bfnutgejcpqxghyslxur.supabase.co` (ref `bfnutgejcpqxghyslxur`) |
| Vokativ endpoint (alt, ne koristi se) | `https://tibor-vokativ.vercel.app/api/vokativ?name=<ime>` |

**Tajne (NISU u repo-u, vidi .env.example):** Supabase `service_role` key, Kit API secret,
Vercel token, AEvent REST JWT token. Ove drži kao env varijable / van git-a.

---

## 4. Arhitektura (data flow)

```
LANDING (Webflow custom code: webflow/landing-jul-2026.html)
  URL params: ?source= ?specificsource= (ad tracking), ?r=CODE (referral)
  -> capture u sessionStorage (nd_trk, nd_ref)
  Modal prijava (JS-built, NIJE <form>; submit je <a id="ndm-submit">)
  Polja: #ndm-ime (Ime i prezime), #ndm-email, #ndm-country (+pozivni broj), #ndm-telefon
  Na submit (validacija OK):
    1. stash {email,name,ref} u sessionStorage (nd_signup) — za thank-you referral widget
    2. Make webhook (fetch JSON keepalive, fire-and-forget):
         { name, first_name, last_name, vokativ, email, phone(E.164), ref, source, specificsource }
         (vokativ se računa INLINE u browseru — vidi #6)
    3. AEvent registracija (fetch urlencoded, AWAITED):
         POST /api-registration  body: secret, wtl, name, email, phone, source, specificsource, ref
         -> AEvent dodeli upcoming sesiju, vrati subscriber.joinURL (tracked link) + replayURL
    4. AEvent OK -> success poruka + redirect na THANKYOU_URL (+ email/name/ref u URL-u)
       AEvent ERROR -> poruka u modalu, BEZ redirecta (osoba nije registrovana, može da ponovi)
       (Guard: ako je SECRET još "PASTE_..." -> preskoči AEvent, funnel radi bez attendance)

MAKE (scenario gradi se ručno — vidi docs/MAKE-SCENARIO.md)
  Webhook prima JSON -> add/update u Kit (custom fields) -> (Dusan zakazuje email sekvence u AEvent-u)
  Make je JEDINI pisac u Kit (zato thank-you /api/signup NE šalje tagId — bez duplog upisa)

THANK-YOU (Webflow custom code: webflow/thankyou-jul-2026.html)
  Čita {email,name,ref} iz URL params (pa fallback sessionStorage nd_signup)
  POST -> /api/signup BEZ tagId  => signup.js "Supabase-only" mod (kitEnabled=false)
    -> upsert u Supabase, vrati { shareUrl, dashboardUrl, refCode }
  Renderuje referral link (#ref-link) + dashboard link (#ref-dash) + WhatsApp CTA

DASHBOARD (Vercel: dashboard/index.html, app.naucidizajn.com/?t=token)
  GET rpc get_dashboard(token) -> progress, lista dovedenih, leaderboard
  "Pozdrav, <vokativ>!" (inline vokativ funkcija)

POSLE WEBINARA
  AEvent REST API (Bearer JWT) -> registrants + timelines -> watch-time po osobi
  (segmentacija u Kit: npr. tag "gledao >30min"). Vidi docs/AEVENT.md.
```

---

## 5. Integracije (sažeto; detalji u docs/)

### AEvent (docs/AEVENT.md)
- Registracija ide **client-side na `/api-registration`** sa `secret` + `wtl`. NE native
  `/registration` (traži captcha → redirect na /captchas/create, ne radi headless).
  NE REST `POST /api/registrants` (vraća 403 — gated).
- `secret` autorizuje preskakanje captcha. To je **kratki public kod** (`UWKciZ4h9DKp92E`),
  bezbedan client-side (kao kod Tibora). **NIJE** JWT REST token.
- AEvent sam dodeli "upcoming" sesiju za taj `wtl` (zato webinarid nije potreban u API pozivu).
- AEvent šalje webinar link + podsetnike (Nikola/Dusan zakazuje sekvence u AEvent dashboard-u).
- REST JWT token (zaseban, tajni): `webinars/registrants/timelines read+write`, `mcp:use`.
  `GET /api/webinars`, `GET /api/registrants`, `DELETE /api/registrants/{uuid}` rade.
  `POST /api/registrants` = 403 (registracija ide SAMO preko /api-registration).

### Make → Kit (docs/MAKE-SCENARIO.md)
- Webhook prima JSON sa `name, first_name, last_name, vokativ, email, phone, ref, source, specificsource`.
- Kit custom fields koje treba napraviti: `vokativ`, `phone`, `source`, `specificsource`, `ref`
  (+ `last_name` ako ne postoji). Pa apply July tag (triggeruje automation ako se koristi).
- **Webinar link NE ide iz Make-a** — AEvent ga šalje. Kit = lista + nurture.

### Supabase + Vercel referral (api/signup.js)
- Tabela `signups` (RLS ON, anon nema direktan pristup). Sve čita preko `get_dashboard(token)`,
  piše preko `create_signup()` (service_role).
- `signup.js` ima 2 moda: `kitEnabled = !!tagId`.
  - **Webinar (jul-2026):** thank-you šalje BEZ tagId → **Supabase-only** (Kit radi Make).
  - Kit-direct mod (stari/giveaway): sa tagId → upiše i u Kit.
- Response: `{ ok, refCode, dashboardUrl, shareUrl, count, isNew, firstName }`.
- CORS `ALLOWED_ORIGINS`: `https://naucidizajn.com`, `https://www.naucidizajn.com`.
  **Stranice su na `www.` — to je u listi. Ako se doda novi domen, dodaj ga ovde.**

### Vokativ (inline)
- Srpski vokativ se računa **u browseru** (kopija logike sa `tibor-vokativ.vercel.app`):
  rečnik izuzetaka `VOK_DICT` + pravila (samoglasnik/-k-g-h/-j → nominativ; ostalo + "e").
  Žensko/strano/nesigurno → nominativ (bezbedno). "Dušan"→"Dušane", "Ana"→"Ana".
- Postoji u: `landing-jul-2026.html` (šalje `vokativ` u Make) i `dashboard/index.html` (pozdrav).
- Zato Make NEMA HTTP korak za vokativ.

---

## 6. GOTCHAS — pročitaj pre nego što diraš (skupo naučeno)

1. **Webflow paste MORA biti ASCII-safe.** Ćirilica/dijakritika (š č ć đ ž) + emoji kao sirovi
   UTF-8 bajtovi se iskvare (mojibake: `š`→`≈°`) pri paste-u/renderu u Webflow-u. Zato su
   `landing-jul-2026.html` i `thankyou-jul-2026.html` **čist ASCII**: HTML tekst → numerički
   entiteti (`&#353;`), JS stringovi → `\uXXXX` escape, flag emoji → surrogate parovi.
   **Ako menjaš tekst u tim fajlovima, NE kucaj sirove ne-ASCII karaktere** — koristi entitete/escape.
   Re-ASCII skripta (Python): split po `<script>`, HTML deo → `&#N;`, JS deo → `\u`. (Dashboard
   NIJE Webflow paste, ima svoj `<meta charset>`, pa sme sirov UTF-8.)

2. **AEvent: 3 puta probano.** `/registration` = captcha (ne headless). `POST /api/registrants`
   (REST) = 403 gated. Radi SAMO `/api-registration` + `secret`. Bez secret-a:
   `{"error":"Unauthorized - Check that lowercase 'secret'..."}`. AEvent validira email
   deliverability (MX) — `@floumate.dev` (bez MX) puca kao "Invalid Email"; pravi mejlovi prolaze.

3. **Kit dupli upis.** Make je jedini pisac u Kit. Thank-you `/api/signup` se zove BEZ `tagId`
   (Supabase-only). Ako ikad dodaš tagId tamo, dobijaš duplikate u Kit-u.

4. **sessionStorage handoff.** Webflow redirect briše query/form podatke. Landing zato:
   (a) stash u `sessionStorage.nd_signup`, i (b) doda `email/name/ref` u redirect URL. Thank-you
   čita URL prvo, pa sessionStorage. Isti origin (www.naucidizajn.com) → sessionStorage preživi.

5. **Telefon E.164.** Country dropdown (default RS +381) + geo-IP auto-detekcija. `buildPhone(dialCode, raw)`:
   skida vodeću 0, poštuje `+`/`00`. Šalje se `+381...` u AEvent i Make (bitno za WhatsApp/SMS).

6. **Countdown timezone.** `new Date("2026-07-09T19:00:00+02:00")` — eksplicitni Beograd offset,
   inače internacionalni posetioci vide pogrešno. Sakriva se kad istekne.

7. **Dashboard TDZ.** Vokativ `const VOK_DICT` MORA biti definisan PRE init koda koji zove
   `render()` (inače `ReferenceError: Cannot access 'VOK_DICT' before initialization`). Stoji
   odmah posle config const-i, iznad `if (isDemoMode)`.

8. **Dashboard `WEBINAR_LANDING_URL`** je trenutno `giveaway-maj-2026` (dashboard je deljen sa
   giveaway kampanjom). Ako webinar registranti koriste ISTI dashboard, share link na dashboard-u
   bi pokazivao na giveaway, ne na webinar. **OTVORENO:** napravi dashboard campaign-aware ili
   zaseban dashboard za webinar. (Share link iz thank-you-a je ispravan; problem je samo prikaz na dashboard-u.)

9. **AEvent registracija je AWAITED i blokirajuća** na landing-u — namerno: ako AEvent padne,
   osoba NIJE registrovana, pa joj ne pokazujemo lažni success. Make je fire-and-forget (ne blokira).

---

## 7. Deploy

Vidi `docs/GO-LIVE-CHECKLIST.md` za pun redosled. Ukratko:

1. **Supabase:** napravi projekat, pokreni `supabase/schema.sql` pa `mig-step-*.sql` redom u SQL Editor-u.
2. **Vercel:** deploy ovog repo-a (`nauci-dizajnu-referral` projekat). Env varijable iz `.env.example`
   (bar `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `DASHBOARD_BASE_URL`). Custom domen
   `app.naucidizajn.com` na dashboard.
3. **AEvent:** webinar 9. jul; `secret` već u landing-u; zakaži email sekvence + Zoom soba.
4. **Make:** napravi scenario (webhook → Kit). Kit custom fields + tag.
5. **Webflow:** paste `landing-jul-2026.html` i `thankyou-jul-2026.html` u custom code odgovarajućih
   stranica. Publish.

## 8. Verifikacija lokalno

Statički fajlovi — `python3 -m http.server` u `webflow/` ili `dashboard/`. Dashboard demo:
`index.html?demo=1`. Landing: otvori, klikni CTA (otvara modal). NE submituj pravim podacima na
preview-u bez potrebe (gađa pravi Make webhook + AEvent). Za test AEvent-a koristi pravi mejl
i obriši registranta posle (`DELETE /api/registrants/{uuid}` sa REST JWT).

## 9. Trenutni status (na dan pisanja, ~jun 2026)

- ✅ Landing + thank-you napisani, ASCII-safe, testirani.
- ✅ AEvent registracija ŽIVA i testirana (secret ubačen, vraća joinURL).
- ✅ Supabase obrisan (fresh start, 0 redova).
- ✅ Dashboard: vokativ pozdrav + uklonjen stari brand.
- ⏳ Make scenario — napraviti (Dusan).
- ⏳ Kit custom fields + tag — napraviti.
- ⏳ AEvent email sekvence + Zoom soba — Dusan.
- ⏳ `app.naucidizajn.com` dashboard domen + `WEBINAR_LANDING_URL` reconcile (gotcha #8).
- ⏳ Paste oba fajla u Webflow + publish.
