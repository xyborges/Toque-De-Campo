# Relatório de regressão — HUD / navegação — 03/11/2026

## Escopo
Auditoria funcional e correções limitadas à interface do Toque de Campo (Godot 4.7.2). Execução em `C:\Users\Joao Borges\Documents\campo-ui-lab-20261103`, com nome de projeto distinto e preferências de teste isoladas. Os processos de simulação/otimização do projeto principal não foram encerrados. Não foram modificados áudio, física, mapas, bots ou renderizadores.

## Correções realizadas nesta rodada
1. `scripts/ui_focus.gd` + `modes/battle_royale/ui/inventory_panel.gd`: fechamento instantâneo do painel de inventário (preserva sistema de animação dos outros modais). Corrigiu as falhas "Tab cannot open inventory over settings/pause" e "dead player cannot reopen inventory" do teste BR.
2. `modes/naval/scripts/mode.gd` + `scripts/ui/settings_panel.gd`: preservar a origem dos atalhos diretos Loja/Frota/Configurações a partir do menu principal; ao navegar para outra página naval, adotar navegação interna.
3. `tests/war_menu_fixture.gd`: atualizar assinatura de `open_war(offline, operation)` à atual assinatura do jogo, removendo erro de parse que impedia os testes Guerra.
4. `tests/deployment170_naval_ui.gd`: atualizar expectativa de 4 para 5 abas do Naval (Vídeo, Áudio, Controles, Interface, Naval; sem Jogabilidade) e não tentar salvar capturas em headless.

Backup pré-alteração disponível em `work/hud-regression-fixes-20261103/backup/`.

## Testes que passaram
| Teste | Resultado | O que verificou |
|---|---|---|
| `tests/ui_modern_flow_regression.gd` (GUI) | **34/34** | Seleção de todos os modos, 6 configurações, implantar no Offline, HUD, pausa, voltar |
| `tests/scoreboard_visual.gd` (GUI) | **54/54** | TAB, captura do mouse, ranking, 1–12 jogadores, 1024×768 / 1280×720 / 1920×1080 |
| `tests/war_menu.gd` (GUI) | **17/17** | Guerra online/offline, menus, alcance de botões e 3 resoluções |
| `tests/war_menu_navigation_quick.gd` | **9/9** | Roteamento online/offline e troca de modo sem iniciar o mapa |
| `tests/naval_launcher_regression.gd` | **9/9** | Voltar à Loja/Configurações de origem e trocar rota interna |
| `tests/deployment170_naval_ui.gd` (3 clientes LAN, DTLS de teste) | **14/14** | Autenticação, lobby, prontidão, combate, morte, respawn, saída |
| `tests/ui_unification_20261103.gd`, `tests/ui_navigation_phase2.gd`, `tests/br_navigation_phase2.gd`, `tests/br_inventory_modular_ui_validation.gd`, `tests/preparation_menu_validation.gd`, `tests/naval_launcher_regression.gd` | **6 suítes / 6 aprovadas** | Regressão final de rotas, inventário, preparação e configurações |

A execução gráfica do placar produziu 14 capturas em `work/scoreboard-*.png` do laboratório. O novo teste visual produziu `work/ui-regression-deep/modern-*.png`.

