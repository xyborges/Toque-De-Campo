@echo off
set "GRASS_GODOT=C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
if not exist "%GRASS_GODOT%" (
  echo Godot nao encontrado.
  pause
  exit /b 1
)
"%GRASS_GODOT%" --path "%~dp0" --rendering-method gl_compatibility --screen 0 --log-file "%~dp0work\nova-play-preview.log" res://tests/nova_grass_play.tscn -- --vegetation-level=2
