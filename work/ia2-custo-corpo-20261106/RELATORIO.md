# IA 2 — Fase 1: cérebro, corpo, poses, consultas e payload (06/11/2026)

**Status:** diagnóstico exploratório concluído; **nenhuma otimização implementada/aprovada**. Máquina: DESKTOP-R0I0NQG, GTX 1650, Godot 4.7.2, Jolt, Forward+, 1920×1080, Médio/100%, FPS destravado, VSync off, 28 bots. Aquecimento de 5 s e 20 s medidos por coleta, câmera fixa, seed 712907. **Um par ON/OFF por mapa: insuficiente para aprovar ganhos (mínimo 5 pares alternados).**

## Bases e coordenação

- Afeganistão: origin/main 4bff4ae, com fixture QA em 176c4f0, runner térmico em 21aed49; branch ia2/custo-corpo-bots-fase1-20261106.
- Favela v25: mapa 7717aa5, base de QA e828888 (merge de main + correção de coletor), fixture 8f9f2e1; branch isolada ia2/favela-v25-fase1-20261106. Não misturar com benchmark da Favela anterior.
- JJ7 IA 1: ia/benchbots-0611, commit 0280a2c, derivado de 46b23f2; 46b23f2 é ancestral de 4bff4ae, com mudança apenas em dados/documentação, sem alteração de gameplay nos arquivos comuns.
- Nenhum arquivo de gameplay editado, nem main. IA 1 mantém propriedade de colisões bot-bot, degraus, move_and_slide, test_move e LOD físico.

## Resultados de 28 bots — frames e física

| Mapa | IA | FPS médio | Frame P95 | Frame P99 | Física média Godot | Frames com ≥4 ticks |
|---|---|---:|---:|---:|---:|---:|
| Afeganistão | ON | 25,73 | 61,88 ms | 76,95 ms | 18,01 ms | 15 |
| Afeganistão | OFF | 17,92 | 107,34 ms | 131,38 ms | 21,64 ms | 117 |
| Favela v25 | ON | 13,38 | 136,05 ms | 209,39 ms | 24,09 ms | 164 |
| Favela v25 | OFF | 10,05 | 199,59 ms | 246,90 ms | 29,59 ms | 121 |

Os quatro runs tiveram **28 bots implantados**, mínimos/finais = 28, 100% de foco, renderer forward_plus, render texture 1920×1080, exit code 0 e coleta validada. Resultados são por máquina e por mapa; não são estimativas de desempenho de um servidor dedicado. FPS 1% low e rastreamento detalhado estão preservados nos JSONs individuais.

### Como foi desativado o cérebro

A flag QA --ia2-brain-off suprime exclusivamente a função de decisão _think() APÓS o aquecimento. O diretor continua chamando _move(), e cada personagem conserva sua física, pose, hitboxes e instruções de direção previamente calculadas. Consequentemente, a movimentação sem decisões novas pode ficar presa em obstáculos e consumir MAIS física. Isto aconteceu na amostra OFF: FPS e P99 pioraram. **A diferença ON/OFF não mede o custo puro do cérebro, nem representa otimização utilizável.** A leitura confiável é a temporização interna da decisão com a ressalva de instrumentação.

## Custos de script — IA ON, ms POR QUADRO renderizado

Tempos inclusivos, potencialmente aninhados, com Time.get_ticks_usec() agregados por Engine.get_process_frames(). Não somar escopos; há custo do profiler e chamadas que se sobrepõem. Valores são média / P95 / P99.

| Escopo | Afeganistão | Favela v25 |
|---|---:|---:|
| Decisão _think | 0,404 / 1,098 / 1,718 | 1,211 / 2,571 / 4,203 |
| Movimento dos bots | 6,045 / 8,624 / 14,389 | 18,909 / 38,047 / 62,021 |
| Diretor completo | 8,547 / 12,476 / 19,979 | 23,646 / 47,257 / 74,847 |
| Física/lógica WarPlayer | 7,278 / 13,689 / 19,539 | 24,077 / 46,073 / 74,354 |
| Pose visual com hit regions anexas | 3,186 / 8,624 / 10,494 | 12,809 / 25,662 / 44,323 |
| Pose da arma | 0,928 / 2,184 / 2,570 | 3,320 / 6,536 / 11,930 |
| IK dos braços | 0,896 / 2,715 / 3,120 | 3,853 / 7,734 / 11,686 |
| Pose do corpo | 0,328 / 1,007 / 1,203 | 1,411 / 2,764 / 4,259 |

Toggle de hitboxes foi chamado 5 vezes no Afeganistão e 1 na Favela durante a medição, com custo médio ~0. Isso NÃO significa hitboxes gratuitas: sua atualização de transform acontece na árvore articulada. GameInfantryPose e WarHumanRig estão dentro dos tempos inclusivos. Não houve versão simplificada: o piloto CollisionRig P1k já mostrou regressão, e mudar a relação visual/hitbox requer aprovação explícita e testes de equivalência de dano.

## Consultas físicas, IA ON, 20 s de janela