## Pendências (NÃO estão aprovadas)
- `tests/br_ui_validation.gd`: **40/41**; falha em orçamento de objetos de loot visuais. Antes da correção eram 3 falhas; as duas de inventário foram resolvidas. O problema restante antecede este lote e pertence à otimização/renderização.
- `tests/war_class_hud.gd`: **23/50**; 27 falhas envolvendo classes e recursos. Repetido com os scripts de HUD **anteriores à unificação**, mostrou exatamente as mesmas 27 falhas. Pode haver teste desatualizado **ou** falha real nas regras/HUD; exige investigação própria, não foi corrigido.
- `tests/deployment170_ui.gd` antigo: **20/30** em headless. Suas expectativas antigas de cinco categorias e verificações gráficas de fullscreen, qualidade e mouse não são válidas nesta execução. O fluxo funcional de implantação, morte e respawn passou; a prova gráfica nova de ponta a ponta passou 34/34. As configurações nativas de janela ainda pedem QA gráfico específico.
- `tests/ui_standardization.gd` legado: falhou e atingiu o limite de execução porque tenta clicar na estrutura antiga de cartões do menu e pressupõe que o Offline cria ator antes da implantação. Substituído por `ui_modern_flow_regression.gd`; não usar o legado como bloqueador sem atualizar suas premissas.
- Durante o teste Naval com clientes simplificados houve mensagens RPC sobre `VoiceContext/ProximityVoice` ausente nesses clientes. O cenário de partida passou 14/14, mas a voz requer teste com clientes completos. Não modificar sons/voz aqui.

## Ainda necessário antes do lançamento
1. Testes reais **com dois executáveis clientes** para Guerra e Battle Royale (entrar, morrer, respawn, desconectar e reentrar), incluindo cliente com conexão instável.
2. Atualização/diagnóstico da suíte de classes Guerra e do orçamento de loot BR pela equipe responsável pelas mecânicas/otimizações.
3. Teste manual/gráfico de fullscreen, resolução e reversão de vídeo em diferentes telas, sem alterar preferências do usuário durante os testes automáticos.
4. Teste de voz com clientes completos, não só clientes `NavalNetwork` simplificados.
5. Reexecutar o gate de UI após qualquer merge de outros trabalhos; não concluir que o jogo inteiro está aprovado apenas porque a UI passa.

