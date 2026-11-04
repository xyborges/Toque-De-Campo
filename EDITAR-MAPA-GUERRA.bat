@echo off
set "GODOT=C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" exit /b 1
"%GODOT%" --editor --path "%~dp0" res://modes/war/scenes/map_additions.tscn
