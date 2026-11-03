# Runs at logon and keeps running: hides the taskbar every time Windows shows it again
# (Win key, Start button, flashing apps, Explorer restart...). Only one copy may run.
$mutex = New-Object System.Threading.Mutex($false, 'Local\TaskbarHideWatcher')
if (-not $mutex.WaitOne(0)) { exit }
Add-Type @"
using System; using System.Runtime.InteropServices;
public class TBS {
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string c, string w);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr a, string c, string w);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [StructLayout(LayoutKind.Sequential)] public struct PTS { public uint Version; public uint ControlMask; public uint StateMask; }
  [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
  [DllImport("kernel32.dll")] static extern bool SetProcessInformation(IntPtr h, int cls, ref PTS info, int size);
  // Opt out of Windows 11 power throttling (EcoQoS) and timer coalescing for this hidden process.
  public static bool NoThrottle() {
    var s = new PTS { Version = 1, ControlMask = 0x1 | 0x4, StateMask = 0 };
    return SetProcessInformation(GetCurrentProcess(), 4, ref s, Marshal.SizeOf(typeof(PTS)));
  }
}
"@
$null = [TBS]::NoThrottle()
$log = Join-Path $PSScriptRoot 'taskbar-watcher.log'
function Write-Log($msg) {
  try {
    if ((Test-Path $log) -and (Get-Item $log).Length -gt 100KB) { Clear-Content $log }
    Add-Content -Path $log -Value ("{0:yyyy-MM-dd HH:mm:ss.fff} {1}" -f (Get-Date), $msg)
  } catch {}
}
Write-Log 'watcher started'
function Hide-Taskbar {
  $tray = [TBS]::FindWindow('Shell_TrayWnd', $null)
  if ($tray -ne [IntPtr]::Zero -and [TBS]::IsWindowVisible($tray)) { [TBS]::ShowWindow($tray, 0) | Out-Null; Write-Log 'taskbar was visible -> hidden' }
  $h = [IntPtr]::Zero
  while (($h = [TBS]::FindWindowEx([IntPtr]::Zero, $h, 'Shell_SecondaryTrayWnd', $null)) -ne [IntPtr]::Zero) {
    if ([TBS]::IsWindowVisible($h)) { [TBS]::ShowWindow($h, 0) | Out-Null }
  }
}

# Wait up to 90 s for Explorer to create the taskbar.
for ($i = 0; $i -lt 45; $i++) {
  if ([TBS]::FindWindow('Shell_TrayWnd', $null) -ne [IntPtr]::Zero) { break }
  Start-Sleep 2
}
Start-Sleep 5
# Hide, and keep checking for as long as the session lasts.
$last = Get-Date
while ($true) {
  Hide-Taskbar
  Start-Sleep -Milliseconds 150
  $now = Get-Date
  $gap = ($now - $last).TotalSeconds
  if ($gap -gt 1.5) { Write-Log ("slow tick: {0:N1} s between checks (throttled or sleep)" -f $gap) }
  $last = $now
}
