extends Node

# Autoload "Stats" — robust run analytics for data-driven balancing.
# Tracks a per-run record AND a persistent lifetime aggregate (across every run),
# written to user://analytics.json. Read it back with report().

const SAVE_PATH := "user://analytics.json"
const INFLIGHT_PATH := "user://run_inflight.json"   # current run, re-written each heartbeat → crash recovery

var run: Dictionary = {}     # current run
var life: Dictionary = {}    # lifetime aggregate (persisted)
var _alive_sum: float = 0.0
var _alive_n: int = 0

func _ready() -> void:
	_load()
	# If a run was still in-flight when the game died last time (hard crash — no
	# clean close), recover it now, flagged as a partial/crashed run so analytics
	# can discount it.
	_recover_crash()
	# Make sure a run abandoned at app-close (alt-F4) — or the crash recovered above —
	# still reports: the close handler folds it locally, but the async upload may not
	# finish before quit, so re-send the last-known lifetime stats now, on next launch.
	# Deferred so the Telemetry autoload (loaded after Stats) has finished its _ready.
	if not life.is_empty():
		Telemetry.call_deferred("send", life)
	# Heartbeat: while a run is active, upload a LIVE snapshot (lifetime + the
	# in-progress run) every 60s — so a run is watchable as it happens and survives a
	# crash. Throttled server-side by Telemetry's 30s MIN_INTERVAL.
	var hb := Timer.new()
	hb.wait_time = 60.0
	hb.autostart = true
	hb.timeout.connect(_heartbeat)
	add_child(hb)

func _notification(what: int) -> void:
	# Player alt-F4'd / closed the window mid-run — still count the partial run
	# (floors reached, kills, etc.) as data instead of throwing it away.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not run.is_empty():
			end_run("abandoned")

# ── run lifecycle ────────────────────────────────────────────────────────────
func _blank_run() -> Dictionary:
	return {
		"t_start": Time.get_ticks_msec(),
		"duration": 0.0,
		"floor_reached": 1,
		"outcome": "abandoned",
		"gold_gained": 0, "gold_spent": 0,
		"fluff_gained": 0, "xp_gained": 0, "levels": 0,
		"damage_taken": 0, "hits_taken": 0,
		"kills_from_behind": 0, "kills_from_front": 0,   # back-shot (rear volley) vs normal kills
		"weapons_dropped": {}, "weapons_by_rarity": {},
		"upgrades_picked": {}, "shop_bought": {},
		"mobs_spawned": {}, "mobs_killed": {},
		"damage_sources": {},
		"alive_peak": 0,
		"enemy_detail": {},     # type -> {count, ttk_sum, hits_sum, dmg_sum}
		"kills_by_weapon": {},  # weapon name -> kills
		"weapon_equips": {},    # weapon name -> times equipped/picked
		"pick_order": [],       # ordered list of level-up ids (the build path)
	}

func start_run() -> void:
	# If a previous run is still open (player quit to menu mid-run, then started a
	# new one), finalize it as abandoned so its partial data isn't lost.
	if not run.is_empty():
		end_run("abandoned")
	run = _blank_run()
	_alive_sum = 0.0
	_alive_n = 0
	_save_inflight()   # mark a run active immediately, so even an early crash is recoverable

func end_run(outcome: String) -> void:
	if run.is_empty():
		return
	run["outcome"] = outcome
	run["duration"] = float(Time.get_ticks_msec() - int(run["t_start"])) / 1000.0
	run["alive_avg"] = (_alive_sum / float(maxi(1, _alive_n)))
	_fold_into_life(run)
	_save()
	_clear_inflight()   # clean end → no crash recovery needed for this run
	Telemetry.send(life)   # anonymous upload (no-op unless an endpoint is configured)
	print("[Stats] run ended (%s) — floor %d, %.0fs, %d gold, %d levels, %d dmg taken" % [
		outcome, int(run["floor_reached"]), float(run["duration"]),
		int(run["gold_gained"]), int(run["levels"]), int(run["damage_taken"])])
	run = {}

