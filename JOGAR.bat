@echo off
set "GODOT=C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" (
  echo Godot nao encontrado em:
  echo %GODOT%
  pause
  exit /b 1
)
"%GODOT%" --path "%~dp0" --log-file "%~dp0godot.log"
