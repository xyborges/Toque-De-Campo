@echo off
cd /d "%~dp0"
python distribution\ubuntu\publish_ubuntu.py %*
if errorlevel 1 (
  echo Falha ao publicar. A versao anterior continua no servidor.
  pause
  exit /b 1
)
echo.
echo Atualizacao disponivel para quem abrir o launcher.
pause
