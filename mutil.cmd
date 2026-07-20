@echo off
rem =====================================================================
rem  mutil.cmd - launcher for the "mutil" MuMu Player utility
rem
rem  Purpose:      Run the POSIX "mutil" shell script from cmd or
rem                PowerShell by locating Git Bash and forwarding all
rem                arguments to it.
rem  Usage:        mutil <command> [args...]
rem  Arguments:    Passed through unchanged to the mutil shell script.
rem  Requirements: Git for Windows (Git Bash). adb on PATH is required
rem                by the connect/disconnect commands.
rem  Exit codes:   0  success
rem                3  Git Bash not found (missing dependency)
rem                *  otherwise the exit code of the mutil script
rem =====================================================================

setlocal EnableExtensions

rem Locate Git Bash: prefer the standard install locations, then fall
rem back to deriving it from the git.exe that is on PATH.
set "BASH="
if exist "%ProgramFiles%\Git\bin\bash.exe" set "BASH=%ProgramFiles%\Git\bin\bash.exe"
if not defined BASH if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" set "BASH=%ProgramFiles(x86)%\Git\bin\bash.exe"
if not defined BASH if exist "%LocalAppData%\Programs\Git\bin\bash.exe" set "BASH=%LocalAppData%\Programs\Git\bin\bash.exe"

if not defined BASH (
    for /f "delims=" %%G in ('where git 2^>nul') do (
        if not defined BASH for %%R in ("%%~dpG..") do if exist "%%~fR\bin\bash.exe" set "BASH=%%~fR\bin\bash.exe"
    )
)

if not defined BASH (
    echo ERROR: Git Bash not found. Install Git for Windows ^(https://git-scm.com^).
    exit /b 3
)

rem Forward every argument to the mutil script located next to this wrapper.
"%BASH%" "%~dp0mutil" %*
exit /b %errorlevel%
