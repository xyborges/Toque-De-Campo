param(
    [ValidateSet('aa','ab')][string]$Mode='aa',
    [ValidateSet(60,120)][int]$Seconds=120,
    [ValidateRange(5,7)][int]$Pairs=5,
    [ValidateRange(1,3)][int]$Level=2
)
$ErrorActionPreference='Stop'
$godot='C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$prefix='nova-session-'+$Mode+'-'+(Get-Date -Format 'yyyyMMdd-HHmmss')
try { $exclusive=[System.IO.File]::Open((Join-Path $PWD 'work/performance-benchmark.lock'),[System.IO.FileMode]::OpenOrCreate,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::None) }
catch { throw 'Outro benchmark está ativo.' }
$monitor=$null
try {
    if (@(Get-Process -Name 'Godot*','Toque*' -ErrorAction SilentlyContinue).Count -gt 0) { throw 'Outra instância Godot está ativa.' }
    $monitorPath=Join-Path $PWD "work/$prefix-hardware.jsonl"
    $monitorScript=Join-Path $PWD 'tests/nova_route_monitor.ps1'
    $monitor=Start-Job -ScriptBlock { param($scriptPath,$outputPath,$runnerPid) & $scriptPath -Path $outputPath -RunnerPid $runnerPid } -ArgumentList $monitorScript,$monitorPath,$PID
    $deadline=[DateTime]::UtcNow.AddSeconds(20)
    while (-not (Test-Path -LiteralPath $monitorPath) -and [DateTime]::UtcNow -lt $deadline -and $monitor.State -eq 'Running') { Start-Sleep -Milliseconds 500 }
    if (-not (Test-Path -LiteralPath $monitorPath)) { throw 'Monitor de hardware indisponível.' }
    (powercfg /getactivescheme) | Set-Content -LiteralPath "work/$prefix-power.txt" -Encoding UTF8
    $engineLog=Join-Path $PWD "work/$prefix-engine.log"
    $log=Join-Path $PWD "work/$prefix.stdout.log"
    # Fresh test storage: no preferences from a real account or older series.
    $data=Join-Path $PWD "work/$prefix-profile"
    Write-Output "SESSION_RUN $prefix"
    & $godot --path . --log-file $engineLog --rendering-method gl_compatibility --resolution 1920x1080 --screen 0 --script res://tests/nova_session_benchmark.gd -- "--label=$prefix" "--naval-data=$data" "--seconds=$Seconds" "--pairs=$Pairs" "--bench-mode=$Mode" "--vegetation-level=$Level" *> $log
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|ERROR:')) { throw "Sessão falhou; consulte $log." }
    if (-not (Test-Path -LiteralPath "work/$prefix.json")) { throw 'Sessão encerrou sem relatório final; série incompleta.' }
    python tools/summarize_nova_session.py $prefix
    if ($LASTEXITCODE -ne 0) { throw 'Resumo indisponível ou cenário incompleto.' }
} finally {
    if ($monitor) { Stop-Job $monitor; Remove-Job $monitor }
    if ($exclusive) { $exclusive.Dispose() }
}
