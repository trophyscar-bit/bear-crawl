extends Node

# Autoload — persistent across runs. Writes to user://meta.json
# (Godot's per-user app data folder).

const SAVE_PATH := "user://meta.json"

var total_fluff: int = 0
var cotton_threads: int = 0       # rarer currency — boss + final-boss drops
var best_floor: int = 0
var times_beaten: int = 0          # how many times the player has beaten Floor 10
var max_ascension: int = 0         # highest ascension level the player can select for a run
var weapon_unlocks: Dictionary = {
	"scatter": false,
	"homing":  false,
	"bomb":    false,
}
var upgrades: Dictionary = {
	"more_plush":     0,  # +1 starting HP per level
	"sharper_crust":  0,  # +1 starting pizza damage per level
	"faster_feet":    0,  # +5% starting move speed per level
	"lucky_start":    0,  # +1 starting weapon-charge bonus per level (gets a bomb at run start)
}

# Costs ramp per level: index [0] = cost for level 1, [1] for level 2, etc.
const WEAPON_DATA: Dictionary = {
	"scatter": {"name": "SCATTER PIZZA", "desc": "Throws 3 pizzas in a cone",       "cost": 30},
	"homing":  {"name": "HOMING PIZZA",  "desc": "Pizzas curve toward enemies",     "cost": 30},
	"bomb":    {"name": "PIZZA BOMB",    "desc": "Throws bombs that fuse + AOE",    "cost": 60},
}

const UPGRADE_DATA: Dictionary = {
	"more_plush":     {"name": "MORE PLUSH",     "desc": "+1 max HP at run start",         "costs": [30, 80],       "max": 2},
	"sharper_crust":  {"name": "SHARPER CRUST",  "desc": "+1 pizza damage at run start",   "costs": [90],           "max": 1},
	"faster_feet":    {"name": "FASTER FEET",    "desc": "+5% move speed at run start",    "costs": [20, 45, 80],   "max": 3},
	"lucky_start":    {"name": "LUCKY START",    "desc": "+1 starting bomb per level",     "costs": [25, 55, 100],  "max": 3},
}

func _ready() -> void:
	load_save()

func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var raw := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return
	var d: Dictionary = parsed
	total_fluff = int(d.get("total_fluff", 0))
	cotton_threads = int(d.get("cotton_threads", 0))
	best_floor = int(d.get("best_floor", 0))
	times_beaten = int(d.get("times_beaten", 0))
	max_ascension = int(d.get("max_ascension", 0))
	var unlocks_v: Variant = d.get("weapon_unlocks", {})
	if unlocks_v is Dictionary:
		for k in (unlocks_v as Dictionary).keys():
			if weapon_unlocks.has(k):
				weapon_unlocks[k] = bool((unlocks_v as Dictionary)[k])
	var up_v: Variant = d.get("upgrades", {})
	if up_v is Dictionary:
		for k in (up_v as Dictionary).keys():
			if upgrades.has(k):
				upgrades[k] = int((up_v as Dictionary)[k])

func save() -> void:
	var d: Dictionary = {
		"total_fluff": total_fluff,
		"cotton_threads": cotton_threads,
		"best_floor": best_floor,
		"times_beaten": times_beaten,
		"max_ascension": max_ascension,
		"weapon_unlocks": weapon_unlocks,
		"upgrades": upgrades,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Couldn't open meta save for writing")
		return
	f.store_string(JSON.stringify(d, "\t"))
	f.close()

func add_fluff(n: int) -> void:
	if n <= 0:
		return
	total_fluff += n
	save()

func add_cotton(n: int) -> void:
	if n <= 0:
		return
	cotton_threads += n
	save()

func record_victory() -> void:
	times_beaten += 1
	save()

func is_weapon_unlocked(id: String) -> bool:
	if id == "default" or id == "":
		return true
	return bool(weapon_unlocks.get(id, false))

func purchase_weapon(id: String) -> bool:
	if is_weapon_unlocked(id):
		return false
	var cost: int = int(WEAPON_DATA.get(id, {}).get("cost", 999999))
	if cotton_threads < cost:
		return false
	cotton_threads -= cost
	weapon_unlocks[id] = true
	save()
	return true

func unlock_ascension_up_to(level: int) -> void:
	if level > max_ascension and level <= 5:
		max_ascension = level
		save()

func note_floor_reached(depth: int) -> void:
	if depth > best_floor:
		best_floor = depth
		save()

func upgrade_level(id: String) -> int:
	# clamp stored level to the current max — handles rebalance / old saves
	var stored: int = int(upgrades.get(id, 0))
	var max_lvl: int = int(UPGRADE_DATA.get(id, {}).get("max", 0))
	return min(stored, max_lvl)

func next_cost(id: String) -> int:
	var data: Dictionary = UPGRADE_DATA.get(id, {})
	var costs: Array = data.get("costs", [])
	var lvl: int = upgrade_level(id)
	if lvl >= int(data.get("max", 0)):
		return -1  # maxed
	if lvl >= costs.size():
		return -1
	return int(costs[lvl])

func can_afford(id: String) -> bool:
	var c: int = next_cost(id)
	return c >= 0 and total_fluff >= c

func purchase(id: String) -> bool:
	var c: int = next_cost(id)
	if c < 0 or total_fluff < c:
		return false
	total_fluff -= c
	upgrades[id] = upgrade_level(id) + 1
	save()
	return true
