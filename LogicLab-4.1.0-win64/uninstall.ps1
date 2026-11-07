# LogicLab 卸载脚本（Windows PowerShell 5.1 / PowerShell 7）
#
# 反向清理：快捷方式、HKCU 文件关联、HKCU 卸载项、安装目录。
# 默认同时删除用户数据（%APPDATA%\LogicLab 的日志与配置）；-KeepUserData 保留。
#
# 用法：
#   powershell -NoProfile -ExecutionPolicy Bypass -File installer/uninstall.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File installer/uninstall.ps1 -KeepUserData
#   powershell -NoProfile -ExecutionPolicy Bypass -File installer/uninstall.ps1 -DryRun
[CmdletBinding()]
param(
    [switch]$KeepUserData,
    [switch]$DryRun,
    [string]$Version = "",
    [switch]$Remove
)

$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } catch { }

$AppName = "LogicLab"
$ProgId = "LogicLab.Circuit"

function Write-Ok([string]$Text) { Write-Host "[OK] $Text" -ForegroundColor Green }
function Write-Warn([string]$Text) { Write-Host "[警告] $Text" -ForegroundColor Yellow }
function Write-Act([string]$Text) {
    if ($DryRun) { Write-Host "[DryRun] $Text" -ForegroundColor Cyan }
    else { Write-Host "[执行] $Text" }
}

$InstallRoot = Join-Path $env:LOCALAPPDATA "LogicLab"

# ---------------------------------------------------------------- 定位安装目录
$InstallDir = $null
if (Test-Path -LiteralPath (Join-Path $PSScriptRoot ($AppName + ".exe"))) {
    $InstallDir = $PSScriptRoot
    if (-not $Version) { $Version = Split-Path -Leaf $PSScriptRoot }
} elseif ($Version) {
    $InstallDir = Join-Path $InstallRoot $Version
} elseif (Test-Path -LiteralPath $InstallRoot) {
    $latest = Get-ChildItem -LiteralPath $InstallRoot -Directory -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latest) {
        $InstallDir = $latest.FullName
        $Version = $latest.Name
    }
}

Write-Host "LogicLab 卸载" -ForegroundColor Cyan
if ($InstallDir) { Write-Host "  安装目录: $InstallDir" } else { Write-Host "  安装目录: 未找到（继续清理注册表与快捷方式）" }
if ($Version) { Write-Host "  版本: $Version" }
if ($DryRun) { Write-Host "  模式: DryRun（只打印动作，不删除任何内容）" -ForegroundColor Yellow }

# ---------------------------------------------------------------- 1. 快捷方式
Write-Host ""
Write-Host "=== 1/4 删除快捷方式 ===" -ForegroundColor Cyan
$shortcuts = @()
$programs = [Environment]::GetFolderPath("Programs")
$desktop = [Environment]::GetFolderPath("Desktop")
if ($programs) { $shortcuts += (Join-Path $programs ($AppName + ".lnk")) }
if ($desktop) { $shortcuts += (Join-Path $desktop ($AppName + ".lnk")) }

foreach ($link in $shortcuts) {
    if (-not (Test-Path -LiteralPath $link)) { continue }
    $target = ""
    try {
        $shell = New-Object -ComObject WScript.Shell
        $target = $shell.CreateShortcut($link).TargetPath
    } catch { }
    $owned = $false
    if ($target) {
        $normalized = $target.ToLowerInvariant()
        if ($normalized.StartsWith($InstallRoot.ToLowerInvariant())) { $owned = $true }
        if ($InstallDir -and $normalized.StartsWith($InstallDir.ToLowerInvariant())) { $owned = $true }
    }
    if (-not $owned) {
        Write-Warn "快捷方式不指向 LogicLab 安装目录，保留: $link（目标 $target）"
        continue
    }
    if ($DryRun) { Write-Act "删除快捷方式 $link" }
    else { Remove-Item -LiteralPath $link -Force -ErrorAction SilentlyContinue; Write-Ok "已删除 $link" }
}

