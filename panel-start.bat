@echo off
rem Lunar Base panel one-click start (repo root, sibling of server\).
rem Windows counterpart of panel-start.sh. Auto-runs panel\setup.bat on first
rem run / when the venv, master data or grant shim is missing.
setlocal
cd /d "%~dp0"

if not exist "panel\web\app.py" (
    echo panel\web\app.py not found. Is the Lunar Base panel checked out under panel\?
    exit /b 1
)

set "NEED_SETUP=0"
if not exist "panel\.venv\Scripts\python.exe" set "NEED_SETUP=1"
if not exist "panel\tools\grant\grant.exe" set "NEED_SETUP=1"
if not exist "panel\data\masterdata\*.json" set "NEED_SETUP=1"
if "%NEED_SETUP%"=="1" (
    echo Panel is not fully initialized -- running panel\setup.bat first ...
    call "panel\setup.bat"
    if errorlevel 1 exit /b 1
)

call "panel\.venv\Scripts\activate.bat"
pushd "panel"
python -m web %*
popd
endlocal
