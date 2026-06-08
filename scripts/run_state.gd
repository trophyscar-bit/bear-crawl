extends Node

# Autoloaded singleton — accessed as RunState.* from any script.
# Holds per-run state. Reset by main.gd on new run.

const DEFAULT_MAX_STACKS: int = 3

# Each boon: id, name, desc, max_stacks, rarity ("common" / "rare" / "legendary").
const COMMON_POOL: Array[Dictionary] = [
	{"id": "extra_cheese",  "name": "EXTRA CHEESE",  "desc": "+1 pizza damage",                 "max_stacks": 2, "rarity": "common"},
	{"id": "stuffed_crust", "name": "STUFFED CRUST", "desc": "Pizzas 25% bigger",               "max_stacks": 3, "rarity": "common"},
	{"id": "speed_slice",   "name": "SPEED SLICE",   "desc": "Pizzas fly 25% faster",           "max_stacks": 3, "rarity": "common"},
	{"id": "plush_armor",   "name": "PLUSH ARMOR",   "desc": "+1 max HP (heal 1)",              "max_stacks": 3, "rarity": "common"},
	{"id": "sticky_buns",   "name": "STICKY BUNS",   "desc": "+12% move speed",                 "max_stacks": 3, "rarity": "common"},
]

const RARE_POOL: Array[Dictionary] = [
	{"id": "bouncy_crust",  "name": "BOUNCY CRUST",  "desc": "Pizzas bounce 2 more times",      "max_stacks": 2, "rarity": "rare"},
	{"id": "double_pep",    "name": "DOUBLE PEP",    "desc": "Throw +1 pizza in a spread",      "max_stacks": 2, "rarity": "rare"},
	{"id": "spicy",         "name": "SPICY",         "desc": "Pizzas burn enemies (1 dmg/s, 3s)","max_stacks": 1, "rarity": "rare"},
	{"id": "pizza_magnet",  "name": "PIZZA MAGNET",  "desc": "Pickups fly toward you",          "max_stacks": 1, "rarity": "rare"},
	{"id": "lucky_crumbs",  "name": "LUCKY CRUMBS",  "desc": "Drop chance doubled",             "max_stacks": 1, "rarity": "rare"},
	{"id": "piercer",       "name": "PIERCER",       "desc": "Pizzas pierce +1 more enemy",     "max_stacks": 3, "rarity": "rare"},
]

const LEGENDARY_POOL: Array[Dictionary] = [
	{"id": "pepperoni_burst","name": "PEPPERONI BURST","desc": "Pizzas explode on impact (AOE)","max_stacks": 1, "rarity": "legendary"},
	{"id": "pizza_wheel",   "name": "PIZZA WHEEL",   "desc": "An orbital slice defends you",    "max_stacks": 1, "rarity": "legendary"},
	{"id": "soft_landing",  "name": "SOFT LANDING",  "desc": "Orbiting slice blocks 1 hit/room", "max_stacks": 1, "rarity": "legendary"},
]

# Base weights for the offer roll. Per-slot drawn without replacement.
const WEIGHT_COMMON: float = 70.0
const WEIGHT_RARE: float = 25.0
const WEIGHT_LEGENDARY: float = 8.0

var active_boons: Array[String] = []

# ---- Run stats (tracked during a single run, reset on new run) ----
var stats_floors_reached: int = 1
var stats_enemies_killed: int = 0
var stats_bombs_thrown: int = 0
var stats_fluff_earned: int = 0
var stats_run_seconds: float = 0.0

# Per-type pickup counters (resets each run). Every 5 of the same type triggers a bonus.
var pickup_stacks: Dictionary = {
	"health": 0,
	"bomb": 0,
	"scatter": 0,
	"homing": 0,
}
const STACK_BONUS_THRESHOLD: int = 5

func reset() -> void:
	active_boons.clear()
	stats_floors_reached = 1
	stats_enemies_killed = 0
	stats_bombs_thrown = 0
	stats_fluff_earned = 0
	stats_run_seconds = 0.0
	pickup_stacks = {"health": 0, "bomb": 0, "scatter": 0, "homing": 0}

# Returns true if this pickup just hit a multiple-of-5 stack bonus.
func add_pickup_stack(kind: String) -> bool:
	if not pickup_stacks.has(kind):
		pickup_stacks[kind] = 0
	pickup_stacks[kind] = int(pickup_stacks[kind]) + 1
	return int(pickup_stacks[kind]) % STACK_BONUS_THRESHOLD == 0

func add(id: String) -> void:
	if id == "":
		return
	active_boons.append(id)

func count(id: String) -> int:
	var n: int = 0
	for b in active_boons:
		if b == id:
			n += 1
	return n

func _boon_data(id: String) -> Dictionary:
	for b in COMMON_POOL:
		if b.id == id:
			return b
	for b in RARE_POOL:
		if b.id == id:
			return b
	for b in LEGENDARY_POOL:
		if b.id == id:
			return b
	return {}

func _max_stacks_for(id: String) -> int:
	var d: Dictionary = _boon_data(id)
	return int(d.get("max_stacks", DEFAULT_MAX_STACKS))

func is_maxed(id: String) -> bool:
	return count(id) >= _max_stacks_for(id)

func rarity_of(id: String) -> String:
	return String(_boon_data(id).get("rarity", "common"))

# ---- Modifier accessors ----

func pizza_damage_bonus() -> int:
	return count("extra_cheese")

func pizza_size_multiplier() -> float:
	return 1.0 + 0.25 * count("stuffed_crust")

func pizza_speed_multiplier() -> float:
	return 1.0 + 0.25 * count("speed_slice")

func bonus_max_health() -> int:
	return count("plush_armor")

func move_speed_multiplier() -> float:
	return 1.0 + 0.12 * count("sticky_buns")

# Bouncy Crust — each stack adds 2 extra bounces (1 base + 2N total)
func extra_bounces() -> int:
	return 2 * count("bouncy_crust")

# Double Pep — each stack adds another pizza per throw
func extra_pizzas() -> int:
	return count("double_pep")

func has_spicy() -> bool:
	return count("spicy") > 0

func has_pizza_magnet() -> bool:
	return count("pizza_magnet") > 0

func drop_chance_multiplier() -> float:
	return 2.0 if count("lucky_crumbs") > 0 else 1.0

func has_pepperoni_burst() -> bool:
	return count("pepperoni_burst") > 0

func has_pizza_wheel() -> bool:
	return count("pizza_wheel") > 0

func has_soft_landing() -> bool:
	return count("soft_landing") > 0

# Piercer — each stack lets pizzas pass through one more enemy
func pizza_pierce() -> int:
	return count("piercer")

# ---- Offer roll: weighted draw without replacement ----

func roll_offers(n: int = 3) -> Array:
	var available: Array = []
	for b in COMMON_POOL:
		if not is_maxed(b.id):
			available.append({"data": b, "weight": WEIGHT_COMMON})
	for b in RARE_POOL:
		if not is_maxed(b.id):
			available.append({"data": b, "weight": WEIGHT_RARE})
	for b in LEGENDARY_POOL:
		if not is_maxed(b.id):
			available.append({"data": b, "weight": WEIGHT_LEGENDARY})

	var result: Array = []
	for _i in n:
		if available.is_empty():
			break
		var total: float = 0.0
		for entry in available:
			total += float(entry.weight)
		var r: float = randf() * total
		var picked: int = 0
		var accum: float = 0.0
		for j in available.size():
			accum += float(available[j].weight)
			if r <= accum:
				picked = j
				break
		result.append(available[picked].data)
		available.remove_at(picked)
	return result
