# Toggle primary monitor and audio device
# Useful for when you need to switch between a monitor at a desk and a TV from the couch

# Monitor Toggle using NirCmd
$logPath = "$env:USERPROFILE\SwapMonitorsLog.txt"
if (!(Test-Path $logPath)) { Set-Content $logPath "1" }
$lastMonitor = Get-Content $logPath
$nextMonitor = if ($lastMonitor -eq "1") { "4" } else { "1" }
Set-Content $logPath $nextMonitor
Start-Process "nircmd.exe" -ArgumentList "setprimarydisplay $nextMonitor"
Write-Host "Switched to Monitor $nextMonitor"

# Audio Toggle using NirCmd
$audioLogPath = "$env:USERPROFILE\SwapAudioLog.txt"
if (!(Test-Path $audioLogPath)) { Set-Content $audioLogPath "device1" }
$lastAudioDevice = Get-Content $audioLogPath

if ($lastAudioDevice -eq "device1") {
    Start-Process "nircmd.exe" -ArgumentList 'setdefaultsounddevice "TV" 1'
    Set-Content $audioLogPath "device2"
    Write-Host "Switched to Soundbar"
} else {
    Start-Process "nircmd.exe" -ArgumentList 'setdefaultsounddevice "Headphones" 1'
    Set-Content $audioLogPath "device1" 
    Write-Host "Switched to Headphones"
}