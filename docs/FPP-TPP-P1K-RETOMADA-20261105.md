# Retomada da P1k FPP/TPP

05/11/2026 · Guerra · Godot 4.7.2 · branch ia/fpp-p1k-retomada

A etapa parte de 2e0d5e2, a base de integração FPP da 1.13.3. O CollisionRig
continua disponível pelo piloto de QA `--true-fpp-p1g-collision`.

## Pose física

- Os fuzis e a Glock dos atores remotos podem alimentar apresentação e colisores
  com a mesma avaliação. Em um tick omitido pelo LOD visual, a física usa o
  solver sem aplicar a pose às malhas.
- Para as ações especiais que ainda usam o rig legado, o fallback calcula a pose
  da ação no tick atual antes de publicar os colisores. Uma apresentação anterior
  no mesmo tick pode ter sido produzida com outro estado, como antes de selecionar
  uma granada.
- A calibração preserva a geometria neutra de joelhos e botas ao equipar em
  postura baixa e acompanha a instância da óptica montada. Passageiros expostos
  usam os pivôs atualizados pelo assento do veículo.

## Validação funcional

| Ensaio | Resultado |
| --- | --- |
| P1b a P1i | Nove suítes passaram. Inclui 60 comparações em transições de postura e 42 verificações de autoridade, entre elas a recarga remota e a remontagem da óptica. |
| P1j ENet/DTLS local | Servidor 15/15, atirador 2/2 e vítima 2/2. |
| Guerra offline no Afeganistão, headless | 900 ticks com um jogador e 28 bots. Todos os bots se moveram, houve 38 tiros registrados e a inspeção dos 22 bots de infantaria ativos ao final encontrou zero erros de autoridade. |

A última guarda mantém o fallback durante a fase aérea de uma corrida em que
a passada já chegou a zero e o peso de sprint ainda está decaindo. A regressão
foi verificada para as cinco armas e não altera a carga pareada abaixo, que
mantém os atores no chão. Um par de confirmação após a guarda também
registrou regressão, com +140,3% no p50 e +105,4% no p99.

## Desempenho sintético

O código medido em 989c44f rodou no i5-11400H com cinco pares A/A e cinco pares
A/B em processos independentes, alternando a ordem. Cada braço teve 120 ticks
de aquecimento e 600 amostras de um lote de 28 atores, com a mesma cadência
visual de 2, 4 ou 8 ticks nos dois braços. O ensaio mede o tempo de pose e
sincronização dentro do script.

| Medida | p50 | p95 | p99 |
| --- | ---: | ---: | ---: |
| Legado, mediana dos cinco braços A | 2,391 ms | 4,009 ms | 5,178 ms |
| Piloto, mediana dos cinco braços B | 4,791 ms | 7,371 ms | 9,011 ms |
| Mediana das diferenças relativas por par A/B | +97,6% | +80,5% | +101,6% |
| Maior variação absoluta por par A/A | 27,4% | — | 45,7% |

Cada execução do piloto fez 14.490 poses físicas sem aplicação visual e
5.670 poses compartilhadas, com zero fallback nessa carga e 16 regiões
ativas por ator. As contagens incluem o aquecimento.

O controle A/A excedeu 5% em p50 e p99. O A/B observou regressão em todos os
pares e excedeu os limites de mediana e cauda. O ensaio é headless e sintético.
O smoke do Afeganistão verifica a execução em mapa completo. A aprovação ainda
exige desempenho pareado estável e a matriz renderizada com 28 bots, além da
validação em mapa completo com clientes exportados. A P2a aguarda esses gates.

## Reproduzir

Em uma worktree importada pelo Godot, apontar `$godot` para o executável local.
Cada braço grava amostras, hashes e logs no diretório de saída.

```powershell
$fppRun = Join-Path $env:TEMP ("toque-fpp-p1k-" + [guid]::NewGuid())
python tests/run_true_fpp_p1k_paired_cost.py --engine $godot --mode aa --output (Join-Path $fppRun "aa")
python tests/run_true_fpp_p1k_paired_cost.py --engine $godot --mode ab --output (Join-Path $fppRun "ab") --control (Join-Path $fppRun "aa/results.json")
```
