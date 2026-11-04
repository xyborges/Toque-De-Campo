$ErrorActionPreference='Stop'
$engine='C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$processes=@()
try {
    Remove-Item -LiteralPath (Join-Path $PWD 'work/br-loot-late-ready.json') -ErrorAction SilentlyContinue
    foreach($role in @('server','alpha','bravo','late')) {
        $log=Join-Path $PWD "work/br-loot-$role.log"
        $arguments=@('--headless','--path',('"'+$PWD+'"'),'--script','res://tests/br_loot_network.gd','--log-file',('"'+$log+'"'),'--','--naval-test-accounts',"--role=$role",('"--naval-data='+$PWD+'/work/br-loot-profile-'+$role+'"'),('"--game-tls-cert='+$PWD+'/work/security182/test.crt"'),('"--game-tls-key='+$PWD+'/work/security182/test.key"'),('"--game-tls-ca='+$PWD+'/work/security182/test.crt"'),'--game-tls-host=localhost')
        $p=Start-Process -FilePath $engine -ArgumentList $arguments -WorkingDirectory $PWD -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $PWD "work/br-loot-$role-stdout.log") -RedirectStandardError (Join-Path $PWD "work/br-loot-$role-stderr.log")
        $processes+=$p
        if($role -eq 'server'){Start-Sleep -Seconds 2}
    }
    $limit=(Get-Date).AddSeconds(120)
    while(@($processes | Where-Object {-not $_.HasExited}).Count -gt 0 -and (Get-Date) -lt $limit){
        if(Select-String -Path 'work/br-loot-*-stderr.log' -Pattern 'SCRIPT ERROR|Parse Error' -Quiet){throw 'Script error in network harness'}
        Start-Sleep -Milliseconds 500
    }
    foreach($p in $processes){if(-not $p.HasExited){throw 'Network test timeout'}}
    foreach($role in @('server','alpha','bravo','late')) {Get-Content -LiteralPath "work/br-loot-$role-stderr.log" -Tail 10}
    Get-Content work/br-loot-network.json
    if(@($processes | Where-Object {$_.ExitCode -ne 0}).Count -gt 0){throw 'Network test failed'}
} finally {
    foreach($p in $processes){if(-not $p.HasExited){Stop-Process -Id $p.Id -Force}}
}
