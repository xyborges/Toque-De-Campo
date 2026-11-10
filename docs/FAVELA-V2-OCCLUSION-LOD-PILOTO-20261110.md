# Favela V2 — piloto de Occlusion Culling 32 m + LOD (10/11/2026)

**Estado:** experimental, desligado por padrão. Sem merge com `main`, sem alteração da build publicada.

## Base e objetivo

Branch `ia/favela-v2-occlusion-lod-pilot-20261110`, derivada de `1ba9534`, a estrutura 3D de subida da Favela V2. Adaptação conservadora do experimento já testado na Favela original, commit `05296b8`, **sem copiar a alteração global do gerador antigo**.

A V2 mantém **640 × 670 m, 197 casas, 49 células físicas de terreno, 29 vias, 88 m entre bases e uma única entrada para o bairro oeste**. O objetivo é verificar otimizações visuais antes de aumentar a densidade de casas, passagens e objetos.

## Implementação

- `modes/war/scripts/favela_v2_visual_optimization.gd`: política compartilhada e independente para LOD e oclusão visual. Os detalhes das casas reutilizados da biblioteca original têm distância máxima de **130 m**; janelas pequenas, **120 m**; caixa-d'água, **180 m**. **Paredes estruturais e lajes permanecem com alcance longo**, inclusive colisão e cobertura.
- Com `--favela-v2-occlusion-pilot`, habilita o **native occlusion culling** do Godot somente para o mapa V2, com no máximo **um `BoxOccluder3D` para cada célula de 32 × 32 m** contendo uma casa sólida. O box é **24 cm menor em cada eixo** que o `BoxShape3D` real, e segue escala/rotação da casa. Portas, passagens, escadas, lajes e objetos finos **não** viram oclusores.
- A configuração global `occlusion_culling/use_occlusion_culling=true` habilita apenas a infraestrutura de renderização; o viewport V2 continua em `false` **sem a flag**.
- Servidor dedicado: **zero** `OccluderInstance3D`, zero trabalho visual de LOD, todas as casas/colisões físicas mantidas. O código do antigo `WarFavelaMap`, o modo Guerra em produção, projéteis, navegação e rede **não mudaram**.
- Preservados os grupos `MultiMesh` dos escadões e o `visibility_range_end` já existente. Nenhuma nova dependência externa foi instalada nesta fase. Não se fez migração precipitada para Terrain3D ou ProtonScatter.

## QA

Godot 4.7.2:
- `tests/favela_v2_visual_optimization_qa.gd` — **411/411 OFF e 411/411 ON**; 197 colisores sólidos preservados, 2.899 elementos visuais com LOD, **107 occluders** em 107 células de 32 m somente no teste ON, servidor físico comparado, 0 occluders no OFF e na autoridade.
- `tests/favela_v2_ascension_qa.gd` — **31/31 PASS**; mapa, terreno e base/rota preservados.
- `tests/favela_v2_topology_qa.gd` — **238/238 PASS**, sem novos atalhos no morro oeste.
- `tests/favela_v2_ascension_walk_qa.gd` — **18/18 PASS**, `GameStepMotion` real, nenhum recuo ou bloqueio.
- O editor recompôs os recursos importados, mas encerrou sua operação de importação com o código Windows `-1073741819`. Os processos independentes de QA e benchmark rodaram e terminaram com código 0, sem erros de script do piloto.

## Benchmark A/B gráfico na GTX 1650

Godot **Forward+**, 1920 × 1080, **150 frames por posição após 75 de aquecimento**, sem bots; três posições reais na Favela V2 (baixa, miolo, alta). Dois pares com ordens invertidas: **OFF→ON** e **ON→OFF**. Resultados integrais em `docs/benchmark-results/favela-v2-occlusion-20261110/ab-r1-r2.json`.

| Posição | Draw calls OFF → ON | P99 R1 OFF → ON (ms) | P99 R2 OFF → ON (ms) |
|---|---:|---:|---:|
| Baixa | **153 → 125** | 5,87 → **5,06** | **6,09** → 7,23 |
| Miolo | 108 → 107 | 9,10 → **5,93** | **5,21** → 5,97 |
| Alta | 82 → 82 | 5,77 → **5,25** | **5,12** → 5,71 |

Build_ms OFF: 993 / 1.021; ON: 944 / 1.134. A diferença entre execuções ainda é maior que o pequeno delta médio de construção. O teste mostra redução consistente de **18,3% nas draw calls na posição baixa**, mas **não melhora estável de P99**. O melhor P99 do primeiro par não se reproduziu no segundo. Não extrapolar FPS ~300–400 da prévia sem bots para combate real.

**Limitações relevantes:** havia outros processos Godot na máquina, não foi verificado foco de janela em 100%, não houve bots, ENet, combate ou amostras repetidas com ambiente isolado. Logo, estes resultados são **exploratórios**, e não gate de lançamento.

## Decisão e continuação

**Aplicar/guardar como candidato:** distância LOD dos acessórios da V2; render-only, com QA de física preservada.

**Não ativar automaticamente:** native occlusion culling de 32 m. A flag continua disponível para comparação, mas somente nova bateria A/B de GPU isolada e teste multiplayer com 0/12/22 bots poderão justificar a ativação.

**Próximas fases, em outras branches pequenas:** adensar as casas da V2 por setor sem fechar becos; substituir anéis/muros visuais do oeste por elevações rochosas naturais bloqueando atalho entre as bases; inserir vegetação/escombros por MultiMesh com zero colisão decorativa e visibilidade LOD; avaliar Terrain3D em mapa paralelo somente se preservar física autoritativa e export de cliente/servidor. `ProtonScatter` e `GridMap` são ferramentas candidatas, não ganhos comprovados a ponto de substituir o gerador existente.

O piloto não modifica `main` nem a build pública.
