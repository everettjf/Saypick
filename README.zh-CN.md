<h1 align="center">TypeTide</h1>
<p align="center"><b>macOS 和 Windows 上的全局 AI 翻译与原地改写</b></p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-26+-black.svg" />
  <img src="https://img.shields.io/badge/Windows-10+-0078d4.svg" />
  <img src="https://img.shields.io/badge/Swift-5.9+-orange.svg" />
  <img src="https://img.shields.io/badge/C++-20-00599c.svg" />
  <img src="https://img.shields.io/badge/AI-Ollama%20%7C%20OpenAI--compatible-7c5cff.svg" />
  <img src="https://img.shields.io/badge/License-MIT-green.svg" />
  <a href="https://discord.com/invite/eGzEaP6TzR"><img src="https://img.shields.io/badge/Discord-加入-5865F2?logo=discord&logoColor=white" /></a>
</p>

<p align="center">
  <a href="https://everettjf.github.io/TypeTide/">🌐 官网</a> ·
  <a href="docs/blog/introducing-typetide.md">📝 项目介绍</a> ·
  <a href="README.md">English</a> · <b>简体中文</b>
</p>

TypeTide 常驻菜单栏（macOS）或系统托盘（Windows），在**任何**应用里都能用。两件事，各一个快捷键：

- **读** — 选中外语文字，按下快捷键，译文就在旁边弹出。
- **写** — 用母语打字，按下快捷键，文字**原地改写**成目标语言，直接可以发送。

翻译走本地模型（**Ollama**，完全私密）或任意 **OpenAI 兼容**接口（更快）。不用开浏览器标签页，不用复制粘贴到翻译网站——选中的文字待在原处；用 Ollama 时，内容永远不离开你的电脑。

<p align="center">
  <img src="docs/screenshots/rewrite.gif" alt="输入中文，按 ⌥R，原地改写为英文" width="760" />
  <br/><sub><i>写 · 用母语输入，按 <kbd>⌥R</kbd>，原地改写成目标语言。</i></sub>
</p>

<p align="center">
  <img src="docs/screenshots/translate.gif" alt="选中文字，译文流式显示在弹窗里" width="760" />
  <br/><sub><i>读 · 选中文字，译文流式显示在弹窗里——可复制或替换。</i></sub>
</p>

<p align="center">
  <img src="docs/screenshots/icon.png" alt="选区旁的浮动翻译图标" width="520" />
  <br/><sub><i>可选的浮动图标，紧贴你的选区出现。</i></sub>
</p>

---

## ✨ 功能

- **读 · 翻译** — 在任意位置选中文字 → 弹窗显示译文。可用快捷键、选区旁的浮动图标或划词自动翻译触发。
- **写 · 原地改写** — 用母语写字，按改写快捷键，输入框内容被替换成译文。可直接替换，也可先预览。
- **每个应用都能用** — 通过 Accessibility API（macOS）/ UI Automation（Windows）读取选区，对 Electron/网页类应用自动降级为剪贴板复制，文字接口不可用时也能工作。原剪贴板内容总会被还原。
- **替换不破坏撤销** — 替换通过粘贴完成，保留每个应用原生的撤销栈（Ctrl+Z / ⌘Z 随时可撤销）。
- **本地或云端** — 可插拔后端：**Ollama**（离线、私密）或任意 **OpenAI 兼容** API（`/chat/completions`，流式）。设置里一键切换。
- **模型选择** — 设置里列出已安装的 Ollama 模型；配置的模型没装时自动选一个已装的，开箱即用。思考型模型（qwen3 系等）已做处理——自动关闭隐藏推理，翻译保持秒回。
- **风格** — 忠实直译、正式、口语、润色四种，读和写可分别设置。
- **只住菜单栏 / 托盘** — 不占 Dock、不占任务栏。全局快捷键、开机自启、按应用跳过列表。
- **双平台全原生** — macOS 用 SwiftUI，Windows 用 Win32 C++。没有 Electron，没有运行时。

