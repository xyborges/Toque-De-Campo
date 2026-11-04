@echo off
cd /d "%~dp0"
echo Downloads: http://192.168.101.227:8088
echo Mantenha esta janela aberta para servir os downloads.
python distribution\update_server.py
if errorlevel 1 (
  echo Nao foi possivel iniciar o servidor. Confira a porta 8088.
  pause
  exit /b 1
)
pause
