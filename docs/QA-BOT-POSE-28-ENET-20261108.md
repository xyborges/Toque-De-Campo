# QA dos 28 bots: dirty guard da pose — 08/11/2026

## Decisão
**Ganho de CPU do cálculo de poses reproduzido em duas máquinas, mas NÃO HOMOLOGADO PARA FPS/PRODUÇÃO.** A flag experimental `TDC_BOT_POSE_DIRTY_GUARD=1` continua desativada por padrão e não foi integrada à `main`. O teste de cliente gráfico com 28 bots ENet na máquina principal foi inválido por timeouts, forte queda de FPS e buffer UDP cheio **mesmo com a flag OFF**. Não atribuir a falha à otimização.

## Fonte e alterações
- Projeto `https://github.com/xyborges/Toque-De-Campo`, base `origin/main a7b9010`.
- Candidato previamente feito por outra IA: `ia/bots-poses-transform-20261108` `0ce0710`, com implementação `eb7275c`.
- Validação isolada na worktree `C:/Users/Joao Borges/Documents/campo-worktrees/qa-bot-pose-main-20261108`, branch `ia/qa-bot-pose-main-20261108`, baseada no candidato remoto. Nenhuma linha de produção foi modificada por esta QA.
- O piloto adiciona guardas de igualdade **exata** em pivôs dos bots remotos nas rotinas `GamePlayer._animate_walk`, `GameInfantryPose.apply` e `WarStance.pose`. Continua calculando as poses, física e hitboxes em cada atualização; não interfere em jogadores humanos, tiros, movimento, decisões da IA ou frequência da física. Default OFF, rollback = remover variável ou definir `TDC_BOT_POSE_DIRTY_GUARD=0`.

## 1. Microbenchmark com 28 bots na R01 (i5-3470)
Cinco pares A/B alternados da branch candidata, Godot 4.7.2 headless e 28 atores reais. Cada execução mede 600 lotes de 28 poses, após aquecimento (16.800 poses por processo). Teste sem ENet, GPU, navegação ou partida real.

| CPU por lote de 28 poses | OFF | ON | Variação |
| --- | ---: | ---: | ---: |
| Média | 6,624292 ms | 6,301582 ms | −4,87% |
| P95 médio | 7,0578 ms | 6,6740 ms | −5,44% |
| P99 médio | 7,3230 ms | 7,0432 ms | −3,82% |

Todos os cinco pares melhoraram na média e no P99; 0 falhas. Dados completos no relatório original `docs/OTIMIZACAO-ATUALIZACAO-BOTS-20261108.md` na branch candidata.

## 2. Microbenchmark no notebook principal (i5-11400H)
Dez processos Godot 4.7.2 headless, cinco pares A/B com ordem `OFF,ON,ON,OFF,OFF,ON,ON,OFF,OFF,ON`. Mesmo commit `0ce0710`, mesmos 28 atores `WarPlayer`, 600 lotes × 28 poses por processo. O checksum estático de hitboxes ficou exatamente `43.8468094542622` nas dez execuções, erro máximo de pegada ~2,384 × 10⁻⁷ m, zero falhas.

| CPU por lote de 28 poses | OFF (5) | ON (5) | Variação |
| --- | ---: | ---: | ---: |
| Média | 9,85356 ms | 9,36088 ms | **−5,00%** |
| P95 médio | 13,8204 ms | 13,1166 ms | −5,09% |
| P99 médio | 19,0946 ms | 17,3992 ms | −8,88% |

A melhora média ocorreu em quatro dos cinco pares; o quinto foi pior, e alguns P99 por par pioraram. Variação de carga da CPU ainda é importante. **Não extrapolar esses valores para FPS, tick do servidor ou ganho de stutter em partida real**. Valores de lote não são custo por frame real: a fixture chama 28 `_animate_walk()` sequencialmente e exclui restante do jogo.
Dados auditáveis versionados: `docs/benchmark-results/bot-pose-primary-20261108.csv` (10 execuções, ponto decimal, 0 erros). Log completo local ignorado no Git: `work/qa-bot-pose-enet/cpu-a-b.txt`.

