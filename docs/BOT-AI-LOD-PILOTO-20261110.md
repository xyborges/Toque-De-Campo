# LOD tatico dos bots: ativacao por padrao — 10/11/2026

## Objetivo
Reduzir custo de percepcao, roteamento e tomada de decisao dos bots *fora de combate*, sem tocar em locomocao, colisoes, hitboxes, cadencia fisica, disparos, dano, visibilidade real, ragdolls e replicacao ENet/DTLS.

Origem: piloto commit `4963b0f`; ativacao padrao na branch `ia/bot-ai-lod-default-20261110`, partindo da main local `85cc9d1`.

## Descobertas
- A Guerra ja usa AStarGrid2D para rotas locais, AStar2D para malha rodoviaria, AStar3D para lajes, cache de rotas (~1.25 s).
- O diretor ja distribui **40 chamadas _think por segundo**, com um bot por vez; `_avoid`/LOS sao consultados nessa cadencia, nao por bot a 60 Hz.
- `GameStepMotion` usa CharacterBody3D/move_and_slide e test_move para degraus.
- `DeathRagdoll` ja implementa ossos fisicos proprios usando RigidBody3D e ConeTwistJoint3D; nao usar PhysicalBone3D em paralelo.
- Bots usam separacao local de aliados por indice espacial e rotas/escape em obstaculos; `NavigationObstacle3D` nao substitui planejamento global e exige mapa de navmesh apropriado.
- Pose LOD visual por distancia ja existe (33/66/125 ms em WarPlayer). Isso nao e LOD de tomada de decisao.

## LOD tatico habilitado por padrao no modo Guerra
Sem parametro de inicializacao, o LOD tatico e usado pelo diretor de bots em todos os mapas Guerra (Favela, Afegao, Ucrania). A flag `--war-bot-ai-lod-legacy` volta ao agendador antigo para testes A/B e reversao rapida.
Mantem o limite duro de no maximo uma decisao por 25 ms, usando round-robin. A consulta de proximidade e somente distancia ao inimigo (nenhum raycast extra).

- Combatendo, em veiculo, abatido/nao implantado, defendendo proximo do objetivo ou a ate 200m de qualquer inimigo ativo: intervalo minimo 0.25 s (sujeito ao limite global de 40/s).
- Entre 200 e 350m de um inimigo ativo, nao engajado: intervalo minimo 0.55 s.
- Sem inimigos proximos (>350 m) e longe de objetivo: intervalo minimo 1.0 s.
- O bot continua andando, sofrendo fisica e replicando sua posicao nos ticks existentes. Apenas `_think` e adiado.
- Estado `ai_lod_next` descartado em `reset()`. `setup()` le a flag de retorno ao agendador antigo; sem flag usa o LOD novo.
- Mesmo com sensor de distancia (e sem linha de visao), um inimigo pode aproximar-se durante a janela de 1.0 s: o piloto precisa de QA de tempo de reacao e alvo atras de cobertura antes de habilitar em release.

## QA requerido
- Teste deterministico de 28 bots (frequencia, limite 40/s, fairness, prioridade e regressao de tempo): `tests/bot_ai_lod_qa.gd`.
- Rodar QA original: `tests/favela_bot_pressure_qa.gd` e `tests/war_bot_escape_armor_qa.gd`, nas duas configuracoes, isoladamente.
- Rodar 0/12/22/28 bots com autoridade real e cliente, 1080p na GTX 1650: `tests/war_lag_load.gd` ou benchmark oficial; medir CPU em `bot.think`, `bot.move`, p95/p99 e tempos de reacao sob inimigos.
- Repetir no Afgão, Favela e Ucrania, com bots defendendo objetivos e reagindo a veículos. Nao publicar ate nao haver regressao em IA e performance.

## Nao recomendado nesta fase
- Trocar imediatamente para NavigationAgent3D: nao torna toda a consulta de rota assincrona e seria reescrever o sistema de A* sem benchmark.
- Adicionar NavigationObstacle3D em todos os veiculos: evita movimentos localmente apenas quando usado com nav avoidance; nao gera caminho alternativo automaticamente.
- Trocar ragdoll por Skeleton3D+PhysicalBone: risco de dobrar fisica; sistema proprio ja existe.
- Instalar LimboAI: arquitetura atual tem classes e estados complexos; consideraria em comportamentos novos, em branch separada, apos medir integracao Windows/Ubuntu.

## Execução local nesta branch
- Godot `4.7.2.stable`, import de recursos do projeto em worktree isolada: `IMPORT_EXIT=0`.
- Teste de algoritmo e seleção real `tests/bot_ai_lod_qa.gd`: **24/24 PASS**, incluindo seleção no WarBotDirector com dois personagens na SceneTree, wake imediato ao engajamento, configuração default-on e simulações de 12/28 bots.
- Regressão de combate/locomoção `tests/war_bot_escape_armor_qa.gd`: **10/10 PASS**, `ESCAPE_EXIT=0`, rota evita barreira e bot reage ao APC procurando cobertura.
- Simulação de 28 bots por dez segundos mostra teto de 400 decisões em combate e 280 decisões quando todos estão distantes; distribuição justa entre IDs. Isso mede **somente a lógica de agendamento**, não FPS ou benefício CPU real.
- Testes de multiplayer, envelhecimento de percepções, combate completo, 0/12/22/28 bots e benchmark gráfico GTX1650: **pendentes**. Branch não pode ser mesclada ou publicada ainda.

## Por que não ativar de imediato
A economia teórica de `_think` varia com quantos bots estão em combate; quando muitos exigem resposta rápida o teto global continua em 40/s. Além disso, um bot sem alvo conhecido pode levar até 1 segundo para notar aproximação inimiga distante. O ganho e os efeitos táticos precisam ser demonstrados na mesma cena com e sem flag.