# ── event recorders (no-ops if no run is active) ─────────────────────────────
func _inc(d: String, key: String, n: int = 1) -> void:
	if run.is_empty():
		return
	var sub: Dictionary = run[d]
	sub[String(key)] = int(sub.get(String(key), 0)) + n

func _add(key: String, n: int) -> void:
	if run.is_empty():
		return
	run[key] = int(run.get(key, 0)) + n

func weapon_dropped(wname: String, rarity: int) -> void:
	_inc("weapons_dropped", wname); _inc("weapons_by_rarity", str(rarity))

func upgrade_picked(id: String) -> void:
	_inc("upgrades_picked", id)
	if not run.is_empty():
		(run["pick_order"] as Array).append(id)

func weapon_equipped(wname: String) -> void:
	_inc("weapon_equips", wname)

# Full per-kill detail: time-to-kill (s), hits taken to die, total damage taken
# to die (~effective HP), and which weapon was equipped at the kill.
func enemy_killed_detail(t: String, ttk: float, hits: int, dmg: int, weapon: String) -> void:
	if run.is_empty():
		return
	_inc("mobs_killed", t)
	_inc("kills_by_weapon", weapon)
	var ed: Dictionary = run["enemy_detail"]
	var e: Dictionary = ed.get(t, {"count": 0, "ttk_sum": 0.0, "hits_sum": 0, "dmg_sum": 0})
	e["count"] = int(e["count"]) + 1
	e["ttk_sum"] = float(e["ttk_sum"]) + ttk
	e["hits_sum"] = int(e["hits_sum"]) + hits
	e["dmg_sum"] = int(e["dmg_sum"]) + dmg
	ed[t] = e

func kill_facing(from_back: bool) -> void:
	# Was the killing blow a Back Shot (rear-volley) projectile, or a normal shot?
	# Lets us gauge how much of the kill load Back Shot carries → whether the rear
	# volley should do reduced damage.
	if from_back:
		_add("kills_from_behind", 1)
	else:
		_add("kills_from_front", 1)

func shop_bought(id: String, cost: int) -> void:
	_inc("shop_bought", id); _add("gold_spent", cost)

func mob_spawned(t: String) -> void:
	_inc("mobs_spawned", t)

func mob_killed(t: String) -> void:
	_inc("mobs_killed", t)

func player_hit(amount: int, source: String = "?") -> void:
	_add("damage_taken", amount); _add("hits_taken", 1); _inc("damage_sources", source, amount)

func gold_gained(n: int) -> void:
	_add("gold_gained", n)

func fluff_gained(n: int) -> void:
	_add("fluff_gained", n)

func xp_gained(n: int) -> void:
	_add("xp_gained", n)

func leveled() -> void:
	_add("levels", 1)

func note_floor(d: int) -> void:
	if not run.is_empty() and d > int(run["floor_reached"]):
		run["floor_reached"] = d

func sample_alive(n: int) -> void:
	if run.is_empty():
		return
	_alive_sum += float(n); _alive_n += 1
	if n > int(run["alive_peak"]):
		run["alive_peak"] = n

# ── aggregate + persistence ──────────────────────────────────────────────────
func _merge_dict(dst: Dictionary, src: Dictionary) -> void:
	for k in src.keys():
		dst[k] = int(dst.get(k, 0)) + int(src[k])

func _fold_into_life(r: Dictionary) -> void:
	_fold_run_into(life, r)

