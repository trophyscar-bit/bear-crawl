extends Node

# Autoload "Stats" — robust run analytics for data-driven balancing.
# Tracks a per-run record AND a persistent lifetime aggregate (across every run),
# written to user://analytics.json. Read it back with report().

const SAVE_PATH := "user://analytics.json"

var run: Dictionary = {}     # current run
var life: Dictionary = {}    # lifetime aggregate (persisted)
var _alive_sum: float = 0.0
var _alive_n: int = 0

func _ready() -> void:
	_load()

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
		"weapons_dropped": {}, "weapons_by_rarity": {},
		"upgrades_picked": {}, "shop_bought": {},
		"mobs_spawned": {}, "mobs_killed": {},
		"damage_sources": {},
		"alive_peak": 0,
	}

func start_run() -> void:
	run = _blank_run()
	_alive_sum = 0.0
	_alive_n = 0

func end_run(outcome: String) -> void:
	if run.is_empty():
		return
	run["outcome"] = outcome
	run["duration"] = float(Time.get_ticks_msec() - int(run["t_start"])) / 1000.0
	run["alive_avg"] = (_alive_sum / float(maxi(1, _alive_n)))
	_fold_into_life(run)
	_save()
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
	life["runs"] = int(life.get("runs", 0)) + 1
	var T: Dictionary = life.get("totals", {})
	for k in ["duration", "gold_gained", "gold_spent", "fluff_gained", "xp_gained", "levels", "damage_taken", "hits_taken", "floor_reached", "alive_peak"]:
		T[k] = float(T.get(k, 0.0)) + float(r.get(k, 0))
	life["totals"] = T
	life["best_floor"] = maxi(int(life.get("best_floor", 0)), int(r.get("floor_reached", 1)))
	var oc: Dictionary = life.get("outcomes", {})
	oc[String(r["outcome"])] = int(oc.get(String(r["outcome"]), 0)) + 1
	life["outcomes"] = oc
	for d in ["weapons_dropped", "weapons_by_rarity", "upgrades_picked", "shop_bought", "mobs_spawned", "mobs_killed", "damage_sources"]:
		var dst: Dictionary = life.get(d, {})
		_merge_dict(dst, r.get(d, {}))
		life[d] = dst

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
	return s
