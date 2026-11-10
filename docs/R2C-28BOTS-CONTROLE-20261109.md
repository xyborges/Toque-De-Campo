# R2C ? dois pares 28 bots GTX 1650 (09/11/2026)

## Configura??o
Favela, 28 bots, Godot 4.7.2, GTX 1650, Forward+, 1920x1080, M?dio 100%, 60 Hz de f?sica, 4s de aquecimento, 30s de medi??o em cada bra?o, 100% foco de janela. Sem processos Godot estrangeiros identificados nas checagens antes/durante os bra?os. Quatro JSONs brutos publicados ao lado deste documento com SHA256 copiado sem altera??o.

## Pares

| Ordem | Estado | FPS m?dio | P95 | P99 | Frames R2C ativa |
| --- | --- | ---: | ---: | ---: | ---: |
| 1? | ON | 31.56 | 44.09 ms | 415.03 ms | 118 |
| 2? | OFF | 35.55 | 37.61 ms | 47.71 ms | 0 |
| 1? invertido | OFF | 35.47 | 38.54 ms | 47.24 ms | 0 |
| 2? invertido | ON | 35.68 | 38.40 ms | 58.05 ms | 127 |

## Interpreta??o e gate

- Todos os bra?os terminaram com exit0, valid=true, 28 bots, Forward+ e nenhum frame fora de foco.
- O primeiro bra?o ON apresentou p99 de 415.03ms, mas o segundo ON depois do controle OFF teve p99 de 58.05ms; poss?vel inicializa??o/cache frio. Sem telemetria de causa do spike n?o afirmar causalidade.
- OFF foi est?vel em duas repeti??es, ~35.5 FPS e p99 ~47ms. ON no segundo par teve 35.68 FPS, p99 58.05ms. N?o h? ganho comprovado nem evid?ncia suficiente para homologar 28 bots.
- **Gate FPS 60 com 28 bots REPROVADO independentemente da flag**, incluindo OFF. Ativa??o R2C geral permanece BLOQUEADA, e o P1k tem gate de CPU separado.
- Progresso t?cnico real: duas execu??es v?lidas ON/OFF na GPU, contrabalan?adas (ON->OFF e OFF->ON), sem concorr?ncia observada.
- Para aprova??o robusta seriam necess?rios pares adicionais e a investiga??o espec?fica do P99/primeiro spawn. A primeira execu??o ON extrema n?o deve ser descartada das evid?ncias.

Arquivos: on-first.json, off-second.json, off-first.json, on-second.json.
