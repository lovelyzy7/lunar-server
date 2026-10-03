@echo off
rem One-click launcher for the Lunar Tear server (Windows).
rem
rem This preserves the original interactive wizard: it validates assets, runs
rem database migrations, builds the service binaries (auth + CDN + game server)
rem and launches them together. Extra arguments are forwarded to the wizard,
rem e.g. Start.bat --prefer-saved         (reuse the saved config)
rem      Start.bat --grpc-port 9003      (custom ports)
rem      Start.bat --setup-only          (patching instructions, no launch)
setlocal
cd /d "%~dp0"

where go >nul 2>&1
if errorlevel 1 (
    echo.
    echo Go 1.25+ not found on PATH. Install Go, then run Start.bat again.
    exit /b 1
)

go run .\cmd\wizard %*
endlocal
