@echo off
rem Abre el tracker de la camara y despues el juego.
setlocal enabledelayedexpansion
cd /d "%~dp0"

call "%~dp0_find-godot.bat" || exit /b 1

rem Entorno de Python: primero el del repo, despues el de la carpeta de arriba.
set "PY=python"
if exist "%~dp0..\.venv\Scripts\python.exe" set "PY=%~dp0..\.venv\Scripts\python.exe"
if exist "%~dp0.venv\Scripts\python.exe" set "PY=%~dp0.venv\Scripts\python.exe"

"%PY%" -c "import mediapipe" >nul 2>nul
if errorlevel 1 (
    echo Falta Python o la libreria mediapipe.
    echo.
    echo Crea el entorno una sola vez, desde esta carpeta:
    echo     python -m venv .venv
    echo     .venv\Scripts\pip install -r tracker\requirements.txt
    echo.
    pause
    exit /b 1
)

echo Tracker en marcha. El juego abre en unos segundos...
start "CHILI - tracker" "%PY%" "tracker\tracker.py"
"%GODOT%" --path game