## Repetibilidade
Testes novos sob `tests/`: `ui_modern_flow_regression.gd`, `naval_launcher_regression.gd`, `war_menu_navigation_quick.gd`. Para simular rede naval usar `--naval-test-accounts`, `--naval-data=<pasta de testes>`, certificado/CA temporários, e nunca certificados de produção. Relatórios e logs completos desta sessão: `C:\Users\Joao Borges\Documents\campo-ui-lab-20261103\work\ui-regression-deep\`.

## Rodada complementar — 03/11/2026 (Guerra, BR e rede)

### Diagnósticos concluídos
- `tests/war_class_hud_current.gd`: **52/52 aprovado** no Godot 4.7.2, em laboratório. A suíte antiga (`war_class_hud.gd`) tinha 27 falhas por premissas antigas: armas de equipe, cura via `med_hold`, kit médico, binóculos/zoom, nome de lançador Javelin. O novo teste preserva o original, executa as mecânicas de hoje e valida valores reais do HUD. Nenhuma regra de combate foi alterada.
- `tests/br_loot_budget_current.gd`: **8/8 aprovado**. A regra vigente do loot preserva todos os objetos até 3m para permitir coleta e limita a 96 os mais distantes; não significa que o sistema perdeu o limite de otimização. Nenhum código de renderização alterado.
- `tests/br_ui_validation_current.gd`: **41/41 aprovado**, com expectativa do orçamento de loot atual. O teste original ficou intacto.
- PvP Deserto com **três processos Godot independentes e DTLS local**, 1 servidor + 2 clientes, usando `tests/deployment170_network.gd`: **20/20 aprovado** (servidor 12, alpha 5, bravo 3), sem erros de engine. Cobriu implantação, validação autoritativa de loadout, pausa online durante dano, morte, respawn e limpeza de partida.
- Teste mínimo ENet/DTLS do BR com um cliente + servidor em laboratório: **aprovado**, servidor e cliente conectados e chave de transporte aceitas.

### Pendências importantes — NÃO LIBERAR COMO APROVADAS
- **Guerra multi-processo com mapa completo**: teste `war_respawn181_network.gd` com servidor, hero e enemy não completou entrada; cliente aguardou `client deployed` e servidor `two ENet clients join`; finalizou por timeout. Isso não prova bug na UI, porém NÃO prova funcionamento multiplayer. O notebook/CPU do laboratório pode interferir na inicialização; diagnóstico exige medições da fase de carga e admissão antes de mudar código.
- **BR fila online ENet** `br_queue_network.gd`: versão atual compilou após sincronizar apenas para o laboratório os scripts recentes `afghan_density_stage2.gd` e `afghan_density_stage3.gd` (já presentes no projeto principal). Mas não recebeu o primeiro join, e o teste continuou com chamadas de RPC sem conexão, estourando o prazo. Transporte DTLS mínimo passa, então investigar a etapa de entrada e os callbacks do fixture antes de atribuir à rede ou ao servidor.
- Uma prova adicional de admissão do BR no laboratório travou durante a execução; foi encerrada sem afetar o projeto principal. Resultado inconclusivo. **Não declarar matchmaking online aprovado.**
- Não testado ainda: ciclo completo multiplayer Guerra/BR com executáveis distribuídos em máquinas diferentes, tela de login real no broker e quedas de rede.

### Integridade e coordenação
- Nenhum arquivo de produção de mapa, bots, física, otimização, áudio ou rede foi editado nesta rodada. Os arquivos novos adicionados ao MAIN são **apenas suítes de regressão**: `tests/war_class_hud_current.gd`, `tests/br_loot_budget_current.gd`, `tests/br_ui_validation_current.gd`.
- Logs e runners de rede em `C:\Users\Joao Borges\Documents\campo-ui-lab-20261103\work\ui-regression-deep` e `work\run_*ui.py` no laboratório.
- Testes completos usam certificado TLS de laboratório e portas locais; não foi publicado build nem alterado servidor remoto.
- Próximo teste com melhor custo/risco: instrumentar eventos por etapa (início do mapa, ENet conectado, desafio/ticket aceito, join RPC, baseline enviada, jogador liberado) com timeout e falha curta; evitar testes longos que continuem enviando RPC após o primeiro erro.

## Atualização: compatibilidade dos mapas e entrada multiplayer (03/11/2026)

**Causa dos bloqueios reproduzidos em laboratório confirmada nos logs**: o servidor recebeu os clientes, mas registrou `admission_rejected: map_content` na Guerra e `br_admission_rejected: map_content` no Battle Royale. O transporte ENet/DTLS completou sua conexão básica. Portanto, não há evidência de que ampliar timeout ou desabilitar a verificação de versão resolva corretamente esses cenários.

**Contexto novo:** há outro trabalho modificando o mapa afegão e arquivos antigos foram apagados intencionalmente. Não restaurar esses arquivos nem reprocessar os mapas no diretório principal enquanto houver edições simultâneas.

**Preflight somente leitura adicionado:** `tools/map_release_preflight_readonly.py`. Execução `python tools/map_release_preflight_readonly.py --map all`:
- Ucrânia (manifesto versão 12, criado em 03/11 às 12:09): **STALE**, 20 fontes alteradas depois do manifesto.
- Afeganistão (manifesto versão 9, criado em 03/11 às 12:10): **STALE**, 6 fontes alteradas depois do manifesto.
- Deserto clássico, Escritório e Naval: **READY**.
- Não há arquivos-fonte faltando nas listas dos manifestos desses mapas; a limpeza mencionada pelo usuário não justifica restaurar arquivos antigos.

**Procedimento seguro para atualização final**: depois que os responsáveis por mapas e otimização concluírem e os arquivos-fonte estiverem congelados, reconstruir os dados preparados com o pipeline oficial `tools/maps.py prepare --map afghan` e `--map ukraine` (ou a etapa equivalente do release), validar `tools/maps.py validate` e executar novamente o preflight; publicar cliente/servidor com os mesmos artefatos. Não editar hashes manualmente nem burlar `MapDefinition.compatible()`.

**Estado da conclusão:** os bloqueios de entrada reproduzidos foram diagnosticados como incompatibilidade dos dados preparados, mas o lançamento multiplayer completo ainda não foi revalidado contra mapas reconstruídos. Testes antigos de fixtures devem ser reavaliados contra a versão atual; não reintroduzir itens removidos.
