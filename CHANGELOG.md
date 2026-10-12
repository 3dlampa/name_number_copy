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