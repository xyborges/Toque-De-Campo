# Optional OS standby-list purge for a genuine cold-cache run on the test machine.
# Windows requires SeProfileSingleProcessPrivilege; report failure, never claim cold.
$ErrorActionPreference='Stop'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class MemoryPurge {
    [DllImport("ntdll.dll")]
    public static extern int NtSetSystemInformation(int kind, ref int command, int length);
}
'@
$cmd=4 # MemoryPurgeStandbyList, SystemMemoryListInformation=80
$status=[MemoryPurge]::NtSetSystemInformation(80,[ref]$cmd,4)
$report=[pscustomobject]@{local_time=(Get-Date).ToString('o');ntstatus=$status;success=($status -eq 0);method="NtSetSystemInformation(SystemMemoryListInformation,MemoryPurgeStandbyList)"}
Write-Output ('CACHE_PURGE '+($report |ConvertTo-Json -Compress))
if($status -ne 0){exit 5}
