# P1g — diagnóstico e comparação reproduzível de custo

Data: 04/11/2026. Base: `ia/fpp-validacao-rede`, commit `09162e5`.
Worktree: `campo-worktrees/fpp-p1g-performance`, branch `ia/fpp-p1g-performance`.

**O gate de desempenho continua fechado.** Não há migração de câmera/visibilidade,
merge na main ou publicação neste trabalho. O piloto mantém a flag opt-in de QA.

## Causas identificadas

O caminho P1g conserva a atualização visual com LOD e acrescenta captura de estado,
solver físico e sincronização de 16 áreas por ator em cada tick. Portanto o custo
é somado ao rig existente, em vez de substituí-lo. Em estados rejeitados, ainda há
construção do estado, validação e espelhamento da hierarquia antiga.

O ensaio anterior tinha 90 amostras, rodadas sempre baseline→piloto, sem reiniciar
o estado dos atores. Como o LOD usa o relógio real, o custo do candidato também
altera quais atualizações visuais vencem o prazo. Isso confunde a comparação.
Além disso, o `pass` daquele fixture verificava autoridade e contagem de solves;
não verificava um limite de mediana ou p99. Não representa aprovação de desempenho.

Uma primeira rodada instrumentada nesta worktree (180 amostras, 60 de aquecimento,
transições mais espaçadas que o fixture original) mediu aproximadamente, por lote
de 28 atores: binding 0,18 ms, estado 1,21 ms, solve 2,85 ms, sync 0,71 ms,
fallback 0,27 ms. Todos os 1.107 fallbacks classificados foram transições prone.
Esses tempos incluem overhead da instrumentação e servem para localizar custo,
não para aprovar ganho. Essa rodada preliminar não tem a carga final de transições.

O primeiro A/A de três pares, sem instrumentação, variou +6,8% na mediana e +60,1%
no p99 agregados, mesmo executando o mesmo código dos dois lados. Uma amostragem
do host também encontrou carga de CPU concorrente em NitroSense, navegador e
Explorer. Nenhum aplicativo do usuário foi encerrado. Não há evidência suficiente
para atribuir essa variação a temperatura, energia ou a um aplicativo específico.

## Mudanças no solver e diagnóstico

- A geometria neutra não amostra mais `GameReloadPose.state()` quando não existe
  recarga ativa. Nenhum consumidor usava a timeline nessa condição.
- No cálculo dos braços, as inversas de `body` foram substituídas pela subtração
  da origem e pela base já conhecida: `body` é construído com base identidade.
- Perfil opt-in divide binding, state, solve, sync e fallback; conta os motivos
  de fallback. Desligado, não executa chamadas ao relógio de instrumentação.
- Não há mudança nas tolerâncias do solver nem ampliação dos estados aceitos.

## Novo ensaio

`tests/true_fpp_p1g_paired_cost.gd` usa 28 atores, cinco armas e as mesmas fórmulas
de movimento do fixture anterior. Calibra todos em pose neutra antes de ativar
o piloto, muda postura a cada 36 ticks e fixa o orçamento visual de cada ator em
2/4/8 ticks nos dois lados. Isso retira a dependência do cronômetro do próprio
candidato; não altera o LOD do gameplay. Valida a mesma quantidade de trabalho
visual e o hash do estado lógico final entre os braços. No piloto exige 448
regiões, zero regiões antigas ativas e uma solução/fallback por ator por tick.

O runner abre processos independentes com perfis temporários, alterna A/B e B/A,
preserva os tempos de cada amostra, calcula deltas por par e guarda hashes dos
fontes e do engine. No Windows inicia diretamente o engine, com saída redirecionada,
evitando que timeout mate somente o wrapper console e deixe outro Godot rodando.

O gate sintético exige cinco pares A/B sem profiling, mediana não pior e p99 até
+5%, além de controle A/A de cinco pares com o mesmo engine/fontes e variação
absoluta de mediana/p99 até 5% em cada par. Controle ausente ou instável impede
aprovação. Esse critério conservador de controle não aumenta o limite do plano.

Exemplo (paths do engine conforme a máquina):

```powershell
python tests/run_true_fpp_p1g_paired_cost.py --engine <Godot> --mode aa --pairs 5 --output work/p1g-perf/aa-optimized.json
python tests/run_true_fpp_p1g_paired_cost.py --engine <Godot> --mode ab --pairs 5 --control work/p1g-perf/aa-optimized.json --output work/p1g-perf/ab-optimized.json
```

Este é um ensaio sintético de CPU/física. Não contém mapa completo, IA, nav,
renderização nem rede. Aprovação dele não substituiria os cinco pares renderizados
de 120 segundos, 28 bots, 40 BR, listen/dedicated e builds exportados do plano.

## Validação funcional realizada

Godot 4.7.2, nove suítes com exit 0: arsenal 50 casos/30 rejeições; prone 25 e
movimento 60; pelve 2 sequências; ADS ferro 90/10 rejeições; recarga 150/10 rejeições;
ADS óptico 120/16 rejeições; cobertura autoritativa 27; autoridade do proxy 30;
dano/ragdoll 24. Logs em diretório temporário `p1g-functional-evsqtm1b`.

ENet/DTLS local: servidor 15/15, atirador 2/2, vítima 2/2, todos exit 0, certificado
efêmero de localhost. Logs em `true-fpp-p1j-gd1dmzp7`. Ainda usa o campo de tiro
plano de QA e não certifica admissão em mapa completo nem rede externa.

## Limites físicos pendentes

O fallback atual copia transforms do rig visual. Se esse rig não foi atualizado
por causa do LOD, espelhá-lo não garante pose física fresca para ações rejeitadas.
O teste de fallback existente prova paridade com o legado, não independência dele.
Esse limite também precisa ser resolvido antes de ativar o piloto por padrão.

Mesmo eliminando alocações desnecessárias, o piloto ainda acrescenta uma passagem
completa de matemática e atualização de áreas à apresentação. Se o custo continuar
acima do limite, é necessário reduzir essa duplicação dentro de P1 e comprovar
equivalência, não ocultar a diferença mudando carga, tolerâncias ou frequência física.

## Resultado final desta investigação

Cinco pares com 600 amostras por braço e sem instrumentação. Os deltas são a
mediana das variações relativas por par.

| Comparação | p50 | p95 | p99 |
| --- | ---: | ---: | ---: |
| A/B, piloto contra legado | +136,1% | +131,8% | +144,1% |
| A/A, maior variação absoluta por par | 40,6% | — | 90,6% |

O A/B excedeu o limite e o A/A excedeu a margem de ruído. Os JSONs com
amostras e hashes estão em `work/p1g-perf/aa-optimized.json` e
`work/p1g-perf/ab-optimized.json`. Os hashes correspondem aos fontes desta
worktree. As rodadas diagnósticas anteriores usaram outra cadência de postura
e não servem para estimar o ganho isolado das duas otimizações.

Em 05/11, a branch `ia/fpp-p1k-retomada` passou a concentrar a investigação
da pose compartilhada. Seu relatório `docs/FPP-TPP-P1K-RETOMADA-20261105.md`
(commit `59477c5`) registra regressão pareada de +97,6% no p50 e +101,6%
no p99, ENet local 19/19 e smoke headless com 28 bots no Afeganistão.
As duas comparações usaram cargas diferentes. O ponto de retomada da P1 é
a branch P1k, com desempenho renderizado pareado e rede com clientes
exportados em mapa completo ainda pendentes.
