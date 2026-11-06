# Requisito oficial de desempenho — GTX 1650

**Status:** metas de aceitacao do projeto, nao alegacao de performance alcancada.
**Hardware de referencia:** NVIDIA GeForce GTX 1650 (4 GiB), preferencialmente testar notebook e desktop separadamente. Diferencas de TGP, resfriamento e CPU devem ser registradas.
**Configuracao padrao:** Godot Forward+; 1920 x 1080; qualidade Medio; escala interna 100%; VSync desligado; FPS sem limite durante a medicao; 28 bots ativos no modo Guerra (Favela como teste principal, Ucrania e Afeganistao como regressao).

## Metas numericas obrigatorias (60 s de coleta apos 10 s de aquecimento)

| Indicador | Meta |
| --- | --- |
| FPS medio | >= 60 |
| FPS mediano | >= 60 |
| 1% low | >= 35 FPS |
| Frametime P95 | <= 25 ms |
| Frametime P99 | <= 33,3 ms |
| Quadros acima de 50 ms | <= 1 por minuto |
| Quadros acima de 100 ms | 0 |
| Bots | 28 efetivamente instanciados e deployados |
| Escala interna | 1920 x 1080, 100% |

Se qualquer um dos limites for excedido, **o resultado e REPROVADO** mesmo com FPS medio acima de 60. O objetivo central e eliminar engasgos fortes / caudas longas no frametime. Medir sem VSync permite isolar a carga do motor; validar com VSync/VRR depois na jogabilidade.

## Regras de validacao

1. Executar `python tests/benchmark/run_benchmark.py --operation favela`, com a mesma versao de Godot, hash do projeto e configuracoes em ambas as maquinas.
2. Coletar FPS, 1% low, P95, P99, quadros >50/100 ms e, quando possivel, temperatura/clock/utilizacao NVIDIA. Comparar tambem CPU do processo e tempo de fisica.
3. Rodar no minimo tres vezes, registrar mediana por indicador e separar primeira execucao (compilacao de pipelines/cache) de execucoes aquecidas; nao esconder travamentos da primeira partida.
4. Repetir Ucrania e Afeganistao. Para uma mudanca de IA, testar 14, 28 e 57 bots em ferramenta separada; o gate oficial atual valida 28.
5. Validar ainda em partida real: caminhada, camera girando, tiroteio, explosoes, veiculos, entrada/saida e multiplayer. O benchmark de camera fixa **nao** substitui esses testes.
6. Se houver throttling, registrar temperatura, clocks, potencia e perfil de energia; nao atribuir automaticamente travamentos ao codigo. Jamais aumentar artificialmente os FPS reduzindo a escala abaixo de 100% para aprovar o gate.
7. Uma otimizacao que aumenta FPS medio mas agrava P99 ou cria travadas >100 ms nao deve ser tratada como melhoria aprovada.

Nenhuma alteracao de renderizador padrao deve ser feita apenas para passar no teste: **Forward+ continua como principal** enquanto os dados de desempenho e estabilidade determinam o plano de otimizacao. O benchmark e reprodutivel, mas tem escopo limitado a WarGame offline e camera estacionaria. Ao comparar contra resultados legados de `work/`, rotular como **nao diretamente comparavel** a menos que fixture e parametros sejam identicos.

## Verificacao funcional inicial — 06/11/2026 (nao oficial)

Na maquina original (NVIDIA GTX 1650, Godot 4.7.2, Forward+, Favela, 1920x1080, Medio, escala 100%, 28 bots), uma rodada **curta** de 10 s, com apenas 4 s de aquecimento, confirmou que o fixture executa e produz dados.

- FPS medio: 26,80; mediano: 29,88; 1% low: 6,69 FPS.
- P95: 60,10 ms; P99: 106,35 ms; 3 quadros acima de 100 ms.
- Media medida de fisica: 19,21 ms; GPU: 7,85 ms.
- Resultado: **REPROVADO** pelos objetivos de fluidez; nao caracteriza o desempenho de uma rodada oficial de 60 s nem, isoladamente, comprova throttling ou gargalo unico.
- Artefatos locais: `work/benchmark-results/*favela-forward_plus-smoke.*` (ignorados no Git).

Importante: resultado de verificacao anterior ao commit do runner. Para comparacoes entre computadores, rodar novamente o **mesmo commit** do benchmark e documentar as configuracoes de energia/temperatura.
