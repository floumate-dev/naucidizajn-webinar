# Webinar „AI dizajnira, ti zarađuješ" — utorak 13.10.2026, 19h

Četvrti re-run (posle 09.07, 30.07, 06.09). Recept je isti kao za 06.09; menjaju se datum, WhatsApp grupa i
oznake. Prijave (reklame) kreću ~03.10. Podsetnici i mejlovi posle webinara NISU u ovom planu — za sada samo
potvrdni mejl.

Legenda: `[x]` gotovo · `[ ]` čeka · ⏳ čeka nekog (ko) · (D) radi Danilo · (C) radim ja u kodu

## 0. Od Nikole / Dušana
- [x] WhatsApp grupa za 13.10 (link u Slack-u, 01.10)
- [x] Landing A isti, menja se samo datum i vreme (13.10, 19h)
- [x] Tekst potvrdnog mejla (Notion „Tvoja prijava je uspešna")
- [ ] ⏳ Zoom licenca aktivna za 13.10 (Dušan: treba zbog AEvent-a; za 06.09 je bio Large Meeting 1000)
- [ ] ⏳ Ponuda na webinaru ista kao 06.09 (cena, bonus, rok)? Isti VSL na thank-you stranici?

## 1. AEvent (D)
- [ ] Nov event 13.10.2026 19:00 (Europe/Belgrade) na POSTOJEĆOJ kampanji → `wtl` i `secret` ostaju, kod se ne dira
- [ ] Zoom soba vezana za event
- [ ] (C) Proba poziva: registracija vraća `joinURL` i „Utorak 7:00 PM"

## 2. Landing — Webflow (C pravi, D lepi + Publish)
Živi landing = `webflow/landing-06sep-EMBED-1.html` (dizajn) + `landing-06sep-EMBED-2.html` (logika), REDOSLED OBAVEZAN.
- [ ] (C) EMBED-1: „u nedelju, 6. septembra" → „u utorak, 13. oktobra" (hero)
- [ ] (C) EMBED-2: `WEBINAR_ID = "13.10"`, datum u modalu, countdown `2026-10-13T19:00:00+02:00`
- [ ] (C) Novi fajlovi `landing-13okt-EMBED-1/2.html`, stari ostaju kao rezerva
- [ ] (D) Paste oba embeda (EMBED-1 pa EMBED-2) + Publish; slug ostaje `/ai-dizajnira-ti-zaradjujes-webinar`
- [ ] (C) Provera uživo: datum, countdown, forma otvara modal

## 3. Thank-you — Webflow (C pravi, D lepi + Publish)
- [ ] (C) `thankyou-jul-2026.html`: datum „u utorak, 13. oktobra", nov WhatsApp link, VSL (isti ili nov ⏳)
- [ ] (D) Paste + Publish
- [ ] (C) Provera uživo: WhatsApp dugme vodi u novu grupu, referral link se pravi

## 4. Make (D, ja pomažem)
- [ ] Filter / grana `06.09` → `13.10` (po `webinar` polju iz landinga)
- [ ] Kit tag `Webinar 13.10.2026.` (stil kao ranije, sa tačkom na kraju)
- [ ] GHL tag `webinar_13_10_26_optin`
- [ ] Nov Google Sheet (ili nov tab) za 13.10
- [ ] Meta CAPI modul ostaje kakav je (`Lead`, bez filtera) — samo proveriti da je u ruti

## 5. Kit — potvrdni mejl (D)
- [ ] Automation: tag `Webinar 13.10.2026.` → potvrdni mejl (tekst iz Notion-a)
- [ ] U mejlu `{{ subscriber.zoom_join_link }}` i nov WhatsApp link; delay 5–10 min ako link stigne prazan (AEvent ga upisuje malo posle taga)
- [ ] Claude YT opt-in automation OSTAJE UGAŠENA do posle webinara

## 6. Supabase referral (C daje SQL, D pušta)
- [ ] Arhiva `signups` → `signups_arhiva_sep2026`, ODMAH `enable row level security`, pa `delete from signups`
- [ ] Provera: anon čitanje vraća `[]`, živa tabela prazna

## 7. Meta reklame (D / media buyer)
- [ ] Reklame vode na isti slug (bez 301 — on briše fbclid/utm)
- [ ] Ad set optimizuje `Lead` (CAPI)
- [ ] Media buyer zna datum 13.10 i start 03.10

## 8. Proba od kraja do kraja (C + D, pre 03.10)
- [ ] Prijava test mejlom sa `?source=test`: AEvent registrant + joinURL, Make run prošao, Kit tag + potvrdni mejl stigao (sa Zoom linkom), GHL tag, red u Sheet-u, `Lead` u Meta Test Events, redirect na thank-you, referral dashboard radi
- [ ] Brisanje test podataka (AEvent registrant, Supabase red, GHL/Kit/Sheet)

## 9. Start ~03.10
- [ ] Reklame uključene; prvih sat vremena pratiti Make run-ove, Sheet i AEvent

## 10. Dan webinara 13.10
- [ ] Zoom i AEvent provera pre 19h

## 11. Posle webinara (bez mejlova)
- [ ] Replay stranica: countdown 13.10 + 3 dana, nov video (YouTube ID + `data-start`) ⏳ Nikola
- [ ] Ponuda (pitch): rok i datumi
- [ ] Attendance tagovi u Kit
- [ ] Uključiti Claude YT opt-in Kit automation (samo za nove prijave posle webinara)
- [ ] Retencija: novi talas članova sama prepoznaje kao novi period churn-a (ništa ne treba)
- [ ] Prolaz kroz celu Retenciju sa Danilom + optimizacija Pretplata (Marketing)
