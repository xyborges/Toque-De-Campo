$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$godot = 'C:\Users\Microgate\Documents\Codex\2026-11-06\fa-a\work\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$out = $PSScriptRoot
$pattern = @(0,1,1,0,0,1,1,0,0,1)
$rows = @()
$env:TDC_IA2_REUSE_RESPAWN_WEAPON = '0'
$env:TDC_IA2_DEFER_REMOTE_RAGDOLL = '0'
$env:TDC_IA2_CLIENT_PROJECTILE_30HZ = '0'
$env:TDC_IA2_LAYOUT_REUSE_FRONTAGE = '0'
$env:TDC_IA2_MAP_STAGES = '0'
foreach ($mode in @('weapons','ragdolls')) {
    for ($i=0; $i -lt $pattern.Count; $i++) {
        $r = $i+1
        $variant = $pattern[$i]
        $letter = if ($variant -eq 0) { 'a' } else { 'b' }
        $base = '{0}-{1:D2}-{2}' -f $mode,$r,$letter
        $log = Join-Path $out ($base+'.log')
        $json = Join-Path $out ($base+'.json')
        if (@(Get-Process -Name 'Godot*' -ErrorAction SilentlyContinue).Count -gt 0) {
            throw 'Another Godot process is running. Measurements must be isolated.'
        }
        $at = [DateTime]::UtcNow.ToString('o')
        & $godot --headless --path $repo --script res://tests/ia2_respawn_ragdoll_benchmark.gd -- "--mode=$mode" "--optimized=$variant" "--run=$r" *> $log
        $code = $LASTEXITCODE
        if ($code -ne 0) { throw "Failed $base, exit $code" }
        $line = Get-Content -LiteralPath $log | Where-Object { $_.StartsWith('IA2_RAGDOLL_WEAPON_BENCH ') } | Select-Object -Last 1
        if ($null -eq $line) { throw "Missing performance report for $base" }
        $raw = $line.Substring('IA2_RAGDOLL_WEAPON_BENCH '.Length)
        $result = $raw | ConvertFrom-Json
        if (@($result.failures).Count -gt 0 -or $result.actor_count -ne 28) { throw "Functional regression at $base" }
        [System.IO.File]::WriteAllText($json,$raw,(New-Object System.Text.UTF8Encoding($false)))
        $spot = if ($mode -eq 'weapons') { $result.refresh_ms } else { $result.death_callback_ms }
        $frame = if ($mode -eq 'weapons') { $result.approx_frame_ms } else { $result.intervals_ms }
        $row = [pscustomobject]@{
            mode=$mode; order=$r;variant=$variant;started_utc=$at
            actor_count=$result.actor_count
            event_count= if ($mode -eq 'weapons') { $result.events } else { $result.death_events }
            spot_mean_ms=$spot.mean_ms
            spot_p95_ms=$spot.p95_ms
            spot_p99_ms=$spot.p99_ms
            spot_max_ms=$spot.max_ms
            observed_interval_p95_ms=$frame.p95_ms
            observed_interval_p99_ms=$frame.p99_ms
            observed_interval_max_ms=$frame.max_ms
            observed_intervals_over_33ms=$frame.over_33ms
            weapon_reuses= if ($mode -eq 'weapons') { $result.reuses } else { $null }
            full_builds= if ($mode -eq 'weapons') { $result.full_builds } else { $null }
            deferred_ragdolls= if ($mode -eq 'ragdolls') { $result.deferred_created } else { $null }
            godot_version=$result.godot_version
        }
        $rows += $row
        $rows | Export-Csv -LiteralPath (Join-Path $out 'five-pairs-raw.csv') -NoTypeInformation -Encoding utf8
        Write-Output ('PAIR_RUN '+($row | ConvertTo-Json -Compress))
    }
}
Write-Output ('COMPLETE '+$rows.Count)
