$ErrorActionPreference='Stop'
$repo=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$godot='C:\Users\Microgate\Documents\Codex\2026-11-06\fa-a\work\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$pattern=@(0,1,1,0,0,1,1,0,0,1)
$rows=@()
$expectedGeometry=$null
$expectedProbes=$null
$failures=0
foreach($i in 0..9){
    if(@(Get-Process -Name 'Godot*' -ErrorAction SilentlyContinue).Count -gt 0){throw 'Concurrent Godot: invalid test'}
    $variant=$pattern[$i]
    $env:TDC_IA2_DEFER_SECTOR_ATTACH='0'
    $env:TDC_IA2_HEADLESS_SKIP_VISUAL_HILLSIDE=[string]$variant
    $env:TDC_IA2_MAP_STAGES='1'
    $name='foliage-{0:D2}-{1}' -f ($i+1),$variant
    $log=Join-Path $PSScriptRoot ($name+'.log')
    $utc=([DateTime]::UtcNow).ToString('o')
    & $godot --headless --path $repo --script res://tests/ia2_map_collider_attach_qa.gd -- "--run=$($i+1)" *> $log
    if($LASTEXITCODE -ne 0){throw "Functional fixture error $name"}
    $line=Get-Content $log|Where-Object{$_.StartsWith('IA2_MAP_COLLIDERS ')}|Select-Object -Last 1
    if(!$line){throw "Missing JSON metric $name"}
    $raw=$line.Substring('IA2_MAP_COLLIDERS '.Length)
    $j=$raw|ConvertFrom-Json
    if(@($j.errors).Count -ne 0 -or $j.shapes -ne 11624 -or $j.sectors -ne 254 -or $j.hill_colliders -ne 78 -or $j.hill_trees -ne 1850 -or $j.probes_hit -ne 20 -or $j.tiles -ne 225 -or $j.houses -ne 4313){throw "Physics geometry error $name"}
    if($variant -eq 0 -and ($j.hill_grass -ne 13334 -or $j.hill_shrubs -ne 4700 -or $j.hill_rocks -ne 480 -or $j.hill_visual_plan_skipped)){throw "Baseline scenic counts bad $name"}
    if($variant -eq 1 -and ($j.hill_grass -ne 0 -or $j.hill_shrubs -ne 0 -or $j.hill_rocks -ne 0 -or !$j.hill_visual_plan_skipped)){throw "Server still computes decorations $name"}
    if(!$expectedGeometry){$expectedGeometry=$j.geometry_sha256;$expectedProbes=$j.probe_sha256}
    if($j.geometry_sha256 -ne $expectedGeometry -or $j.probe_sha256 -ne $expectedProbes){$failures++;Write-Output ("INTEGRITY_MISMATCH "+$name)}
    [System.IO.File]::WriteAllText((Join-Path $PSScriptRoot ($name+'.json')),$raw,(New-Object System.Text.UTF8Encoding($false)))
    $row=[pscustomobject]@{run=$i+1;variant=$variant;utc=$utc;
        ready_ms=$j.ready_ms;world_build_ms=$j.world_build_ms;map_build_ms=$j.map_build_ms;
        hillside_ms=$j.stages_ms.hillside;neighborhoods_ms=$j.stages_ms.neighborhoods;
        terrain_ms=$j.stages_ms.terrain_225_tiles;layout_reservations_ms=$j.stages_ms.layout_reservations;
        collision_shapes=$j.shapes;sectors=$j.sectors;hill_trees=$j.hill_trees;hill_colliders=$j.hill_colliders;
        hill_shrubs=$j.hill_shrubs;hill_grass=$j.hill_grass;hill_rocks=$j.hill_rocks;
        geometry_sha256=$j.geometry_sha256;probe_sha256=$j.probe_sha256}
    $rows+=$row
    $rows|Export-Csv (Join-Path $PSScriptRoot 'foliage-5pairs.csv') -Encoding UTF8 -NoTypeInformation
    Write-Output ('IA2_FOLIAGE_PAIR '+($row|ConvertTo-Json -Compress))
}
Write-Output ('TEN_FOLIAGE_RUNS_COMPLETE geometry_mismatches='+$failures)
if($failures -ne 0){throw "Geometry mismatches in $failures runs"}
