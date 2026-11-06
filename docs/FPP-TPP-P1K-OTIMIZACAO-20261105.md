# P1k — custo do CollisionRig

05–06/11/2026. Branch `ia/fpp-p1k-retomada`, base `59477c5`.

## Escopo e limite

O trabalho preserva o piloto opt-in `--true-fpp-p1g-collision`, a cadência
física por tick e as 16 regiões. Não altera a câmera, o protocolo de rede,
a migração visual, a main nem a publicação. A branch experimental
`ia/fpp-p1k-physical-replacement` e suas reservas permanecem intactas.

P1k não está aprovada. O critério continua sendo mediana não pior e p99
até +5% fora do ruído. O gate completo também exige mapa renderizado com
28 bots e rede em mapa completo com clientes exportados.

## Diagnóstico e alteração

A implementação consolidada calcula uma pose física em todos os ticks.
O legado só articula o avatar quando o LOD visual vence. Compartilhar o
resultado nos ticks visuais elimina a duplicação nesses ticks, mas não
remove o custo dos demais. No cenário de 720 ticks e 28 atores são 14.490
solves físicos e 5.670 poses compartilhadas.

O perfil inicial desta rodada mediu, em média por lote de 28 atores,
3,245 ms no solver, 0,956 ms na captura, 0,851 ms na sincronização e
0,872 ms na aplicação visual. O profiler inclui overhead dos cronômetros,
executa a referência visual no mesmo ciclo e não é um teste de FPS.

As otimizações substituem o dicionário de entrada por campos tipados e
reutilizam a calibração e os buffers pertencentes a cada ator. A geometria
das pernas fica tipada, os mounts e transforms usam índices previamente
resolvidos e a sincronização usa referências ordenadas às regiões. A API
de dicionários continua disponível para os testes existentes. Translações
com base identidade dispensam multiplicações de matrizes completas.

Os estados são capturados novamente em cada solve. Não há quantização,
redução de frequência de colisão nem reutilização de uma pose de outro
tick. Os fallbacks e a invalidação ao trocar arma ou óptica são preservados.

## Evidência funcional

O teste de equivalência extrai de Git o solver anterior em `59477c5` e
compara entrada, calibração, apresentação, regiões e cano. Usa uma seed
fixa e 1.200 poses de cinco armas, com pitch, lean, movimento, transições
e recargas. Também confere 35 rejeições de estados fora do contrato.

Resultado final: 158.540 comparações, nenhuma falha. Maior erro numérico
1,47e-6. A comparação inclui a escrita dos transforms nos colisores.

As nove suítes funcionais passaram, incluindo 50 casos do arsenal,
60 casos de movimento, 60 transições, 90 verificações de mira aberta,
150 de recarga, 120 de ópticas, 42 de autoridade e 24 de dano/ragdoll.
O proxy manteve 16 regiões nas três posturas e nenhuma colisão duplicada.

ENet/DTLS local passou com servidor 15/15, atirador 2/2 e vítima 2/2 em
processos independentes. A primeira tentativa usou um certificado de QA
vencido e falhou no handshake. Um novo certificado temporário de localhost
permitiu a repetição, mantendo a validação TLS. Nenhuma chave foi versionada.

Os ensaios funcionais e de rede ocorreram depois do desempenho, em sequência.
Isso não substitui o gate de rede em mapa completo com clientes exportados.

## Medição e ambiente

O runner preserva pares alternados em processos independentes, a mesma
cadência visual 2/4/8, contagem de trabalho, estado final e hashes. Agora
também verifica todos os scripts de gameplay, rejeita amostras não finitas
e oferece cadência de relógio e afinidade opcionais. A espera de cadência
fica fora do intervalo medido e é igual nos dois braços.

A primeira tentativa A/A com um núcleo lógico, 240 ticks de aquecimento
e 1.200 amostras foi interrompida por variação elevada. Não pode aprovar
nenhum gate. Os logs parciais foram preservados em
`%TEMP%/p1k-final-20261105/aa/`.

