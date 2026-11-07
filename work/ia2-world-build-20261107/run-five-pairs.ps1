$ErrorActionPreference='Stop'
$repo=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$godot='C:\Users\Microgate\Documents\Codex\2026-11-06\fa-a\work\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$pattern=@(0,1,1,0,0,1,1,0,0,1)
$rows=@()
$invalid=0
$expectedGeometry=$null
$expectedProbes=$null
foreach($i in 0..9){
    if(@(Get-Process -Name 'Godot*' -ErrorAction SilentlyContinue).Count -gt 0){throw 'Godot concorrente: invalida a coleta'}
    $variant=$pattern[$i]
    $env:TDC_IA2_DEFER_SECTOR_ATTACH=[string]$variant
    $env:TDC_IA2_MAP_STAGES='1'
    $name='colliders-{0:D2}-{1}' -f ($i+1),$variant
    $log=Join-Path $PSScriptRoot ($name+'.log')
    $when=([DateTime]::UtcNow).ToString('o')
    & $godot --headless --path $repo --script res://tests/ia2_map_collider_attach_qa.gd -- "--run=$($i+1)" *> $log
    if($LASTEXITCODE -ne 0){throw "QA failed $name"}
    $line=Get-Content $log|Where-Object{$_.StartsWith('IA2_MAP_COLLIDERS ')}|Select-Object -Last 1
    if(!$line){throw "Report missing $name"}
    $raw=$line.Substring('IA2_MAP_COLLIDERS '.Length)
    $j=$raw|ConvertFrom-Json
    if(@($j.errors).Count -ne 0 -or $j.shapes -ne 11624 -or $j.sectors -ne 254 -or $j.tiles -ne 225 -or $j.houses -ne 4313 -or $j.probes_hit -ne 20){throw "Geometry missing or wrong: $name"}
    if(!$expectedGeometry){$expectedGeometry=$j.geometry_sha256;$expectedProbes=$j.probe_sha256}
    if($j.geometry_sha256 -ne $expectedGeometry -or $j.probe_sha256 -ne $expectedProbes){$invalid+=1;Write-Output ("INTEGRITY_MISMATCH "+$name+" "+$j.geometry_sha256+" "+$j.probe_sha256)}
    [System.IO.File]::WriteAllText((Join-Path $PSScriptRoot ($name+'.json')),$raw,(New-Object System.Text.UTF8Encoding($false)))
    $row=[pscustomobject]@{run=$i+1;variant=$variant;utc=$when;
        ready_ms=$j.ready_ms;world_build_ms=$j.world_build_ms;map_build_ms=$j.map_build_ms;
        neighborhoods_ms=$j.stages_ms.neighborhoods;hillside_ms=$j.stages_ms.hillside;
        layout_reservations_ms=$j.stages_ms.layout_reservations;
        terrain_ms=$j.stages_ms.terrain_225_tiles;flush_ms=$j.stages_ms.geometry_flush;
        colliders=$j.shapes;sectors=$j.sectors;probes_hit=$j.probes_hit;
        geometry_sha256=$j.geometry_sha256;sorted_geometry_sha256=$j.sorted_geometry_sha256;unlabelled_sha256=$j.unlabelled_sha256;probe_sha256=$j.probe_sha256}
    $rows+=$row
    $rows|Export-Csv (Join-Path $PSScriptRoot 'colliders-5pairs.csv') -Encoding UTF8 -NoTypeInformation
    Write-Output ('IA2_COLLIDERS_PAIR '+($row|ConvertTo-Json -Compress))
}
Write-Output ('ALL_TEN_COLLIDERS_RUNS_VALID violations='+$invalid)
if($invalid -ne 0){throw ('Integrity mismatches in '+$invalid+' runs')}