## Ideias adicionais examinadas (nao implementadas nesta mudanca)
- **LOD de pose fora da camera:** WarPlayer ja usa distancia para cadencia visual em `_animate_walk` (aprox. 30/15/8 Hz para faixas de 80m/250m/mais distante). Um proximo teste deve pular apenas calculos visuais fora do campo de visao, SEM desativar `WarPlayer`, a pose fisica autoritativa, hitboxes ou multiplayer. `VisibleOnScreenEnabler3D` direto no ator pode desabilitar o processo inteiro, por isso nao e seguro.
- **GDExtension em C++:** tecnicamente compativel com Godot 4, mas ainda nao medido. Priorizar apenas funções de matematica pura de `GameInfantryPose` e solvers de pose, caso o `GamePerformanceProbe` comprove custo alto de GDScript; manter transformacoes em cena, autoridade, hitboxes e dano em Godot. Exigiria binarios Windows x64 e Linux x64, testes equivalentes e fallback GDScript. Nao substitui custo do Jolt/`move_and_slide()`.
- **Export dedicado para Ubuntu:** o preset `Export as dedicated server` pode eliminar recursos visuais no PCK, mas nao suspende automaticamente callbacks fisicos dos bots. Avaliar numa branch separada, nunca presumir FPS/CPU melhores por export menor.

## Homologacao 10/11/2026 — LOD padrao (somente branch, NAO main)

### QA basico e carga
- Godot 4.7.2. Script `tests/bot_ai_lod_qa.gd`: **27/27** default-on e **27/27** com `--war-bot-ai-lod-legacy`, sem erro de script apos remover `setup(game)` de fixture fora da SceneTree e tornar a leitura de flag pura (`WarBotAiLod.enabled_from_args`).
- `tests/war_bot_escape_armor_qa.gd`: **10/10 PASS**, navegacao real e resposta a APC.
- `tests/war_lag_load.gd` com 12/28 bots: nenhum erro ou populacao incompleta nos pares default/legacy; nao afirmar ganho de FPS so por esse teste.

### Pares isolados de 28 bots, 24 s medidos, Godot headless, outros Godots pausados
| Rodada/ordem | Modo | P50 frame ms | P95 frame ms | P95 fisica ms | Falhas |
|---|---|---:|---:|---:|---:|
| R1 primeiro | LOD default | 14.382 | 31.881 | 30.941 | 0 |
| R1 segundo | Legacy | 14.109 | 30.603 | 21.318 | 0 |
| R2 primeiro | Legacy | 14.095 | 30.670 | 20.855 | 0 |
| R2 segundo | LOD default | 13.923 | 30.948 | 20.557 | 0 |

Leitura: **sem demonstracao consistente de ganho de performance**. P95 frame muito proximo na R2, e o grande pico de fisica LOD na R1 nao se repetiu. Estas execucoes nao sao renderizadas a 1080p e nao provam FPS na GTX1650. Otimizacoes de IA nao eliminam o custo de `move_and_slide`, Jolt, hitboxes ou criacao de corpos.

### Multiplayer — bloqueado no teste de entrada, antes de bots existirem
- Duas execucoes `tests/run_favela_network.py --script tests/favela_online_bot_qa.gd`, servidor e dois clientes reais: **NAO PASSOU**. Em ambas, `humans=0`, `bots=0` no servidor e timeout de baseline nos clientes. Primeira mostrou erro mbedTLS -0x7700; segunda passou `--game-tls-host=localhost` para QA, eliminando o erro nativo observado, mas nao resolveu a admissao dos clientes.
- Certificado QA estava valido e inclui SAN localhost e 127.0.0.1. Isolamento do transporte: `tests/rpg_range_dtls_probe.gd` **8/8 PASS**, com socket DTLS loopback, recebimento de pacote e verificacao de payload. Isto **nao** equivale ao full-map ENet.
- Sem bots spawnados, nao ha evidencias de regressao do LOD no protocolo multiplayer; mas a homologacao multiplayer completa continua **pendente**.
- O runner QA ganhou a opcao `--game-tls-host=localhost` de teste. Nao alteramos o transporte de producao.

### Decisao da integracao
- O LOD passa a ser **default apenas nesta branch de homologacao**. `--war-bot-ai-lod-legacy` continua disponivel para retorno instantaneo ao agendador anterior durante QA.
- **Nao mesclar em `main`, nao publicar a build** ate confirmar multiplayer com bots no mapa real e medir ao menos um par A/B grafico 1080p GTX1650 sem concorrencia. Nao atribuir o timeout de rede ao LOD sem evidencias.

### Regressao de pressao real de bots na Favela
- `tests/favela_bot_pressure_qa.gd` foi executado com LOD default e legacy; o QA **antigo** falhou em ambos apenas na assercao de cinco objetivos simultaneos: `WarFavelaFrontline.enabled(FAVELA)` agora concentra a frente sequencial em C.
- Atualizada somente a assercao do teste para permitir um unico setor C na Favela; nenhum sistema de objetivos, movimento ou IA de producao foi alterado para contornar o teste.
- Com QA alinhado ao modo sequencial, `FAVELA_BOT_PRESSURE_RESULT {"ok":true,"failures":[],"strong_progress":4}`; `FAVELA_PRESSURE_ADAPTED_EXIT=0`. Testou 28 bots, 4 aproximacoes fortes, 300 ticks de linha de visao, ataque e retencao de defesa. A menor frequencia de decisoes nao bloqueou pressao de objetivos neste cenario.
