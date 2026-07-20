# mutil — context and progress

This document is **both documentation and a build guide**: it records what
`mutil` does and why, and how you could rebuild such a tool. That way the work
can be picked up or reconstructed later, even without chat history.
State: 2026-07-20, mutil 2.0.

*A Dutch version of this document is available as `mutil-context-nl.md`.*

## Purpose

`mutil` is a CLI tool to manage **MuMu Player 12** Android emulators from the
terminal: list devices, start/stop them and connect/disconnect `adb`. It
replaces looking up ports by hand and running `adb connect` manually.

## Build approach (to recreate)

Follow these steps; the details are further down in this document.

1. **Environment**: write a POSIX shell script (`#!/bin/sh`) for Git Bash and
   use `powershell.exe` for Windows-specific queries (MuMuManager JSON,
   `netstat`, registry). `nc`/`ss` are absent, so avoid that approach.
2. **Core query `mumu_query`**: call `MuMuManager info -v all` once, parse the
   JSON in PowerShell and emit one line per instance:
   `INDEX<TAB>NAME<TAB>STATUS<TAB>ADDRESS`. See *Status* and *Port selection*.
3. **Find the manager (`find_manager`)**: env override `MUMU_MANAGER` → fixed
   paths → running MuMu process → uninstall registry (via `DisplayIcon` /
   `UninstallString`). Pass the path to PowerShell via `MUMU_MM`.
4. **List helpers**: `list_full` adds the adb-connection status (via
   `adb devices`); `list_instances` is a thin `awk` filter.
5. **Commands**: `devices` (show), `open`/`close` (start/stop and wait via
   `wait_state` + `device_online`/`device_stopped`), `connect`/`disconnect`
   (`adb` via `connect_row`, which starts an offline device first).
6. **Interaction**: numbered selection (`parse_choices`, commas + `A`=all), name
   filter (`filter_by_name`) and lenient `Y/N` prompts (`confirm_yes`).
7. **Robustness**: temp files via `mktemp` + `trap`, errors to stderr (`err`),
   PowerShell in a *quoted* heredoc (no injection).
8. **Wrapper + install**: `mutil.cmd` locates Git Bash and forwards args (works
   in cmd/PowerShell); put the folder on the Windows `PATH`.

## Environment

- **Git Bash / MSYS2** (MINGW64) on Windows. The script is a POSIX shell script
  (`#!/bin/sh`).
- Available: `adb`, `powershell.exe`, Windows `netstat`, `cygpath`, `mktemp`.
- **Not** available here: `nc`, `ss` (hence no netcat approach).
- **MuMu Player 12** with `MuMuManager.exe` (CLI for instance info and control).

## Files and locations

