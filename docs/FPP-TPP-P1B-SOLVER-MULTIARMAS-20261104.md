# P1b — Solver físico multiarmas, primeiro pacote

**Data:** 04/11/2026
**Plano principal:** [FPP-TPP-CORPO-UNICO-PLANO-20261104.md](FPP-TPP-CORPO-UNICO-PLANO-20261104.md)
**Plano Squad:** [REALISMO-TATICO-PLANO-SQUAD-20261104.md](REALISMO-TATICO-PLANO-SQUAD-20261104.md)
**Estado:** código e QA preparados em **branch exclusiva**, sem ativar no `WarPlayer` real; nenhum release/merge realizado.

## Escopo entregue

`modes/war/scripts/collision_pose_solver.gd` passou de um modelo com offsets fixos do G3 para um **solver matemático por arma** (G3, AK, FAL, Glock, sniper). O binding lê **uma vez** o modelo, os sockets/pose de mãos, as referências de cano, a anatomia das regiões `Area3D` e o repouso das pernas. `solve(bindings, state)` não lê nós, câmera, cena, materiais, raycasts ou estado do servidor; produz transforms locais de 16 regiões e do cano a partir dos dados de calibração e do estado de mira e postura.

A conta do G3 utiliza a posição neutra da mão esquerda na calibração para respeitar seu grip visual atual. Os offsets do braço/cano passam a ser próprios de cada arma; Glock usa o cuff de pistola e AK o basis definido por `GameAKReload.hand_basis`. A postura crouch considera deslocamento vertical do corpo, flexão de coxa/joelho/tornozelo, lean e correção de -0,05m do cano, sem consultar nodes durante `solve`.

**A calibração exige personagem equipado e em pose neutra**. Fazer binding durante recarga, movimento ou com óptica já levantada não está homologado; esse cenário deve ser rejeitado pelo futuro integrador. Isso não é prova de animação universal nem substitui os sockets definitivos.

## Verificações reais nesta worktree

- `tests/true_fpp_p1b_collision_math_arsenal.gd`: **50/50 testes passaram** — 5 armas x (standing e crouch real) x 5 combinações de pitch/lean. Para cada arma 16 regiões físicas e cano. As cápsulas de crouch foram verificadas (shape baixo e `stance.crouch_weight=1.0`).
- Máximo global da diferença de *posição* entre solver e rig existente: **0,0000031m** (~0,0031mm); diferença do cano abaixo de **0,0000028m** (~0,0028mm).
- Maior diferença de vetor de base: **0,0315** (adimensional, não tratar como ângulo ou prova de rotação idêntica); aprovado apenas para a tolerância experimental `basis_delta<0.05`.
- **30/30 condições rejeitadas corretamente**, contemplando prone, movimento, recarga, PiP, ação especial e incompatibilidade entre arma equipada e calibração.
- `tests/true_fpp_p1b_collision_math_standing.gd`: PASS (5 poses do G3).
- `tests/true_fpp_p1b_collision_rig_proxy.gd`: PASS (16 regiões, 3 posturas, proxies com colisão desativada).
- `tests/true_fpp_p1a_collision_snapshot.gd`: PASS (3 posturas, troca de observador sem alterar pose).
- `tests/prone_weapon_pose_validation.gd`: **1126/1126**, PASS; este é o **rig antigo**, não o novo solver em prone.
- `tests/optics_universal_validation_20261103.gd`: **242/242**, PASS **headless**; não comprova o PiP no novo solver.
- `git diff --check`: PASS.

### Microbenchmark isolado

Para cada arma o fixture executa 76 lotes com 28 `solve` serializados (8 lotes de aquecimento, 68 medidos), alterando pitch/lean sem animação visual.

| Arma | p50 / 28 cálculos | p95 | p99 |
|---|---:|---:|---:|
| G3 | 1,224 ms | 1,658 ms | 2,059 ms |
| AK | 1,286 ms | 1,585 ms | 1,802 ms |
| FAL | 1,095 ms | 1,710 ms | 1,901 ms |
| Glock | 1,164 ms | 1,547 ms | 1,806 ms |
| Sniper | 1,133 ms | 1,443 ms | 1,493 ms |

**Limite:** 28 chamadas com a mesma geometria calibrada e estados diferentes, **não** 28 jogadores com cenas, GDExtension, servidor ENet, animação visual, IA, hitboxes ativas e GPU. Não afirmar melhoria de FPS ou menor custo da versão de produção com estes números.

## Segundo pacote — prone e locomocao

A continuidade da P1b ampliou o solver para **prone estavel e locomocao ativa** sem leitura de nodes durante `solve()`. O estado agora carrega postura, contato com o solo, fase da passada, direcao local e os pesos de marcha/sprint; a geometria de pe e os bounds das botas continuam sendo calibrados apenas no `bind()`.

Validacoes desta rodada:

- **25/25 poses prone**: 5 armas x 5 combinacoes de pitch/lean.
- **60/60 poses de movimento**: caminhada, corrida, deslocamento agachado e rastejamento, com 3 fases de passada por modo e 5 armas.
- As pernas foram verificadas como realmente variando entre amostras; o teste nao aceita uma pose estacionaria repetida como locomocao valida.
- Tolerancias reforcadas: erro de posicao de regiao e cano abaixo de **1 mm**, e `basis_delta < 0.005`. Os resultados observados ficaram na ordem de poucos milesimos de milimetro.
- **25/25 rejeicoes de movimento inseguro** adicionais: sem contato com solo, membros inferiores incapazes, ADS ativo e disparo em cooldown continuam fora do contrato do solver.
- O prone respeita o clamp real de mira de `WarPlayer` em `-0.38 rad`; valores externos abaixo disso nao deslocam o cano para uma pose que o jogo nunca permite.
- Foi encontrado e corrigido um bug preexistente no rig atual: ao levantar diretamente do prone, `Pelvis.rotation.x` permanecia em `-PI/2`, deixando `abdomenPelvis` orientado 90 graus. O teste `true_fpp_p1b_pelvis_upright.gd` cobre `2 -> 0` e `2 -> 1 -> 0` com restauracao exata.
- Suite completa da rodada: `true_fpp_p1b_pelvis_upright`, `true_fpp_p1b_collision_stance_motion`, `true_fpp_p1b_collision_math_arsenal`, `true_fpp_p1b_collision_math_standing`, `true_fpp_p1b_collision_rig_proxy`, `true_fpp_p1a_collision_snapshot`, `prone_weapon_pose_validation` (**1126/1126**) e `optics_universal_validation_20261103` (**242/242**) — todas com exit 0.

