# P1b — protótipo de CollisionRig separado da apresentação

**Data:** 04/11/2026  
**Versão local:** 1.13.1 — Godot 4.7.2  
**Status:** cena de teste e código de protótipo **implementados**. **Não integrado à física autoritativa, não publicado, não ativado por padrão.**

## Mudança concreta

Arquivos:
- `modes/war/scripts/collision_pose_state.gd` — captura leitura pura das transforms de 16 regiões físicas possíveis, cano, arma, postura, pitch/lean, life e física; comparação de posição e orientação em coordenadas do ator.
- `modes/war/scripts/collision_rig_proxy.gd` — um `Node3D` independente que replica a hierarquia com até 16 `Area3D` próprios e `CollisionShape3D` com shapes e transforms copiados; armazena `CollisionMuzzle`.
- `tests/true_fpp_p1a_collision_snapshot.gd` — compara a pose física do próprio ator ao trocar câmera, três posturas, e garante que a pose reage ao pitch/lean.
- `tests/true_fpp_p1b_collision_rig_proxy.gd` — constrói rig físico paralelo no fixture `WarGame`, faz espelhamento da pose, valida o erro por região e cano.

O protótipo físico é independente na **estrutura** (`Area3D` não são filhos de `MeshInstance3D`); shapes estão intencionalmente **desabilitados e com `collision_layer=0`**, para impedir dois alvos de tiros por jogador. Isso é uma prova de arquitetura, não uma alteração de gameplay.

## Testes realizados

`true_fpp_p1b_collision_rig_proxy.gd`: **passou**, exit 0; **16 regiões físicas**, erro de posição e do cano **0 m** em standing/crouch/prone, sem regiões ausentes; ocultar `body_root` não muda as transforms do proxy. A cópia contém shapes mas não participa da física. Relatório `work/fpp-tpp-p1a-20261104/collision-rig-proxy-qa.json`.

`true_fpp_p1a_collision_snapshot.gd`: **passou**, exit 0; três posturas com mesmas transforms ao mudar câmera FPP/TPP do observador; alterar pitch/lean move hitboxes e cano, como esperado. Relatório `work/fpp-tpp-p1a-20261104/collision-snapshot-qa.json`.

As regressões da P1a anterior após rollback também passaram: `true_fpp_p1a_authority_hitboxes` 5/5, `prone_weapon_pose_validation` 1126/1126, `optics_universal_validation_20261103` 242/242 headless, e o microbenchmark legado continuou próximo da referência (3,74 ms em lote de 28 G3 no último ensaio).

## O que NÃO está implementado

O `CollisionRigProxy.sync(frame)` recebe a pose **já calculada pelo rig visual**, logo ainda não reduz o custo CPU da pose: usa um espelhamento de dados apenas como prova. O `WarPlayer` de produção não instancia esse proxy. Nenhuma hitbox autoritativa foi movida da árvore atual. O servidor não o utiliza para aceitar projéteis, e o cano real também permanece igual.

Os dois experimentos preliminares (Lite e por eventos) foram rejeitados por custo e **revertidos byte a byte** no gameplay. [Relatório e tabelas](FPP-TPP-P1A-COLLISION-LITE-EXPERIMENT-20261104.md). O piloto full anterior só existe com flag QA `--true-fpp-p1a-authority`, off por padrão.

## Próximo trabalho para concluir a P1b

1. **Solver físico puro**, sem referência às transforms visuais: decompor torso/cabeça, braços, mãos, coxas/canelas/pés e muzzle em fórmulas compartilhadas extraídas da matemática atual de `WarStance`, `GameInfantryPose`, `WarLocomotion` e `WarHumanRig`, a partir de um `PoseFrame` imutável por tick.
2. Comparar solver e rig antigo com `WarCollisionPoseState.compare`, em sequências de movimento e não só quadros parados. Testar mortes por região, hitboxes em servidor dedicated/listen, render por LOD 8/15/30 Hz, distâncias 10/70/150/300/1700 m.
3. Medir p50/p95/p99 e memória de 28 atores sem render, depois 1080p com 28 bots, antes de mover a autoridade dos `Area3D` para o novo rig.
4. Após o gate de equivalência e custo, fazer **swap atômico dos colliders** de um G3 em piloto reversível: antiga árvore passa a não-colidir e a nova a colidir, sem as duas simultaneamente. Validar spectator/anti-cheat, FPP/TPP, quinas/janelas, prone/lean, optics/ragdoll e rede.
5. Só depois iniciar G3 corpo único FPP/TPP.

**Nenhuma atualização foi lançada.**
