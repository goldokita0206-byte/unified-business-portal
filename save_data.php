<<<<<<< HEAD
﻿<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=utf-8");
$input = json_decode(file_get_contents("php://input"), true);
$category = preg_replace("/[^a-zA-Z0-9_]/", "", $input["category"]);
$filename = basename($input["filename"]);
$dataDir = __DIR__ . "/data/" . $category . "/";
if (!is_dir($dataDir)) mkdir($dataDir, 0755, true);
file_put_contents($dataDir . $filename, json_encode($input["data"], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
echo json_encode(["status" => "ok", "path" => "data/$category/$filename"]);
=======
﻿<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=utf-8");
$input = json_decode(file_get_contents("php://input"), true);
$category = preg_replace("/[^a-zA-Z0-9_]/", "", $input["category"]);
$filename = basename($input["filename"]);
$dataDir = __DIR__ . "/data/" . $category . "/";
if (!is_dir($dataDir)) mkdir($dataDir, 0755, true);
file_put_contents($dataDir . $filename, json_encode($input["data"], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
echo json_encode(["status" => "ok", "path" => "data/$category/$filename"]);
>>>>>>> 5014a6bb678258fef484eedb9636e649cdfba0f4