Durante a execução a CPU registrou 54% de uso. Uma amostra de três segundos
mostrou atividade de navegador, NitroSense e dois testes Godot de outras
worktrees. Esses processos não foram encerrados. O teste headless mede
CPU e não diagnostica throttling térmico da GPU.

## Resultado dos cinco pares

A rodada completa usou cinco pares A/A e cinco A/B, 120 ticks de
aquecimento e 600 amostras por braço, cadência mínima de 16.667 µs,
sem fixar afinidade. Os dois braços tinham os mesmos scripts e estados
lógicos. Cada braço B atualizou as 16 regiões dos 28 atores, com
14.490 solves físicos, 5.670 poses compartilhadas e zero fallback.

| Medida | p50 | p95 | p99 |
| --- | ---: | ---: | ---: |
| Legado, mediana dos cinco braços A | 3,125 ms | 5,222 ms | 6,807 ms |
| Piloto, mediana dos cinco braços B | 5,248 ms | 9,018 ms | 12,365 ms |
| Mediana das diferenças por par A/B | +73,3% | +70,1% | +64,9% |
| Maior variação absoluta por par A/A | 19,5% | — | 77,2% |

**Gate reprovado.** O piloto piorou a mediana em todos os cinco pares.
O controle excedeu 5% em p50 e p99, portanto também é inadequado para
certificar uma diferença pequena. Não é possível atribuir toda a regressão
ao ruído, nem atribuir a diferença em relação à rodada antiga apenas à
otimização: a cadência de relógio e a carga externa mudaram.

Após a rodada, houve somente uma guarda adicional na API de dicionários
`solve()` para rejeitar calibração vazia antes de acessá-la e comentários.
O caminho de runtime medido, `capture()`/`solve_cached()`/`sync_packed()`,
permaneceu igual. A equivalência final e a rede foram validadas depois
dessa guarda. Os hashes das evidências distinguem essas revisões.

Evidências versionadas, com amostras brutas e hashes:

- [Controle A/A](evidence/fpp-p1k-20261106/aa.json)
- [Comparação A/B](evidence/fpp-p1k-20261106/ab.json)
- [Nove suítes](evidence/fpp-p1k-20261106/regression.json)
- [Equivalência numérica](evidence/fpp-p1k-20261106/equivalence.json)
- [Rede ENet/DTLS](evidence/fpp-p1k-20261106/network.json)

## O que ainda bloqueia

É preciso reduzir o custo adicional dos 14.490 solves sem omitir ticks
físicos, obter um controle A/A estável e repetir o gate. A troca por uma
GPU melhor pode ajudar os ensaios renderizados, mas não comprova a correção
desse custo de CPU. Depois disso ainda faltam mapa completo renderizado
com 28 bots e rede com clientes exportados. P2a e merge na main aguardam
esses gates.

## Reproduzir

Reservar primeiro os artefatos escritos pelos runners conforme suas
docstrings. Executar os ensaios de desempenho sem regressões simultâneas.

```powershell
python tests/run_true_fpp_p1k_solver_equivalence.py --engine $godot
python tests/run_true_fpp_p1k_regression.py --engine $godot

$p1kRun = Join-Path $env:TEMP ("p1k-" + [guid]::NewGuid())
python tests/run_true_fpp_p1k_paired_cost.py --engine $godot --mode aa --warmup 120 --samples 600 --pace-usec 16667 --output (Join-Path $p1kRun "aa")
python tests/run_true_fpp_p1k_paired_cost.py --engine $godot --mode ab --warmup 120 --samples 600 --pace-usec 16667 --output (Join-Path $p1kRun "ab") --control (Join-Path $p1kRun "aa/results.json")
```

Um A/B com controle A/A inválido não passa, mesmo que tenha números
favoráveis. As amostras brutas e os hashes ficam nos diretórios de saída.
