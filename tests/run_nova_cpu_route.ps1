$ErrorActionPreference='Stop'
$prefix='nova-cpu-route-'+(Get-Date -Format 'yyyyMMdd-HHmmss')
$godot='C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
try { $exclusive=[System.IO.File]::Open((Join-Path $PWD 'work/performance-benchmark.lock'),[System.IO.FileMode]::OpenOrCreate,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::None) }
catch { throw 'Outro benchmark está ativo.' }
$monitor=$null
try {
    if (@(Get-Process -Name 'Godot*','Toque*' -ErrorAction SilentlyContinue).Count -gt 0) { throw 'Outro jogo Godot está ativo.' }
    $monitorPath=Join-Path $PWD "work/$prefix-hardware.jsonl"
    $monitorScript=Join-Path $PWD 'tests/nova_route_monitor.ps1'
    $monitor=Start-Job -ScriptBlock { param($scriptPath,$outputPath,$runnerPid) & $scriptPath -Path $outputPath -RunnerPid $runnerPid } -ArgumentList $monitorScript,$monitorPath,$PID
    $deadline=[DateTime]::UtcNow.AddSeconds(20)
    while (-not (Test-Path -LiteralPath $monitorPath) -and [DateTime]::UtcNow -lt $deadline -and $monitor.State -eq 'Running') { Start-Sleep -Milliseconds 500 }
    if (-not (Test-Path -LiteralPath $monitorPath)) { throw 'Monitor indisponível.' }
    Write-Output "PROFILE_RUN $prefix"
    $log="work/$prefix.log"
    $engineLog=Join-Path $PWD "work/$prefix-engine.log"
    $data=Join-Path $PWD 'work/benchmark-profile'
    & $godot --path . --log-file $engineLog --rendering-method gl_compatibility --resolution 1920x1080 --screen 0 --script res://tests/nova_route_natural_benchmark.gd -- "--label=$prefix" "--naval-data=$data" --seconds=120 --camera-route --exact-resolution --performance-probe --qa-bot-profile *> $log
    if ($LASTEXITCODE -ne 0 -or (Select-String -Path $log -Pattern 'SCRIPT ERROR|ERROR:')) { throw "Perfil falhou; veja $log." }
    python tools/summarize_nova_cpu_probe.py $prefix
    if ($LASTEXITCODE -ne 0) { throw 'Sem perfil válido.' }
} finally {
    if ($monitor) { Stop-Job $monitor; Remove-Job $monitor }
    if ($exclusive) { $exclusive.Dispose() }
}
