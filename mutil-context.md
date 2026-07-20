# mutil — context en voortgang

Dit document is **zowel documentatie als bouwinstructie**: het legt vast wat
`mutil` doet en waarom, én hoe je zo'n tool opnieuw kunt opbouwen. Zo kan het
werk later worden opgepakt of gereconstrueerd, ook zonder chatgeschiedenis.
Stand: 2026-07-20, mutil 2.0.

## Doel

`mutil` is een CLI-tool om Android-emulators van **MuMu Player 12** vanuit de
terminal te beheren: devices tonen, starten/stoppen en `adb` verbinden/
verbreken. Het vervangt het handmatig opzoeken van poorten en `adb connect`.

## Bouwaanpak (om opnieuw te maken)

Volg deze stappen; de details staan verderop in dit document.

1. **Omgeving**: schrijf een POSIX-shellscript (`#!/bin/sh`) voor Git Bash en
   gebruik `powershell.exe` voor Windows-specifieke queries (MuMuManager-JSON,
   `netstat`, registry). `nc`/`ss` ontbreken, dus vermijd die aanpak.
2. **Kernquery `mumu_query`**: roep één keer `MuMuManager info -v all` aan, parse
   de JSON in PowerShell en geef per instance één regel
   `INDEX<TAB>NAAM<TAB>STATUS<TAB>ADRES`. Zie *Statusbepaling* en *Poortkeuze*.
3. **Manager vinden (`find_manager`)**: env-override `MUMU_MANAGER` → vaste
   paden → draaiend MuMu-proces → uninstall-registry (via `DisplayIcon` /
   `UninstallString`). Geef het pad aan PowerShell door via `MUMU_MM`.
4. **Lijst-helpers**: `list_full` voegt de adb-verbindingsstatus toe (via
   `adb devices`); `list_instances` is een dunne `awk`-filter.
5. **Commando's**: `devices` (tonen), `open`/`close` (starten/stoppen en wachten
   met `wait_state` + `device_online`/`device_stopped`), `connect`/`disconnect`
   (`adb` via `connect_row`, dat een offline device eerst start).
