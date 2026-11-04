param(
    [string]$ProjectRoot = 'C:/Users/Joao Borges/Documents/Codex/2026-10-16/quer/outputs/campo-cartunesco-godot',
    [string]$Engine = 'C:/Users/Joao Borges/Documents/Codex/tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
)
$ErrorActionPreference = 'Stop'
$baselineRoot = Join-Path $ProjectRoot 'work/baseline191-src'
$fixture = Join-Path $ProjectRoot 'tests/cpu191_vehicle_world.gd'
$baselineFixture = Join-Path $baselineRoot 'tests/cpu191_vehicle_world.gd'
Copy-Item -LiteralPath $fixture -Destination $baselineFixture
foreach ($variant in @('baseline', 'current')) {
    $runRoot = if ($variant -eq 'baseline') { $baselineRoot } else { $ProjectRoot }
    foreach ($scenario in @('benchmark', 'basecorner')) {
        $report = Join-Path $ProjectRoot "work/perf181/cpu191-vehicle-world-$variant-$scenario.json"
        $log = Join-Path $ProjectRoot "work/perf181/cpu191-vehicle-world-$variant-$scenario.stdout.log"
        $profile = Join-Path $ProjectRoot "work/perf181/cpu191-vehicle-world-profile-$variant-$scenario"
        & $Engine --headless --max-fps 60 --path $runRoot --script res://tests/cpu191_vehicle_world.gd -- "--world-label=$variant" "--world-scenario=$scenario" "--world-report=$report" "--naval-data=$profile" *> $log
        if ($LASTEXITCODE -ne 0) { throw "Vehicle world fixture failed: $variant / $scenario; see $log" }
        $result = Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
        Write-Output ($result | Select-Object label,scenario,four_simulate_wall,four_align_inclusive_wall | ConvertTo-Json -Depth 4 -Compress)
    }
}
