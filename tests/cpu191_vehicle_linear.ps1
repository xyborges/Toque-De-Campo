param(
    [string]$ProjectRoot = 'C:/Users/Joao Borges/Documents/Codex/2026-10-16/quer/outputs/campo-cartunesco-godot',
    [string]$Engine = 'C:/Users/Joao Borges/Documents/Codex/tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
)
$ErrorActionPreference = 'Stop'
$baselineRoot = Join-Path $ProjectRoot 'work/baseline191-src'
foreach ($name in @('cpu191_vehicle_world.gd', 'cpu191_vehicle_linear.gd')) {
    Copy-Item -LiteralPath (Join-Path $ProjectRoot "tests/$name") -Destination (Join-Path $baselineRoot "tests/$name")
}
foreach ($variant in @('baseline', 'current')) {
    $runRoot = if ($variant -eq 'baseline') { $baselineRoot } else { $ProjectRoot }
    $report = Join-Path $ProjectRoot "work/perf181/cpu191-vehicle-linear-$variant.json"
    $log = Join-Path $ProjectRoot "work/perf181/cpu191-vehicle-linear-$variant.stdout.log"
    $profile = Join-Path $ProjectRoot "work/perf181/cpu191-vehicle-linear-profile-$variant"
    & $Engine --headless --max-fps 60 --path $runRoot --script res://tests/cpu191_vehicle_linear.gd -- "--world-label=$variant" --world-scenario=linear "--world-report=$report" "--naval-data=$profile" *> $log
    if ($LASTEXITCODE -ne 0) { throw "Linear vehicle world fixture failed: $variant; see $log" }
    $result = Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    Write-Output ($result | Select-Object label,scenario,four_simulate_wall,four_align_inclusive_wall | ConvertTo-Json -Depth 4 -Compress)
}
