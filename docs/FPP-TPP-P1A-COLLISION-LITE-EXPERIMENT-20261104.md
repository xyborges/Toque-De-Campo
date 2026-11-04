# P1a — Experimentos de CollisionPose leve e contrato físico

**Data:** 04/11/2026  
**Projeto:** Toque de Campo 1.13.1, Godot 4.7.2  
**Estado:** INVESTIGAÇÃO EXECUTADA, SOLUÇÕES CARAS REJEITADAS, CÓDIGO DO GAMEPLAY RESTAURADO. **Não houve ativação nem publicação.**  
**Planos:** [Unificação FPP/TPP](FPP-TPP-CORPO-UNICO-PLANO-20261104.md) · [P1a anterior](FPP-TPP-P1A-PILOTO-20261104.md) · [Realismo tático](REALISMO-TATICO-PLANO-SQUAD-20261104.md).

## Objetivo

A P0 confirmou que no *listen-server* o LOD de animação remota pode deixar pivôs físicos defasados. As hitboxes `Area3D` hoje são filhas de `MeshInstance3D` de membros, tórax, cabeça, mãos, joelho e canelas. Atualizar a pose procedural inteira com frequência fixa resolve o defeito no teste, mas tem alto custo (~7,53 ms de média no lote de 28 personagens G3).

Esta rodada tentou dois intermediários **sem alterar dano ou disparo**:

1. **`WarCollisionPoseLite`** nos quadros de animação pulados: usa a hierarquia atual, posiciona postura e arma, resolve braços/hitboxes, mas evita selecionar novas malhas de luva e atualizar objetos decorativos. Inclui fallback para granadas, lançadores, água, melee e utilidades.
2. **Gatilho por mudança de pose**: força a pose completa quando stance, pitch, lean, reload ou arma mudam, mantendo o LOD quando o estado está próximo da última pose física.

## Resultado dos benchmarks isolados — NÃO FPS do jogo

Fixture `tests/true_fpp_p1a_28_pose_cost.gd`: 28 atores G3 em host, 120 amostras ao ritmo de `physics_frame`, alguns com postura, movimento, mira e lean alterados. Valores estão sujeitos a variação por carga/temperatura. Ambos os novos candidatos usaram o mesmo teste e flag específica.

| Caminho | Média 28 atores | P95 | P99 | Decisão |
|---|---:|---:|---:|---|
| LOD anterior (P1a original) | 3,387 ms | 11,501 ms | 12,780 ms | Referência; preservado |
| Full 60 Hz da P1a anterior | 7,526 ms | 10,465 ms | 11,289 ms | Corrige o teste, caro, permanece desativado |
| Lite, primeira rodada | 10,566 ms | 14,497 ms | 18,746 ms | Rejeitado |
| Lite com instrumentação | 9,716 ms | 11,754 ms | 13,218 ms | Rejeitado |
| Por evento, qualquer delta | 7,830 ms | 10,873 ms | 12,479 ms | Rejeitado |
| Por evento com limiares de 0,005 stance / 0,025 pitch / 0,020 lean | 7,191 ms | 14,119 ms | 16,619 ms | Rejeitado |

**Por que Lite foi mais lento:** atualizar a hierarquia atual ainda chama `GameInfantryPose.apply`, `WarStance.pose`, `_update_weapon_pose` e `WarHumanRig.pose` (mãos, antebraço, arma e colisor no mesmo conjunto). No ensaio instrumentado, custos médios por invocação da versão Lite foram aproximadamente: corpo 34 µs, stance 52 µs, arma 69 µs, braços 95 µs. Tirar algumas escritas cosméticas NÃO desassocia a física do visual.

**Por que por evento não resolve:** no combate, pitch/lean e o movimento das pernas variam frequentemente. Desativar atualização de hitboxes nesses quadros gera erro acumulado; permitir atualização frequente faz retornar o custo de pose completa.

## O que passou em teste

