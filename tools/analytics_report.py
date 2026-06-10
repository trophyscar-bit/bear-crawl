#!/usr/bin/env python3
"""Bear Crawl — analytics report generator.

Reads the game's lifetime analytics (user://analytics.json, written by the in-game
Stats autoload) and builds a self-contained HTML dashboard with charts + balance
suggestions. Run it any time after playing some runs:

    python tools/analytics_report.py            # auto-finds the save
    python tools/analytics_report.py <path.json>

Writes analytics_report.html next to this repo and opens it in your browser.
"""
import os, sys, json, glob, webbrowser, html, datetime, base64, io

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
ASSETS = os.path.join(REPO, "assets")
try:
    from PIL import Image
    _PIL = True
except Exception:
    _PIL = False

# Friendly names for known install ids (server keeps hex only; "4d617474" = "Matt" in ASCII).
NAME_MAP = {
    "4d617474": "Matt",
}

# Test / legacy install ids to drop from every report (junk uploads, pre-rename
# data, etc.). Anything listed here is skipped when loading the dataset.
IGNORE_IDS = {
    "aaaa1111test",                       # early connectivity test
    "46489ff34e9d2ceb2b4ac45bc04e7582",   # Matt's pre-rename random id (now "4d617474")
}

# mob scene-name -> (sprite file, frame_count for spritesheets)
ICON_MAP = {
    "skeleton": ("skeleton_walk.png", 13), "sword_skeleton": ("sword_skel_idle.png", 8),
    "enemy": ("dark_bear.png", 1), "seal": ("seal.png", 1), "duckling": ("duck.png", 1),
    "plush_brawler": ("plush_brawler_front.png", 1), "hound": ("hound.png", 1),
    "frost_cub": ("frost_cub.png", 1), "cream_bear": ("cream_bear.png", 1),
    "beanie_bear": ("beanie_bear.png", 1), "teddy_bear": ("teddy_bear.png", 1),
    "army_bear": ("army_bear.png", 1), "gun_bear": ("gun_bear.png", 1),
    "growler": ("growler.png", 1), "shrinkwrap_bear": ("shrinkwrap_bear.png", 1),
}
_icache = {}

