$ErrorActionPreference = 'Stop'
$godot = 'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$monitorPath = Join-Path $PWD 'work/nova-grama-hardware.jsonl'
$monitorScript = Join-Path $PWD 'tests/perf200_cpu_monitor.ps1'
$monitor = Start-Job -ScriptBlock { param($scriptPath, $outputPath) & $scriptPath -Path $outputPath } -ArgumentList $monitorScript, $monitorPath
try {
    $deadline = [DateTime]::UtcNow.AddSeconds(20)
    while (-not (Test-Path -LiteralPath $monitorPath) -and [DateTime]::UtcNow -lt $deadline -and $monitor.State -eq 'Running') { Start-Sleep -Milliseconds 500 }
    if (-not (Test-Path -LiteralPath $monitorPath)) { throw 'Hardware monitoring could not start' }
    foreach ($entry in @('a1','b1','a2','b2','a3','b3','a4')) {
        $extra = @()
        if ($entry.StartsWith('b')) { $extra += '--nova-grama' }
        if ($entry -eq 'b3') { $extra += '--captures' }
        $log = "work/nova-grama-$entry.log"
        & $godot --path . --rendering-method gl_compatibility --resolution 1920x1080 --screen 0 --script res://tests/nova_grama_benchmark.gd -- "--label=nova-grama-$entry" --seconds=20 --exact-resolution @extra *> $log
        if ($LASTEXITCODE -ne 0) { throw "Benchmark $entry failed ($LASTEXITCODE); see $log" }
        Write-Output (Select-String -Path $log -Pattern 'BENCH_RESULT|NOVA_COUNTS|CAPTURE|ERROR|SCRIPT ERROR' | ForEach-Object { $_.Line })
    }
} finally {
    if ($monitor) { Stop-Job $monitor; Remove-Job $monitor }
}
