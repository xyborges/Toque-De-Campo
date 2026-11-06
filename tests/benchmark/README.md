# Benchmark oficial portatil — Guerra / GTX 1650

A fonte versionada do benchmark e `tests/benchmark/war_1080p_benchmark.gd`. Nao utiliza `work/` como codigo-fonte, nem caminhos absolutos para o Godot. A pasta `work/benchmark-results/` armazena somente resultados locais e continua ignorada no Git.

## Primeiro uso (ou apos atualizar assets)

1. Instale Godot 4.7.2 e Python 3.10+ na maquina.
2. Abra o projeto no editor Godot uma vez para importar os recursos, ou execute `godot --headless --editor --path . --import`.
3. Feche o editor e outros processos Godot que competem por CPU/GPU. Deixe o computador conectado a energia e espere a temperatura estabilizar.
4. No terminal da **raiz** do clone, execute:

```powershell
python tests/benchmark/run_benchmark.py --operation favela --renderer forward_plus
```

Se Godot nao estiver no PATH, informe `--godot "C:\caminho\Godot_v4.7.2-stable_win64_console.exe"`, ou defina `GODOT_BIN`. Tambem funciona com `./tests/benchmark/run_benchmark.ps1 -...`? **Nao**: o wrapper apenas encaminha os argumentos Python, portanto use `./tests/benchmark/run_benchmark.ps1 --operation favela`.

## Operacoes e resultados

- `--operation favela`, `afghan` ou `ukraine`; `--renderer forward_plus` (padrao) ou `gl_compatibility`.
- `--warmup 10 --duration 60` sao os valores padrao. Para diagnostico rapido, `--duration 10`, mas nao compare com a linha de base oficial.
- `--godot PATH` e `--dry-run` sao opcionais. `--allow-fail` retorna codigo zero mesmo quando o hardware nao passa no gate, mantendo o status REPROVADO no relatorio.
- Arquivos: `work/benchmark-results/<id>.json` (Godot), `<id>.summary.json` (metadados + criterios), `<id>.log` (diagnostico), e `<id>.gpu.csv` (telemetria NVIDIA quando disponivel).
- O runner termina com status diferente de zero quando o Godot falha, falta o resultado ou algum limite de desempenho nao foi atendido.

## Escopo e limites

Teste de uma partida **offline real** de Guerra com 28 bots instanciados/deployados, camera estacionaria, 1080p/Médio/100%, VSync e limitador desativados. Nao equivale a multiplayer real nem a um percurso completo da Favela; nao representa exatamente o fixture legado de Afeganistao/Ucrania. Os resultados sao comparaveis entre maquinas somente com mesmo commit, mesma operacao, renderer, duracao, aquecimento e versao do Godot. Um `PASS` nao prova ausencia universal de travamentos: e um gate de regressao, a complementar com caminhada, combate, veiculos e rede.

O cenario imprime `PERF_1080P_READY` e `PERF_1080P_RESULT` e valida a resolucao interna e 28 bots antes de medir. Consulte `docs/PERFORMANCE-GTX1650-BASELINE.md` para os objetivos oficiais de fluidez.

## Protocolo v2: integridade obrigatoria da coleta

O runner marca **COLETA_INVALIDA** e retorna codigo **4** quando falta qualquer condicao de validade, independentemente da flag --allow-fail:

- A janela Godot precisa estar em primeiro plano durante **100% dos quadros**. Uma perda de foco invalida a medicao (nao confundir com FPS baixo).
- Os 28 bots devem estar presentes durante a coleta, amostrados pelo menos uma vez por segundo; minimo e final precisam ser 28.
- O rastro completo de tempos de quadro precisa corresponder as estatisticas e aos horarios de inicio e fim.
- Forward+, 1920x1080, escala 100%, VSync desativado e sem limite de FPS no perfil oficial; nunca usar flags de congelamento.
- Para NVIDIA, nvidia-smi precisa fornecer amostras da **mesma placa usada pelo Godot**, dentro da janela, em quantidade minima de metade da duracao em segundos. Sem essas amostras, resultado invalido.
- O JSON inclui foco, transicoes, populacao de bots, frame_time_trace_ms e measurement_window_unix_ms em epoch UTC.

Novos artefatos (ignorados pelo Git):
- <id>.json: relatorio bruto com sequencia de todos os frames.
- <id>.summary.json: status final e verificacoes de integridade e performance separadas.
- <id>.log: stdout/stderr completos.
- <id>.gpu.csv: todas as amostras NVIDIA, inclusive carregamento.
- <id>.gpu-measurement.csv: apenas amostras da GPU correta dentro da janela oficial.

O recorte da GPU usa timestamps UTC em milissegundos medidos na mesma maquina do jogo. O CSV completo nao e substituido. --allow-fail so permite FPS abaixo da meta; NAO permite coleta invalida. Duracao de 10 s e considerada diagnostico, nao teste oficial.

Para medir, deixe a janela Godot em primeiro plano sem alt-tab, overlay agressivo ou outro teste concorrente. Repita tres vezes, observando temperaturas e clocks. O script nao força artificialmente o foco.

Testes unitarios da integridade:
    python -m unittest discover -s tests/benchmark -p test_runner.py -v

### Protecao contra processos concorrentes

Antes de abrir o Godot, o runner consulta a lista de processos do computador (tasklist no Windows; ps em Linux). Se houver **qualquer outro Godot** executando, interrompe antes do teste com codigo 5. Nenhum processo alheio e encerrado. A lista tambem e conferida ao final: se outro Godot aparecer ate o encerramento, a coleta fica invalida. Feche previamente os editores Godot, servidores de teste e execucoes de benchmark das outras IAs.

Na auditoria de GPU, a quantidade de amostras nao basta: tambem exigimos cobertura perto das duas extremidades da janela e nenhum intervalo entre amostras maior que 4 segundos. A coleta oficial nao inclui o aquecimento.
