# Get monitor names from WMI
$MonitorNames = Get-WmiObject -Namespace root\wmi -ClassName WmiMonitorID | ForEach-Object {
    if ($_.UserFriendlyName) {
        [System.Text.Encoding]::ASCII.GetString($_.UserFriendlyName -ne 0)
    } else {
        "Generic Monitor"
    }
}

# Load Windows Forms assembly to access screen information
Add-Type -AssemblyName System.Windows.Forms

# Display each monitor with its number, name, and device name
$i = 1
[System.Windows.Forms.Screen]::AllScreens | ForEach-Object {
    "$i`: $($MonitorNames[$i-1]) ($($_.DeviceName))"
    $i++
}