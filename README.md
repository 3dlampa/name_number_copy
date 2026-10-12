# Név és rendelésszám vágólapra másoló

**Verzió:** 2026.10.12-choice-v1.0.2  
**Platform:** Windows 11 x64  
**Programfájl:** `name - number copy.exe`

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

`HU 132688 - Matyikó Tamás -`  
`HU 132688 - SOS - Matyikó Tamás -`  
`RO 132688 - Matyikó Tamás -`  
`SK 84 - Matyikó Tamás -`  
`CZ 555 - Matyikó Tamás -`

Az országkód a webshop domainjéből jön, nem a böngésző nyelvéből.

## Telepítés

A célkönyvtár:

`D:\3d lámpa\Photoshop és Illustrator scriptek`

1. Zárd be a korábban beragadt másoló EXE-t, ha még fut.
2. Másold az új `name - number copy.exe` fájlt a fenti mappába a meglévő fájl helyére. A jelenlegi fájlról előtte készíts mentést.
3. Alternatívaként futtasd az új, mellékelt `telepites.bat`-ot. Megőrzi a régi EXE-t időbélyeges `.backup_...` néven, majd a helyére másolja az újat. **Nem** használja a korábbi `C:\Scripts` célútvonalat, és nem telepít böngészőt.
4. Teszteld egy és két különböző, nyitott rendelés mellett, lehetőleg aktív Illustrator ablakkal.

**Fontos:** Ez a feltöltött hibás Go-alapú EXE működését reprodukáló/javító forrás, nem az eredeti elveszett forrásfájl visszafejtett, byte-pontos másolata. Mivel a Windows és az Illustrator nem érhető el a tesztkörnyezetben, a fókusz és a konzol valós viselkedését a felhasználó gépén is tesztelni kell. Hibák logja: `%TEMP%\name_number_copy_error.log`.

## Fordítás / ellenőrzés

```sh
go test -count=1 ./...
GOOS=windows GOARCH=amd64 go build -trimpath -ldflags='-H windowsgui -s -w' -o 'name - number copy.exe' .
```

Az `-H windowsgui` szükséges, hogy egy rendelésnél ne nyíljon konzol. Az `AllocConsole` csak két vagy több egyedi rendelésnél fut.

## Biztonság / megőrzés

- Telepítéskor az eredeti EXE biztonsági másolata megmarad.
- Adatbázist, webshop-állományokat és rendeléseket nem módosít.
- A vágólapot csak sikeresen kiolvasott, kiválasztott rendelésnél írja.
- CDP WebSocket csak localhost `9222`/`9223` porton engedélyezett.
- Hibáknál nem ír ki felugró ablakot, helyette naplófájlba ír.