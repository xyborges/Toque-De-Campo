# Auditoria inicial — física, movimento e poses dos bots

**Data:** 09/11/2026
**Máquina de referência:** DESKTOP-JJ7U3G3, i5-11400H + GTX 1650
**Base atual da auditoria:** `origin/main ce2653e`
**Branch isolada:** `ia/bot-physics-pose-jj7-20261109`

## Veredito inicial

1. **O movimento físico do Jolt e as poses são alvos prioritários**, mas ainda não existe otimização de gameplay homologada nesta auditoria.
2. **Nunca reduzir a física de 60 Hz nem pular hitboxes para ganhar FPS:** as regiões balísticas ainda seguem pivôs visuais em certas configurações. Separar o solver físico do LOD visual requer compatibilidade com P1k.
3. As tentativas históricas de desligar colisão bot×bot apresentaram desempenho inconsistente e pior P99 em vários pares. Não habilitar em produção.
4. `test_move` (degraus) não mostrou custo relevante na amostra estudada. Não concentrar esforço no cache experimental de passos sem uma reprodução de gargalo real.
5. A investigação cria medidores adicionais **opt-in** para separar `bot_move_total` e `bot_separation` dos custos de `move_slide`. Fora do modo de diagnóstico, toda a física e os controles seguem o comportamento atual.

## Evidências anteriores já disponíveis no disco — NÃO são um novo benchmark

Resultados em `work/ia1-fisica-bots-20261106/` da worktree histórica `ia1-fisica-bots-0611`, usando Godot 4.7.2, Favela, Forward+, 1080p, 100% da escala, foco contínuo, com 0/6/12/28 bots.

| Bots | FPS médio | P99 frame (ms) | Física/quadros (ms) | GPU (ms) | `move_slide` (ms/quadro) | Pose (ms/quadro) |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 97,60 | 23,54 | 5,98 | 2,76 | 0,000 | 0,000 |
| 6 | 80,28 | 26,04 | 9,91 | 3,14 | 0,057 | 0,083 |
| 12 | 56,09 | 37,61 | 12,80 | 4,43 | 0,248 | 0,238 |
| 28 | **20,59** | **107,61** | **18,52** | 9,85 | **3,359** | **2,116** |

A coleta de 28 bots manteve todos os 28 vivos ao final e a física em ~60 ticks/s, mas precisou de **2,92 ticks físicos por quadro renderizado em média**. Portanto, o FPS cai mesmo sem reduzir o clock lógico da física. Os medidores de Jolt e pose são tempo acumulado por quadro de render e **não** incluem todo o tempo de física, e as áreas aninhadas do profiler não devem ser somadas.

Para a Favela com 28 bots, outras parcelas exclusivas por quadro foram: `think_total` **0,272 ms** (inclui percepção/navegação), `navigation` **0,034 ms**, `perception` **0,036 ms** e `step_test` **0,004 ms**. A prioridade indicada pelos valores medidos é `move_slide`, depois a pose, e não roteamento ou degraus.

## Experimentos negativos antigos

A/B de cinco pares no mesmo mapa, substituindo somente colisão bot×bot por exceções físicas, **não mostrou ganho seguro**:

| Par | FPS controle → exceção | P99 controle → exceção (ms) |
| --- | --- | --- |
| 1 | 22,00 → 19,42 | 81,05 → 105,06 |
| 2 | 22,71 → 22,72 | 88,00 → 77,94 |
| 3 | 22,20 → 23,34 | 88,64 → 117,61 |
| 4 | 23,85 → 18,29 | 100,29 → 159,92 |
| 5 | 11,74 → 9,25 | 201,59 → 183,16 |

Além do risco de sobreposição de corpos e cobertura física, esse resultado não justifica remover colisões. O protótipo antigo de atualização física de poses a 30 Hz também não pode ser aceito sem equivalência de regiões e ações.

## Auditoria do código atual

