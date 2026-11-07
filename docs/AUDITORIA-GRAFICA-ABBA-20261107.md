# Auditoria gráfica A/B/BA — GTX 1650 (07/11/2026)

**Decisão de promoção: NÃO APROVAR FPS / HOLD para lançamento.**
As duas flags são candidatas a acelerar o **carregamento** sob opt-in. Os dados de janela gráfica aquecida não sustentam ativá-las como otimizações de FPS ou de P95/P99. A `main`, distribuição pública e servidores de produção não foram alterados nesta bateria.

## Condições
- Código: `ia/auditoria-otimizacoes-20261107@b08bd503e0538fdd171620a2862d7bf583b9c63f`.
- Máquina: `DESKTOP-JJ7U3G3`, GTX 1650, Godot 4.7.2 stable, Jolt, Forward+.
- Modo Guerra **Favela**, 1920 × 1080, Médio, escala 100%, VSync OFF, FPS uncapped, **28 bots**.
- Runner oficial `tests/benchmark/run_benchmark.py`: 10 s de aquecimento + 60 s de medição por execução; verificação de foco, população dos bots, rastro completo e telemetria NVIDIA alinhada.
- Ordem alternada **OFF → ON → ON → OFF** para atenuar variação de primeira execução e deriva térmica. Quatro coletas **válidas**, foco 100%, entre 55 e 56 amostras GPU em cada janela. Todas **REPROVADAS** pelo gate numérico de desempenho.
- Flags OFF: `TDC_IA2_HOUSING_CACHE=0`, `TDC_IA2_HEADLESS_SKIP_VISUAL_HILLSIDE=0`.
- Flags ON: `TDC_IA2_HOUSING_CACHE=1`, `TDC_IA2_HEADLESS_SKIP_VISUAL_HILLSIDE=1`.

## Resultados por rodada

| Rodada | Flags | FPS médio | 1% low FPS | P95 ms | P99 ms | Frames >50 ms/min | Frames >100 ms | Foco |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| 1 | OFF | 26,405 | 10,587 | 54,544 | 74,135 | 140 | 3 | 100% |
| 2 | ON | 24,888 | 10,096 | 61,381 | 78,430 | 235 | 3 | 100% |
| 3 | ON | 25,707 | 9,868 | 58,095 | 82,637 | 163 | 4 | 100% |
| 4 | OFF | 25,384 | 11,123 | 54,829 | 71,412 | 170 | 1 | 100% |

## Médias por condição (n=2 por condição)

| Indicador | OFF | ON | Diferença relativa ON |
|---|---:|---:|---:|
| FPS médio | 25,894 | 25,298 | −2,30% |
| 1% low FPS | 10,855 | 9,982 | −8,04% |
| P95 ms | 54,687 | 59,738 | +9,24% (pior) |
| P99 ms | 72,774 | 80,534 | +10,66% (pior) |
| >50 ms por minuto | 155 | 199 | +28,39% (pior) |
| >100 ms por execução | 2,0 | 3,5 | +75% (pior, contagem pequena) |
| Tempo médio da física monitorada, ms | 18,139 | 17,887 | −1,39% |
| Tempo médio GPU, ms | 8,582 | 8,955 | +4,35% |

**Ressalva estatística:** apenas dois runs por condição. Não se pode afirmar regressão causal provocada pelas flags. Porém, nesta máquina, os ganhos de FPS observados anteriormente na segunda GTX 1650 **não se reproduziram**.

## Cruzamento com DESKTOP-R0I0NQG
Na R0I foram feitos **um par válido** (ON e OFF), com GPU sincronizada e foco 100%, mesmos parâmetros. Aquele par mostrou FPS médio 21,758 OFF → 26,142 ON (+20,1%) e P99 120,400 OFF → 85,489 ON (−29,0%). Os dados estão em `docs/benchmark-results/auditoria-gtx1650-r0i-20261107.json`.

Esse contraste entre máquinas/rodadas confirma a necessidade de controlar variação do cenário, carga e intervalos do sistema operacional antes de atribuir melhora à flag.

## Separar *startup* de FPS
- **Cache de lotes da Favela:** melhorou consistentemente o planejamento e a construção durante o carregamento em cinco pares headless da máquina JJ7. Tem fallback por assinatura e só carrega quando `TDC_IA2_HOUSING_CACHE=1`.
- **Skip de planejamento de vegetação headless:** a condição só executa quando `kit.visuals == false`; não remove objetos visuais de um cliente renderizado. A medição de cliente Forward+ não é teste de ganhos desta opção no servidor.
- Os dois controles acima ocorrem no *startup* e **não deveriam ser tratados como ganhos diretos no loop contínuo de 60 segundos**, medido após aquecimento.
- O candidato opt-in permanece adequado apenas para nova bateria de *startup/headless*, junto de validação de export/caches e integridade. Não publicar alegação de FPS otimizado a partir destes A/B.

## Gate de atualização e estabilidade
- FPS alvo 60, 1% low 35, P95 até 25 ms, P99 até 33,3 ms, >100 ms zero. **Nenhuma das quatro coletas passou**.
- Telemetria durante a janela mostra tempos GPU de ~8–9 ms e física monitorada ~18 ms, com vários ticks por quadro. Próxima prioridade técnica: reduzir custo de atualização de bots/poses/corpo e física sem alterar contagem de 28 bots, qualidade ou mecânica.
- ENet/DTLS local de QA ainda não admitiu um cliente com flags ON ou OFF. Foi observado `TLS handshake error -30464` no fixture QA. A falha igual no baseline não comprova regressão da flag. Não alterar transporte ou certificados de produção sem experimento isolado e revalidação.
- **NÃO integrar automaticamente na `main` nem publicar uma nova build.** Manter Forward+ desktop como principal.

## Dados brutos e auditabilidade
`docs/benchmark-results/auditoria-gtx1650-jj7-abba-20261107.json` inclui quatro séries completas de frame times, picos, sondas CPU/física/GPU, amostras NVIDIA, hashes SHA256 dos JSON originais, metadados de foco e integridade. Arquivos originais permanecem em `work/benchmark-results/`, ignorado pelo Git.

Os testes foram coletados mantendo a janela Godot em foco durante 100% das quatro medições.
