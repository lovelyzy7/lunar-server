@echo off
rem Server one-click start (repo root, sibling of server\).
rem Runs the original interactive wizard unchanged; extra args are forwarded
rem (e.g. --prefer-saved, --grpc-port 9003, --setup-only).
setlocal
cd /d "%~dp0"

if not exist "server\cmd\wizard\main.go" (
    echo server\cmd\wizard not found. Is the game server checked out under server\?
    exit /b 1
)

where go >nul 2>&1
if errorlevel 1 (
    echo.
    echo Go 1.25+ not found on PATH. Install Go, then run server-start.bat again.
    exit /b 1
)

cd server
go run .\cmd\wizard %*
endlocal
