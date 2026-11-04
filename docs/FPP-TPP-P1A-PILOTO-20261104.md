# FPP/TPP — P1a, piloto de pose física autoritativa

> **Avaliação adicional, 04/11/2026:** [experimentos Lite/event e contrato de snapshot](FPP-TPP-P1A-COLLISION-LITE-EXPERIMENT-20261104.md). Esses novos experimentos foram revertidos após benchmark desfavorável; o piloto full anterior mantém sua flag QA desligada por padrão. Nenhum código de combate mudou.

**Data:** 04/11/2026  
**Projeto auditado:** Toque de Campo 1.13.1, Godot 4.7.2  
**Status:** PILOTO IMPLEMENTADO E VALIDADO EM FIXTURE. **DESABILITADO POR PADRÃO**, por custo CPU. **Não publicado.**  
**Planos relacionados:** [Plano FPP/TPP](FPP-TPP-CORPO-UNICO-PLANO-20261104.md), [P0b](FPP-TPP-P0B-RESULTADOS-20261104.md), [Plano Squad](REALISMO-TATICO-PLANO-SQUAD-20261104.md).

## 1. Causa e decisão

Os `Area3D` das regiões de acerto no avatar são filhos dos pivôs visuais (ossos procedurais). Em `modes/war/scripts/player.gd::_animate_walk()`, o LOD por distância podia retornar **antes** de recalcular os mesmos pivôs mesmo em *listen server* que também controla a autoridade física. Em dedicated server sem câmera local não costuma haver esse skip.

**Correção de prova:** quando o jogo é a autoridade de multiplayer e o modo de teste está ativado, **não pular** `_animate_walk()` por LOD de observador. Assim a rotina existente recalcula as regiões com a pose, inclusive em prone/lean. Nenhuma fórmula de IK, dano, tiro, recoil, respawn ou malha foi reescrita.

**Limite conhecido:** essa correção é um *piloto de correção física*, não a separação completa de `CollisionPose` e `PresentationPose`. Ainda percorre a pose procedural completa, incluindo nós visuais, e tem custo alto. **Não habilitar em produção por padrão.**

### Como ativar apenas em QA

```text
Godot_v4.7.2-stable_win64_console.exe --headless --path <raiz> --script <teste> -- --true-fpp-p1a-authority
```

A flag `--true-fpp-p1a-authority` é lida uma vez em `WarPlayer._ready()`, e só remove o LOD nos atores sob `game.multiplayer.is_server()`. Sem a flag, a lógica original de LOD permanece; isso não dá vantagem ao jogador em partidas existentes. Dedicated servers sem câmera local continuam recalculando naturalmente pela lógica antiga.

## 2. Arquivo de gameplay modificado

`modes/war/scripts/player.gd`

- adicionou `p1a_authority_collision_pilot` (flag de QA, default false).
- `_animate_walk()` só ignora o skip LOD de distância para a autoridade quando a flag está ativada.
- não altera `GamePlayer`, `_server_accept_shot`, câmera, ópticas, rede, hitbox shapes, modelos nem recarga.

Cópia para rollback preservada ANTES da alteração em:
`work/fpp-tpp-p1a-20261104/war-player.gd.before`.

## 3. QA de hitboxes — 5 distâncias

`tests/true_fpp_p1a_authority_hitboxes.gd` cria um host Guerreiro com câmera, um G3 e atores remotos individuais, fixa a pose, passa para prone, força `next_pose_usec` no futuro e compara a transformação completa de **13 regiões físicas** (posição e bases), antes e após atualizar.

| Distância observador → ator | Erro ao forçar LOD | Erro em seis ticks de prone | Mudança de câmera do observador |
|---:|---:|---:|---:|
| 10 m | 0,000 m | 0,000 m | 0,000 m |
| 70 m | 0,000 m | 0,000 m | 0,000 m |
| 150 m | 0,000 m | 0,000 m | 0,000 m |
| 300 m | 0,000 m | 0,000 m | 0,000 m |
| 1.700 m | 0,000 m | 0,000 m | 0,000 m |

**Resultado:** fixture passou **5/5**, 13 regiões checadas por distância, processo exit 0; teste usa a flag. O resultado não prova fidelidade do hitbox a 60 Hz *sob carga de rede real*; compara as poses controladas do host.

Saída: `work/fpp-tpp-p1a-20261104/authority-hitbox-qa.json`.

