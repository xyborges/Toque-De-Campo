# Bots / IK — retomada da avaliação A/B (08/11/2026)

**Veredito: NÃO homologar a otimização na main.** A economia no escopo IK existe, mas FPS e cauda de quadros não melhoraram consistentemente com 28 bots. Manter `TDC_R01_IK_NODE_CACHE` desligada por padrão.

## Controle de versões e isolamento
- Repositório: `xyborges/Toque-De-Campo`.
- R01: branch `ia/r01-arm-ik-cost-20261108`, base original `4e41854`, piloto `73a5232`, relatório atualizado `08a3307`.
- Máquina principal: branch `ia/ik-28bots-qa-20261108`, base `origin/main a7b9010` (inclui integração das flags IA2 de outras IAs); piloto portado cirurgicamente por `66ac428`.
- `modes/war/scripts/human_rig.gd` é o único arquivo de produção modificado, e só quando a variável `TDC_R01_IK_NODE_CACHE=1` estiver habilitada. `WarPlayer`, `GamePlayer`, `bot_director`, `step_motion`, movimento, armas, física de disparos e rede estão intocados.
- **A branch main não foi modificada; nenhuma build/servidor foi atualizada por esta tarefa.**

## 1. R01: CPU do IK isolado, 28 atores (cinco pares)
- Godot 4.7.2, i5-3470, sem clientes ENet adicionais. Cinco pares alternados, dez processos `Godot` independentes, sequência `0,1,1,0,0,1,1,0,0,1`. Cada processo resolve 56 IK por lote, 600 amostras medidas após aquecimento (33.600 chamadas).
- Tempo médio por lote: **2,283288 ms original vs 2,132034 ms otimizado (−6,62%)**. Todos os cinco pares venceram em média.
- P95 médio: 2,4016 ms original vs 2,3302 ms otimizado (−2,97%).
- **P99 médio: 2,5928 ms original vs 2,7624 ms otimizado (+6,54%, pior)**.
- Todas as 10 execuções: exit 0, sem falhas, checksum de posições exatamente `3980.89246164644` e erro máximo de pegada ~0,000000255 m. A economia não é ganho de FPS.
- Log local: `work/r01-arm-ik/r01-paired-20261108.txt` na R01 (ignorado no Git).

## 2. Máquina principal: 28 bots e um cliente gráfico ENet
- DESKTOP-JJ7U3G3: i5-11400H, GTX 1650, Godot 4.7.2, Vulkan/Forward+, servidor Godot headless e cliente gráfico, rede loopback, 28 bots reais ativos no servidor / 29 atores replicados no cliente. Todas as execuções completaram com 0 falhas e todas as fases tiveram movimento real.
- Benchmark: `tests/run_war_frame_pacing.py` para 1280 × 800; cópia temporária `work/run_war_ik_1080.py` para 1920 × 1080, sem modificar o runner oficial. Fases de aproximadamente 20 s: parado, correndo, tanque. Não confundir com simulação de combate completo em servidor remoto.
- **1280 × 800**: modo original executado antes do otimizado. A rodada otimizada registrou alguns avisos de criação de cache de shaders por limite de caminho do Windows no APPDATA longo.
- **1920 × 1080**: modo otimizado executado antes do original, com APPDATA mais curto; logs de cliente sem erro de cache na coleta final. Não há comprovação de que todas as configurações gráficas coincidam com preset Médio oficial. Cada variante tem apenas uma execução em cada resolução.

### 1280 × 800 — FPS e P99 do quadro

| Fase | Original FPS | Otimizado FPS | Original P99 (ms) | Otimizado P99 (ms) |
| --- | ---: | ---: | ---: | ---: |
| Parado | **47,06** | 44,16 | **32,62** | 39,25 |
| Correndo | **41,96** | 41,77 | 37,30 | **36,26** |
| Tanque | **49,59** | 48,49 | **35,02** | 40,46 |

### 1920 × 1080 — FPS e P99 do quadro

