## 2026-10-12 - v1.1.2-rc.1 (gepszintu bongeszo-telepites, nem felhasznaloi mappa)

- Javítva: 'Hiányzik egy Windows felhasználói mappa' hiba. Közös Public Desktop, Common Programs, Common Startup használatával, felhasználói mappáktól függetlenül.
- Edge támogatás: szűz Windows 11 / Edge-only gépen is 9222 CDP debugprofil, internet és extra függőség nélkül.
- Felhasználónként elkülönített CDP-profil: az indító az aktuális felhasználó LOCALAPPDATA mappáját keresi az első használatkor, nem a telepítő adminisztrátorának profilját.
- Emelt szintű telepítőből nem indul emelt jogosultságú böngésző. A közös Startup parancsikon normál Windows-logon után fut.
- Meglévő célmappa vagy EXE esetén interaktív folytatási kérdés, dátumos biztonsági mentés; nem tekintjük hibának a mappa létezését.
- Nem szükséges Python, Go, winget, külső számla/fiók vagy manuális Chromium-debugprofil készítés. UAC szükséges lehet, ha gépszintű parancsikonokhoz adminjog kell.
- A rendelésmásoló kódja és a vágólapformátum változatlan.
- Windows GitHub Actions: több böngésző, Edge-only, CommonStartup és Common Desktop, mentések, verzió és ZIP-fájl ellenőrzés. Élő felhasználói teszt még hátravan.

## 2026-10-12 - v1.1.1-rc.1 (egységes, kötelező patch-verziózás)

- Az EXE beágyazott verzióját a `VERSION` fájl adja; a fixen beégetett régi verzió megszűnt.
- Kötelező verzióléptetés: **csak a harmadik szám +1** (`1.3.1 → 1.3.2`); RC-jelölés külön, nem a PATCH helyett.
- A GitHub Release, teljes ZIP, forráskód és tesztek a `VERSION` értékét használják, egyezésük automatikusan ellenőrzött.
- A release pipeline nem engedi a már publikált release/tag felülírását és hibára fut, ha kimarad a patch-növelés.
- A másoló és a böngésző-telepítő működése ezzel a módosítással nem változik.
- v1.0.3 az utolsó felhasználó által stabilnak visszaigazolt változat, megőrizve; ez még RC.

## 2026-10-12 - Installer v1.0.3 (szabadon választható telepítési hely)

- A `telepites.bat` már nem használ beégetett telepítési célmappát. Rákérdez a teljes útvonalra, Enterre a korábbi `D:\3d lámpa\Photoshop és Illustrator scriptek` az alapértelmezés.
- Elfogadja az idézőjeles elérési utakat, kezeli a szóközt és ékezeteket, szükség esetén létrehozza az új célmappát.
- Meglévő cél-EXE esetén kötelező, dátumos mentést készít a felülírás előtt; sikertelen mentésnél nincs csere.
- Átmeneti fájlba másol és csak azt követően cseréli a cél-EXE-t, majd méretet ellenőriz. Ha a forrás és cél azonos fájl, kihagyja a másolást.
- Parancssori telepítés is lehetséges első célútvonal argumentummal, például `telepites.bat "E:\Scriptek"`.
- A program EXE-je és a rendelésválasztó kódja változatlanul maradt a v1.0.2-höz képest.
- Teszt: Windows Actions telepítőteszt, CRLF / UTF-8 és saját mappába telepítés (a Windows-teszt eredményét külön ellenőrizni kell).

# Változásnapló

## 2026-10-12 - 2026.10.12-choice-v1.0.2

- **Javítás:** több rendelés esetén visszaállított, számozott konzolos rendelésválasztó.
- **Fókusz:** egyetlen egyedi rendelés esetén nem nyílik konzol, nincs SetForegroundWindow / ShowWindow.
- **Konzol:** csak több egyedi rendelésnél, a rendelésadatok háttérben történő beolvasása után nyílik meg.
- **Billentyűk:** 1-9 Enter nélkül, Esc megszakít; sikeres választás után a konzol azonnal bezárul.
- **Hibakezelés:** ha a kiválasztott rendelés neve nem olvasható, másik rendelés választható.
- **Vágólap:** láthatatlan Windows-ablakhoz rendelt, Unicode vágólapkezelés.
- **Formátum:** országkód és szóköz a rendelésszám előtt; SOS és névformátum változatlan.
- **Állapot:** `go test` és Windows x64 keresztfordítás sikeres. Valós Windows/Illustrator teszt még hátravan.
- **Forrás:** a felhasználótól kapott hibás EXE működéséből rekonstruált Go implementáció. Nem tekinthető az eredeti program bitazonos helyreállításának.
- **Telepítés:** `D:\3d lámpa\Photoshop és Illustrator scriptek`; régi EXE mentése.

## 2026-10-12 - v1.1.0-rc.1 (bongeszobeallitas a telepitovel, elo tesztre var)

- A telepito automatikusan megkeresi a telepitett Brave es/vagy Google Chrome EXE-ket a Windows regisztracioban es a szabvanyos telepitesi mappakban.
- A Brave 9222, Chrome 9223 CDP portot kap; a Windows alapertelmezett bongeszojet preferalja, amennyiben a ketto kozul valamelyik.
- Kulon, tartos CDP-profilokat keszit. A korabban letrehozott `OpenCartBraveDebug\\User Data` es `OpenCartChromeDebug\\User Data` profilokat, ha vannak, ujrafelhasznalja.
- Az Asztalra es a Start menube bongeszoindito parancsikon kerul, a Windows-bejelentkezeskor automatikusan elindul az elsoleges CDP-bongeszo.
- A normál bongeszoprofilt, taskbar-pint, alapertelmezett bongeszobeallitasokat es a mar megnyitott bolti fiokadatokat nem modositja.
- A telepites csak akkor sikeres, ha a Brave/Chrome beallitas is sikerult, a debug kapcsolat elerheto, es a segedscriptek ellenorzese sikeres.
- Uj Windows integracios tesztek: ket bongeszo, portok, parancsikonok, felhasznaloi autostart, ujratelepitesi backupok, azonos celmappa, ervenytelen bongeszo es CRLF.
- A valos Brave/Chrome profil elso inditasa es a Windows-alapertelmezett ikonok kezelese felhasznaloi tesztelesre var. A v1.0.3 kiadas valtozatlan.