## 💡 为什么选 TypeTide

| | TypeTide | 浏览器翻译网站 | 系统自带翻译 |
|---|---|---|---|
| 任何应用里都能用（邮件、聊天、IDE、终端） | ✅ | ❌（来回粘贴） | ⚠️ 仅菜单 |
| 回复场景**原地改写** | ✅ | ❌ | ❌ |
| 100% 离线 / 私密 | ✅（Ollama） | ❌ | ⚠️ |
| 自选模型 / 接口 | ✅ | ❌ | ❌ |
| 流式输出 | ✅ | ⚠️ | ❌ |

## 🌍 语言

检测与翻译覆盖使用人数最多的 10 种语言：**英语、中文、印地语、西班牙语、法语、阿拉伯语、孟加拉语、俄语、葡萄牙语、印尼语**。在**设置 → Language** 里选好你的母语和外语。每个快捷键（⌥D / ⌥R）各有独立方向：**自动**检测选中文字的语言并翻译成另一种，混合语言容易误判时也可以钉死**固定**方向。

## 🚀 快速开始

**1. 选一个后端**

本地（私密、离线）——先安装 [Ollama](https://ollama.com/download)，然后：
```bash
# macOS: brew install ollama · Windows: winget install Ollama.Ollama
ollama pull qwen2.5:3b   # 或任何你喜欢的对话模型
ollama serve             # 通常已作为服务在运行
```
……或者用云端：在**设置 → Backend** 里选 *OpenAI-compatible*，填入 base URL、API key 和模型名。

TypeTide 会在**设置 → Backend** 里列出你已安装的模型；配置的模型没装时会自动换成已装的——拉取*任意*一个对话模型就能跑起来。

**2. 安装 TypeTide**

macOS——推荐用 [Homebrew](https://brew.sh)：
```bash
brew install --cask everettjf/typetide/typetide
```
……或者从 [Releases](../../releases) 下载最新 `.dmg`，拖进「应用程序」后启动。安装包已由 Apple 签名和公证。

Windows——从 [Releases](../../releases) 下载最新的 `TypeTide-Setup-x.y.z.exe` 安装包运行即可（按用户安装，无需管理员权限；也提供便携版 `TypeTide-Windows-x.y.z.zip`）。如果 SmartScreen 提示无法识别的应用，点**更多信息 → 仍要运行**。

**3. 首次运行**

macOS：在**系统设置 → 隐私与安全性 → 辅助功能**里允许 TypeTide（读取选区和替换文字需要）。Windows 无需任何特殊权限。然后：

- 选中文字 → **⌥D**（macOS）/ **Alt+D**（Windows）→ 看译文。
- 用母语输入 → **⌥R** / **Alt+R** → 原地改写。

快捷键、触发方式、风格、语言都可以在**设置**里改。

## ⌨️ 默认快捷键

| 操作 | macOS | Windows |
|---|---|---|
| 翻译选中文字（读） | <kbd>⌥</kbd><kbd>D</kbd> | <kbd>Alt</kbd><kbd>D</kbd> |
| 改写并替换（写） | <kbd>⌥</kbd><kbd>R</kbd> | <kbd>Alt</kbd><kbd>R</kbd> |

## 🧠 工作原理

```
选中 / 输入  ─►  快捷键 · 浮动图标 · 自动
                        │
        取词（AX / UI Automation 选区 ─► 剪贴板兜底）
                        │
          翻译（Ollama / OpenAI 兼容，流式）
                        │
      读：弹窗展示  ·  写：原地粘贴（可撤销）
```

## 🏗️ 项目结构

```
macos/                 # SwiftUI 应用（Xcode 工程）
├── TypeTide/
│   ├── Core/          # SelectionCapture、TextReplacer、TriggerController、
│   │                  # SelectionMonitor、PopupPositioner、LaunchAtLogin 等
│   ├── Translation/   # TranslationProvider、Ollama / OpenAI provider、
│   │                  # TranslationService、缓存、模型自动纠正
│   ├── UI/            # 翻译弹窗 + 浮动选区图标
│   ├── Config/        # AppSettings、LanguageConfig
│   ├── Services/      # GlobalShortcutCenter、UpdateChecker、系统服务
│   └── Views/         # 菜单栏 + 设置界面
└── scripts/           # 发布 / 公证脚本

windows/               # 原生 Win32 C++20 应用（CMake）
├── src/               # 托盘、热键、UIA 取词、弹窗、provider、
│                      # 设置窗口、替换器、语言检测
└── assets/            # 图标

docs/                  # GitHub Pages 站点 + 博客 + 截图
```

## 🔨 构建与发布

macOS：
```bash
cd macos
open TypeTide.xcodeproj          # ⌘R 运行

# 签名发布 + 公证 DMG（先导出 APPLE_ID、APPLE_SPECIFIC_PASSWORD、APPLE_TEAM_ID）
./scripts/build-release.sh      # → build/TypeTide-x.y.z.dmg
```

要求：macOS 26+、Xcode 15+。应用**未**沙盒化（需要辅助功能权限 + 合成键盘事件）。本地开发构建请用你的 Apple Development 团队签名，这样辅助功能授权在重新构建后依然有效。

Windows：
```powershell
cd windows
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build             # → build/TypeTide.exe
```

要求：Windows 10+、Visual Studio 2022+（MSVC、CMake、Ninja）。零第三方依赖——纯 Win32 + WinHTTP + UI Automation。架构与测试体系见 [windows/README.md](windows/README.md)。

**发版** —— 双端共享一个版本号（根目录 `VERSION` 文件），可以以任意先后顺序附着到同一个 GitHub release：

```bash
./scripts/bump-version.sh            # patch +1，同步 pbxproj / CMake / rc / manifest
# 提交后，在各自平台上：
./scripts/release-windows.ps1        # Windows：构建安装包 + zip，创建/补传 release
./scripts/release-macos.sh           # macOS：构建公证 DMG，创建/补传 release
```

哪个平台先发就由它创建 `vX.Y.Z` tag，另一个平台稍后把自己的产物传到同一个 release 上。需要先 `gh auth login` 一次。

## 🔧 常见问题

- **快捷键没反应** → macOS：确认辅助功能已授权（设置 → General 显示 *Granted*）且菜单栏里 TypeTide 处于开启状态。Windows：可能有其他应用占用了该热键——在**设置 → Shortcuts** 里换一个。
- **没有译文** → Ollama：`ollama serve` 在运行吗？模型装了吗？（配置的模型没装时 TypeTide 会自动换成已装的。）OpenAI：检查 base URL / key / 模型名。
- **qwen3 之类的模型翻译特别慢** → TypeTide 已为 Ollama 模型自动关闭隐藏「思考」；如果还是慢，可能是模型对你的硬件太大了——在**设置 → Backend** 的下拉框里换个小的。
- **某些应用里弹窗位置不准** → 这些应用不暴露文字边界；弹窗会退回到光标位置。
- **Sequoia 或更早的 macOS 提示无法打开** → TypeTide 要求 **macOS 26+**。它基于当前的 SwiftUI 菜单栏和设置 API 构建，保持单一现代基线是小项目可靠性的前提。暂无支持旧版 macOS 的计划。
- **哪个语言填哪里？** → 在**设置 → Language** 里选你的**母语**和**外语**（没有容易搞反的“源/目标”概念）。每个快捷键有自己的方向；**自动**会检测选中文字的语言并翻译成另一种。

## 🤝 参与贡献

欢迎提 Issue 和 PR。来 [Discord](https://discord.com/invite/eGzEaP6TzR) 聊聊。

## 📄 许可证

[MIT](LICENSE) · 为 macOS 和 Windows 用 ❤️ 打造。如果 TypeTide 帮到了你，点个 ⭐️ 就是最好的支持！
