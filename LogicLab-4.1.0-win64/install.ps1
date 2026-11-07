# LogicLab 免管理员安装脚本（Windows PowerShell 5.1 / PowerShell 7）
#
# 安装到 %LOCALAPPDATA%\LogicLab\<version>，创建开始菜单与桌面快捷方式，
# 注册 HKCU 文件关联（.logiclab）与 HKCU 卸载项；全程不需要管理员权限。
#
# 用法：
#   powershell -NoProfile -ExecutionPolicy Bypass -File installer/install.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File installer/install.ps1 -DryRun
#   powershell -NoProfile -ExecutionPolicy Bypass -File installer/install.ps1 -NoShortcuts
#   powershell -NoProfile -ExecutionPolicy Bypass -File installer/install.ps1 -Source dist\LogicLab
[CmdletBinding()]
param(
    [string]$Source = "",
    [switch]$DryRun,
    [switch]$NoShortcuts,
    [string]$Version = ""
)

$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } catch { }

$AppName = "LogicLab"
$ProgId = "LogicLab.Circuit"
$RepoRoot = Split-Path -Parent $PSScriptRoot

function Write-Ok([string]$Text) { Write-Host "[OK] $Text" -ForegroundColor Green }
function Write-Warn([string]$Text) { Write-Host "[警告] $Text" -ForegroundColor Yellow }
function Write-Fail([string]$Text) { Write-Host "[失败] $Text" -ForegroundColor Red; exit 1 }
function Write-Act([string]$Text) {
    if ($DryRun) { Write-Host "[DryRun] $Text" -ForegroundColor Cyan }
    else { Write-Host "[执行] $Text" }
}

# ---------------------------------------------------------------- 版本号
if (-not $Version) {
    $verFile = Join-Path $RepoRoot "src\logiclab\version.py"
    if (Test-Path -LiteralPath $verFile) {
        $text = Get-Content -LiteralPath $verFile -Raw -Encoding UTF8
        $m = [regex]::Match($text, '__version__\s*=\s*"([^"]+)"')
        if ($m.Success) { $Version = $m.Groups[1].Value }
    }
}
if (-not $Version) { Write-Fail "无法确定版本号，请用 -Version 指定（例如 -Version 4.1.0）" }

# ---------------------------------------------------------------- 路径
if (-not $Source) { $Source = Join-Path $RepoRoot "dist\LogicLab" }
elseif (-not [System.IO.Path]::IsPathRooted($Source)) { $Source = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $Source)) }

if (-not $env:LOCALAPPDATA) { Write-Fail "环境变量 LOCALAPPDATA 不存在，无法确定安装目录" }
$InstallRoot = Join-Path $env:LOCALAPPDATA "LogicLab"
$InstallDir = Join-Path $InstallRoot $Version
$ExePath = Join-Path $InstallDir ($AppName + ".exe")
$SourceExe = Join-Path $Source ($AppName + ".exe")

Write-Host "LogicLab $Version 免管理员安装" -ForegroundColor Cyan
Write-Host "  安装目录: $InstallDir"
Write-Host "  来源目录: $Source"
if ($DryRun) { Write-Host "  模式: DryRun（只打印将执行的动作，不写任何文件或注册表）" -ForegroundColor Yellow }

# ---------------------------------------------------------------- 校验来源
if (-not (Test-Path -LiteralPath $SourceExe)) {
    if ($DryRun) {
        Write-Warn "来源目录中未找到 $AppName.exe（DryRun 继续，仅演示动作）"
    } else {
        Write-Fail "未找到 $SourceExe，请先运行 tools/build_release.ps1 或 PyInstaller 打包"
    }
}

