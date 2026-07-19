# 发布 Windows 版到 GitHub Releases。
# 版本号 = 根目录 VERSION（先用 scripts/bump-version.sh 递增并提交）。
# release 不存在则创建（Windows 先发就由它建 tag），已存在则把资产补传上去
# （macOS 先发过同版本时走这条路）。需要 gh 已登录：gh auth login
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$version = (Get-Content (Join-Path $root "VERSION") -Raw).Trim()
$tag = "v$version"

# gh 可能不在 PATH（默认装在 Program Files）
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    $env:PATH += ";$env:ProgramFiles\GitHub CLI"
}
# gh 往 stderr 写正常输出（如 "release not found"），Stop 策略下会被
# PowerShell 5.1 当成致命错误 —— gh 调用一律放宽策略、按退出码判断。
$ErrorActionPreference = "Continue"
gh auth status *> $null
if ($LASTEXITCODE -ne 0) { throw "gh is not authenticated — run: gh auth login" }
$ErrorActionPreference = "Stop"

# 构建产物
& (Join-Path $root "windows\scripts\build-release.ps1")

$setup = Join-Path $root "windows\build\Saypick-Setup-$version.exe"
$zip = Join-Path $root "windows\build\Saypick-Windows-$version.zip"

# release 不存在则创建
$ErrorActionPreference = "Continue"
gh release view $tag --repo everettjf/Saypick *> $null
$exists = ($LASTEXITCODE -eq 0)
if (-not $exists) {
    Write-Output "creating release $tag"
    gh release create $tag --repo everettjf/Saypick --title "Saypick $version" `
        --notes "Saypick $version — system-wide AI translation & inline rewrite.`n`n- Windows: download and run **Saypick-Setup-$version.exe** (or use the portable zip)`n- macOS: download **Saypick-$version.dmg** (uploaded separately if not yet present)" 2>&1 | ForEach-Object { "$_" }
    if ($LASTEXITCODE -ne 0) { throw "gh release create failed" }
} else {
    Write-Output "release $tag exists — uploading Windows assets to it"
}

gh release upload $tag $setup $zip --repo everettjf/Saypick --clobber 2>&1 | ForEach-Object { "$_" }
if ($LASTEXITCODE -ne 0) { throw "asset upload failed" }
$ErrorActionPreference = "Stop"

Write-Output ""
Write-Output "released: https://github.com/everettjf/Saypick/releases/tag/$tag"
