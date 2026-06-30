# AEvent integracija

AEvent (tenant `42253777`) hostuje webinar, prati attendance/watch-time i šalje webinar
link + podsetnike. Ovaj dokument je reverse-engineering AEvent API-ja (nema javne docs koje smo koristili).

## TL;DR

- Registracija ide **client-side POST na `/api-registration`** sa `secret` + `wtl` + `name/email/phone`.
- `secret` = `UWKciZ4h9DKp92E` (kratki public kod, bezbedan u Webflow source-u).
- `wtl` = `FLnvhOvvnBywf8g` (= webinarTimeline). `webinarID` = `88179186855`.
- AEvent sam izabere upcoming sesiju → vraća `subscriber.joinURL` (per-registrant tracked link).
- REST API (Bearer JWT) se koristi SAMO posle webinara za attendance/watch-time.

## Tri puta registracije (zašto baš `/api-registration`)

| Endpoint | Rezultat | Zaključak |
|---|---|---|
| `POST /registration` (native forma) | 302 → `/api/registrants/{uuid}/captchas/create` | **Captcha**, ne radi headless. Forma iz AEvent-a sa `{{!webinarid}}` template tagovima — tagovi se NE resolvuju na Webflow-u. |
| `POST /api/registrants` (REST, Bearer JWT) | `422 webinarTimeline required` → onda `403` (prazno) | **Gated** — ne može da kreira registranta ovim putem. |
| `POST /api-registration` (+ `secret`) | `{"subscriber":{...,"joinURL":...}}` ✅ | **RADI.** Secret autorizuje preskakanje captcha. |

## `/api-registration` — kako se zove (kao na landing-u)

```
POST https://42253777.aevent.online/api-registration
Content-Type: application/x-www-form-urlencoded

secret=UWKciZ4h9DKp92E
wtl=FLnvhOvvnBywf8g
name=Petar Petrović
email=...            (mora proći AEvent MX/deliverability check)
phone=+381...        (E.164)
source=...           (opciono — ad tracking, ide u customtags AEvent-a)
specificsource=...
ref=...              (referral kod)
```

Greške:
- bez/lošeg secret-a: `{"error":"Unauthorized - Check that lowercase 'secret' is being sent with the correct value."}` (401)
- nevalidan email (npr. domen bez MX): `Invalid Email Entered ... Ref=#web-001` (422)

Uspeh vraća `subscriber.joinURL` (npr. `https://joinevent.link/.../...`) i `replayURL`,
+ `webinar` blok (timelineName, dayofweek, userTime, itd.).

**Na landing-u:** poziv je AWAITED. AEvent OK → success + redirect na thank-you. AEvent error →
poruka u modalu, BEZ redirecta (osoba nije registrovana). `parseAEventError()` mapira poruke na srpski.
Guard: ako je `AEVENT.SECRET` još `"PASTE_..."` → preskoči AEvent (funnel radi bez attendance).

## REST API (Bearer JWT) — za attendance POSLE webinara

Base: `https://42253777.aevent.online/api/`. Header: `Authorization: Bearer <JWT>` + `Accept: application/json`.
JWT je TAJNA (scopes: webinars/registrants/timelines read+write, media, forms, mcp:use, chat.write).
**Ne commituj ga.** Drži kao `AEVENT_API_TOKEN` env / van git-a.

Korisni pozivi:
- `GET /api/webinars` → lista webinara (uniqueID, uuid, webinarID, timeStamp, webinarTimeline...).
- `GET /api/webinars/88179186855` → pun webinar objekat.
- `GET /api/registrants` → `{"success":[...],"total":N}`.
- `DELETE /api/registrants/{uuid}` → 204 (radi — koristi za brisanje test registranata).
- `POST /api/registrants` → **403, ne koristi** (registracija ide preko /api-registration).

Napomena o rutiranju: radi flat pattern `/{tenant}.aevent.online/api/{resource}`. Varijante tipa
`/api/v1/...` ili `/api/webinars/{uuid}/registrants` vraćaju `410 No User`.

### Watch-time (cilj: "do kog trenutka je ko gledao")

Posle webinara: `timelines.read` + `registrants.read`. Po registrantu se dobija koliko/dokle je
gledao (join/leave, attendance). Ideja: skripta/Make povuče attendance → tag u Kit
(npr. "gledao >30min", "Non-Attendee") za segmentaciju ponude. (Tačan timeline endpoint istražiti
sa tokenom: `GET /api/registrants/{uuid}` i `/api/timelines` su polazne tačke.)

## Webinar objekat (ključne vrednosti)

```
webinarID: 88179186855   uuid: UGOzC1jrzHGcJoS   webinarTimeline: FLnvhOvvnBywf8g
timeStamp: 2026-07-09 17:00:00+00:00 (= 19h CEST)   timeZone: Europe/Prague
mode: MEETING   timerLength: 5400 (90 min)   integrationID: OorySttiyoACOym
```

## Ako secret istekne / promeni se

Novi `secret` se dobija iz AEvent-a u **API/headless varijanti forme** (ona koja postuje na
`/api-registration` i ima `<input name="secret">`). Standardna forma (`/registration` + captcha)
NEMA secret. Zameni vrednost u `webflow/landing-jul-2026.html` → `AEVENT.SECRET`.
