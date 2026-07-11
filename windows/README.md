# Saypick for Windows

Native Win32 C++20 port of Saypick — system-wide AI translation & inline
rewrite. Zero third-party dependencies: WinHTTP for networking, UI Automation
for selection capture, a tiny built-in JSON parser. No Electron, no runtime.

## Feature parity with macOS

| | macOS | Windows |
|---|---|---|
| Read · translate selection | ⌥D → popup | Alt+D → popup |
| Write · rewrite in place | ⌥R | Alt+R |
| Selection capture | AX API → clipboard fallback | UI Automation TextPattern → clipboard fallback |
| Undo-safe replace | synthetic ⌘V | synthetic Ctrl+V |
| Backends | Ollama · OpenAI-compatible (streaming) | same |
| Floating icon / auto-translate on select | ✅ | ✅ (low-level mouse hook) |
| Retarget language in popup | ✅ | ✅ |
| Styles (Faithful/Formal/Casual/Polished) | ✅ | ✅ |
| Menu bar / tray | menu bar | system tray |
| Launch at login | SMAppService | HKCU Run key |
| Per-app skip list | ✅ | ✅ (exe name) |
| Update check | GitHub Releases | same |
| Settings | SwiftUI window | native tabbed window |
| Permissions needed | Accessibility | none |

Settings persist to `%APPDATA%\Saypick\settings.json`
(override dir with the `SAYPICK_DATA_DIR` env var; set `SAYPICK_DEBUG=1` to
write `debug.log` beside it).

## Build

Requirements: Windows 10+, Visual Studio 2022+ (MSVC toolset, CMake, Ninja —
all bundled with the "Desktop development with C++" workload).

```powershell
# from a VS Developer PowerShell / Command Prompt
cd windows
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build          # → build\Saypick.exe
```

The tray icon (`assets/app.ico`) is generated from the macOS icon set with
`scripts\make-icon.ps1`.

## Test

```powershell
# unit-style self-tests (JSON, language detection, settings, prompts)
build\Saypick.exe --selftest

# + a real streaming translation through the configured backend
build\Saypick.exe --selftest-translate
```

End-to-end (drives the real app + a mock backend + a scratch editor window;
uses synthetic input, so keep hands off the keyboard while it runs):

```powershell
# terminal 1 — mock backend (OpenAI SSE + Ollama NDJSON on :8199)
scripts\mock-openai.ps1

# terminal 2 — point the app at a scratch data dir with mock settings, then:
$env:SAYPICK_DATA_DIR = "$env:TEMP\saypick-e2e"
scripts\test-e2e.ps1        # WinForms host → clipboard-fallback capture path
scripts\test-e2e-wpf.ps1    # WPF host → UI Automation TextPattern path
```

## Architecture

```
main.cpp             single instance, COM init, message loop
App                  orchestrator: hotkeys, flows, thread marshaling (WM_APP_*)
SelectionCapture     UIA TextPattern selection (+ rect) → synthetic Ctrl+C fallback
TextReplacer         clipboard paste replace (undo-safe), clipboard restored
Translator           prompts · Ollama NDJSON · OpenAI SSE · LRU cache (worker threads)
Http                 WinHTTP streaming POST / GET
PopupWindow          no-activate topmost popup: streaming text, Copy/Replace,
                     retarget menu, Esc / click-outside dismiss, dark mode, DPI
SelectionIcon        floating icon next to selection
SelectionMonitor     WH_MOUSE_LL mouse-up → UIA selection (icon / auto trigger)
SettingsWindow       tabbed native settings (instant apply)
TrayIcon / Hotkeys / LaunchAtLogin / UpdateChecker / Settings / Json / Language
```

Threading rule: all UI on the main thread; translation streams on worker
threads and posts `WM_APP_*` messages with heap payloads (receiver frees).

## Known limitations

- Some apps (many Electron apps, some WinForms controls) don't expose UIA
  TextPattern — capture falls back to an invisible copy and the popup anchors
  at the cursor instead of the selection.
- The settings window follows the system light theme only (the popup follows
  dark mode).
- `RegisterHotKey` fails if another app owns the combo; Saypick warns once and
  you can pick a different shortcut in Settings → Shortcuts.
