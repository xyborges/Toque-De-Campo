# Benchmark GTX 1650 desktop — Favela (06/11/2026)

Resultado: **REPROVADO nas sete rodadas**. O teste foi executado no commit `378148b`, com Godot 4.7.2 oficial, i5-3470, GTX 1650 e 15,7 GiB de RAM. Windows 10, plano Alto desempenho, monitor 1920 × 1080 (~59 Hz).

Cenário: Guerra offline, câmera fixa na Favela, Forward+, 1920 × 1080, Médio, escala 100%, 28 bots, V-Sync e limite de FPS desligados, 10 s de aquecimento e 60 s de coleta. O runner registrou a versão do motor e validou renderizador, escala, bots e resolução. As medições da GPU incluem carregamento e encerramento.

| Rodada | FPS médio | FPS mediano | 1% low | P95 ms | P99 ms | >50 ms/min | >100 ms | Foco observado |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 1 | 18.45 | 19.07 | 6.04 | 75.82 | 130.27 | 658 | 26 | 6/6 janelas |
| 2 | 4.55 | 4.93 | 2.55 | 362.54 | 389.64 | 273 | 273 | 1/7 janelas |
| 3 | 2.47 | 2.48 | 1.79 | 464.40 | 508.92 | 149 | 149 | 1/8 janelas |
| 4 | 12.07 | 13.50 | 4.96 | 148.61 | 183.12 | 722 | 107 | 6/6 janelas |
| 5 | 9.06 | 9.77 | 4.58 | 179.47 | 208.72 | 544 | 287 | 6/7 janelas |
| 6 | 13.25 | 14.97 | 5.43 | 143.80 | 171.32 | 750 | 98 | 5/6 janelas |
| 7 | 12.88 | 14.98 | 5.74 | 138.49 | 152.88 | 551 | 214 | 5/5 janelas |

O foco é amostrado em janelas de diagnóstico e não comprova foco contínuo. As rodadas 1, 4 e 7 registraram foco em todas as janelas observadas; 2, 3, 5 e 6 tiveram pelo menos uma janela sem foco. Todos os resultados foram preservados; a perda de foco e a variação entre rodadas impedem atribuir causalidade apenas ao código.

Para as rodadas 1, 4 e 7, as medianas entre rodadas foram: FPS médio 12.88, FPS mediano 14.98, 1% low 5.74, P95 ms 138.49, P99 ms 152.88.

A GPU variou entre 34 e 37 °C nas amostras, sem evidência de limitação térmica da GPU nessas leituras. Não houve medição contínua de temperatura da CPU; não é possível excluir throttling da CPU. Os monitores de física e GPU não são parcelas exclusivas somáveis do quadro.

A referência anterior de 26,8 FPS foi um smoke de 10 s e 4 s de aquecimento, em outra CPU; não é comparação controlada com estas coletas. O benchmark mede operação offline e câmera fixa, sem validar rede, movimento completo ou combate prolongado. As métricas resumidas estão no JSON ao lado. Os [dados das sete rodadas](benchmark-results/gtx1650-desktop-20261106) incluem a saída bruta do benchmark, o resumo, o log do Godot e a telemetria da GPU. A publicação substitui o nome do computador e os caminhos locais por referências portáteis. As medições foram preservadas.
