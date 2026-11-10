# Piloto de LOD tatico dos bots — 10/11/2026

## Objetivo
Reduzir custo de percepcao, roteamento e tomada de decisao dos bots *fora de combate*, sem tocar em locomocao, colisoes, hitboxes, cadencia fisica, disparos, dano, visibilidade real, ragdolls e replicacao ENet/DTLS.

Branch: `ia/bot-ai-lod-pilot-20261110`, base main local `85cc9d1`.

## Descobertas
- A Guerra ja usa AStarGrid2D para rotas locais, AStar2D para malha rodoviaria, AStar3D para lajes, cache de rotas (~1.25 s).
- O diretor ja distribui **40 chamadas _think por segundo**, com um bot por vez; `_avoid`/LOS sao consultados nessa cadencia, nao por bot a 60 Hz.
- `GameStepMotion` usa CharacterBody3D/move_and_slide e test_move para degraus.
- `DeathRagdoll` ja implementa ossos fisicos proprios usando RigidBody3D e ConeTwistJoint3D; nao usar PhysicalBone3D em paralelo.
- Bots usam separacao local de aliados por indice espacial e rotas/escape em obstaculos; `NavigationObstacle3D` nao substitui planejamento global e exige mapa de navmesh apropriado.
- Pose LOD visual por distancia ja existe (33/66/125 ms em WarPlayer). Isso nao e LOD de tomada de decisao.

## Piloto implementado, DESLIGADO POR PADRAO
Flag apenas para testes: `--war-bot-ai-lod-pilot`.
Mantem o limite duro de no maximo uma decisao por 25 ms, usando round-robin. A consulta de proximidade e somente distancia ao inimigo (nenhum raycast extra).

- Combatendo, em veiculo, abatido/nao implantado, defendendo proximo do objetivo ou a ate 200m de qualquer inimigo ativo: intervalo minimo 0.25 s (sujeito ao limite global de 40/s).
- Entre 200 e 350m de um inimigo ativo, nao engajado: intervalo minimo 0.55 s.
- Sem inimigos proximos (>350 m) e longe de objetivo: intervalo minimo 1.0 s.
- O bot continua andando, sofrendo fisica e replicando sua posicao nos ticks existentes. Apenas `_think` e adiado.
- Estado `ai_lod_next` descartado em `reset()`. `setup()` le a flag; sem flag o codigo anterior segue identico.
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
- Teste de algoritmo e seleção real `tests/bot_ai_lod_qa.gd`: **24/24 PASS**, incluindo seleção no WarBotDirector com dois personagens na SceneTree, wake imediato ao engajamento, configuração default-off e simulações de 12/28 bots.
- Regressão de combate/locomoção `tests/war_bot_escape_armor_qa.gd`: **10/10 PASS**, `ESCAPE_EXIT=0`, rota evita barreira e bot reage ao APC procurando cobertura.
- Simulação de 28 bots por dez segundos mostra teto de 400 decisões em combate e 280 decisões quando todos estão distantes; distribuição justa entre IDs. Isso mede **somente a lógica de agendamento**, não FPS ou benefício CPU real.
- Testes de multiplayer, envelhecimento de percepções, combate completo, 0/12/22/28 bots e benchmark gráfico GTX1650: **pendentes**. Branch não pode ser mesclada ou publicada ainda.

## Por que não ativar de imediato
A economia teórica de `_think` varia com quantos bots estão em combate; quando muitos exigem resposta rápida o teto global continua em 40/s. Além disso, um bot sem alvo conhecido pode levar até 1 segundo para notar aproximação inimiga distante. O ganho e os efeitos táticos precisam ser demonstrados na mesma cena com e sem flag.