- `modes/war/scripts/bot_director.gd::_physics_process` percorre os bots, executa `_move` a cada tick para atores ativos a pé, deixando atores em água/veículos para outros caminhos.
- `modes/war/scripts/bot_director.gd::_move` calcula a separação com atores próximos, define velocidade, aplica `GameStepMotion.move` e avalia travamentos. Não roda `_update_weapon_pose` uma segunda vez no fluxo normal.
- `scripts/step_motion.gd` utiliza `move_and_slide()` e tenta resolver degraus com `test_move()` somente quando há colisão bloqueante; a cache experimental de falhas está OFF.
- `modes/war/scripts/player.gd::_animate_walk` mantém limites de frequência visual por distância para atores remotos, mas o autoritativo não deve perder alinhamento físico. Há comentários explícitos sobre o risco de regiões de acerto seguindo pivôs visuais.
- `BotCostProbe` mede por quadro o custo do `move_slide`, degraus, percepção, LOS, navegação, pose e decisão. Esta branch acrescenta `bot_move_total` e `bot_separation`, garantindo que a execução original continue intacta com `--ia1-physics-probe` desligado.

## Gate antes de recomendar qualquer mudança

1. Importar e compilar a branch experimental sobre a **main atual**; dados antigos não podem ser comparados automaticamente com a revisão nova.
2. Medir 0/12/28 bots na Favela com mesma cena, 1080p Médio 100%, sem concorrência Godot, registrando FPS/P95/P99, ticks/s, GPU, Jolt, poses, separação e movimento total.
3. Se houver candidato, fazer cinco pares OFF/ON alternados, 10 s warmup e 60 s por condição para gate oficial, sem reduzir a física, a qualidade gráfica ou a população real de bots.
4. Manter paridade de hitboxes por região, cano, tiros e navegação em 25.200 verificações ou outro fixture estritamente equivalente; repetir no multiplayer autoritativo.
5. Só integrar à `main` se reduzir custo real sem piorar P99, travadas ou precisão de disparos. **R2C fica postergada** até esse gate.

## Estado das novas medições

**Três coletas diagnósticas concluídas na JJ7:** Godot 4.7.2, Favela, Forward+, 1920×1080, escala 100%, 6 s de aquecimento e 18 s de medição por condição. Todos os testes tiveram foco integral, o número solicitado de bots permaneceu vivo até o fim, a física avançou a aproximadamente 60 ticks/s e os processos encerraram com código 0. O editor recompilou a worktree sem erro após reconstrução de seu cache local.

| Cenário | FPS médio | P95/P99 de quadro | Física média | GPU média | Ticks/quadro |
| --- | ---: | ---: | ---: | ---: | ---: |
| 12 bots, probe ON | **84,65** | 16,53 / 20,87 ms | 9,27 ms | 3,48 ms | 0,71 |
| 28 bots, probe ON | **45,35** | 33,02 / 46,26 ms | 16,71 ms | 5,62 ms | 1,32 |
| 28 bots, probe OFF | **40,65** | 36,70 / 63,84 ms | 18,96 ms | 5,49 ms | 1,48 |

**Custos internos em ms por quadro** (probe ON, subcomponentes sobrepostos não são somados):

| Escopo | 12 bots | 28 bots | Observação |
| --- | ---: | ---: | --- |
| Movimento total | 0,863 | **4,199** | Inclui slide e separação |
| move_and_slide | 0,578 | **2,629** | ~0,079 versus ~0,075 ms por chamada |
| Separação entre atores | 0,086 | **0,615** | ~0,012 versus ~0,018 ms por chamada |
| Pose | 0,275 | **1,222** | P95 no quadro com 28 bots = 5,656 ms; P99 = 6,282 ms |
| Decisão (inclusive) | 0,127 | 0,314 | Navegação e percepção estão aninhadas |
| Navegação | 0,047 | 0,126 | Abaixo do custo de Jolt e pose |
| Degraus/test_move | 0,0001 | 0,029 | Não é prioridade |

**Diagnóstico:** o custo de Jolt por chamada se manteve aproximadamente estável entre 12 e 28 bots. A quantidade de chamadas por quadro aumentou de 7,28 para 34,91 devido ao maior número de atores e ao menor FPS; a separação mostrou aumento de custo por chamada com maior densidade. As poses têm distribuição irregular com pico P95 considerável. A medição sem probe **não é um par A/B controlado**, apenas uma contraprova de execução sem instrumentação. O FPS menor sem probe **não comprova que a instrumentação ajuda**, pois há variação entre partidas e aquecimento.

A meta oficial de 60 FPS e P99 ≤33,3 ms **não foi alcançada com 28 bots**. As três coletas duram 18 s e, portanto, são diagnósticas, não homologação de 60 s. Todas as medições estão preservadas em JSON na pasta docs/benchmark-results/bot-physics-jj7-20261109. A branch acrescenta apenas instrumentação opt-in, sem mudança de movimento ou hitboxes. A R2C continua aguardando uma otimização segura e validada.
