; Saypick Windows 安装器（Inno Setup）。
; 由 windows/scripts/build-release.ps1 调用：
;   ISCC.exe /DAppVersion=x.y.z Saypick.iss
; 按用户级安装（无需管理员/UAC），带开始菜单项、卸载器和可选开机自启。

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{7A2E5B90-3C64-4D8F-9B1A-52E8C0A47F31}
AppName=Saypick
AppVersion={#AppVersion}
AppPublisher=everettjf
AppPublisherURL=https://github.com/everettjf/Saypick
AppSupportURL=https://github.com/everettjf/Saypick/issues
AppUpdatesURL=https://github.com/everettjf/Saypick/releases
DefaultDirName={autopf}\Saypick
DefaultGroupName=Saypick
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=..\build
OutputBaseFilename=Saypick-Setup-{#AppVersion}
SetupIconFile=..\assets\app.ico
UninstallDisplayIcon={app}\Saypick.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no
DisableProgramGroupPage=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "autostart"; Description: "Start Saypick when I sign in"; GroupDescription: "Additional options:"

[Files]
Source: "..\build\Saypick.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Saypick"; Filename: "{app}\Saypick.exe"
Name: "{group}\Uninstall Saypick"; Filename: "{uninstallexe}"

[Registry]
; 开机自启（用户勾选时写入；卸载时清掉）
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; \
    ValueType: string; ValueName: "Saypick"; ValueData: """{app}\Saypick.exe"""; \
    Flags: uninsdeletevalue; Tasks: autostart

[Run]
Filename: "{app}\Saypick.exe"; Description: "Launch Saypick now"; \
    Flags: nowait postinstall skipifsilent

[UninstallRun]
; 卸载前退出正在运行的实例（用户设置保留在 %APPDATA%\Saypick，重装不丢配置）
Filename: "{cmd}"; Parameters: "/C taskkill /IM Saypick.exe /F"; \
    Flags: runhidden skipifdoesntexist; RunOnceId: "KillSaypick"
