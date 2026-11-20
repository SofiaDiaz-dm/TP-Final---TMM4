@echo off
rem Busca un ejecutable de Godot y lo deja en la variable GODOT.
rem Orden: variable de entorno, PATH, carpeta estandar de instalacion, tools\ local.
setlocal enabledelayedexpansion

if defined GODOT (
    if exist "!GODOT!" exit /b 0
)
set "GODOT="

where godot >nul 2>nul && set "GODOT=godot"
if not defined GODOT (
    for %%d in ("%LOCALAPPDATA%\Programs\Godot" "%~dp0tools") do (
        for %%f in ("%%~d\Godot_v*_win64.exe") do set "GODOT=%%~ff"
    )
)

if not defined GODOT (
    echo No encuentro Godot.
    echo.
    echo Instalalo desde https://godotengine.org/download/windows
    echo o deja el ejecutable en: %LOCALAPPDATA%\Programs\Godot
    echo.
    pause
    exit /b 1
)

endlocal & set "GODOT=%GODOT%"
exit /b 0