# ---------------------------------------------------------------- 2. 注册表
Write-Host ""
Write-Host "=== 2/4 清理注册表（HKCU） ===" -ForegroundColor Cyan
$ClassesRoot = "HKCU:\Software\Classes"
$ExtKey = "$ClassesRoot\.logiclab"
$ProgKey = "$ClassesRoot\$ProgId"
$OpenWithKey = "$ExtKey\OpenWithProgids"
$UninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\LogicLab"

if (Test-Path -LiteralPath $ExtKey) {
    $current = ""
    try { $current = (Get-Item -LiteralPath $ExtKey).GetValue("") } catch { }
    if ($current -eq $ProgId) {
        if ($DryRun) { Write-Act "删除注册表键 $ExtKey" }
        else { Remove-Item -LiteralPath $ExtKey -Recurse -Force -ErrorAction SilentlyContinue; Write-Ok "已删除 $ExtKey" }
    } else {
        Write-Warn ".logiclab 关联不属于 LogicLab（当前值 '$current'），保留"
    }
}
if (Test-Path -LiteralPath $OpenWithKey) {
    if ($DryRun) { Write-Act "删除注册表键 $OpenWithKey" }
    else { Remove-Item -LiteralPath $OpenWithKey -Recurse -Force -ErrorAction SilentlyContinue; Write-Ok "已删除 $OpenWithKey" }
}
if (Test-Path -LiteralPath $ProgKey) {
    if ($DryRun) { Write-Act "删除注册表键 $ProgKey" }
    else { Remove-Item -LiteralPath $ProgKey -Recurse -Force -ErrorAction SilentlyContinue; Write-Ok "已删除 $ProgKey" }
}
if (Test-Path -LiteralPath $UninstallKey) {
    if ($DryRun) { Write-Act "删除注册表键 $UninstallKey" }
    else { Remove-Item -LiteralPath $UninstallKey -Recurse -Force -ErrorAction SilentlyContinue; Write-Ok "已删除卸载项" }
}

# ---------------------------------------------------------------- 3. 程序文件
Write-Host ""
Write-Host "=== 3/4 删除程序文件 ===" -ForegroundColor Cyan
if ($InstallDir -and (Test-Path -LiteralPath $InstallDir)) {
    if ($DryRun) { Write-Act "删除目录 $InstallDir" }
    else {
        Remove-Item -LiteralPath $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Ok "已删除 $InstallDir"
    }
} else {
    Write-Host "无程序目录需要删除"
}
if (-not $DryRun -and (Test-Path -LiteralPath $InstallRoot)) {
    $remaining = @(Get-ChildItem -LiteralPath $InstallRoot -Force -ErrorAction SilentlyContinue)
    if ($remaining.Count -eq 0) {
        Remove-Item -LiteralPath $InstallRoot -Force -ErrorAction SilentlyContinue
        Write-Ok "已删除空的 $InstallRoot"
    }
}

# ---------------------------------------------------------------- 4. 用户数据
Write-Host ""
Write-Host "=== 4/4 用户数据 ===" -ForegroundColor Cyan
$UserData = Join-Path $env:APPDATA "LogicLab"
if ($KeepUserData) {
    Write-Host "保留用户数据（-KeepUserData）: $UserData" -ForegroundColor Yellow
} elseif (Test-Path -LiteralPath $UserData) {
    if ($DryRun) { Write-Act "删除用户数据 $UserData" }
    else {
        Remove-Item -LiteralPath $UserData -Recurse -Force -ErrorAction SilentlyContinue
        Write-Ok "已删除用户数据 $UserData"
    }
} else {
    Write-Host "无用户数据需要删除"
}

Write-Host ""
if ($DryRun) { Write-Host "DryRun 结束：未删除任何内容。" -ForegroundColor Yellow }
else { Write-Host "LogicLab 卸载完成。" -ForegroundColor Green }
exit 0
