$ErrorActionPreference = 'Stop'
$godot = 'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$prefix = 'nova-details-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
$lockPath = Join-Path $PWD 'work/performance-benchmark.lock'
try { $exclusive = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None) }
catch { throw 'Outro benchmark está ativo; não iniciar medições simultâneas.' }
$monitor = $null
try {
    $monitorPath = Join-Path $PWD "work/$prefix-hardware.jsonl"
    $monitorScript = Join-Path $PWD 'tests/perf200_cpu_monitor.ps1'
    $monitor = Start-Job -ScriptBlock { param($scriptPath, $outputPath) & $scriptPath -Path $outputPath } -ArgumentList $monitorScript, $monitorPath
    $deadline = [DateTime]::UtcNow.AddSeconds(20)
    while (-not (Test-Path -LiteralPath $monitorPath) -and [DateTime]::UtcNow -lt $deadline -and $monitor.State -eq 'Running') { Start-Sleep -Milliseconds 500 }
    if (-not (Test-Path -LiteralPath $monitorPath)) { throw 'Hardware monitoring could not start' }
    Write-Output "BENCH_RUN $prefix"
    foreach ($entry in @('a1','b1','a2','b2','a3','b3','a4')) {
        if (@(Get-Process -Name 'Godot*' -ErrorAction SilentlyContinue).Count -gt 0) { throw "Outro processo Godot está ativo; medição $entry cancelada." }
        $extra = @()
        if ($entry.StartsWith('b')) { $extra += '--nova-grama'; $extra += '--nova-details-only' }
        $label = "$prefix-$entry"
        $log = "work/$label.log"
        $testData = Join-Path $PWD 'work/benchmark-profile'
        $engineLog = Join-Path $PWD "work/$label-engine.log"
        & $godot --path . --log-file $engineLog --rendering-method gl_compatibility --resolution 1920x1080 --screen 0 --script res://tests/nova_grama_benchmark.gd -- "--label=$label" "--naval-data=$testData" --seconds=25 --exact-resolution @extra *> $log
        if ($LASTEXITCODE -ne 0) { throw "Benchmark $entry failed ($LASTEXITCODE); see $log" }
        if (Select-String -Path $log -Pattern 'SCRIPT ERROR|ERROR:') { throw "Benchmark $entry produced errors; see $log" }
        if (-not (Test-Path -LiteralPath "work/$label-offline.json")) { throw "Benchmark $entry terminou sem resultado; veja $log" }
        $data = Get-Content -LiteralPath "work/$label-offline.json" -Raw | ConvertFrom-Json
        if ($data.actors -ne 18) { throw "Benchmark $entry não teve 18 participantes" }
        if ($entry.StartsWith('b') -and (-not $data.nova_details_only -or $data.nova_counts.terrain_sectors -lt 1 -or $data.nova_counts.cells -lt 1)) { throw "Detalhes isolados não foi aplicado corretamente em $entry" }
        Write-Output (Select-String -Path $log -Pattern 'BENCH_RESULT|NOVA_COUNTS' | ForEach-Object { $_.Line })
    }
} finally {
    if ($monitor) { Stop-Job $monitor; Remove-Job $monitor }
    if ($exclusive) { $exclusive.Dispose() }
}

