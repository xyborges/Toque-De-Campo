# IA 2 — Pendências de entrada, projéteis visuais e custo de ragdoll individual

Data: 7 de novembro de 2026. Computador: DESKTOP-R0I0NQG. Godot 4.7.2.stable.official.ed1daf0bf, 60 Hz de física. Base da branch: `70c88fc` (Favela v25); branch `ia2/entrada-staged-projeteis-20261107`. Sem alterações na main, servidor publicado, limite de 28 bots ou autoridade de tiros. Os experimentos são **headless e isolados**, não equivalem a FPS de cliente GTX 1650 nem comprovam comportamento de ENet/combate real.

## 1. Construção da Favela: planejamento parcelado antes do ENet

O cliente já pré-constrói o mundo antes da conexão ENet, evitando que a construção suspenda acknowledgements de rede. Ainda assim, o planejamento de 4.313 lotes bloqueava o laço principal durante cerca de 1,3 segundo. Acrescentamos protótipo com `TDC_IA2_STAGED_FAVELA_LAYOUT=1`, **desligado por padrão**: `favela_layout.gd` preserva a versão síncrona e acrescenta corrotinas que cedem o processamento entre iterações; `favela_map.gd` só publica a lista no cache estático depois de completa; `game.gd::join_game()` prepara o cache antes de ENet e registra `war_layout_staged`. Nenhuma geometria ou máscara foi reduzida. O orçamento escolhido para o protótipo é de 16 ms por fatia; o algoritmo pode ultrapassar o orçamento antes de alcançar uma fronteira de yield segura.

Na medição da rotina isolada com 10 execuções A-B-B-A-A-B-B-A-A-B, 4.313 lotes e digest `cf02c42b719d067724e2913677870aaadadcd89ba463c577a33cf905e520ea55` foram **idênticos** em todas. Com orçamento de 8 ms, a versão parcelada demorava cerca de 2,35 s em vez de 1,3 s; o orçamento de 16 ms aproximou o total de 1,3 a 1,46 s e manteve o maior intervalo da etapa em aproximadamente 79–82 ms na amostra isolada. Ambos os métodos geram o mesmo resultado geométrico. Logs `staged-layout-5pairs.log` e `staged-layout-16ms-5pairs.log`.

### Cinco pares A/B do mundo completo (dez processos Godot)

Todos passaram, com **4.313 casas, 225 tiles e 11.624 formas de colisão**, mesmo hash de lotes. Os dados estão em `world-5pairs.csv`, 10 JSONs e 10 logs.

| Medida | A original | B preparação em quadros |
|---|---:|---:|
| Média até `join_ready` | 10.795,23 ms | 11.443,97 ms |
| Média de `world_build_ms` (não inclui a preparação extra B) | 5.820,72 ms | 4.745,29 ms |
| Pré-preparação média B | não existe | 1.434,44 ms |
| Maior fatia observada da preparação | bloqueio original ~1,3 s | 99,828 ms |
| Pares em que B terminou mais cedo | — | **1/5** |

B ficou **6,01% mais lento** até `join_ready`, com ruído de 12,53% entre controles A. Não comprova redução do tempo até partida jogável. A construção restante do mundo ainda bloqueia a interface por cerca de 4 a 5 segundos e não foi particionada. **Decisão: protótipo opt-in, não ativar.** É importante que um futuro particionamento de edifícios, collision shapes, instâncias e materiais preserve o contrato de mundo completo antes de liberar controles e jogadores.

## 2. Projéteis visuais no cliente: custo das consultas

O projeto já tinha pool de 512 projéteis e uma `PhysicsRayQueryParameters3D` reaproveitada por projétil. Havia uma flag anterior `TDC_IA2_CLIENT_PROJECTILE_30HZ=1`, desligada por padrão, que varre o trecho acumulado para projéteis meramente visuais elegíveis, sem alterar raios autoritativos do servidor, explosões ou guiados.

Neste trabalho foram criados QA e benchmark com **120 balas visuais simultâneas**, parede fixa e cinco pares A/B de processos Godot independentes. Todos os 120 impactos acertaram a mesma parede nos mesmos pontos nas dez rodadas; SHA256 de posições: `db15d8e6f95ba999e7fc889b6076492667b8c4efc4acd792a450381af4fc01be`.

