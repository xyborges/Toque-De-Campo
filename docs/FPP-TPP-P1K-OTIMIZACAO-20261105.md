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

## Benchmark no executável de release

O template Windows de release não executa a fixture passada por `--script`.
O exportador usa a mesma carga como cena inicial do preset Windows QA e
restaura o `project.godot` após gerar o pacote. O manifesto vincula o
executável, o PCK, os scripts de gameplay e a fixture ao export.

Com cinco pares por modo e a mesma cadência da rodada do editor, a
variação absoluta máxima do A/A foi 10,7% no p50 e 23,8% no p99. O A/B
observou +68,1% no p50, +52,8% no p95 e +60,3% no p99. Em todos os braços
B, os 28 atores mantiveram autoridade física nas 16 regiões, com 14.490
solves físicos, 5.670 poses compartilhadas e zero fallback. O controle
excedeu 5% e o A/B continua fora do orçamento. O smoke do exportador
validou a entrada da cena e a coleta de amostras em um novo pacote, com
um só par e variação alta.

- [A/A no release](evidence/fpp-p1k-20261106/release-aa.json)
- [A/B no release](evidence/fpp-p1k-20261106/release-ab.json)

No modo normal, `WarPlayer._physics_process()` consulta a água antes da
pose. A fixture chama a pose diretamente. Por isso, nos ticks em que o
LOD visual pula a pose, a primeira consulta pode cair no solver do
piloto. No profiler diagnóstico do editor, antecipar a consulta para
fora de `capture()` reduziu a média de captura de 0,614 para 0,396 ms
por 28 atores. A própria consulta custou 0,333 ms. São duas execuções
exploratórias. O solver ainda ficou entre 1,73 e 1,82 ms e o A/B
versionado mantém a carga original.

Use a worktree isolada, com os templates Windows instalados, e reserve os
caminhos temporários listados em `tests/export_true_fpp_p1k_qa.py`.

```powershell
$p1kRun = Join-Path $env:TEMP ("p1k-release-" + [guid]::NewGuid())
$p1kBuild = Join-Path $p1kRun "build"
python tests/export_true_fpp_p1k_qa.py --engine $godot --output $p1kBuild
$p1kExe = Join-Path $p1kBuild "P1kBenchmark.exe"
python tests/run_true_fpp_p1k_paired_cost.py --engine $p1kExe --exported --mode aa --pace-usec 16667 --output (Join-Path $p1kRun "aa")
python tests/run_true_fpp_p1k_paired_cost.py --engine $p1kExe --exported --mode ab --pace-usec 16667 --control (Join-Path $p1kRun "aa/results.json") --output (Join-Path $p1kRun "ab")
```

A fixture roda headless. Ela mede o custo de pose e colisão dos 28 atores
no runtime de release. Para fechar o plano ainda são necessários o mapa
completo renderizado com 28 bots e a rede em mapa completo com clientes
exportados.
