# Load a small C# type into the current PowerShell session so we can call Win32 APIs directly.  
# Add-Type compiles the embedded C# and exposes the static methods so PowerShell can P/Invoke user32.dll [WM_SETTINGCHANGE docs describe the message behavior].
# This is a more elegant solution than restarting explorer.exe, which closes all open File Explorer windows.
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win {
  // FindWindow lets us get a handle (HWND) to an existing top-level window by its class name and/or title.
  // Explorer’s taskbar uses the window class "Shell_TrayWnd", so this retrieves the taskbar’s HWND.
  [DllImport("user32.dll", CharSet=CharSet.Auto)]
  public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

  // SendMessage posts a message to a specific window (here, the taskbar), synchronously delivering WM_SETTINGCHANGE.
  // Official guidance prefers broadcasting WM_SETTINGCHANGE to all top-level windows, but sending directly to Shell_TrayWnd is a common, pragmatic trick to nudge a redraw.
  [DllImport("user32.dll", SetLastError=true)]
  public static extern IntPtr SendMessage(IntPtr hWnd, int Msg, IntPtr wParam, IntPtr lParam);
}
"@

# Find the taskbar’s window by class name; returns IntPtr.Zero if not found.
$h = [Win]::FindWindow("Shell_TrayWnd", $null)

if ($h -ne [IntPtr]::Zero) {
  # WM_SETTINGCHANGE (aka WM_WININICHANGE) has numeric value 0x1A (26 decimal).
  # wParam must be NULL when an app sends this message; lParam can be a string hint like "TraySettings",
  # but passing IntPtr.Zero still prompts many shells to re-query settings and repaint the taskbar surface.
  # This is synchronous and targets the taskbar window only (not a broadcast).
  [void][Win]::SendMessage($h, 0x1A, [IntPtr]::Zero, [IntPtr]::Zero) # WM_SETTINGCHANGE
  Write-Host "Taskbar redrawn successfully"
} else {
  Write-Error "Failed to redraw taskbar"
}