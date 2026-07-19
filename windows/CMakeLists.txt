cmake_minimum_required(VERSION 3.20)
project(Saypick VERSION 0.1.4 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(Saypick WIN32
    src/main.cpp
    src/App.cpp
    src/Log.cpp
    src/Json.cpp
    src/Language.cpp
    src/Settings.cpp
    src/Credentials.cpp
    src/Clipboard.cpp
    src/Keyboard.cpp
    src/Http.cpp
    src/Translator.cpp
    src/OllamaModels.cpp
    src/CrashDump.cpp
    src/SelectionCapture.cpp
    src/TextReplacer.cpp
    src/Hooks.cpp
    src/PopupWindow.cpp
    src/SelectionIcon.cpp
    src/SelectionMonitor.cpp
    src/TrayIcon.cpp
    src/SettingsWindow.cpp
    src/LaunchAtLogin.cpp
    src/UpdateChecker.cpp
    src/SelfTest.cpp
    src/Saypick.rc
    src/Saypick.manifest
)

target_compile_definitions(Saypick PRIVATE
    UNICODE _UNICODE NOMINMAX WIN32_LEAN_AND_MEAN
    SAYPICK_VERSION_STRING="${PROJECT_VERSION}"
)

if(MSVC)
    target_compile_options(Saypick PRIVATE /W4 /utf-8 /EHsc)
endif()

target_link_libraries(Saypick PRIVATE
    user32 gdi32 shell32 ole32 oleaut32 uuid comctl32
    winhttp uiautomationcore dwmapi advapi32 shlwapi uxtheme dbghelp
)