# Fold a run record into an aggregate dict L. Used for the persisted lifetime AND for
# throwaway live snapshots, so a 60s heartbeat never mutates the real `life`.
func _fold_run_into(L: Dictionary, r: Dictionary) -> void:
	L["runs"] = int(L.get("runs", 0)) + 1
	var T: Dictionary = L.get("totals", {})
	for k in ["duration", "gold_gained", "gold_spent", "fluff_gained", "xp_gained", "levels", "damage_taken", "hits_taken", "floor_reached", "alive_peak", "kills_from_behind", "kills_from_front"]:
		T[k] = float(T.get(k, 0.0)) + float(r.get(k, 0))
	L["totals"] = T
	L["best_floor"] = maxi(int(L.get("best_floor", 0)), int(r.get("floor_reached", 1)))
	var oc: Dictionary = L.get("outcomes", {})
	oc[String(r["outcome"])] = int(oc.get(String(r["outcome"]), 0)) + 1
	L["outcomes"] = oc
	for d in ["weapons_dropped", "weapons_by_rarity", "upgrades_picked", "shop_bought", "mobs_spawned", "mobs_killed", "damage_sources", "kills_by_weapon", "weapon_equips"]:
		var dst: Dictionary = L.get(d, {})
		_merge_dict(dst, r.get(d, {}))
		L[d] = dst
	# nested enemy detail (count/ttk/hits/dmg per type)
	var led: Dictionary = L.get("enemy_detail", {})
	for t in (r.get("enemy_detail", {}) as Dictionary).keys():
		var dd: Dictionary = led.get(t, {"count": 0, "ttk_sum": 0.0, "hits_sum": 0, "dmg_sum": 0})
		var src: Dictionary = r["enemy_detail"][t]
		for k in src.keys():
			dd[k] = float(dd.get(k, 0)) + float(src[k])
		led[t] = dd
	L["enemy_detail"] = led
	# per-run history (capped) for trend charts
	var hist: Array = L.get("history", [])
	var _enemies_n: int = 0
	for v in (r.get("mobs_spawned", {}) as Dictionary).values():
		_enemies_n += int(v)
	hist.append({
		"outcome": r["outcome"], "floor": int(r.get("floor_reached", 1)), "duration": float(r.get("duration", 0.0)),
		"gold": int(r.get("gold_gained", 0)), "levels": int(r.get("levels", 0)), "dmg": int(r.get("damage_taken", 0)),
		"alive_peak": int(r.get("alive_peak", 0)), "picks": r.get("pick_order", []),
		"partial": bool(r.get("partial", false)),
		"hits": int(r.get("hits_taken", 0)),
		"enemies": _enemies_n,
	})
	if hist.size() > 400:
		hist = hist.slice(hist.size() - 400)
	L["history"] = hist

# ── heartbeat + crash recovery ───────────────────────────────────────────────
func _live_run_record() -> Dictionary:
	# A snapshot of the active run with up-to-the-second duration/alive figures.
	var r: Dictionary = run.duplicate(true)
	r["duration"] = float(Time.get_ticks_msec() - int(run.get("t_start", Time.get_ticks_msec()))) / 1000.0
	r["alive_avg"] = (_alive_sum / float(maxi(1, _alive_n)))
	return r

func _heartbeat() -> void:
	if run.is_empty():
		return
	_save_inflight()
	# Build life + current run as an "in_progress" snapshot WITHOUT touching `life`.
	var snap: Dictionary = life.duplicate(true)
	var r: Dictionary = _live_run_record()
	r["outcome"] = "in_progress"
	r["partial"] = true
	_fold_run_into(snap, r)
	snap["live"] = true   # marks this upload as a live, not-yet-final run
	Telemetry.send(snap)

func _save_inflight() -> void:
	if run.is_empty():
		return
	var f := FileAccess.open(INFLIGHT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_live_run_record()))
		f.close()

func _clear_inflight() -> void:
	if FileAccess.file_exists(INFLIGHT_PATH):
		var d := DirAccess.open("user://")
		if d != null:
			d.remove("run_inflight.json")

