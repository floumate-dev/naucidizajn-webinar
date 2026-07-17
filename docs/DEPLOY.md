# Deploy — ⚠️ PROČITAJ PRE `vercel deploy`

Ovaj repo se deployuje u **DVA odvojena Vercel projekta**, a produkcijski alias API-ja **ne prati
automatski** produkciju. Zbog toga `vercel deploy --prod` može da prijavi uspeh a da uživo
ne promeni ništa. Otkriveno 2026-07-16/17 posle višesatne istrage.

## Dva projekta, dva cilja

| Šta | Vercel projekat | Domen | `.vercel/project.json` u repou |
|---|---|---|---|
| **Dashboard** (`dashboard/index.html`) | `giveaway-licni-brend-referral`<br>`prj_Gf5Ayk5o8I9TSvt4K5CuvPpKvdp3` | `app.naucidizajn.com` | ✅ pokazuje ovde |
| **API** (`api/signup.js`) | `nauci-dizajnu-referral`<br>`prj_dIyzzy6gl2r6ni2Sc6iSqBZlq7gm` | `nauci-dizajnu-referral.vercel.app` | ❌ NE |

Team: `team_Svm6zi0TYmPcaLAVhCKJdUqn` (`naucidizajns-projects`). Nijedan nije git-connected —
deploy je uvek CLI iz lokalnog foldera.

**Thank-you stranica gađa API:** `webflow/thankyou-jul-2026.html` → `CONFIG.apiUrl` →
`https://nauci-dizajnu-referral.vercel.app/api/signup`. Dashboard i API su odvojeni servisi.

## ⚠️ Zamka 1: `.vercel` pokazuje samo na dashboard

Običan `vercel deploy --prod` iz repoa ažurira **samo dashboard**. Izmena u `api/signup.js`
ne stiže nigde — bez ijedne greške.

Za API se mora privremeno zameniti link:

```bash
cp .vercel/project.json /tmp/vercel-backup.json
echo '{"projectId":"prj_dIyzzy6gl2r6ni2Sc6iSqBZlq7gm","orgId":"team_Svm6zi0TYmPcaLAVhCKJdUqn","projectName":"nauci-dizajnu-referral"}' > .vercel/project.json
npx vercel@latest deploy --prod --yes --token=<TOKEN>
cp /tmp/vercel-backup.json .vercel/project.json    # VRATI, uvek
```

## ⚠️ Zamka 2: alias API-ja NE prati produkciju

`nauci-dizajnu-referral.vercel.app` je regularan projektni domen (`gitBranch: null`,
`redirect: null`, verified) — trebalo bi da prati produkciju, **ali ne prati.** Zaglavljen je
na deploymentu `aw6hk3lhn` (**19.06. u 15:02**).

Posledice, sve tihe:
- Deploy od 19.06. u **15:46** nikad nije otišao uživo.
- Deploy od 17.07. (`jp8edwrx4`, CORS staging) — takođe ne. Stoji neaktiviran.
- Vercel u UI-ju piše „Production · READY". **Laže.**

**Posle svakog `--prod` deploya API-ja alias se mora pomeriti RUČNO:**
```bash
npx vercel@latest alias set <novi-deployment-url> nauci-dizajnu-referral.vercel.app --token=<TOKEN>
```
Provera gde alias stvarno pokazuje:
```bash
curl -s -H "Authorization: Bearer <TOKEN>" \
  "https://api.vercel.com/v4/aliases?teamId=team_Svm6zi0TYmPcaLAVhCKJdUqn&limit=20"
```

## ⚠️ Zamka 3: reward env varijable su na POGREŠNOM projektu

```
nauci-dizajnu-referral (ŽIVI API):  CONVERTKIT_WINNER_TAG_ID, CONVERTKIT_API_SECRET,
                                    WEBINAR_LANDING_URL, DASHBOARD_BASE_URL, SUPABASE_*
                                    → NEMA REWARD_WEBHOOK_URL / REWARD_THRESHOLD

giveaway-licni-brend-referral (dashboard):  REWARD_THRESHOLD, REWARD_WEBHOOK_URL, ...
                                            → tu nikom ne trebaju (dashboard ne zove API)
```

**Zato nagrada za 10 referrala nikad nije opalila — četiri nezavisna razloga:**
1. `maybeFireRewardWebhook` deployovan u **dashboard** projekat, ne u API.
2. `REWARD_WEBHOOK_URL` setovan na **dashboard** projekat, ne na API.
3. I da je oboje bilo tačno — **alias ne bi pomerio kod uživo** (Zamka 2).
4. Stara verzija (`maybeTagWinner`, koja JESTE živa) sedi unutar `if (kitEnabled)`, a
   webinar ne šalje `tagId` → `kitEnabled = false` → mrtav kod. Zato ni `CONVERTKIT_WINNER_TAG_ID`
   (koji jeste setovan na API-ju) ne radi ništa.

Nagrada je odbačena kao koncept (2026-07-16) — traži unakrsno poređenje sa AEvents attendance,
plus je gameable (Trajče Kostov: 10 lažnih prijava sa svog IP-ja za 18 min, tačno na prag).
Evidencija ostaje u Supabase koloni `referrals_brought` (puni je AFTER INSERT trigger, radi nezavisno).

## Šta je uživo (stanje 2026-07-17)

- **API** = deployment `aw6hk3lhn`, build od **19.06.** Ima stari `maybeTagWinner` (mrtav kod).
  **Nema** CORS za Webflow staging → thank-you na `nauci-dizajn.webflow.io` ne može da zove API
  → prikaže „Link stiže na tvoj email" i `svojoj platformi` vodi u prazno. **Na produkciji radi.**
- **Dashboard** = deployment od 2026-07-16, aktuelan.
- Repo `api/signup.js` je **ispred** živog API-ja za ~114 linija (reward mehanizam + CORS staging).
  Prevezivanje aliasa je provereno bezbedno (reward ostaje uspavan bez `REWARD_WEBHOOK_URL`),
  ali nije urađeno — nije bilo potrebe pred launch.

## TODO posle webinara: spojiti u jedan projekat

Dashboard i API u istom projektu → jedan deploy cilj, jedan alias, nema ove tri zamke.
Traži izmenu `CONFIG.apiUrl` u `webflow/thankyou-jul-2026.html` i re-paste u Webflow.
