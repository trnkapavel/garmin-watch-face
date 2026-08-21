# Watch face pro Epix Pro Gen 2 51mm (Connect IQ)

Vlastní ciferník v Monkey C, designově vycházející z Apple Watch Ultra (ne kopie).
Cílové zařízení: **`epix2pro51mm`** (454×454 AMOLED, API 5.2).

## Co zobrazuje

- **Čas** velkými číslicemi s jemným gradientem, pod ním datum
- **Vnější prstenec** = oblouk od východu do západu slunce, barva se mění podle denní doby;
  na prstenci značky východu, západu a aktuálního času
- **Hodinové ticky** po obvodu
- **Čtyři gauge** (dvě nahoře, dvě dole): tep, kroky, baterie, …
- **Podkladová křivka barometrického tlaku** za 12 h – jemně šedá, hodnotu nese tvar, ne číslo

Poloha slunce se počítá vlastním NOAA algoritmem, ne z Weather API.

## Build

```bash
monkeyc -f monkey.jungle -o build/UltraSun.prg -y developer_key -d epix2pro51mm -r
```

`-r` = release build. Podpisový klíč `developer_key` je v `.gitignore` – **nikdy ho necommituj.**

Vývojový build + simulátor:

```bash
./run-simulator.sh
```

## Nahrání do hodinek (sideload)

Epix Pro se přes USB nehlásí jako disk – viz [`NOTES.md`](NOTES.md), sekce *Sideload*.
Zkráceně: hodinky v režimu **MTP**, ukončit OpenMTP a spustit

```bash
clang -o tools/mtpput tools/mtpput.c \
  -I/opt/homebrew/opt/libmtp/include -L/opt/homebrew/opt/libmtp/lib -lmtp
tools/mtpput build/UltraSun.prg UltraSun.prg <parent_id složky Apps>
```

`parent_id` zjistíš přes `mtp-folders`.

## Dokumentace

- [`NOTES.md`](NOTES.md) – co jsme se při vývoji naučili (geometrie, AOD limity, pasti, sideload)
- [`garmin_rules.md`](garmin_rules.md) – referenční pravidla Connect IQ / Monkey C
