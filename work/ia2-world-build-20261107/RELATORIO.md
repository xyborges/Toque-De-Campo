# Toque de Campo — IA 2: construção da Favela e custo do servidor sem render

**Data:** 7 de novembro de 2026. **Máquina de teste:** DESKTOP-R0I0NQG. **Godot:** 4.7.2 stable (ed1daf0bf). **Base:** commit `66f6176`. **Branch:** `ia2/perf-world-build-phases-20261107`. `main` preservada; nenhuma build ou servidor de produção alterado.

## Escopo e protocolo

Objetivo: atacar custo FIXO de construção do mapa Favela, sem reduzir a geometria de colisão nem o número de bots. Testes **headless offline**, sempre na mesma máquina, sem outro Godot concorrente. Godot 4.7.2, mesmo mapa e códigos. Cinco pares A/B intercalados em processos independentes, ordem **A, B, B, A, A, B, B, A, A, B** para cada hipótese. Cada coleta preserva log bruto, CSV, JSON e medição por fase usando `TDC_IA2_MAP_STAGES=1`.

**Limite:** os tempos de boot não são FPS nem P99 de cliente GTX 1650; não incluem temperatura de GPU nem jogo de 120 segundos com cliente ENet conectado. O teste separado de 28 bots é uma partida local automatizada sem combate intenso. Os benchmarks do servidor são apenas indicativos de custo de inicialização.

## Perfil original — onde estava o custo

Três execuções iniciais com `ia2_map_stage_qa.gd` identificaram aproximadamente: reservas de lotes 1,3 s, bairros 1,3 s, encostas ~1,0 s, 225 tiles ~0,6 s e acabamentos/ruas cerca de 0,5 s. Essas fases são síncronas e seguem precisando de trabalho estrutural para reduzir travadas visuais na entrada. Logs `phase-1.log`, `phase-2.log`, `phase-3.log`.

## Experimento A — registrar colisores setoriais apenas no final

Hipótese: preparar 11.624 `CollisionShape3D` sob seus 254 `StaticBody3D` de setor antes de registrar os corpos na `SceneTree`. Alteração em `EnvironmentKit` protegida temporariamente por `TDC_IA2_DEFER_SECTOR_ATTACH=1`. Objetos, dimensões, camadas, máscaras e poses não foram alterados.

Os pilotos foram promissores e a geometria ordenada e 20 raycasts físicos bateram. Porém, na matriz de dez execuções:

| Medida | Original | Experimental | Interpretação |
|---|---:|---:|---|
| Construção média do mapa | 5.602,2 ms | 5.432,8 ms | -3,02% |
| Tempo médio até `join_ready` | 10.636,5 ms | 10.406,8 ms | -2,16% |
| Ruído do controle da construção (amplitude/média) | 18,31% | — | ganho inferior ao ruído |
| Pares melhores | — | 4/5 | insuficiente |

**DECISÃO: DESCARTADO E REVERTIDO.** Nenhuma mudança em `scripts/environment/environment_kit.gd` fica no código versionado. Diff reproduzível, somente como arquivo comprimido `DESCARTADO-defer-sector-attach.patch.gz`; dados completos em `colliders-5pairs.csv` e JSONs/logs.

**Auditoria da inconsistência de hash:** numa coleta de controle original, o hash da lista na ordem bruta de filhos diferiu. Conferimos: hash das formas **ordenadas** igual, hash de transformações e dimensões **sem nomes** igual, hash de cada um dos 254 setores igual e 20 resultados de raycast iguais. A diferença foi **ordem de enumeração**, não geometria física. A comparação válida usa hashes canônicos e raios; preservamos os dois hashes brutos para rastreabilidade. Uma primeira matriz interrompida detectou a diferença e motivou essa checagem.

## Experimento B — não planejar vegetação exclusivamente visual em servidor headless

O gerador da encosta construía milhares de posições de grama, arbustos e rochas decorativas mesmo com `EnvironmentKit.visuals=false`, embora jamais criasse seus objetos visuais. O único grupo da encosta que produz colisão são troncos ocasionais entre as árvores. Todas as quatro categorias usam geradores `RandomNumberGenerator` independentes, com sementes fixas.

Código em `modes/war/scripts/favela_hillside.gd`, opt-in:

`TDC_IA2_HEADLESS_SKIP_VISUAL_HILLSIDE=1` (**padrão OFF**)