# ---------------------------------------------------------------- 1. 复制文件
Write-Host ""
Write-Host "=== 1/4 复制程序文件 ===" -ForegroundColor Cyan
if (Test-Path -LiteralPath $Source) {
    $files = @(Get-ChildItem -LiteralPath $Source -Recurse -File -Force -ErrorAction SilentlyContinue)
    if ($DryRun) {
        Write-Act "复制 $($files.Count) 个文件: $Source -> $InstallDir"
    } else {
        $copied = 0
        $skipped = 0
        foreach ($file in $files) {
            $rel = $file.FullName.Substring($Source.Length).TrimStart('\')
            $dest = Join-Path $InstallDir $rel
            $destDir = Split-Path -Parent $dest
            if (Test-Path -LiteralPath $dest) {
                $existing = Get-Item -LiteralPath $dest -Force
                if ($existing.Length -eq $file.Length) { $skipped++; continue }
            }
            if (-not (Test-Path -LiteralPath $destDir)) { New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
            Copy-Item -LiteralPath $file.FullName -Destination $dest -Force
            $copied++
        }
        Write-Ok "已复制 $copied 个文件（跳过未变化的 $skipped 个）：$InstallDir"
    }
} elseif (-not $DryRun) {
    Write-Fail "来源目录不存在: $Source"
}

# 安装脚本随程序一起落到安装目录，供卸载项调用
$instScript = Join-Path $PSScriptRoot "uninstall.ps1"
$instTarget = Join-Path $InstallDir "uninstall.ps1"
if (Test-Path -LiteralPath $instScript) {
    if (-not (Test-Path -LiteralPath $instTarget)) {
        if ($DryRun) { Write-Act "复制 uninstall.ps1 -> $instTarget" }
        elseif (Test-Path -LiteralPath $InstallDir) { Copy-Item -LiteralPath $instScript -Destination $instTarget -Force }
    }
}

# ---------------------------------------------------------------- 2. 快捷方式
Write-Host ""
Write-Host "=== 2/4 创建快捷方式 ===" -ForegroundColor Cyan
function New-Shortcut([string]$LinkPath, [string]$TargetPath) {
    if ($DryRun) { Write-Act "创建快捷方式 $LinkPath -> $TargetPath"; return }
    $linkDir = Split-Path -Parent $LinkPath
    if (-not (Test-Path -LiteralPath $linkDir)) { New-Item -ItemType Directory -Force -Path $linkDir | Out-Null }
    $shell = New-Object -ComObject WScript.Shell
    $sc = $shell.CreateShortcut($LinkPath)
    $sc.TargetPath = $TargetPath
    $sc.WorkingDirectory = Split-Path -Parent $TargetPath
    $sc.IconLocation = $TargetPath + ",0"
    $sc.Description = "LogicLab 可视化数字逻辑仿真与教学平台"
    $sc.Save()
    Write-Ok "快捷方式: $LinkPath"
}

if ($NoShortcuts) {
    Write-Host "跳过快捷方式（-NoShortcuts）" -ForegroundColor Yellow
} else {
    $programs = [Environment]::GetFolderPath("Programs")
    $desktop = [Environment]::GetFolderPath("Desktop")
    if (-not $programs) { $programs = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs" }
    if (-not $desktop) { $desktop = Join-Path $env:USERPROFILE "Desktop" }
    New-Shortcut (Join-Path $programs ($AppName + ".lnk")) $ExePath
    New-Shortcut (Join-Path $desktop ($AppName + ".lnk")) $ExePath
}

# ---------------------------------------------------------------- 3. 注册表
Write-Host ""
Write-Host "=== 3/4 注册文件关联与卸载项（HKCU） ===" -ForegroundColor Cyan
function New-RegKey([string]$Path) {
    if ($DryRun) { Write-Act "新建注册表键 $Path"; return }
    New-Item -Path $Path -Force | Out-Null
}
function Set-RegDefault([string]$Path, [string]$Value) {
    if ($DryRun) { Write-Act "设置 $Path (默认) = $Value"; return }
    Set-Item -Path $Path -Value $Value -Force
}
function Set-RegValue([string]$Path, [string]$Name, [string]$Value, [string]$Kind = "String") {
    if ($DryRun) { Write-Act "设置 $Path 的 $Name = $Value"; return }
    if ($Kind -eq "DWord") {
        New-ItemProperty -Path $Path -Name $Name -Value ([int]$Value) -PropertyType DWord -Force | Out-Null
    } else {
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType String -Force | Out-Null
    }
}

$ClassesRoot = "HKCU:\Software\Classes"
$ExtKey = "$ClassesRoot\.logiclab"
$ProgKey = "$ClassesRoot\$ProgId"
$OpenWithKey = "$ExtKey\OpenWithProgids"
$IconKey = "$ProgKey\DefaultIcon"
$CommandKey = "$ProgKey\shell\open\command"
$UninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\LogicLab"

New-RegKey $ExtKey
Set-RegDefault $ExtKey $ProgId
New-RegKey $OpenWithKey
Set-RegValue $OpenWithKey $ProgId ""
New-RegKey $ProgKey
Set-RegDefault $ProgKey "LogicLab 电路文件"
New-RegKey $IconKey
Set-RegDefault $IconKey ($ExePath + ",0")
New-RegKey $CommandKey
Set-RegDefault $CommandKey ('"' + $ExePath + '" "%1"')

New-RegKey $UninstallKey
Set-RegValue $UninstallKey "DisplayName" "LogicLab 可视化数字逻辑仿真与教学平台"
Set-RegValue $UninstallKey "DisplayVersion" $Version
Set-RegValue $UninstallKey "DisplayIcon" $ExePath
Set-RegValue $UninstallKey "InstallLocation" $InstallDir
Set-RegValue $UninstallKey "Publisher" "LogicLab Team"
Set-RegValue $UninstallKey "DisplayNameShort" "LogicLab"
Set-RegValue $UninstallKey "EstimatedSize" "120000" "DWord"
Set-RegValue $UninstallKey "NoModify" "1" "DWord"
Set-RegValue $UninstallKey "NoRepair" "1" "DWord"
$uninstallCmd = 'powershell -NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $InstallDir "uninstall.ps1") + '" -Version ' + $Version
Set-RegValue $UninstallKey "UninstallString" $uninstallCmd

# ---------------------------------------------------------------- 4. 汇总
Write-Host ""
Write-Host "=== 4/4 完成 ===" -ForegroundColor Cyan
if ($DryRun) {
    Write-Host "DryRun 结束：未写入任何文件或注册表。" -ForegroundColor Yellow
    exit 0
}
Write-Ok "LogicLab $Version 已安装到 $InstallDir"
Write-Host "  启动: $ExePath"
Write-Host "  卸载: $uninstallCmd"
Write-Host "  卸载项: $UninstallKey"
exit 0
