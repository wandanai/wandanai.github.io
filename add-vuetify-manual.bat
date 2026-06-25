@echo off
chcp 65001 >nul
set "PROJDIR=%~1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-vuetify-manual.ps1" -ProjDir "%PROJDIR%"
