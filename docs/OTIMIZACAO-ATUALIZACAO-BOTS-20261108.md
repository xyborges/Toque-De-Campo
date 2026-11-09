# Otimização do processamento físico e visual dos 28 bots — 08/11/2026

## Escopo
- Repositório oficial `https://github.com/xyborges/Toque-De-Campo`; base `origin/main` **a7b9010**.
- R01: `ia/bots-poses-transform-20261108` em `C:/Users/Microgate/Documents/tdc-bot-poses-20261108`. Testes Godot 4.7.2 headless, i5-3470.
- Objetivo: diminuir o custo de composição de poses e atualizações de broadphase geradas por setters de transformações repetidos **sem diminuir frequência física, congelar hitboxes, alterar IA, tiro, armas, movimento ou rede**.
- Alterações somente em `scripts/player.gd`, `scripts/infantry_pose.gd`, `modes/war/scripts/stance.gd`; testes novos `tests/r01_bot_pose_dirty_bench.gd` e UID.
- **Opt-in: `TDC_BOT_POSE_DIRTY_GUARD=1`; padrão desligado.** Atua exclusivamente em `WarPlayer` remoto/não local com meta `war_bot=true`. Jogadores locais e outros modos seguem sempre o caminho anterior.
- Guardas de igualdade **exata**, não aproximada, antes dos setters que alteram pivôs do corpo, pernas, pés, cabeça e ombros. Não pula cálculos de pose nem reusa estados de frames anteriores. Se um valor físico mudou mesmo minimamente, o setter original ainda roda.
- Ficam intactas todas as regras de colisão/atrito, decisões de bot, física de movimento, alcance e colisão de projéteis, posições de granadas e lógica de morte.

## A/B controlado R01 (isolado, não FPS real)
- Fixture Godot headless instancia **28 `WarPlayer` reais**, todos com articulação, armas, rig/hitboxes, simulando estáticos, movimento de pernas e mudanças de mira.
- 620 ciclos por processo, primeiros 20 descartados; 600 lotes × 28 poses = **16.800 poses medidas por processo**.
- Cinco pares alternados `OFF,ON,ON,OFF,OFF,ON,ON,OFF,OFF,ON`, cada variante em processo separado. 10 execuções com exit 0 e zero erros.
- Amostras de 8 hit regions ao longo da duração em todos os 28 atores; checksum de geometria de bots estáticos **43.8468094542622** em ambos os modos; erro de pegada máximo ~0,0000002384 m. Dinâmicos tiveram testes de finitude e pegada; o movimento de base usa relógio e não permite comparação bit a bit de poses em processos separados.

| Estatística por lote de 28 poses | Original (5) | Guard ON (5) | Variação |
| --- | ---: | ---: | ---: |
| Média em CPU | 6,624292 ms | **6,301582 ms** | **−4,87%** |
| P95 | 7,0578 ms | **6,6740 ms** | **−5,44%** |
| P99 | 7,3230 ms | **7,0432 ms** | **−3,82%** |

Todos os cinco pares melhoraram média e P99. Raw local: `work/botposes-r01/pairs.txt` (ignorado no Git).
**Limite**: o valor mede o custo de 28 chamadas sequenciais `_animate_walk()` forçadas. Não inclui `WarBotDirector`, `GameStepMotion.move`, física completa 60 Hz, renderização, tráfego ENet, nem representa ganho direto de FPS.

## QA adicional — paridade física de posturas e armas em 28 bots
- Fixture `tests/r01_bot_pose_stance_qa.gd` com `war_bot=true`, rig/hitboxes reais de 28 WarPlayers.
- 4 armas (FAL, AK, Glock, G3), transições em pé/agachado/deitado, 3 ângulos de pitch e lean.
- **25.200 verificações** por variante, 13 regiões físicas e duas mãos.
- OFF: exit 0, erros 0, checksum físico **1915.82259598156**.
- ON: exit 0, erros 0, checksum físico **1915.82259598156**, idêntico.
- Testes headless do projeto com ON: pose189 2.196/2.196, prone weapon 1.126/1.126, AK reload 1.101/1.101, P1a de hitboxes 5 distâncias PASS. Nem todas essas suites exercitam o guard diretamente, que só atua nos bots; a fixture nova foi feita para isso.

## Gate de segurança e publicação
- Antes de qualquer integração: validação de postura/arma/recarga/FPP/TPP, hitboxes em 10/70/150/300/1700m e teste de 28 bots no multiplayer em GTX 1650 com tempo real de quadro e P99. Especialmente observar se guardas adicionais custam mais do que evitam em bots correndo.
- **Não ativar a flag nem integrar o experimento à main com base só neste microbenchmark**.
- Mudanças de `main` paralelas devem ser verificadas com `git fetch origin`, cherry-pick seletivo e QA sobre a versão mais recente. Não alterar worktrees de outras IAs.
