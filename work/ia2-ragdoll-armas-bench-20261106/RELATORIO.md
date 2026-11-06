# IA2: benchmark de ragdolls e reconstrução de armas — Toque de Campo
Data: 06/11/2026. Computador: DESKTOP-R0I0NQG. Godot 4.7.2.stable.official.ed1daf0bf, física 60 Hz. Base: f72a0f1. Branch: ia2/bench-ragdoll-armas-20261106. Main não modificada.

## Escopo e rigor
Testes headless com 28 WarPlayer remotos instanciados, usando o cenário tests/war_optics_fixture.gd. **Não** são 28 bots pensando/disputando objetivos e **não** medem FPS de cliente GTX1650, rede ENet, GPU nem multiplayer dedicado. Cada variante rodou em um processo Godot independente, sem outro Godot ativo, com as demais flags experimentais OFF. Ordem A-B-B-A-A-B-B-A-A-B: cinco pares A/B por intervenção, dez coletas de armas e dez de ragdolls. Todos os subprocessos passaram nas verificações do fixture. Dados brutos em five-pairs-raw.csv e arquivos de cada rodada .json e .log. Análise em five-pairs-analysis.json.

## Experimento A: reuso da geometria de arma em respawns/equipamentos sem mudança real
Fixture: 20 atualizações sucessivas nos 28 atores (560 chamadas por subprocesso), incluindo revalidação do marcador de disparo; uma troca explícita de arma deve continuar reconstruindo muzzle e modelo. Flag existente TDC_IA2_REUSE_RESPAWN_WEAPON=1, OFF por padrão.

| Medida | A original | B reuso | Ganho |
|---|---:|---:|---|
| Tempo médio por lote de 28 armas | 6,31635 ms | 2,92906 ms | -3,38729 ms / -53,63% |
| Média dos P99 internos por lote | 7,037 ms | 3,481 ms | melhora |
| P99 médio das janelas medidas do fixture | 9,4276 ms | 7,2014 ms | melhora |
| Máximo intervalo observado | 9,695 ms | 7,350 ms | melhora |
| Intervalos acima de 33 ms | 0 | 0 | nenhuma travada detectada |

Vitórias B: 5/5 pares. Ruído da média de A, amplitude/média: 0,33%; ruído dos P99 de A: 5,16%. Cada B reaproveitou as 560 atualizações em vez de reconstruir a arma; troca para outra arma segue fazendo rebuild. **Decisão:** ganho de CPU real para o fixture, superior ao ruído, mas ainda precisa validação de partida real, respawn ENet, FPP/TPP, tiro/hitboxes e P99 do cliente antes de virar padrão.

## Experimento B: ragdoll remoto enfileirado
Fixture: quatro rajadas de oito mortes artificiais, com 28 personagens remotos disponíveis; o mesmo DeathRagdoll é criado com clearance, corpos físicos, juntas e materiais. Flag existente TDC_IA2_DEFER_REMOTE_RAGDOLL=1, OFF por padrão. A fila limita a apresentação remota a um novo cadáver por quadro; a câmera de morte local permanece imediata e o servidor headless de produção não cria cadáver visual.

**Comparação primária válida:** apenas PRIMEIRA rajada de cada subprocesso, quando as duas variantes começam sem cadáveres e terminam com 8 cadáveres.

| Primeira rajada, cinco repetições | A imediato | B uma criação por quadro |
|---|---:|---:|
| Média dos callbacks de oito mortes | 78,8418 ms | 1,8674 ms |
| Média dos P99 das primeiras janelas observadas | 78,8418 ms | 10,641 ms |
| Intervalos acima de 33 ms | 5 | 0 |
| Cadáveres criados na primeira janela | 8 | 8 |

**Interpretação:** redução significativa de trabalho *concentrado* na mesma chamada; o trabalho físico total dos oito cadáveres continua existindo, agora distribuído em até oito quadros com latência visual correspondente.

**Dados complementares, NÃO equivalentes de população:** quatro rajadas completas por subprocesso resultaram em callbacks médios A=81,651 ms e B=1,135 ms; média dos P99 das janelas A=101,412 ms e B=33,129 ms; intervalos acima de 33 ms A=21 e B=6. A variante B ainda apresentou pico máximo de 71,674 ms. O ruído no P99 da variante A foi muito alto (85,97%); não aprovar a fila para produção com base nesse valor. Existe um defeito na contagem de cadáveres em rajadas, que confunde essa comparação de quatro ondas.

## Experimento C: defeito no limite de 10 cadáveres
O trecho antigo selecionava old[0] para queue_free() quando a lista estava cheia; a remoção é adiada até o final do quadro, e rajadas acabavam agendando repetidamente o mesmo corpo. O teste de quatro rajadas acumulou 29 cadáveres físicos em A (versus 10 no modo B); isso é um **problema real no tratamento de mortes simultâneas**.

Corrigido experimentalmente em scripts/main.gd, atrás de uma flag separada: TDC_IA2_RAGDOLL_STRICT_CAP=1, OFF por padrão. O algoritmo conta somente cadáveres ainda não marcados para remoção e seleciona para descarte um cadáver não agendado anteriormente. Nenhuma alteração de dano, tiro, hitbox, colisão de personagens vivos ou autoridade de rede.

Teste tests/ia2_ragdoll_cap_qa.gd: 12 mortes no mesmo quadro; sem a flag o sistema manteve **11** corpos, com a flag manteve **10**. Verificação de liberação passou. Corrigiu integridade do limite, mas **não há cinco pares A/B isolando o ganho de P99 dessa flag**, portanto ainda não habilitar globalmente.

## Regressões e pendências
- Código GDScript compilou via Godot --headless --check-only para scripts/main.gd e dois scripts novos.
- tests/ia2_entry_combat_qa.gd passou com flags de reuso de arma, fila de ragdoll, ray visual e limite estrito ativadas: **23 checks, 0 falhas**.
- tests/ia2_ragdoll_cap_qa.gd: **4 verificações, 0 falhas** (inclui limpeza após cada caso).
- Testes de perfil no fixture terminados sem falhas, 20 resultados completos. Não houve medições térmicas de GPU nem render de cliente.
- Não houve medição da melhoria em partida real com RTT, jitter, FPS/P95/P99 GTX1650 ou tiros; não misturar com os benchmarks da JJ7.
- Nenhuma flag foi ligada por padrão; nada vai para a main nem há build pública. A IA 1 mantém propriedade dos ajustes de movimento/física do bot.

## Arquivos e integração
- scripts/main.gd: novo opt-in de limite estrito de cadáveres, preservando a lógica antiga como padrão.
- tests/ia2_respawn_ragdoll_benchmark.gd: fixture de 28 remotos, 560 refreshes ou 32 mortes.
- tests/ia2_ragdoll_cap_qa.gd: 12 mortes simultâneas e contagem de corpos.
- work/ia2-ragdoll-armas-bench-20261106: este relatório, dados, logs, CSV, scripts de execução e checksum SHA256.

**Decisão final:** o reuso de armas apresentou sinal robusto nos cinco pares; o escalonamento de ragdolls reduz os picos de múltiplas mortes sob oito corpos equivalentes, mas pode causar atraso de cadáver visual e não eliminou todos os picos; o limite físico tem defeito comprovado e correção experimental. Testar as três flags individualmente num cliente real antes de homologá-las.
