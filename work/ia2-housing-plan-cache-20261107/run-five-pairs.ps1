$ErrorActionPreference='Stop'
$repo=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$godot='C:\Users\Microgate\Documents\Codex\2026-11-06\fa-a\work\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$pattern=@(0,1,1,0,0,1,1,0,0,1)
$rows=@()
$expectedPlan=$null
$expectedGeometry=$null
$expectedRay=$null
foreach($i in 0..9){
  if(@(Get-Process -Name Godot* -ErrorAction SilentlyContinue).Count -gt 0){throw 'Godot concorrente detectado'}
  $variant=$pattern[$i]
  $env:TDC_IA2_HOUSING_CACHE=[string]$variant
  $env:TDC_IA2_STAGED_FAVELA_LAYOUT='0'
  $env:TDC_IA2_HEADLESS_SKIP_VISUAL_HILLSIDE='0'
  $env:TDC_IA2_BOX_SHAPE_CACHE='0'
  $name='housing-{0:D2}-{1}' -f ($i+1),$variant
  $log=Join-Path $PSScriptRoot ($name+'.log')
  & $godot --headless --path $repo --script res://tests/ia2_housing_plan_cache_qa.gd -- "--run=$($i+1)" *> $log
  if($LASTEXITCODE -ne 0){throw "Godot QA failed: $name"}
  $line=Get-Content $log|Where-Object{$_.StartsWith('IA2_HOUSING_PLAN_BENCH ')}|Select-Object -Last 1
  if(!$line){throw "Missing metrics $name"}
  $raw=$line.Substring('IA2_HOUSING_PLAN_BENCH '.Length)
  $j=$raw|ConvertFrom-Json
  if(@($j.errors).Count -gt 0 -or $j.lots -ne 4188 -or $j.collisions -ne 11146){throw "Unexpected gameplay scene: $name"}
  if(!$expectedPlan){$expectedPlan=$j.plan_sha256;$expectedGeometry=$j.geometry_sha256;$expectedRay=$j.ray_sha256}
  if($j.plan_sha256 -ne $expectedPlan -or $j.geometry_sha256 -ne $expectedGeometry -or $j.ray_sha256 -ne $expectedRay){throw "HASH MISMATCH $name"}
  if(([bool]$j.cache_enabled) -ne ([bool]$variant)){throw "Flag mismatch $name"}
  if($variant -eq 1 -and $j.layout_status -ne 'loaded'){throw "Cache not used $name"}
  if($variant -eq 0 -and $j.layout_status -ne 'generated'){throw "Invalid baseline $name"}
  [System.IO.File]::WriteAllText((Join-Path $PSScriptRoot ($name+'.json')),$raw,(New-Object System.Text.UTF8Encoding($false)))
  $row=[pscustomobject]@{
      run=$i+1;variant=$variant;layout_ms=$j.layout_ms;world_ms=$j.world_ms;ready_ms=$j.ready_ms;
      lots=$j.lots;houses=$j.houses;collision_shapes=$j.collisions;
      plan_sha256=$j.plan_sha256;geometry_sha256=$j.geometry_sha256;ray_sha256=$j.ray_sha256
  }
  $rows+=$row
  $rows|Export-Csv (Join-Path $PSScriptRoot 'housing-5pairs.csv') -Encoding UTF8 -NoTypeInformation
  Write-Output ('IA2_HOUSING_PAIR '+($row|ConvertTo-Json -Compress))
}
Write-Output 'IA2_HOUSING_FIVE_PAIRS_COMPLETE'