| Medida | A (ray 60 Hz) | B (ray visual 30 Hz) |
|---|---:|---:|
| Custo médio por tick da rotina de projéteis | 2,8191 ms | 2,6811 ms |
| Economia média da rotina | — | **4,89%** |
| Amplitude de ruído dos controles | **14,85%** | — |
| Vitória em média | — | 5/5 pares |
| Vitória em P99 do hotspot | — | 4/5 pares |

A variante B pulou 7.440 consultas visuais por execução até o impacto, mas continuou custando quase o mesmo porque há outros trabalhos de integração balística e apresentação. **DECISÃO: não ativar; resultado inferior ao ruído e P99 não melhora em todos os pares.** Este turno **não modificou** `projectiles.gd`, apenas testou o código opt-in já existente. Não há validação de obstáculos móveis e efeitos de câmera numa sessão real.

## 3. Ragdoll individual: consultas e colisões internas

A criação real utiliza cerca de **15 partes físicas, 14 juntas, clearance de pose, materiais e colisores**. Cada parte usa `collision_layer=8` e `collision_mask=1`. Havia até **210 exceções explícitas** de colisão entre membros, além de 28 automáticas da junta. Foi testada a hipótese de suprimir as 210 chamadas explícitas, conservando as 28 automáticas, sob flag experimental separada `TDC_IA2_RAGDOLL_MASK_ONLY=1`. Houve 16 criações por execução, cinco pares A/B e física estável/mesma contagem de partes.

| Medida | A original | B sem 210 exceções explícitas |
|---|---:|---:|
| Custo médio de criar um cadáver | 10,351 ms | 9,372 ms |
| Redução média | — | **9,45%** |
| Ruído controle (amplitude/média) | **92,29%** | — |
| Pares melhores em média / P99 | — | **3/5 e 3/5** |

**DECISÃO: REPROVADO e REVERTIDO.** `scripts/death_ragdoll.gd` está idêntico ao commit-base. Diff descartado guardado apenas como `DESCARTADO-ragdoll-mask-only.patch.gz` e fixture descartada em `DESCARTADO-ia2_ragdoll_single_bench.gd` dentro dos dados, para documentação; não recompilar esse código em produção. O trabalho anterior de fila remota de ragdolls e correção de limite de cadáveres permanece opt-in na branch-base e **não foi refeito**.

## 4. Integridade, segurança e decisão

- Os testes são apenas de laboratório **headless** no mesmo R0I; não foi executado cliente gráfico 1080p/GTX 1650, benchmark real de rede, stutter ao entrar, FPS de renderização nem teste humano em combate. Não comparar com métricas da JJ7.
- Modificações produtivas neste branch apenas: `modes/war/scripts/favela_layout.gd`, `modes/war/scripts/favela_map.gd` e `modes/war/scripts/game.gd` (tudo atrás da flag de preparação em quadros, padrão OFF). Não se mexeu em bot_director, step_motion, sistema de movimento, hitboxes, servidor ou cenas 3D.
- Novos testes: `tests/ia2_layout_staged_qa.gd`, `tests/ia2_staged_world_qa.gd`, `tests/ia2_projectile_visual_cost_qa.gd`. Scripts de A/B e dados brutos preservados em `work/ia2-staged-layout-projectiles-20261107/`. Checksum SHA256 em `SHA256SUMS.txt`.
- Verificações de sintaxe Godot, QA de integridade do mapa inteiro e regressões de combate/Favela foram executadas, com resultados nos logs pertinentes. A alteração não está habilitada por padrão, não foi mesclada nem publicada ao servidor.

**Prioridade seguinte proposta para outra revisão:** dividir ou reduzir a etapa restante de construção do mundo sem deixar colisões incompletas, e perfilar efeitos de explosões/impactos, material e desenho de projéteis no cliente. Não usar a flag de raycast 30 Hz ou a mudança descartada de colisões de ragdoll como "ganho" confirmado. Não prometer FPS 60 só com esse trabalho.
