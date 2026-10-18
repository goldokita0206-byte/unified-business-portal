<<<<<<< HEAD
﻿<?php
header("Content-Type: application/json; charset=utf-8");
$category = preg_replace("/[^a-zA-Z0-9_]/", "", $_GET["category"]);
$file = basename($_GET["file"]);
$path = __DIR__ . "/data/" . $category . "/" . $file;
if (!file_exists($path)) { echo json_encode(["error" => "not found"]); exit; }
echo file_get_contents($path);
=======
﻿<?php
header("Content-Type: application/json; charset=utf-8");
$category = preg_replace("/[^a-zA-Z0-9_]/", "", $_GET["category"]);
$file = basename($_GET["file"]);
$path = __DIR__ . "/data/" . $category . "/" . $file;
if (!file_exists($path)) { echo json_encode(["error" => "not found"]); exit; }
echo file_get_contents($path);
>>>>>>> 5014a6bb678258fef484eedb9636e649cdfba0f4
