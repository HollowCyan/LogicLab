# LogicLab 安装与卸载（Windows 免管理员）

LogicLab 提供两种 Windows 发行形态：

| 形态 | 位置 | 需要管理员 | 适用场景 |
| --- | --- | --- | --- |
| 绿色免安装（onedir） | 解压后的 `LogicLab` 目录，双击 `LogicLab.exe` | 否 | 试用、U 盘携带、教学机房统一分发 |
| 安装版（本目录脚本） | `%LOCALAPPDATA%\LogicLab\<version>` | 否 | 日常使用，需要开始菜单/桌面快捷方式与 `.logiclab` 文件关联 |

安装脚本全程只写 **HKCU** 与 **%LOCALAPPDATA%**，不触碰 HKLM，因此不需要管理员权限。

## 前置条件

1. 已用 `tools/build_release.ps1`（或 `python -m PyInstaller --noconfirm --clean LogicLab.spec`）生成 `dist\LogicLab\`。
2. Windows PowerShell 5.1 或 PowerShell 7 均可。

## 安装

```powershell
# 常规安装（来源默认 dist\LogicLab）
powershell -NoProfile -ExecutionPolicy Bypass -File installer/install.ps1

# 预览将执行的动作，不写任何文件与注册表
powershell -NoProfile -ExecutionPolicy Bypass -File installer/install.ps1 -DryRun

# 指定来源目录 / 版本 / 不创建快捷方式
powershell -NoProfile -ExecutionPolicy Bypass -File installer/install.ps1 -Source D:\pkg\LogicLab -Version 4.1.0
powershell -NoProfile -ExecutionPolicy Bypass -File installer/install.ps1 -NoShortcuts
```

安装脚本是幂等的：重复执行只覆盖变化的文件，注册表项用覆盖写入，不会产生重复条目。

| 参数 | 说明 |
| --- | --- |
| `-Source` | 包目录，默认 `dist\LogicLab` |
| `-DryRun` | 只打印动作，零写入 |
| `-NoShortcuts` | 不创建开始菜单/桌面快捷方式 |
| `-Version` | 覆盖版本号（默认读 `src/logiclab/version.py`） |

## 安装内容

- 程序文件：`%LOCALAPPDATA%\LogicLab\<version>\`
- 开始菜单：`<Programs>\LogicLab.lnk`
- 桌面：`<Desktop>\LogicLab.lnk`
- 注册表（全部 HKCU）：
  - `HKCU\Software\Classes\.logiclab`（默认值 `LogicLab.Circuit`）
  - `HKCU\Software\Classes\.logiclab\OpenWithProgids\LogicLab.Circuit`
  - `HKCU\Software\Classes\LogicLab.Circuit\DefaultIcon`（`<exe>,0`）
  - `HKCU\Software\Classes\LogicLab.Circuit\shell\open\command`（`"<exe>" "%1"`）
  - `HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\LogicLab`（控制面板卸载项）

## 卸载

```powershell
# 卸载并删除用户数据（日志、配置）
powershell -NoProfile -ExecutionPolicy Bypass -File installer/uninstall.ps1

# 保留用户数据（%APPDATA%\LogicLab）
powershell -NoProfile -ExecutionPolicy Bypass -File installer/uninstall.ps1 -KeepUserData

# 预览
powershell -NoProfile -ExecutionPolicy Bypass -File installer/uninstall.ps1 -DryRun
```

也可以在“设置 → 应用 → 已安装的应用”里点卸载（卸载项调用安装目录内的 `uninstall.ps1`）。
卸载脚本只会删除指向 LogicLab 安装目录的快捷方式，以及值等于 `LogicLab.Circuit` 的
`.logiclab` 关联，避免误删其它程序。

## 校验发行包

```powershell
Get-FileHash .\LogicLab-4.1.0-win64.zip -Algorithm SHA256
Get-Content .\LogicLab-4.1.0-win64.zip.sha256
```

两个 SHA256 值应一致。

## 常见问题

- **提示“无法加载文件 … 因为在此系统上禁止运行脚本”**：使用上面的 `-ExecutionPolicy Bypass` 调用方式，或对当前用户执行 `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`。
- **中文显示乱码**：脚本以 UTF-8 BOM 保存并把控制台输出设为 UTF-8；若终端编码为 936，可在 PowerShell 里执行 `chcp 65001` 后重试。
- **双击 `.logiclab` 没有反应**：确认安装完成且 `HKCU\Software\Classes\.logiclab` 默认值为 `LogicLab.Circuit`；运行一次 `install.ps1` 会重新注册（幂等）。
- **卸载后仍能在“已安装的应用”里看到 LogicLab**：说明安装目录被移动过导致 `uninstall.ps1` 不在原路径；直接运行本目录的 `uninstall.ps1` 即可清理注册表与快捷方式。
