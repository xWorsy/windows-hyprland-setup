# Runs right after the Start button is pressed: Windows re-shows the taskbar when Start opens,
# so keep hiding it for a few seconds.
Add-Type @"
using System; using System.Runtime.InteropServices;
public class TBR {
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string c, string w);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr a, string c, string w);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
}
"@
for ($i = 0; $i -lt 40; $i++) {
  $tray = [TBR]::FindWindow('Shell_TrayWnd', $null)
  if ($tray -ne [IntPtr]::Zero -and [TBR]::IsWindowVisible($tray)) { [TBR]::ShowWindow($tray, 0) | Out-Null }
  $h = [IntPtr]::Zero
  while (($h = [TBR]::FindWindowEx([IntPtr]::Zero, $h, 'Shell_SecondaryTrayWnd', $null)) -ne [IntPtr]::Zero) {
    if ([TBR]::IsWindowVisible($h)) { [TBR]::ShowWindow($h, 0) | Out-Null }
  }
  Start-Sleep -Milliseconds 100
}
