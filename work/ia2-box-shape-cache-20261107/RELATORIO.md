# IA 2 — Auditoria de BoxShape3D e montagem física da Favela

**Data:** 7 de novembro de 2026. **Máquina:** DESKTOP-R0I0NQG. **Godot:** 4.7.2 stable. **Base:** `ee969af` (origin/main). **Branch:** `ia2/box-shape-cache-20261107`.

## Objetivo e escopo

Separar o custo de **criar recursos físicos** do custo de **anexar colisores na árvore**. Não alterar quantidade de bots, gameplay, servidores em produção, autoridade de rede ou mapas. Testes **headless locais**, sem cliente ENet, renderização ou GPU, para o mapa Favela da `main` (4.188 casas; não usar números antigos da v25).

Instrumentação temporária de `EnvironmentKit.box()` e `_collider()` acumulou microssegundos de criação/reaproveitamento e adição dos nós. Todas as medições usam a mesma instrumentação `TDC_IA2_BOX_PROFILE=1`. Hipótese: num servidor sem renderizar, reutilizar `BoxShape3D` de mesmo Vector3 `size` dentro da instância `EnvironmentKit` (somente formas imutáveis, sem alterar transformações ou colisores). Testar `TDC_IA2_BOX_SHAPE_CACHE=1`, default OFF. Nunca compartilhar formas entre mundos diferentes.

## Cinco pares A/B, cada execução em Godot independente

Ordem A–B–B–A–A–B–B–A–A–B. Dez processos completos e isolados, mesmos arquivos e parâmetros, sem outro Godot concorrente. Estatística de ruído = amplitude/média dos cinco controles. Resultados brutos estão em `boxes-5pairs.csv`, `boxes-XX-N.json`, logs e `analysis.json`; reaplicação do diff e execução em `run-five-pairs.ps1`.

| Indicador | Original A | Cache B | Variação |
|---|---:|---:|---|
| Custo acumulado para criar/buscar caixas | **35,783 ms** | **30,412 ms** | **−5,370 ms (−15,0%)** |
| Anexar colisores de caixa à árvore | 447,331 ms | 453,830 ms | +6,499 ms |
| Construção total do mundo | **4.913,412 ms** | **5.029,407 ms** | **+2,36% (pior)** |
| Tempo até `join_ready` | **9.135,587 ms** | **9.349,479 ms** | **+2,34% (pior)** |
| Ruído da montagem A (amplitude/média) | **3,33%** | — | O efeito total fica dentro do ruído |
| Ruído do `join_ready` A | **1,91%** | — | — |
| Pares com vantagem B na construção | — | 1/5 | Não aprovar |
| Pares com vantagem B na entrada | — | 1/5 | Não aprovar |
| Pares com vantagem B na **criação de caixas** | — | 5/5 | Ganho localizado sem reflexo global |

O ambiente contém **8.698 chamadas `EnvironmentKit.box()` com colisão**. A flag reutilizou **3.826 `BoxShape3D` por execução**, reduzindo recursos únicos de caixa encontrados no mundo de **8.812 para 4.986** (os números incluem formas extras fora do EnvironmentKit). A amplitude do controle do custo de criar caixas foi 4,89%, menor que o ganho isolado de 15%. Porém, a rotina de criação representa só ~0,7% da montagem de 4,9 segundos; anexar colisores representa ~9,1% e continua caro.

**Limites:** os tempos de anexação são inclusivos e contêm chamadas nativas do Godot e obtenção de corpos setoriais. As somas parciais não representam o tempo total da construção. A criação de um nó físico pode provocar trabalho subsequente no PhysicsServer, não medido nesta instrumentação. Esta coleta não fornece FPS/P99 de cliente gráfico nem carga de 28 bots.

## Verificações de integridade física

Todos os dez processos terminaram sem erro e mantiveram:
- **4.188 casas**, **225 tiles**, **11.146 colisores contabilizados pelo mapa**;
- **11.243 formas BoxShape3D** na árvore da Favela (incluindo formas externas ao contador do mapa);
- **geometria física idêntica**, digest canônico `ed382d5d98cbb2bb1471ac926b1cf890ee755213163ac8f2ddee32c33a48ca80`;
- **oito raycasts físicos de controle idênticos**, digest `574841c454eb1f4ffe3703bfa0d5796c51cdb6676e428177b2468651a159f7b5`.

Não há prova de segurança para modificação das dimensões compartilhadas em tempo de jogo, portanto o cache foi restrito a um mundo headless e **DESCARTADO** após os testes.

## Decisão de integração

**Reprovar e reverter** o cache de `BoxShape3D`. O arquivo `scripts/environment/environment_kit.gd` será deixado **idêntico à main**. A instrumentação e o patch experimental são preservados apenas como `DESCARTADO-environment-kit-cache.patch.gz`, juntamente com `DESCARTADO-ia2_box_shape_cache_qa.gd` e os dados de reprodução. O fixture arquivado só pode rodar depois de aplicar o patch experimental em uma branch isolada.

A evidência prioriza o custo de **instanciar/registrar colisores**, mas outra frente já reprovou anexar setores fora da SceneTree; não reintroduzir essa tentativa sem uma arquitetura diferente. Outra intervenção potencial de maior retorno é **pré-compilar o planejamento determinístico dos lotes** com verificação de integridade e fallback ao algoritmo, ou medir detalhadamente a composição das casas. Nenhuma mudança de servidor, rede ou `main` será publicada a partir desta hipótese sem revisão.

## Arquivos

Registros de 10 rodadas `.json` e `.log`, dois pilotos, `boxes-5pairs.csv`, `analysis.json`, `analyze.py`, `run-five-pairs.ps1`, patch compactado, fixture arquivada, `SHA256SUMS.txt` e este relatório. Nenhum arquivo de produção é entregue alterado.
