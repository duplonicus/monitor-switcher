; Monitor Switcher AutoHotkey Script v2
; Press Ctrl+Alt+M to toggle between monitors and audio devices
; This script calls the PowerShell script switch.ps1

#Requires AutoHotkey v2.0+
#SingleInstance Force

; Set working directory to script location
SetWorkingDir(A_ScriptDir)

; Define the hotkey: Ctrl+Alt+M
^!m:: {
    ; Run the PowerShell script
    Run('powershell.exe -ExecutionPolicy Bypass -File "switch.ps1"', , 'Hide')
    ; Show a brief notification
    ToolTip('Switching monitors and audio...')
    SetTimer(RemoveToolTip, 2000)
}

; Alternative hotkey: Ctrl+Alt+S (for "Switch") - Uses Task Scheduler for admin privileges
^!s:: {
    Run('powershell.exe -ExecutionPolicy Bypass -File "admin_scheduled_task_switch.ps1"', , 'Hide')
    ToolTip('Switching monitors and audio (elevated)...')
    SetTimer(RemoveToolTip, 2000)
}

; Remove the tooltip after 2 seconds
RemoveToolTip() {
    ToolTip()
    SetTimer(RemoveToolTip, 0)
}

; Show help message on startup
ToolTip('Monitor Switcher loaded! Press Ctrl+Alt+M or Ctrl+Alt+S (admin scheduled task) to switch monitors')
SetTimer(RemoveStartupToolTip, 3000)

RemoveStartupToolTip() {
    ToolTip()
    SetTimer(RemoveStartupToolTip, 0)
}
