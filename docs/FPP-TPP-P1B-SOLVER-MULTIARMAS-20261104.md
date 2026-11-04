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

## Etapas que continuam bloqueadas

1. **P1b restante:** solver de prone, gait/locomoção, sprint, recarga, ADS e PiP, tiros entre ticks e equipamento especial. Cada etapa exige equivalência de transforms, não basta que a arma renderize.
2. **Integração física real:** `collision_rig_proxy.gd` ainda recebe pose do rig visual e mantém shapes desligados. O solver multiarmas **não** está conectado a `WarPlayer`, nem as hitboxes autoritativas foram transferidas. Antes do swap, medir `CollisionPose` real 60 Hz x `PresentationPose` 8/15/30 Hz e comparar runtime sob carga.
3. **Combate:** ainda não foram homologados disparo aceito, cobertura em quinas/janelas, dano por membro, ragdoll e 2 clientes exportados. Nenhum protocolo de rede ou anti-cheat foi mudado.
4. **P2 e seguintes:** true FPP/câmera, integração de PiP na arma real, remoção de `view_root` e migração de gadgets, BR e outros modos seguem pendentes. Não apresentar a P1b como corpo único final.

## Segurança e integração

Esta branch altera **somente um solver isolado, um teste e este documento**; não toca em `scripts/player.gd`, `modes/war/scripts/player.gd`, `main.gd`, `project.godot`, `weapon_optics.gd`, gameplay nem modelos editados por outras IAs.

**Próximo pacote recomendado:** expandir o solver para prone/locomoção, adicionar baseline de 28 bots no listen-server e dedicated, testar cobertura e habilitar piloto controlado de CollisionRig sob flag somente após passar esses gates. Integrar branch atual por revisão; não publicar.
