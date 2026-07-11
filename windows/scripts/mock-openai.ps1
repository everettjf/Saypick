# 翻译后端 mock：
#   POST */chat/completions → OpenAI 风格 SSE 流式
#   POST /api/generate      → Ollama 风格 NDJSON 流式
# 测试用：让 Saypick 的两种后端都有可对接的本地端点。
# 用法: .\mock-openai.ps1 [-Port 8199] [-Reply "TRANSLATED_TEXT"]
param(
    [int]$Port = 8199,
    [string]$Reply = "MOCK_TRANSLATION_OK"
)
$ErrorActionPreference = "Stop"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Start()
Write-Output "mock backend listening on http://127.0.0.1:$Port"
while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response
    $null = (New-Object System.IO.StreamReader($req.InputStream)).ReadToEnd()
    Write-Output "request: $($req.HttpMethod) $($req.Url.AbsolutePath)"
    $isOpenAI = $req.Url.AbsolutePath -like "*/chat/completions"
    $isOllama = $req.Url.AbsolutePath -eq "/api/generate"
    if (-not ($isOpenAI -or $isOllama)) {
        $res.StatusCode = 404; $res.Close(); continue
    }
    $res.StatusCode = 200
    $res.ContentType = if ($isOpenAI) { "text/event-stream" } else { "application/x-ndjson" }
    $res.SendChunked = $true
    $writer = New-Object System.IO.StreamWriter($res.OutputStream, (New-Object System.Text.UTF8Encoding($false)))  # 无 BOM
    # 把回复拆成两个 delta 模拟流式
    $half = [int][Math]::Ceiling($Reply.Length / 2)
    foreach ($part in @($Reply.Substring(0, $half), $Reply.Substring($half))) {
        if ($isOpenAI) {
            $json = '{"choices":[{"delta":{"content":' + (ConvertTo-Json $part) + '}}]}'
            $writer.Write("data: $json`n`n")
        } else {
            $json = '{"response":' + (ConvertTo-Json $part) + ',"done":false}'
            $writer.Write("$json`n")
        }
        $writer.Flush()
        Start-Sleep -Milliseconds 60
    }
    if ($isOpenAI) { $writer.Write("data: [DONE]`n`n") }
    else { $writer.Write('{"response":"","done":true}' + "`n") }
    $writer.Flush()
    $res.Close()
}
