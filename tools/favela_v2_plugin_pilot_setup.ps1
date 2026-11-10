# Isolated A/B add-on setup. Vends NO upstream binary into the game's Git.
# Only official Terrain3D release and upstream ProtonScatter source are used.
param([switch]$SkipDownloads)
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $project
New-Item -ItemType Directory -Force 'work\v2-third-party-pilot' | Out-Null
# Godot must NOT scan the unzipped add-on twice under work/.
if(-not(Test-Path 'work\.gdignore')){New-Item -ItemType File 'work\.gdignore' | Out-Null}
$cache = Join-Path $project 'work\v2-third-party-pilot'
$archive = Join-Path $cache 'Terrain3D_v1.1.0-stable.zip'
$release = 'https://github.com/TokisanGames/Terrain3D/releases/download/v1.1.0-stable/Terrain3D_v1.1.0-stable.zip'
if(-not (Test-Path $archive) -and -not $SkipDownloads) {
    & curl.exe -fL --retry 2 --connect-timeout 18 -o $archive $release
    if($LASTEXITCODE -ne 0){throw 'Cannot download Terrain3D upstream release'}
}
$expectedTerrainHash = '51B78BC758F5759CBC8EAAAB14E5CF4E8661717E265FDD760F5ABF945F15B243'
if((Get-FileHash $archive -Algorithm SHA256).Hash -ne $expectedTerrainHash){throw 'Terrain3D zip hash changed; stop to verify upstream'}
if(-not (Test-Path 'addons\terrain_3d')){
    $extracted = Join-Path $cache 'terrain_unpacked'
    if(-not(Test-Path $extracted)){Expand-Archive -LiteralPath $archive -DestinationPath $extracted -Force}
    $plugin = Get-ChildItem $extracted -Directory -Recurse |
        Where-Object {$_.Name -eq 'terrain_3d' -and (Test-Path (Join-Path $_.FullName 'plugin.cfg'))} |
        Select-Object -First 1
    if(-not $plugin){throw 'Terrain3D plugin directory not found in official release zip'}
    Copy-Item $plugin.FullName -Destination 'addons\terrain_3d' -Recurse -Force
}
if(-not(Test-Path 'addons\proton_scatter')){
    $source=Join-Path $cache 'proton_scatter_upstream'
    if(-not(Test-Path $source)){
        if($SkipDownloads){throw 'Missing ProtonScatter source'}
        & git clone --depth 1 --single-branch https://github.com/HungryProton/scatter.git $source
        if($LASTEXITCODE -ne 0){throw 'Cannot clone ProtonScatter upstream'}
    }
    $fixedCommit = '7198cc00078ebde61307578137c3f35223c6e438'
    if((& git -C $source rev-parse HEAD).Trim() -ne $fixedCommit){
        & git -C $source fetch --depth 1 origin $fixedCommit
        if($LASTEXITCODE -ne 0){throw 'Pinned ProtonScatter revision unavailable'}
        & git -C $source checkout --detach $fixedCommit
        if($LASTEXITCODE -ne 0){throw 'Could not select pinned ProtonScatter revision'}
    }
    Copy-Item (Join-Path $source 'addons\proton_scatter') -Destination 'addons\proton_scatter' -Recurse -Force
}
# Addons are intentionally local, not tracked or shipped in the game.
$exclude = (& git rev-parse --git-path info/exclude).Trim()
$additions = @('/addons/terrain_3d/','/addons/proton_scatter/')
foreach($item in $additions){
    if(-not((Get-Content $exclude -ErrorAction SilentlyContinue) -contains $item)){
        Add-Content -Path $exclude -Value $item
    }
}
$hash= (Get-FileHash $archive -Algorithm SHA256).Hash
$scatterSource=Join-Path $cache 'proton_scatter_upstream'
$sha=(& git -C $scatterSource rev-parse HEAD).Trim()
Write-Output ('TERRAIN_ZIP_SHA256='+$hash)
Write-Output ('PROTON_COMMIT='+$sha)
Write-Output ('TERRAIN_ADDON_EXISTS='+(Test-Path 'addons\terrain_3d\plugin.cfg'))
Write-Output ('SCATTER_ADDON_EXISTS='+(Test-Path 'addons\proton_scatter\plugin.cfg'))
Write-Output 'Installed local add-ons for research. Neither is added to production main.'
