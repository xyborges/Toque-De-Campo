@echo off
set "GODOT=C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" exit /b 1
"%GODOT%" --path "%~dp0" --screen 0 --resolution 1440x900 --position 20,20 res://editor/war/biblioteca.tscn