func _recover_crash() -> void:
	if not FileAccess.file_exists(INFLIGHT_PATH):
		return
	var f := FileAccess.open(INFLIGHT_PATH, FileAccess.READ)
	var parsed: Variant = null
	if f != null:
		parsed = JSON.parse_string(f.get_as_text())
		f.close()
	_clear_inflight()
	if parsed is Dictionary and not (parsed as Dictionary).is_empty():
		var r: Dictionary = parsed
		r["outcome"] = "crashed"      # distinct outcome bucket
		r["partial"] = true           # flagged so analytics can discount it
		_fold_into_life(r)
		_save()
		print("[Stats] recovered a crashed run — floor %d, %.0fs (flagged partial)" % [
			int(r.get("floor_reached", 1)), float(r.get("duration", 0.0))])

func reset_lifetime() -> void:
	life = {}
	_save()

func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(life, "\t"))
		f.close()

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		life = {}
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		life = {}
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	life = parsed if parsed is Dictionary else {}

# ── report ───────────────────────────────────────────────────────────────────
func _top(d: Dictionary, n: int = 6) -> String:
	var arr: Array = []
	for k in d.keys():
		arr.append([k, int(d[k])])
	arr.sort_custom(func(a, b): return a[1] > b[1])
	var out: String = ""
	for i in mini(n, arr.size()):
		out += "    %-18s %d\n" % [arr[i][0], arr[i][1]]
	return out if out != "" else "    (none)\n"

func report() -> String:
	var runs: int = int(life.get("runs", 0))
	if runs == 0:
		return "No runs recorded yet. Play a run and the data shows up here."
	var T: Dictionary = life.get("totals", {})
	var per := func(k): return float(T.get(k, 0.0)) / float(runs)
	var s: String = "════  LIFETIME  (%d runs)  ════\n" % runs
	s += "Outcomes: %s\n" % str(life.get("outcomes", {}))
	s += "Best floor: %d   |   Avg floor: %.1f\n" % [int(life.get("best_floor", 0)), per.call("floor_reached")]
	s += "Avg run: %.0fs   |   Avg levels: %.1f\n" % [per.call("duration"), per.call("levels")]
	s += "Avg gold gained: %.0f   spent: %.0f   |   Avg fluff: %.0f\n" % [per.call("gold_gained"), per.call("gold_spent"), per.call("fluff_gained")]
	s += "Avg dmg taken/run: %.1f   over %.1f hits   (~%.1f dmg/hit)\n" % [per.call("damage_taken"), per.call("hits_taken"), per.call("damage_taken") / maxf(1.0, per.call("hits_taken"))]
	s += "Avg alive peak: %.0f\n" % per.call("alive_peak")
	s += "\nTop LEVEL-UP picks:\n" + _top(life.get("upgrades_picked", {}))
	s += "Top SHOP buys:\n" + _top(life.get("shop_bought", {}))
	s += "Most-spawned mobs:\n" + _top(life.get("mobs_spawned", {}))
	s += "Biggest damage SOURCES:\n" + _top(life.get("damage_sources", {}))
	s += "Weapon drops by rarity:\n" + _top(life.get("weapons_by_rarity", {}))
	s += "Kills by weapon:\n" + _top(life.get("kills_by_weapon", {}))
	s += "\nENEMY profile (avg per kill):\n"
	s += "    %-15s %5s %6s %6s %7s\n" % ["type", "kills", "TTK", "hits", "HP~"]
	var ed: Dictionary = life.get("enemy_detail", {})
	var rows: Array = []
	for t in ed.keys():
		rows.append([t, ed[t]])
	rows.sort_custom(func(a, b): return int(a[1]["count"]) > int(b[1]["count"]))
	for i in mini(12, rows.size()):
		var e: Dictionary = rows[i][1]
		var c: float = maxf(1.0, float(e["count"]))
		s += "    %-15s %5d %5.1fs %6.1f %7.1f\n" % [rows[i][0], int(e["count"]), float(e["ttk_sum"]) / c, float(e["hits_sum"]) / c, float(e["dmg_sum"]) / c]
	return s
