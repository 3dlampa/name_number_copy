# Név és rendelésszám vágólapra másoló

**Aktuális kiadás (EXE és telepítő):** `v1.1.10`
**Verzióforrás:** `VERSION` (az EXE-be beágyazva, a Release tag/ZIP ezt ellenőrzi)  
**Platform:** Windows 11 x64  
**Programfájl:** `name - number copy.exe`

## v1.1.10: átlátható telepítés, natív böngészőindító, eltávolítás

- A telepítő minden módosítást előre jelez; interaktív jóváhagyás előtt nem ír a célmappába vagy a közös indítómappákba. A böngésző automatikus indítása külön választható, alapból kikapcsolva.
- A közös Asztal/Start menü/Startup ikonok közvetlenül az EXE `--start-browser` módját használják. Böngészőindításkor nincs PowerShell-folyamat, kódolt parancs vagy végrehajtási házirend-kapcsoló. A korábbi PS1 belépési pont kompatibilitási wrapper marad.
- Az UAC-emelés látható `-File` scriptet használ. A Base64 paraméter csak JSON-adatot tartalmaz; útvonal nem válik PowerShell-kóddá. A telepítő és eltávolító a folyamatára korlátozott PowerShell `Bypass` kapcsolót használ, nem állít át tartós házirendet és nem módosítja a vírusvédelmet.
- Ha eleve rendszergazdaként indítod, a böngésző továbbra is a bejelentkezett felhasználó normál jogával indul. Az ezt biztosító ideiglenes Windows-feladat látható, és végül törlődik; normál telepítésnél nincs rá szükség.
- Megmarad a Brave/Chrome/Edge felismerés, a 9222/9223 CDP-port, a külön felhasználói profil és a korábbi OpenCart-profil újrahasználata. A natív indító csak a loopback végpontokat használja, proxy és átirányítás nélkül, és mindkét CDP-végpontot ellenőrzi.
- Eltávolítás: `eltavolitas.bat` a telepítési mappában, vagy a Start menü `OpenCart Rendelesmasolo` eltávolítója. Csak a telepített saját fájlokat és ténylegesen ide mutató parancsikonokat törli. Más fájlokat, böngészőket és profilokat megőriz. Zárd be az OpenCart-böngészőt, majd a normál böngészőikonnal térj vissza; a külön profilt saját adataid miatt megtartjuk.
- Adatkezelés/használat: [HASZNALATI_FELTETELEK.txt](HASZNALATI_FELTETELEK.txt). Nincs telemetria, külső adatküldés, programletöltés vagy automatikus frissítés.
- A harmadik gépen látott normál jogosultságú indítás külön szakaszjelzéseket kap. A natív CDP-várakozás teljes határideje 20 másodperc; közvetlen admin-telepítésnél 30 másodperces ellenőrzés, feladatállapot/eredménykód és naplóútvonal jelzi a hibát. Az indítóikon már EXE-t futtat, így ezen az útvonalon nem nyílik üres PowerShell/Terminal ablak. A másik gép konkrét hibaoka a naplója nélkül még nem igazolt.
- A másolás, névkiolvasás, SOS, országprefix, választó, fókuszvisszaadás és a záró kötőjel utáni szóköz változatlan.

