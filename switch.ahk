; Monitor Switcher hotkeys (AutoHotkey v2)
;
;   Ctrl+Alt+S  switch, elevated, via scheduled task "MonitorSwitcher" (so admin windows move too).
;   Ctrl+Alt+V  same as Ctrl+Alt+S.
;               Both fall back to running switch.ps1 directly (non-elevated) if the task is not registered.
;               Register once from an admin shell in this folder (edit the paths in the XML first if needed):
;                   schtasks /Create /XML "MonitorSwitcher-Task.xml" /TN "MonitorSwitcher" /F
;   Ctrl+Alt+M  switch directly, non-elevated: admin windows will not move.
;   Ctrl+Alt+D  dry run: writes the plan to logs\switch-YYYY-MM-DD.log, changes nothing.
;   Ctrl+Alt+X  monitors off (PC keeps running); move the mouse to wake.

#Requires AutoHotkey v2.0+
#SingleInstance Force

SetWorkingDir(A_ScriptDir)

SwitchElevated() {
    if (RunWait('schtasks /Query /TN "MonitorSwitcher"', , 'Hide') = 0) {
        Run('schtasks /Run /TN "MonitorSwitcher"', , 'Hide')
        Tip('Switching (elevated)...')
    } else {
        Run('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "switch.ps1"', , 'Hide')
        Tip('Switching (NOT elevated: task MonitorSwitcher not registered)...', 3000)
    }
}

^!s:: SwitchElevated()
^!v:: SwitchElevated()

^!m:: {
    Run('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "switch.ps1"', , 'Hide')
    Tip('Switching (non-elevated)...')
}

^!d:: {
    Run('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "switch.ps1" -DryRun', , 'Hide')
    Tip('Dry run -> logs\switch-' . FormatTime(, 'yyyy-MM-dd') . '.log', 3000)
}

^!x:: {
    Run('nircmd.exe monitor off', , 'Hide')
    Tip('Monitors off', 1500)
}

Tip(text, ms := 2000) {
    ToolTip(text)
    SetTimer(() => ToolTip(), -ms)
}

Tip('Monitor Switcher loaded. Ctrl+Alt+S: switch | M: switch (non-elevated) | D: dry run | X: monitors off', 3000)
