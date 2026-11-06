# P1k — comparação de custo com a consulta de água equivalente

06/11/2026 · Guerra · base `3670699` · branch `ia/fpp-p1k-retomada`

## Ajuste da medição

O ciclo físico normal consulta `in_water()` em `locomotion.advance()` antes
do processamento da pose. A fixture anterior não executava esse trecho e
podia cobrar do piloto uma consulta que os dois caminhos já teriam feito.
Agora a fixture faz essa consulta para os 28 atores nos dois braços, antes
do intervalo cronometrado de pose. O ensaio verifica 20.160 consultas, zero
atores na água e o mesmo estado final nos dois braços. Ela continua sendo
um ensaio sintético, sem substituir uma medição da partida completa.

## Solver

O cálculo da passada esquerda e direita compartilha a mesma função seno,
quantidade de movimento e inclinação. A orientação da mão, a proporção do
braço e a verificação de pistola são calculadas uma vez por pose. O solver
continua executando para cada estado e tick físico que precisa dele.

A comparação com o código em `3670699` passou 1.200 poses, 158.540
comparações, 35 rejeições e erro numérico máximo zero. O diagnóstico
alternou a ordem dos solvers em cada tick. Em uma execução de 360 amostras,
observou 2,384 ms de p50 no anterior e 2,320 ms no atual, com p99 de 3,749
e 3,769 ms. É uma amostra exploratória e não permite afirmar ganho estável.

## Windows QA release

Os cinco pares A/A tiveram variação absoluta máxima de 5,25% no p50 e
35,02% no p99. Os cinco pares A/B observaram +68,20% no p50, +53,93% no p95
e +56,42% no p99. A mediana dos tempos dos braços foi de 2,789 ms no
legado e 4,565 ms no piloto. Os 28 atores mantiveram as 16 regiões ativas,
14.490 poses físicas adicionais, 5.670 poses compartilhadas e zero fallback
em cada braço B. Os valores são por lote dentro da seção de pose.

O controle A/A não ficou estável no limite definido e o A/B excedeu os
limites. O desempenho continua reprovado, inclusive após igualar a consulta
de água. As medições anteriores usavam outra carga, portanto não é válido
calcular um ganho direto a partir da diferença dos percentuais.

- [Controle A/A Windows](evidence/fpp-p1k-20261106/release-water-aa.json)
- [Comparação A/B Windows](evidence/fpp-p1k-20261106/release-water-ab.json)

## Servidor Linux

O servidor usa Xeon E5-2697A v4 com oito CPUs virtuais. O pacote de QA foi
exportado para Linux, verificado por hash e executado com prioridade baixa em
uma pasta temporária isolada. Os serviços da partida e a versão publicada
continuaram em execução. O ensaio utiliza o runtime de release e o mesmo
cenário sintético de 28 atores, sem carregar uma partida completa.

O A/A teve variação absoluta máxima de 3,80% no p50 e 11,08% no p99, de modo
que o controle não passou. No A/B, a mediana das diferenças pareadas foi
+63,30% no p50, +52,10% no p95 e +48,70% no p99. Todos os braços do piloto
mantiveram 28 atores, 16 regiões por ator e zero fallback nessa carga.
O resultado demonstra regressão no ensaio, mas não quantifica o impacto
em FPS, latência ou capacidade de uma partida real no servidor.

- [Controle A/A Linux](evidence/fpp-p1k-20261106/server-water-aa.json)
- [Comparação A/B Linux](evidence/fpp-p1k-20261106/server-water-ab.json)

## Funcional e rede

As nove suítes funcionais passaram nesta revisão. Incluem as transições de
postura, cinco armas, recarga, ópticas, autoridade, dano e ragdoll. A rede
ENet/DTLS local passou 15/15 no servidor e 2/2 em cada um dos dois clientes.
O certificado de teste foi temporário e não foi incluído nas evidências.

- [Nove suítes](evidence/fpp-p1k-20261106/regression-water.json)
- [Rede local](evidence/fpp-p1k-20261106/network-water.json)
- [Equivalência do solver](evidence/fpp-p1k-20261106/equivalence-water.json)

## Próximos gates

O custo físico adicional continua acima do orçamento, tanto no Windows como
no Linux do servidor. É necessário reduzir esse custo e obter um A/A estável,
sem diminuir a cadência física nem omitir regiões. Só então avançar para
medição renderizada de mapa completo e rede com clientes exportados. P2a,
migração visual e integração na main permanecem bloqueadas pelos gates.

Para reproduzir, executar `tests/run_true_fpp_p1k_equivalence_optimized.py`,
`tests/run_true_fpp_p1k_regression.py` e `tests/run_true_fpp_p1j_network.py`.
O Linux usa `tests/export_true_fpp_p1k_linux_qa.py` e
`tests/run_true_fpp_p1k_linux_benchmark.py`, com os arquivos temporários
reservados conforme as instruções nos próprios scripts. Os dados brutos e
hashes estão preservados nos JSONs acima.