## 3. Testes funcionais com hitboxes reais
- Fixture própria `tests/r01_bot_pose_stance_qa.gd` com ON nesta máquina: **28 bots, 25.200 checks, 60 combinações, 13 hit regions, 2 mãos, quatro armas FAL/AK/Glock/G3, três posturas, pitch e lean; 0 erros; checksum 1915.82259598156; exit 0**.
- A máquina principal também repetiu a variante **OFF**: 25.200 checks, 60 combinações, 28 bots, checksum **1915.82259598156**, zero erros e exit 0. Assim, ON/OFF da mesma máquina mantiveram a mesma geometria física.
- Regressões com flag ON na máquina principal: `pose189_validation.gd` **2.196 checks PASS**, `prone_weapon_pose_validation.gd` **1.126 checks PASS**, `ak_reload_shoulders_validation.gd` **1.101 checks PASS** (todas exit 0, sem falhas).
- A R01 registrou paridade OFF/ON com os mesmos 25.200 checks e o mesmo checksum.
- Os testes verificam transformações físicas corretas, mas **não substituem teste de tiros e hit registration em sessão multiplayer real**.

## 4. Benchmark gráfico ENet na máquina principal: inválido
- Simulação: servidor Godot headless + cliente nativo Forward+ em GTX 1650, 28 bots no servidor, circuito ENet local, TLS de teste, flags de produção existentes. Duas tentativas com o piloto **desligado (OFF)**.
- **1920 × 1080**: cliente com 22 avisos `Buffer full, dropping packets!`, timeouts das fases parado/correndo/tanque, correções chegando a 96. Cliente não entregou relatório com `failures=[]`. Descartar FPS/P99.
- **1280 × 800**: também inválido; 68 avisos de buffer cheio, timeouts em todas as fases. O relatório bruto do cliente teve apenas ~8,51/7,75/7,99 FPS nas três fases e falhas `timeout: idle completion`, `timeout: foot completion`, `timeout: tank completion`, evidência de ambiente não comparável ao benchmark anterior estável (~40 FPS). Esses valores NÃO são resultado da otimização porque estava OFF.
- Servidor preservou `bot_count=28` no JSON de ambas as tentativas, sem falhas da autoridade. A mensagem `NETWORK_PACING server finish bots=0` vem da limpeza final, não significa que os 28 bots desapareceram durante o teste.
- **Problema identificado no runner temporário**: `tests/war_frame_pacing_network.gd` salva JSON em `res://work/microstutter1105/network-*.json`, enquanto a cópia do runner buscava `work/qa-bot-pose-enet/network-*.json`; por isso o runner reportou equivocadamente `server failed`. Os JSON brutos foram recuperados do caminho real e confirmam os timeouts do cliente. Esse erro de caminho é independente dos timeouts.
- A primeira importação Godot desta worktree também retornou `-1073741819` (access violation), embora os testes headless seguintes tenham funcionado. Import/shader cache frio, configurações gráficas, sobrecarga do computador e sincronização UDP precisam ser verificados em ambiente de benchmark saudável. Não afirmar causa sem isolamento.
- Consequência: **nenhum A/B gráfico válido**. Não executar a flag ON no cenário gráfico até o controle OFF parar de perder pacotes.

## Gates de publicação
1. **Manter flag OFF na main**, não cherry-pick da branch apenas por ganho de CPU.
2. Corrigir o ambiente gráfico/runner usando diretório de JSON certo, importar o projeto completamente, validar estabilidade do cliente OFF com 28 bots, zero timeouts e perda de UDP, resolução/qualidade/foco/GPU fixados.
3. Somente então fazer cinco pares gráficos alternados OFF/ON, validar FPS médio, P95/P99 de frame, clock GPU/CPU, múltiplos physics ticks e atividade de bots, combate, armas, mortes, posturas, veículos e hitboxes físicas.
4. Continuar medindo `player.pose` e `player.remote.physics` separadamente (nos testes anteriores ~0,31–0,32 ms por chamada inclusive escopos aninhados). Não desligar `_physics_process`, congelar hitboxes nem reduzir autoridade balística para ganhar FPS.
