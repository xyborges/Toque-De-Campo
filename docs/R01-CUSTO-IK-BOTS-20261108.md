# R01 — custo de atualização de braços/IK dos bots (08/11/2026)

## Escopo e coordenação
- Repositório oficial: `xyborges/Toque-De-Campo`; base `origin/main` `4e41854` (1.13.9/build 97).
- Branch exclusiva: `ia/r01-arm-ik-cost-20261108`, worktree `C:/Users/Microgate/Documents/tdc-r01-arm-ik-20261108`.
- Equipamento: DESKTOP-R0I0NQG, i5-3470 e GTX 1650, Godot 4.7.2.
- Outros prompts permanecem responsáveis por `modes/war/scripts/player.gd`, `scripts/player.gd`, `modes/war/scripts/bot_director.gd`, `scripts/step_motion.gd`, hitboxes/CollisionRig, ópticas e rede. NENHUM desses arquivos foi modificado aqui.
- `main` não foi alterada; nenhuma build foi publicada.

## Investigação
- O `WarPlayer._physics_process` conserva trabalho de movimento e de apresentação; o código já possui LOD da pose visual por distância (aprox. 30/15/8 Hz).
- `WarHumanRig.pose` é usado para resolver mãos e cotovelos no mundo (inclusive armas e agarramentos), e toca pivôs portadores de hitboxes.
- Não é seguro simplesmente desligar essas atualizações ou mudar a frequência de hitboxes: o servidor precisa validar tiros corretamente.

## Experimento opt-in
Flag `TDC_R01_IK_NODE_CACHE=1` (desligada por padrão). Em `modes/war/scripts/human_rig.gd`:
- Cache local no pivô do braço com os três nós já existentes: antebraço, mão e braço superior.
- O cache é reconstruído quando `WarHumanRig.build` reconstrói o rig, evitando buscas repetidas por nome durante `pose`.
- Fallback mantém a busca original se o cache não estiver disponível ou tiver referências inválidas.
- Nenhuma alteração nas fórmulas IK, poses, hitboxes, raycasts, movimentação, rede, armas ou atualização do servidor.
- O modo padrão usa os nós originais. É um piloto, não uma otimização homologada.

## Benchmark isolado
Fixture `tests/r01_arm_ik_benchmark.gd`: 28 atores remotos reais `WarPlayer`, 56 resoluções IK por amostra, 600 amostras após aquecimento, total de 33.600 chamadas por execução. Movimento de mira/lean controlado e posição das mãos verificada. **Não** representa partida completa, FPS, carga de bots com IA/ENet nem colisões simultâneas de 28 bots em terreno real.

| Medida preliminar de um único A/B | Original | Cache opt-in |
| --- | ---: | ---: |
| CPU por lote de 56 IK (média) | 2,2495 ms | 2,1137 ms |
| P95 por lote | 2,433 ms | 2,228 ms |
| P99 por lote | 2,660 ms | 2,390 ms |
| Checksum de poses | 3980,89246164644 | 3980,89246164644 |
| Maior erro da pegada | 0,000000255 m | 0,000000255 m |
| Falhas | 0 | 0 |

Isso representa **aproximadamente 6% de redução de CPU no lote sintético isolado**, não 6% de FPS no jogo.

## Por que a bateria de cinco pares não foi validada
Durante as repetições A/B alternadas a carga da CPU da R01 chegou a aproximadamente **94%**. Uma execução original passou de 2,60 ms para 9,38 ms de média, com p99 de 52,65 ms, variação muito superior à otimização que se buscava medir.
Confirmado por inspeção dos processos: outra instância de IA estava realizando teste ENet com a R01 como cliente e DESKTOP-JJ7U3G3 como servidor, ambos usando Godot 4.7.2. A bateria foi **interrompida sem encerrar nem modificar processos da outra IA**.

## Veredito
- Correção funcional inicial do piloto: **PASS** na fixture de 28 avatares, mesma pose exata e nenhuma exceção de script.
- Ganho de FPS, P95/P99 real, desempenho de IA ativa e hitreg multiplayer: **NÃO COMPROVADOS**.
- **Não integrar à main, não ligar a flag por padrão, não lançar build** com base nestas medições.
- Próximo teste quando as duas máquinas estiverem livres: cinco pares alternados A/B na mesma CPU/GPU, 28 bots em combate, medindo P95/P99 de quadro e perfil de `WarPlayer`, validação de hitboxes/armas/reload/FPP-TPP e conferindo se a redução de custo IK supera ruído.
