# Poznámky z vývoje

Co se při stavbě tohohle ciferníku ukázalo jako podstatné. Psáno tak, aby se to nemuselo
objevovat podruhé.

## Zadání a mantinely

- Ciferník na prodej v Connect IQ Store, cíl **jen `epix2pro51mm`** (začít úzce).
- Název ani popis aplikace **nesmí obsahovat „fēnix“ ani „Garmin“** – ochranné známky.
  Současné `AppName` v `resources/strings` je pracovní placeholder, před vydáním změnit.
- **Žádné bitmapy z firmwaru Garminu** – všechno překreslené vlastními prostředky.
- Vnější prstenec je oblouk východ–západ slunce. Živý kompas v CIQ watch face nejde
  (watch face nemá přístup k průběžnému čtení senzorů).
- Sluneční data z **vlastního NOAA výpočtu**, ne z Weather API.

## Geometrie kruhového displeje

454×454, střed (227, 227). Ticky mají vnitřní hranu na poloměru **`CONTENT_R = 193`**.

Použitelná polovina šířky ve svislém odsazení `dy` od středu:

```
halfW = sqrt(CONTENT_R² − dy²)
```

Disk se u horního i dolního okraje **prudce zužuje**. Konkrétně změřené volné pruhy
v hotovém layoutu:

| pásmo (dy) | výška | šířka |
|---|---|---|
| −97 … −61 | 37 px | 326 px |
| +25 … +54 | 30 px | 364 px |
| +161 … +188 | 28 px | **54 px** |

Poslední řádek je poučení: pod spodními gauge se prakticky nic nevejde.

**Ponaučení: layout neodhadovat, ale změřit.** Křivku tlaku jsem dvakrát umístil špatně,
protože jsem si volné místo tipnul. Spolehlivý postup je vyrenderovat snímek ze
simulátoru a projít ho po řádcích – hledat souvislé pruhy černých pixelů.

## AOD a AMOLED

- V AOD smí svítit **max 10 % pixelů**. Naměřeno u téhle verze: **4,55 %** kresby,
  **5,11 %** včetně skleněného odlesku, který simulátor kreslí přes displej.
  (Ten odlesk je asi 0,56 % a do vlastního rozpočtu nepatří – při měření ho odečti.)
- Burn-in: souřadnice v AOD průběžně posouvat, kontrolovat
  `DeviceSettings.requiresBurnInProtection`.
- Křivka tlaku se v AOD vůbec nekreslí (`if (aod) { return; }`).

## Pasti, na které jsme narazili

- **Simulátor běží ve 12hodinovém formátu.** Kvůli tomu vypadala značka aktuálního času
  na prstenci jako chyba – displej ukazoval 11:27, zatímco Mac měl 23:27. Značka byla
  celou dobu správně. Než začneš hledat chybu v úhlech, zkontroluj formát času.
- **Typechecker Monkey C odmítne `null` v číselném lokálu**, který jde do `dc.drawLine`.
  Vzor `var lastX = null; … drawLine(lastX, …)` neprojde – přepiš na indexovou smyčku,
  kde se počítají oba konce úsečky.
- **`SensorHistory` vyžaduje oprávnění v manifestu**, jinak build spadne na šesti chybách:
  ```xml
  <iq:uses-permission id="SensorHistory"/>
  ```
  Volání navíc chraň `Toybox has :SensorHistory`.
- **Simulátor tlaková data má** (jen velmi plochá). Proto křivka potřebuje minimální
  rozpětí `GRAPH_MIN_SPAN` – pod ním by se kreslil jen šum senzoru.
- Podpisový klíč je v kořeni repa jako `developer_key`, ne v `~/.Garmin/`.

## Spotřeba paměti

Limit pro watch face na `epix2pro51mm` je **131072 B (128 kB)**, aktuální využití
zhruba **11,1 kB**. Release `.prg` má 18 220 B. Prostor na vlastní bitmapový font
z TTF tedy je – to je zatím největší nevyužitá vizuální rezerva, jen pozor na paměť.

## Sideload do hodinek

Epix Pro Gen 2 se **nepřipojí jako disk** – v `/Volumes` se nikdy nic neobjeví.
Podle USB režimu v nastavení hodinek se hlásí jako:

| režim | PID | co to je |
|---|---|---|
| MTP | `0x50da` | Composite Device, funguje přes MTP |
| Garmin | `0x0003` | Vendor-Specific Device, proprietární protokol |

Vendor ID je vždy `0x091e` (Garmin International).

Cíl přenosu: `Internal Storage` → `GARMIN` (folder id 16777216) → `Apps` (id 16777274).
ID zjistíš přes `mtp-folders`.

**`mtp-sendfile` na tomhle zařízení nefunguje** – skončí na
`PTP Layer error 2002: get_suggested_storage_id(): could not get storage id from parent id`,
protože neumí ke `parent_id` dohledat `storage_id`.

Řešení je [`tools/mtpput.c`](tools/mtpput.c): nastaví na `LIBMTP_file_t` **oba** údaje
(`storage_id` z `LIBMTP_Get_Storage`, `parent_id` ručně) a zavolá
`LIBMTP_Send_File_From_File`, čímž problémovou cestu obejde.

```bash
brew install libmtp
clang -o tools/mtpput tools/mtpput.c \
  -I/opt/homebrew/opt/libmtp/include -L/opt/homebrew/opt/libmtp/lib -lmtp
tools/mtpput build/UltraSun.prg UltraSun.prg 16777274
```

Dvě věci, které přenos spolehlivě rozbijí:

1. **Běžící OpenMTP** si zařízení zabere výhradně pro sebe – libmtp pak hlásí, že žádné
   zařízení nevidí. Před přenosem ho ukonči (`osascript -e 'quit app "OpenMTP"'`).
2. **Režim „Garmin“** místo MTP – přes MTP se pak zařízení oslovit nedá.

Po nahrání kabel odpojit a ciferník vybrat v nabídce hodinek.

## Stav

- Otestováno v simulátoru. **Na reálném zařízení zatím nespuštěno.**
