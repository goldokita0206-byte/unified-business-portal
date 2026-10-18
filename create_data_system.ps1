# 統合ポータル データ管理機能 一括作成スクリプト
$ErrorActionPreference = "Stop"
$baseDir = Get-Location
$dataDir = Join-Path $baseDir "data"

Write-Host "=== データフォルダ構成を作成中 ===" -ForegroundColor Cyan

# フォルダ作成
$folders = @("sales","production","public","corporate","application","partner","assets/js")
if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir | Out-Null }
foreach ($f in $folders) {
    $path = Join-Path $dataDir $f
    if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
}
$jsDir = Join-Path $baseDir "assets/js"
if (-not (Test-Path $jsDir)) { New-Item -ItemType Directory -Path $jsDir -Force | Out-Null }

Write-Host "フォルダ作成完了" -ForegroundColor Green

# 共通JavaScriptライブラリ
$commonJs = @'
const PORT = 8080;
const BASE_DATA_PATH = "./data/";

async function saveData(category, data) {
  const timestamp = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19);
  const filename = `${category}_${timestamp}.json`;
  const response = await fetch("/save_data.php", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ category, filename, data })
  });
  return await response.json();
}

async function listFiles(category) {
  const res = await fetch(`/list_data.php?category=${category}`);
  return await res.json();
}

async function loadData(category, filename) {
  const res = await fetch(`/load_data.php?category=${category}&file=${filename}`);
  return await res.json();
}

function formToJSON(formId) {
  const form = document.getElementById(formId);
  if (!form) return {};
  const formData = new FormData(form);
  const obj = {};
  formData.forEach((v, k) => obj[k] = v);
  obj["更新日時"] = new Date().toLocaleString("ja-JP");
  return obj;
}
'@

$jsPath = Join-Path $jsDir "data_manager.js"
Set-Content -Path $jsPath -Value $commonJs -Encoding UTF8
Write-Host "共通スクリプト作成: data_manager.js" -ForegroundColor Green

# データ保存用PHP
$savePhp = @'
<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=utf-8");
$input = json_decode(file_get_contents("php://input"), true);
$category = preg_replace("/[^a-zA-Z0-9_]/", "", $input["category"]);
$filename = basename($input["filename"]);
$dataDir = __DIR__ . "/data/" . $category . "/";
if (!is_dir($dataDir)) mkdir($dataDir, 0755, true);
file_put_contents($dataDir . $filename, json_encode($input["data"], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
echo json_encode(["status" => "ok", "path" => "data/$category/$filename"]);
'@
Set-Content -Path (Join-Path $baseDir "save_data.php") -Value $savePhp -Encoding UTF8

# 一覧取得用PHP
$listPhp = @'
<?php
header("Content-Type: application/json; charset=utf-8");
$category = preg_replace("/[^a-zA-Z0-9_]/", "", $_GET["category"]);
$dir = __DIR__ . "/data/" . $category . "/";
if (!is_dir($dir)) { echo json_encode([]); exit; }
$files = scandir($dir);
$list = [];
foreach ($files as $f) {
  if (pathinfo($f, PATHINFO_EXTENSION) === "json") $list[] = $f;
}
rsort($list);
echo json_encode($list);
'@
Set-Content -Path (Join-Path $baseDir "list_data.php") -Value $listPhp -Encoding UTF8

# 読込用PHP
$loadPhp = @'
<?php
header("Content-Type: application/json; charset=utf-8");
$category = preg_replace("/[^a-zA-Z0-9_]/", "", $_GET["category"]);
$file = basename($_GET["file"]);
$path = __DIR__ . "/data/" . $category . "/" . $file;
if (!file_exists($path)) { echo json_encode(["error" => "not found"]); exit; }
echo file_get_contents($path);
'@
Set-Content -Path (Join-Path $baseDir "load_data.php") -Value $loadPhp -Encoding UTF8

Write-Host "サーバー側処理ファイル作成完了" -ForegroundColor Green

# 各画面用サンプルフォーム埋め込みスクリプト
$sampleHtml = @'
<!-- ▼ 各HTMLファイルの</body>直前に追加 ▼ -->
<script src="assets/js/data_manager.js"></script>
<script>
const CATEGORY = "@@CATEGORY@@";

async function saveCurrentForm() {
  const data = formToJSON("mainForm");
  const res = await saveData(CATEGORY, data);
  alert("保存しました: " + res.path);
  refreshFileList();
}

async function refreshFileList() {
  const list = await listFiles(CATEGORY);
  const sel = document.getElementById("fileSelector");
  sel.innerHTML = `<option value="">-- 過去データを選択 --</option>`;
  list.forEach(f => sel.innerHTML += `<option value="${f}">${f}</option>`);
}

async function loadSelected() {
  const sel = document.getElementById("fileSelector").value;
  if (!sel) return;
  const data = await loadData(CATEGORY, sel);
  Object.keys(data).forEach(k => {
    const el = document.querySelector(`[name="${k}"]`);
    if (el) el.value = data[k];
  });
}
</script>

<!-- フォーム下部に追加 -->
<div style="margin-top:20px;padding:15px;background:#f5f5f5;border-radius:8px;">
  <button onclick="saveCurrentForm()" style="padding:8px 20px;background:#2563eb;color:#fff;border:none;border-radius:4px;cursor:pointer;">💾 保存</button>
  <select id="fileSelector" onchange="loadSelected()" style="padding:6px;margin-left:10px;min-width:250px;">
    <option value="">-- 過去データを選択 --</option>
  </select>
</div>
'@
$samplePath = Join-Path $baseDir "保存読込機能_追加用.txt"
Set-Content -Path $samplePath -Value $sampleHtml -Encoding UTF8

Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  一括作成 完了！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "データ保存先: $dataDir"
Write-Host "共通JS: assets/js/data_manager.js"
Write-Host "追加サンプル: 保存読込機能_追加用.txt"
Write-Host ""
Write-Host "各画面のHTMLに「保存読込機能_追加用.txt」の内容を貼り付け、"
Write-Host "CATEGORY定数を対応するカテゴリ名に置き換えてください"
Write-Host ""