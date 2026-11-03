<#
  Откат установки «Windows как Hyprland»: возвращает панель задач, убирает автозапуск, возвращает старые
  настройки и (по желанию) удаляет программы GlazeWM и Zebar.
  Запуск:  powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
  Перед каждым серьёзным шагом спрашивает. Свои файлы без вопроса не удаляет.
#>
[CmdletBinding()]
param(
  [string]$HomeDir = $env:USERPROFILE,
  [switch]$Yes   # на все вопросы отвечать значением по умолчанию
)

$ErrorActionPreference = 'Continue'
$realRun = ($HomeDir -eq $env:USERPROFILE)
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$glzr = Join-Path $HomeDir '.glzr'

function Say($m)  { Write-Host "  $m" }
function Step($m) { Write-Host ""; Write-Host "==> $m" -ForegroundColor Green }
function Warn($m) { Write-Host "  ! $m" -ForegroundColor Yellow }
function Ask($q, [bool]$default) {
  if ($Yes) { return $default }
  $hint = if ($default) { 'Д/н' } else { 'д/Н' }
  $a = Read-Host "  $q [$hint]"
  if ([string]::IsNullOrWhiteSpace($a)) { return $default }
  return ($a.Trim().ToLower() -in 'д', 'y', 'да', 'yes')
}

Write-Host ""
Write-Host "Windows как Hyprland: удаление" -ForegroundColor Cyan
if (-not $realRun) { Warn 'Тестовый запуск в другую папку: реестр, процессы и Windows Terminal не трогаются.' }

# 1. Остановить программы и сторожа панели задач
if ($realRun) {
  Step 'Останавливаю GlazeWM, Zebar и сторожа панели задач'
  Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'taskbar-startup\.ps1|taskbar-rehide\.ps1|zebar-noactivate\.ps1' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
  # GlazeWM сам закроет Zebar по своим настройкам, но на всякий случай останавливаем оба
  Get-Process glazewm, glazewm-watcher, zebar -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  Say 'Готово.'

  # 2. Панель задач и автозапуск
  Step 'Возвращаю панель задач и убираю автозапуск'
  $tb = Join-Path $glzr 'taskbar.ps1'
  if (Test-Path $tb) { & powershell -NoProfile -ExecutionPolicy Bypass -File $tb show | Out-Null; Say 'Панель задач показана.' }
  $run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
  foreach ($n in 'TaskbarHide', 'GlazeWM') {
    if (Get-ItemProperty -Path $run -Name $n -ErrorAction SilentlyContinue) {
      Remove-ItemProperty -Path $run -Name $n
      Say "Убрана запись автозапуска: $n"
    }
  }
}

# 3. Настройки GlazeWM / Zebar: свои уходят в сторону (не удаляются), старые возвращаются
Step 'Возвращаю прежние настройки GlazeWM и Zebar'
if (Test-Path $glzr) {
  $removed = "$glzr.removed-$stamp"
  Rename-Item $glzr $removed
  Say "Мои настройки переименованы в $removed (можно удалить вручную)."
  $backups = Get-ChildItem (Split-Path $glzr) -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like ((Split-Path $glzr -Leaf) + '.backup-*') } | Sort-Object Name
  if ($backups) {
    $last = $backups | Select-Object -Last 1
    Copy-Item $last.FullName $glzr -Recurse
    Say "Возвращены прежние настройки из $($last.FullName)"
  } else {
    Say 'Старых настроек не было, папка .glzr остаётся пустой (программы создадут стандартные).'
  }
} else { Say 'Папки .glzr нет, пропускаю.' }

# 4. Windows Terminal
if ($realRun) {
  Step 'Возвращаю настройки Windows Terminal'
  $targets = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
  ) | Where-Object { Test-Path $_ }
  foreach ($p in $targets) {
    $bk = $p -replace 'settings\.json$', 'settings.backup-before-night-arch.json'
    if (Test-Path $bk) {
      if (Ask "Вернуть прежние настройки терминала из копии ($bk)? Все изменения в терминале после установки пропадут." $true) {
        Copy-Item $p ($p -replace 'settings\.json$', "settings.before-restore-$stamp.json")
        Copy-Item $bk $p -Force
        Say "Возвращено: $p"
      }
    } else { Say "Копии для $p нет, оставляю как есть." }
  }
}

# 5. Программы
if ($realRun) {
  Step 'Программы GlazeWM и Zebar'
  if (Ask 'Удалить программы GlazeWM и Zebar с компьютера?' $false) {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
      winget uninstall --id glzr-io.glazewm --disable-interactivity
      if (winget list zebar --disable-interactivity 2>$null | Select-String -Pattern 'Zebar') {
        winget uninstall --name Zebar --disable-interactivity
      }
      Say 'Готово.'
    } else { Warn 'winget не найден. Удалите GlazeWM и Zebar в «Параметры → Приложения».' }
  } else { Say 'Программы оставлены. Удалить позже: winget uninstall --id glzr-io.glazewm' }
}

# 6. Остатки
Step 'Оставшиеся копии'
$leaf = Split-Path $glzr -Leaf
$left = Get-ChildItem (Split-Path $glzr) -Directory -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -like "$leaf.backup-*" -or $_.Name -like "$leaf.removed-*" }
if ($left) {
  $left | ForEach-Object { Say $_.FullName }
  if (Ask 'Удалить эти папки с копиями окончательно? (после этого вернуть настройки из них нельзя)' $false) {
    $left | ForEach-Object { Remove-Item $_.FullName -Recurse -Force }
    Say 'Удалено.'
  } else { Say 'Оставлены. Если всё в порядке, удалите их вручную.' }
} else { Say 'Остатков нет.' }

Write-Host ""
Write-Host 'Готово. Чтобы окна вернулись в обычное состояние, при необходимости перезайдите в Windows.' -ForegroundColor Cyan