| Caminho | Afeganistão: chamadas / média por frame | Favela v25: chamadas / média por frame | Observação |
|---|---|---|---|
| _visible_enemy | 647 / 0,077 ms | 756 / 0,164 ms | Busca com raycasts internos possíveis |
| _has_clear_shot | 470 / 0,016 ms | 0 / 0 ms | Uma raycast por chamada; no v25 esta amostra não exercitou este caminho |
| _avoid | 642 / 0,023 ms | 755 / 0,077 ms | 1 a 9 raycasts por invocação, não contabilizados individualmente |
| _traffic_clear | 34 / 0,003 ms | 36 / 0,009 ms | Até duas consultas de forma por invocação |

Olhando código de produção: a) _visible_enemy faz _has_clear_shot e _think consulta outra vez para o alvo selecionado — candidato para reuso seguro; b) _traffic_clear cria BoxShape3D e PhysicsShapeQueryParameters3D por chamada — candidato para reuso. **Nenhum deles foi otimizado na Fase 1.** O QA conta invocações de funções, e não cada query interna de _avoid/_traffic_clear; as taxas exatas exigem instrumentação mais fina e validação de equivalência.

## Replicação: estimativa offline, não tráfego medido

Com zero clientes conectados, a fixture após os 20 s de FPS monta 20 períodos sintéticos de 28 estados, agrupando até 4 atores por lote e medindo var_to_bytes. Produziu **280 estados/s, 70 lotes/s, 37,1–37,2 KB/s de payload serializado por cliente hipotético, ~1,0–1,2 ms de CPU por segundo de simulação**. Não mede bytes reais da rede: faltam envelope RPC, ENet/UDP, criptografia, retransmissão, serialização específica do protocolo e CPU do cliente war_bot_states(). Não extrapolar para número de clientes; Fase 3 dedicada necessária. Os JSONs indicam real_network_peers=0 e actual_network_bytes_per_sec=null.

## GPU, temperatura, integridade e ruído

Telemetria nvidia-smi filtrada pelo intervalo Unix start/end emitido pelo Godot:

| Caso | Amostras válidas GPU | Temperatura mínima–máxima | Térmico SW/HW |
|---|---:|---:|---|
| Afghan ON | 18 | 37–39°C | Desconhecido — somente máscara geral active |
| Afghan OFF | 19 | 37–38°C | Desconhecido — somente máscara geral active |
| Favela v25 ON | 18 | 35–36°C | Not Active nas 18 amostras |
| Favela v25 OFF | 17 | 36–37°C | Not Active nas 17 amostras |

Máscara geral de throttling inclui motivo de ociosidade; não confundir com limitação térmica. O teste JJ7 antigo teve cerca de 6% de ruído sem bots, **não** é controle A/A da R0I. Faltam os 5 pares alternados requeridos para aceitar qualquer mudança. Nenhuma melhoria foi aprovada.

## Ocorrências, status e conflitos

- Godot 4.7.2 import e --check-only da fixture: **PASS** nas duas worktrees; Python py_compile: **PASS**.
- Teste smoke inicial no Afeganistão ON: registro produzido, mas Godot travou no teardown explícito, processo interrompido manualmente e **INVALIDADO**. A fixture QA foi corrigida para sair via SceneTree.quit(), e as quatro coletas oficiais encerraram código 0. Preservar log e dados do smoke inválido para auditoria.
- Tocados exclusivamente: testes IA2 ia2_cost_benchmark.gd, ia2_cost_game.gd, ia2_cost_metrics.gd e respectivos .uid; tools/ia2_cost_runner.py; dados brutos e relatório work/ia2-custo-corpo-20261106. **Nenhum arquivo de produção compartilhado tocado**, portanto sem conflito de edição com IA 1.
- JJ7: quatro JSONs b0-r1, b0-r2, b12-r1, b12-r2 + CSVs e logs **acessíveis em leitura** em worktree local da JJ7U3G3: benchbots-0611/work/bot-comparison-jj-20261106. Não estão publicados no GitHub e a IA 1 deverá centralizar as próprias evidências sem colisões.
- Não fizemos pose simplificada por risco de precisão dos hitboxes; **requer autorização antes de experimento**.
- Fase 2 (otimizações a/b com flag, 5 pares alternados e testes de hitbox/dano/escada/veículo/multiplayer): **NÃO INICIADA**.
- Fase 3 (servidor dedicado com 28 bots, cliente real e bytes ENet): **NÃO INICIADA**.

Referências metodológicas: https://docs.godotengine.org/pt-br/4.x/tutorials/scripting/debug/the_profiler.html e https://docs.godotengine.org/en/4.6/classes/class_engine.html.

**Veredito:** os 28 bots reais estão presentes. Temporização de decisões é relativamente menor que movimento e pose, mas desligá-la sem controlar trajetórias agrava física e frame pacing. Na Favela v25 há forte custo de pose, porém falta perfilar de forma mais granular e repetir pares antes de concluir causa. Paramos no fim da Fase 1, conforme a instrução.
