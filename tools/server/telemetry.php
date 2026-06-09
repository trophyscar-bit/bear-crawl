<?php
// Bear Crawl — telemetry receiver.
// Drop this on your host (e.g. Bluehost: https://mattkelly.com/bc/telemetry.php),
// set the SAME key here and in scripts/telemetry.gd, and the game will POST each
// player's anonymous lifetime stats here. One JSON file per install id is written
// to ./telemetry_data (protected by the .htaccess in this folder).

$KEY  = 'CHANGE_ME';                 // <-- must match SHARED_KEY in telemetry.gd
$DATA = __DIR__ . '/telemetry_data'; // per-install records live here

header('Content-Type: text/plain');

$raw = file_get_contents('php://input');
if (strlen($raw) > 1000000) { http_response_code(413); exit('too big'); }
$j = json_decode($raw, true);
if (!is_array($j) || ($j['key'] ?? '') !== $KEY) { http_response_code(403); exit('forbidden'); }

// install id is our random uuid (hex only) — anonymous, not hardware/IP based.
$id = preg_replace('/[^a-f0-9]/', '', (string)($j['id'] ?? ''));
if (strlen($id) < 8) { http_response_code(400); exit('bad id'); }

if (!is_dir($DATA)) { mkdir($DATA, 0700, true); }

$rec = array(
  'id'      => $id,
  'version' => (string)($j['version'] ?? ''),
  'ts'      => (int)($j['ts'] ?? time()),
  'ip'      => $_SERVER['REMOTE_ADDR'] ?? '',   // for rough geo only; not used as the key
  'country' => $_SERVER['HTTP_CF_IPCOUNTRY'] ?? '',
  'stats'   => $j['stats'] ?? array(),
);
// stats are CUMULATIVE lifetime — just overwrite this install's latest snapshot.
file_put_contents("$DATA/$id.json", json_encode($rec));
echo 'ok';
