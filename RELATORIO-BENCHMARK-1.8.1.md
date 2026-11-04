# Toque de Campo — benchmark de desempenho e correções

## Ambiente

- Godot 4.7.2, renderer GL Compatibility.
- NVIDIA GeForce GTX 1650.
- Medição gráfica em viewport interno 1920 × 1080, janela 1280 × 720, VSync desligado, FPS sem limite.
- Render-only: câmera e cena fixas, simulação parada, cinco fases de 5 segundos com aquecimento antes de cada fase.
- O teste de 12 clientes executa 12 clientes ENet e o servidor na mesma máquina; ele é um teste de estresse co-hospedado, não equivale a 12 computadores.

## Renderização antes/depois

Comparação do baseline salvo em `work/perf181-baseline.pck` com o código atualizado. Cada célula mostra baseline → atualizado.

| Cena | FPS médio | Chamadas de desenho | CPU de renderização (ms) | Primitivas |
|---|---:|---:|---:|---:|
| Combate | 125,7 → 126,0 | 2116 → 1881 (-11%) | 4,42 → 3,86 (-13%) | 2,064 M → 2,064 M |
| Térmica | 119,2 → 106,8 | 3279 → 1882 (-43%) | 5,08 → 3,51 (-31%) | 2,715 M → 2,064 M |
| Cidade | 131,5 → 114,2 | 1889 → 1401 (-26%) | 4,83 → 3,78 (-22%) | 1,651 M → 1,663 M |
| Porto | 106,4 → 104,1 | 2006 → 1470 (-27%) | 5,71 → 4,24 (-26%) | 2,133 M → 2,133 M |
| Floresta | 177,5 → 165,1 | 790 → 577 (-27%) | 2,47 → 2,05 (-17%) | 1,083 M → 1,089 M |

O ganho mais claro é a redução do trabalho de CPU e dos lotes de desenho, especialmente na térmica. O FPS desta rodada variou por fase e não subiu em todas elas; houve picos isolados de 89–100 ms em algumas capturas. Portanto, estes resultados não comprovam 60 FPS estáveis em combate.

O pico de memória render-only foi 348,0 MiB no baseline e 344,3 MiB na versão atual. Os tempos de GPU variaram bastante entre as execuções e não mostram uma melhora uniforme.

## Stress multiplayer válido já concluído

Na rodada válida anterior, 12 clientes entraram, atiraram, usaram veículos/drones, geraram explosões e um cliente desconectou durante a medição.

| Indicador do cliente que renderiza | Baseline | Otimizado |
|---|---:|---:|
| FPS médio | 53,95 | 53,53 |
| 1% low | 12,9 | 23,7 |
| Frame time p95 | 25,25 ms | 27,44 ms |
| Maior frame | 477,8 ms | 80,4 ms |
| CPU de renderização | 7,17 ms | 5,66 ms |
| GPU de renderização | 7,81 ms | 7,18 ms |
| Chamadas de desenho máximas | 1559 | 1264 |
| Memória | 361,5 MiB | 370,4 MiB |

Essa rodada reduziu chamadas de desenho e os picos mais graves, mas a média permaneceu perto de 53 FPS e a memória subiu. O teste não alcançou 60 FPS médios.

Uma repetição feita durante esta continuação não conectou nenhum cliente ao host dentro de 150 segundos; ela não gerou dados de desempenho e foi excluída. Assim, os números acima são da rodada multiplayer válida anterior, não uma confirmação da repetição atual.

## Combate offline com bots

Teste com um jogador humano estacionário e 11 bots reais de Guerra durante 30 segundos, com combate ativo:

| Indicador | Antes da redução do custo de IA | Após a redução |
|---|---:|---:|
| FPS médio | 51,1 | 58,8 |
| Física média | 18,15 ms | 10,75 ms |
| Frame time p95 | 24,38 ms | 19,41 ms |
| Frame máximo | 3535 ms | 200 ms |
| 1% low | 4,1 | 21,4 |
| Disparos aceitos no teste | 341 | 365 |
| Falhas de implantação | 0 | 0 |

Uma rodada por configuração; os valores são indicativos e ainda há um pico de 200 ms. Na rodada final, os bots encontraram alvos (449 aquisições, 339 verificações com linha livre), tentaram 393 disparos e o servidor aceitou 365.

## Mudanças feitas

- Térmica: troquei a sobreposição de material, que desenhava cada modelo novamente, por substituição temporária do material do modelo. Ao desligar a térmica, o material original é restaurado, inclusive se outro sistema o alterar durante a visualização.
- Cenário: objetos próximos compartilham materiais por família e carregam suas variações de cor por instância. Instâncias brancas não alocam buffer de cor. Geometria, texturas, colisões e cores visíveis foram preservadas.
- Bots offline: antitanque agora recebe o lançador correto para sua equipe; antes, bots do time da Stinger solicitavam RPG e a implantação era recusada. Os bots surgem em faixas separadas perto do front e priorizam A/B/C, em vez de dispersarem a partida até os portos distantes. A grade de navegação caiu de 88 mil para cerca de 22 mil células e as decisões táticas passaram de aproximadamente 43 para 20 por segundo no conjunto, mantendo movimento e disparo a cada passo físico.
- Armas online: snapshots de movimento são não confiáveis e podem chegar fora de ordem. Eles não alteram mais o identificador visual da arma; o RPC confiável de equipagem atualiza e reconstrói o modelo. Uma atualização de identidade que realmente mude a arma também reconstrói o modelo. Isso impede que um snapshot antigo faça a FAL exibir o modelo da sniper ou deixe o modelo AK associado a outra arma.

## Validação e limites

- Compilação/varredura do projeto no Godot: passou.
- Regressão de otimização: 19 verificações, 0 falhas.
- Regressão visual da térmica: 4 verificações, 0 falhas; cores de instância iguais, alvo quente visível e parede bloqueando a visão térmica.
- Benchmark offline: 12 participantes incluindo o humano, bots implantados e disparos aceitos.
- A repetição multiplayer de 12 clientes nesta continuação falhou antes de estabelecer conexões. A correção do modelo remoto foi compilada e seu fluxo de atualização foi revisado, mas não foi possível confirmar visualmente o modelo em uma sessão multiplayer nova nesta rodada.
- O stress test co-hospedado é muito mais pesado que 12 jogadores distribuídos entre computadores e não é uma medição de rede real.
- Meta de 60 FPS estáveis em 1080p ainda não foi demonstrada: o cliente do stress test ficou perto de 53,5 FPS, e a rodada offline com 11 bots ficou em 58,8 FPS médio com picos.
