## 2026-10-14 – v1.1.9 (stabil kiadás, backup nélküli telepítés és záró szóköz)

- A telepítő nem készít többé EXE-, script-, konfiguráció- vagy parancsikon-backupot.
- Frissítéskor törli a saját korábbi, pontosan azonosított backupfájljait a célmappából, a közös Asztalról, Start menüből és Indítópultból. Az Indítópultban maradt `.lnk.backup_...` fájl okozta az „Alkalmazás kiválasztása” ablakot; más program fájljai megmaradnak.
- A vágólapra másolt szöveg utolsó kötőjele után pontosan egy szóköz kerül, minden webshopnál, normál/SOS és egy/több rendeléses másoláskor, a meglévő közös formázóban.
- Megmarad az EXE staging cseréje, a scriptmásolás ellenőrzése, a gépi parancsikonok, a normál felhasználói CDP-ellenőrzés, a fókuszkezelés és a biztonságos UAC-útvonalátadás.
- Regressziós tesztek: régi backupok takarítása, backup nélküli ismételt és azonos mappás telepítés, idegen fájlok és működő ikonok megőrzése, záró szóköz minden ország/SOS esetében.

## 2026-10-13 – v1.1.8 (stabil kiadás, UAC-útvonalkezelés)

- Az emelt telepítő teljes útvonala és célmappája adatként jut át a PowerShell és CMD között; az aposztróf, Unicode, százalékjel és további legális karakterek nem értelmeződnek parancsként.
- Közös elevate_installer.ps1 segéd, JSON/Base64 adatátadás és rögzített /elevated-child jelző; a normál felhasználói CDP-ellenőrzés megmarad.
- Az argumentummal indított telepítés is ellenőrzi az emelési szükségletet. A scriptsmásolás nem ad útvonalakat a CALL második értelmezési körének.
- Megmarad a v1.1.7 általános alkalmazásfókusz-javítása, a korábbi rendelésválasztó, többnyelvű névkinyerés és az automatikus CDP-indítás.
- Automatikus regressziós ellenőrzés a valódi BAT/helper/encoded-bootstrap/CMD adatútra; RunAs-kérés, /elevated-child, parent CDP-folytatás, hibakód és megszakítás is ellenőrzött.
- A javítás alapváltozatán négy valódi UAC-telepítés/újratelepítés sikeres volt normál és speciális útvonalakkal; a mért token Limitedből Fullra váltott. A gép házirendje kérdés nélküli emelést engedélyezett; interaktív UAC-Igen/Nem nem volt tesztelve.
- A v1.1.8 összeillesztett kiadása újra lefuttatja a legújabb Go-, JavaScript-, telepítő- és CDP-teszteket. A felhasználó kérésére stabil, RC nélkül.
- Az összes korábbi GitHub Release megmarad; külön v1.1.8 EXE és teljes ZIP készül.

## 2026-10-13 – v1.1.7-rc.1 (utolsó aktív alkalmazás fókuszának visszaállítása)

- Több rendelés választóablakának használata után az eredetileg előtérben lévő **bármely** alkalmazás kapja vissza a fókuszt; semmilyen programnévhez nem kötött.
- Korábbi fókusz visszaállítása közvetlenül a konzol lezárása előtt, majd szükség esetén a bezárás után is.
- Win32 `SetForegroundWindow` sikertelenségekor `AttachThreadInput` + `BringWindowToTop` tartalék; inputszálak azonnali szétkapcsolásával, érvénytelen HWND-k kizárásával.
- Az egy rendeléses láthatatlan működés változatlan. Böngészőindító, telepítő, rendeléskinyerés, választási billentyűk és vágólapformátum nem változik.
- Kiegészítő Go regressziós teszt az érvénytelen HWND-k biztonságos kezelésére. A Windows CI és Release tesztek után valós fókuszpróba szükséges.

## 2026-10-12 – v1.1.6-rc.1 (adminisztrátori telepítésből automatikus, normál felhasználói CDP)

