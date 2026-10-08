$ErrorActionPreference = 'Stop'
$file = 'F:\godot fair duet\create\phase-war\.godot\unit_review\flow_mark4\ww1_mark4_grid_template_L.png'

$targets = Invoke-RestMethod -Uri 'http://127.0.0.1:9222/json' -Method Get
$page = $targets | Where-Object { $_.type -eq 'page' -and $_.url -like '*flow.google.com/project*' } | Select-Object -First 1
if (-not $page) { throw 'no page target' }
$ws = New-Object System.Net.WebSockets.ClientWebSocket
$ct = [System.Threading.CancellationToken]::None
$ws.ConnectAsync([Uri]$page.webSocketDebuggerUrl, $ct).Wait()
Write-Output "connected: $($page.url)"

function Send-Cdp($obj) {
  $json = $obj | ConvertTo-Json -Compress -Depth 8
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
  $null = $ws.SendAsync([ArraySegment[byte]]::new($bytes), [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $ct).Result
}
$script:id = 10
function Recv-CdpMsg {
  $buf = New-Object byte[] (2MB)
  $ms = New-Object System.IO.MemoryStream
  while ($true) {
    $seg = [ArraySegment[byte]]::new($buf)
    $r = $ws.ReceiveAsync($seg, $ct).Result
    if ($r.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) { throw 'closed' }
    $ms.Write($buf, 0, $r.Count)
    if ($r.EndOfMessage) { break }
  }
  [System.Text.Encoding]::UTF8.GetString($ms.ToArray()) | ConvertFrom-Json
}

Send-Cdp @{ id = 1; method = 'Page.enable' }
$null = Recv-CdpMsg
Send-Cdp @{ id = 2; method = 'Page.setInterceptFileChooserDialog'; params = @{ enabled = $true } }
$null = Recv-CdpMsg
Write-Output 'fileChooser intercept ON'

$js = "var b=[...document.querySelectorAll('button')].find(function(x){return x.textContent.indexOf('上传媒体内容')>-1}); if(b){b.click(); 'clicked'}else{'notfound'}"
$script:id++
Send-Cdp @{ id = $script:id; method = 'Runtime.evaluate'; params = @{ expression = $js; returnByValue = $true } }
$resp = Recv-CdpMsg
Write-Output "click result: $($resp.result.result.value)"

$backend = $null
foreach ($i in 1..20) {
  $m = Recv-CdpMsg
  if ($m.method -eq 'Page.fileChooserOpened') {
    $backend = $m.params.backendNodeId
    Write-Output "fileChooserOpened mode=$($m.params.mode) backend=$backend"
    break
  }
}
if (-not $backend) { throw 'no fileChooserOpened event' }

$script:id++
Send-Cdp @{ id = $script:id; method = 'DOM.setFileInputFiles'; params = @{ files = @($file); backendNodeId = $backend } }
$resp = Recv-CdpMsg
Write-Output "setFiles resp id=$($resp.id) err=$($resp.error)"

Send-Cdp @{ id = 99; method = 'Page.setInterceptFileChooserDialog'; params = @{ enabled = $false } }
Start-Sleep -Milliseconds 500
$null = $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, 'done', $ct).Result
Write-Output 'OK'
