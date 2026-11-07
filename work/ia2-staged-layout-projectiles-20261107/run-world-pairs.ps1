$ErrorActionPreference='Stop'
$repo=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$godot='C:\Users\Microgate\Documents\Codex\2026-11-06\fa-a\work\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$pattern=@(0,1,1,0,0,1,1,0,0,1)
$rows=@()
foreach($i in 0..9){
    if(@(Get-Process -Name 'Godot*' -ErrorAction SilentlyContinue).Count -gt 0){throw 'Godot concorrente'}
    $variant=$pattern[$i]
    $name='world-{0:D2}-{1}' -f ($i+1),$variant
    $log=Join-Path $PSScriptRoot ($name+'.log')
    $env:TDC_IA2_STAGED_FAVELA_LAYOUT='0'
    & $godot --headless --path $repo --script res://tests/ia2_staged_world_qa.gd -- "--staged=$variant" "--run=$($i+1)" *> $log
    if($LASTEXITCODE -ne 0){throw "World QA failed $name"}
    $line=Get-Content $log|Where-Object{$_.StartsWith('IA2_STAGED_WORLD_QA ')}|Select-Object -Last 1
    if(!$line){throw "missing report $name"}
    $raw=$line.Substring('IA2_STAGED_WORLD_QA '.Length)
    $j=$raw|ConvertFrom-Json
    if(@($j.problems).Count -gt 0 -or $j.geometry.collision_shapes -ne 11624 -or $j.geometry.terrain_tiles -ne 225){throw "world integrity failed $name"}
    [System.IO.File]::WriteAllText((Join-Path $PSScriptRoot ($name+'.json')),$raw,(New-Object System.Text.UTF8Encoding($false)))
    $row=[pscustomobject]@{run=$i+1;variant=$variant;total_ready_ms=$j.total_to_join_ready_ms;
        world_build_ms=$j.world_build_ms;preparation_ms=$j.preparation_elapsed_ms;
        preparation_max_slice_ms=$j.preparation.max_slice_ms;
        collisions=$j.geometry.collision_shapes;tiles=$j.geometry.terrain_tiles;
        lots=$j.geometry.houses;digest=$j.hash}
    $rows+=$row
    $rows|Export-Csv (Join-Path $PSScriptRoot 'world-5pairs.csv') -Encoding UTF8 -NoTypeInformation
    Write-Output ('IA2_WORLD_PAIR '+($row|ConvertTo-Json -Compress))
}
Write-Output 'ALL_TEN_WORLD_RUNS_VALID'
