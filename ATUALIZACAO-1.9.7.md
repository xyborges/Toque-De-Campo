# 1.9.7 — Ajustes de vídeo

Publicada no servidor Ubuntu como build 70 em 27/10/2026.

- Configurações → Vídeo oferece antisserrilhamento Desligado, MSAA 2×, 4× e 8×. O padrão para uma instalação sem preferência anterior é desligado; os presets gráficos podem mudar esse valor.
- Preferências de vídeo, sensibilidade por equipamento, áudio, atalhos e câmeras são armazenadas por conta no servidor, com cache local separado por conta fora das pastas de versões instaladas. A sincronização ocorre após autenticação e ao salvar alterações.
- Se uma gravação não for concluída, a alteração permanece pendente para outra tentativa.
- Blindados retornam após 15 segundos, com suspensão reiniciada e espaço livre na base; quando a área estiver completamente obstruída, o retorno aguarda até haver espaço.
- As laterais das trincheiras centrais foram suavizadas para permitir que blindados saiam dirigindo, preservando a cobertura do fundo.

## Verificações

- `tests/antialias197.gd`: painel de vídeo, padrão desligado, aplicação do MSAA 4× no renderizador, persistência após recarregar e persistência da sensibilidade normal e com mira.
- `tests/account_preferences197.gd`: sincronização por conta, isolamento no mesmo computador, retorno após falha de rede e rejeição de respostas antigas. `tests/account_authority.py`: autenticação, isolamento entre usuários, validação de conteúdo e mesclagem por categoria na API real com banco isolado.
- `tests/vehicle_spawn197.gd`: nascimento, colisão no ponto de retorno, temporizador e observador remoto. `tests/trench_vehicle.gd`: saída de quatro blindados em marcha à frente e ré nas simulações offline e de autoridade online.