6. **Interactie**: genummerde keuze (`parse_choices`, komma's + `A`=alles),
   naamfilter (`filter_by_name`) en tolerante `Y/N`-prompts (`confirm_yes`).
7. **Robuustheid**: temp-bestanden via `mktemp` + `trap`, fouten naar stderr
   (`err`), PowerShell in een *quoted* heredoc (geen injectie).
8. **Wrapper + installatie**: `mutil.cmd` lokaliseert Git Bash en geeft args
   door (werkt in cmd/PowerShell); zet de map op de Windows-`PATH`.

## Omgeving

- **Git Bash / MSYS2** (MINGW64) op Windows. Het script is een POSIX-
  shellscript (`#!/bin/sh`).
- Beschikbaar: `adb`, `powershell.exe`, Windows `netstat`, `cygpath`, `mktemp`.
- **Niet** beschikbaar in deze omgeving: `nc`, `ss` (daarom geen netcat-aanpak).
- **MuMu Player 12** met `MuMuManager.exe` (CLI voor instance-info en besturing).

## Bestanden en locaties

| Pad | Rol |
| --- | --- |
| `tools/cli/mutil/mutil` | Het shellscript (alle logica). |
| `tools/cli/mutil/mutil.cmd` | Wrapper voor cmd/PowerShell via Git Bash. |
| `tools/cli/mutil/readme.md` | Gebruikers-README (NL). |
| `tools/cli/mutil/terminal-profile.ps1` | Windows Terminal-profiel toevoegen |
| `C:\Sources\mutil\` | Installatiekopie (`mutil` + `mutil.cmd`) op de PATH. |
| Bureaublad `mutil.lnk` | Pinbare snelkoppeling (`cmd.exe /k mutil`). |

De repo-map heette eerst `muutil` en is later `mutil` geworden; de dubbele map
is opgeruimd. Na elke wijziging worden beide bestanden naar `C:\Sources\mutil`
gekopieerd (identiek houden).

## Commando's

De commando's vallen in twee groepen: MuMu Player-instances beheren (via
`MuMuManager`) versus `adb`-verbindingen beheren. De help toont ze zo
gegroepeerd.

**MuMu Player (instances):**

| Commando | Doel |
| --- | --- |
| `devices` | Alle instances tonen met status en adb-verbinding. |
| `open` | Een gestopte emulator starten (keuze bij meerdere). |
| `close` | Een draaiende emulator stoppen (keuze bij meerdere). |

**adb (verbindingen):**

| Commando | Doel |
| --- | --- |
| `connect` | `adb` verbinden; start het device eerst indien nodig. |
| `disconnect` | Een `adb`-verbinding verbreken. |

`help` toont de helptekst.

Bij meerdere kandidaten toont de tool een genummerde lijst. Invoer kan één
nummer zijn, meerdere komma-gescheiden nummers (`1,3,5`), of `A` (alle getoonde).

Bij `open`, `close`, `connect` en `disconnect` kun je optioneel een naam
meegeven (`mutil connect Dev`) om case-insensitief op naam te filteren; bij
precies één match volgt de actie direct.

## Werking en architectuur

- **`mumu_query`** is de kern: één PowerShell-aanroep die `MuMuManager info -v
  all` (JSON) leest en per instance een regel geeft:
  `INDEX<TAB>NAAM<TAB>STATUS<TAB>ADRES`.
- **`list_full`** breidt `mumu_query` uit met de adb-verbindingsstatus per
  device; **`list_instances`** is een dunne `awk`-filter over `mumu_query`.
- **`find_manager`** lokaliseert `MuMuManager.exe` in volgorde: env-var
  `MUMU_MANAGER`, vaste installatiepaden, draaiend MuMu-proces, en de uninstall-
  registry. `mumu_query` krijgt dit pad door via de env-var `MUMU_MM`.
- **`parse_choices`** valideert de komma-selectie tegen het bereik.
- **`filter_by_name`** + optioneel naam-argument bij `open`/`close`/`connect`/
  `disconnect` (bijv. `mutil connect Dev`): filtert kandidaten op naam (case-
  insensitief, substring). Bij precies één match wordt de actie direct uitgevoerd.
- **`ensure_mumu_running`** draait vóór elk MuMu-commando: is MuMu Player niet
  gestart (`tasklist`-check op `MuMuNxMain.exe`), dan vraagt het `(Y/N)` om te
  starten. Elk antwoord met een `y` (bv. `y`, `yes`) start `MuMuNxMain.exe`; al
  het andere niet. Na het starten wacht `wait_mumu_running` (elke 3s, time-out
  2 min) tot de app draait.
- **`open`/`close` wachten** tot het device online resp. afgesloten is (elke 5s,
  time-out 2 min) via `wait_state` met `device_online` / `device_stopped`.
  `open` gebruikt `start_instance` (gedeeld met `connect`), `close` gebruikt
  `stop_instance`.
- **`connect`/`disconnect`** werken op de volledige lijst (`list_full`) met
  status én adb-status. Zonder naam toont `connect` alle devices die nog niet
  met adb verbonden zijn (online-niet-verbonden én niet-gestarte). `connect_row`
  regelt per device de logica: online → alleen adb connect; offline/booting →
  eerst `start_instance` (open-gedrag: starten + wachten) en dan adb connect.
- **`err`** stuurt foutmeldingen naar stderr; **`new_ps_file`** maakt met
  `mktemp` een tijdelijk `.ps1`-bestand; een `trap` ruimt dat op (ook bij Ctrl-C).

### Statusbepaling

Per instance uit MuMuManager:

- `online` = `is_android_started` én `is_process_started` (beide waar).
- `offline` = beide onwaar.
- `busy` = precies één waar (bezig met opstarten of afsluiten).

`open` biedt alleen `offline` aan, `close` alleen `online`; `busy` valt dus
automatisch buiten beide. `connect` toont juist alle devices die nog niet
adb-verbonden zijn (ongeacht status) en start niet-online devices eerst.

### Poortkeuze (belangrijk)

MuMu exposeert één instance op meerdere `adb`-poorten (bijv. 5559, 7555 en
16448). Alleen poorten in het Android-emulatorbereik **5554-5585** worden door
Visual Studio en de Android SDK herkend. De tool kiest daarom die poort (via de
listening-poorten van het `headless_pid`) in plaats van de hoge `adb_port` die
MuMuManager standaard rapporteert. Een device dat nog opstart (`busy`) toont de
hoge `adb_port` tot de emulator-poort luistert; `connect` haalt het adres
opnieuw op zodra het device online is.

## Belangrijke bevindingen

- Verbinden op de hoge `adb_port` (bijv. 16448) werkte wel met `adb`, maar het
  device verscheen niet in Visual Studio; op de 555x-poort wél.
- MuMu's uninstall-registry heeft een lege `InstallLocation`; het pad wordt
  daarom afgeleid uit `DisplayIcon` en `UninstallString`.
- `where bash` in cmd wees naar **WSL** (`System32\bash.exe`), die Windows-paden
  niet snapt. De wrapper kiest daarom expliciet Git Bash.
- `Get-NetTCPConnection` was traag (~3,7s per aanroep); vervangen door
  `netstat -ano`. Daardoor ging `mutil devices` van ~4,5s naar ~1,4s.

## Best practices die zijn toegepast

- **`mutil.cmd`** volgt de skill *Windows Batch Script Best Practices*
  (`.github/skills/cmd-script-guidelines.sql/SKILL.md`): documentatie-header,
  `setlocal EnableExtensions`, exitcode `3` bij ontbrekende dependency,
  `ERROR:`-prefix.
- **`mutil`** (POSIX-sh): `sh -n`-clean, consequente quoting, PowerShell in een
  *quoted* heredoc (geen injectie), `printf` voor data, foutmeldingen naar
  stderr, tijdelijke bestanden via `mktemp` + `trap`.

## Prestaties

- `mutil devices` ≈ 1,4s (of ~1,8s met een draaiend device).
- Resterende tijd is vooral de opstart van Windows PowerShell (~1s) plus
  `MuMuManager` (~0,4s) — één PowerShell-aanroep per commando.

## Installatie (kort)

Zie `readme.md`. Samengevat: kopieer `mutil` en `mutil.cmd` naar een vaste map
(bijv. `C:\Sources\mutil`) en zet die **map** op de Windows-`PATH`. De wrapper
laat de commando's ook in cmd en PowerShell werken. `adb` moet op de `PATH`
staan.

## Taakbalk-snelkoppeling

Een shellscript of `.cmd` kan niet rechtstreeks aan de taakbalk; Windows pint
alleen snelkoppelingen naar een `.exe`. Daarom is er een snelkoppeling
`mutil.lnk` op het bureaublad met doel `cmd.exe /k mutil` en het MuMu-icoon.
Via rechtsklik -> *Aan taakbalk vastmaken* pin je die (het doel is `cmd.exe`,
dus pinnen mag). Pas het doel-argument aan (bijv. `/k mutil connect`) voor een
vaste actie.

## Windows Terminal-profiel

Er is een profiel `mutil` toegevoegd aan Windows Terminal (`settings.json`,
opdracht `cmd.exe /k mutil`). Het script `terminal-profile.ps1` voegt dat
profiel idempotent toe: het maakt een back-up, voegt het in ná `"list": [` en
valideert de JSON. Openen kan via het dropdownmenu of met `wt -p mutil`; voor de
taakbalk pin je een snelkoppeling naar `wt.exe -p mutil`. De readme bevat het
volledige PowerShell-commando.

## Testen (hoe verifieer je wijzigingen)

- Syntax: `sh -n mutil`.
- README lint: `npx --yes markdownlint-cli readme.md`.
- Functioneel: start/stop een instance met
  `MuMuManager.exe control -v <index> launch|shutdown` en controleer
  `mutil devices` / `open` / `connect` / `disconnect`.
- Timing: `time sh mutil devices`.

## Mogelijke vervolgstappen

Technische verbeteringen:

- PowerShell-opstart (~1s) is de grootste resterende kost; `pwsh` (PowerShell 7)
  start soms sneller, maar is niet gegarandeerd aanwezig.
- Eventueel de status `busy` verder benutten in de UI/uitvoer.
- Detectie-randgevallen: MuMu op een niet-standaard schijf zonder registry-entry
  (dan is de `MUMU_MANAGER`-override de oplossing).

Feature-ideeën:

- `restart`-commando (`MuMuManager control -v <index> restart`).
- Interactief menu wanneer `mutil` zonder argument draait (nu: help).
- `mutil shell [naam]` / `mutil logcat [naam]`: snelkoppelingen naar
  `adb shell` / `adb logcat` voor een device.
- `mutil install <apk> [naam]`: een APK installeren via `adb install`.
- Machine-leesbare uitvoer (`--json`) voor scripting.
- Tab-completion (bash + PowerShell) voor commando's en device-namen.
- Onthouden van het laatst gebruikte device als standaard.
