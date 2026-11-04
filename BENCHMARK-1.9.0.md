# Benchmark 1.9.0

Godot 4.7.2, Windows, NVIDIA GeForce GTX 1650, 1920 × 1080, Compatibility.

## Comparação da renderização

Mesmas cinco câmeras, VSync desligado, sem limite de FPS e cinco segundos de amostras por vista após aquecimento. A simulação está congelada; a cena usa personagens, blindados e o mapa real. O resultado não representa uma partida de combate com 12 jogadores.

| Vista | FPS antes | FPS depois | 1% low antes | 1% low depois | Draw calls antes/depois |
|---|---:|---:|---:|---:|---:|
| combat | 169.7 | 169.4 | 117.1 | 129.7 | 1304 / 1244 |
| combat_thermal | 163.5 | 155.3 | 126.8 | 93.4 | 1305 / 1245 |
| city | 154.1 | 153.8 | 56.1 | 109.6 | 1313 / 1291 |
| harbor | 134.7 | 118.3 | 96.4 | 30.1 | 1455 / 1418 |
| forest | 209.6 | 200.5 | 142.2 | 121.9 | 716 / 632 |

O depois inclui 200 objetos adicionais, crateras, materiais do terreno e a integração modular. Instanciamento, agrupamento e LOD reduzem chamadas de desenho; isso não significa que todas as vistas tenham FPS superior ao cenário menos detalhado.

## Carga de rede

Servidor autoritativo e 12 conexões reais por ENet/DTLS no mesmo PC. O cenário dispara armas, move quatro blindados, usa drones, gera explosões e desconecta um participante. As contas e a imortalidade são exclusivas do ensaio.

| Ensaio | FPS médio no cliente visível | 1% low | Frame p95 | Pico |
|---|---:|---:|---:|---:|
| 12 clientes completos, com Profiler | 32.2 | 4.1 | 60.8 ms | 274.1 ms |
| 1 cliente completo + 11 agentes leves, sem Profiler | 47.7 | 17.8 | 32.0 ms | 104.7 ms |

Os 11 agentes leves conservam a superfície local necessária à movimentação; a autoridade e o cliente visível mantêm o mapa inteiro. Há concorrência de CPU entre 13 processos. A instrumentação do Profiler também acrescenta custo, por isso não se interpreta a diferença entre as duas linhas como um ganho da otimização.

**A meta de 60 FPS estáveis em combate com 12 jogadores não foi demonstrada.** Os testes de carga passaram funcionalmente, mas ainda mostram picos e custo de CPU. Uma medição com clientes em PCs separados e a autoridade no Ubuntu continua necessária para separar o custo de simulação local do servidor de produção.

Logs do Profiler: `work/perf181/war-bench-library190-final2-12-server.stdout.log` e `war-bench-library190-final2-12-8.stdout.log`. Dados completos: `tests/library190-performance-comparison.json`.

## Verificação funcional

Os testes específicos verificam colisões idênticas no cliente/servidor, escavação, entrada e saída de trincheiras, encaixes, restauração do terreno, balística com resistência, passagem sonora de projéteis e tremor de impacto para operador/passageiro. A integração de rede também valida disparo, recarga, drone, morte, respawn e disparo do APC depois do respawn.
