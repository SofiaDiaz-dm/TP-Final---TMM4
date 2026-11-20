@echo off
rem Abre solo el editor de Godot en este proyecto.
setlocal enabledelayedexpansion
cd /d "%~dp0"

call "%~dp0_find-godot.bat" || exit /b 1

"%GODOT%" --editor --path game
