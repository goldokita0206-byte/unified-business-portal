<<<<<<< HEAD
﻿<#
統合業務ポータル 一括セットアップスクリプト
作成日: 2026-10-18
説明: フォルダ作成→DB初期化→管理者登録→サーバー起動まで一括実行
#>

# ==============================================
# 事前準備・フォルダ構成
# ==============================================
Write-Host "=== フォルダ構成を作成中 ===" -ForegroundColor Cyan
$baseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$folders = @("data", "lib", "public")
foreach ($f in $folders) {
    $path = Join-Path $baseDir $f
    if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path | Out-Null }
}

$dataDir = Join-Path $baseDir "data"
$libDir  = Join-Path $baseDir "lib"
$pubDir  = Join-Path $baseDir "public"

# ==============================================
# 共通セキュリティ関数
# ==============================================
Write-Host "=== セキュリティモジュールを作成中 ===" -ForegroundColor Cyan
$libScript = @'
function Get-RandomString {
    param([int]$Length = 16)
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return -join (1..$Length | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
}

function Get-PasswordHash {
    param(
        [Parameter(Mandatory)][string]$Password,
        [Parameter(Mandatory)][string]$Salt
    )
    $combined = [Text.Encoding]::UTF8.GetBytes($Password + $Salt)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    return [Convert]::ToBase64String($sha256.ComputeHash($combined))
}

function Test-Password {
    param(
        [Parameter(Mandatory)][string]$InputPassword,
        [Parameter(Mandatory)][string]$StoredHash,
        [Parameter(Mandatory)][string]$StoredSalt
    )
    $computed = Get-PasswordHash $InputPassword $StoredSalt
    return ($computed -eq $StoredHash)
}

function Protect-JsonData {
    param([string]$Path, $Data)
    $Data | ConvertTo-Json -Depth 10 | Out-File $Path -Encoding UTF8
}

function Import-JsonData {
    param([string]$Path, $Default = @())
    if (-not (Test-Path $Path)) { return $Default }
    $txt = Get-Content $Path -Raw -Encoding UTF8
    return $txt | ConvertFrom-Json -Depth 10
}
'@
$libScript | Out-File (Join-Path $libDir "security.ps1") -Encoding UTF8

# ==============================================
# データベース初期化
# ==============================================
Write-Host "=== データベースを初期化中 ===" -ForegroundColor Cyan
. (Join-Path $libDir "security.ps1")

$usersPath = Join-Path $dataDir "users.json"
$logsPath  = Join-Path $dataDir "login_logs.json"
$opsPath   = Join-Path $dataDir "operations.json"

# 初回のみ管理者作成
if (-not (Test-Path $usersPath)) {
    $adminPass = "Admin@2026"  # ← 初回パスワード：利用後に必ず変更！
    $salt = Get-RandomString 24
    $hash = Get-PasswordHash $adminPass $salt

    $initialUsers = @(
        [PSCustomObject]@{
            Id           = 1
            Username     = "admin"
            PasswordHash = $hash
            Salt         = $salt
            Role         = "all"
            IsActive     = $true
            CreatedAt    = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    )
    Protect-JsonData $usersPath $initialUsers
    Write-Host "✅ 管理者アカウント作成完明 / ID:admin / Pass:$adminPass" -ForegroundColor Yellow
}

# ログファイル初期化
if (-not (Test-Path $logsPath)) { Protect-JsonData $logsPath @() }
if (-not (Test-Path $opsPath))  { Protect-JsonData $opsPath  @() }

# ==============================================
# ログインページ作成
# ==============================================
Write-Host "=== ログインページ作成中 ===" -ForegroundColor Cyan
$loginHtml = @'
<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>ログイン - 統合業務ポータル</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <style>
    body{background:linear-gradient(135deg,#1e293b 0%,#0f172a 100%); min-height:100vh;}
  </style>
</head>
<body class="flex items-center justify-center">
  <div class="w-full max-w-md p-8 bg-white/10 backdrop-blur rounded-2xl shadow-2xl border border-white/20">
    <div class="text-center mb-8">
      <div class="text-4xl mb-2">🔐</div>
      <h1 class="text-2xl font-bold text-white">統合業務ポータル</h1>
      <p class="text-slate-400 text-sm mt-1">Enterprise Unified Portal</p>
    </div>
    <form onsubmit="doLogin(event)" class="space-y-4">
      <div>
        <label class="text-slate-300 text-sm block mb-1">ユーザー名</label>
        <input type="text" id="uid" required
          class="w-full px-4 py-3 rounded-lg bg-white/10 border border-white/20 text-white focus:outline-none focus:border-blue-400">
      </div>
      <div>
        <label class="text-slate-300 text-sm block mb-1">パスワード</label>
        <input type="password" id="pwd" required
          class="w-full px-4 py-3 rounded-lg bg-white/10 border border-white/20 text-white focus:outline-none focus:border-blue-400">
      </div>
      <div id="msg" class="text-red-400 text-sm hidden"></div>
      <button type="submit" id="btn"
        class="w-full py-3 bg-blue-600 hover:bg-blue-700 text-white font-bold rounded-lg transition-colors">
        ログイン
      </button>
    </form>
  </div>
<script>
async function doLogin(e){
  e.preventDefault();
  const btn=document.getElementById('btn'), msg=document.getElementById('msg');
  btn.disabled=true; btn.textContent='認証中…'; msg.classList.add('hidden');
  try{
    const res=await fetch('/api/login',{
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify({
        username:document.getElementById('uid').value,
        password:document.getElementById('pwd').value
      })
    });
    const d=await res.json();
    if(d.success){
      localStorage.setItem('portal_session',d.session);
      localStorage.setItem('portal_role',d.role);
      location.href='/dashboard.html';
    }else{
      msg.textContent=d.error||'ログインに失敗しました';
      msg.classList.remove('hidden');
    }
  }catch(e){msg.textContent='サーバー接続エラー';msg.classList.remove('hidden');}
  btn.disabled=false; btn.textContent='ログイン';
}
</script>
</body>
</html>
'@
$loginHtml | Out-File (Join-Path $pubDir "index.html") -Encoding UTF8

# ==============================================
# ダッシュボードページ（認証付き）
# ==============================================
Write-Host "=== ダッシュボードページ作成中 ===" -ForegroundColor Cyan
$dashHtml = @'
<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>ポータル - 統合業務ポータルシステム</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <style>
    .fade-in{animation:fadeIn .25s ease-out;}
    @keyframes fadeIn{from{opacity:0;transform:translateY(6px)}to{opacity:1;transform:translateY(0)}}
    .system-card{transition:all .2s cubic-bezier(.4,0,.2,1)}
    .system-card:hover{transform:translateY(-4px);box-shadow:0 12px 24px -10px rgba(0,0,0,.15)}
  </style>
</head>
<body class="bg-slate-100 min-h-screen flex flex-col">
<script>
// 認証チェック
(async ()=>{
  const ses=localStorage.getItem('portal_session');
  if(!ses){location.href='/index.html';return}
  const v=await fetch('/api/verify',{method:'POST',headers:{'Content-Type':'application/json'},
    body:JSON.stringify({session:ses})});
  const r=await v.json();
  if(!r.valid){localStorage.clear();location.href='/index.html';return}
  window.__role=r.role;
  document.cookie=`role=${r.role};path=/`;
  initPage();
})();
</script>
<header class="bg-slate-900 text-white shadow-lg sticky top-0 z-40">
  <div class="max-w-7xl mx-auto px-4 py-3 flex flex-wrap justify-between items-center gap-4">
    <div class="flex items-center space-x-3">
      <div class="p-2 bg-blue-600 rounded-lg text-xl">❖</div>
      <div><h1 class="font-bold">統合業務ポータル</h1><p class="text-xs text-slate-400">Local AI Secure Portal</p></div>
    </div>
    <div class="flex items-center gap-3">
      <select id="role-sel" onchange="changeRole(this.value)" class="bg-slate-800 text-xs border border-slate-600 rounded px-2 py-1">
        <option value="all">全システム表示</option>
        <option value="employee">一般社員</option>
        <option value="factory">現場作業員</option>
        <option value="public">行政職員</option>
        <option value="client">取引先</option>
      </select>
      <button onclick="doLogout()" class="bg-red-600/80 hover:bg-red-600 px-3 py-1.5 rounded text-xs">ログアウト</button>
    </div>
  </div>
</header>
<main class="flex-1 max-w-7xl mx-auto p-4 sm:p-6">
  <h2 class="text-lg font-bold mb-4">🚀 業務システムハブ <span id="cnt" class="text-sm font-normal text-slate-500"></span></h2>
  <div id="grid" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 fade-in"></div>
</main>

<div class="fixed bottom-5 right-5 z-50 flex flex-col items-end">
  <div id="chat-win" class="hidden w-80 sm:w-96 bg-white rounded-2xl shadow-2xl border border-slate-200 flex flex-col mb-3" style="height:480px">
    <div class="bg-slate-900 text-white p-3 flex justify-between items-center">
      <span class="font-bold text-sm">🤖 社内AIアシスタント</span>
      <button onclick="toggleChat()" class="text-slate-400 hover:text-white font-bold">&times;</button>
    </div>
    <div id="chat-log" class="flex-1 p-3 overflow-y-auto bg-slate-50 text-xs space-y-3 text-slate-600">
      <div class="text-center py-2">ローカルAIへようこそ</div>
    </div>
    <div class="p-3 border-t flex gap-2">
      <input id="chat-in" type="text" placeholder="メッセージ入力…" class="flex-1 border rounded px-3 py-2 text-xs">
      <button onclick="sendChat()" class="bg-blue-600 text-white px-3 py-2 rounded text-xs">送信</button>
    </div>
  </div>
  <button onclick="toggleChat()" class="bg-blue-600 hover:bg-blue-700 text-white p-4 rounded-full shadow-lg text-2xl">🤖</button>
</div>

<script>
const systems=[
  {id:'sales',name:'営業支援&CRM',icon:'📈',color:'indigo',desc:'顧客・商談・見積・予実管理',roles:['all','employee']},
  {id:'public',name:'公共・行政管理',icon:'🏛️',color:'indigo-900',desc:'入札・補助金・事業計画',roles:['all','public']},
  {id:'field',name:'現場・生産管理',icon:'🏭',color:'amber',desc:'進捗・点検・不具合報告',roles:['all','factory']},
  {id:'corp',name:'コーポレート管理',icon:'🖥️',color:'teal',desc:'人事・資産・経理',roles:['all','employee']},
  {id:'portal',name:'社内ポータル&申請',icon:'🏢',color:'slate',desc:'決裁・勤怠・FAQ',roles:['all','employee','factory','public']},
  {id:'partner',name:'社外連携ポータル',icon:'🌐',color:'blue',desc:'契約・見積・進捗共有',roles:['all','client','employee']}
];
let curRole='all';
function initPage(){renderSystems()}
function renderSystems(){
  const g=document.getElementById('grid'); g.innerHTML='';
  const f=systems.filter(s=>s.roles.includes(curRole));
  document.getElementById('cnt').textContent=`(${f.length}システム)`;
  f.forEach(s=>{
    g.innerHTML+=`<div class="system-card bg-white rounded-xl border-slate-200 shadow-sm p-5">
      <h3 class="font-bold text-lg mb-2">${s.icon} ${s.name}</h3>
      <p class="text-xs text-slate-500 mb-3">${s.desc}</p>
      <button class="w-full bg-slate-900 text-white py-2 rounded text-xs">画面を開く →</button>
    </div>`;
  });
}
function changeRole(r){curRole=r;renderSystems()}
function doLogout(){localStorage.clear();location.href='/index.html'}
function toggleChat(){document.getElementById('chat-win').classList.toggle('hidden')}
async function sendChat(){
  const i=document.getElementById('chat-in'),l=document.getElementById('chat-log'),m=i.value.trim();
  if(!m)return;
  l.innerHTML+=`<div class="text-right"><span class="bg-blue-600 text-white px-3 py-2 rounded inline-block max-w-[85%]">${escape(m)}</span></div>`;
  i.value='';
  const ld=document.createElement('div');ld.className='text-left';ld.innerHTML='<span class="bg-slate-200 px-3 py-2 rounded">応答生成中…</span>';l.appendChild(ld);l.scrollTop=l.scrollHeight;
  try{
    const res=await fetch('http://localhost:11434/api/generate',{
      method:'POST',headers:{'Content-Type':'application/json'},
      body:JSON.stringify({model:'llama3',prompt:m,stream:false})
    });
    const d=await res.json();
    ld.remove();
    l.innerHTML+=`<div class="text-left"><span class="bg-white border px-3 py-2 rounded">${escape(d.response)}</span></div>`;
  }catch(e){ld.remove();l.innerHTML+='<div class="text-left text-red-500">接続エラー:ollama serveを確認</div>'}
  l.scrollTop=l.scrollHeight;
}
function escape(s){const d=document.createElement('div');d.textContent=s;return d.innerHTML}
document.getElementById('chat-in').addEventListener('keypress',e=>e.key==='Enter'&&sendChat());
</script>
</body>
</html>
'@
$dashHtml | Out-File (Join-Path $pubDir "dashboard.html") -Encoding UTF8

# ==============================================
# メインサーバースクリプト
# ==============================================
Write-Host "=== サーバースクリプト作成中 ===" -ForegroundColor Cyan
$serverScript = @'
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
'@
$serverScript | Out-File (Join-Path $baseDir "start_server.ps1") -Encoding UTF8

# ==============================================
# 完了メッセージ
# ==============================================
Write-Host ""
Write-Host "✅ 全ファイル作成完了！" -ForegroundColor Green
Write-Host "----------------------------------------"
Write-Host "📂 フォルダ:" $baseDir
Write-Host "🚀 起動コマンド:"
Write-Host "   cd `"$baseDir`""
Write-Host "   .\start_server.ps1"
Write-Host ""
Write-Host "🔑 初回ログイン情報"
Write-Host "   ユーザー名: admin"
Write-Host "   パスワード: Admin@2026"
Write-Host ""
Write-Host "⚠️  初回パスワードは必ず変更してください！" -ForegroundColor Red
Write-Host "----------------------------------------"
=======
﻿<#
統合業務ポータル 一括セットアップスクリプト
作成日: 2026-10-18
説明: フォルダ作成→DB初期化→管理者登録→サーバー起動まで一括実行
#>

# ==============================================
# 事前準備・フォルダ構成
# ==============================================
Write-Host "=== フォルダ構成を作成中 ===" -ForegroundColor Cyan
$baseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$folders = @("data", "lib", "public")
foreach ($f in $folders) {
    $path = Join-Path $baseDir $f
    if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path | Out-Null }
}

$dataDir = Join-Path $baseDir "data"
$libDir  = Join-Path $baseDir "lib"
$pubDir  = Join-Path $baseDir "public"

# ==============================================
# 共通セキュリティ関数
# ==============================================
Write-Host "=== セキュリティモジュールを作成中 ===" -ForegroundColor Cyan
$libScript = @'
function Get-RandomString {
    param([int]$Length = 16)
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return -join (1..$Length | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
}

function Get-PasswordHash {
    param(
        [Parameter(Mandatory)][string]$Password,
        [Parameter(Mandatory)][string]$Salt
    )
    $combined = [Text.Encoding]::UTF8.GetBytes($Password + $Salt)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    return [Convert]::ToBase64String($sha256.ComputeHash($combined))
}

function Test-Password {
    param(
        [Parameter(Mandatory)][string]$InputPassword,
        [Parameter(Mandatory)][string]$StoredHash,
        [Parameter(Mandatory)][string]$StoredSalt
    )
    $computed = Get-PasswordHash $InputPassword $StoredSalt
    return ($computed -eq $StoredHash)
}

function Protect-JsonData {
    param([string]$Path, $Data)
    $Data | ConvertTo-Json -Depth 10 | Out-File $Path -Encoding UTF8
}

function Import-JsonData {
    param([string]$Path, $Default = @())
    if (-not (Test-Path $Path)) { return $Default }
    $txt = Get-Content $Path -Raw -Encoding UTF8
    return $txt | ConvertFrom-Json -Depth 10
}
'@
$libScript | Out-File (Join-Path $libDir "security.ps1") -Encoding UTF8

# ==============================================
# データベース初期化
# ==============================================
Write-Host "=== データベースを初期化中 ===" -ForegroundColor Cyan
. (Join-Path $libDir "security.ps1")

$usersPath = Join-Path $dataDir "users.json"
$logsPath  = Join-Path $dataDir "login_logs.json"
$opsPath   = Join-Path $dataDir "operations.json"

# 初回のみ管理者作成
if (-not (Test-Path $usersPath)) {
    $adminPass = "Admin@2026"  # ← 初回パスワード：利用後に必ず変更！
    $salt = Get-RandomString 24
    $hash = Get-PasswordHash $adminPass $salt

    $initialUsers = @(
        [PSCustomObject]@{
            Id           = 1
            Username     = "admin"
            PasswordHash = $hash
            Salt         = $salt
            Role         = "all"
            IsActive     = $true
            CreatedAt    = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    )
    Protect-JsonData $usersPath $initialUsers
    Write-Host "✅ 管理者アカウント作成完明 / ID:admin / Pass:$adminPass" -ForegroundColor Yellow
}

# ログファイル初期化
if (-not (Test-Path $logsPath)) { Protect-JsonData $logsPath @() }
if (-not (Test-Path $opsPath))  { Protect-JsonData $opsPath  @() }

# ==============================================
# ログインページ作成
# ==============================================
Write-Host "=== ログインページ作成中 ===" -ForegroundColor Cyan
$loginHtml = @'
<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>ログイン - 統合業務ポータル</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <style>
    body{background:linear-gradient(135deg,#1e293b 0%,#0f172a 100%); min-height:100vh;}
  </style>
</head>
<body class="flex items-center justify-center">
  <div class="w-full max-w-md p-8 bg-white/10 backdrop-blur rounded-2xl shadow-2xl border border-white/20">
    <div class="text-center mb-8">
      <div class="text-4xl mb-2">🔐</div>
      <h1 class="text-2xl font-bold text-white">統合業務ポータル</h1>
      <p class="text-slate-400 text-sm mt-1">Enterprise Unified Portal</p>
    </div>
    <form onsubmit="doLogin(event)" class="space-y-4">
      <div>
        <label class="text-slate-300 text-sm block mb-1">ユーザー名</label>
        <input type="text" id="uid" required
          class="w-full px-4 py-3 rounded-lg bg-white/10 border border-white/20 text-white focus:outline-none focus:border-blue-400">
      </div>
      <div>
        <label class="text-slate-300 text-sm block mb-1">パスワード</label>
        <input type="password" id="pwd" required
          class="w-full px-4 py-3 rounded-lg bg-white/10 border border-white/20 text-white focus:outline-none focus:border-blue-400">
      </div>
      <div id="msg" class="text-red-400 text-sm hidden"></div>
      <button type="submit" id="btn"
        class="w-full py-3 bg-blue-600 hover:bg-blue-700 text-white font-bold rounded-lg transition-colors">
        ログイン
      </button>
    </form>
  </div>
<script>
async function doLogin(e){
  e.preventDefault();
  const btn=document.getElementById('btn'), msg=document.getElementById('msg');
  btn.disabled=true; btn.textContent='認証中…'; msg.classList.add('hidden');
  try{
    const res=await fetch('/api/login',{
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify({
        username:document.getElementById('uid').value,
        password:document.getElementById('pwd').value
      })
    });
    const d=await res.json();
    if(d.success){
      localStorage.setItem('portal_session',d.session);
      localStorage.setItem('portal_role',d.role);
      location.href='/dashboard.html';
    }else{
      msg.textContent=d.error||'ログインに失敗しました';
      msg.classList.remove('hidden');
    }
  }catch(e){msg.textContent='サーバー接続エラー';msg.classList.remove('hidden');}
  btn.disabled=false; btn.textContent='ログイン';
}
</script>
</body>
</html>
'@
$loginHtml | Out-File (Join-Path $pubDir "index.html") -Encoding UTF8

# ==============================================
# ダッシュボードページ（認証付き）
# ==============================================
Write-Host "=== ダッシュボードページ作成中 ===" -ForegroundColor Cyan
$dashHtml = @'
<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>ポータル - 統合業務ポータルシステム</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <style>
    .fade-in{animation:fadeIn .25s ease-out;}
    @keyframes fadeIn{from{opacity:0;transform:translateY(6px)}to{opacity:1;transform:translateY(0)}}
    .system-card{transition:all .2s cubic-bezier(.4,0,.2,1)}
    .system-card:hover{transform:translateY(-4px);box-shadow:0 12px 24px -10px rgba(0,0,0,.15)}
  </style>
</head>
<body class="bg-slate-100 min-h-screen flex flex-col">
<script>
// 認証チェック
(async ()=>{
  const ses=localStorage.getItem('portal_session');
  if(!ses){location.href='/index.html';return}
  const v=await fetch('/api/verify',{method:'POST',headers:{'Content-Type':'application/json'},
    body:JSON.stringify({session:ses})});
  const r=await v.json();
  if(!r.valid){localStorage.clear();location.href='/index.html';return}
  window.__role=r.role;
  document.cookie=`role=${r.role};path=/`;
  initPage();
})();
</script>
<header class="bg-slate-900 text-white shadow-lg sticky top-0 z-40">
  <div class="max-w-7xl mx-auto px-4 py-3 flex flex-wrap justify-between items-center gap-4">
    <div class="flex items-center space-x-3">
      <div class="p-2 bg-blue-600 rounded-lg text-xl">❖</div>
      <div><h1 class="font-bold">統合業務ポータル</h1><p class="text-xs text-slate-400">Local AI Secure Portal</p></div>
    </div>
    <div class="flex items-center gap-3">
      <select id="role-sel" onchange="changeRole(this.value)" class="bg-slate-800 text-xs border border-slate-600 rounded px-2 py-1">
        <option value="all">全システム表示</option>
        <option value="employee">一般社員</option>
        <option value="factory">現場作業員</option>
        <option value="public">行政職員</option>
        <option value="client">取引先</option>
      </select>
      <button onclick="doLogout()" class="bg-red-600/80 hover:bg-red-600 px-3 py-1.5 rounded text-xs">ログアウト</button>
    </div>
  </div>
</header>
<main class="flex-1 max-w-7xl mx-auto p-4 sm:p-6">
  <h2 class="text-lg font-bold mb-4">🚀 業務システムハブ <span id="cnt" class="text-sm font-normal text-slate-500"></span></h2>
  <div id="grid" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 fade-in"></div>
</main>

<div class="fixed bottom-5 right-5 z-50 flex flex-col items-end">
  <div id="chat-win" class="hidden w-80 sm:w-96 bg-white rounded-2xl shadow-2xl border border-slate-200 flex flex-col mb-3" style="height:480px">
    <div class="bg-slate-900 text-white p-3 flex justify-between items-center">
      <span class="font-bold text-sm">🤖 社内AIアシスタント</span>
      <button onclick="toggleChat()" class="text-slate-400 hover:text-white font-bold">&times;</button>
    </div>
    <div id="chat-log" class="flex-1 p-3 overflow-y-auto bg-slate-50 text-xs space-y-3 text-slate-600">
      <div class="text-center py-2">ローカルAIへようこそ</div>
    </div>
    <div class="p-3 border-t flex gap-2">
      <input id="chat-in" type="text" placeholder="メッセージ入力…" class="flex-1 border rounded px-3 py-2 text-xs">
      <button onclick="sendChat()" class="bg-blue-600 text-white px-3 py-2 rounded text-xs">送信</button>
    </div>
  </div>
  <button onclick="toggleChat()" class="bg-blue-600 hover:bg-blue-700 text-white p-4 rounded-full shadow-lg text-2xl">🤖</button>
</div>

<script>
const systems=[
  {id:'sales',name:'営業支援&CRM',icon:'📈',color:'indigo',desc:'顧客・商談・見積・予実管理',roles:['all','employee']},
  {id:'public',name:'公共・行政管理',icon:'🏛️',color:'indigo-900',desc:'入札・補助金・事業計画',roles:['all','public']},
  {id:'field',name:'現場・生産管理',icon:'🏭',color:'amber',desc:'進捗・点検・不具合報告',roles:['all','factory']},
  {id:'corp',name:'コーポレート管理',icon:'🖥️',color:'teal',desc:'人事・資産・経理',roles:['all','employee']},
  {id:'portal',name:'社内ポータル&申請',icon:'🏢',color:'slate',desc:'決裁・勤怠・FAQ',roles:['all','employee','factory','public']},
  {id:'partner',name:'社外連携ポータル',icon:'🌐',color:'blue',desc:'契約・見積・進捗共有',roles:['all','client','employee']}
];
let curRole='all';
function initPage(){renderSystems()}
function renderSystems(){
  const g=document.getElementById('grid'); g.innerHTML='';
  const f=systems.filter(s=>s.roles.includes(curRole));
  document.getElementById('cnt').textContent=`(${f.length}システム)`;
  f.forEach(s=>{
    g.innerHTML+=`<div class="system-card bg-white rounded-xl border-slate-200 shadow-sm p-5">
      <h3 class="font-bold text-lg mb-2">${s.icon} ${s.name}</h3>
      <p class="text-xs text-slate-500 mb-3">${s.desc}</p>
      <button class="w-full bg-slate-900 text-white py-2 rounded text-xs">画面を開く →</button>
    </div>`;
  });
}
function changeRole(r){curRole=r;renderSystems()}
function doLogout(){localStorage.clear();location.href='/index.html'}
function toggleChat(){document.getElementById('chat-win').classList.toggle('hidden')}
async function sendChat(){
  const i=document.getElementById('chat-in'),l=document.getElementById('chat-log'),m=i.value.trim();
  if(!m)return;
  l.innerHTML+=`<div class="text-right"><span class="bg-blue-600 text-white px-3 py-2 rounded inline-block max-w-[85%]">${escape(m)}</span></div>`;
  i.value='';
  const ld=document.createElement('div');ld.className='text-left';ld.innerHTML='<span class="bg-slate-200 px-3 py-2 rounded">応答生成中…</span>';l.appendChild(ld);l.scrollTop=l.scrollHeight;
  try{
    const res=await fetch('http://localhost:11434/api/generate',{
      method:'POST',headers:{'Content-Type':'application/json'},
      body:JSON.stringify({model:'llama3',prompt:m,stream:false})
    });
    const d=await res.json();
    ld.remove();
    l.innerHTML+=`<div class="text-left"><span class="bg-white border px-3 py-2 rounded">${escape(d.response)}</span></div>`;
  }catch(e){ld.remove();l.innerHTML+='<div class="text-left text-red-500">接続エラー:ollama serveを確認</div>'}
  l.scrollTop=l.scrollHeight;
}
function escape(s){const d=document.createElement('div');d.textContent=s;return d.innerHTML}
document.getElementById('chat-in').addEventListener('keypress',e=>e.key==='Enter'&&sendChat());
</script>
</body>
</html>
'@
$dashHtml | Out-File (Join-Path $pubDir "dashboard.html") -Encoding UTF8

# ==============================================
# メインサーバースクリプト
# ==============================================
Write-Host "=== サーバースクリプト作成中 ===" -ForegroundColor Cyan
$serverScript = @'
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
'@
$serverScript | Out-File (Join-Path $baseDir "start_server.ps1") -Encoding UTF8

# ==============================================
# 完了メッセージ
# ==============================================
Write-Host ""
Write-Host "✅ 全ファイル作成完了！" -ForegroundColor Green
Write-Host "----------------------------------------"
Write-Host "📂 フォルダ:" $baseDir
Write-Host "🚀 起動コマンド:"
Write-Host "   cd `"$baseDir`""
Write-Host "   .\start_server.ps1"
Write-Host ""
Write-Host "🔑 初回ログイン情報"
Write-Host "   ユーザー名: admin"
Write-Host "   パスワード: Admin@2026"
Write-Host ""
Write-Host "⚠️  初回パスワードは必ず変更してください！" -ForegroundColor Red
Write-Host "----------------------------------------"
>>>>>>> 5014a6bb678258fef484eedb9636e649cdfba0f4
Write-Host "準備完了です。上記のコマンドでサーバーを起動してください ✨"