# Windows 发布构建：Release exe + Inno Setup 安装包 + 便携 zip。
# 版本号读根目录 VERSION 文件（用 scripts/bump-version.sh 递增）。
# 产物：
#   windows/build/Saypick.exe
#   windows/build/Saypick-Setup-{v}.exe     （安装包）
#   windows/build/Saypick-windows-{v}.zip   （便携版）
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$win = Join-Path $root "windows"
$version = (Get-Content (Join-Path $root "VERSION") -Raw).Trim()
Write-Output "building Saypick for Windows v$version"

# --- 定位工具链 ---
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vs) { throw "Visual Studio with C++ workload not found" }
$devcmd = Join-Path $vs "Common7\Tools\VsDevCmd.bat"

$iscc = @("${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
          "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
          "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe") |
        Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { throw "Inno Setup 6 not found (winget install JRSoftware.InnoSetup)" }

# --- 构建 exe（版本号已由 bump-version.sh 写进 CMakeLists/rc/manifest）---
cmd /c "`"$devcmd`" -arch=amd64 -no_logo && cd /d `"$win`" && cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release && cmake --build build"
if ($LASTEXITCODE -ne 0) { throw "cmake build failed" }
$exe = Join-Path $win "build\Saypick.exe"
if (-not (Test-Path $exe)) { throw "Saypick.exe not produced" }

# 构建后快速自检（Start-Process：exe 起不来（如 SxS 配置损坏）也会抛错，
# 直接用 & 调用时 $LASTEXITCODE 不会更新，坏包会溜进安装器）
$env:SAYPICK_DATA_DIR = Join-Path $env:TEMP "saypick-release-selftest"
$st = Start-Process -FilePath $exe -ArgumentList "--selftest" -NoNewWindow -Wait -PassThru
if ($st.ExitCode -ne 0) { throw "self-test failed (exit $($st.ExitCode))" }
Remove-Item Env:\SAYPICK_DATA_DIR

# --- 安装包 ---
& $iscc "/DAppVersion=$version" (Join-Path $win "installer\Saypick.iss") | Select-Object -Last 3
if ($LASTEXITCODE -ne 0) { throw "ISCC failed" }
$setup = Join-Path $win "build\Saypick-Setup-$version.exe"

# --- 便携 zip ---
$zip = Join-Path $win "build\Saypick-windows-$version.zip"
if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path $exe -DestinationPath $zip

Write-Output ""
Write-Output "artifacts:"
Get-Item $setup, $zip | ForEach-Object { "  $($_.FullName)  ($([math]::Round($_.Length/1MB,2)) MB)" }
