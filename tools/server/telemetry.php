<?php
// Bear Crawl — telemetry receiver + admin read/wipe.
// Drop this on your host (e.g. Bluehost: https://mattkelly.com/bc/telemetry.php).
// The game POSTs each player's anonymous lifetime stats here; one JSON file per
// install id is written to ./telemetry_data (protected by the .htaccess here).
//
// Two separate keys, on purpose:
//   $KEY       — the SHARED upload key. It also ships inside the public .exe, so
//                treat it as NOT secret. It only deters random internet POSTs.
//   $ADMIN_KEY — a SERVER-ONLY secret. Never in the client. Gates reading (?dump)
//                and wiping (?wipe) everyone's data. Keep this private.

$KEY       = 'mk-bc-7x9qR2wNpL';          // shared upload key (matches telemetry.gd; also in the public exe)
$ADMIN_KEY = 'bc-admin-a07f991ed98cdea548048b7f6610123db2a6eee620240469';  // PRIVATE — rotate anytime; it lives only here
$DATA      = __DIR__ . '/telemetry_data'; // per-install records live here

header('Content-Type: text/plain');

// Admin auth: prefer the X-Admin-Key HTTP header (kept OUT of access logs); fall
// back to an ?admin= query param for convenience. Constant-time compare.
function admin_ok($ADMIN_KEY) {
  $supplied = $_SERVER['HTTP_X_ADMIN_KEY'] ?? ($_GET['admin'] ?? '');
  return is_string($supplied) && hash_equals($ADMIN_KEY, $supplied);
}

// ── Admin: DUMP every record as JSON (so the report tool can pull all players) ──
// curl -H "X-Admin-Key: <ADMIN_KEY>" "https://.../bc/telemetry.php?dump=1"
if (isset($_GET['dump'])) {
  if (!admin_ok($ADMIN_KEY)) { http_response_code(403); exit('forbidden'); }
  header('Content-Type: application/json');
  $out = array();
  if (is_dir($DATA)) {
    foreach (glob("$DATA/*.json") as $f) {
      $d = json_decode(@file_get_contents($f), true);
      if (is_array($d)) { $out[] = $d; }
    }
  }
  echo json_encode(array('count' => count($out), 'players' => $out));
  exit;
}

// ── Admin: WIPE stored records (reset the dataset between test rounds) ─────────
// curl -H "X-Admin-Key: <ADMIN_KEY>" "https://.../bc/telemetry.php?wipe=all"
// optional &keep=<id>,<id> to spare specific install ids
if (isset($_GET['wipe'])) {
  if (!admin_ok($ADMIN_KEY)) { http_response_code(403); exit('forbidden'); }
  $keep = array();
  if (!empty($_GET['keep'])) {
    foreach (explode(',', (string)$_GET['keep']) as $k) {
      $k = preg_replace('/[^a-f0-9]/', '', $k);
      if ($k !== '') { $keep[$k] = true; }
    }
  }
  $n = 0;
  if (is_dir($DATA)) {
    foreach (glob("$DATA/*.json") as $f) {
      if (isset($keep[basename($f, '.json')])) { continue; }
      if (@unlink($f)) { $n++; }
    }
  }
  exit("wiped $n");
}

// ── Upload (from the game), gated by the shared key ───────────────────────────
$raw = file_get_contents('php://input');
if (strlen($raw) > 1000000) { http_response_code(413); exit('too big'); }
$j = json_decode($raw, true);
if (!is_array($j) || !hash_equals($KEY, (string)($j['key'] ?? ''))) { http_response_code(403); exit('forbidden'); }

// install id is our random uuid (hex only) — anonymous, not hardware/IP based.
$id = preg_replace('/[^a-f0-9]/', '', (string)($j['id'] ?? ''));
if (strlen($id) < 8) { http_response_code(400); exit('bad id'); }

if (!is_dir($DATA)) { mkdir($DATA, 0700, true); }

$rec = array(
  'id'      => $id,
  'version' => (string)($j['version'] ?? ''),
  'ts'      => (int)($j['ts'] ?? time()),
  'country' => $_SERVER['HTTP_CF_IPCOUNTRY'] ?? '',
  'stats'   => $j['stats'] ?? array(),
);
// stats are CUMULATIVE lifetime — just overwrite this install's latest snapshot.
file_put_contents("$DATA/$id.json", json_encode($rec));
echo 'ok';
