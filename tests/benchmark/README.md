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