A módosítások a [Google szoftverirányelveinek](https://www.google.com/about/unwanted-software-policy.html) átláthatósági/eltávolíthatósági elveit követik. Az EXE hiteles kiadói aláírás nélkül készült; a Drive korábbi minősítésének pontos oka nem ismert, az új csomag elfogadását nem lehet garantálni. [Ellenőrzési jegyzőkönyv](docs/verification-v1.1.10.md).

## Működés

- A program Windows GUI alrendszerrel indul. **Egyetlen egyedi rendelés esetén nem nyit konzolt, nem helyez előtérbe semmilyen ablakot**, hanem közvetlenül a vágólapra másol.
- Két vagy több különböző megnyitott OpenCart rendelésnél **csak a választás idejére** hoz létre konzolt (`AllocConsole`).
- A választó számozott rendeléseket, webshopot, országkódot, rendelésszámot, nevet és SOS-jelölést ír ki.
- Az `1`...`9` számok Enter nélkül választanak, majd a program kimásolja az adatot és bezárja a konzolt.
- Tíznél több rendelésnél a 10. és fölötti elemekhez `0`, majd a teljes sorszám, végül Enter szükséges (például `010` + Enter a 10.-hez).
- `Esc` megszakít és bezár, a vágólapot nem változtatja meg.
- Konzol megnyitása előtt kiolvassa a rendeléseket: nem jelenít meg üres ablakot az adatgyűjtés alatt.
- Választás után megpróbálja visszaadni a korábban aktív ablak fókuszát.
- Ugyanazon webshop és rendelésszám duplán megnyitva csak egy rendelésnek számít.
- Brave / Chromium debug port: 9222, második debug böngésző: 9223.
- Csak `sale/order/info` és `sale/order/edit` OpenCart admin részletező oldalak olvashatók; rendeléslista nem.
- A megnyitott rendeléslapot nem aktiválja, az adatokat CDP `Runtime.evaluate` segítségével olvassa.

## Vágólap formátuma

- `HU 132688 - Matyikó Tamás - `
- `HU 132688 - SOS - Matyikó Tamás - `
- `RO 132688 - Matyikó Tamás - `
- `SK 84 - Matyikó Tamás - `
- `CZ 555 - Matyikó Tamás - `

Az utolsó kötőjel után pontosan egy szóköz kerül a vágólapra, normál és SOS esetben is. Ez az egy rendeléses és a több rendeléses választóból történő másolásra egyaránt vonatkozik.

Az országkód a webshop domainjéből jön, nem a böngésző nyelvéből.

## Telepítés

Telepítéskor a `telepites.bat` **bekéri a telepítési mappát**. Az Enter lenyomására az alapértelmezett mappát használja:

`D:\3d lámpa\Photoshop és Illustrator scriptek`

Más mappa esetén egyszerűen gépeld be a teljes útvonalat, például `E:\Munka\Scriptek` (akár idézőjelek között is). Ha a célmappa még nem létezik, a telepítő megpróbálja létrehozni. Nem telepít automatikusan a `C:\Scripts` alá.

1. Zárd be a régi másoló EXE-t, ha még fut.
2. Csomagold ki a ZIP-et, és indítsd a `telepites.bat`-ot. A program EXE-fájlja a BAT mellett legyen.
3. Válassz telepítési helyet, olvasd el a változtatásokat és a [használati tájékoztatót](HASZNALATI_FELTETELEK.txt), majd hagyd jóvá a telepítést. Az automatikus böngészőindítás külön I/N választás; Enter esetén kikapcsolva marad. Frissítéskor az N választás a régi saját automatikus indítót is eltávolítja. A telepítő az EXE-t és a scripteket backup nélkül frissíti, a böngészőbeállításokat és a parancsikonokat szintén backup nélkül írja. A korábbi telepítő saját, ismert nevű `.backup_...` fájljait törli a célmappából, a közös Asztalról, a Start menüből és az Indítópultból.
4. Teszteld egy és két különböző nyitott rendelés mellett, lehetőleg aktív Illustrator ablakkal.

Automatizált telepítéshez a célmappa első argumentumként is átadható: `telepites.bat "E:\Munka\Scriptek"`. Ez a mód nem kér billentyűbevitelt, és automatikus indítás nélkül telepít. Az automatikus indítás csak kifejezett `/autostart:on` második argumentummal engedélyezett: `telepites.bat "E:\Munka\Scriptek" /autostart:on`.

**Fontos:** Ez a feltöltött hibás Go-alapú EXE működését reprodukáló/javító forrás, nem az eredeti elveszett forrásfájl visszafejtett, byte-pontos másolata. Mivel a Windows és az Illustrator nem érhető el a tesztkörnyezetben, a fókusz és a konzol valós viselkedését a felhasználó gépén is tesztelni kell. Hibák logja: `%TEMP%\name_number_copy_error.log`.

## Fordítás / ellenőrzés

```sh
go test -count=1 ./...
GOOS=windows GOARCH=amd64 go build -trimpath -ldflags='-H windowsgui -s -w' -o 'name - number copy.exe' .
```

Az `-H windowsgui` szükséges, hogy egy rendelésnél ne nyíljon konzol. Az `AllocConsole` csak két vagy több egyedi rendelésnél fut.

## Biztonság / megőrzés

- Telepítéskor nem készül EXE-, script-, konfiguráció- vagy parancsikon-backup. A korábbi telepítőbackupok automatikusan törlődnek; más programok mentéseihez nem nyúl.
- Adatbázist, webshop-állományokat és rendeléseket nem módosít.
- A vágólapot csak sikeresen kiolvasott, kiválasztott rendelésnél írja.
- CDP WebSocket csak localhost `9222`/`9223` porton engedélyezett.
- Hibáknál nem ír ki felugró ablakot, helyette naplófájlba ír.

## Korábbi böngészőbeállítás (v1.1.0-rc.1; történeti leírás)

Az uj telepito felismeri a telepitett Brave es Google Chrome bongeszot. A Brave CDP-portja 9222; Chrome 9223. A felhasznalo Windows-alapertelmezett Brave/Chrome/Edge bongeszojet automatikusan preferalja (ha nincs, Brave, majd Chrome). Mindket telepitett bongeszohoz kulon inditoikon jon letre az Asztalon es a Start menuben. A preferalt bongeszo minden felhasznaloi Windows-bejelentkezeskor automatikusan elindul, ezert nem kell kezzel debug parancssori kapcsolokat irni.

A Chrome 136-tol `--remote-debugging-port` csak kulon `--user-data-dir` adatkotarral megbizhato. A telepito a korabbi OpenCartDebug profilokat, ha megtalalja, megtartja es ujrafelhasznalja. A regi normal Brave/Chrome profilok, a Windows alapertelmezett bongeszo es az eredeti taskbar ikonok valtozatlanok. Az uj ikon neve **OpenCart - Brave** vagy **OpenCart - Chrome**; rendelest ebben a kulon bongeszoprofilban kell megnyitni, es elso alkalommal a webshopba bejelentkezni. A normal bongeszoikonra kattintva tovabbra is elindulhat a normal (CDP nelkuli) profil, ennek automatikus atirasa nem biztonsagos.

A debug-port kizarolag 127.0.0.1-hez kotodik, de a gepen futo mas helyi folyamatok technikailag hozzaferhetnek a CDP-hez, ezert a kulon bongeszo-profilban csak a szukseges munkat vegezd. Sikertelen bongeszo-felderites vagy portellenorzes eseten a telepites NEM jelez sikert. A v1.1.9 telepito nem keszit backupokat, es eltavolitja a korabbi sajat telepitobackupokat.

**Biztonsagi statusz:** a korabbi ellenorzott v1.0.3 Release valtozatlanul elerheto; a v1.1.0-rc.1 elozetes, Windows/Illustrator gyakorlati tesztre var.

## Kiadások verziózási szabálya

**Mindig csak a harmadik (PATCH) számot növeljük eggyel:** `1.3.1 → 1.3.2`, `1.1.0 → 1.1.1`. A major/minor számot automatikusan nem módosítjuk. Tesztkiadás esetén az `-rc.1` utótag az állapotot jelenti; nem helyettesíti a harmadik szám emelését.

Az EXE, a `VERSION` fájl, a kiadási Git-tag, a Release címe, a ZIP neve és a Notion változásnaplója ugyanazt a verziót kell hogy tartalmazza. A GitHub Actions publikálás előtt ellenőrzi a korábbi kiadásokhoz képest az egylépéses patch növelést, a beágyazott Go-verziót, a telepítőt, a ZIP-t és a standalone EXE-t. A korábbi stabil Release változatlan, az RC külön kiadás.


## v1.1.2-rc.1 - minden Windows-felhasználó, szűz Windows 11

- **Gépszintű telepítő**, rendszergazdai jogosultság szükséges (Windows UAC egyszer kérhet jóváhagyást), utána **senkinek nem kell külön telepítenie**.
- A közös Windows Asztal, Start menü és **minden felhasználó Startup** mappájába helyezi az OpenCart-indító parancsikonokat. Nem függ attól, melyik adminisztrátori fiókból fut a telepítő.
- Brave, Chrome és **Microsoft Edge** felismerés. Szűz Windows 11-en a rendszerbe épített Edge önmagában elég: nincs szükség Pythonra, Go-ra, wingetre, külső letöltésre vagy új felhasználói fiókra.
- Brave és Edge: CDP 9222; Chrome: CDP 9223. A már működő másoló-EXE működéséhez nem nyúltunk.
- Az OpenCart böngészőprofil minden Windows-felhasználónál a **saját** `%LOCALAPPDATA%\NameNumberCopy\BrowserProfiles\...` helyén jön létre **csak az első használatkor**. Korábbi OpenCart-specifikus CDP-profilokat újrahasznál; a normál böngészőprofilokat nem módosítja.
- A rendszer-bejelentkezéskor a közös Startup indítja a kiválasztott böngészőt az adott felhasználó **normál jogosultságával**; a telepítő rendszergazdaként nem indít emelt jogú böngészőt.
- Ha a célmappa vagy az EXE már létezik, interaktív telepítésnél **rákérdez a folytatásra**. A meglévő mappa önmagában nem hiba. A v1.1.9-től a jóváhagyott frissítés backup nélkül történik.
- Az OpenCart webshop-adminba történő bejelentkezést nem kerüli meg: új, elkülönített profilban szükség lehet az eredeti webshop-fiókkal történő bejelentkezésre; nincs extra, külön telepítőfiók.
- **Korlát:** ha egy speciálisan módosított Windowsról az összes Chromium-alapú böngészőt eltávolították, internet nélküli telepítő nem tud új böngészőt előállítani. Ilyenkor pontos, érthető hiba jelenik meg, nem hamis sikerüzenet.
- **Visszaállítás:** az ellenőrzött v1.0.3 stabil Release, a v1.1.0-rc.1 és v1.1.1-rc.1 próbaverziók érintetlenül megmaradnak.


## v1.1.3-rc.1 - román ügyfélnév felismerése

- A korábbi névkinyerő csak a magyar `Vásárló adatok` / `Vevő adatok` és angol `Customer details` / `Customer info` fejlécet ismerte. Emiatt a román `3dlampa.ro` oldalakon `[név nem olvasható]` jelenhetett meg.
- Most felismeri többek közt a `Datele clientului`, `Detalii client`, `Informații despre client`, továbbá a szlovák/cseh ügyféladat-fejléceket is.
- Először az ügyfélblokk DOM-jában keresi a megfelelő ügyfél-linket; különben kizárólag a fejléc utáni neveket és `Nume/Prenume` mezőket vizsgálja, majd használja a régi szöveges tartalékot.
- A név- és rendelésszám-választó, fókuszkezelés, SOS, HU/RO/SK/CZ prefix, böngészőbeállítás és telepítő változatlan.
- Automatikus JavaScript névkinyerési tesztek a tényleges Go-EXE-be beágyazott kódról (román, magyar, szlovák, cseh, angol, SOS).
- Éles `RO 191` rendeléshez nem férünk hozzá, így a valós böngészős tesztet a felhasználónak kell megerősítenie; addig előzetes RC.


## v1.1.4 - stabil kiadás (2026-10-12)

- A `v1.1.3-rc.1` névkinyerő, választó és böngészőtelepítő **működése változatlan**; csak a kiadási verzió és a stabil státusz frissült.
- A felhasználó saját gépén egyidejűleg nyitott HU, RO, SK, CZ rendeléseknél ellenőrizte a vevőnevek kiolvasását és a számozott választót; a román névhibát megszűntnek jelezte.
- A következő PATCH-verzió `v1.1.4`, külön GitHub Release, EXE és teljes telepítő ZIP, a kiadási fájlba is beágyazott azonos verzióval.
- A kiadási pipeline a `VERSION` fájl `-rc.` utótagjából automatikusan dönt: RC esetén prerelease, utótag nélkül stabil / latest. Korábbi Release-eket **nem ír felül**.
- A **másik Windows-gépes telepítési teszt még hátravan**; ez nem módosítja a felhasználó saját gépén már igazolt névfelismerést.


## v1.1.5-rc.1 – telepítés csak bizonyított CDP-kapcsolattal

- A telepítő **nem jelezhet sikert** csak azért, mert az EXE, a beállító JSON és az OpenCart parancsikonok létrejöttek.
- A közös, minden felhasználónak szóló fájlokat továbbra is emelt jogosultsággal telepíti, de a **böngészőt a telepítőt indító normál Windows-felhasználó kontextusában** indítja, külön OpenCart-profillal.
- Az UAC-gyerek telepítő lezárulta után elindítja a tényleges Brave/Chrome/Edge böngészőt, ellenőrzi a `/json/version` és `/json/list` végpontot a kiválasztott 9222/9223 porton, **csak ekkor sikeres**.
- Hiba esetén nem sikeresnek jelzi, hanem olvasható hibaüzenet és `%TEMP%\name_number_copy_browser.log` napló keletkezik.
- A böngésző kiválasztása elsősorban a telepítő `Primary` beállítását követi, de felismeri az aktuális felhasználó saját böngészőtelepítését is.
- Az OpenCart normál és a dedikált debug-böngésző profilok nem kerülnek felülírásra. Ha már nyitott webböngésző fut, a CDP-s böngésző külön profilban indul.
- Közvetlen rendszergazdai indításnál a telepítő biztonságból **nem indít megemelt jogú böngészőt**; ha nincs már ellenőrzött CDP, érthetően kéri a normál dupla kattintásos telepítőindítást.
- A telepítőt továbbra is `telepites.bat` néven adjuk át. **Normál dupla kattintással** indítsd; maga intézi az UAC engedélyt.
- A másoló EXE rendelésfelismerési, névkinyerési és fókuszkezelési logikája **változatlan**, a beágyazott PATCH-verziószám kivételével.
- Ez előzetes RC kiadás, amíg a második, korábban hibás gépen nincs visszaellenőrizve.


## v1.1.6-rc.1 – rendszergazdaként indított telepítő javítása

- A v1.1.5-rc.1 hibája: ha a telepítő **már adminisztrátori jogosultsággal** indult, a `-CheckOnly` ágon csak megvizsgálta a 9222-es portot, de nem indította el a böngészőt. A felhasználói napló ennek következtében `CDP 9222 nem elérhető` hibát mutatott.
- Most ilyen esetben is **önállóan indítja a böngészőt az asztalra bejelentkezett Windows-felhasználó normál jogosultságával**. Ehhez ideiglenes Windows Task Scheduler feladatot használ, **InteractiveToken + Limited RunLevel** módban.
- Nincs új függőség, nincs jelszókérés vagy új felhasználói fiók. A feladatot a telepítő eltávolítja a CDP-ellenőrzés után.
- Megmaradt a normál UAC kétlépcsős telepítés: ha nem adminisztrátori joggal indult, a telepítő a gépi parancsikonok után a felhasználó saját munkamenetéből indítja a böngészőt.
- A sikerhez ténylegesen válaszolnia kell a `/json/version` és `/json/list` CDP-végpontnak. Hiba esetén STOP és hibanapló.
- A felhasználó által igazolt `v1.1.4` stabil EXE rendelésválasztója, névkinyerése, fókuszkezelése és vágólapformátuma **változatlan**.
- RC tesztkiadás: a külön Windows-fiókos/valós Brave indítás gyakorlati visszaellenőrzése szükséges a hibás gépen.

## v1.1.7-rc.1 – általános alkalmazásfókusz visszaállítása

- Két vagy több megnyitott rendelésnél a választó előtt aktív **bármely Windows-ablak** kerül előtérbe a kiválasztás, másolás vagy Esc utáni bezáráskor (nem csak Illustrator vagy Photoshop).
- A Windows időnként blokkolja a `SetForegroundWindow` hívást. Biztonságos Win32 `AttachThreadInput` tartalék állítja vissza a korábban aktív ablakot; csak érvényes ablakra és a konzolválasztó futása után.
- A fókuszvisszaállítás most először még a `FreeConsole` hívás előtt történik, majd a konzol bezárását követően szükség esetén ellenőrzötten újrapróbálja.
- **Egyetlen rendelésnél változatlan** az azonnali, konzol nélküli vágólapmásolás, fókuszváltás nélkül.
- Az összes többi működés (vevőnév, RO/HU/SK/CZ, SOS, portok, telepítő, böngészőprofilok) változatlan. A tesztkiadás a felhasználó Windows-ablakainak valós kipróbálásáig RC.


## v1.1.8 – stabil UAC-útvonalkezelés

- Az emelt telepítő teljes útvonala és célmappája adatként jut át a PowerShell és CMD között; az aposztróf, Unicode, százalékjel és további legális karakterek nem értelmeződnek parancsként.
- Közös elevate_installer.ps1 segéd, JSON/Base64 adatátadás és rögzített /elevated-child jelző; a normál felhasználói CDP-ellenőrzés megmarad.
- Az argumentummal indított telepítés is ellenőrzi az emelési szükségletet. A scriptsmásolás nem ad útvonalakat a CALL második értelmezési körének.
- Megmarad a v1.1.7 általános alkalmazásfókusz-javítása, a korábbi rendelésválasztó, többnyelvű névkinyerés és az automatikus CDP-indítás.
- Automatikus regressziós ellenőrzés a valódi BAT/helper/encoded-bootstrap/CMD adatútra; RunAs-kérés, /elevated-child, parent CDP-folytatás, hibakód és megszakítás is ellenőrzött.
- A javítás alapváltozatán négy valódi UAC-telepítés/újratelepítés sikeres volt normál és speciális útvonalakkal; a mért token Limitedből Fullra váltott. A gép házirendje kérdés nélküli emelést engedélyezett; interaktív UAC-Igen/Nem nem volt tesztelve.
- A v1.1.8 összeillesztett kiadása újra lefuttatja a legújabb Go-, JavaScript-, telepítő- és CDP-teszteket. A felhasználó kérésére stabil, RC nélkül.
- Az összes korábbi GitHub Release megmarad; külön v1.1.8 EXE és teljes ZIP készül.

