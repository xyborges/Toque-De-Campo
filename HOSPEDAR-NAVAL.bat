@echo off
pushd "%~dp0"
echo TOQUE DE CAMPO - SERVIDOR NAVAL FIXO OPCIONAL
echo Para partidas comuns, basta criar a sala dentro do jogo.
echo No jogo: Modo Naval - conectar a 192.168.101.227
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0distribution\start-naval-server.ps1" %*
set "NAVAL_EXIT_CODE=%ERRORLEVEL%"
popd
pause
exit /b %NAVAL_EXIT_CODE%