| Path | Role |
| --- | --- |
| `tools/cli/mutil/mutil` | The shell script (all logic). |
| `tools/cli/mutil/mutil.cmd` | Wrapper for cmd/PowerShell via Git Bash. |
| `tools/cli/mutil/readme.md` | User README (English). |
| `tools/cli/mutil/readme_nl.md` | User README (Dutch). |
| `tools/cli/mutil/mutil-context.md` | This build guide (English). |
| `tools/cli/mutil/mutil-context-nl.md` | Build guide (Dutch). |
| `tools/cli/mutil/terminal-profile.ps1` | Adds a Windows Terminal profile. |
| `C:\Sources\mutil\` | Install copy (`mutil` + `mutil.cmd`) on the PATH. |
| Desktop `mutil.lnk` | Pinnable shortcut (`cmd.exe /k mutil`). |

The repo folder was first named `muutil` and later renamed to `mutil`; the
duplicate folder was removed. After every change both files are copied to
`C:\Sources\mutil` (kept identical).

## Commands

The commands fall into two groups: managing MuMu Player instances (via
`MuMuManager`) versus managing `adb` connections. The help shows them grouped
this way.

**MuMu Player (instances):**

| Command | Purpose |
| --- | --- |
| `devices` | Show all instances with status and adb connection. |
| `open` | Start a stopped emulator (choice if several). |
| `close` | Stop a running emulator (choice if several). |

**adb (connections):**

| Command | Purpose |
| --- | --- |
| `connect` | Connect `adb`; start the device first if needed. |
| `disconnect` | Break an `adb` connection. |

`help` shows the help text.

With several candidates the tool shows a numbered list. Input can be a single
number, comma-separated numbers (`1,3,5`), or `A` (all listed).

For `open`, `close`, `connect` and `disconnect` you can optionally pass a name
(`mutil connect Dev`) to filter case-insensitively by name; with exactly one
match the action runs directly.

## How it works (architecture)

- **`mumu_query`** is the core: one PowerShell call that reads
  `MuMuManager info -v all` (JSON) and emits one line per instance:
  `INDEX<TAB>NAME<TAB>STATUS<TAB>ADDRESS`.
- **`list_full`** extends `mumu_query` with the adb-connection status per
  device; **`list_instances`** is a thin `awk` filter over `mumu_query`.
- **`find_manager`** locates `MuMuManager.exe` in order: env var `MUMU_MANAGER`,
  fixed install paths, running MuMu process, and the uninstall registry.
  `mumu_query` receives this path via the env var `MUMU_MM`.
- **`parse_choices`** validates the comma selection against the range.
- **`filter_by_name`** + optional name argument for `open`/`close`/`connect`/
  `disconnect` (e.g. `mutil connect Dev`): filters candidates by name
  (case-insensitive substring). With one match the action runs directly.
- **`ensure_mumu_running`** runs before each MuMu command: if MuMu Player is not
  running (`tasklist` check on `MuMuNxMain.exe`), it asks `(Y/N)` to start it.
  Any answer with a `y` (e.g. `y`, `yes`) starts `MuMuNxMain.exe`; anything else
  does not. After starting, `wait_mumu_running` waits (every 3s, 2 min timeout)
  until the app runs.
- **`open`/`close` wait** until the device is online resp. stopped (every 5s,
  2 min timeout) via `wait_state` with `device_online` / `device_stopped`.
  `open` uses `start_instance` (shared with `connect`), `close` uses
  `stop_instance`.
- **`connect`/`disconnect`** work on the full list (`list_full`) with status and
  adb status. Without a name, `connect` shows every device not yet connected via
  adb (online-not-connected and not-started). `connect_row` handles the per
  device logic: online → adb connect only; offline/booting → `start_instance`
  first (open behaviour: start + wait) and then adb connect.
- **`err`** sends error messages to stderr; **`new_ps_file`** creates a
  temporary `.ps1` file via `mktemp`; a `trap` cleans it up (also on Ctrl-C).

### Status

Per instance from MuMuManager:

- `online` = `is_android_started` and `is_process_started` (both true).
- `offline` = both false.
- `busy` = exactly one true (starting up or shutting down).

`open` only offers `offline`, `close` only `online`; `busy` therefore falls
outside both. `connect` on the other hand shows all devices not yet connected
via adb (regardless of status) and starts non-online devices first.

### Port selection (important)

MuMu exposes one instance on multiple `adb` ports (e.g. 5559, 7555 and 16448).
Only ports in the Android emulator range **5554-5585** are recognised by Visual
Studio and the Android SDK. The tool therefore picks that port (via the
listening ports of `headless_pid`) instead of the high `adb_port` that
MuMuManager reports by default. A device that is still starting (`busy`) shows
the high `adb_port` until the emulator port listens; `connect` re-fetches the
address once the device is online.

## Key findings

- Connecting on the high `adb_port` (e.g. 16448) worked with `adb`, but the
  device did not appear in Visual Studio; on the 555x port it did.
- MuMu's uninstall registry has an empty `InstallLocation`; the path is derived
  from `DisplayIcon` and `UninstallString` instead.
- `where bash` in cmd pointed to **WSL** (`System32\bash.exe`), which does not
  understand Windows paths. The wrapper therefore picks Git Bash explicitly.
- `Get-NetTCPConnection` was slow (~3.7s per call); replaced with `netstat -ano`.
  That brought `mutil devices` from ~4.5s down to ~1.4s.

## Applied best practices

- **`mutil.cmd`** follows the *Windows Batch Script Best Practices* skill
  (`.github/skills/cmd-script-guidelines.sql/SKILL.md`): documentation header,
  `setlocal EnableExtensions`, exit code `3` on a missing dependency,
  `ERROR:` prefix.
- **`mutil`** (POSIX sh): `sh -n`-clean, consistent quoting, PowerShell in a
  *quoted* heredoc (no injection), `printf` for data, error messages to stderr,
  temp files via `mktemp` + `trap`.

## Performance

- `mutil devices` ≈ 1.4s (or ~1.8s with a running device).
- The remaining time is mostly Windows PowerShell startup (~1s) plus
  `MuMuManager` (~0.4s) — one PowerShell call per command.

## Installation (short)

See `readme.md`. In short: copy `mutil` and `mutil.cmd` to a fixed folder (e.g.
`C:\Sources\mutil`) and put that **folder** on the Windows `PATH`. The wrapper
makes the commands work in cmd and PowerShell too. `adb` must be on `PATH`.

## Taskbar shortcut

A shell script or `.cmd` cannot be pinned to the taskbar directly; Windows only
pins shortcuts to an `.exe`. Hence there is a `mutil.lnk` shortcut on the desktop
targeting `cmd.exe /k mutil` with the MuMu icon. Right-click ->
*Pin to taskbar* to pin it (the target is `cmd.exe`, so pinning is allowed).
Adjust the target argument (e.g. `/k mutil connect`) for a fixed action.

## Windows Terminal profile

A profile `mutil` was added to Windows Terminal (`settings.json`, command
`cmd.exe /k mutil`). The script `terminal-profile.ps1` adds that profile
idempotently: it makes a backup, inserts it after `"list": [` and validates the
JSON. Open it via the dropdown or with `wt -p mutil`; for the taskbar pin a
shortcut to `wt.exe -p mutil`. The readme contains the full PowerShell command.

## Testing (how to verify changes)

- Syntax: `sh -n mutil`.
- README lint: `npx --yes markdownlint-cli readme.md`.
- Functional: start/stop an instance with
  `MuMuManager.exe control -v <index> launch|shutdown` and check
  `mutil devices` / `open` / `connect` / `disconnect`.
- Timing: `time sh mutil devices`.

## Possible next steps

Technical improvements:

- PowerShell startup (~1s) is the biggest remaining cost; `pwsh` (PowerShell 7)
  sometimes starts faster, but is not guaranteed to be present.
- Optionally use the `busy` status more in the UI/output.
- Detection edge cases: MuMu on a non-standard drive without a registry entry
  (the `MUMU_MANAGER` override is the solution then).

Feature ideas:

- `restart` command (`MuMuManager control -v <index> restart`).
- Interactive menu when `mutil` runs without an argument (now: help).
- `mutil shell [name]` / `mutil logcat [name]`: shortcuts to `adb shell` /
  `adb logcat` for a device.
- `mutil install <apk> [name]`: install an APK via `adb install`.
- Machine-readable output (`--json`) for scripting.
- Tab completion (bash + PowerShell) for commands and device names.
- Remembering the last used device as default.
