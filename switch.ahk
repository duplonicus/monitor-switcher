; Monitor Switcher AutoHotkey Script (AutoHotkey v2)
;
;   Ctrl+Alt+V  switch (v2), elevated, via scheduled task "MonitorSwitcherV2" (moves admin windows too).
;   Ctrl+Alt+S  same as Ctrl+Alt+V (kept because muscle memory).
;               Both fall back to running switch-v2.ps1 directly (non-elevated) if the task is not registered.
;               Register once from an admin shell in this folder:
;                   schtasks /Create /XML "MonitorSwitcherV2-Task.xml" /TN "MonitorSwitcherV2"
;   Ctrl+Alt+M  switch (v2) directly, non-elevated: admin windows will not move.
;   Ctrl+Alt+D  v2 dry run: writes the plan to logs\switch-YYYY-MM-DD.log, changes nothing.
;   Ctrl+Alt+X  monitors off (PC keeps running); move the mouse to wake.
;
;   v1 (switch.ps1, task "MonitorSwitcher") is no longer bound to any key. Run .\switch.ps1 by hand if you need it.

#Requires AutoHotkey v2.0+
#SingleInstance Force

SetWorkingDir(A_ScriptDir)

; --- v2 ---------------------------------------------------------------------
SwitchElevated() {
    if (RunWait('schtasks /Query /TN "MonitorSwitcherV2"', , 'Hide') = 0) {
        Run('schtasks /Run /TN "MonitorSwitcherV2"', , 'Hide')
        Tip('Switching (v2, elevated)...')
    } else {
        Run('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "switch-v2.ps1"', , 'Hide')
        Tip('Switching (v2, NOT elevated: task MonitorSwitcherV2 not registered)...', 3000)
    }
}

^!v:: SwitchElevated()
^!s:: SwitchElevated()

^!m:: {
    Run('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "switch-v2.ps1"', , 'Hide')
    Tip('Switching (v2, non-elevated)...')
}

^!d:: {
    Run('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "switch-v2.ps1" -DryRun', , 'Hide')
    Tip('v2 dry run -> logs\switch-' . FormatTime(, 'yyyy-MM-dd') . '.log', 3000)
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

Tip('Monitor Switcher loaded. Ctrl+Alt+V or S: switch (elevated) | M: switch (non-elevated) | D: dry run | X: monitors off', 3000)
