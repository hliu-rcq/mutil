# mutil

`mutil` is een kleine CLI-tool om Android-emulators van **MuMu Player** te
starten en stop te zetten vanuit de terminal. De tool is met behulp van Copilot
geschreven om initieel het verbinden met een emulator via `adb` te
vereenvoudigen, zodat je niet handmatig poorten hoeft op te zoeken, dit is
uiteindelijk uitgebreid zodat het ook gemakkelijker is om vanuit dezelfde
terminal een device te starten.

De actieve instances worden opgevraagd via `MuMuManager.exe`. Per instance kiest
de tool automatisch de poort in het Android-emulatorbereik (5554-5585). Die
poorten worden herkend door de Android SDK en door Visual Studio, in
tegenstelling tot de hoge `adb`-poort die MuMu standaard rapporteert.

## Commando's

Gebruik: `mutil <commando>`

| Commando | Omschrijving |
| --- | --- |
| `devices` | Toont alle devices met status en adb-verbinding. |
| `open` | Start een gestopte emulator (vraagt welke bij meerdere). |
| `close` | Stopt een draaiende emulator (vraagt welke bij meerdere). |
| `connect` | Verbindt `adb`; start het device eerst indien nodig. |
| `disconnect` | Verbreekt de `adb`-verbinding met een device. |
| `help` | Toont de helptekst. |

### Meerdere devices kiezen

Wanneer er meerdere devices in aanmerking komen, toont de tool een genummerde
lijst. Je kunt dan:

- één nummer invoeren, bijvoorbeeld `2`;
- meerdere nummers scheiden met komma's, bijvoorbeeld `1,3,5`;
- `A` invoeren om alle getoonde devices te kiezen.

Devices die op dat moment aan het opstarten of afsluiten zijn, worden niet
aangeboden bij `open` en `close`.

### Filteren op naam

Bij `open`, `close`, `connect` en `disconnect` kun je een naam meegeven, bijv.
`mutil connect Dev`. Alleen devices waarvan de naam die tekst bevat (niet
hoofdlettergevoelig) worden aangeboden. Is er precies één match, dan wordt de
actie meteen uitgevoerd.

### Wachten op start/afsluiten

`open` en `close` wachten tot het device daadwerkelijk online respectievelijk
afgesloten is. Ze controleren elke 5 seconden en breken na 2 minuten af met een
time-out. `connect` gebruikt hetzelfde wachten als het een inactief device
eerst moet starten.

Zonder naam toont `connect` een lijst van alle devices die nog niet met adb
verbonden zijn (online-niet-verbonden én niet-gestarte). Kies je een online
device, dan verbindt hij alleen; kies je een niet-gestart device, dan voert hij
eerst het `open`-gedrag uit (starten en wachten tot online) en verbindt daarna.
Is er precies één kandidaat, dan handelt hij die direct af. Zijn alle devices
al verbonden, dan meldt hij dat.

### MuMu Player automatisch starten

Draait MuMu Player niet, dan vraagt elk commando eerst of je hem wilt starten
(`Y`/`N`). Elk antwoord dat een `y` bevat (zoals `y`, `Y`, `yes`) start MuMu
Player; al het andere laat het commando gewoon doorgaan. Na het starten wacht
de tool tot MuMu Player draait (controle elke 3 seconden, time-out 2 minuten).

## Vereisten

Zorg dat de volgende zaken aanwezig zijn voordat `mutil` bruikbaar is:

- **Git Bash** (MSYS2) — het script is een POSIX-shellscript.
- **adb** in `PATH` (Android SDK platform-tools).
- **MuMu Player 12** (wordt automatisch gevonden; zie hieronder).
- **PowerShell** (standaard aanwezig op Windows).

`mutil` zoekt `MuMuManager.exe` automatisch op: via het standaardpad, een
draaiend MuMu-proces en de uninstall-registry. Staat MuMu op een niet-standaard
locatie, zet dan de omgevingsvariabele `MUMU_MANAGER` op het volledige pad naar
`MuMuManager.exe`.

## Installatie

Voer de onderstaande stappen uit in **Git Bash**.

Kopieer `mutil` en `mutil.cmd` naar een vaste map.
Dit kun je bijv. als volgt doen met de volgende commando's:

```bash
mkdir -p /c/Sources/mutil
cp mutil mutil.cmd /c/Sources/mutil/
```

Voeg vervolgens de **map** `C:\Sources\mutil` (niet het bestand) toe aan de
Windows-omgevingsvariabele `PATH`. Open daarna een nieuw venster en gebruik
`mutil devices`.

De `mutil.cmd`-wrapper start het script via Git Bash, waardoor het commando ook
werkt in **cmd** en **PowerShell**. Zorg dat `adb` in `PATH` staat.

## Windows Terminal-profiel

Een profiel toevoegen dat `mutil` opent. Voer dit uit in **PowerShell**; het
maakt eerst een back-up (`settings.json.bak`), voegt het profiel na `"list": [`
in en valideert de JSON:

```powershell
$settings = Join-Path $env:LOCALAPPDATA `
    'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
Copy-Item $settings "$settings.bak" -Force
$text = [IO.File]::ReadAllText($settings)
if ($text -notmatch '"name"\s*:\s*"mutil"') {
    $guid = "{$([guid]::NewGuid())}"
    $prof = @"
            {
                "name": "mutil",
                "commandline": "cmd.exe /k mutil",
                "startingDirectory": "%USERPROFILE%",
                "guid": "$guid"
            },
"@
    $rx  = [regex]'("list"\s*:\s*\[)'
    $new = $rx.Replace($text, "`$1`r`n$prof", 1)
    $null = $new | ConvertFrom-Json
    $enc = New-Object Text.UTF8Encoding $false
    [IO.File]::WriteAllText($settings, $new, $enc)
}
```

Herstart daarna Windows Terminal; het profiel **mutil** staat in het
dropdownmenu. Openen kan ook met `wt -p mutil`.

Als je geen rechten hebt om de script uit te voeren, voer dan eerst het
volgende uit op de locatie waar het bestand staat:

```powershell
powershell -ExecutionPolicy Bypass -File terminal-profile.ps1
```

## Voorbeeld

```text
$ mutil devices
MuMu devices:
  Android Device               (offline)
  SCS - Ontwikkeling           (online) 127.0.0.1:5559
  SCS - Ontwikkeling - Review  (online) 127.0.0.1:5563
```
