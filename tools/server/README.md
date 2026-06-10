# Bear Crawl telemetry — setup (PRIVATE TESTING)

For private testers only. Collects gameplay stats keyed by a random per-install
UUID (no hardware fingerprint, no stored IP). Same metrics the in-game STATS
screen shows. The build always reports while an endpoint is configured.

## Keys (two of them, on purpose)
- **`$KEY`** — the SHARED upload key. It also ships inside the public `.exe`, so
  treat it as **not secret**; it only deters random internet POSTs.
- **`$ADMIN_KEY`** — a **server-only** secret. Never in the client. Gates reading
  (`?dump`) and wiping (`?wipe`) everyone's data. Keep it private; rotate anytime.

Both are pre-filled in `telemetry.php`. The admin key is currently:
`bc-admin-a07f991ed98cdea548048b7f6610123db2a6eee620240469`

## 1. Deploy / update the receiver (Bluehost)
Upload `telemetry.php` **and** `.htaccess` into `public_html/bc/`
→ `http://bc.mattkelly.com/telemetry.php`.
Re-uploading the new `telemetry.php` is safe: it keeps the same `$KEY`, so testers'
uploads keep working — it just adds the admin read/wipe endpoints. The `.htaccess`
blocks anyone from browsing/downloading `telemetry_data/`.

## 2. Pull everyone's stats on demand (admin)
The admin key goes in a **header** (kept out of server access logs), not the URL:
```
curl -s -H "X-Admin-Key: bc-admin-a07f991ed98cdea548048b7f6610123db2a6eee620240469" \
  "http://bc.mattkelly.com/telemetry.php?dump=1" -o dump.json
python tools/analytics_report.py dump.json
```
That writes the combined dashboard (`analytics_report.html`) + a per-player report
for each install id (`players/<id>.html`), with the roster and Back-Shot/TTK
sections across the whole player base. (Use `curl`, not Python's urllib —
Cloudflare's WAF flags urllib's TLS fingerprint.)

## 3. Wipe the dataset (admin, between test rounds)
```
curl -s -H "X-Admin-Key: <ADMIN_KEY>" "http://bc.mattkelly.com/telemetry.php?wipe=all"
# keep specific ids:  ...?wipe=all&keep=4d617474,<id>
```

## Alternative (no admin endpoint)
You can still just download the `telemetry_data` folder from cPanel and run
`python tools/analytics_report.py path/to/telemetry_data`.