### Microbenchmark de movimento

Fixture isolado com 28 estados sinteticos em movimento por lote, 8 lotes de aquecimento e 68 medidos:

| Arma | p50 / 28 solves | p95 | p99 |
|---|---:|---:|---:|
| G3 | 2,155 ms | 3,242 ms | 3,534 ms |
| AK | 1,725 ms | 2,384 ms | 2,475 ms |
| FAL | 1,841 ms | 2,792 ms | 3,269 ms |
| Glock | 1,880 ms | 2,375 ms | 2,750 ms |
| Sniper | 1,749 ms | 2,069 ms | 2,389 ms |

Isto ainda **nao** e custo de 28 personagens reais. Nao inclui entidades, broadphase, rede, IA, audio, renderizacao ou atualizacao de `Area3D`.

## P1c — soft aim e mira de ferro

O solver agora aceita `aiming` e `iron_sights` **somente quando nao ha modulo optico ativo**. No rig atual, a mira de ferro sem luneta usa o mesmo `weapon_root` autoritativo e apenas suprime o sway de marcha; por isso o solver reproduz essa regra diretamente. Qualquer ADS com optica continua bloqueado para o pacote de PiP/lente real.

- `tests/true_fpp_p1c_collision_ads_iron.gd`: **90/90 poses** — 5 armas x 3 posturas x 2 modos (soft aim/iron) x 3 fases de movimento.
- **10/10 casos de ADS optico rejeitados** de forma explicita.
- Tolerancia do gate permanece abaixo de 1 mm em posicao/cano e `basis_delta < 0.005`; os erros observados ficaram novamente na ordem de milesimos de milimetro.

## P1d — recarga fisica multiarmas

A recarga passou a ser reconstruida a partir do **timer autoritativo** e de `GameReloadPose.state()`, que ja e uma funcao pura. O `bind()` calibra uma vez a transformacao neutra do modelo, os grips e o cano. Durante `solve()`, nenhuma consulta a `Node3D` e feita: o solver recompõe a transformacao local do modelo, as duas maos, o basis da empunhadura e o cano conforme `reload_left/reload_total`.

Regras especificas preservadas:

- FAL, G3 e Glock acompanham a rotacao/translacao do modelo procedural e o ponto de mao de apoio da timeline.
- AK usa os pontos `hand/right_hand` e o basis relativo de `GameAKReload`.
- Sniper mantem o basis das maos alinhado ao `weapon_root` enquanto o rifle importado se move, igual ao rig atual.
- O cuff da mao esquerda troca para a pegada de magazine/ferrolho apenas nas fases em que `hand_grabbing` esta ativo.
- O cano acompanha o modelo durante a recarga em todas as cinco armas.

`tests/true_fpp_p1d_collision_reload.gd`: **150/150 poses** — 5 armas x 3 posturas x parado/movimento x 5 pontos de progresso da recarga. Mais **10/10 estados invalidos** rejeitados por arma/calibracao incompatível ou timer invalido. Gate: <1 mm em posicao/cano e `basis_delta < 0.005`; os erros observados ficaram em poucos milesimos de milimetro.

## Etapas que continuam bloqueadas

1. **P1b restante:** PiP/ADS óptico, tiros entre ticks, transições intermediárias de postura e equipamento especial. Standing, crouch, prone estável, caminhada, sprint, rastejamento, soft aim, iron sights sem óptica e recarga já têm paridade matemática nos fixtures atuais.
2. **Integração física real:** `collision_rig_proxy.gd` ainda recebe pose do rig visual e mantém shapes desligados. O solver multiarmas **não** está conectado a `WarPlayer`, nem as hitboxes autoritativas foram transferidas. Antes do swap, medir `CollisionPose` real 60 Hz x `PresentationPose` 8/15/30 Hz e comparar runtime sob carga.
3. **Combate:** ainda não foram homologados disparo aceito, cobertura em quinas/janelas, dano por membro, ragdoll e 2 clientes exportados. Nenhum protocolo de rede ou anti-cheat foi mudado.
4. **P2 e seguintes:** true FPP/câmera, integração de PiP na arma real, remoção de `view_root` e migração de gadgets, BR e outros modos seguem pendentes. Não apresentar a P1b como corpo único final.

## Segurança e integração

Esta branch altera o solver isolado, testes P1b-P1d, este documento e uma correção pontual em `modes/war/scripts/stance.gd` para restaurar a pelve ao sair do prone. Não toca em `scripts/player.gd`, `modes/war/scripts/player.gd`, `main.gd`, `project.godot`, `weapon_optics.gd`, protocolo de rede nem modelos editados por outras IAs.

**Próximo pacote recomendado:** modelar PiP/ADS óptico na arma real sem renderização dentro do solver; depois adicionar baseline de 28 bots no listen-server/dedicated, cobertura em quinas/janelas e somente então habilitar um piloto controlado do CollisionRig sob flag. Integrar branch atual por revisão; não publicar.
