; Monitor Switcher AutoHotkey Script (AutoHotkey v2)
;
;   Ctrl+Alt+V  v2 switch, elevated, via scheduled task "MonitorSwitcherV2" (moves admin windows too).
;               Falls back to running switch-v2.ps1 directly (non-elevated) if the task is not registered.
;               Register once from an admin shell in this folder:
;                   schtasks /Create /XML "MonitorSwitcherV2-Task.xml" /TN "MonitorSwitcherV2"
;   Ctrl+Alt+D  v2 dry run: writes the plan to logs\switch-YYYY-MM-DD.log, changes nothing.
;   Ctrl+Alt+M  v1 switch.ps1 (non-elevated)            - legacy
;   Ctrl+Alt+S  v1 via scheduled task "MonitorSwitcher"  - legacy
;   Ctrl+Alt+X  monitors off (PC keeps running); move the mouse to wake.

#Requires AutoHotkey v2.0+
#SingleInstance Force

SetWorkingDir(A_ScriptDir)

; --- v2 ---------------------------------------------------------------------
^!v:: {
    if (RunWait('schtasks /Query /TN "MonitorSwitcherV2"', , 'Hide') = 0) {
        Run('schtasks /Run /TN "MonitorSwitcherV2"', , 'Hide')
        Tip('Switching (v2, elevated)...')
    } else {
        Run('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "switch-v2.ps1"', , 'Hide')
        Tip('Switching (v2, NOT elevated: task MonitorSwitcherV2 not registered)...', 3000)
    }
}

^!d:: {
    Run('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "switch-v2.ps1" -DryRun', , 'Hide')
    Tip('v2 dry run -> logs\switch-' . FormatTime(, 'yyyy-MM-dd') . '.log', 3000)
}

; --- v1 (legacy) ------------------------------------------------------------
^!m:: {
    Run('powershell.exe -ExecutionPolicy Bypass -File "switch.ps1"', , 'Hide')
    Tip('Switching monitors and audio (v1)...')
}

^!s:: {
    Run('powershell.exe -ExecutionPolicy Bypass -File "admin_scheduled_task_switch.ps1"', , 'Hide')
    Tip('Switching monitors and audio (v1, elevated)...')
}

; --- misc -------------------------------------------------------------------
^!x:: {
    Run('nircmd.exe monitor off', , 'Hide')
    Tip('Monitors off', 1500)
}

Tip(text, ms := 2000) {
    ToolTip(text)
    SetTimer(() => ToolTip(), -ms)
}

Tip('Monitor Switcher loaded. Ctrl+Alt+V switch (v2) | Ctrl+Alt+D dry run | Ctrl+Alt+S/M v1 | Ctrl+Alt+X monitors off', 3000)
