# v1.1.11 ellenőrzési jegyzőkönyv – 2026-10-14

- PASS: teljes Go-tesztsor, CDP-töredékek 4 MiB összkorlátja, sorrend/control frame, verzió, formátum és záró szóköz.
- PASS: a tényleges beágyazott JavaScript 11 HU/RO/SK/CZ/EN névkiolvasási és SOS esete.
- PASS: Windows telepítő fresh/reinstall/same-path; Brave/Chrome/Edge és Edge-only; nincs böngésző esetén leállás; gépi konfiguráció, indítóikonok, SHA256, UTF8 BOM/CRLF.
- PASS: valódi BAT/helper/-File worker/CMD útvonalátadás; ékezet, aposztróf, %, !, &, ^, zárójel, záró backslash és injekciós minták. RunAs/UAC kizárólag ebben a tesztben mockolt.
- PASS: megszakítás jóváhagyás előtt nem ír; automatikus indítás On/Off külön választás; frissítéskor a saját régi Startup-link törlődik.
- PASS: a natív indító tényleges tesztböngésző-folyamatot indít; Windows argv pontos ékezetes/metakarakteres profilútvonallal; Auto választás, loopback CDP, korábbi profil és bejelentkezési adat megőrzése.
- PASS: /json/version és /json/list ellenőrzés; hiányzó/hibás CDP elutasítása; a teljes indítási határidőt a megállt HTTP-végpont sem lépheti túl.
- PASS: eltávolító csak saját fájlokat/ide mutató ikonokat töröl; idegen manifest elutasítása; azonos nevű, más célú parancsikon, idegen fájl és profil megőrzése.
- PASS: tényleges BAT-eltávolító közvetlen és mockolt UAC útvonalon; saját BAT törlése után exit 0, megszakításnál érintetlen telepítés.
- PASS: valamennyi PowerShell-fájl szintaktikai ellenőrzése.
- PASS: a v1.1.9 forrásával összevetve a platform_windows.go, platform_other.go és cdp_fragment_test.go tartalma változatlan; Git-blobjaik azonosak. A kiadási checkout a sortöréseket explicit .gitattributes szerint kezeli. A meglévő másolólogikában csak az új, külön --start-browser belépési ág és import-rendezés változott; fókusz/konzol/vágólap/rendeléskiolvasás változatlan.
- PASS: helyben fordított EXE Microsoft Defender egyedi vizsgálata: found no threats, exit 0, változatlan hash. Platform 4.18.26090.9, szignatúra 1.461.20.0. Az első, perjeles útvonallal indított vizsgálat hibával zárult; a Windows által feloldott teljes útvonalon a vizsgálat sikeresen végigfutott.

A közzétett EXE és ZIP a CI ellenőrzött forrásából készül; a végső, letöltött kiadási fájlok hash- és Defender-jegyzőkönyve a munkahelyi qa-v1.1.11 mappában található. A teszt nem kapcsolja ki a védelmet, nem alkalmaz kizárást és nem karanténozza a csomagot.

## Bizonyítási határok

- A valódi UAC-párbeszéd és eltérő adminfiók nem automatizált; az emelt indító Limited/InteractiveToken szerződését a teszt forrásból is ellenőrzi.
- Valódi, éles rendeléseken a grafikai program fókusztesztje és a harmadik gép új telepítővel történő próbája még szükséges. A képen a gépi szakasz kész, a normál felhasználói böngészőindítás következett. A konkrét ottani hibaoka az ottani napló nélkül nem ismert.
- A natív indítóban nincs PowerShell. Közvetlen admin-telepítéskor az ideiglenes Windows-feladat EXE-t indít, nem üres Terminal/PowerShell ablakot. CDP-várakozás: natív 20 s; admin-ellenőrzés 30 s, rövid egyedi HTTP-kérésekkel, feladatállapot/eredménykód és napló.
- Hiteles kiadói kódaláírás nincs. A Google korábbi automatikus malware-minősítésének konkrét szabályát nem adta meg; a Drive elfogadása és minden víruskereső eredménye nem garantált.

## Ellenőrzött dokumentáció

- [Google Unwanted Software Policy](https://www.google.com/about/unwanted-software-policy.html): tájékoztatás, érdemi választás, egyszerű eltávolítás, idegen fájlok megőrzése, adatkezelés; az aláírási ajánlásnak jelenleg nem felel meg.
- [PowerShell -File és szó szerinti paraméterek](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_powershell_exe?view=powershell-5.1).
- [Start-Process / RunAs](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/start-process?view=powershell-5.1).
- [Chrome remote debugging és külön profil](https://developer.chrome.com/blog/remote-debugging-port).
