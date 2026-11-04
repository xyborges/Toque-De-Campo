$ErrorActionPreference='Stop'
$engine='C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$processes=@()
try {
    foreach($role in @('server','victim','looter')) {
        $log=Join-Path $PWD "work/br-corpse-network-$role.log"
        $arguments=@('--headless','--path',('"'+$PWD+'"'),'--script','res://tests/br_corpse_loot_network.gd','--log-file',('"'+$log+'"'),'--','--naval-test-accounts',"--role=$role",('"--naval-data='+$PWD+'/work/br-corpse-net-profile-'+$role+'"'),('"--game-tls-cert='+$PWD+'/work/security182/test.crt"'),('"--game-tls-key='+$PWD+'/work/security182/test.key"'),('"--game-tls-ca='+$PWD+'/work/security182/test.crt"'),'--game-tls-host=localhost')
        $p=Start-Process -FilePath $engine -ArgumentList $arguments -WorkingDirectory $PWD -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $PWD "work/br-corpse-network-$role-stdout.log") -RedirectStandardError (Join-Path $PWD "work/br-corpse-network-$role-stderr.log")
        $processes+=$p
        if($role -eq 'server'){Start-Sleep -Seconds 1}
    }
    $limit=(Get-Date).AddSeconds(100)
    while(@($processes | Where-Object {-not $_.HasExited}).Count -gt 0 -and (Get-Date) -lt $limit){
        if(Select-String -Path 'work/br-corpse-network-*-stderr.log' -Pattern 'SCRIPT ERROR|Parse Error' -Quiet){throw 'Script error in corpse network harness'}
        Start-Sleep -Milliseconds 400
    }
    foreach($p in $processes){if(-not $p.HasExited){throw 'Corpse network test timeout'}}
    Get-Content work/br-corpse-loot-network.json
    foreach($role in @('server','victim','looter')) {Get-Content -LiteralPath "work/br-corpse-network-$role-stderr.log" -Tail 12}
    if(@($processes | Where-Object {$_.ExitCode -ne 0}).Count -gt 0){throw 'Corpse network test failed'}
} finally {
    foreach($p in $processes){if(-not $p.HasExited){Stop-Process -Id $p.Id -Force}}
}