## 4. Desempenho A/B, 28 atores

`tests/true_fpp_p1a_28_pose_cost.gd`: 28 instâncias remotas G3 no host de teste, depois de aquecimento, em 120 iterações com um `physics_frame` entre amostras, velocidade, pitch, lean e mudanças de postura simuladas. Cronometra apenas o bloco sequencial de atualização das poses (não o frame inteiro).

| Métrica do lote de 28 | Legado (flag ausente) | Piloto (flag presente) |
|---|---:|---:|
| Média | **3,387 ms** | **7,526 ms** |
| Mediana | 0,420 ms | 7,175 ms |
| P95 | 11,501 ms | 10,465 ms |
| P99 | 12,780 ms | 11,289 ms |

Diferença média **+4,139 ms por quadro (+122%) no lote da fixture**. O LOD antigo reúne trabalho em alguns quadros, causando picos de tempo; o piloto distribui trabalho mas passa a pagar por ele em todos os quadros. **Não são FPS 1080p com 28 bots reais**, nem CPU total, nem prova de melhora ou piora dos picos de frametime do jogo completo. As medidas podem variar com throttling, memória e carga concorrente.

Arquivos:
- `work/fpp-tpp-p1a-20261104/authority-28-pose-cost-legacy.json`
- `work/fpp-tpp-p1a-20261104/authority-28-pose-cost-pilot.json`

**Decisão de rollout:** custo médio alto demais para aplicar automaticamente sem um solver de colisão simplificado. O padrão atual mantém a proteção de FPS existente.

## 5. Validação do código atual após adição da flag

- `tests/true_fpp_p1a_authority_hitboxes.gd` **com flag:** passou 5/5, exit 0.
- `tests/true_fpp_p0_hitbox_lod_baseline.gd` **sem flag:** 5/5 cenários instrumentais, preserva o comportamento anterior: máximo ~1,621 m no skip de pose completamente assentada e ~1,025 m após seis ticks (exit 0 não significa ausência de problema).
- `tests/true_fpp_p0_cover_baseline.gd` **sem flag:** seis cenários/12 disparos aceitos, exit 0. Diferenças de alvo FPP/TPP em quina/janela ainda presentes.
- `tests/prone_weapon_pose_validation.gd` sem flag: 1126/1126, exit 0.
- `tests/optics_universal_validation_20261103.gd` sem flag: 242/242, exit 0 (headless, não valida PiP renderizado).
- `tests/true_fpp_p0_g3_baseline.gd` sem flag: exit 0, mantém cópia FPP ~26 cm do cano físico e manete G3 imóvel. **Esses bugs ainda não foram corrigidos.**
- `tests/scoped_muzzle_regression.gd` do legado ainda estava vermelho (326/490 erros no P0a): não usar esse resultado como gate verde.

## 6. Próximo pacote técnico obrigatório: CollisionPose leve

Antes de habilitar a solução em todos os hosts:

1. Introduzir `CollisionPose` **sem MeshInstance3D** (ou atualizar somente os pivôs que carregam `Area3D`), com cálculos físicos determinísticos a 60 Hz: corpo, cabeça, membros, stance, lean, muzzle.
2. Extrair/compartilhar matematicamente a pose existente, evitando duplicar regras de postura e pegar na arma. Cuidado: `WarHumanRig.pose`, `GameInfantryPose.apply` e `WarStance.pose` hoje alteram pivôs, meshes e recursos no mesmo fluxo.
3. Prototipar `PresentationPose` de frequência reduzida que **não** pausa ou congela ancestral de `Area3D`; o visual pode interpolar sem interferir no raio autoritativo do tiro.
4. Repetir QA de 13 regiões por distância, ler transforms físicas do collider e testar paredes/quinas, morte, ragdoll e tiros de G3.
5. Medir em cena real GTX 1650 + 28 bots, incluindo custo do servidor e memória, p50/p95/p99, e comparar com o legado e o piloto atual. **Não ativar em produção até o desempenho ser aprovado.**

As etapas P2a/P3a (corpo único FPP + G3 sem óptica) continuam aguardando esse gate; não tocar ainda no `view_root`/PiP ou na mira balística baseada em câmera.

**Resumo:** prova física funciona, mas gasto de CPU não autoriza ativação por padrão. Os mecanismos atuais de gameplay permanecem como estavam para o jogador.
