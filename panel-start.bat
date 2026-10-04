@echo off
rem Repo-root launcher for the Lunar Base panel (sibling of server\).
rem The implementation lives in panel\start.bat, which is layout-agnostic and
rem auto-initializes on first run. Extra args are forwarded (e.g. --auth).
setlocal
call "%~dp0panel\start.bat" %*
endlocal
