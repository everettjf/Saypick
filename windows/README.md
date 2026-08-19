# TypeTide for Windows

Native Win32 C++20 port of TypeTide — system-wide AI translation & inline
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
| Ollama model picker / auto-resolve | ✅ | ✅ (dropdown from /api/tags; invalid model auto-replaced at startup) |
| Floating icon / auto-translate on select | ✅ | ✅ (low-level mouse hook) |
| Retarget language in popup | ✅ | ✅ |
| Styles (Faithful/Formal/Casual/Polished) | ✅ | ✅ |
| Menu bar / tray | menu bar | system tray |
| Launch at login | SMAppService | HKCU Run key |
| Per-app skip list | ✅ | ✅ (exe name) |
| Update check | GitHub Releases | same |
| Settings | SwiftUI window | native tabbed window |
| Shortcut actions / verification | ✅ | ✅ |
| First-run backend check | ✅ | ✅ |
| Local privacy-safe diagnostics | ✅ | ✅ |
| System light/dark settings UI | ✅ | ✅ |
| Permissions needed | Accessibility | none |

Settings persist to `%APPDATA%\TypeTide\settings.json`
(override dir with the `TYPETIDE_DATA_DIR` env var; set `TYPETIDE_DEBUG=1` to
write `debug.log` beside it).

Cloud API presets are available for OpenAI, OpenRouter, and DeepSeek, alongside
any custom OpenAI-compatible `/chat/completions` endpoint. In normal use the API
key is stored in Windows Credential Manager; it is never written back to
`settings.json`. Ollama models are preloaded at startup and kept warm for 10
minutes to avoid cold-start delays.

The shortcut editor supports Ctrl, Shift, Alt, and the Windows key. Each of the
two shortcuts independently chooses smart/native/foreign direction and popup or
in-place replacement. Either shortcut can be cleared; keep at least one configured
for keyboard triggering. The Ollama picker also recommends an installed model size
from the machine's physical memory; it never downloads or changes models by itself.

## Build

Requirements: Windows 10+, Visual Studio 2022+ (MSVC toolset, CMake, Ninja —
all bundled with the "Desktop development with C++" workload).

```powershell
# from a VS Developer PowerShell / Command Prompt
cd windows
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build          # → build\TypeTide.exe
```

The tray icon (`assets/app.ico`) is generated from the macOS icon set with
`scripts\make-icon.ps1`.

## Test

```powershell
# unit-style self-tests (JSON, language detection, settings, shared contracts,
# privacy-safe diagnostics, prompts)
build\TypeTide.exe --selftest

# + a real streaming translation through the configured backend
build\TypeTide.exe --selftest-translate
```

End-to-end (drives the real app + a mock backend + a scratch editor window;
uses synthetic input, so keep hands off the keyboard while it runs):

```powershell
# terminal 1 — mock backend (OpenAI SSE + Ollama NDJSON on :8199)
scripts\mock-openai.ps1

# terminal 2 — point the app at a scratch data dir with mock settings, then:
$env:TYPETIDE_DATA_DIR = "$env:TEMP\typetide-e2e"
scripts\test-e2e.ps1        # WinForms host → clipboard-fallback capture path
scripts\test-e2e-wpf.ps1    # WPF host → UI Automation TextPattern path
```

For the complete release-candidate matrix (hotkey conflicts, first-run checks,
dark mode, clipboard restoration, cloud/Ollama streaming, and installer smoke
tests), follow [`TESTING.md`](TESTING.md) on a Windows machine.

## Architecture

```
main.cpp             single instance, COM init, message loop
App                  orchestrator: hotkeys, flows, thread marshaling (WM_APP_*)
SelectionCapture     UIA TextPattern selection (+ rect) → synthetic Ctrl+C fallback
TextReplacer         clipboard paste replace (undo-safe), clipboard restored
Translator           prompts · Ollama NDJSON · OpenAI SSE · LRU cache (worker threads)
OllamaModels         /api/tags model list · auto-resolve · async preload/keep-alive
Http                 WinHTTP streaming POST / GET
PopupWindow          no-activate topmost popup: streaming text, Copy/Replace,
                     retarget menu, Esc / click-outside dismiss, dark mode, DPI
SelectionIcon        floating icon next to selection
SelectionMonitor     WH_MOUSE_LL mouse-up → UIA selection (icon / auto trigger)
SettingsWindow       tabbed native settings (instant apply)
TrayIcon / Hotkeys / LaunchAtLogin / UpdateChecker / Settings / Json / Language
```

Threading rule: all UI on the main thread, and the main thread **never
sleeps** — a stalled message loop gets the low-level hooks silently removed
by the OS. Anything that waits (clipboard-fallback capture, paste
replacement, HTTP) runs on worker threads and posts `WM_APP_*` messages with
heap payloads (receiver frees). Workers never read `Settings::shared()`
directly; config is snapshotted on the main thread and passed in.

Reliability notes:
- Paste replacement uses clipboard delayed rendering (`WM_RENDERFORMAT`) to
  know when the target actually consumed the paste before restoring the
  original clipboard.
- `settings.json` writes are atomic (temp file + rename).
- Unhandled exceptions write a minidump to `%APPDATA%\TypeTide\crashes\`
  (the 5 most recent are kept) — attach one when reporting a crash.
- The tray icon re-registers itself after an explorer.exe restart.
- Selections over 5000 characters are rejected with a friendly message.

Thinking models (qwen3 family etc.) are handled: the Ollama request sends
`"think": false` (and retries without it for models that reject the field) —
otherwise a 2-second translation silently burns minutes on hidden reasoning.

## Known limitations

- Some apps (many Electron apps, some WinForms controls) don't expose UIA
  TextPattern — capture falls back to an invisible copy and the popup anchors
  at the cursor instead of the selection.
- `RegisterHotKey` fails if another app owns the combo; TypeTide warns once and
  you can pick a different shortcut in Settings → Shortcuts.