def mob_icon(t, px=40):
    """A small base64 PNG icon for a mob type (empty string if unavailable)."""
    if not _PIL:
        return ""
    if t in _icache:
        return _icache[t]
    fname, frames = ICON_MAP.get(t, (str(t) + ".png", 1))
    fp = os.path.join(ASSETS, fname)
    tag = ""
    if os.path.exists(fp):
        try:
            im = Image.open(fp).convert("RGBA")
            if frames > 1:
                im = im.crop((0, 0, im.width // frames, im.height))
            bb = im.getbbox()
            if bb:
                im = im.crop(bb)
            im.thumbnail((px, px), Image.LANCZOS)
            canvas = Image.new("RGBA", (px, px), (0, 0, 0, 0))
            canvas.alpha_composite(im, ((px - im.width) // 2, (px - im.height) // 2))
            buf = io.BytesIO(); canvas.save(buf, "PNG")
            uri = "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()
            tag = '<img class="mico" src="%s">' % uri
        except Exception:
            tag = ""
    _icache[t] = tag
    return tag

def find_json():
    if len(sys.argv) > 1 and os.path.exists(sys.argv[1]):
        return sys.argv[1]
    cands = []
    appdata = os.environ.get("APPDATA", "")
    if appdata:
        cands += glob.glob(os.path.join(appdata, "Godot", "app_userdata", "*", "analytics.json"))
    cands += glob.glob(os.path.join(REPO, "**", "analytics.json"), recursive=True)
    cands = [c for c in cands if os.path.exists(c)]
    if not cands:
        return None
    return max(cands, key=os.path.getmtime)

def pct(part, whole):
    return (100.0 * part / whole) if whole else 0.0

def mmss(seconds):
    s = int(round(seconds))
    return f"{s // 60}:{s % 60:02d}"

def bar_chart(title, d, total=None, unit="", fmt="{:.0f}", color="#caa15a", top=12, icons=False):
    items = sorted(d.items(), key=lambda kv: kv[1], reverse=True)[:top]
    if not items:
        return f'<div class="card"><h3>{html.escape(title)}</h3><p class="muted">(no data)</p></div>'
    tot = total if total is not None else sum(d.values())
    mx = max((v for _, v in items), default=1) or 1
    rows = ""
    for k, v in items:
        w = 100.0 * v / mx
        share = f" · {pct(v, tot):.0f}%" if tot else ""
        ic = mob_icon(str(k), 22) if icons else ""
        rows += (f'<div class="row"><div class="lbl">{ic}{html.escape(str(k))}</div>'
                 f'<div class="track"><div class="fill" style="width:{w:.1f}%;background:{color}"></div>'
                 f'<span class="val">{fmt.format(v)}{unit}{share}</span></div></div>')
    return f'<div class="card"><h3>{html.escape(title)}</h3>{rows}</div>'

def line_chart(title, ys, color="#6fd3ff"):
    if len(ys) < 2:
        return f'<div class="card"><h3>{html.escape(title)}</h3><p class="muted">(need 2+ runs)</p></div>'
    W, H, P = 640, 180, 24
    mn, mx = min(ys), max(ys)
    rng = (mx - mn) or 1
    pts = []
    for i, y in enumerate(ys):
        x = P + (W - 2 * P) * (i / (len(ys) - 1))
        yy = (H - P) - (H - 2 * P) * ((y - mn) / rng)
        pts.append(f"{x:.1f},{yy:.1f}")
    poly = " ".join(pts)
    return (f'<div class="card"><h3>{html.escape(title)}</h3>'
            f'<svg viewBox="0 0 {W} {H}" class="line">'
            f'<polyline points="{poly}" fill="none" stroke="{color}" stroke-width="2"/>'
            f'<text x="{P}" y="14" class="ax">{mx:g}</text>'
            f'<text x="{P}" y="{H-6}" class="ax">{mn:g}</text></svg></div>')

def _merge_into(dst, src):
    dst["runs"] = int(dst.get("runs", 0)) + int(src.get("runs", 0))
    dst["best_floor"] = max(int(dst.get("best_floor", 0)), int(src.get("best_floor", 0)))
    dt = dst.setdefault("totals", {})
    for k, v in src.get("totals", {}).items():
        dt[k] = float(dt.get(k, 0)) + float(v)
    for d in ["outcomes", "weapons_by_rarity", "upgrades_picked", "shop_bought",
              "mobs_spawned", "mobs_killed", "damage_sources", "kills_by_weapon", "weapon_equips"]:
        dd = dst.setdefault(d, {})
        for k, v in src.get(d, {}).items():
            dd[k] = int(dd.get(k, 0)) + int(v)
    led = dst.setdefault("enemy_detail", {})
    for t, e in src.get("enemy_detail", {}).items():
        cur = led.setdefault(t, {"count": 0, "ttk_sum": 0.0, "hits_sum": 0, "dmg_sum": 0})
        for k, v in e.items():
            cur[k] = float(cur.get(k, 0)) + float(v)
    dst.setdefault("history", []).extend(src.get("history", []))

def load_data():
    """Returns (merged_life_dict, n_players). A directory arg merges every
    per-install file in it (the downloaded telemetry_data); else a single save."""
    arg = sys.argv[1] if len(sys.argv) > 1 else None
    if arg and os.path.isdir(arg):
        merged, n = {}, 0
        for fp in sorted(glob.glob(os.path.join(arg, "*.json"))):
            try:
                d = json.load(open(fp, encoding="utf-8"))
                _merge_into(merged, d.get("stats", d))
                n += 1
            except Exception:
                pass
        return merged, n
    p = arg if (arg and os.path.exists(arg)) else find_json()
    if not p:
        return None, 0
    return json.load(open(p, encoding="utf-8")), 1

def render_html(L, players, extra_top=""):
    runs = int(L.get("runs", 0))
    if runs == 0:
        return None
    T = L.get("totals", {})
    per = lambda k: float(T.get(k, 0.0)) / runs
    oc = L.get("outcomes", {})
    wins = int(oc.get("victory", 0)); deaths = int(oc.get("died", 0))
    hist = L.get("history", [])
    ed = L.get("enemy_detail", {})
    equips = L.get("weapon_equips", {})
    picks = L.get("upgrades_picked", {})

    # ── summary cards ─────────────────────────────────────────────────────────
    # "Win rate" removed — there's no win condition, so it was always 0%.
    # "Dmg taken/hit" = how hard an enemy hit lands on YOU (not your output).
    avg_dph = per("damage_taken") / max(1.0, per("hits_taken"))
    summ = [
        ("Players", f"{players}"),
        ("Runs", f"{runs}"),
        ("Best floor", f"{int(L.get('best_floor', 0))}"),
        ("Avg floor", f"{per('floor_reached'):.1f}"),
        ("Avg run", mmss(per('duration'))),
        ("Avg levels", f"{per('levels'):.1f}"),
        ("Avg gold", f"{per('gold_gained'):.0f}"),
        ("Dmg taken/hit", f"{avg_dph:.1f}"),
        ("Avg alive peak", f"{per('alive_peak'):.0f}"),
    ]
    scards = "".join(f'<div class="stat"><div class="num">{v}</div><div class="cap">{k}</div></div>' for k, v in summ)

    # ── enemy table ───────────────────────────────────────────────────────────
    # Tankiness now leads with HITS-TO-KILL and EFFECTIVE HP (avg damage dealt to
    # kill one — weapon-independent), since time-to-kill is noisy. "Fight time" is
    # the reworked TTK: active combat only, not wall-clock-since-first-hit.
    spawned = L.get("mobs_spawned", {})
    erows = ""
    for t, e in sorted(ed.items(), key=lambda kv: kv[1].get("hits_sum", 0) / max(1, kv[1].get("count", 1)), reverse=True):
        c = max(1, int(e.get("count", 0)))
        sp = int(spawned.get(t, 0))
        ttk = e.get("ttk_sum", 0) / c
        hits = e.get("hits_sum", 0) / c
        hp = e.get("dmg_sum", 0) / c
        erows += (f"<tr><td>{mob_icon(t, 30)}{html.escape(t)}</td><td>{sp}</td><td>{int(e['count'])}</td>"
                  f"<td><b>{hits:.1f}</b></td><td>{hp:.0f}</td><td>{ttk:.1f}s</td></tr>")
    etable = (f'<div class="card wide"><h3>Enemy tankiness</h3><table>'
              f'<tr><th>type</th><th>spawned</th><th>killed</th>'
              f'<th>hits&#8203;-to-kill</th><th>effective HP</th><th>fight time</th></tr>{erows}</table></div>')

    # ── suggestions / heuristics ──────────────────────────────────────────────
    sug = []
    etot = sum(equips.values()) or 1
    for w, n in sorted(equips.items(), key=lambda kv: kv[1], reverse=True):
        if pct(n, etot) >= 45:
            sug.append(("warn", f"<b>{html.escape(w)}</b> is used {pct(n, etot):.0f}% of the time — dominant pick. Consider buffing alternatives or toning it down."))
        break
    ptot = sum(picks.values()) or 1
    for u, n in sorted(picks.items(), key=lambda kv: kv[1], reverse=True):
        if pct(n, ptot) >= 35:
            sug.append(("warn", f"Level-up <b>{html.escape(u)}</b> picked {pct(n, ptot):.0f}% of the time — likely a no-brainer; review its power/cost."))
        break
    # Tankiness flags use HITS-to-kill now (unambiguous), not the noisy time metric.
    for t, e in ed.items():
        c = max(1, int(e.get("count", 0)))
        if c < 5:
            continue
        hits = e.get("hits_sum", 0) / c
        if hits < 1.5:
            sug.append(("info", f"{mob_icon(t, 26)}<b>{html.escape(t)}</b> dies in ~{hits:.1f} hits — trivial / maybe too weak."))
        elif hits > 10:
            sug.append(("warn", f"{mob_icon(t, 26)}<b>{html.escape(t)}</b> takes ~{hits:.1f} hits to kill — may feel too spongy."))
    # No win condition exists, so there's no win-rate signal. Death rate ~100% is
    # expected (every run ends in death); only flag if runs are ending very fast.
    if runs >= 5 and (T.get("duration", 0) / runs) < 60:
        sug.append(("warn", f"Average run is only {mmss(T.get('duration',0)/runs)} — players may be dying too fast."))
    if not sug:
        sug.append(("info", "Nothing jumps out yet — play more runs for clearer signal."))
    # ── Back Shot effectiveness ───────────────────────────────────────────────
    kb = int(T.get("kills_from_behind", 0))   # kills by the rear (Back Shot) volley
    kf = int(T.get("kills_from_front", 0))     # kills by normal shots
    ktot = kb + kf
    if ktot > 0:
        back_pct = pct(kb, ktot)
        bs_cards = (
            f'<div class="stat"><div class="num">{back_pct:.0f}%</div><div class="cap">kills from Back Shot</div></div>'
            f'<div class="stat"><div class="num">{kb}</div><div class="cap">back-shot kills</div></div>'
            f'<div class="stat"><div class="num">{kf}</div><div class="cap">front kills</div></div>'
        )
        backshot_html = (f'<div class="section">Back Shot effectiveness</div>'
                         f'<div class="stats">{bs_cards}</div>'
                         f'<p class="muted" style="margin:6px 2px">Share of all kills dealt by the rear (Back Shot) volley. '
                         f'A high share suggests the back volley is carrying too much — consider reducing its damage.</p>')
        if back_pct >= 35:
            sug.append(("warn", f"Back Shot rear volley scored <b>{back_pct:.0f}%</b> of all kills — it may be too strong; consider reduced rear-volley damage."))
    else:
        backshot_html = ""

    sug_html = "".join(f'<div class="sug {c}">{m}</div>' for c, m in sug)

    # ── charts ────────────────────────────────────────────────────────────────
    charts = "".join([
        bar_chart("Weapon pick % (equips)", equips, color="#e08a3c"),
        bar_chart("Kills by weapon", L.get("kills_by_weapon", {}), color="#d65c93"),
        bar_chart("Level-up picks", picks, color="#69c98c"),
        bar_chart("Shop buys", L.get("shop_bought", {}), color="#caa15a"),
        bar_chart("Most-spawned mobs", spawned, color="#7d88c0", icons=True),
        bar_chart("Damage sources", L.get("damage_sources", {}), color="#e0584e"),
        bar_chart("Weapon drops by rarity", L.get("weapons_by_rarity", {}), color="#9b8cff"),
        line_chart("Floor reached per run", [int(h.get("floor", 1)) for h in hist]),
        line_chart("Gold per run", [int(h.get("gold", 0)) for h in hist], color="#caa15a"),
    ])

    page = f"""<!doctype html><html><head><meta charset="utf-8">
<title>Bear Crawl — Balance Report</title><style>
body{{background:#14110c;color:#eadfce;font-family:Segoe UI,Arial,sans-serif;margin:0;padding:24px}}
h1{{color:#ffd76b;margin:0 0 2px}} .sub{{color:#9c876a;margin:0 0 18px}}
.stats{{display:flex;flex-wrap:wrap;gap:12px;margin-bottom:20px}}
.stat{{background:#221a10;border:1px solid #4a3418;border-radius:10px;padding:12px 18px;min-width:96px;text-align:center}}
.num{{font-size:26px;color:#ffd76b;font-weight:700}} .cap{{font-size:12px;color:#b09371}}
.grid{{display:flex;flex-wrap:wrap;gap:16px}}
.card{{background:#1d1710;border:1px solid #4a3418;border-radius:12px;padding:16px;width:360px}}
.card.wide{{width:752px}} h3{{margin:0 0 12px;color:#ffd76b;font-size:16px}}
.row{{display:flex;align-items:center;margin:5px 0;font-size:13px}}
.lbl{{width:120px;color:#cdb796;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}}
.track{{flex:1;background:#0e0b07;border-radius:5px;height:20px;position:relative}}
.fill{{height:100%;border-radius:5px}} .val{{position:absolute;right:8px;top:1px;font-size:12px;color:#eadfce}}
table{{width:100%;border-collapse:collapse;font-size:13px}} th,td{{padding:5px 8px;text-align:right;border-bottom:1px solid #3a2a14}}
th:first-child,td:first-child{{text-align:left}} th{{color:#caa15a}}
.muted{{color:#7d6a4f}} svg.line{{width:100%;height:auto;background:#0e0b07;border-radius:8px}} .ax{{fill:#7d6a4f;font-size:11px}}
a{{color:#6fd3ff;text-decoration:none}} a:hover{{text-decoration:underline}}
.mico{{vertical-align:middle;margin-right:6px;image-rendering:pixelated}}
.sug{{padding:10px 14px;border-radius:8px;margin:6px 0;font-size:14px}}
.sug.warn{{background:#3a2410;border:1px solid #8a5a1e}} .sug.info{{background:#10243a;border:1px solid #2a5a8a}}
.section{{margin:22px 0 8px;color:#ffd76b;font-size:18px}}
</style></head><body>
<h1>🐻 Bear Crawl — Balance Report</h1>
<p class="sub">{players} player(s) · {runs} runs · generated {datetime.datetime.now():%Y-%m-%d %H:%M}</p>
<div class="stats">{scards}</div>
{extra_top}
{backshot_html}
<div class="section">Suggestions</div>{sug_html}
<div class="section">Enemy balance</div><div class="grid">{etable}</div>
<div class="section">Charts</div><div class="grid">{charts}</div>
</body></html>"""
    return page

def player_label(u):
    st = u.get("stats", {})
    runs = int(st.get("runs", 0))
    oc = st.get("outcomes", {})
    wins = int(oc.get("victory", 0))
    when = datetime.datetime.fromtimestamp(int(u.get("ts", 0))).strftime("%Y-%m-%d") if u.get("ts") else "?"
    return runs, wins, when

def build_roster(users):
    rows = ""
    for u in sorted(users, key=lambda x: int(x.get("stats", {}).get("runs", 0)), reverse=True):
        st = u.get("stats", {})
        runs, wins, when = player_label(u)
        avg_floor = float(st.get("totals", {}).get("floor_reached", 0)) / max(1, runs)
        rid = str(u.get("id", "?"))
        sid = NAME_MAP.get(rid, rid[:10])
        rows += (f'<tr><td><a href="players/{html.escape(rid)}.html" target="_blank">{html.escape(sid)}</a></td>'
                 f'<td>{html.escape(str(u.get("version","")))}</td><td>{runs}</td>'
                 f'<td>{int(st.get("best_floor",0))}</td><td>{avg_floor:.1f}</td>'
                 f'<td>{when}</td></tr>')
    return ('<div class="section">Players</div><div class="grid"><div class="card wide"><h3>Per-player roster (click an id)</h3>'
            '<table><tr><th>install id</th><th>ver</th><th>runs</th><th>best floor</th>'
            f'<th>avg floor</th><th>last seen</th></tr>{rows}</table></div></div>')

def main():
    arg = sys.argv[1] if len(sys.argv) > 1 else None
    out = os.path.join(REPO, "analytics_report.html")

    # Build a per-player `users` list from either a telemetry_data folder OR a
    # dump JSON file ({"players":[...]} from telemetry.php?dump). Multi-player mode.
    raw_users = None
    if arg and os.path.isdir(arg):
        raw_users = []
        for fp in sorted(glob.glob(os.path.join(arg, "*.json"))):
            try:
                raw_users.append(json.load(open(fp, encoding="utf-8")))
            except Exception:
                continue
    elif arg and os.path.isfile(arg) and arg.lower().endswith(".json"):
        try:
            doc = json.load(open(arg, encoding="utf-8"))
        except Exception:
            doc = None
        if isinstance(doc, dict) and isinstance(doc.get("players"), list):
            raw_users = doc["players"]            # server dump
        elif isinstance(doc, list):
            raw_users = doc

    if raw_users is not None:
        users = []
        for u in raw_users:
            uid = str(u.get("id", "?"))
            if uid in IGNORE_IDS:
                print("  (skipping test/legacy id %s)" % uid)
                continue
            users.append(u)
        if not users:
            print("No (non-test) player records in", arg)
            return
        merged = {}
        for u in users:
            _merge_into(merged, u.get("stats", u))
        # one report per player → players/<id>.html
        pdir = os.path.join(REPO, "players")
        os.makedirs(pdir, exist_ok=True)
        for u in users:
            ph = render_html(u.get("stats", {}), 1)
            if ph:
                with open(os.path.join(pdir, str(u.get("id", "unknown")) + ".html"), "w", encoding="utf-8") as f:
                    f.write(ph)
        page = render_html(merged, len(users), build_roster(users))
    else:
        L, n = load_data()
        if not L:
            print("No analytics found. Play a run, or pass a telemetry_data folder.")
            return
        page = render_html(L, n)

    if not page:
        print("0 runs recorded yet.")
        return
    with open(out, "w", encoding="utf-8") as f:
        f.write(page)
    print("Wrote", out, "(+ per-player reports in players/)" if (arg and os.path.isdir(arg)) else "")
    try:
        webbrowser.open("file:///" + out.replace("\\", "/"))
    except Exception:
        pass

if __name__ == "__main__":
    main()
