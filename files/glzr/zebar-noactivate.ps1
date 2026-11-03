# Makes the Zebar bar window non-activating, so clicking its buttons does not steal focus
# (needed so a second click on the Start button closes Start instead of reopening it).
# Waits up to 60 s for the Zebar window to exist.
Add-Type @"
using System; using System.Runtime.InteropServices; using System.Text; using System.Collections.Generic;
public class ZN {
  public delegate bool EP(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(EP e, IntPtr l);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint p);
  [DllImport("user32.dll")] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", EntryPoint="GetWindowLongPtrW")] static extern IntPtr GetLong(IntPtr h, int i);
  [DllImport("user32.dll", EntryPoint="SetWindowLongPtrW")] static extern IntPtr SetLong(IntPtr h, int i, IntPtr v);
  [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);
  const int GWL_EXSTYLE = -20; const long WS_EX_NOACTIVATE = 0x08000000L;
  public static int Apply(uint[] pids) {
    int n = 0;
    EnumWindows((h, x) => {
      uint p; GetWindowThreadProcessId(h, out p);
      if (Array.IndexOf(pids, p) < 0 || !IsWindowVisible(h)) return true;
      var sb = new StringBuilder(80); GetClassName(h, sb, 80);
      if (sb.ToString() != "Tauri Window") return true;
      long ex = (long)GetLong(h, GWL_EXSTYLE);
      if ((ex & WS_EX_NOACTIVATE) == 0) {
        SetLong(h, GWL_EXSTYLE, (IntPtr)(ex | WS_EX_NOACTIVATE));
        SetWindowPos(h, IntPtr.Zero, 0, 0, 0, 0, 0x0001 | 0x0002 | 0x0004 | 0x0010 | 0x0020); // NOSIZE|NOMOVE|NOZORDER|NOACTIVATE|FRAMECHANGED
      }
      n++; return true;
    }, IntPtr.Zero);
    return n;
  }
}
"@
for ($i = 0; $i -lt 30; $i++) {
  $ids = [uint32[]]@(Get-Process zebar -ErrorAction SilentlyContinue | ForEach-Object Id)
  if ($ids.Count -gt 0 -and [ZN]::Apply($ids) -gt 0) { "applied"; break }
  Start-Sleep 2
}
