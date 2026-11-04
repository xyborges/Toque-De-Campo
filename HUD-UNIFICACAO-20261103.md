# Unificação HUD e menus — 03/11/2026 (primeiro lote)

## Escopo
Intervenção exclusivamente na interface de usuário do Godot. Não foram alterados áudio, mapas, física, renderização, bot, autoridade de rede ou dados de conta.

## Alterações implementadas
- `scripts/ui/ui_kit.gd`: botão MENU compartilhado entre os três HUDs principais, com mesmo texto e posição.
- `scripts/ui/infantry_hud.gd`: método `apply_layout_variant("war")`, responsável pelo posicionamento visual da infantaria no modo Guerra.
- `modes/war/scripts/ui.gd`: delega o posicionamento ao HUD compartilhado, em vez de alterar diretamente múltiplos nós internos.
- `scripts/ui/naval_hud.gd` e `modes/battle_royale/ui/hud.gd`: uso do novo botão compartilhado.
- `scripts/ui/main_menu.gd`: seção de configurações com seis atalhos (Vídeo, Áudio, Controles, Jogabilidade, Interface e Naval), diretamente para as abas do painel existente.
- `modes/battle_royale/ui/inventory_panel.gd`: ScrollContainer horizontal para permitir acesso às colunas de inventário em telas estreitas.
- `scripts/ui/pause_menu.gd`: título `MENU DA PARTIDA` e estado contextual (online: a partida continua; offline: partida pausada).

## Validação
- Godot 4.7.2 no laboratório isolado `C:\Users\Joao Borges\Documents\campo-ui-lab-20261103`.
- Importação de recursos no laboratório: concluída (exit 0).
- Carregamento dos 8 scripts relevantes: aprovado.
- Navegação nas seis abas de configurações: 6/6 aprovadas.
- Alocação do layout da Guerra: aprovada.
- Container horizontal do inventário BR: aprovado.
- Estado contextual online/offline do menu de partida: aprovado.
- Teste automatizado: `tests/ui_unification_20261103.gd`.
- Teste antigo `tests/ui_integration.gd` não concluiu em modo headless no laboratório; encerrada apenas essa instância de teste. Portanto, o pacote de regressões abrangente **ainda está pendente**.

## Segurança e coordenação
Cópias pré-alteração dos oito scripts em `work/hud-unification-20261103/backup/`. O primeiro conjunto de sete arquivos também consta de `work/hud-unification-20261103/manifest.json`. A modificação de `pause_menu.gd` foi feita em seguida, com backup próprio. Não sobrescrever modificações de outros trabalhos sem comparar versões recentes.

## Próxima fase
1. Consolidar navegação principal/Naval e estados de modais, sem modificar as mecânicas.
2. Componentizar notificações, marcadores e indicadores de recursos, evitando mudanças de nós internos entre modos.
3. Testar responsividade em 800x600, 1280x800 e 1920x1080 com capturas **atuais**.
4. Rodar testes interativos de ESC, teclado, mouse, pausa, lobby, respawn, morte, reconexão e retorno ao menu.
5. Evoluir telas e transições respeitando `DIRETRIZES-INTERFACE.md` e a paleta do login.

## Fase 2 — navegação padronizada (03/11/2026)

**Implementado em 8 arquivos**, com backup pré-alteração em `work/hud-navigation-20261103/backup/` e inventário SHA-256 em `work/hud-navigation-20261103/manifest.json`.

- `scripts/ui_focus.gd`: `open_root()` abre uma tela principal sem histórico acidental; `open_route()` limita a navegação a origem + destino; `back()` respeita callbacks próprios e painéis com ESC bloqueado.
- `modes/naval/scripts/mode.gd`: páginas de Salas/Frota/Loja/Lobby usam navegação de tela, enquanto Configurações e Pausa continuam modais; o retorno das Configurações restaura Naval Home sem sair do modo.
- `scripts/ui/settings_panel.gd`: voltar pelo ESC usa o mesmo `leave()` do botão e a confirmação de vídeo usa `_revert_video()`.
- `scripts/ui/pause_menu.gd`: mesmo tratamento de ESC que o botão Continuar; novo `confirm_leave()` centraliza saída.
- `scripts/main.gd`: ESC encaminha para `GameUIFocus.back()`, preservando exceções de carregamento e implantação.
- `scripts/ui/menu_page.gd`: o link para o menu principal no Naval solicita confirmação quando há partida ativa.
- `modes/war/scripts/ui.gd`: implantação usa a confirmação de saída compartilhada; tela de resultado final não some com ESC.
- `modes/battle_royale/ui/hud.gd`: saída da espera usa confirmação compartilhada quando disponível; resultado final não some com ESC.

**Testes executados no laboratório isolado:** `tests/ui_navigation_phase2.gd` — 11 testes passaram; `tests/br_navigation_phase2.gd` — 4 testes passaram; `tests/ui_unification_20261103.gd` — 6/6 abas e demais verificações passaram. Os arquivos fonte dos testes direcionados estão salvos em `tests/`.

**Regressão conhecida:** `tests/br_ui_validation.gd` registrou 3 falhas (visibilidade imediata de inventário ao fechar e orçamento visual de loot). Repetido com o HUD anterior desta fase: exatamente as mesmas três falhas. O teste antigo `tests/war_menu.gd` permaneceu rodando sem relatório no modo headless do laboratório e foi encerrado somente ali; testes completos de campanha/multiplayer não foram executados.

**Segurança:** nenhum mapa, áudio, física, rede ou configuração de renderização foi alterado. A integração foi feita em uma cópia Godot 4.7.2 fora da pasta principal.

**Próxima etapa:** revisão de comportamentos de pausa e resultados em sessões reais, fluxo Naval de lobby/saída de sala e teste visual em diferentes resoluções.

## Fase 3 — regressão ampliada (03/11/2026)
- **Novas correções de UI:** fechamento imediato do inventário BR e retorno ao menu de origem dos atalhos diretos da Loja/Configurações Naval.
- **Testes com renderização real:** placar **54/54**, menu Guerra **17/17**, fluxo UI atual **34/34**.
- **Multiplayer Naval local com DTLS temporário:** **14/14** (lobby, partida, morte, respawn e saída); clientes de teste simplificados ainda geram avisos de RPC de voz.
- **Seis suítes de regressão de UI:** **6/6** aprovadas. Teste antigo Guerra reparado (`open_war` passou de um para dois argumentos).
- **Pendências:** `war_class_hud.gd` tem 27 falhas **idênticas ao HUD anterior à unificação**, e `br_ui_validation.gd` tem 1 falha preexistente de orçamento de loot. Não considerar essas áreas aprovadas até investigação. Também faltam executáveis reais de 2 clientes em Guerra/BR e fullscreen nativo.
- **Relatório técnico completo:** `HUD-TESTES-REGRESSAO-20261103.md`. Backups das alterações em `work/hud-regression-fixes-20261103/backup/`.
