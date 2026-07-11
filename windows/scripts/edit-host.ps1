# E2E 测试宿主：一个带多行文本框的窗口（标准 EDIT 控件，自带 UIA TextPattern）。
# 独立进程运行，避免测试碰到用户真实应用里的数据。
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$form = New-Object System.Windows.Forms.Form
$form.Text = "SaypickTestHost"
$form.Width = 600
$form.Height = 300
$form.StartPosition = "CenterScreen"
$tb = New-Object System.Windows.Forms.TextBox
$tb.Multiline = $true
$tb.Dock = "Fill"
$tb.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$form.Controls.Add($tb)
$form.Add_Shown({ $tb.Focus() })
[System.Windows.Forms.Application]::Run($form)
