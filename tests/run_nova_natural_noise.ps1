$ErrorActionPreference = 'Stop'
$godot = 'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$prefix = 'nova-natural-aa-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
$lockPath = Join-Path $PWD 'work/performance-benchmark.lock'
try { $exclusive = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None) }
catch { throw 'Outro benchmark está ativo.' }
$monitor = $null
try {
    $monitorPath = Join-Path $PWD "work/$prefix-hardware.jsonl"
    $monitorScript = Join-Path $PWD 'tests/nova_route_monitor.ps1'
    $monitor = Start-Job -ScriptBlock { param($scriptPath,$outputPath,$runnerPid) & $scriptPath -Path $outputPath -RunnerPid $runnerPid } -ArgumentList $monitorScript,$monitorPath,$PID
    $deadline=[DateTime]::UtcNow.AddSeconds(20)
    while (-not (Test-Path -LiteralPath $monitorPath) -and [DateTime]::UtcNow -lt $deadline -and $monitor.State -eq 'Running') { Start-Sleep -Milliseconds 500 }
    if (-not (Test-Path -LiteralPath $monitorPath)) { throw 'Monitor de hardware indisponível.' }
    (powercfg /getactivescheme) | Set-Content -LiteralPath "work/$prefix-power.txt" -Encoding UTF8
    Write-Output "BENCH_RUN $prefix"
    foreach ($entry in @('a1','b1','a2','b2','a3','b3','a4','b4','a5','b5','a6','b6','a7','b7','a8')) {
        if (@(Get-Process -Name 'Godot*','Toque*' -ErrorAction SilentlyContinue).Count -gt 0) { throw "Outro jogo Godot está ativo; $entry cancelado." }
        $label="$prefix-$entry"
        $log="work/$label.log"
        $engineLog=Join-Path $PWD "work/$label-engine.log"
        $testData=Join-Path $PWD 'work/benchmark-profile'
        # A and B are identical: this block measures natural variation.
        & $godot --path . --log-file $engineLog --rendering-method gl_compatibility --resolution 1920x1080 --screen 0 --script res://tests/nova_route_natural_benchmark.gd -- "--label=$label" "--naval-data=$testData" --seconds=120 --camera-route --exact-resolution *> $log
        if ($LASTEXITCODE -ne 0 -or (Select-String -Path $log -Pattern 'SCRIPT ERROR|ERROR:')) { throw "Falha em $entry; veja $log." }
        $resultPath="work/$label-offline.json"
        if (-not (Test-Path -LiteralPath $resultPath)) { throw "Relatório ausente em $entry." }
        $data=Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
        if ($data.actors -ne 18 -or -not $data.natural_render_loop -or -not $data.camera_route -or $data.sample_ms -lt 110000 -or $data.resolution -ne '(1920.0, 1080.0)') { throw "Cenário incompleto em $entry." }
        Write-Output ("{0} FPS-mediano={1:N1} p99={2:N1}ms >33/min={3:N1} pior={4:N1}ms" -f $entry,$data.median_fps,$data.frame_p99_ms,$data.over33_frames_per_minute,$data.worst_ms)
    }
    python tools/summarize_nova_route.py $prefix
    if ($LASTEXITCODE -ne 0) { throw 'Não foi possível resumir os resultados.' }
} finally {
    if ($monitor) { Stop-Job $monitor; Remove-Job $monitor }
    if ($exclusive) { $exclusive.Dispose() }
}

