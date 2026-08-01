# E2E 测试宿主（WPF TextBox，支持 UIA TextPattern → 验证 UIA 取词主路径）。
# TextChanged 时把内容写入 $SyncFile，测试脚本从文件读回验证替换结果。
param([string]$SyncFile = "$env:TEMP\typetide-wpf-sync.txt")
Add-Type -AssemblyName PresentationFramework
$window = New-Object System.Windows.Window
$window.Title = "TypeTideWpfHost"
$window.Width = 600
$window.Height = 300
$window.WindowStartupLocation = "CenterScreen"
$tb = New-Object System.Windows.Controls.TextBox
$tb.TextWrapping = "Wrap"
$tb.AcceptsReturn = $true
$tb.FontSize = 14
$tb.Text = "你好世界，今天天气很好。"
$window.Content = $tb
$tb.Add_TextChanged({
    [System.IO.File]::WriteAllText($SyncFile, $tb.Text, (New-Object System.Text.UTF8Encoding($false)))
}.GetNewClosure())
$window.Add_ContentRendered({
    $tb.Focus() | Out-Null
    $tb.SelectAll()
})
$window.ShowDialog() | Out-Null
