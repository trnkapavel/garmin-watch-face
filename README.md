# Garmin Watch Face (Connect IQ)

Jednoduchy cifernik pro Garmin hodinky v Monkey C.

## Co zobrazuje

- cas (12/24h podle nastaveni zarizeni)
- datum
- kroky
- stav baterie

## Poznamky

- Projekt je pripraveny jako zaklad pro dalsi upravy designu.
- Podporovane produkty jsou zatim: `fr245`, `venu`, `vivoactive4`.

## Build a simulace

1. Nainstaluj Connect IQ SDK (např. z [Garmin Developer](https://developer.garmin.com/connect-iq/sdk/)).
2. Build (použij svůj klíč pro podpis):

```bash
monkeyc -f monkey.jungle -o bin/WatchFace.prg -d venu -y developer_key
```

3. Spuštění simulátoru – vyber jeden způsob:

**A) Skript v projektu (doporučeno):**
```bash
chmod +x run-simulator.sh
./run-simulator.sh
```

**B) Přímo z SDK (cesta se může lišit podle verze):**
```bash
open -a "$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.4.1-2026-02-03-e9f77eeaa/bin/ConnectIQ.app"
```

**C) Build a hned spustit v simulátoru (monkeydo):**
```bash
monkeydo bin/WatchFace.prg venu
```
*(Potřebuješ mít `monkeydo` v PATH – přidej složku `bin` SDK.)*

4. V simulátoru: **File → Open** (nebo přetáhni) a vyber `bin/WatchFace.prg`.

---

### Simulátor se nespustí

- **„The executable is missing“** – App ze SDK někdy na Macu selhává. Zkus spustit přímo binárku:
  ```bash
  "$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.4.1-2026-02-03-e9f77eeaa/bin/ConnectIQ.app/Contents/MacOS/simulator"
  ```
- **Java** – Simulátor potřebuje Javu. Nainstaluj např. OpenJDK 17+ a nastav `JAVA_HOME`.
- **Zkus jinou verzi SDK** – v `~/Library/Application Support/Garmin/ConnectIQ/Sdks/` můžeš mít více verzí; v příkazech změň cestu na starší (např. `connectiq-sdk-mac-8.4.0-...`).
- **VS Code** – rozšíření „Monkey C“ umí build a spuštění simulátoru (F5).
