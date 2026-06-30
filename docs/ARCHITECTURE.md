# Arhitektura — detaljan data flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ REKLAMA (Instagram itd.)                                                      │
│   URL: .../ai-dizajnira-ti-zaradjujes-webinar-jul-2026?source=ig&specificsource=ig_video │
└───────────────┬──────────────────────────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ LANDING  (webflow/landing-jul-2026.html, Webflow custom code)                 │
│  • capture ?source/?specificsource → sessionStorage.nd_trk                    │
│  • capture ?r=CODE → sessionStorage.nd_ref                                     │
│  • countdown na 2026-07-09T19:00+02:00                                         │
│  • CTA "#prijava" otvara JS modal (NIJE <form>)                               │
│  • polja: Ime i prezime, Email, Telefon (country dropdown +381 default, geo-IP)│
│  • submit (validacija OK):                                                     │
│       split imena → first_name/last_name; telefon → E.164; vokativ (inline)   │
│       (1) sessionStorage.nd_signup = {email,name,ref}                          │
│       (2) Make webhook (JSON keepalive, fire&forget)                          │
│       (3) AEvent /api-registration (urlencoded, AWAITED)                       │
│       (4) AEvent OK → redirect THANKYOU_URL?email&name&ref ; ERROR → poruka    │
└──────┬───────────────────────────────────┬───────────────────────────────────┘
       │ (2) Make                           │ (3) AEvent
       ▼                                    ▼
┌──────────────────────────┐   ┌───────────────────────────────────────────────┐
│ MAKE scenario            │   │ AEvent (tenant 42253777)                      │
│  webhook → Kit add       │   │  registruje za upcoming sesiju (wtl)          │
│  (custom fields, tag)    │   │  vraća subscriber.joinURL (tracked)           │
│  → Kit lista/nurture     │   │  šalje webinar link + podsetnike (sekvence)   │
└──────────────────────────┘   │  prati attendance/watch-time                  │
                               └───────────────────────────────────────────────┘
       │ (4) redirect
       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ THANK-YOU  (webflow/thankyou-jul-2026.html, Webflow custom code)              │
│  • čita email/name/ref iz URL (fallback sessionStorage.nd_signup)             │
│  • POST /api/signup (BEZ tagId = Supabase-only)                               │
│       → upsert u Supabase, vrati {shareUrl, dashboardUrl, refCode}            │
│  • prikaže referral link (#ref-link) + dashboard link (#ref-dash)             │
│  • WhatsApp CTA (Zoom link + podsetnici idu kroz grupu)                       │
└──────┬──────────────────────────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────┐   ┌──────────────────────────────┐
│ /api/signup (Vercel: api/signup.js)      │   │ SUPABASE (bfnutgejcpqxghyslxur)│
│  kitEnabled = !!tagId                     │──▶│  create_signup() (service_role)│
│  webinar mod: tagId prazan → Supabase-only│   │  tabela signups (RLS ON)       │
│  vraća refCode/dashboardUrl/shareUrl      │   │  get_dashboard(token) za read  │
└──────────────────────────────────────────┘   └──────────────────────────────┘
       ▲
       │ GET get_dashboard(token)
┌──────────────────────────────────────────────────────────────────────────────┐
│ DASHBOARD (dashboard/index.html, Vercel app.naucidizajn.com/?t=token)         │
│  progress bar, lista dovedenih, leaderboard, "Pozdrav, <vokativ>!"            │
└──────────────────────────────────────────────────────────────────────────────┘

POSLE WEBINARA: AEvent REST API (Bearer JWT) → watch-time po osobi → tag u Kit (segmentacija).
```

## Ključne odluke

- **Zašto AEvent client-side (`/api-registration`) a ne preko Make-a:** AEvent native forma traži
  captcha; REST POST je gated (403). `/api-registration` + secret radi headless i vraća join link.
  Registracija je na landing-u (a ne thank-you) jer mora pre redirecta i da blokira na grešci.
- **Zašto Make + odvojen referral Supabase:** Make vlasnik Kita; Supabase samo za referral
  counts/dashboard. Dva nezavisna sistema, oba keyed na email, bez konflikta.
- **Zašto Supabase-only na thank-you:** Kit upis radi Make → izbegava duplikate.
- **Zašto vokativ inline (browser):** jednostavniji Make (bez HTTP koraka), konzistentno sa landing-om.
