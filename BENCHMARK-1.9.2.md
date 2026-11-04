# Guerra 1.9.2 — medições e limites

27/10/2026. Godot 4.7.2, renderizador Compatibility/OpenGL, NVIDIA GTX 1650, imagem renderizada em 1920×1080. Baseline: fonte preservada da 1.9.1/build 62. Sem outro jogo aberto durante as medições.

## Teste isolado dos portos

Um cliente nativo, mapa completo e câmera em percurso definido. Cinco segundos por fase, primeiro segundo descartado, VSync desligado, uma renderização explícita por amostra. Duas execuções por versão. Não representa uma partida com doze jogadores.

Os acessos foram remodelados: nos trechos que consultam a altura do terreno, a câmera acompanha o novo piso. É uma comparação da experiência nas mesmas regiões/rotas de observação, não de geometria idêntica. As capturas de cada fase foram salvas.

| Fase | Frame médio antes, ms¹ | Depois, ms¹ | Draw calls antes → depois | 1% low antes, FPS² | Depois, FPS² |
|---|---:|---:|---:|---:|---:|
| Antes de E | 4,18 | 3,93 | 444 → 476 | 118,8–164,4 | 146,4–155,3 |
| Entrada em E | 3,69 | 3,82 | 369–370 → 380–385 | 157,6–162,0 | 53,6–153,2 |
| Dentro de E | 3,82 | 3,51 | 277 → 287 | 50,4–112,7 | 54,8–63,5 |
| Saída de E | 7,57 | 7,16 | 1235–1236 → 1038 | 71,9–88,1 | 25,5–92,4 |
| Porto D | 8,15 | 7,62 | 1249 → 1097 | 61,6–68,7 | 24,9–27,4 |

¹ Média das duas execuções. ² Intervalo dos resultados das duas execuções; não é intervalo de confiança estatístico. 1% low é o inverso da média dos 1% quadros mais lentos.

A média melhorou nas vistas mais abertas, com menos chamadas de desenho. **Os picos não foram eliminados**: o porto D apresentou pior 1% low nas duas execuções novas. Também houve variação relevante na entrada/saída de E. Esses resultados não sustentam uma afirmação de fluidez estável nem de otimização concluída. Medianas de cena e médias de GPU não explicam sozinhas as travadas.

Relatórios completos: `work/perf192/{before,after}192-{road,repeat}-ports.json`. Há amostras de GPU, processamento, física e memória. Os monitores de processamento/física podem conservar um pico de um ciclo anterior e são inclusivos; não foram somados para calcular um suposto tempo total de CPU.

## Carga com 12 conexões reais

Servidor autoritativo, 12 clientes loopback por DTLS, um deles renderizando em 1080p. Mesma sequência antes/depois: disparos contínuos, recargas, quatro blindados em movimento, dois drones, quatro explosões pesadas simultâneas a cada dois segundos e desconexão de um ocupante. Barreira de entrada e aquecimento antes de medir. Nenhuma falha funcional nos relatórios dos 13 processos.

| Medida sem Profiler | Antes | Depois |
|---|---:|---:|
| Cliente visual — FPS médio | 46,3 | 48,2 |
| Cliente visual — 1% low, FPS | 13,5 | 17,7 |
| Cliente visual — frame p95, ms | 34,71 | 34,45 |
| Servidor — ciclos médios/s | 44,4 | 48,8 |
| Servidor — frame p95, ms | 57,95 | 35,62 |
| Maior frame do cliente na janela da desconexão, ms | 37,5 | 29,4 |
| Maior frame do servidor nessa janela, ms | 212,4 | 30,1 |
| Pico de projéteis ativos no cliente visual | 43 | 45 |

O ganho médio do cliente neste ensaio foi de cerca de 4%. Isso **não demonstra 60 FPS estáveis**, e uma execução por versão não separa completamente ganho de código, variação do sistema e escalonamento dos processos.

Limitações deliberadas da carga: todos os processos disputam CPU/memória neste mesmo PC; os clientes sem renderização usam um recorte de colisão, enquanto autoridade/renderizador mantêm o mapa completo; o cenário de carga impede mortes para sustentar os disparos. Dano, mortes, armas e implantação foram verificados separadamente em integração. Este ensaio não simula doze pessoas em doze computadores nem mede latência de internet.

Relatórios: `work/perf192/before192-multiplayer.json` e `after192-multiplayer.json`.

## Profiler do próprio Godot

Foi feita uma execução adicional instrumentada, separada da comparação de FPS. Um receptor local leu o fluxo de depuração remota do motor, incluindo `servers:profile_frame` e assinaturas de funções. Foram obtidos **mais de 880 quadros por processo**, com 262 assinaturas de funções no servidor e 301 no renderizador. O custo dessa instrumentação não foi misturado com o teste acima. Referência do funcionamento: [Profiler do Godot](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/the_profiler.html).

Trabalho relevante encontrado na execução instrumentada:

- Servidor: movimento/colisão em `WarVehicleStep._move`, envio em `GameNetworkBroadcast.send`, animação em `WarPlayer._animate_walk` e processamento dos personagens.
- Renderizador: a chamada explícita de desenho do próprio ensaio, processamento/animação dos personagens e atualização de fumaça/efeitos.
- Tempos de funções podem incluir chamadas nativas, bloqueios e atrasos de escalonamento. Chamadas aninhadas não podem ser somadas como custos independentes.

Arquivos brutos e resumos: `work/perf192/godot-profiler-{server,renderer}{,-summary}.json`. O receptor e os testes ficam fora do pacote público.

## Conclusão de desempenho

Há redução de desenho nas vistas abertas e melhora moderada na carga conjunta, mas ainda existem gargalos e picos. A prioridade seguinte de otimização deve ser separar melhor o custo de colisão dos blindados, poses dos personagens e apresentação de efeitos, sem reduzir a precisão dos hitboxes ou esconder colisões. A meta de 60 FPS ainda exige trabalho e validação em máquinas separadas, incluindo o servidor Ubuntu.

O lançamento é uma revisão de combate, veículos, implantação e mapa acompanhada de medições — não uma certificação de 60 FPS.
