# Bear Crawl telemetry — setup

Collects **anonymous gameplay stats** from players (no personal data, no hardware
fingerprint — just a random per-install UUID + the same metrics the in-game STATS
screen shows). Players can opt out in the pause menu.

## 1. Host the receiver (Bluehost)
1. Pick a shared key (any random string).
2. Edit `telemetry.php` → set `$KEY` to it.
3. Upload `telemetry.php` **and** `.htaccess` into a folder on your site,
   e.g. `public_html/bc/` → `https://mattkelly.com/bc/telemetry.php`.
4. The script auto-creates `bc/telemetry_data/` and writes one `<id>.json` per
   player there. The `.htaccess` blocks anyone from browsing/downloading it.

## 2. Turn it on in the game
In `scripts/telemetry.gd`:
```
const ENDPOINT  := "https://mattkelly.com/bc/telemetry.php"
const SHARED_KEY := "<same key as the PHP>"
```
Rebuild + release. Players' lifetime stats now upload on each run end (rate-limited).

## 3. Disclose it
Add a line to your itch/GitHub page and ideally a first-run notice, e.g.:
> "Bear Crawl sends anonymous gameplay statistics to help balance the game.
>  Turn it off any time in Settings."

## 4. View everyone's data
Download the `telemetry_data` folder (cPanel File Manager / FTP), then:
```
python tools/analytics_report.py path/to/telemetry_data
```
It merges every player's stats into one dashboard (player count, combined charts,
enemy TTK across the whole player base, etc.).