- A második Windows-gépen a v1.1.5-rc.1 `VERIFY_ADMIN` ága a `-CheckOnly` paraméterrel ellenőrizte a 9222-es portot, de a Brave indítását kihagyta. Ez bizonyított telepítőhiba volt, nem függőség- vagy OpenCart-hiba.
- Most adminisztrátori indítás esetén is elindítja a Brave/Chrome/Edge böngészőt a bejelentkezett Explorer-felhasználó nevében, ideiglenes Task Scheduler **InteractiveToken + Limited** feladattal.
- A normál felhasználói CDP-végpontokat továbbra is élőben ellenőrzi; a gépi telepítés önmagában nem jelent sikert.
- Az átmeneti ütemezett feladat a futás végén törlésre kerül. Nem kell külső futtatókörnyezet, felhasználónév/jelszó megadása, és a normál böngészőprofilokat nem módosítja.
- Az előző stabil v1.1.4 és az összes korábbi RC Release megmarad. A másoló EXE-logika nem változik; kizárólag PATCH-verziószám emelkedik `1.1.5 → 1.1.6`.
- Windows integrációs teszt ellenőrzi, hogy az emelt jogosultságú telepítő nem `-CheckOnly` ellenőrzéssel áll meg.

## 2026-10-12 – v1.1.5-rc.1 (telepítő: tényleges CDP-ellenőrzés)

- Gyökérok: a másoló az új gépen települt, de egyik böngészőfolyamat sem rendelkezett debugporttal; a telepítő mégis sikert jelzett.
- A rendszergazdai telepítés után a normál felhasználó automatikusan elindítja a választott böngészőt, majd a 9222/9223 CDP-végpontokat élesben ellenőrzi.
- Hiba esetén STOP, látható hibaüzenet és napló a TEMP mappában; nincs több hamis sikerüzenet.
- Javítva: az admin telepítő és a normál felhasználói ellenőrzés határa, és a telepítési útvonal továbbadása UAC után.
- Automatikus Windows ellenőrzés egészül ki: hiányzó CDP esetén kötelező hiba; válaszoló mock CDP esetén siker.
- Az EXE másolási/névkinyerési logikája nem változott. A korábbi stabil v1.1.4 és az előzetes kiadások megmaradnak.

## 2026-10-12 - v1.1.4 (stabil kiadás, RC-jelölés nélkül)

- A felhasználó megerősítette, hogy a v1.1.3-rc.1 több webshopos rendelésválasztója, névfelismerése és másolója saját gépén megfelelően működik (köztük 3dlampa.ro #191).
- Új stabil GitHub Release; PATCH növelés 1.1.3 -> 1.1.4. Az EXE-be ágyazott VERSION, ZIP, Release tag és cím azonos.
- **A másoló-, névkinyerő-, telepítő- és böngészőindító logikán nem változtattunk.**
- A kiadási pipeline RC nélküli verziót automatikusan stabil `--latest` Release-ként publikál; az RC-tag-ek megmaradnak.
- Még hátralévő teszt: másik Windows-gépen a teljes telepítés és gépszintű indító ellenőrzése.
- Az összes korábbi stabil és RC Release letölthető, visszaállítható mentés marad.

## 2026-10-12 - v1.1.3-rc.1 (román vásárlói név helyreállítása)

- Hibajavítás: a korábbi JS kizárólag HU/EN ügyféladat-fejléceket kezelt; a `3dlampa.ro` rendelésnél `[név nem olvasható]` lett az eredmény.
- RO ügyféladat-fejlécek, `Nume/Prenume` mezők és célzott ügyfél-link DOM felismerés; SK/CZ fejlécek.
- A korábbi magyar/angol nevek és az SOS forma megőrzése, célzott regressziós Node.js teszttel.
- Másolóválasztó, Illustrator-fókusz, telepítő, WinCDP-beállítás változatlan.
- Frissített teszt- és Release pipeline: a Node.js a kiadásnál magát a gyártási `extractorJS` stringet hajtja végre.
- Patch +1 verzió: v1.1.2 -> v1.1.3, az összes korábbi Release és stabil v1.0.3 érintetlenül megmarad.

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
