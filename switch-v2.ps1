<#
.SYNOPSIS
    Monitor Switcher v2 - closed-loop desk <-> couch switch.

.DESCRIPTION
    Replaces switch.ps1. What is different, and why:

      * Monitors are identified by EDID short ID / serial / \\.\DISPLAYn - never by a bare number.
        To MultiMonitorTool a bare number means "\\.\DISPLAY<n>", and Windows renumbers those on
        driver installs and hot-plugs. On 2026-09-26 this machine had DISPLAY13..16, so the old
        config's 1/2/3/4 resolved to nothing and /SetPrimary silently did no work.
      * The direction comes from the CURRENT primary monitor, read live. There is no state file
        to drift out of sync with reality.
      * The primary switch is polled until Windows confirms it, and nothing else happens if it
        never does. No more moving windows and toggling audio against a display that did not switch.
      * Windows are moved with SetWindowPlacement, which moves minimized windows too and keeps each
        window's minimized / maximized / normal state. Nothing is maximized just to make it movable.
      * Every move is verified against the monitor the window actually landed on, retried once,
        and failures are logged with a reason (e.g. elevated window from a non-elevated run).
      * Audio is selected by MONITOR, not by device name: a display-audio endpoint carries the same
        PnP container ID as the monitor it belongs to, so "the audio of AOC2401" survives the renames
        Windows does on every driver install. Set natively (IPolicyConfig) for all three roles and
        read back to confirm. Names and endpoint IDs remain available as explicit fallbacks.
      * Every run writes logs\switch-YYYY-MM-DD.log so "sometimes" leaves evidence.

    Elevated (admin) windows can only be moved by an elevated process. Register the scheduled task
    (MonitorSwitcherV2-Task.xml) and run it from the hotkey, exactly like v1's Ctrl+Alt+S.

.PARAMETER DryRun
    Log the plan (monitors seen, current primary, target, per-window destination) and change nothing.

.PARAMETER To
    Force a direction ('desk' or 'couch') instead of toggling from the current primary.
    Also useful to re-apply the layout without switching.

.PARAMETER ListAudio
    List the active playback endpoints with the monitor each belongs to, then exit.

.EXAMPLE
    .\switch-v2.ps1 -DryRun
    .\switch-v2.ps1
    .\switch-v2.ps1 -To desk
    .\switch-v2.ps1 -ListAudio
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [ValidateSet('desk', 'couch')]
    [string]$To,
    [switch]$ListAudio
)

$ErrorActionPreference = 'Stop'
$here    = $PSScriptRoot
$mmtExe  = Join-Path $here 'MultiMonitorTool.exe'
$nircmd  = Join-Path $here 'nircmd.exe'
$cfgPath = Join-Path $here 'config-v2.json'

# ---------------------------------------------------------------- logging
$logDir = Join-Path $here 'logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$logFile = Join-Path $logDir ('switch-{0:yyyy-MM-dd}.log' -f (Get-Date))

function Log {
    param([string]$Message, [string]$Level = 'INFO')
    $line = '{0:HH:mm:ss.fff} [{1,-5}] {2}' -f (Get-Date), $Level, $Message
    Add-Content -Path $logFile -Value $line
    Write-Host $line
}

function Trunc([string]$s, [int]$n) { if ($s.Length -gt $n) { $s.Substring(0, $n - 1) + '~' } else { $s } }

# ---------------------------------------------------------------- native
Add-Type -TypeDefinition @"
using System;
using System.Text;
using System.Runtime.InteropServices;
using System.Collections.Generic;

public static class Native {
    [StructLayout(LayoutKind.Sequential)] public struct RECT  { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct MONITORINFOEX {
        public int cbSize; public RECT rcMonitor; public RECT rcWork; public uint dwFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string szDevice;
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct WINDOWPLACEMENT {
        public int length; public int flags; public int showCmd;
        public POINT ptMinPosition; public POINT ptMaxPosition; public RECT rcNormalPosition;
    }

    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    public delegate bool MonitorEnumProc(IntPtr hMonitor, IntPtr hdc, ref RECT rect, IntPtr lParam);

    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr clip, MonitorEnumProc cb, IntPtr lParam);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern bool GetMonitorInfo(IntPtr hMonitor, ref MONITORINFOEX mi);
    [DllImport("user32.dll")] public static extern IntPtr MonitorFromWindow(IntPtr hWnd, uint flags);
    [DllImport("user32.dll")] public static extern IntPtr MonitorFromRect(ref RECT r, uint flags);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr hWnd);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr hWnd, StringBuilder s, int n);
    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")] public static extern IntPtr GetWindowLongPtr(IntPtr hWnd, int idx);
    [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr hWnd, uint cmd);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll", SetLastError = true)] public static extern bool GetWindowPlacement(IntPtr hWnd, ref WINDOWPLACEMENT wp);
    [DllImport("user32.dll", SetLastError = true)] public static extern bool SetWindowPlacement(IntPtr hWnd, ref WINDOWPLACEMENT wp);
    [DllImport("user32.dll", SetLastError = true)] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int cmd);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindow(string cls, string title);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);
    [DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll")] public static extern bool SystemParametersInfo(uint action, uint p, ref RECT r, uint winini);
    [DllImport("user32.dll", SetLastError = true)] public static extern bool SetProcessDpiAwarenessContext(IntPtr ctx);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr hWnd, int attr, out int val, int size);

    public static List<IntPtr> Windows() {
        var l = new List<IntPtr>();
        EnumWindows((h, p) => { l.Add(h); return true; }, IntPtr.Zero);
        return l;
    }
    public static List<IntPtr> Monitors() {
        var l = new List<IntPtr>();
        EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, (IntPtr m, IntPtr hdc, ref RECT r, IntPtr p) => { l.Add(m); return true; }, IntPtr.Zero);
        return l;
    }
}
"@

