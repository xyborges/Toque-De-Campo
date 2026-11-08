# Dashboard unificado das partidas — 08/11/2026

## Objetivo

Substituir as barras e os indicadores dispersos do topo por um componente de dados da partida, compartilhado entre todos os modos. **Não altera tickets, capturas, pontuações, RPCs, cronômetros nem regras de jogo.**

## Referências pesquisadas

- Battlefield Conquest: organização visual de equipes, tickets, tempo e objetivos.
- Squad: estados de setores, contestação e objetivo ativo.
- Princípios de HUD: dados relevantes e frequentes, pouco texto e área central da imagem livre.
- Fontes públicas: https://www.pcgamer.com/battlefield-2042-new-scoreboard/ ; https://squad.fandom.com/wiki/Control_Point ; https://unity.com/blog/video-game-ui-ux-basics

## Implementação

Fonte única do desenho: `scripts/ui/match_dashboard.gd` (`GameMatchDashboard`). Paleta do login (`FieldTheme`), sem novas cores arbitrárias de facção. Painel de **620 × 142 px**, com hierarquia fixa em todos os modos:

| Modo | Números | Estado inferior |
| --- | --- | --- |
| Guerra Ucrânia/Afeganistão | Equipes 0/1, tickets e tempo restante | Objetivos realmente ativos, posse, disputa e porcentagem de captura |
| Guerra Favela | Mesmos valores e formato | Setores A–E, alvo da linha de frente e progresso real de captura |
| Battle Royale | Sobreviventes, total, abates e relógio da zona | Próxima zona, fechando, aguardando ou encerrada |
| Naval | Comandantes e tipo de embarcação | Combate naval (sem cronômetro fictício) |
| Treino/PVP base | Jogadores, abates e tempo | Situação da partida e objetivo quando fornecido |

Na Guerra a equipe 0 fica sempre à esquerda, a equipe 1 à direita, sem trocar de posição após respawn. O time local é marcado discretamente. Todas as atualizações leem apenas dados existentes/sincronizados.

## Limpeza e compatibilidade

- Removidos `modes/war/scripts/objective_bar.gd` e `.uid`; todas as chamadas conhecidas foram migradas.
- Removidos cabeçalhos redundantes do Battle Royale e Naval; widgets e testes do BR adaptados.
- Alertas de combate e zona deslocados para não ocultar o dashboard.
- Os HUDs de saúde, munição, minimapa, tela de resultados e scoreboard detalhado continuam intactos.
- UIDs do novo componente e teste foram geradas pelo Godot, sem modificação de assets do jogo.

## Resultados do QA (Godot 4.7.2 Windows)

Máquina: DESKTOP-JJ7U3G3, renderer **headless**, sem benchmark gráfico ou coleta de FPS. Import inicial da worktree pelo editor finalizado com exit 0.

- **PASS — 11/11:** `tests/match_dashboard_qa.gd`, exit 0, incluindo Guerra 3 setores, Favela 5, contestação, capturador, tempo, tickets, Battle Royale, Naval e arena.
- **PASS parcial — 17/19:** `tests/war163_hud_projection.gd`, projeção de marcadores com **erro máximo de 0 px** nas resoluções 1024×768 e 1920×1080. Duas falhas em textos/estados da tela de implantação e respawn, fora do caminho visual alterado. Não declarar aprovação integral.
- **FAIL já reproduzido no original — 37/41:** `tests/br_ui_validation.gd`. As mesmas 4 falhas no **checkout da main original**: exibição de resultado de vitória, detalhe de precisão/arma, causa de eliminação e limite do pool de loot. O assert migrado do novo relógio passou. O original apresentou também erros de cache de classes; nenhum deles surgiu na worktree importada.
- **PASS:** `git diff --check`; referências anteriores `objective_bar`, `zone_text` e `hud.top` ausentes dos scripts.

## Riscos e pendências

A renderização com janela real em 720p e 1080p, observação manual de sobreposição e desempenho na GTX 1650 ainda não foram medidos. As duas falhas de implantação da suíte Guerra não foram comparadas diretamente com baseline em Godot importado, mas o código de implantação não foi modificado. Não interpretar teste headless como teste de GPU ou release do jogo.

Branch de implementação: `ia/jj7u3g3-match-dashboard-20261108`; base inicial: `origin/main` 109410a. O estado definitivo de merge e do PR deve ser consultado no GitHub.
