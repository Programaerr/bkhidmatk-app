# Stops Flutter runs left from an earlier F5, so a new run never builds or installs
# at the same time as an old one. Their phone log readers are closed with them.
$ErrorActionPreference = 'SilentlyContinue'

$runs = @(Get-CimInstance Win32_Process | Where-Object {
        $_.Name -match '^dart(vm)?\.exe$' -and $_.CommandLine -match 'flutter_tools\.snapshot"?\s+run\b'
    })
foreach ($run in $runs) {
    # A run's helper may already be gone with its parent, so taskkill's complaint is dropped.
    taskkill /PID $run.ProcessId /T /F 2>$null | Out-Null
}

Get-CimInstance Win32_Process | Where-Object {
    $_.Name -eq 'adb.exe' -and $_.CommandLine -match 'logcat -v time -T'
} | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

if ($runs.Count -gt 0) {
    Write-Output "Stopped $($runs.Count) earlier Flutter run(s)."
}
exit 0
