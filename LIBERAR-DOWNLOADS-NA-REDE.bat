@echo off
echo Clique neste BAT com o botao direito e escolha Executar como administrador.
powershell.exe -NoProfile -File "%~dp0distribution\liberar-downloads-lan.ps1"
if errorlevel 1 echo Nao foi possivel ajustar a regra. Execute como administrador e confira a mensagem acima.
pause
