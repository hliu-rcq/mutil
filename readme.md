# Disclaimer
This is made with the use of ai. Attached to this repo is a **mutil-context.md** file with the chat history summed up.
The context file makes it possible to continue development without needing to waste credits to understand the tool to recreate it. 

# mutil

`mutil` is a small CLI tool to start, stop and connect to **MuMu Player**
Android emulators from the terminal. It was originally written (with Copilot) to
simplify connecting to an emulator via `adb` so you don't have to look up ports
by hand, and later grew to also start and stop devices from the same terminal.

_A Dutch version of this document is available as `readme_nl.md`._

Running instances are queried through `MuMuManager.exe`. For each instance the
tool automatically picks the port in the Android emulator range (5554-5585).
Those ports are recognised by the Android SDK and Visual Studio, unlike the high
`adb` port that MuMu reports by default.

## Commands

Usage: `mutil <command> [name]`

| Command | Description |
| --- | --- |
| `devices` | Show all devices with status and adb connection. |
| `open` | Start a stopped emulator (asks which if several). |
| `close` | Stop a running emulator (asks which if several). |
| `connect` | Connect `adb`; starts the device first if needed. |
| `disconnect` | Disconnect `adb` from a device. |
| `help` | Show the help text. |

### Selecting multiple devices

When several devices qualify, the tool shows a numbered list. You can then:

- enter a single number, for example `2`;
- separate multiple numbers with commas, for example `1,3,5`;
- enter `A` to select all listed devices.

Devices that are currently starting up or shutting down are not offered by
`open` and `close`.

### Filtering by name

For `open`, `close`, `connect` and `disconnect` you can pass a name, e.g.
`mutil connect Dev`. Only devices whose name contains that text
(case-insensitive) are offered. If exactly one matches, the action runs
immediately.

### Waiting for start/stop

`open` and `close` wait until the device is actually online or stopped
respectively. They check every 5 seconds and abort after 2 minutes with a
timeout. `connect` uses the same wait when it has to start an inactive device
first.

Without a name, `connect` lists every device that is not yet connected via adb
(online-but-not-connected and not-started). Pick an online device and it just
connects; pick a not-started device and it first runs the `open` behaviour
(start and wait until online) and then connects. If exactly one candidate
exists, it is handled directly. If all devices are already connected, it says
so.

### Auto-starting MuMu Player

If MuMu Player is not running, every command first asks whether to start it
(`Y`/`N`). Any answer containing a `y` (such as `y`, `Y`, `yes`) starts MuMu
Player; anything else lets the command continue. After starting, the tool waits
until MuMu Player is running (checking every 3 seconds, 2 minute timeout).

## Requirements

Make sure the following are present before using `mutil`:

- **Git Bash** (MSYS2) — the script is a POSIX shell script.
- **adb** on `PATH` (Android SDK platform-tools).
- **MuMu Player 12** (found automatically; see below).
- **PowerShell** (installed by default on Windows).

`mutil` locates `MuMuManager.exe` automatically: via the default path, a running
MuMu process and the uninstall registry. If MuMu is installed in a non-standard
location, set the environment variable `MUMU_MANAGER` to the full path of
`MuMuManager.exe`.

## Installation

Run the steps below in **Git Bash**.

Copy `mutil` and `mutil.cmd` to a fixed folder, for example:

```bash
mkdir -p /c/Sources/mutil
cp mutil mutil.cmd /c/Sources/mutil/
```

Then add the **folder** `C:\Sources\mutil` (not the file) to the Windows `PATH`
environment variable. Open a new window and run `mutil devices`.

The `mutil.cmd` wrapper launches the script via Git Bash, so the command also
works in **cmd** and **PowerShell**. Make sure `adb` is on `PATH`.

## Windows Terminal profile

To add a profile that opens `mutil`, run this in **PowerShell**. It first makes
a backup (`settings.json.bak`), inserts the profile after `"list": [` and
validates the JSON:

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

Restart Windows Terminal afterwards; the **mutil** profile appears in the
dropdown. You can also open it with `wt -p mutil`. The same script is available
as `terminal-profile.ps1`; if script execution is blocked, run:

```powershell
powershell -ExecutionPolicy Bypass -File terminal-profile.ps1
```

## Example

```text
$ mutil devices
MuMu devices:
  Android Device               (offline)
  SCS - Ontwikkeling           (online, adb: connected) 127.0.0.1:5559
  SCS - Ontwikkeling - Review  (online, adb: not connected) 127.0.0.1:5563
```
