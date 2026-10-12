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