# Per-monitor DPI awareness, so every rect we read or write is in physical pixels regardless of
# the 125% monitor. Must happen before any other user32 call in this process.
$dpiMode = 'unaware'
try {
    if ([Native]::SetProcessDpiAwarenessContext((New-Object System.IntPtr -ArgumentList ([long]-4)))) { $dpiMode = 'per-monitor-v2' }
    elseif ([Runtime.InteropServices.Marshal]::GetLastWin32Error() -eq 5) { $dpiMode = 'per-monitor-v2 (set by an earlier run in this shell)' }   # ERROR_ACCESS_DENIED = awareness already set; it cannot be lowered
    elseif ([Native]::SetProcessDPIAware()) { $dpiMode = 'system' }
} catch { if ([Native]::SetProcessDPIAware()) { $dpiMode = 'system' } }

# ---------------------------------------------------------------- audio (native)
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;
namespace SwitcherAudio {
    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] public class MMDeviceEnumeratorCom {}
    [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IMMDeviceEnumerator {
        [PreserveSig] int EnumAudioEndpoints(int dataFlow, int stateMask, out IMMDeviceCollection devices);
        [PreserveSig] int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice device);
    }
    [ComImport, Guid("0BD7A1BE-7A1A-44DB-8397-CC5392387B5E"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IMMDeviceCollection { [PreserveSig] int GetCount(out uint count); [PreserveSig] int Item(uint index, out IMMDevice device); }
    [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IMMDevice {
        [PreserveSig] int Activate(ref Guid iid, int clsCtx, IntPtr p, out IntPtr iface);
        [PreserveSig] int OpenPropertyStore(int access, out IPropertyStore ps);
        [PreserveSig] int GetId([MarshalAs(UnmanagedType.LPWStr)] out string id);
        [PreserveSig] int GetState(out int state);
    }
    [StructLayout(LayoutKind.Sequential)] public struct PROPERTYKEY { public Guid fmtid; public uint pid; }
    [StructLayout(LayoutKind.Sequential)] public struct PROPVARIANT { public ushort vt; public ushort r1, r2, r3; public IntPtr p; public IntPtr p2; }
    [ComImport, Guid("886d8eeb-8cf2-4446-8d02-cdba1dbdcf99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IPropertyStore {
        [PreserveSig] int GetCount(out uint c); [PreserveSig] int GetAt(uint i, out PROPERTYKEY k);
        [PreserveSig] int GetValue(ref PROPERTYKEY k, out PROPVARIANT v); [PreserveSig] int SetValue(ref PROPERTYKEY k, ref PROPVARIANT v); [PreserveSig] int Commit();
    }
    // IPolicyConfig is undocumented but has been stable since Windows 7; it is what the Settings app,
    // nircmd, SoundSwitch and AudioDeviceCmdlets all use to change the default endpoint.
    [ComImport, Guid("870af99c-171d-4f9e-af0d-e63df40c2bc9")] public class PolicyConfigClientCom {}
    [ComImport, Guid("f8679f50-850a-41cf-9c72-430f290290c8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IPolicyConfig {
        [PreserveSig] int GetMixFormat(string id, out IntPtr f); [PreserveSig] int GetDeviceFormat(string id, int d, out IntPtr f); [PreserveSig] int ResetDeviceFormat(string id);
        [PreserveSig] int SetDeviceFormat(string id, IntPtr a, IntPtr b); [PreserveSig] int GetProcessingPeriod(string id, int d, out long a, out long b); [PreserveSig] int SetProcessingPeriod(string id, ref long p);
        [PreserveSig] int GetShareMode(string id, out IntPtr m); [PreserveSig] int SetShareMode(string id, IntPtr m); [PreserveSig] int GetPropertyValue(string id, int s, ref PROPERTYKEY k, out PROPVARIANT v);
        [PreserveSig] int SetPropertyValue(string id, int s, ref PROPERTYKEY k, ref PROPVARIANT v);
        [PreserveSig] int SetDefaultEndpoint([MarshalAs(UnmanagedType.LPWStr)] string id, int role);
        [PreserveSig] int SetEndpointVisibility(string id, int v);
    }
    public class Endpoint {
        public string Id; public string Name; public string Adapter; public int FormFactor; public string ContainerId; public string Topology;
        public bool DefaultConsole; public bool DefaultMultimedia; public bool DefaultCommunications;
    }
    public static class Api {
        [DllImport("ole32.dll")] static extern int PropVariantClear(ref PROPVARIANT v);
        static readonly Guid PKEY_Device          = new Guid("a45c254e-df1c-4efd-8020-67d146a850e0"); // ,2 name (user-editable)
        static readonly Guid PKEY_DeviceInterface = new Guid("026e516e-b814-414b-83cd-856d6fef4822"); // ,2 adapter
        static readonly Guid PKEY_ContainerId     = new Guid("8c7ed206-3f8a-4827-b3ab-ae9e1faefc6c"); // ,2 same as the monitor's
        static readonly Guid PKEY_AudioEndpoint   = new Guid("1da5d803-d492-4edd-8c23-e0c0ffee7f0e"); // ,0 form factor
        static readonly Guid PKEY_Topology        = new Guid("b3f8fa53-0004-438e-9003-51a46e139bfc"); // ,11 KS topology filter (per GPU port)
        static string Str(IPropertyStore ps, Guid fmt, uint pid) {
            var k = new PROPERTYKEY { fmtid = fmt, pid = pid }; PROPVARIANT v;
            if (ps.GetValue(ref k, out v) != 0) return "";
            string s = "";
            if (v.vt == 31) s = Marshal.PtrToStringUni(v.p);
            else if (v.vt == 72) s = ((Guid)Marshal.PtrToStructure(v.p, typeof(Guid))).ToString();
            else if (v.vt == 19 || v.vt == 3) s = (v.p.ToInt64() & 0xFFFFFFFF).ToString();
            PropVariantClear(ref v); return s;
        }
        public static List<Endpoint> Render() {
            var en = (IMMDeviceEnumerator)new MMDeviceEnumeratorCom(); var defs = new string[3]; IMMDevice d;
            for (int r = 0; r < 3; r++) { defs[r] = ""; if (en.GetDefaultAudioEndpoint(0, r, out d) == 0) { string id; d.GetId(out id); defs[r] = id; } }
            IMMDeviceCollection col; en.EnumAudioEndpoints(0, 1, out col); uint n; col.GetCount(out n);   // eRender, DEVICE_STATE_ACTIVE
            var list = new List<Endpoint>();
            for (uint i = 0; i < n; i++) {
                col.Item(i, out d); string id; d.GetId(out id); IPropertyStore ps; d.OpenPropertyStore(0, out ps);
                var e = new Endpoint { Id = id, Name = Str(ps, PKEY_Device, 2), Adapter = Str(ps, PKEY_DeviceInterface, 2),
                    ContainerId = Str(ps, PKEY_ContainerId, 2).ToLowerInvariant(), Topology = Str(ps, PKEY_Topology, 11) };
                int ff; int.TryParse(Str(ps, PKEY_AudioEndpoint, 0), out ff); e.FormFactor = ff;
                e.DefaultConsole = defs[0] == id; e.DefaultMultimedia = defs[1] == id; e.DefaultCommunications = defs[2] == id;
                list.Add(e);
            }
            return list;
        }
        public static int SetDefault(string id, int role) { var pc = (IPolicyConfig)new PolicyConfigClientCom(); return pc.SetDefaultEndpoint(id, role); }
    }
}
"@

$SW_SHOWMAXIMIZED   = 3
$SW_SHOWNOACTIVATE  = 4
$SW_SHOWMINNOACTIVE = 7
$SW_RESTORE         = 9

# ---------------------------------------------------------------- tools
function Invoke-Tool {
    param([string]$Exe, [string]$Arguments, [switch]$NoWait)
    Log ('> {0} {1}' -f (Split-Path $Exe -Leaf), $Arguments) 'CMD'
    if (-not (Test-Path $Exe)) { throw "tool not found: $Exe" }
    if ($NoWait) { Start-Process -FilePath $Exe -ArgumentList $Arguments -WindowStyle Hidden | Out-Null; return $null }
    $p = Start-Process -FilePath $Exe -ArgumentList $Arguments -WindowStyle Hidden -PassThru -Wait
    return $p.ExitCode
}

function Notify([string]$Text) {
    if (-not $cfg.notify) { return }
    try { Invoke-Tool $nircmd ('trayballoon "Monitor Switcher" "{0}" "" 4000' -f ($Text -replace '"', "'")) -NoWait } catch { Log "notify failed: $($_.Exception.Message)" 'WARN' }
}

# ---------------------------------------------------------------- monitors
function Get-MmtMonitors {
    # MultiMonitorTool is the source of truth for identity (EDID short ID, serial) and the primary flag.
    $csv = Join-Path $env:TEMP 'monitor-switcher-v2-monitors.csv'
    if (Test-Path $csv) { Remove-Item $csv -Force }
    Invoke-Tool $mmtExe ('/scomma "{0}"' -f $csv) | Out-Null
    if (-not (Test-Path $csv)) { throw 'MultiMonitorTool produced no monitor list (/scomma)' }
    Import-Csv $csv | ForEach-Object {
        [pscustomobject]@{
            Name        = $_.Name
            ShortId     = $_.'Short Monitor ID'
            Serial      = $_.'Monitor Serial Number'
            MonitorName = $_.'Monitor Name'
            Active      = ($_.Active -eq 'Yes')
            Primary     = ($_.Primary -eq 'Yes')
            Resolution  = $_.Resolution
            Position    = $_.'Left-Top'
            Scale       = $_.'Current Scale'
        }
    }
}

function Get-LiveMonitors {
    # Geometry straight from Windows, in physical pixels. Re-read after the primary changes:
    # every monitor's coordinates shift when the origin moves.
    foreach ($m in [Native]::Monitors()) {
        $mi = New-Object Native+MONITORINFOEX
        $mi.cbSize = [Runtime.InteropServices.Marshal]::SizeOf($mi)
        [void][Native]::GetMonitorInfo($m, [ref]$mi)
        [pscustomobject]@{ Handle = $m; Name = $mi.szDevice; Primary = (($mi.dwFlags -band 1) -ne 0); Mon = $mi.rcMonitor; Work = $mi.rcWork }
    }
}

function Resolve-Monitor {
    param([string]$Spec, $Mmt)
    if (-not $Spec) { return $null }
    if ($Spec -eq 'Primary') { return ($Mmt | Where-Object Primary | Select-Object -First 1) }
    if ($Spec -match '^\d+$') {
        Log "monitor spec '$Spec' is a bare number. MultiMonitorTool reads that as \\.\DISPLAY$Spec, which Windows renumbers; use the Short Monitor ID or serial instead." 'WARN'
        $Spec = "\\.\DISPLAY$Spec"
    }
    $Mmt | Where-Object { $_.ShortId -eq $Spec -or $_.Serial -eq $Spec -or $_.Name -eq $Spec -or $_.MonitorName -eq $Spec } | Select-Object -First 1
}

function Wait-Primary {
    param([string]$DeviceName, [int]$TimeoutMs)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    do {
        $p = Get-LiveMonitors | Where-Object Primary | Select-Object -First 1
        if ($p -and $p.Name -eq $DeviceName) { Log ('primary confirmed after {0} ms' -f $sw.ElapsedMilliseconds); return $true }
        Start-Sleep -Milliseconds 200
    } while ($sw.ElapsedMilliseconds -lt $TimeoutMs)
    return $false
}

function Get-WorkspaceOffset {
    # WINDOWPLACEMENT.rcNormalPosition is in "workspace coordinates": screen coordinates minus the
    # primary monitor's work-area origin. That is (0,0) with a bottom taskbar, but not always.
    $r = New-Object Native+RECT
    [void][Native]::SystemParametersInfo(0x30, 0, [ref]$r, 0)   # SPI_GETWORKAREA
    @{ X = $r.Left; Y = $r.Top }
}

# ---------------------------------------------------------------- audio
$formFactors = @{ 0 = 'network'; 1 = 'speakers'; 2 = 'line'; 3 = 'headphones'; 4 = 'microphone'; 5 = 'headset'; 6 = 'handset'; 7 = 'digital'; 8 = 'spdif'; 9 = 'display-audio'; 10 = 'unknown' }

function Get-AudioEndpoints { ,@([SwitcherAudio.Api]::Render()) }

function Get-MonitorContainers {
    # monitor EDID short ID (AOC2401) -> PnP container ID. Display-audio endpoints share the container
    # of their monitor, which is what makes "audio of monitor X" resolvable without any device name.
    $map = @{}
    try {
        foreach ($dev in (Get-PnpDevice -Class Monitor -PresentOnly -ErrorAction Stop)) {
            $short = ($dev.InstanceId -split '\\')[1]
            $cid = (Get-PnpDeviceProperty -InstanceId $dev.InstanceId -KeyName DEVPKEY_Device_ContainerId -ErrorAction SilentlyContinue).Data
            if ($short -and $cid) { $map[$short] = ([string]$cid).Trim('{}').ToLowerInvariant() }
        }
    } catch { Log "monitor container lookup failed: $($_.Exception.Message)" 'WARN' }
    $map
}

function Resolve-AudioEndpoint {
    # $Spec: { monitor: 'AOC2401' } | { name: 'TV' } | { id: '{0.0.0...}' } | { topology: 'topo04' } | 'TV' (legacy string = name)
    param($Spec, $Endpoints, $Containers)
    if (-not $Spec) { return $null }
    if ($Spec -is [string]) { $Spec = [pscustomobject]@{ name = $Spec } }
    if ($Spec.monitor) {
        $cid = $Containers[[string]$Spec.monitor]
        if (-not $cid) { Log "audio: no present monitor with ID '$($Spec.monitor)'" 'WARN' }
        else {
            $hit = $Endpoints | Where-Object { $_.ContainerId -eq $cid } | Select-Object -First 1
            if ($hit) { return [pscustomobject]@{ Endpoint = $hit; How = "audio of monitor $($Spec.monitor)" } }
            Log "audio: monitor $($Spec.monitor) has no active audio endpoint" 'WARN'
        }
    }
    if ($Spec.id)       { $hit = $Endpoints | Where-Object { $_.Id -eq $Spec.id } | Select-Object -First 1;                 if ($hit) { return [pscustomobject]@{ Endpoint = $hit; How = 'endpoint id' } } }
    if ($Spec.topology) { $hit = $Endpoints | Where-Object { $_.Topology -like "*$($Spec.topology)*" } | Select-Object -First 1; if ($hit) { return [pscustomobject]@{ Endpoint = $hit; How = "topology '$($Spec.topology)'" } } }
    if ($Spec.name)     { $hit = $Endpoints | Where-Object { $_.Name -eq $Spec.name } | Select-Object -First 1;             if ($hit) { return [pscustomobject]@{ Endpoint = $hit; How = "name '$($Spec.name)' (names are reset by Windows on driver installs; prefer monitor)" } } }
    return $null
}

function Format-AudioEndpoint($ep, $Containers) {
    $mon = ($Containers.GetEnumerator() | Where-Object { $_.Value -eq $ep.ContainerId } | Select-Object -First 1).Key
    $roles = @(); if ($ep.DefaultConsole) { $roles += 'console' }; if ($ep.DefaultMultimedia) { $roles += 'multimedia' }; if ($ep.DefaultCommunications) { $roles += 'communications' }
    '{0,-22} adapter={1,-30} type={2,-13} monitor={3,-8} default=[{4}]' -f (Trunc $ep.Name 22), (Trunc $ep.Adapter 30), $formFactors[$ep.FormFactor], $(if ($mon) { $mon } else { '-' }), ($roles -join ' ')
}

function Set-DefaultAudio {
    param($Ep, $Roles)
    foreach ($r in $Roles) {
        $hr = [SwitcherAudio.Api]::SetDefault($Ep.Id, [int]$r)
        if ($hr -ne 0) { Log ('audio: SetDefaultEndpoint role {0} failed hr=0x{1:X8}' -f $r, $hr) 'WARN' }
    }
    $after = Get-AudioEndpoints | Where-Object { $_.Id -eq $Ep.Id } | Select-Object -First 1
    $ok = [bool]($after -and $after.DefaultMultimedia)
    Log ("audio: default -> '{0}' ({1}){2}" -f $Ep.Name, $Ep.Adapter, $(if ($ok) { ', confirmed' } else { '  NOT CONFIRMED' }))
    return $ok
}

# ---------------------------------------------------------------- windows
$skipClasses = @(
    'Progman', 'WorkerW', 'Shell_TrayWnd', 'Shell_SecondaryTrayWnd', 'Windows.UI.Core.CoreWindow',
    'DV2ControlHost', 'MSCTFIME UI', 'IME', 'ForegroundStaging', 'XamlExplorerHostIslandWindow',
    'Windows.Internal.Shell.TabProxyWindow', 'TaskListThumbnailWnd', 'tooltips_class32'
)

function Get-CandidateWindows {
    param($LiveMons)
    $wsOff = Get-WorkspaceOffset
    foreach ($h in [Native]::Windows()) {
        if (-not [Native]::IsWindowVisible($h)) { continue }
        $sb = New-Object System.Text.StringBuilder 1024
        [void][Native]::GetWindowText($h, $sb, 1024)
        $title = $sb.ToString()
        if ($title -eq '') { continue }
        $cb = New-Object System.Text.StringBuilder 256
        [void][Native]::GetClassName($h, $cb, 256)
        $class = $cb.ToString()
        if ($skipClasses -contains $class) { continue }
        $cloaked = 0
        [void][Native]::DwmGetWindowAttribute($h, 14, [ref]$cloaked, 4)          # DWMWA_CLOAKED
        if ($cloaked -ne 0) { continue }                                          # other virtual desktop / suspended UWP
        $ex = [Native]::GetWindowLongPtr($h, -20).ToInt64()                       # GWL_EXSTYLE
        $isTool = ($ex -band 0x80) -ne 0                                          # WS_EX_TOOLWINDOW
        $isApp  = ($ex -band 0x40000) -ne 0                                       # WS_EX_APPWINDOW
        if ($isTool -and -not $isApp) { continue }
        $owner = [Native]::GetWindow($h, 4)                                       # GW_OWNER
        if ($owner -ne [IntPtr]::Zero -and -not $isApp) { continue }              # dialogs follow their owner
        $wpid = [uint32]0
        [void][Native]::GetWindowThreadProcessId($h, [ref]$wpid)
        if ($wpid -eq $PID) { continue }
        try { $procName = (Get-Process -Id $wpid -ErrorAction Stop).ProcessName } catch { $procName = "pid$wpid" }
        if ($procName -in @('MultiMonitorTool', 'nircmd')) { continue }
        $wp = New-Object Native+WINDOWPLACEMENT
        $wp.length = [Runtime.InteropServices.Marshal]::SizeOf($wp)
        if (-not [Native]::GetWindowPlacement($h, [ref]$wp)) { continue }
        $nr = New-Object Native+RECT
        $nr.Left = $wp.rcNormalPosition.Left + $wsOff.X;  $nr.Top    = $wp.rcNormalPosition.Top + $wsOff.Y
        $nr.Right = $wp.rcNormalPosition.Right + $wsOff.X; $nr.Bottom = $wp.rcNormalPosition.Bottom + $wsOff.Y
        $isMin = [Native]::IsIconic($h)
        if ($isMin) { $mh = [Native]::MonitorFromRect([ref]$nr, 2) } else { $mh = [Native]::MonitorFromWindow($h, 2) }   # MONITOR_DEFAULTTONEAREST
        $src = $LiveMons | Where-Object { $_.Handle -eq $mh } | Select-Object -First 1
        [pscustomobject]@{
            Handle = $h; Title = $title; Class = $class; Process = "$procName.exe"; ProcId = $wpid
            Min = $isMin; Max = [Native]::IsZoomed($h); NormalRect = $nr; SrcMonitor = $src
        }
    }
}

function Find-Rule {
    param($Win, [string]$Mode)
    foreach ($r in $cfg.rules) {
        if ($r.when -and $r.when -ne $Mode) { continue }
        $m = $r.match
        if (-not $m) { continue }
        if ($m.process -and $Win.Process -ne $m.process) { continue }
        if ($m.class   -and $Win.Class   -ne $m.class)   { continue }
        if ($m.title   -and $Win.Title   -notlike "*$($m.title)*") { continue }
        return $r
    }
    return $null
}

function New-Plan {
    param($Wins, [string]$Mode, $Target, $Mmt, $ModeCfg)
    foreach ($w in $Wins) {
        $rule = Find-Rule $w $Mode
        $dest = $Target
        if ($rule -and $rule.monitor) {
            $dest = Resolve-Monitor $rule.monitor $Mmt
            if (-not $dest -or -not $dest.Active) {
                Log "rule monitor '$($rule.monitor)' not available; '$(Trunc $w.Title 40)' goes to the primary instead" 'WARN'
                $dest = $Target
            }
        }
        $place = 'keep'
        if ($ModeCfg.defaultPlace) { $place = $ModeCfg.defaultPlace }
        if ($rule -and $rule.place) { $place = $rule.place }
        [pscustomobject]@{ Win = $w; DestName = $dest.Name; DestLabel = $dest.ShortId; Place = $place; Rule = $rule }
    }
}

function Get-WindowState($w) { if ($w.Min) { 'min' } elseif ($w.Max) { 'max' } else { 'normal' } }

function Move-PlannedWindow {
    param($Plan, $LiveMons, $WsOff)
    $w = $Plan.Win
    $dest = $LiveMons | Where-Object { $_.Name -eq $Plan.DestName } | Select-Object -First 1
    if (-not $dest) { return @{ Ok = $false; Reason = "destination $($Plan.DestName) not present after the switch" } }
    $work = $dest.Work
    $workW = $work.Right - $work.Left; $workH = $work.Bottom - $work.Top
    $nr = $w.NormalRect
    $wW = $nr.Right - $nr.Left; $wH = $nr.Bottom - $nr.Top
    # keep the window's position relative to its source monitor's work area
    $relX = 0; $relY = 0
    if ($w.SrcMonitor) { $relX = $nr.Left - $w.SrcMonitor.Work.Left; $relY = $nr.Top - $w.SrcMonitor.Work.Top }
    $x = $work.Left + $relX; $y = $work.Top + $relY
    switch ($Plan.Place) {
        'left'   { $x = $work.Left; $y = $work.Top; $wW = [int]($workW / 2); $wH = $workH; $cmd = $SW_SHOWNOACTIVATE }
        'right'  { $x = $work.Left + [int]($workW / 2); $y = $work.Top; $wW = $workW - [int]($workW / 2); $wH = $workH; $cmd = $SW_SHOWNOACTIVATE }
        'max'    { $cmd = $SW_SHOWMAXIMIZED }
        'min'    { $cmd = $SW_SHOWMINNOACTIVE }
        'normal' { $cmd = $SW_SHOWNOACTIVATE }
        default  { if ($w.Min) { $cmd = $SW_SHOWMINNOACTIVE } elseif ($w.Max) { $cmd = $SW_SHOWMAXIMIZED } else { $cmd = $SW_SHOWNOACTIVATE } }
    }
    # clamp into the destination work area
    if ($wW -gt $workW) { $wW = $workW }
    if ($wH -gt $workH) { $wH = $workH }
    if ($x + $wW -gt $work.Right)  { $x = $work.Right - $wW }
    if ($y + $wH -gt $work.Bottom) { $y = $work.Bottom - $wH }
    if ($x -lt $work.Left) { $x = $work.Left }
    if ($y -lt $work.Top)  { $y = $work.Top }

    $wp = New-Object Native+WINDOWPLACEMENT
    $wp.length = [Runtime.InteropServices.Marshal]::SizeOf($wp)
    $wp.flags = 0
    $pt = New-Object Native+POINT; $pt.X = -1; $pt.Y = -1        # -1,-1 = let Windows pick min/max positions
    $wp.ptMinPosition = $pt; $wp.ptMaxPosition = $pt
    $rc = New-Object Native+RECT                                   # nested struct fields must be assigned whole
    $rc.Left = $x - $WsOff.X; $rc.Top = $y - $WsOff.Y; $rc.Right = $rc.Left + $wW; $rc.Bottom = $rc.Top + $wH
    $wp.rcNormalPosition = $rc
    # Step 1: place the normal rect on the destination (minimized windows stay minimized).
    $wp.showCmd = if ($cmd -eq $SW_SHOWMINNOACTIVE) { $SW_SHOWMINNOACTIVE } else { $SW_SHOWNOACTIVATE }
    $ok  = [Native]::SetWindowPlacement($w.Handle, [ref]$wp)
    $err = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    # Step 2: maximize on the monitor that now contains the normal rect.
    if ($ok -and $cmd -eq $SW_SHOWMAXIMIZED) {
        $wp.showCmd = $SW_SHOWMAXIMIZED
        $ok  = [Native]::SetWindowPlacement($w.Handle, [ref]$wp)
        $err = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    }
    if (-not $ok) {
        $reason = if ($err -eq 5) { 'access denied: elevated window, run v2 through the scheduled task' } else { "SetWindowPlacement failed, win32 error $err" }
        return @{ Ok = $false; Reason = $reason }
    }
    @{ Ok = $true; X = $x; Y = $y; W = $wW; H = $wH; Cmd = $cmd }
}

function Test-WindowOn {
    param($Win, [string]$DestName, $LiveMons, $WsOff)
    $h = $Win.Handle
    if ([Native]::IsIconic($h)) {
        $wp = New-Object Native+WINDOWPLACEMENT
        $wp.length = [Runtime.InteropServices.Marshal]::SizeOf($wp)
        [void][Native]::GetWindowPlacement($h, [ref]$wp)
        $r = New-Object Native+RECT
        $r.Left = $wp.rcNormalPosition.Left + $WsOff.X; $r.Top = $wp.rcNormalPosition.Top + $WsOff.Y
        $r.Right = $wp.rcNormalPosition.Right + $WsOff.X; $r.Bottom = $wp.rcNormalPosition.Bottom + $WsOff.Y
        $mh = [Native]::MonitorFromRect([ref]$r, 2)
    } else {
        $mh = [Native]::MonitorFromWindow($h, 2)
    }
    $m = $LiveMons | Where-Object { $_.Handle -eq $mh } | Select-Object -First 1
    return ($m -and $m.Name -eq $DestName)
}

function Send-TaskbarNudge {
    # Win11 sometimes leaves the taskbar on the old primary blank after a primary change.
    # WM_SETTINGCHANGE to every taskbar window makes explorer re-query and repaint. Same trick as v1.
    $targets = @()
    $h = [Native]::FindWindow('Shell_TrayWnd', $null)
    if ($h -ne [IntPtr]::Zero) { $targets += $h }
    $s = [IntPtr]::Zero
    do {
        $s = [Native]::FindWindowEx([IntPtr]::Zero, $s, 'Shell_SecondaryTrayWnd', $null)
        if ($s -ne [IntPtr]::Zero) { $targets += $s }
    } while ($s -ne [IntPtr]::Zero)
    foreach ($t in $targets) {
        $res = [IntPtr]::Zero
        [void][Native]::SendMessageTimeout($t, 0x1A, [IntPtr]::Zero, [IntPtr]::Zero, 2, 1000, [ref]$res)   # WM_SETTINGCHANGE, SMTO_ABORTIFHUNG
    }
    Log "taskbar nudge sent to $($targets.Count) taskbar window(s)"
}

# ---------------------------------------------------------------- main
$mutex = New-Object System.Threading.Mutex($false, 'Global\MonitorSwitcherV2')
$haveMutex = $false
try {
    $haveMutex = $mutex.WaitOne(0)
    if (-not $haveMutex) { Log 'another switch is still running; ignoring this press' 'WARN'; exit 2 }

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    Log ('==== switch-v2 start  dryRun={0} to={1} elevated={2} dpi={3} host={4}' -f $DryRun, $(if ($To) { $To } else { 'toggle' }), $isAdmin, $dpiMode, $PSVersionTable.PSVersion)

    if (-not (Test-Path $cfgPath)) { throw "config not found: $cfgPath" }
    $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
    foreach ($k in 'desk', 'couch') { if (-not $cfg.modes.$k -or -not $cfg.modes.$k.monitor) { throw "config: modes.$k.monitor is required" } }
    if (-not $cfg.timing) { $cfg | Add-Member timing ([pscustomobject]@{ primaryTimeoutMs = 8000; settleMs = 750; verifyDelayMs = 300 }) }
    $audioRoles = @(0, 1, 2); if ($cfg.audioRoles) { $audioRoles = @($cfg.audioRoles) }

    if ($ListAudio) {
        $containers = Get-MonitorContainers
        Log 'active playback endpoints:'
        foreach ($ep in (Get-AudioEndpoints)) { Log ('  ' + (Format-AudioEndpoint $ep $containers)); Log ('      id={0}' -f $ep.Id); Log ('      topology={0}' -f $ep.Topology) }
        Log '==== done'; exit 0
    }

    # --- what is connected, and which one is primary right now
    $mmt = @(Get-MmtMonitors)
    foreach ($m in $mmt) {
        Log ('monitor {0,-14} id={1,-8} serial={2,-14} name={3,-16} {4,-11} scale={5,-5} at={6,-14} active={7} primary={8}' -f $m.Name, $m.ShortId, $m.Serial, (Trunc $m.MonitorName 16), $m.Resolution, $m.Scale, $m.Position, $m.Active, $m.Primary)
    }
    $desk  = Resolve-Monitor $cfg.modes.desk.monitor  $mmt
    $couch = Resolve-Monitor $cfg.modes.couch.monitor $mmt
    if (-not $desk)         { throw "desk monitor '$($cfg.modes.desk.monitor)' is not in the monitor list" }
    if (-not $couch)        { throw "couch monitor '$($cfg.modes.couch.monitor)' is not in the monitor list. Is the TV on and connected?" }
    if (-not $desk.Active)  { throw "desk monitor $($desk.ShortId) is present but inactive" }
    if (-not $couch.Active) { throw "couch monitor $($couch.ShortId) is present but inactive. Is the TV on?" }

    $currentPrimary = $mmt | Where-Object Primary | Select-Object -First 1
    if (-not $currentPrimary) { throw 'no monitor reports itself as primary' }

    if ($To) { $mode = $To }
    elseif ($currentPrimary.Name -eq $desk.Name)  { $mode = 'couch' }
    elseif ($currentPrimary.Name -eq $couch.Name) { $mode = 'desk' }
    else {
        $mode = $cfg.fallbackMode; if (-not $mode) { $mode = 'desk' }
        Log "primary is $($currentPrimary.ShortId), which is neither desk nor couch; falling back to '$mode'" 'WARN'
    }
    $target  = if ($mode -eq 'desk') { $desk } else { $couch }
    $modeCfg = $cfg.modes.$mode
    Log ("current primary {0} ({1})  ->  mode '{2}': primary {3} ({4}), default place '{5}'" -f $currentPrimary.ShortId, $currentPrimary.Name, $mode, $target.ShortId, $target.Name, $modeCfg.defaultPlace)

    # --- audio endpoint, resolved by monitor (container ID), never by its editable name
    $audio = $null
    if ($modeCfg.audio) {
        $containers = Get-MonitorContainers
        $audio = Resolve-AudioEndpoint $modeCfg.audio (Get-AudioEndpoints) $containers
        if ($audio) { Log ("audio: '{0}' ({1}) via {2}" -f $audio.Endpoint.Name, $audio.Endpoint.Adapter, $audio.How) }
        else { Log ("audio: nothing matches {0}; run -ListAudio to see what is active" -f ($modeCfg.audio | ConvertTo-Json -Compress)) 'WARN' }
    }

    # --- inventory + plan, taken BEFORE the switch so relative positions are known
    $live = @(Get-LiveMonitors)
    $wins = @(Get-CandidateWindows $live)
    $plan = @(New-Plan $wins $mode $target $mmt $modeCfg)
    Log "$($wins.Count) movable window(s):"
    foreach ($p in $plan) {
        $srcLabel = if ($p.Win.SrcMonitor) { ($mmt | Where-Object { $_.Name -eq $p.Win.SrcMonitor.Name } | Select-Object -First 1).ShortId } else { '?' }
        Log ('  {0,-24} {1,-42} {2,-6} {3,-8} -> {4,-8} {5,-6}{6}' -f (Trunc $p.Win.Process 24), (Trunc $p.Win.Title 42), (Get-WindowState $p.Win), $srcLabel, $p.DestLabel, $p.Place, $(if ($p.Rule) { ' [rule]' } else { '' }))
    }
    if ($DryRun) { Log 'dry run: nothing changed'; Log '==== done'; exit 0 }

    # --- 1. primary, verified
    if ($target.Name -ne $currentPrimary.Name) {
        Invoke-Tool $mmtExe ('/SetPrimary "{0}"' -f $target.Name) | Out-Null
        if (-not (Wait-Primary $target.Name $cfg.timing.primaryTimeoutMs)) {
            throw "primary did not change to $($target.ShortId) within $($cfg.timing.primaryTimeoutMs) ms. Nothing else was touched. (MultiMonitorTool readme: on Win11 24H2, if every action fails, open Display settings and change something, then retry.)"
        }
        Start-Sleep -Milliseconds $cfg.timing.settleMs
    } else {
        Log "primary is already $($target.ShortId); re-applying the window layout only"
    }

    # --- 2. windows, verified + one retry
    $live2 = @(Get-LiveMonitors)
    $wsOff = Get-WorkspaceOffset
    $results = foreach ($p in $plan) { [pscustomobject]@{ Plan = $p; Result = (Move-PlannedWindow $p $live2 $wsOff) } }
    Start-Sleep -Milliseconds $cfg.timing.verifyDelayMs
    $moved = 0; $failed = @()
    foreach ($r in $results) {
        $p = $r.Plan
        if ($r.Result.Ok -and (Test-WindowOn $p.Win $p.DestName $live2 $wsOff)) { $moved++; continue }
        if ($r.Result.Ok) {
            # landed somewhere else: restore, force the rect with SetWindowPos, re-apply state
            $res = $r.Result
            if (-not $p.Win.Min -and $res.Cmd -ne $SW_SHOWMINNOACTIVE) { [void][Native]::ShowWindow($p.Win.Handle, $SW_RESTORE) }
            [void][Native]::SetWindowPos($p.Win.Handle, [IntPtr]::Zero, $res.X, $res.Y, $res.W, $res.H, 0x14)   # SWP_NOZORDER | SWP_NOACTIVATE
            if ($res.Cmd -eq $SW_SHOWMAXIMIZED) { [void][Native]::ShowWindow($p.Win.Handle, $SW_SHOWMAXIMIZED) }
            Start-Sleep -Milliseconds 150
            if (Test-WindowOn $p.Win $p.DestName $live2 $wsOff) { $moved++; Log "  retry ok: $($p.Win.Process) '$(Trunc $p.Win.Title 40)'"; continue }
            $failed += [pscustomobject]@{ Plan = $p; Reason = 'moved but did not land on the destination (app repositions itself?)' }
        } else {
            $failed += [pscustomobject]@{ Plan = $p; Reason = $r.Result.Reason }
        }
    }
    Log "windows: $moved moved, $($failed.Count) failed"
    foreach ($f in $failed) { Log ("  FAILED {0} '{1}' -> {2}: {3}" -f $f.Plan.Win.Process, (Trunc $f.Plan.Win.Title 40), $f.Plan.DestLabel, $f.Reason) 'WARN' }

    # --- 3. taskbar, 4. audio (only now, so audio never disagrees with the display)
    if ($cfg.taskbarNudge) { Send-TaskbarNudge }
    $audioOk = $null
    if ($audio) { $audioOk = Set-DefaultAudio $audio.Endpoint $audioRoles }

    $summary = "Now on $mode ($($target.ShortId)). $moved windows moved"
    if ($failed.Count) { $summary += ", $($failed.Count) failed (see log)" }
    if ($audio) { $summary += ". Audio: $($audio.Endpoint.Name)" + $(if (-not $audioOk) { ' (NOT confirmed)' } else { '' }) }
    elseif ($modeCfg.audio) { $summary += '. Audio: NOT switched (no match, see log)' }
    Log $summary
    Notify $summary
    Log '==== done'
    exit 0
}
catch {
    Log "FAILED: $($_.Exception.Message)" 'ERROR'
    if ($_.ScriptStackTrace) { Log $_.ScriptStackTrace 'ERROR' }
    Notify "Monitor switch FAILED: $($_.Exception.Message)"
    exit 1
}
finally {
    if ($haveMutex) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
