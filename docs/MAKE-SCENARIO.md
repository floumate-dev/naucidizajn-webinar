# Make scenario (webhook → Kit)

Make prima prijavu sa landing-a i upisuje u Kit. **Make je jedini pisac u Kit** (zato thank-you
`/api/signup` ne šalje tagId — bez duplog upisa). Webinar link NE ide iz Make-a (AEvent ga šalje).

## Webhook payload (šta landing šalje)

`POST https://hook.eu2.make.com/n0sdfhr9jf1drjk85bjfnmkb2fh0eeqg`
Content-Type: `application/json`, fire-and-forget (keepalive):

```json
{
  "name": "Petar Petrović",
  "first_name": "Petar",
  "last_name": "Petrović",
  "vokativ": "Petre",
  "email": "petar@primer.com",
  "phone": "+381641234567",
  "ref": "X7K2M9",
  "source": "instagram",
  "specificsource": "instagram_video_bandera",
  "utm_source": "120210...",
  "utm_medium": "120211...",
  "utm_campaign": "120212..."
}
```

> `vokativ` se već računa na landing-u (inline) — Make NEMA HTTP korak za vokativ.
> Tracking polja (`source`, `specificsource`, `utm_source`, `utm_medium`, `utm_campaign`) su
> prisutna samo ako su bila u landing URL-u. UTM dolaze sa Meta reklama
> (`utm_source={{campaign.id}}&utm_medium={{adset.id}}&utm_campaign={{ad.id}}`).
> Ista tracking polja idu i u AEvent (customtags).

## Koraci scenarija

1. **Webhook** (Custom webhook). Pošalji jednu test prijavu sa landing-a da Make "redetermine
   data structure" i mapira polja.
2. **Kit → Create/Update Subscriber:**
   - `email_address` = `{{email}}`
   - `first_name` = `{{first_name}}`
   - custom fields: `last_name`, `vokativ`, `phone`, `source`, `specificsource`, `ref`,
     `utm_source`, `utm_medium`, `utm_campaign`
3. **Kit → Add tag to subscriber:** July webinar tag (po `email`/subscriber id). Tag može da
   triggeruje Kit automation ako je koristiš (npr. welcome bez Zoom linka — link šalje AEvent).
4. (Opciono) error handling: ako Kit vrati non-2xx, loguj/alert.

## Kit setup (pre scenarija)

Napravi **custom fields** (Subscribers → Custom Fields): `vokativ`, `phone`, `source`,
`specificsource`, `ref`, `utm_source`, `utm_medium`, `utm_campaign` (i `last_name` ako ne postoji).
Napravi **tag** za July webinar.

## Podela uloga (bitno)

- **AEvent** = webinar (join) link + podsetnici (Dusan zakazuje sekvence u AEvent-u) + attendance.
- **Make → Kit** = email lista + custom fields + nurture. Bez webinar linka.
- **Thank-you → /api/signup** = referral (Supabase-only), bez Kit-a.

## Napomena: zašto JSON a ne form-urlencoded

Make custom webhook parsira oba. Koristimo JSON + keepalive (kao proven Tibor setup). Make
webhook odgovara na CORS preflight, pa cross-origin POST sa `Content-Type: application/json` radi.
