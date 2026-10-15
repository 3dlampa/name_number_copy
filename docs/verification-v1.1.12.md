# v1.1.12 ellenőrzési jegyzőkönyv – 2026-10-15

## Helyben ellenőrzött működés

- PASS: Go-tesztek, CDP-üzenetkorlát és sorrend, verzió, formázás és utolsó kötőjel utáni szóköz.
- PASS: Windows-folyamatazonosítás valódi helyi TCP-listenerrel; PID, létrehozási idő, saját felhasználó és munkamenet. A korlátozott AppContainer környezet a folyamat-/portadatokat nem engedi olvasni; a teszt normál, nem adminisztrátori Windows-asztali folyamatban futott sikeresen.
- PASS: normál Brave-adatkönyvtár kiválasztása; hiányzó profilnál érthető hiba, külön profil választható, Chrome/Edge és korábbi OpenCart-profilok megmaradnak. A program nem másol vagy importál sütiket/jelszavakat.
- PASS: valódi natív indító és tesztböngésző; Unicode/metakarakteres útvonal, közvetlen normál profilmappa, élő folyamat újrahasználata, eltérő profiljegyzék elutasítása. A futó böngészőt nem állítja le.
- PASS: valódi BAT-telepítő és emelési segéd; Enterrel C:\Scripts, útvonalkódolás és injekciós minták, megszakítás írás nélkül, automatikus indítás külön On/Off, normál/külön Brave választás. A UAC-párbeszéd ezekben a tesztekben mockolt.
- PASS: fresh/reinstall/same-path, gépi parancsikonok, nincs új backup, régi saját backupok célzott takarítása, idegen fájlok/ikonok/profilok megőrzése, eltávolító tényleges BAT-öneltávolítása helyes kilépési kóddal.
- A másoló- és fókuszkezelés meglévő logikáját a változás nem írja át. A natív indító hibája kézi indításnál ablakot mutat; automatikus indításnál csak naplóz.

## Kötelező kiadási ellenőrzések

A két Windows GitHub Actions folyamat minden kiadás előtt megismétli a Go-, a 11 HU/RO/SK/CZ/EN JavaScript-, a telepítő- és az indítóteszteket. A PowerShell-kompatibilitási indítónál a teszt igazolja, hogy visszatér a nyitva maradó böngésző mellett is.

A tests/test_real_brave_windows.ps1 kizárólag eldobható GitHub Windows-workerben fut. A hivatalos Brave v1.97.57 ZIP SHA256- és Authenticode-ellenőrzése után az ottani tényleges normál User Data könyvtárral próbálja a termék indítóját, az élő folyamat újrahasználatát és a szabályos bezárás utáni újraindítást. Saját gépen, meglévő normál profilnál megtagadja a futást. A tesztböngésző nincs a termékcsomagban; a termék nem tölt le böngészőt.

Az EXE/ZIP közzétételét a fenti tesztek és az összeállított ZIP verzió-/tartalomellenőrzése blokkolja, ha hiba történik. A letöltött, kiadási hash-sel azonos EXE és ZIP Defender-vizsgálati eredménye a munkahelyi qa-v1.1.12 mappában kerül rögzítésre.

## Bizonyítási határok

- Tényleges Google-fiókba belépés és a Google kockázati döntése nem automatizált. A meglévő adatkönyvtár használata megőrzi a helyi bejelentkezési állapotot; lejárt vagy szerveroldalon érvénytelenített belépést nem állít helyre, újraazonosítást nem zár ki.
- A normál profil CDP-kapcsolata annak megnyitott lapjait helyi programoknak elérhetővé teszi. A telepítő ezt előre jelzi. A folyamatellenőrzés a téves profil újrahasználatát akadályozza; a CDP-végpontnak nem ad Windows-fiókalapú hitelesítést.
- A Chrome 136+ alapértelmezett profiljának CDP-korlátját nem kerüli meg: Chrome/Edge továbbra is külön profillal indul. A Brave-támogatás a fent megadott tényleges verzión ellenőrizhető, nem minden jövőbeli verzióra tett ígéret.
- Valódi UAC-Igen/Nem, másik adminfiók, a felhasználó harmadik gépe és aktív Illustrator-munkamenete külön gyakorlati próba. A felhasználó szerint a korábbi harmadik gépes elakadást a böngésző újratelepítése oldotta meg; a pontos korábbi hibaok nem bizonyított.
- Nincs hiteles kiadói kódaláírás. A Google Drive korábbi minősítésének konkrét szabályát nem közölték; a Drive elfogadását nem lehet garantálni.

## Ellenőrzött elsődleges dokumentáció

- [Chromium profil és adatkönyvtár](https://www.chromium.org/developers/creating-and-using-profiles/).
- [Chrome 136 remote debugging változás](https://developer.chrome.com/blog/remote-debugging-port).
- [Brave sensitive data storage](https://support.brave.com/hc/en-us/articles/29808985123085-Sensitive-data-storage).
- [Microsoft GetExtendedTcpTable](https://learn.microsoft.com/en-us/windows/win32/api/iphlpapi/nf-iphlpapi-getextendedtcptable) és [GetProcessTimes](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getprocesstimes).
- [PowerShell Start-Process várakozás a folyamatszerkezetre](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/start-process?view=powershell-5.1) és [.NET Process.WaitForExit](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.process.waitforexit).
