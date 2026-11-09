# Realismo R2C — piloto de quadril/tronco no corpo TPP

**09/11/2026 | Projeto Godot Toque de Campo | Branch `ia/realismo-r2c-world-20261109`**

**Estado: protótipo executável OFF por padrão, gates locais PASS, NÃO homologado para multiplayer, bots, R2C física completa ou produção.**

## Origem e objetivo

Esta branch parte de `origin/main ce2653e` e traz seletivamente os sete commits de R1A/R1B/R1C/R2A/R2B, sem misturar benchmarks de outras branches ou trabalhos paralelos. O contrato puro R2A já fornece `hip_offset`, `hip_angles` e `torso_angles`. Aqui o R2C-0 aplica o resultado **uma única vez ao corpo do jogador local em terceira pessoa**, em um quadro físico, sem relógio paralelo, depois da pose-base e antes de resolver a arma e IK das mãos.

O modelo 3D da G3 não foi modificado. A capacidade e o limite temporário de 11 bots por equipe também não foram modificados; a investigação da física/poses segue em `ia/bot-physics-pose-jj7-20261109`.

## Implementação

1. `modes/war/scripts/tactical_world_body.gd`: adaptador com gate estrito que usa as funções puras de R2A para aplicar pequenos deslocamentos e rotações em `Pelvis` e `Torso`. As regiões de dano são descendentes desses pivôs e se deslocam junto com a malha, não há collider paralelo.
2. `modes/war/scripts/locomotion.gd`: terceira flag `tactical_world_pilot`, estado da transformação anterior do quadril e função de restauração. Sem cálculos nem transformações de mundo quando o piloto está desligado.
3. `modes/war/scripts/player.gd`: chamada R2C depois de `GameInfantryPose.apply` / `stance.pose`, **antes da arma real e das mãos**; restauração exata do quadril antes de cada reconstrução e nos estados de morte/veículo/água que não passam pela animação habitual.
4. `tests/realismo_r2c_world_pilot.gd`: gates, idempotência, ativação/desativação, câmera, cano, arma real, cápsula e regiões de dano.

A primeira versão detectou um erro real: `GameInfantryPose.apply()` restaura só o eixo Z da rotação do `Pelvis`; a adição R2C nos eixos X/Y acumulava desvio. Isso foi corrigido **guardando e restaurando o `Transform3D` anterior completo**, e não zerando a rotação, preservando qualquer postura legítima já existente.

Amplitude nominal máxima do contrato: quadril X até 1,4 cm, Y até 1,2 cm (pouso), Z até 0,6 cm, pequenas rotações; torso compensado com limites R2A de poucas centésimas de radianos. Nenhuma escrita adicional em `CharacterBody.velocity`, cápsula `BodyCollision`, `weapon_root`, `muzzle_marker`, câmera, protocolo ou projéteis.

## Flags e limites de ativação

As **três** condições são exigidas:

```text
TDC_TACTICAL_MOTION_PILOT=1
TDC_TACTICAL_BODY_PILOT=1
TDC_TACTICAL_WORLD_PILOT=1
```

Ou respectivamente `--tactical-motion-pilot --tactical-body-pilot --tactical-world-pilot`. Padrão de todas as flags OFF.

Mesmo com flags ON, R2C-0 exige **WarPlayer local, offline, TPP, G3, vivo, implantado, em pé, a pé e livre de ações concorrentes**. FPP, personagem remoto, bot, sala online, crouch/prone, ADS, disparo/cooldown, recarga, gadget, granadas, melee, binóculo, veículo, água, morte e respawn não ativam o adaptador. FPP R2B continua sendo outra camada.

**Por quê?** Na base atual os `Area3D` de dano continuam sob pivôs visuais. A atualização visual remota sofre LOD, e os sinais R1 de aceleração/pouso são apresentados só para o ator local. Habilitar essa pose em um cliente online sem um `PoseFrame` físico autoritativo transmitido/simulado em ambos os lados cria discrepâncias balísticas. A versão em jogo não autoriza isso.

## Resultados reproduzidos em DESKTOP-JJ7U3G3

Godot 4.7.2, scripts em headless (código de saída zero), sem uso concorrente de outra execução Godot:

| Suite | Resultado |
| --- | ---: |
| **R2C-0 quadril/tronco físico/TPP** | **105/105 PASS** |
| R2A contrato puro | 33/33 PASS |
| R2B G3 FPP | 93/93 PASS |
| R1A longitudinal | 8/8 PASS |
| R1B lateral | 13/13 PASS |
| R1C pouso | 16/16 PASS |
| R1C pouso físico 1,15 m | 10/10 PASS |
| Ópticas universais | 242/242 PASS |
| **Total** | **520/520 PASS** |

No R2C, a diferença OFF/ON foi confirmada nas transforms de pelve e tronco e nas regiões `chest` e `abdomenPelvis`. Os offsets da área em relação ao próprio pivô ficaram invariantes; arma de mundo, cano verdadeiro, câmera e cápsula ficaram idênticos. O gate bloqueou FPP, remoto, online, bot e ações concorrentes. Repetições e desativação restauraram exatamente a base sem drift.

**Atenção à importação:** uma importação fria `godot --editor --headless --quit` encerrou com access violation `-1073741819`, mas registrou a nova classe e os testes runtime acima funcionaram, sem erro de parser. Esse crash do editor NÃO está resolvido e é motivo adicional para não promover a branch sem uma importação limpa.

`git merge-tree --write-tree origin/ia/fpp-p1k-physical-replacement HEAD` terminou com **exit 0**, sem conflito textual na simulação. Isso **não** demonstra equivalência física, runtime híbrido nem desempenho; misturar essas branches completas traria também divergências históricas de release. Não houve merge de P1k, nem alterações no `main`.

## Próximos gates para R2C física e multiplayer

1. Definir um `PoseFrame` físico que todos os atores, bots e clientes possam calcular a 60 Hz com os mesmos sinais do servidor e o mesmo instante de contato.
2. Integrar com o CollisionRig P1k **somente** após uma equivalência real das 16 regiões, head/chest/pelvis, hitboxes, dano, IK, mira/cano, mudança FPP/TPP, stance standing→crouch→prone, granada, veículos, morte, ragdoll e LOD remoto.
3. Executar tiros e geometria em 0–1700 m numa partida multiplayer real (ENet/DTLS), sem aumentar o trabalho físico por bot de forma proibitiva.
4. Realizar benchmark A/A e A/B pareado no GTX 1650, 1080p Médio 100%, 0/12/22/28 bots, 5 pares de 60 s com foco 100% e P95/P99, física, GPU e memória. Não basta passar QA de transforms.
5. Resolver o crash de importação e revisar visualmente braços, ombros e caixa torácica durante strafe, pouso e mudança de perspectiva.

**Decisão atual:** manter R2C-0 opt-in e isolado. A redução do número de bots de 28 para 22 é uma configuração provisória, não substitui otimização da física. Esta branch não contém autorização de release nem merge para `main`.
