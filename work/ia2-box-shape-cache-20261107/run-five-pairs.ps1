$ErrorActionPreference='Stop'
$repo=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$godot='C:\Users\Microgate\Documents\Codex\2026-11-06\fa-a\work\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$pattern=@(0,1,1,0,0,1,1,0,0,1)
$rows=@()
$referenceGeometry=''
$referenceRay=''
foreach($i in 0..9){
  if(@(Get-Process -Name 'Godot*' -ErrorAction SilentlyContinue).Count -gt 0){throw 'Godot concorrente'}
  $v=$pattern[$i]
  $env:TDC_IA2_BOX_PROFILE='1'
  $env:TDC_IA2_BOX_SHAPE_CACHE=[string]$v
  $env:TDC_IA2_HEADLESS_SKIP_VISUAL_HILLSIDE='0'
  $env:TDC_IA2_STAGED_FAVELA_LAYOUT='0'
  $name='boxes-{0:D2}-{1}' -f ($i+1),$v
  $log=Join-Path $PSScriptRoot ($name+'.log')
  & $godot --headless --path $repo --script res://tests/ia2_box_shape_cache_qa.gd -- "--run=$($i+1)" *> $log
  if($LASTEXITCODE -ne 0){throw "Godot failure $name"}
  $line=Get-Content -LiteralPath $log | Where-Object {$_.StartsWith('IA2_BOX_CACHE_BENCH ')} | Select-Object -Last 1
  if(!$line){throw "No metrics $name"}
  $raw=$line.Substring('IA2_BOX_CACHE_BENCH '.Length)
  $j=$raw|ConvertFrom-Json
  if(@($j.errors).Count -gt 0 -or [int]$j.box_count -ne 11243 -or [int]$j.collision_shapes -ne 11146){throw "Fixture regression $name"}
  if(!$referenceGeometry){$referenceGeometry=$j.geometry_sha256;$referenceRay=$j.ray_sha256}
  if($j.geometry_sha256 -ne $referenceGeometry -or $j.ray_sha256 -ne $referenceRay){throw "Physics mismatch $name"}
  if(([bool]$j.cache_enabled) -ne ([bool]$v)){throw "Invalid flag $name"}
  [System.IO.File]::WriteAllText((Join-Path $PSScriptRoot ($name+'.json')),$raw,(New-Object System.Text.UTF8Encoding($false)))
  $row=[pscustomobject]@{run=$i+1;variant=$v;world_ms=$j.world_ms;ready_ms=$j.ready_ms;
      create_ms=$j.profile.shape_lookup_and_creation_ms;attach_ms=$j.profile.collider_attach_ms;
      cache_hits=$j.profile.cache_hits;cache_misses=$j.profile.cache_misses;
      box_count=$j.box_count;unique_resources=$j.unique_box_shape_resources;
      geometry_sha256=$j.geometry_sha256;ray_sha256=$j.ray_sha256}
  $rows+=$row
  $rows|Export-Csv (Join-Path $PSScriptRoot 'boxes-5pairs.csv') -Encoding UTF8 -NoTypeInformation
  Write-Output ('IA2_BOX_PAIR '+($row|ConvertTo-Json -Compress))
}
Write-Output 'IA2_BOX_FIVE_PAIRS_COMPLETE'
