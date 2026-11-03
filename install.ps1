<#
  Установщик «Windows как Hyprland»: GlazeWM (окна плитками и хоткеи) + панель Zebar + оформление Windows Terminal.
  Запуск:  powershell -ExecutionPolicy Bypass -File .\install.ps1
  Ничего не удаляется: старые настройки сохраняются копиями. Откат: uninstall.ps1
#>
[CmdletBinding()]
param(
  [string]$HomeDir = $env:USERPROFILE,  # куда ставить (для проверки можно указать другую папку)
  [switch]$NoWinget,                    # не ставить программы через winget
  [switch]$NoTerminal,                  # не трогать настройки Windows Terminal
  [string]$TerminalSettings,            # путь к settings.json терминала (для проверки; обычно находится сам)
  [switch]$NoStart,                     # не запускать GlazeWM в конце
  [switch]$Yes,                         # на все вопросы отвечать значением по умолчанию
  [bool]$HideTaskbar = $false,          # спрятать панель задач (обходной способ, по умолчанию нет)
  [bool]$Autostart = $true              # запускать GlazeWM при входе в Windows
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$src = Join-Path $root 'files\glzr'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$realRun = ($HomeDir -eq $env:USERPROFILE)

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

if (-not (Test-Path $src)) { throw "Не найдена папка $src. Запускайте install.ps1 из распакованного репозитория." }
if ($PSVersionTable.PSVersion.Major -lt 5) { throw 'Нужен Windows PowerShell 5.1 или новее.' }

Write-Host ""
Write-Host "Windows как Hyprland: установка" -ForegroundColor Cyan
Say "Папка настроек: $HomeDir\.glzr"
if (-not $realRun) { Warn "Тестовый запуск в другую папку: реестр и Windows Terminal не трогаются." }

# вопросы (если не указаны параметрами и не включён -Yes)
if (-not $PSBoundParameters.ContainsKey('Autostart') -and $realRun) {
  $Autostart = Ask 'Запускать GlazeWM при входе в Windows?' $true
}
if (-not $PSBoundParameters.ContainsKey('HideTaskbar') -and $realRun) {
  $HideTaskbar = Ask 'Спрятать панель задач Windows? (обходной способ, может глючить; потом убирается uninstall.ps1)' $false
}

# 1. Программы
if (-not $NoWinget) {
  Step 'Ставлю GlazeWM (вместе с ним встанет панель Zebar)'
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw 'Не найден winget. Обновите «Установщик приложений» в Microsoft Store и запустите снова.' }
  $installed = winget list --id glzr-io.glazewm --disable-interactivity 2>$null | Select-String 'glzr-io.glazewm'
  if ($installed) { Say 'GlazeWM уже установлен, пропускаю.' }
  else {
    Say 'Может появиться окно «Разрешить внесение изменений» (UAC): нажмите «Да».'
    winget install --id glzr-io.glazewm --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) { throw "winget вернул ошибку $LASTEXITCODE. Установка остановлена, ваши настройки не тронуты." }
  }
}

# 2. Настройки GlazeWM и Zebar
Step 'Копирую настройки'
$glzr = Join-Path $HomeDir '.glzr'
New-Item -ItemType Directory -Force -Path $glzr | Out-Null
if (Test-Path (Join-Path $glzr 'glazewm\config.yaml')) {
  $bk = "$glzr.backup-$stamp"
  Copy-Item $glzr $bk -Recurse
  Say "Старые настройки сохранены: $bk"
}

# GlazeWM плохо разбирает пробелы в пути команды, поэтому берём короткий (8.3) путь, если нужно
function Get-SafePath($p) {
  if ($p -notmatch '\s' -and $p -cmatch '^[\x20-\x7E]+$') { return $p }
  try {
    $short = (New-Object -ComObject Scripting.FileSystemObject).GetFolder($p).ShortPath
    if ($short -notmatch '\s' -and $short -cmatch '^[\x20-\x7E]+$') { return $short }
  } catch {}
  Warn "В пути '$p' есть пробелы или не латинские буквы, и короткий путь получить не удалось. Кнопка «Пуск» на панели может не работать."
  return $p
}
$glzrSafe = Get-SafePath $glzr
$fwd = $glzrSafe -replace '\\', '/'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$textExt = '.yaml', '.json', '.html', '.css', '.ps1', '.vbs'

