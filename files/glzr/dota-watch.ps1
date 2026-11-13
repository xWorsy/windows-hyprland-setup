# While the game window (Dota 2 by default) is the focused window, turns on the GlazeWM
# binding mode 'dota' (all your hotkeys except Alt+B, Alt+E and Alt+F). When you switch to
# another window (Alt+1/2/... works inside the mode), turns the mode off again.
# The mode itself is defined in glazewm\config.yaml (binding_modes -> 'dota').
param(
  [string]$ProcessName = 'dota2',   # process name without .exe
  [string]$ModeName = 'dota',
  [double]$IntervalSec = 0.4
)

# Only one copy at a time.
$mutex = New-Object System.Threading.Mutex($false, 'Local\GlazeWmGameWatcher')
if (-not $mutex.WaitOne(0)) { exit }

Add-Type @"
using System; using System.Runtime.InteropServices;
public class FG {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
}
"@

$glaze = Join-Path $env:ProgramFiles 'glzr.io\GlazeWM\cli\glazewm.exe'
$log = Join-Path $PSScriptRoot 'dota-watch.log'

function Write-Log($msg) {
  try {
    if ((Test-Path $log) -and (Get-Item $log).Length -gt 100KB) { Clear-Content $log }
    Add-Content -Path $log -Value ("{0:yyyy-MM-dd HH:mm:ss} {1}" -f (Get-Date), $msg)
  } catch {}
}

function Get-ForegroundProcessName {
  $h = [FG]::GetForegroundWindow()
  if ($h -eq [IntPtr]::Zero) { return '' }
  $pid2 = 0
  [void][FG]::GetWindowThreadProcessId($h, [ref]$pid2)
  try { return (Get-Process -Id $pid2 -ErrorAction Stop).ProcessName } catch { return '' }
}

# Note: 'glazewm query binding-modes' fails while any mode is active (a GlazeWM quirk),
# so this script does not read the mode back, it just remembers what it switched on.
function Set-Mode([bool]$on) {
  $cmd = if ($on) { 'wm-enable-binding-mode' } else { 'wm-disable-binding-mode' }
  & $glaze command $cmd --name $ModeName 2>$null | Out-Null
}

Write-Log "watcher started for '$ProcessName', mode '$ModeName'"
$modeOn = $false
try {
  while ($true) {
    $onGame = ((Get-ForegroundProcessName) -eq $ProcessName)
    if ($onGame -and -not $modeOn) {
      Set-Mode $true; $modeOn = $true; Write-Log "$ProcessName in focus -> mode '$ModeName' ON"
    }
    elseif (-not $onGame -and $modeOn) {
      Set-Mode $false; $modeOn = $false; Write-Log "$ProcessName not in focus -> mode '$ModeName' OFF"
    }
    Start-Sleep -Milliseconds ([int]($IntervalSec * 1000))
  }
}
finally {
  # On exit never leave the restricted mode switched on.
  if ($modeOn) { Set-Mode $false; Write-Log 'watcher stopped, mode OFF' }
}
