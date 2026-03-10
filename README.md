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

1. Nainstaluj Connect IQ SDK.
2. Nastav promenne prostredi (typicky `CIQ_SDK_HOME`).
3. Build:

```bash
monkeyc -f monkey.jungle -o bin/WatchFace.prg -d fr245
```

4. Spusteni v simulatoru:

```bash
connectiq
```

Pak v simulatoru otevri vygenerovany `bin/WatchFace.prg`.
