<#
ポータル HTTPサーバー
#>
param([int]$Port=8080)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\security.ps1")

$baseDir = $PSScriptRoot
$pubDir  = Join-Path $baseDir "public"
$dataDir = Join-Path $baseDir "data"
$usersPath = Join-Path $dataDir "users.json"
$logsPath  = Join-Path $dataDir "login_logs.json"
$opsPath   = Join-Path $dataDir "operations.json"

$sessions = @{}

function LoadUsers  { return Import-JsonData $usersPath @() }
function LoadLogs   { return Import-JsonData $logsPath @() }
function SaveLogs($l){ Protect-JsonData $logsPath $l }

function New-SessionToken {
  $token = Get-RandomString 48
  $sessions[$token] = @{ UserId = $args[0]; Role = $args[1]; Attr = Get-Date }
  return $token
}

function Write-LogEntry {
  param($un,$status,$ip,$ua)
  $logs = LoadLogs
  $logs += [PSCustomObject]@{
    Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Username = $un; Status = $status; IpAddress = $ip; UserAgent = $ua
  }
  SaveLogs $logs
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
try { $listener.Start() }
catch { Write-Host "ポート $Port が使用中です。終了してから再実行してください"; exit 1 }

Write-Host "========================================" -ForegroundColor Green
Write-Host "  サーバー起動: http://localhost:$Port/" -ForegroundColor Green
Write-Host "  ログイン: admin / Admin@2026" -ForegroundColor Yellow
Write-Host "  ※ 初回パスワードは必ず変更してください" -ForegroundColor DarkYellow
Write-Host "  停止するには Ctrl+C" -ForegroundColor Gray
Write-Host "========================================"

function Send-Response {
  param($Ctx,$Data,$Code=200,$CT="application/json")
  $Ctx.Response.StatusCode = $Code
  $Ctx.Response.ContentType = $CT
  if ($Data -is [string]) { $b = [Text.Encoding]::UTF8.GetBytes($Data) }
  else { $j = $Data | ConvertTo-Json -Depth 10; $b = [Text.Encoding]::UTF8.GetBytes($j) }
  $Ctx.Response.ContentLength64 = $b.Length
  $Ctx.Response.OutputStream.Write($b,0,$b.Length)
  $Ctx.Response.Close()
}

while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $req = $ctx.Request
  $path = $req.Url.LocalPath

  if ($path -eq "/api/login") {
    $rd = New-Object IO.StreamReader($req.InputStream)
    $body = $rd.ReadToEnd() | ConvertFrom-Json
    $users = LoadUsers
    $match = $users | Where-Object { $_.Username -eq $body.username -and $_.IsActive }
    $ip = $req.RemoteEndPoint.Address.ToString()
    $ua = $req.UserAgent

    if (-not $match) {
      Write-LogEntry $body.username "failed" $ip $ua
      Send-Response $ctx @{ success = $false; error = "ユーザー名またはパスワードが違います" }
      continue
    }
    if (-not (Test-Password $body.password $match.PasswordHash $match.Salt)) {
      Write-LogEntry $body.username "failed" $ip $ua
      Send-Response $ctx @{ success = $false; error = "パスワードが違います" }
      continue
    }
    $tok = New-SessionToken $match.Id $match.Role
    Write-LogEntry $body.username "success" $ip $ua
    Send-Response $ctx @{ success = $true; session = $tok; role = $match.Role }
  }
  elseif ($path -eq "/api/verify") {
    $rd = New-Object IO.StreamReader($req.InputStream)
    $body = $rd.ReadToEnd() | ConvertFrom-Json
    $valid = $sessions.ContainsKey($body.session)
    Send-Response $ctx @{ valid = $valid; role = if ($valid) { $sessions[$body.session].Role } else { $null } }
  }
  elseif ($path -eq "/api/logout") {
    $rd = New-Object IO.StreamReader($req.InputStream)
    $body = $rd.ReadToEnd() | ConvertFrom-Json
    if ($sessions.ContainsKey($body.session)) { $sessions.Remove($body.session) }
    Send-Response $ctx @{ success = $true }
  }
  else {
    if ($path -eq "/") { $path = "/index.html" }
    $file = Join-Path $pubDir $path.TrimStart('/')
    if (Test-Path $file) {
      $txt = Get-Content $file -Raw -Encoding UTF8
      Send-Response $ctx $txt 200 "text/html; charset=utf-8"
    } else {
      Send-Response $ctx @{ error = "Not Found" } 404
    }
  }
}
$listener.Stop()