- Lite e event-based, nas condições controladas do `true_fpp_p1a_authority_hitboxes.gd`: 13 regiões por personagem, cinco distâncias 10/70/150/300/1700 m, prone total e seis ticks de transição, alternância de câmera do observador: **0 mm** de diferença quando comparado à pose completa imediatamente recalculada; **isso não demonstra ausência de erro em movimento real entre amostras**.
- Nenhum desses protótipos removeu ou adicionou `Area3D` a um personagem real de produção.
- Uma ferramenta nova **independente da apresentação** foi criada: `modes/war/scripts/collision_pose_state.gd`. Ela captura transformações das regiões físicas, do cano, postura, inclinação, vida e arma em coordenadas do ator, sem alterar gameplay. `compare(a,b)` reporta maiores erros de posição e base e regiões faltantes.
- `tests/true_fpp_p1a_collision_snapshot.gd` passou: três posturas (standing, crouch, prone) com paridade física entre perspectivas do observador; mover pitch/lean gerou movimento mensurável na região de acerto e cano. Relatório `work/fpp-tpp-p1a-20261104/collision-snapshot-qa.json`.

## Decisão técnica e rollback

**Os dois novos algoritmos de runtime foram descartados.** Após medições, foram restaurados **byte a byte** os arquivos do início da rodada:
- `modes/war/scripts/player.gd` (mantém somente a **flag QA da P1a anterior** `--true-fpp-p1a-authority`, off por padrão);
- `modes/war/scripts/human_rig.gd`;
- `modes/war/scripts/stance.gd`.

O módulo experimental Lite saiu de `modes/war/scripts/` e está preservado apenas como `work/fpp-tpp-p1a-lite-20261104/collision_pose_lite.gd.experimental.txt`, junto a cópias das edições descartadas e scripts de QA experimentais. Os relatórios JSON de benchmark e QA foram mantidos para análise. Os testes normais `true_fpp_p1a_authority_hitboxes.gd` e `true_fpp_p1a_28_pose_cost.gd` foram restaurados para a flag anterior. O jogador atual não recebe a implementação descartada.

## Protótipo P1b implementado após o rollback

A estrutura de [CollisionRigProxy](FPP-TPP-P1B-COLLISION-RIG-PROXY-20261104.md) foi construída com 16 `Area3D` e shapes isolados dos meshes. Teste passou (três posturas, 0 m de erro), **mas recebe snapshots do rig atual** e não otimiza gameplay. Sua inclusão apenas como módulo separado sem uso em produção é a base do futuro solver de baixo custo.

## Próxima implementação real — P1b CollisionRig

**Não repetir Lite sobre os nós atuais.** Fazer uma hierarquia física própria com **mesmos shapes e nomes de região**, desacoplada de `MeshInstance3D`; um solver puro calcula transformações físicas de 13–16 segmentos por `physics_frame`, sem material, malha, câmera, som, óptica nem duplicatas FPP. A apresentação de `Skeleton3D`/rig procedural apenas lê a mesma pose e poderá ser atualizada por LOD independente.

Sequência técnica recomendada:
1. Criar `CollisionRig` autônomo **em cena de teste**, com `Node3D` e `Area3D` equivalentes à árvore de hitboxes da versão atual; não reparent em produção até QA.
2. Extrair da matemática de `WarStance`, `GameInfantryPose`, `WarLocomotion` e `WarHumanRig` um `CollisionPoseFrame` de transforms (head/torso/pelvis, upper/lower arms, mãos, coxas/canelas/pés) e muzzle. **Uma única fonte de cálculo.**
3. Medir a equivalência de transforms de cada região com `WarCollisionPoseState.compare`, com 0,5–2 cm iniciais de tolerância em estados de movimento e coincidência exata em estado parado/mesmo tick.
4. Somente se ficar independente, testar física de 60Hz + render 8/15/30Hz e avaliar custo. Ao comparar, manter o desenho do corpo remoto e a autoridade do cano coherentes.
5. Inserir *feature flag* e gate por arma; G3 primeiro, FAL/AK/Glock/sniper após. Não alterar dano de membros, municão, loot/spawns, óticas PiP, câmera ou protocolos até equivalência aprovada.
6. Repetir 28 bots, listen host, dedicated headless, ENet 2 clients, rig FPP/TPP, ragdoll, morte, prone/lean, veículo, janela/quina, 4x/8x.

**Status honesto:** P1b foi preparada com um contrato de snapshot e testes; **CollisionRig físico independente AINDA NÃO FOI IMPLEMENTADO**. Nenhum ganho de FPS foi alegado, e nenhuma atualização foi distribuída.
