@echo off
rem Builds Pyrelink (Moonlight for Android, restyled for Pyrelark) and installs it on your phone.
rem   Build Pyrelink.bat -Update     start again from the newest Moonlight source
rem   Build Pyrelink.bat -NoInstall  build only
rem   Build Pyrelink.bat -Bundle     also make Pyrelink.aab for Google Play
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "tools\build.ps1" %*
echo.
pause