| Fase | Original FPS | Otimizado FPS | Original P99 (ms) | Otimizado P99 (ms) |
| --- | ---: | ---: | ---: | ---: |
| Parado | 44,43 | **45,28** | 34,16 | **32,58** |
| Correndo | **40,30** | 39,47 | **38,17** | 48,44 |
| Tanque | **47,01** | 46,36 | **32,68** | 34,13 |

Resultado geral: otimização foi mais rápida apenas no trecho parado a 1080p; nas outras cinco combinações resolução/fase não houve ganho de FPS. P99 piorou em vários casos. Logo, **nenhuma evidência de correção de travamentos**.

### Profiler de escopos reais
O profiler de servidor incluiu 28 bots com movimentação, poses e física atualizadas:
- 1280 × 800: `player.arm_ik` original 0,04771 ms/chamada vs otimizado 0,04576 ms (−4,1%), mas `player.pose` 0,31169 → 0,31473 ms e `player.remote.physics` 0,32442 → 0,32852 ms.
- 1920 × 1080: `player.arm_ik` original 0,04829 ms/chamada vs otimizado 0,04458 ms (−7,7%); `player.pose` 0,31608 → 0,30620 ms e `player.remote.physics` 0,32899 → 0,31970 ms. A variação do agendamento/carga das rodadas impede atribuir esses deltas de pose/física especificamente ao cache.
- Profiler completo de referência registrou ~163 mil chamadas de `player.arm_ik`, ~81 mil `player.pose` e ~106 mil `player.remote.physics` durante ~73 s. Tempos de escopos incluem rotinas aninhadas e **NÃO devem ser somados**. O custo total do boneco vivo é muito maior que o da simples busca dos nós do braço.

## 3. Regressões funcionais (otimização ligada na máquina principal)
Todos os testes headless abaixo terminaram com **exit 0, zero falhas**:
- `tests/r01_arm_ik_benchmark.gd`: 28 avatares, 33.600 resoluções de IK, checksum de poses igual ao original.
- `tests/pose189_validation.gd`: **2.196 verificações**, sem penetração dos braços/erro de pegada relevante.
- `tests/prone_weapon_pose_validation.gd`: **1.126 verificações**, armas, ADS, ópticas, recarga, posições deitado/agachado e primeira/terceira pessoa.
- `tests/ak_reload_shoulders_validation.gd`: **1.101 verificações**, recarga de AK, ombros, pegada da arma, ópticas e rig compartilhado BR.
- `tests/true_fpp_p1a_authority_hitboxes.gd -- --true-fpp-p1a-authority`: regiões balísticas autoritativas conferidas em **10, 70, 150, 300 e 1700 m**, 13 regiões por ator, nenhum erro de pose com LOD/câmera no piloto QA. Não significa que todo o plano P1a esteja habilitado em produção.

## Decisão e próxima prioridade
1. **Não promover `TDC_R01_IK_NODE_CACHE=1` à main**, pois o delta de FPS é inconsistente e o P99 até piora. Preservar branch opt-in para estudo.
2. O custo real está concentrado na **atualização do WarPlayer inteiro**, especialmente escopos `player.pose` e `player.remote.physics`, que englobam IK e outras rotinas. Não repetir a experiência de desligar `_physics_process` inteiro: isso congela estado/posições das hitboxes.
3. Próxima frente recomendada: instrumentar e otimizar *separadamente* `_animate_walk`, `_update_weapon_pose`, `stance.advance` e transformações físicas sem retirar autoridade de tiros/cobertura. Coordenar com IAs que já reservam `player.gd`/bot director antes de integrar.
4. Dados brutos dos quatro ensaios multiplayer estão em `work/microstutter1105/ik-*-client.json` e `ik-*-server.json` da worktree principal (ignorados no Git). Não extrapolar os resultados para 60 FPS/1080p Médio até execução no cenário oficial de combate com período de amostragem maior e vários pares completos.
