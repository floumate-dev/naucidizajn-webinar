# SOP: posle webinara (Kit tagovi prisustva i post-webinar mejlovi)

Prvi put urađeno za webinar 13.10.2026. Ponavlja se za svaki sledeći webinar. Datum u primerima
(`13.10.2026.`) zameni datumom novog webinara.

## Pre webinara (dan ranije)

1. **Kit tagovi prisustva postoje** i svaki ima bar jednog pretplatnika (Danilov test nalog), inače
   ih Kit ne nudi u filteru publike:
   - `Webinar 13.10.2026. | No show`
   - `Webinar 13.10.2026. | <20%`
   - `Webinar 13.10.2026. | Do pitcha`
   - `Webinar 13.10.2026. | Pogledali pitch`
   - `Webinar 13.10.2026. | Kupili tokom webinara`
2. **Post-webinar mejlovi zakazani** sa publikama:
   - No-show mejl: `No show` (bez isključenja, i članovi dobijaju snimak).
   - „Bili, izašli pre ponude": **Matching any** `<20%` ili `Do pitcha` + none of `Skool član`.
     (`<20%` i `Do pitcha` se ne preklapaju — sa samo jednim tagom deo ljudi ne dobije mejl.)
   - „Pogledali pitch": `Pogledali pitch` + none of `Skool član`.
   - Svuda gde Nikola piše „excluding Skool members": none of `Skool član` (tag održava alat, vidi
     dashboard `docs/HOURLY-SYNC.md` 2f).
3. **Kit automatizacija „Kupili tokom webinara"** (Bought AI Club → tag `Kupili tokom webinara` →
   sekvenca sa mejlom liste) postoji, mejl u sekvenci je **Published**, automatizacija je ugašena.
4. **Replay stranica:** tajmer i tekst „Dostupan do …" na novi datum (snimak važi do sutradan u ponoć).

## Za vreme webinara

- **19:00** uključi Kit automatizaciju „Kupili tokom webinara"; ugasi je kad se webinar završi
  (13.10. u 20:30). Bivši članovi koji se vrate (već imaju `Bought AI Club`) je ne okidaju —
  njih posle ručno.
- **Zapiši vremena** (ili ih uzmi od Nikole): kad je pomenuo zajednicu, kad je počeo da nabraja šta
  se dobija, **kad je rekao cenu**. Granica za `Pogledali pitch` je **trenutak cene**
  (13.10: zajednica 19:49, nabrajanje 19:51, **cena 19:52**).

## Odmah posle webinara (pre slanja post-webinar mejlova)

Kit publiku računa u trenutku slanja — tagovi moraju biti upisani PRE slanja. 13.10 su upisani
posle 21:15, pa su mejlovi pomereni na 22:45. **Cilj: CSV odmah po završetku, upis pre 21:15.**

1. **AEvent → webinar → Registrants → Download** (CSV „registrant download"). Sačuvaj ga van
   git repoa (npr. `Downloads`) — ima mejlove i telefone.
2. **Proba** (ništa ne upisuje), iz foldera `naucidizajn-webinar`:
   ```
   node --env-file="../naucidizajn-dashboard/.env.local" scripts/aevent-attendance-tags.mjs --csv "C:/Users/.../Downloads/registrant-download.csv" --webinar "13.10.2026." --pitch 19:52
   ```
   Proveri da je u CSV-u samo ovaj webinar i da brojke imaju smisla (13.10: 2.252 prijavljena,
   691 došao → Pogledali pitch 525, Do pitcha 88, <20% 78, No show 1.561).
3. **Upis:** ista komanda + `--write`. Prvo idu prisutni (~7 min za ~700), pa No show
   (~20 min za ~1.500). Mejlovi za prisutne mogu čim su prisutni gotovi.
4. **Obriši CSV.**
5. **Kit:** publike post-webinar mejlova sada pokazuju prave brojeve (ne 1). Ako je neki mejl već
   otišao samo test nalogu → Duplicate → ista publika → pošalji.

### Pravila tagova (u skripti)

| Tag | Pravilo |
|---|---|
| `No show` | `Attended` nije `Yes` |
| `Pogledali pitch` | bio prisutan u trenutku cene (vreme izlaska = ulazak + ukupno vreme gledanja) |
| `<20%` | otišao pre cene, gledao < 20 min |
| `Do pitcha` | otišao pre cene, gledao 20+ min |

Vreme izlaska je procena: ko je izašao pa se vratio izgleda kao da je otišao ranije. AEvent tačnije ne daje.

## Sledećih dana

- **Mejl 8 i 10** (prijavljeni koji su otvorili bar jedan post-webinar mejl): pre slanja ručno
  staviti tag `Webinar 13.10.2026. - Otvorio` prijavljenima koji su otvorili mejlove 1-7 (pa 1-9).
- **Replay stranica:** zameni video (`data-yt`, `data-start`) kad Nikola okači snimak.
- **Kupili tokom webinara:** uporedi nove članove u Skool-u (vreme webinara) sa onima koji su
  ušli u automatizaciju; ko fali (bivši član koji se vratio), dodaj ručno.
- Claude sekvenca / druge automatizacije koje čekaju „posle webinara" — uključi.
