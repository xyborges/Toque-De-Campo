# Wrapper para Windows; o runner Python e a fonte unica de logica.
$ErrorActionPreference = 'Stop'
$runner = Join-Path $PSScriptRoot 'run_benchmark.py'
& python $runner @args
exit $LASTEXITCODE