Get-ChildItem $src -Recurse -File | ForEach-Object {
  $rel = $_.FullName.Substring($src.Length).TrimStart('\')
  $dest = Join-Path $glzr $rel
  New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
  if ($textExt -contains $_.Extension.ToLower()) {
    $t = [IO.File]::ReadAllText($_.FullName, $utf8)
    $t = $t.Replace('{{GLZR_FWD}}', $fwd).Replace('{{GLZR_WIN}}', $glzr)
    [IO.File]::WriteAllText($dest, $t, $utf8)
  } else {
    Copy-Item $_.FullName $dest -Force
  }
}
Say "Скопировано в $glzr"

# 3. Windows Terminal
if (-not $NoTerminal -and ($realRun -or $TerminalSettings)) {
  Step 'Оформляю Windows Terminal (прозрачность, цвета, шрифт)'
  $style = Get-Content (Join-Path $root 'files\terminal\style.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  $targets = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
  ) | Where-Object { Test-Path $_ }
  if ($TerminalSettings) { $targets = @($TerminalSettings) }
  if (-not $targets) { Warn 'Windows Terminal не найден, пропускаю.' }
  foreach ($p in $targets) {
    try {
      $bk = $p -replace 'settings\.json$', 'settings.backup-before-night-arch.json'
      if (-not (Test-Path $bk)) { Copy-Item $p $bk }
      $s = Get-Content $p -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($s.profiles -is [array]) { Warn "Старый формат настроек в $p, пропускаю."; continue }
      if (-not $s.profiles) { $s | Add-Member -NotePropertyName profiles -NotePropertyValue ([pscustomobject]@{}) -Force }
      if (-not $s.profiles.defaults) { $s.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{}) -Force }
      foreach ($prop in $style.defaults.PSObject.Properties) {
        $s.profiles.defaults | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
      }
      $s | Add-Member -NotePropertyName 'compatibility.enableUnfocusedAcrylic' -NotePropertyValue $style.'compatibility.enableUnfocusedAcrylic' -Force
      $schemes = @(); if ($s.schemes) { $schemes = @($s.schemes | Where-Object { $_.name -ne $style.scheme.name }) }
      $s | Add-Member -NotePropertyName schemes -NotePropertyValue @($schemes + $style.scheme) -Force
      $themes = @(); if ($s.themes) { $themes = @($s.themes | Where-Object { $_.name -ne $style.windowTheme.name }) }
      $s | Add-Member -NotePropertyName themes -NotePropertyValue @($themes + $style.windowTheme) -Force
      $s | Add-Member -NotePropertyName theme -NotePropertyValue $style.theme -Force
      [IO.File]::WriteAllText($p, ($s | ConvertTo-Json -Depth 20), $utf8)
      Say "Готово: $p (копия старых настроек: $bk)"
    } catch {
      Warn "Не смог изменить $p ($($_.Exception.Message)). Файл не тронут. Скорее всего, в нём есть комментарии //."
    }
  }
}

# 4. Автозапуск и панель задач
if ($realRun) {
  $run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
  $exe = Join-Path $env:ProgramFiles 'glzr.io\GlazeWM\glazewm.exe'
  if ($Autostart) {
    Step 'Включаю запуск GlazeWM при входе в Windows'
    if (Test-Path $exe) { Set-ItemProperty -Path $run -Name 'GlazeWM' -Value ('"' + $exe + '"'); Say 'Готово.' }
    else { Warn "Не найден $exe, автозапуск не включён." }
  }
  if ($HideTaskbar) {
    Step 'Прячу панель задач'
    Set-ItemProperty -Path $run -Name 'TaskbarHide' -Value ('wscript.exe "' + (Join-Path $glzr 'taskbar-startup.vbs') + '"')
    Start-Process wscript.exe -ArgumentList ('"' + (Join-Path $glzr 'taskbar-startup.vbs') + '"')
    Say 'Готово. Вернуть панель: uninstall.ps1'
  }
}

# 5. Запуск
if ($realRun -and -not $NoStart) {
  $exe = Join-Path $env:ProgramFiles 'glzr.io\GlazeWM\glazewm.exe'
  if ((Test-Path $exe) -and -not (Get-Process glazewm -ErrorAction SilentlyContinue)) {
    Step 'Запускаю GlazeWM'
    Say 'Окна сразу перестроятся плитками, это нормально. Выйти: Alt+Shift+E.'
    Start-Process $exe
  } elseif (Get-Process glazewm -ErrorAction SilentlyContinue) {
    Say 'GlazeWM уже запущен. Чтобы подхватить новые настройки, нажмите Alt+Shift+R.'
  }
}

Write-Host ""
Write-Host "Готово." -ForegroundColor Cyan
Write-Host "  Главные хоткеи: Alt+Enter терминал, Alt+h/j/k/l между окнами, Alt+1..9 рабочие столы, Alt+Q закрыть окно."
Write-Host "  Полный список и откат: README.md"
