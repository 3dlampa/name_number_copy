# v1.1.9 ellenőrzés

## Változás és bizonyíték

A v1.1.8 telepítő a régi indítóparancsikont ugyanabba a CommonStartup mappába mentette `.lnk.backup_yyyyMMdd_HHmmss_fff` néven. A felhasználó gépén megtalált `OpenCart Rendelesmasolo - bongeszoinditas.lnk.backup_20261012_110113_288` végződése egyezik a felugró ablakban láthatóval.

A v1.1.9 nem készít backupot. A PowerShell setup közös takarítófüggvénye csak a telepítő öt ismert program/config/script nevéhez és négy ismert parancsikonjához tartozó, korábban generált dátumos vagy két véletlen számos suffixet törli. A törlés nem rekurzív, LiteralPath-ot használ, hiba esetén a setup nem jelent sikert.

A meglévő formatValue közös formázó normál és SOS ága egy záró ASCII szóközt ad a szöveghez; mindkét másolási út ezt használja.

A csomagellenőrzés kimutatta, hogy a korábban helyben javított és ellenőrzött CDP-töredékkezelés nem szerepelt a v1.1.8 GitHub-forrásában. A meglévő ellenőrzött implementáció CDP-része és eredeti regressziós tesztje bekerült a v1.1.9-be. A teljes Go-tesztcsomag ezután ismét sikeres: az összesített 4 MiB üzenetkorlát, a memóriafoglalás előtti méretellenőrzés, az üzenetsorrend és a ping/pong kezelés megőrzött.

A GitHub build teljes tagelőzményt tölt le. A még ki nem adott verzió befejezhető több commitban; már tagelt verzióhoz továbbra is kötelező az új PATCH-szám. A publikálás továbbra is ellenőrzi az előző kiadáshoz képest pontosan egy PATCH-lépést, az aktuális main commitot és a két kötelező assetet. Korábbi commit vagy kiadás nincs átírva.

## Ellenőrzések

- A módosított ország/SOS teszt az eredeti kódon 14 eltéréssel hibázott a hiányzó záró szóköz miatt.
- Go teljes tesztcsomag: sikeres, beleértve a verzió-, fókusz/választó-logika- és CDP-fragmentációs teszteket.
- A tényleges beágyazott JavaScript 11 névkiolvasási tesztje: sikeres.
- Windows GUI build: `-H windowsgui -s -w`; nincs általános konzolos buildre váltás.
- Windows telepítő: új telepítés, régi backupfixture-ek törlése, ismételt és azonos mappás telepítés backup nélkül, idegen backup/nevek megőrzése, aktív indítóikonok és autostart megőrzése.
- UAC-útvonalteszt: az emelés mockolt; speciális karakterek, visszavonás és hibás gyermekfolyamat ellenőrzése.
- CDP: izolált hiányzó endpoint és egészséges mock endpoint; aktív felhasználói böngészőkhez nem nyúl.
- A gépen azonosított kilenc régi telepítőbackup törölve; hét aktív telepített fájl SHA-256 tartalma változatlan.
- Windows PowerShell 5.1-hez UTF-8 BOM, BAT-hoz CRLF ellenőrizve.

## Gyakorlati határok

A telepítő tesztje saját mappákba dolgozik és nem indít éles webshopböngészőt. A másoló élő Illustrator-fókusza és vágólapos beillesztése ebben a kiadásban nem lett külön élő GUI-teszttel megismételve; a platformkód változatlan, a formátum pontos szövegértékét regressziós teszt ellenőrzi. A backupok törléséhez ezen a gépen valódi UAC-emelés sikeresen megtörtént.

## Források

- [Microsoft: Indítópult kezelése](https://support.microsoft.com/en-gb/windows/experience/startup-boot/configure-startup-applications-in-windows)
- [Microsoft: Remove-Item és LiteralPath](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/remove-item?view=powershell-5.1)
- [Go fmt](https://pkg.go.dev/fmt)
- [GitHub Release](https://docs.github.com/en/rest/releases/releases)
