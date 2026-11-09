# Realismo R2B — piloto visual G3 FPP (ombros, arma, proteção física)

**Data:** 09/11/2026
**Base:** realismo R1C `0b8f86a` e contrato R2A `WarTacticalBodyPose`
**Estado:** validado em branch experimental; **não integrado à main**

## Objetivo e escopo

Adicionar resposta discreta de peso ao ombro/arma em aceleração, strafe e aterrissagem sem tocar no corpo físico. O módulo `modes/war/scripts/tactical_body_pose.gd` calcula alvos independentes para **quadril, tronco e arma FPP**; neste piloto somente `fpp_weapon_angles` é aplicado, exclusivamente sobre `view_root.rotation` local.

A implementação usa `WarLocomotion`, reaproveita os três sinais filtrados das R1A/R1B/R1C e aplica o complemento após reconstruir a pose base em `pose_weapon()`. Não foi criada outra timeline, nem outro controlador de movimento. O método privado `_allows_tactical_body_fpp()` concentra a elegibilidade; o módulo matemático permanece puro.

**Não foram editados** `player.gd`, `human_rig.gd`, `infantry_pose.gd`, `collision_pose_solver.gd` ou `collision_rig_proxy.gd`. Não muda `Pelvis`, `Torso`, ombros físicos, hitboxes, cano real, câmera, `CharacterBody.velocity`, bot, IA ou pacote de rede.

## Gates de habilitação e prioridade

**OFF por padrão.** Para ativar o piloto é necessário usar as duas flags:

```text
TDC_TACTICAL_MOTION_PILOT=1
TDC_TACTICAL_BODY_PILOT=1
```

Ou argumentos Godot `--tactical-motion-pilot --tactical-body-pilot`. O complemento roda só para **um jogador local, em pé, G3, FPP e a pé**. TPP, bots/remotos, AK/FAL/sniper, crouch/prone, ADS, iron sight, recarga, tiro/recoil, gadget, binóculo, granada, morte e veículo mantêm o caminho original. Se apenas uma flag estiver ligada, o complemento não é aplicado.

Os três pesos são sempre saturados no intervalo correto e entradas não finitas são neutralizadas antes dos cálculos. O maior ângulo resultante é pequeno (menos de cerca de 2 graus combinados no caso extremo).

## Evidência funcional

`tests/realismo_r2a_body_pose_contract.gd`: **33/33 PASS**, incluindo neutralidade, simetria, limites, NaN/Infinity e determinismo do módulo puro.

`tests/realismo_r2b_g3_body_pose.gd`: **93/93 PASS**, cobrindo 18 situações. Em cada estado, comparamos a flag OFF e ON e verificamos arma mundial, câmera, `view_root`, tronco e cabeça. Somente o cenário G3 local FPP fora de ações recebe os ângulos adicionais. Liga/desliga repetido restaura exatamente a pose base, sem acumular transform.

Regressões `realismo_r1a_motion_weight.gd` **8/8**, `realismo_r1b_lateral_weight.gd` **13/13**, `realismo_r1c_landing_weight.gd` **16/16**, todas PASS após a refatoração. A suíte `optics_universal_validation_20261103.gd` passou **242/242**, com **as duas flags habilitadas**, nas armas AK, FAL, G3 e sniper e nas ópticas prism4x, pso4x, hensoldt4x e precision8x.

O gate físico independente `tests/realismo_r1c_physics_landing.gd` foi repetido com **as duas flags habilitadas** e passou **10/10**: o corpo tocou o chão no frame 28 e o peso visual da aterrissagem disparou no frame 29, já no chão, sem nenhum impulso antecipado no ar. Isso valida que a nova classe de pose não atravessou o fluxo de colisão da R1C.

## Evidência visual G3 / Forward+ / GTX 1650

`tests/realismo_r2b_g3_calibration.gd` renderizou quatro capturas em **1280 × 720, Forward+**, com viewport FPP confirmado: `neutral`, `accelerate`, `strafe` e `landing`. Resultado **25/25 PASS**, com invariância de `weapon_root`, câmera, torso e deslocamento da R1.

Exemplos dos ângulos adicionais registrados (radianos):

| Caso | Pitch X | Yaw Y | Roll Z |
|---|---:|---:|---:|
| Neutro | 0 | 0 | 0 |
| Aceleração (peso 0,75) | +0,0075 | 0 | 0 |
| Strafe (peso -0,70) | 0 | +0,0049 | +0,0140 |
| Aterrissagem (peso 0,65) | +0,0117 | 0 | 0 |

Os efeitos são discretos e visíveis como deslocamento dos ombros/arma na cópia FPP, não como rotação da câmera. **Estas capturas exercitam pesos controlados**, não substituem um playtest humano de partida com rede.

## Microbenchmark: interpretação limitada

`tests/realismo_r2b_pose_benchmark.gd` fez warm-up e cinco pares A/A e A/B de **28 atores sintéticos × 720 ticks = 20.160 actor-frames**, chamando o novo cálculo para **um único ator FPP local** em cada tick.

Resultado registrado na Desktop JJ7:
- A/A mediana da diferença: **+0,002 ms** para o lote;
- A/B mediana: **+1,098 ms** para os 720 ticks;
- custo incremental exploratório: **~1,525 µs por tick local**, na fixture sintética;
- no modo padrão e nos 27 atores remotos, o helper R2B não é executado.

**Não é benchmark de FPS nem prova de desempenho multiplayer.** Não foram executados cinco pares com jogo renderizado, 28 bots reais e ENet. O orçamento de CPU, P95/P99 e publicação continuam sujeitos ao gate completo da GTX 1650. P1k continua pendente em trabalho separado.

## Regras para R2C — corpo físico / TPP

Não aplicar `hip_offset`, `hip_angles` ou `torso_angles` diretamente sobre os nós `Pelvis` e `Torso` atuais: hitboxes dependem da mesma hierarquia, enquanto o LOD visual remoto e o solver físico podem ter cadências diferentes. Primeiro, reconciliar trabalho de física/pose dos bots e concluir equivalência e custo do CollisionRig (P1k), preservando as 16 regiões a 60 Hz. Só depois testar PoseFrame único, ombros/IK/arma do mundo, danos, servidor e 28 bots.

## Próxima decisão

1. Manter R2A como contrato sem efeitos físicos.
2. Manter R2B como piloto G3 FPP **OFF por padrão**, disponível para QA.
3. Somente após gate de CPU, corpo/arma real e multiplayer: R2C com quadril e tronco físicos compartilhados.
4. Não publicar nem integrar na `main` automaticamente.
