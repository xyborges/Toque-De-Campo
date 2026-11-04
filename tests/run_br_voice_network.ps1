$ErrorActionPreference='Stop'
$engine='C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$processes=@()
try {
    foreach($role in @('server','alpha','bravo','charlie','delta')) {
        $log=Join-Path $PWD "work/br-voice-$role.log"
        $arguments=@('--headless','--path',('"'+$PWD+'"'),'--script','res://tests/br_voice_network.gd','--log-file',('"'+$log+'"'),'--','--naval-test-accounts',"--role=$role",('"--naval-data='+$PWD+'/work/br-voice-profile-'+$role+'"'),('"--game-tls-cert='+$PWD+'/work/security182/test.crt"'),('"--game-tls-key='+$PWD+'/work/security182/test.key"'),('"--game-tls-ca='+$PWD+'/work/security182/test.crt"'),'--game-tls-host=localhost')
        $p=Start-Process -FilePath $engine -ArgumentList $arguments -WorkingDirectory $PWD -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $PWD "work/br-voice-$role-stdout.log") -RedirectStandardError (Join-Path $PWD "work/br-voice-$role-stderr.log")
        $processes+=$p
        if($role -eq 'server'){Start-Sleep -Seconds 1}
    }
    $limit=(Get-Date).AddSeconds(75)
    while(@($processes | Where-Object {-not $_.HasExited}).Count -gt 0 -and (Get-Date) -lt $limit){Start-Sleep -Milliseconds 300}
    foreach($p in $processes){if(-not $p.HasExited){throw 'Voice test timeout'}}
    foreach($role in @('server','alpha','bravo','charlie','delta')) {Get-Content -LiteralPath "work/br-voice-$role-stderr.log" -Tail 14}
    Get-Content work/br-voice-network.json
    if(@($processes | Where-Object {$_.ExitCode -ne 0}).Count -gt 0){throw 'Voice test failed'}
    if(Select-String -Path 'work/br-voice-*-stderr.log' -Pattern 'SCRIPT ERROR|Parse Error|^ERROR:' -Quiet){throw 'Voice script error'}
} finally {
    foreach($p in $processes){if(-not $p.HasExited){Stop-Process -Id $p.Id -Force}}
}
