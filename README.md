# Konverzo Mail

Emailový klient pre **macOS** a **Android** (Flutter). Správy od jedného človeka sa zobrazujú ako jedna konverzácia, v čistom štýle podobnom Apple Mail. Podporuje Gmail, Outlook a vlastný IMAP/SMTP server. Optimalizovaný pre **Samsung Galaxy Z Fold7**.

> Kód som nemohol skompilovať ani otestovať na reálnom účte, takže pri prvom zostavení môžu vyskočiť drobné chyby. Workflow na GitHube spúšťa aj `flutter analyze` a `flutter test` a ich výpis ti pomôže chyby rýchlo nájsť.

## Čo funguje
- Viac účtov: Gmail, Outlook, vlastný IMAP/SMTP; prihlásenie heslom aj cez **OAuth2** (Google, Microsoft, pozri `OAUTH_SETUP.md`)
- Zoskupenie správ do konverzácií podľa protistrany (prijaté aj odoslané), vyhľadávanie, filter na účet a neprečítané
- **Lokálna databáza (SQLite)**: okamžitý štart, offline čítanie, inkrementálna synchronizácia (len nové správy)
- Označenie ako prečítané po otvorení konverzácie (aj na serveri)
- Vlákno ako bubliny, odpoveď priamo vo vlákne, **nová správa** s našepkávaním kontaktov, zobrazenie mien príloh
- Heslá a tokeny v Keychain / Android Keystore, HTML emaily bez načítania vzdialených obrázkov
- Svetlý aj tmavý režim

## Galaxy Z Fold7 a veľká plocha
Rozloženie sa riadi skutočnou veľkosťou okna a ohybom displeja, takže funguje aj v rozdelenej obrazovke a v DeX:

| Situácia | Rozloženie |
|---|---|
| Vonkajší displej / zložený (< 600 dp) | jeden panel, zoznam → vlákno |
| Rozdelená obrazovka (600–840 dp) | zoznam + vlákno, filtre ako čipy |
| **Vnútorný displej (≥ 840 dp)** | úzka bočná lišta (účty, neprečítané) + zoznam + vlákno |
| Širšie ako 1200 dp (DeX, monitor) | rozšírený bočný panel s popiskami |
| **Flex režim** (polozložený, vodorovný ohyb) | hore vlákno, dole písanie, rýchle odpovede a prepínač konverzácií |
| Polozložený so zvislým ohybom („kniha“) | zoznam vľavo, vlákno vpravo od ohybu |

Ďalej: šírku zoznamu možno ťahom meniť (uloží sa), rozpísaná odpoveď (koncept) prežije preskladanie telefónu,
aplikácia sa pri skladaní nereštartuje a vybraná konverzácia ostane otvorená.

**Klávesové skratky** (fyzická klávesnica, DeX): `Alt + ↑/↓` prepínanie konverzácií, `Ctrl+F` hľadať,
`Ctrl+N` nová správa, `Ctrl+R` obnoviť, `Esc` zrušiť výber.

## Čo zatiaľ nie je
- sťahovanie a posielanie príloh (zobrazujú sa len názvy)
- push notifikácie (synchronizácia prebehne pri otvorení a pri ťahu nadol)
- mazanie, archivácia, priečinky mimo doručenej a odoslanej pošty
- Google v režime Testing: obnovovací token vyprší po 7 dňoch (pozri `OAUTH_SETUP.md`)

## Ako získať `.dmg` a `.apk` (bez vlastného Macu)
1. Vytvor si bezplatný účet na github.com a nový repozitár (napr. `konverzo-mail`).
2. Nahraj doň celý obsah tohto priečinka (vrátane skrytého priečinka `.github`).
3. Na GitHube otvor záložku **Actions** → **Build apps** → **Run workflow**.
4. Po niekoľkých minútach otvor dokončený beh a dole v **Artifacts** stiahni
   `KonverzoMail-dmg` a `KonverzoMail-apk`.

Alebo vytvor tag `v0.2.0` a súbory sa objavia v sekcii **Releases**.

## Inštalácia
- **Android:** skopíruj `.apk` do telefónu, povoľ inštaláciu z neznámych zdrojov a otvor ho.
- **macOS:** otvor `.dmg` a presuň aplikáciu do Aplikácií. Je nepodpísaná, takže prvýkrát na ňu klikni pravým tlačidlom → **Otvoriť** (prípadne Systémové nastavenia → Súkromie a bezpečnosť → **Aj tak otvoriť**).

## Lokálne zostavenie
```bash
bash scripts/build_dmg.sh   # na Macu (Flutter + Xcode)
bash scripts/build_apk.sh   # Flutter + Android SDK
```

## Prihlásenie
- **Gmail (bez nastavovania):** zapni dvojstupňové overenie a vytvor „heslo aplikácie“ na myaccount.google.com/apppasswords.
- **Gmail / Outlook cez OAuth2:** postup v `OAUTH_SETUP.md`. Outlook.com ho väčšinou vyžaduje.
- **Vlastný IMAP:** zadaj IMAP a SMTP server, porty (IMAP 993, SMTP 465 alebo 587) a heslo.
