# v1.1.8 stabil – kiadási ellenőrzés (2026-10-13)

A felhasználó kérésére stabil kiadás, RC-utótag nélkül.
Alap: v1.1.7-rc.1, commit 18ea20cd8181447a716460e2ce60a5615acd7450. A meglévő rendeléskinyerés, általános fókusz-visszaadás és normál felhasználói CDP-indítás forrása változatlan.

## Javítás
Az útvonalak a telepítő UAC-határán környezeti változóként, majd JSON/Base64-adatként jutnak át a közös elevate_installer.ps1 segéden. Az emelt CMD egyszer értelmezi a rögzített parancsszöveget, késleltetett bővítés nélkül. A /elevated-child jelző rögzített kapcsoló, nem felhasználói parancsszöveg. A gépi lépcső után megmarad a normál felhasználói CDP-ellenőrzés.
Az argumentummal indított telepítés is az emelésellenőrzésen halad át. A scriptmásolás két hívója nem használ útvonalas CALL-argumentumot; a közös másoló megtartja a mentést és bájtegyezés-ellenőrzést.

## Ellenőrzések
- Windows Go 1.23.12: `go test -count=1 ./...` PASS.
- `go build -trimpath -ldflags '-H windowsgui -s -w' -o 'name - number copy.exe' .` PASS.
- PE subsystem Windows GUI, beágyazott VERSION v1.1.8.
- `node tests/order_name_cases.js`: 11/11 PASS, HU/RO/SK/CZ/EN/DOM/SOS.
- `tests/test_installer_elevation.ps1` Windows PowerShell 5.1: valós BAT/helper/encoded-bootstrap/CMD adatút, normál/aposztrófos/Unicode/százalékjeles/felkiáltójeles/ampersandos/caretes/zárójeles/trailing-backslash útvonal, interaktív célkiválasztás, machine-stage jelző, szülői CDP-folytatás, hibakód, megszakítás, hibás idézőjel elutasítása PASS. RunAs ezekben az automatikus tesztekben helyettesített.
- `tests/test_installer_windows.ps1`: első telepítés, újratelepítési EXE/config/script/ikon mentések és hash, közös tesztikonok, Edge-only, azonos forrás/cél, no-browser STOP, UTF-8 BOM és CRLF PASS.
- Hiányzó CDP esetén hiba, két válaszoló mock CDP-végpont esetén siker PASS. A teszt szabad 9222/9223 portot választ, a már futó böngészőket megőrzi.
- Az admin telepítő meglévő Limited/InteractiveToken ütemezett-feladat ágának megőrzése ellenőrizve.
- Helyi EXE és teljes ZIP egyezése, ZIP root/source script- és VERSION-egyezés, új helper és regressziós teszt jelenléte PASS.

## Valódi UAC-próba és bizonyítási határ
A javítás korábbi alapváltozatán 2026-10-13-án négy teljes valódi telepítés/újratelepítés sikeres volt normál és speciális forrás-/célútvonalakkal, valódi Program Files célba. Közvetlen folyamat-token mérés: nem emelt Limited -> emelt Full PowerShell és CMD. Az eredeti hat közös parancsikon/mentés visszaállt, a próbatelepítések eltávolítva, az eredeti projekt fájljai változatlanok maradtak.
Ez az élő próba az alapváltozathoz tartozik; a v1.1.8 legújabb CDP-/fókuszjavításokkal összeillesztett forrásának ellenőrzése a fenti új automatikus teszteken alapul.
A gép ConsentPromptBehaviorAdmin=0 házirendje kérdés nélküli emelést engedélyezett. Az interaktív UAC Igen/Nem felület, másik adminfiók, új Windows-bejelentkezés és teljes új élő fókuszpróba nem része e kiadási tesztnek. A házirendet nem módosítottuk.

## Megőrzés
A v1.1.4 stabil és az összes korábbi stabil/RC kiadás külön, letölthető mentésként megmarad. Az új kiadás v1.1.8 EXE-t és teljes ZIP-et ad át.