- Quando `kit.visuals == false`, a flag omite os três planejamentos exclusivamente decorativos.
- As 1.850 árvores e os 78 troncos físicos continuam calculados normalmente, com as mesmas posições (SHA256 das árvores: `5cac83c1de52a0a083228dca513907cc4cb29f585df1850164ae683db26648c9`).
- Clientes com `kit.visuals == true` continuam planejando **4.700 arbustos, 13.334 gramas e 480 rochas decorativas**, mesmo se a flag existir no ambiente.
- Estatísticas headless informam explicitamente `hill_visual_plan_skipped=true` e zero posições visuais planejadas. Não reportar os zero como remoção de terreno/colisão.

O teste isolado `ia2_headless_foliage_qa.gd` mediu **999,884 ms → 93,998 ms** e comprovou identidade exata das árvores.

### Cinco pares A/B — mapa completo

| Medida | A, completo | B, sem plano decorativo headless | Economia |
|---|---:|---:|---:|
| Encostas | 1.037,06 ms | 110,23 ms | **926,83 ms (89,37%)** |
| Construção de mapa | 5.670,40 ms | 4.571,20 ms | 1.099,20 ms (19,38%) |
| `world_build_ms` | 5.811,69 ms | 4.708,49 ms | 1.103,19 ms (18,98%) |
| Tempo até `join_ready` | 10.738,16 ms | 9.338,41 ms | 1.399,75 ms (13,04%) |

**Todas as cinco comparações** favoreceram B tanto na construção do mapa quanto no tempo até `join_ready`. O ruído de controle foi **8,63%** no hotspot de encostas (ganho claramente acima dele), **23,95%** na construção inteira e **25,42%** no tempo até `join_ready` (ganhos globais ainda dentro do ruído). NÃO extrapolar a melhoria global para outro hardware sem teste.

### Integridade física e geração determinística

A cada execução: **4.313 casas, 225 tiles, 254 setores, 11.624 formas de colisão, 1.850 árvores, 78 troncos físicos e 20 raios de cenário positivos**. Hash canônico de todas as colisões, hash por setor, hash das formas sem rótulos e hash dos contatos físicos **idênticos nas dez execuções**. A mesma oscilação de ordem bruta dos filhos ocorreu em uma coleta *original*, esclarecida na seção anterior, sem alteração real das colisões.

Testes reproduzíveis e dados: `foliage-5pairs.csv`, `foliage-5pairs-analysis.json`, dez `foliage-XX-N.json` com `sector_geometry`, dez logs e o analisador `analyze-foliage.py`.

**DECISÃO:** melhoria inequívoca do custo do planejamento de encostas no servidor sem render, com geometria preservada. **Flag continua OFF por padrão**: falta validação em servidor dedicado e cliente ENet real, P99 e intensidade de combate conforme política do projeto. Não promover à `main` sem revisão e homologação.

## Regressões e segurança

- Projeto e testes analisados com Godot 4.7.2; nenhum erro de sintaxe.
- `tests/favela_runtime_qa.gd --favela-bots` com a flag ligada: **39 verificações, zero falhas, 28 bots ativos e implantados, oito veículos**. QA automatizado sem troca intensa de tiros.
- `tests/ia2_entry_combat_qa.gd`: validação de armas, ragdolls e raios autoritativos documentada em `combat-regression.log`.
- Não foram editados `bot_director.gd`, `step_motion.gd`, projéteis, armas, hitboxes, motor de física, posições dos jogadores, sincronização ou rede.
- As flags `TDC_IA2_MAP_STAGES` e `TDC_IA2_HEADLESS_SKIP_VISUAL_HILLSIDE` não são ativadas por código em produção; só nos scripts de QA.

## Entregáveis e próximo passo

Arquivo de produção alterado: apenas `modes/war/scripts/favela_hillside.gd`. Novos testes: `tests/ia2_headless_foliage_qa.gd`, `tests/ia2_map_collider_attach_qa.gd`. Evidências e scripts de reprodução em `work/ia2-world-build-20261107/` com hashes SHA256.

A próxima intervenção deve estudar **a montagem síncrona de bairros e terreno com controle de tempo de quadro real** num cliente 1080p, e medir o efeito no servidor dedicado e na conexão ENet antes da aprovação. Não confundir carregamento inicial com custo contínuo por bot. Não reduzir grass/arbustos visuais do cliente para obter esta melhora.
