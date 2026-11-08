# Execute on the checked-out revision. No build or deploy is performed.
# powershell -NoProfile -ExecutionPolicy Bypass -File .\work\entrada-mapas\regenerar_recursos.ps1 -GodotExe "C:\<Godot-4.7.2>\Godot_v4.7.2-stable_win64_console.exe"
param(
    [string]$GodotExe="",
    [string]$ProjectRoot=""
)
$ErrorActionPreference='Stop'
if(!$ProjectRoot){$ProjectRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent}
if(!$GodotExe){
    $candidates=@(
        $env:GODOT_472,
        'C:\Users\Microgate\Documents\Codex\2026-11-06\fa-a\work\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
    ) | Where-Object {$_ -and (Test-Path -LiteralPath $_)}
    if($candidates.Count -gt 0){$GodotExe=$candidates[0]}
}
if(!(Test-Path -LiteralPath $GodotExe)){throw "Indique -GodotExe para Godot 4.7.2 (console)."}
if(!(Test-Path -LiteralPath (Join-Path $ProjectRoot 'project.godot'))){throw "Projeto Godot ausente."}
$version=(& $GodotExe --version |Select-Object -First 1)
if($LASTEXITCODE -ne 0 -or $version -notmatch '^4\.7\.2'){throw "Godot incompatível: $version"}
if(@(Get-CimInstance Win32_Process|Where-Object {$_.Name -match 'Godot'}).Count -gt 0){throw "Feche outros processos Godot antes de regenerar."}
$env:TDC_IA2_HOUSING_CACHE='0'
$env:TDC_IA2_TERRAIN_FACES='0'
$housing='res://tests/ia2_housing_plan_cache_qa.gd'
$argsHousing=@('--generate')
if(Test-Path (Join-Path $ProjectRoot 'tests/ia2_v25_housing_cache_qa.gd')){
    $housing='res://tests/ia2_v25_housing_cache_qa.gd'
    $argsHousing=@('--mode=generate')
}
& $GodotExe --headless --path $ProjectRoot --script $housing -- @argsHousing
if($LASTEXITCODE -ne 0){throw "Falha na geração do cache de lotes."}
$terrain='tests/ia2_terrain_faces_cache_qa.gd'
if(Test-Path (Join-Path $ProjectRoot $terrain)){
    & $GodotExe --headless --path $ProjectRoot --script res://tests/ia2_terrain_faces_cache_qa.gd
    if($LASTEXITCODE -ne 0){throw "Falha no cache de colisão do terreno."}
}
foreach($file in @('housing_plan_cache.res','terrain_faces_cache.res')){
    $path=Join-Path $ProjectRoot ('maps\prepared\favela\'+$file)
    if(Test-Path $path){
        $item=Get-Item -LiteralPath $path
        $sha=(Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
        Write-Output ('PREPARED_RESOURCE '+([pscustomobject]@{file=$file;bytes=$item.Length;sha256=$sha}|ConvertTo-Json -Compress))
    }
}
Write-Output ('SOURCE_COMMIT '+(git -C $ProjectRoot rev-parse HEAD))
Write-Output 'Conferir inclusao dos .res no PCK e executar QA com dois clientes antes de publicar qualquer build.'
