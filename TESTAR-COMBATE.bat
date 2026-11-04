@echo off
set "GODOT_TEST_EXE=C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
pushd "%~dp0"
"%GODOT_TEST_EXE%" --headless --path . --script tests/combat_integration.gd --quit-after 1200 --log-file "%~dp0work\local-combat-test.log"
if errorlevel 1 goto failure
"%GODOT_TEST_EXE%" --headless --path . --script tests/melee_offline_integration.gd --quit-after 6000 --log-file "%~dp0work\melee-offline-tests.log"
if errorlevel 1 goto failure
python tests/run_melee_network.py
if errorlevel 1 goto failure
"%GODOT_TEST_EXE%" --headless --path . --script tests/ragdoll_stability.gd --quit-after 2400 --log-file "%~dp0work\ragdoll-stability.log"
if errorlevel 1 goto failure
python tests/run_network_tests.py
if errorlevel 1 goto failure
"%GODOT_TEST_EXE%" --path . --script tests/ui_integration.gd --screen 0 --resolution 960x640 --position 20,20 --quit-after 900 --log-file "%~dp0work\ui-integration.log"
if errorlevel 1 goto failure
popd
exit /b 0
:failure
popd
exit /b 1
