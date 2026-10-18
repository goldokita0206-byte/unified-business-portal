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
