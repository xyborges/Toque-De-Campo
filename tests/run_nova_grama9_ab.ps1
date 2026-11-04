$ErrorActionPreference = 'Stop'
$godot = 'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$runId = Get-Date -Format 'yyyyMMdd-HHmmss'
$prefix = "nova-grama9-$runId"
$lockPath = Join-Path $PWD 'work/performance-benchmark.lock'
try {
    $exclusive = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
} catch {
    throw 'Outro benchmark está usando o computador; não iniciar medições simultâneas.'
}
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
        $others = @(Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^Godot.*\.exe$' })
        if ($others.Count -gt 0) { throw "Outro processo Godot está ativo; a medição $entry foi cancelada." }
        $extra = @()
        if ($entry.StartsWith('b')) { $extra += '--nova-grama'; $extra += '--biome-trees2' }
        if ($entry -eq 'b3') { $extra += '--captures' }
        $log = "work/$prefix-$entry.log"
        & $godot --path . --rendering-method gl_compatibility --resolution 1920x1080 --screen 0 --script res://tests/nova_grama_benchmark.gd -- "--label=$prefix-$entry" --seconds=25 --exact-resolution @extra *> $log
        if ($LASTEXITCODE -ne 0) { throw "Benchmark $entry failed ($LASTEXITCODE); see $log" }
        $errors = Select-String -Path $log -Pattern 'SCRIPT ERROR|ERROR:'
        if ($errors) { throw "Benchmark $entry produced errors; see $log" }
        Write-Output (Select-String -Path $log -Pattern 'BENCH_RESULT|NOVA_COUNTS|CAPTURE' | ForEach-Object { $_.Line })
    }
} finally {
    if ($monitor) { Stop-Job $monitor; Remove-Job $monitor }
    if ($exclusive) { $exclusive.Dispose() }
}
