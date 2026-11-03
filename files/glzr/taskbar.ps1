# Hide or show the Windows taskbar window. Usage: powershell -File taskbar.ps1 hide|show
param([Parameter(Mandatory)][ValidateSet('hide','show')][string]$Mode)
Add-Type @"
using System; using System.Runtime.InteropServices;
public class TBW {
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string c, string w);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr a, string c, string w);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
}
"@
$cmd = if ($Mode -eq 'hide') { 0 } else { 5 }
$tray = [TBW]::FindWindow('Shell_TrayWnd', $null)
[TBW]::ShowWindow($tray, $cmd) | Out-Null
$h = [IntPtr]::Zero
while (($h = [TBW]::FindWindowEx([IntPtr]::Zero, $h, 'Shell_SecondaryTrayWnd', $null)) -ne [IntPtr]::Zero) {
  [TBW]::ShowWindow($h, $cmd) | Out-Null
}
"taskbar visible: $([TBW]::IsWindowVisible($tray))"
