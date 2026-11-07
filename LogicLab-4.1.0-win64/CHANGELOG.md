# Changelog

本项目遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。
格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

## [4.1.0] - 2026-12-01

质量与文档版本：补齐可持续运行的测试体系，清理占位代码，文档与真实实现对齐。
（本段为变更摘要，发布日期以 Release 页面为准。）

### 新增
- 真实 pytest 测试体系（替换掉 import 即 `sys.exit` 的手写脚本）：
  - `tests/test_core_engine.py`：ctypes 直连内核，覆盖与/或/非/与非/或非/异或/同或全真值表、4 值 X 传播、三态 Z、常数门、DFF tick、CLOCK 翻转、DFF 反馈与组合环报错；内核缺失时自动 skip。
  - `tests/test_version.py`：`version.py` 与 pyproject / CMakeLists / `assets/version_info.txt` / CHANGELOG 的版本一致性校验。
  - `tests/test_verilog.py`：Verilog 导出的模块头、端口声明、内部 wire 与真实门实例连线。
  - `tests/test_packaging.py`：`LogicLab.spec` 全部 datas 源路径、exe 图标与打赏二维码的存在性与格式校验。
- 文档：`CONTRIBUTING.md`（环境/构建/测试/提交规范/PR 检查单）、`SECURITY.md`（漏洞上报 fly_space_why@163.com 与支持版本）、`docs/PLATFORMS.md`（平台支持与验证状态）、`docs/RELEASE.md`（发布检查单与产物校验）。
- `.gitignore` 按真实产物重写（内核构建产物、测试缓存、打包 zip/sha256、本地恢复目录等）；保留 `docs/`、`assets/` 入库。

### 修复
- `pytest` 在收集阶段即崩溃（手写脚本在模块级调用 `sys.exit`，导致 INTERNALERROR）：删除 `tests/test_m1.py`、`test_m2.py`、`test_m3.py` 并清理 `__pycache__`、`.pytest_cache`。
- 文档与实现脱节：`docs/ARCHITECTURE.md` 的「测试策略」一节改为真实存在的测试文件，删除对已移除模块的描述。
- 测试中的内核 ABI 与 `core/logiclab_core.h` 对齐（`ll_tick(c, count)`），不再沿用过期签名。

### 移除
- 删除 `ai_assistant`、`collaboration`、`plugin_system`、`fpga_export` 与 **45 个不可仿真占位元件**。
- 示例从 **50 个假条目**收敛为 **19 个可验证示例**（每个示例都有参考输出，可一键自检）。

### 已知限制
- 界面为中文单语；Windows 10/11 x64 为唯一实机验证平台，Linux/macOS 仅 CI 构建与测试验证（详见 `docs/PLATFORMS.md`）。
- 时序仿真为门级/单位延迟模型，非真实器件时序。
- 未签名 PyInstaller 产物可能被杀毒软件误报，请核对 SHA256。

## [4.0.0] - 2026-11-07

首个正式发布版（Production/Stable）。

### 亮点
- **真值表 ⇄ 电路双向**：可编辑真值表 → Quine–McCluskey 最简 SOP → XOR/XNOR 识别 → 一键生成布局电路；也可从现有电路导出真值表与逻辑表达式。
- **设计–验证闭环**：19 个自带参考输出的示例、一键示例自检、等价性检查、可综合 Verilog + 自检 testbench、VCD 波形、单位延迟时序报告。
- **4 值逻辑内核**：0/1/X/Z 与三态门一等公民；C++ 内核 O(V+E) 拓扑、批量信号快照；实测性能见 README。
- **专业编辑器 + 绿色免安装**：拖拽放置、全量撤销、未保存保护、60 秒自动恢复、最近文件、深浅主题、适应窗口、快捷键、诊断自检；开箱即用的 Windows 绿色包。

### 新增
- `logiclab/synthesis.py`：Quine–McCluskey 最简 SOP 综合器（≤8 输入，含无关项、XOR/XNOR 识别、规范 SOP 回退）。
- 真值表对话框：表格编辑、从电路读入、表达式显示、CSV 导出、生成最简电路。
- 交互式教程对话框：4 个教程、载入电路、判题、进度持久化。
- 帮助 → 诊断/自检对话框；`logiclab --selftest` 无界面自检；`--version`；命令行打开工程文件。
- 自动恢复、最近文件、窗口状态、主题/时钟频率设置持久化；应用图标与 About。
- 结构化日志（`%APPDATA%/LogicLab/logs`）与全局异常钩子。
- 一键发布脚本 `tools/build_release.ps1`、PyInstaller 配置、CI 工作流、`docs/QA.md` 发布清单。

### 修复
- 内核源码与 DLL 脱节：以源码为准重建 `logiclab_core.dll`，统一 `ll_tick(c, count)` ABI。
- 时钟门不翻转、DFF/JK 边沿检测使用错误信号、DFF 反馈被误判组合环，时序电路示例可正常仿真。
- 安装/打包后找不到内核 DLL（多路径解析 + 包内 `_bin`）。
- 深色主题菜单无效、教程菜单误重置主题。
- 等价性检查导入错误模块导致必然失败。
- Verilog 导出网表所有连线输出 `1'b0`。
- 真值表每行重建内核导致慢且端口顺序不稳定。
- 波形记录 O(n) 截断、VCD 变量名超过 26 个冲突。
- 工程保存改为原子写并保留 `.bak`；撤销覆盖连线创建/删除与元件移动。
- 版本号在 pyproject/CMake/UI 间不一致的问题（统一 4.0.0）。

### 移除 / 归档
- 归档 50 个示例中不可验证/未接线的占位示例，仅保留 19 个可自检示例；旧模块移至 `extras/legacy_cells/`。
- 移除假 FPGA 导出（仅注释的网表、无效引脚约束），移至 `extras/experimental/`。
- 移除导入时自动加载插件、未使用的 AI/协作/插件占位菜单入口（模块归档至 `extras/experimental/`）。
- 清理仓库中的 `nul`、`test.vcd`、`vc_test/` 等构建/测试残留。

### 已知限制
- 界面为中文单语；目标平台以 Windows 10/11 x64 为主，Linux/macOS 支持源码构建。
- 时序仿真为门级/单位延迟模型，非真实器件时序。
- Verilog 通过 golden test 与自检 testbench 验证，不内置外部仿真器。
