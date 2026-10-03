@echo off
rem Lunar Base panel setup (lives in panel\, sibling of server\).
rem CLI counterpart of the /settings INITIALIZATION section; safe to re-run.
setlocal
cd /d "%~dp0"
set "PANEL=%~dp0"
for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "SERVER=%ROOT%\server"

if not exist "%PANEL%\web\app.py" (
    echo panel\web\app.py not found under %PANEL%.
    echo Is the Lunar Base panel checked out in the panel\ directory?
    exit /b 1
)

echo.
echo === Lunar Base panel setup ===
echo.

if not exist "%PANEL%\.venv" (
    echo Creating virtual environment in panel\.venv ...
    py -m venv "%PANEL%\.venv"
    if not exist "%PANEL%\.venv\Scripts\python.exe" python -m venv "%PANEL%\.venv"
    if not exist "%PANEL%\.venv\Scripts\python.exe" (
        echo Failed to create virtual environment. Make sure Python 3.10+ is installed.
        exit /b 1
    )
) else (
    echo Virtual environment already exists.
)

call "%PANEL%\.venv\Scripts\activate.bat"

echo Installing / updating app dependencies ...
python -m pip install --upgrade pip
python -m pip install -r "%PANEL%\web\requirements.txt"
if errorlevel 1 (
    echo Dependency install failed. Check the messages above.
    exit /b 1
)

echo.
echo === Master data ===
echo.

if exist "%PANEL%\data\masterdata\*.json" (
    echo Master data already dumped at panel\data\masterdata\ -- skipping.
    goto :names_section
)

rem Bundled copy of lunar-scripts (dump_masterdata.py + schemas.json).
set "MD_SCRIPT=%PANEL%\scripts\dump_masterdata.py"
set "MD_INPUT=%SERVER%\assets\release\20240404193219.bin.e"

if not exist "%MD_SCRIPT%" (
    echo Skipping master-data dump: %MD_SCRIPT% not found.
    echo Write features need the dump. Re-run setup.bat once scripts\ is restored.
    goto :names_section
)

if not exist "%MD_INPUT%" (
    echo Skipping master-data dump: master data binary not found at:
    echo   %MD_INPUT%
    echo Populate server\assets\ first, then re-run setup.bat.
    goto :names_section
)

echo Installing master-data dump dependencies (one-time, into panel\.venv) ...
python -m pip install pycryptodome msgpack lz4
if errorlevel 1 (
    echo Failed to install dump dependencies. Setup will continue without master data.
    goto :names_section
)

echo.
echo Dumping master data to panel\data\masterdata\ ...
python -X utf8 "%MD_SCRIPT%" --input "%MD_INPUT%" --output "%PANEL%\data\masterdata"
if errorlevel 1 (
    echo Master data dump failed. Setup will continue.
)

:names_section
echo.
echo === Names extraction ===
echo.

if exist "%PANEL%\data\names\*.json" (
    echo Names already extracted at panel\data\names\ -- skipping.
    goto :shim_section
)

if not exist "%PANEL%\data\masterdata\*.json" (
    echo Skipping names extraction: master data dump is missing or empty.
    echo Re-run setup.bat after the master-data dump succeeds.
    goto :shim_section
)

set "REVISIONS_DIR=%SERVER%\assets\revisions"
if not exist "%REVISIONS_DIR%\" (
    echo Skipping names extraction: game-server revisions tree not found at:
    echo   %REVISIONS_DIR%
    echo The panel will fall back to raw IDs without display names.
    goto :shim_section
)

echo Extracting English names from text bundles ...
python "%PANEL%\tools\extract_names.py" --revisions-dir "%REVISIONS_DIR%"
if errorlevel 1 (
    echo Names extraction failed. Setup will continue.
)

:shim_section
echo.
echo === Grant shim build ===
echo.

where go >nul 2>&1
if errorlevel 1 (
    echo Go is not on PATH. Skipping grant shim build.
    echo All write operations need Go ^(1.25+^). Install it and re-run setup.bat.
    goto :patch_deps_section
)

if not exist "%SERVER%\go.mod" (
    echo Skipping shim build: game server not found at %SERVER%\
    echo Re-run setup.bat once server\ is in place.
    goto :patch_deps_section
)

if not exist "%PANEL%\tools\grant\src\main.go" (
    echo Skipping shim build: panel\tools\grant\src\main.go missing.
    goto :patch_deps_section
)

echo Copying shim sources into server\cmd\lunar-base-grant\ ...
if not exist "%SERVER%\cmd\lunar-base-grant\" mkdir "%SERVER%\cmd\lunar-base-grant"
copy /Y "%PANEL%\tools\grant\src\*.go" "%SERVER%\cmd\lunar-base-grant\" >nul
if errorlevel 1 (
    echo Failed to copy shim sources. Write operations will not work.
    goto :patch_deps_section
)

echo Building panel\tools\grant\grant.exe ...
pushd "%SERVER%"
go build -o "%PANEL%\tools\grant\grant.exe" .\cmd\lunar-base-grant\
set "BUILD_RC=%errorlevel%"
popd

if not "%BUILD_RC%"=="0" (
    echo grant.exe build failed ^(exit code %BUILD_RC%^). Write operations will not work.
    echo Check that server\ compiles cleanly: cd server ^&^& go build .\...
    goto :patch_deps_section
)
echo Built: panel\tools\grant\grant.exe

:patch_deps_section
echo.
echo === Patch dependencies ===
echo.
call "%PANEL%patch-deps.bat"
if errorlevel 1 (
    echo Patch dependency install failed or was incomplete. Setup will continue.
)

echo.
echo Setup complete. Start the panel with panel-start.bat from the repo root.
endlocal
