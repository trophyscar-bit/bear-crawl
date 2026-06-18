extends Node

# ── ARPG run state (Diablo-style) ──────────────────────────────────────────
# Persists across dungeon floors (autoload). Holds the player's level/XP/gold,
# the currently equipped weapon (rolled loot), and the loot/XP generators.
# `active` gates all of this so the legacy main-game flow is untouched.

signal stats_changed
signal weapon_changed(weapon: Dictionary)
signal leveled_up(level: int)
signal toast(text: String, color: Color)
signal loot_dropped(pos: Vector2, item: Dictionary)

var active: bool = false
var depth: int = 1
var level: int = 1
var xp: int = 0
var xp_to_next: int = 6
var gold: int = 0
var weapon: Dictionary = {}
var dungeon_path: String = "res://scenes/dungeon.tscn"
# Biome rotation — each new floor randomly picks one of these (no immediate repeat).
const BIOMES: Array = [
	"res://scenes/dungeon.tscn",     # cave (the classic)
	"res://scenes/cyber2077.tscn",   # cyberpunk building (the big-tile one we kept)
	"res://scenes/damp.tscn",        # stone & moss
	"res://scenes/hand.tscn",        # pen & ink
	"res://scenes/space.tscn",       # moon / asteroid surface
	"res://scenes/poolrooms.tscn",   # liminal indoor pool (day/night variants)
	"res://scenes/wheat.tscn",       # outdoor field of wheat (hedgerow maze)
	"res://scenes/sewer.tscn",       # flooded sewers (AI-generated brick)
	"res://scenes/suburb.tscn",      # suburban neighbourhood (AI-generated tiles)
]
var _last_biome: String = "res://scenes/dungeon.tscn"
var light_mode: int = 1   # which live lighting preset is active (persists across floors)
var light_boost: int = 1  # 1-5 brightness pump on all light sources (persists)
var brightness_level: int = 2  # dungeon darkness preset 1=dark 2=medium 3=bright (persists)
var auto_sell_rarity: bool = true   # ON by default — auto-sell WEAKER drops automatically (no pause-menu toggle needed)
var backrooms_next: bool = false    # next floor loads as a BACKROOMS stage (boss-portal)
# Forced floor sequence (scene paths) that overrides the random biome pick — used to
# script set-piece runs, e.g. backrooms portal → pool rooms → field of wheat.
var scripted_queue: Array = []
# True when a level was launched from the dev Level Select (a one-off test, not a run) —
# Esc then exits straight back to Level Select instead of opening the pause menu.
var level_lab: bool = false
# The lab level you're currently in, so Level Select can offer "Resume" back to it
# instead of only dumping you to the title.
var last_lab_scene: String = ""
# True when the current floor was entered through a HUB door — clearing it returns to the Hub.
var return_to_hub: bool = false
var pending_variant: int = 0        # dev level-lab picks a design variant (1-5; 0 = use scene default)
var enemy_bright: int = 1 # 1-3 enemy self-illumination (persists)
var backrooms_pack: int = 5  # backrooms asset pack (locked to 5 — the chosen look)
var no_projectile_glow: bool = false  # backrooms turns off the projectile glow

# Permanent run upgrades bought at the between-floor shop.
var dmg_mult: float = 1.0
var cooldown_mult: float = 1.0
var bonus_maxhp: int = 0
var crit_chance: float = 0.0
var speed_mult: float = 1.0
var bonus_projectiles: int = 0
var back_shot: bool = false   # Back Shot power-up: also fire out the back (180°)
# Spawn safety: no enemy fires a projectile until this msec timestamp. Set when a
# floor loads so you get a breather to orient before anything shoots.
var spawn_grace_msec: int = 0
func in_spawn_grace() -> bool:
	return Time.get_ticks_msec() < spawn_grace_msec
func begin_spawn_grace(seconds: float) -> void:
	spawn_grace_msec = Time.get_ticks_msec() + int(seconds * 1000.0)

const RARITY_NAMES := ["Common", "Magic", "Rare", "Legendary"]
const RARITY_COLORS := [
	Color(0.92, 0.92, 0.95),   # common    - white  (classic ARPG rarity ramp)
	Color(0.35, 0.85, 0.40),   # magic     - green
	Color(0.70, 0.42, 1.00),   # rare      - purple
	Color(1.00, 0.82, 0.20),   # legendary - gold/yellow
]

# Weapon archetypes — equipping one genuinely changes the attack feel.
# Numbers live in a wide economy (enemy HP is 20+), so per-hit damage is a
# FRACTION of a target's health — even the heavy cannon takes ~2 hits on trash,
# never a one-shot.
const ARCHETYPES := [
	{"name": "Pepperoni Slicer", "count": 1, "cooldown": 0.34, "speed": 600.0, "dmg": 8,  "color": Color(1.0, 0.78, 0.42), "proj": "pepperoni", "proj_scale": 0.62},
	{"name": "Triple Crust",     "count": 3, "cooldown": 0.55, "speed": 520.0, "dmg": 4,  "color": Color(1.0, 0.55, 0.35)},
	{"name": "Cheese Spike",     "count": 1, "cooldown": 0.18, "speed": 780.0, "dmg": 5,  "color": Color(1.0, 0.95, 0.5), "proj": "cheese", "proj_scale": 0.5},
	{"name": "Deep-Dish Cannon", "count": 1, "cooldown": 0.75, "speed": 470.0, "dmg": 12, "color": Color(1.0, 0.4, 0.3), "proj": "deepdish", "proj_scale": 0.85},
	{"name": "Frost Calzone",    "count": 2, "cooldown": 0.42, "speed": 560.0, "dmg": 6,  "color": Color(0.5, 0.85, 1.0), "proj": "ice", "proj_scale": 0.6},
	# Bouncy Blaster: spammy, lower per-hit, but each ball ricochets off walls for
	# ~4s in a random colour — persists far longer than anything else, so spamming
	# fills the room with bouncing shots that keep finding mobs.
	# weight 0.33 → rolls ~1/3 as often as the other weapons (a lucky find).
	{"name": "Bouncy Blaster",   "count": 1, "cooldown": 0.26, "speed": 620.0, "dmg": 4,  "color": Color(1, 1, 1), "ball": true, "bounces": 9, "weight": 0.33},
]

# ── Heroes + weapon trees ─────────────────────────────────────────────────────
# Each hero owns ONE weapon. No drops, no swapping, no multi-weapon. The weapon
# starts at its base and grows along a BRANCHING tree: at the between-floor shop
# you first pick one of two PATHS, then advance along it tier by tier.
const HEROES: Array = [
	{
		"id": "rupert", "name": "Rupert", "tree": "pizza",
		"color": Color(1.0, 0.78, 0.42),
		"blurb": "Throws pizzas straight. At the shop, branch into Homing Pie or Extra-Large.",
	},
	{
		"id": "finn", "name": "Finn", "tree": "darts",
		"color": Color(1.0, 0.95, 0.5),
		"blurb": "Flings fast cheese darts. At the shop, branch into Spray or Lance.",
	},
]
var hero_id: String = "rupert"

# Per-weapon branching upgrade trees. Each path is a list of TIERS; each tier's
# `mods` are folded into the weapon when you reach it (multipliers compound). All
# effects reuse mechanics the projectile already supports (homing, pierce, count,
# size, fire-rate) plus one new one: `split` (burst into mini homing pizzas on hit).
const WEAPON_TREES: Dictionary = {
	"pizza": {
		"name": "Pizza", "color": Color(1.0, 0.78, 0.42),
		"proj": "pepperoni", "proj_scale": 0.62,
		"base": {"dmg": 8.0, "cooldown": 0.34, "speed": 600.0, "count": 1},
		"paths": {
			"homing": {
				"name": "Homing Pie",
				"blurb": "Pizzas seek the nearest enemy. Shorter range and softer hits, but they never miss.",
				"tiers": [
					{"name": "Heat-Seeking Crust", "desc": "Pizzas home to enemies (shorter range, -20% dmg)", "mods": {"homing": true, "turn": 5.5, "dmg_mult": 0.8, "life_mult": 0.7}},
					{"name": "Hot Pursuit", "desc": "Sharper tracking, longer range, +20% dmg", "mods": {"turn": 8.0, "life_mult": 1.5, "dmg_mult": 1.2}},
					{"name": "Pizza Party!", "desc": "On hit: burst into 5 mini pizzas that home to the next target", "mods": {"split": 5, "dmg_mult": 1.1}},
				],
			},
			"xl": {
				"name": "Extra Large",
				"blurb": "Huge, heavy slices. Big damage, slower throws — they bulldoze through crowds.",
				"tiers": [
					{"name": "Extra Large", "desc": "+50% damage, +60% size, slower fire", "mods": {"dmg_mult": 1.5, "size_mult": 1.6, "cd_mult": 1.35}},
					{"name": "Deep Dish", "desc": "+25% damage, pierces 1 enemy", "mods": {"dmg_mult": 1.25, "pierce": 1}},
					{"name": "Family Size", "desc": "+40% damage & size, pierces 1 more", "mods": {"dmg_mult": 1.4, "size_mult": 1.3, "pierce": 1}},
				],
			},
		},
	},
	"darts": {
		"name": "Cheese Darts", "color": Color(1.0, 0.95, 0.5),
		"proj": "cheese", "proj_scale": 0.5,
		"base": {"dmg": 5.0, "cooldown": 0.2, "speed": 780.0, "count": 1},
		"paths": {
			"spray": {
				"name": "Spray",
				"blurb": "A storm of fast little darts — wide and relentless, light per hit.",
				"tiers": [
					{"name": "Triple Toss", "desc": "+2 darts in a spread (-15% dmg each)", "mods": {"count": 2, "dmg_mult": 0.85}},
					{"name": "Rapid Fire", "desc": "+30% fire rate, +1 dart", "mods": {"cd_mult": 0.7, "count": 1}},
					{"name": "Cheese Storm", "desc": "+2 darts, faster fire", "mods": {"count": 2, "cd_mult": 0.85}},
				],
			},
			"lance": {
				"name": "Lance",
				"blurb": "One fast spike that skewers a whole line of enemies.",
				"tiers": [
					{"name": "Piercing Lance", "desc": "Pierces 2 enemies, +40% damage & speed", "mods": {"pierce": 2, "dmg_mult": 1.4, "speed_mult": 1.2}},
					{"name": "Skewer", "desc": "Pierces 2 more, +30% damage", "mods": {"pierce": 2, "dmg_mult": 1.3}},
					{"name": "Railgun", "desc": "Pierces 5 more, big damage & speed", "mods": {"pierce": 5, "dmg_mult": 1.6, "speed_mult": 1.4}},
				],
			},
		},
	},
}

# Live tree state for the current run.
var weapon_tree: String = "pizza"   # which tree the chosen hero uses
var weapon_path: String = ""        # "" until you pick at the shop; then a path key
var weapon_tier: int = 0            # how many tiers of the chosen path are applied
var extra_weapons: Array = []       # kept empty — multi-weapon is disabled
const MAX_EXTRA_WEAPONS: int = 2    # (legacy; multi-weapon collect path is dead but still compiled)

const WEAPON_MAX_LVL: int = 8

# Each weapon LEVELS UP along a fixed path (Vampire-Survivors style). Index 0 is
# the Lv1→2 step … index 6 is Lv7→8. The last step is an "evolved" capstone.
const LEVEL_PATHS: Dictionary = {
	"Pepperoni Slicer": [
		{"dmg": 3, "label": "+3 Damage"},
		{"pierce": 1, "label": "+1 Pierce"},
		{"cd": 0.88, "label": "+14% Fire Rate"},
		{"count": 1, "label": "+1 Projectile"},
		{"dmg": 4, "label": "+4 Damage"},
		{"pierce": 1, "label": "+1 Pierce"},
		{"dmg": 6, "count": 1, "label": "EVOLVED: +6 Dmg, +1 Shot"},
	],
	"Triple Crust": [
		{"dmg": 2, "label": "+2 Damage"},
		{"count": 1, "label": "+1 Projectile"},
		{"cd": 0.90, "label": "+11% Fire Rate"},
		{"dmg": 2, "label": "+2 Damage"},
		{"pierce": 1, "label": "+1 Pierce"},
		{"count": 1, "label": "+1 Projectile"},
		{"dmg": 3, "count": 1, "label": "EVOLVED: +3 Dmg, +1 Shot"},
	],
	"Cheese Spike": [
		{"cd": 0.90, "label": "+11% Fire Rate"},
		{"dmg": 2, "label": "+2 Damage"},
		{"pierce": 1, "label": "+1 Pierce"},
		{"cd": 0.88, "label": "+14% Fire Rate"},
		{"dmg": 3, "label": "+3 Damage"},
		{"pierce": 1, "label": "+1 Pierce"},
		{"pierce": 2, "cd": 0.85, "label": "EVOLVED: +2 Pierce, faster"},
	],
	"Deep-Dish Cannon": [
		{"dmg": 4, "label": "+4 Damage"},
		{"pierce": 1, "label": "+1 Pierce"},
		{"dmg": 5, "label": "+5 Damage"},
		{"cd": 0.90, "label": "+11% Fire Rate"},
		{"dmg": 6, "label": "+6 Damage"},
		{"count": 1, "label": "+1 Projectile"},
		{"dmg": 10, "pierce": 1, "label": "EVOLVED: +10 Dmg, +1 Pierce"},
	],
	"Frost Calzone": [
		{"dmg": 2, "label": "+2 Damage"},
		{"count": 1, "label": "+1 Projectile"},
		{"dmg": 2, "label": "+2 Damage"},
		{"cd": 0.90, "label": "+11% Fire Rate"},
		{"count": 1, "label": "+1 Projectile"},
		{"dmg": 3, "label": "+3 Damage"},
		{"count": 1, "dmg": 3, "label": "EVOLVED: +1 Shot, +3 Dmg"},
	],
	"Bouncy Blaster": [
		{"dmg": 2, "label": "+2 Damage"},
		{"bounces": 3, "label": "+3 Bounces"},
		{"cd": 0.90, "label": "+11% Fire Rate"},
		{"dmg": 2, "label": "+2 Damage"},
		{"bounces": 3, "label": "+3 Bounces"},
		{"count": 1, "label": "+1 Projectile"},
		{"count": 1, "dmg": 4, "bounces": 4, "label": "EVOLVED: +1 Shot, +4 Dmg"},
	],
}

func _archetype_by_name(n: String) -> Dictionary:
	for a in ARCHETYPES:
		if String(a.get("name", "")) == n:
			return a
	return ARCHETYPES[0]

# Build a weapon dict from its archetype at a given level (applies the level path)
# + rarity. Depth scales the BASE damage so deeper drops feel stronger.
func _build_weapon(arch: Dictionary, lvl: int, rar: int) -> Dictionary:
	var w: Dictionary = arch.duplicate(true)
	lvl = clampi(lvl, 1, WEAPON_MAX_LVL)
	var dmult: float = 1.0 + 0.07 * float(depth - 1)
	var dmg: float = float(w.get("dmg", 1)) * dmult
	var cd: float = float(w.get("cooldown", 0.34))
	var count: int = int(w.get("count", 1))
	var pierce: int = int(w.get("pierce", 0))
	var bounces: int = int(w.get("bounces", 0))
	var path: Array = LEVEL_PATHS.get(String(w.get("name", "")), [])
	for i in mini(lvl - 1, path.size()):
		var step: Dictionary = path[i]
		dmg += float(step.get("dmg", 0))
		if step.has("cd"):
			cd *= float(step["cd"])
		count += int(step.get("count", 0))
		pierce += int(step.get("pierce", 0))
		bounces += int(step.get("bounces", 0))
	w["dmg"] = int(ceil(dmg))
	w["cooldown"] = maxf(0.07, cd)
	w["count"] = count
	w["pierce"] = pierce
	if bool(w.get("ball", false)) or bounces > 0:
		w["bounces"] = bounces
	w["lvl"] = lvl
	w["rarity"] = rar
	w["maxlvl"] = WEAPON_MAX_LVL
	w["score"] = _score(w)
	return w

# Label for the NEXT level-up of the equipped weapon ("" if maxed).
func weapon_next_label() -> String:
	var lvl: int = int(weapon.get("lvl", 1))
	if lvl >= WEAPON_MAX_LVL:
		return ""
	var path: Array = LEVEL_PATHS.get(String(weapon.get("name", "")), [])
	if lvl - 1 < path.size():
		return String((path[lvl - 1] as Dictionary).get("label", ""))
	return ""

var run_time: float = 0.0   # total elapsed time for the WHOLE run (across floors)

func _process(delta: float) -> void:
	# Accumulate total run time while a run is active. As an autoload this pauses
	# with the tree (so it stops on the character screen, like the stage timer).
	if active:
		run_time += delta

func reset_run() -> void:
	active = true
	run_time = 0.0
	Stats.start_run()
	depth = 1
	dungeon_path = "res://scenes/dungeon.tscn"   # floor 1 = the cave (familiar start)
	_last_biome = dungeon_path
	scripted_queue.clear()
	level_lab = false
	last_lab_scene = ""
	return_to_hub = false
	level = 1
	xp = 0
	xp_to_next = 6
	gold = 0
	dmg_mult = 1.0
	cooldown_mult = 1.0
	bonus_maxhp = 0
	crit_chance = 0.0
	speed_mult = 1.0
	bonus_projectiles = 0
	back_shot = false
	# Workshop meta-upgrades — a permanent head start that run upgrades stack onto.
	# (Max HP via more_plush + Move Speed via faster_feet are applied in player.gd.)
	dmg_mult += 0.05 * float(MetaSave.upgrade_level("sharper_crust"))
	cooldown_mult *= pow(0.96, float(MetaSave.upgrade_level("hot_oven")))
	crit_chance += 0.03 * float(MetaSave.upgrade_level("sharp_eye"))
	light_boost = 1
	enemy_bright = 1
	backrooms_pack = 5
	# Hero pick: start the hero's weapon tree at its base (no path chosen yet — you
	# branch at the first shop). No drops, no swapping, no multi-weapon.
	extra_weapons.clear()
	var hero: Dictionary = hero_data()
	weapon_tree = String(hero.get("tree", "pizza"))
	weapon_path = ""
	weapon_tier = 0
	weapon = _build_tree_weapon()
	Stats.weapon_equipped(String(weapon.get("name", "?")))
	emit_signal("weapon_changed", weapon)
	emit_signal("stats_changed")

# ── weapon tree → effective weapon dict ───────────────────────────────────────
# Builds the weapon the player actually fires: the tree's base stats with every
# reached tier of the chosen path folded in. Output fields match what player.gd /
# pizza.gd read (dmg, cooldown, speed, count, pierce, homing, size_mult, split…).
func _build_tree_weapon() -> Dictionary:
	var tree: Dictionary = WEAPON_TREES.get(weapon_tree, WEAPON_TREES["pizza"])
	var base: Dictionary = tree["base"]
	var w: Dictionary = {
		"name": String(tree["name"]),
		"dmg": float(base["dmg"]),
		"cooldown": float(base["cooldown"]),
		"speed": float(base["speed"]),
		"count": int(base["count"]),
		"pierce": 0,
		"homing": false,
		"turn": 5.5,
		"size_mult": 1.0,
		"life_mult": 1.0,
		"speed_mult": 1.0,
		"split": 0,
		"color": tree.get("color", Color(1, 1, 1)),
		"proj": String(tree.get("proj", "")),
		"proj_scale": float(tree.get("proj_scale", 0.6)),
		"rarity": 0, "lvl": 1, "maxlvl": WEAPON_MAX_LVL,
	}
	if weapon_path != "" and (tree["paths"] as Dictionary).has(weapon_path):
		var tiers: Array = tree["paths"][weapon_path]["tiers"]
		for i in mini(weapon_tier, tiers.size()):
			_apply_tier(w, (tiers[i] as Dictionary).get("mods", {}))
	w["speed"] = float(w["speed"]) * float(w["speed_mult"])
	w["score"] = _score(w)
	return w

func _apply_tier(w: Dictionary, mods: Dictionary) -> void:
	w["dmg"] = float(w["dmg"]) * float(mods.get("dmg_mult", 1.0))
	w["cooldown"] = float(w["cooldown"]) * float(mods.get("cd_mult", 1.0))
	w["count"] = int(w["count"]) + int(mods.get("count", 0))
	w["pierce"] = int(w["pierce"]) + int(mods.get("pierce", 0))
	w["size_mult"] = float(w["size_mult"]) * float(mods.get("size_mult", 1.0))
	w["life_mult"] = float(w["life_mult"]) * float(mods.get("life_mult", 1.0))
	w["speed_mult"] = float(w["speed_mult"]) * float(mods.get("speed_mult", 1.0))
	if mods.has("homing"):
		w["homing"] = bool(mods["homing"])
	if mods.has("turn"):
		w["turn"] = float(mods["turn"])
	w["split"] = maxi(int(w["split"]), int(mods.get("split", 0)))

# Tree introspection used by the shop to offer branch picks.
func _tree() -> Dictionary:
	return WEAPON_TREES.get(weapon_tree, WEAPON_TREES["pizza"])

func tree_path_count() -> int:
	if weapon_path == "":
		return 0
	return ((_tree()["paths"][weapon_path]["tiers"]) as Array).size()

func tree_is_maxed() -> bool:
	return weapon_path != "" and weapon_tier >= tree_path_count()

# Short HUD label: weapon name, plus the chosen path + progress once you've branched.
func weapon_summary() -> String:
	var nm: String = String(weapon.get("name", "Weapon"))
	if weapon_path == "":
		return nm
	var pname: String = String((_tree()["paths"][weapon_path] as Dictionary).get("name", weapon_path))
	return "%s · %s %d/%d" % [nm, pname, weapon_tier, tree_path_count()]

# ── effective combat stats (weapon + run upgrades) ──────────────────────────
# The *_of(w) variants evaluate an ARBITRARY weapon dict (so the auto-firing
# secondary weapons can compute their own damage/rate/count); the bare versions
# operate on the equipped primary.
func weapon_damage_of(w: Dictionary) -> int:
	return int(ceil(float(w.get("dmg", 1)) * dmg_mult)) + bonus_damage()

func weapon_cooldown_of(w: Dictionary) -> float:
	return maxf(0.06, float(w.get("cooldown", 0.34)) * cooldown_mult)

func weapon_count_of(w: Dictionary) -> int:
	return int(w.get("count", 1)) + bonus_projectiles

func weapon_damage() -> int:
	return weapon_damage_of(weapon)

func weapon_cooldown() -> float:
	return weapon_cooldown_of(weapon)

func weapon_count() -> int:
	return weapon_count_of(weapon)

# ── DPS-based difficulty scaling ─────────────────────────────────────────────
# Estimates the player's current damage potential so the dungeon can scale enemy
# toughness + numbers to match — DPS is king, so instead of capping upgrades we
# scale the world (Vampire-Survivors style: you get strong, the swarm grows).
func player_power() -> float:
	if weapon.is_empty():
		return 20.0
	var dps: float = float(weapon_damage() * weapon_count()) / weapon_cooldown()
	if back_shot:
		dps *= 1.3                                  # extra coverage front+back
	dps *= 1.0 + crit_chance                         # crit ≈ +100% on crit
	dps *= 1.0 + 0.2 * float(weapon.get("pierce", 0))
	if bool(weapon.get("ball", false)):
		dps *= 1.0 + 0.1 * float(weapon.get("bounces", 0))
	return dps

func expected_power() -> float:
	# What a "fair" player should roughly have at this depth (starter ≈ 23 dps).
	return 22.0 * (1.0 + 0.28 * float(depth - 1))

func challenge_ratio() -> float:
	# >1 = player is over-powered for the depth → scale the world up. Clamped so a
	# nuke build makes things harder but never impossible/degenerate.
	return clampf(player_power() / maxf(1.0, expected_power()), 0.6, 3.5)

func rolled_crit() -> bool:
	return randf() < crit_chance

func _starter_weapon() -> Dictionary:
	return _build_weapon(ARCHETYPES[0], 1, 0)

# ── heroes ───────────────────────────────────────────────────────────────────
func hero_data() -> Dictionary:
	for h in HEROES:
		if String((h as Dictionary).get("id", "")) == hero_id:
			return h
	return HEROES[0]

func set_hero(id: String) -> void:
	for h in HEROES:
		if String((h as Dictionary).get("id", "")) == id:
			hero_id = id
			return

func _hero_starter_weapon(hero: Dictionary) -> Dictionary:
	var arch: Dictionary = _archetype_by_name(String(hero.get("weapon", "Pepperoni Slicer")))
	return _build_weapon(arch, 1, 0)

# ── multi-weapon collection (floor drops) ────────────────────────────────────
# Floor drops NEVER swap your hero's primary. A duplicate type levels the weapon
# you already hold; a new type fills a free secondary slot (auto-firing); if all
# slots are full the drop pours into your weakest weapon as a level. Returns a
# short toast string describing what happened.
func collect_weapon(item: Dictionary) -> String:
	var iname: String = String(item.get("name", "Weapon"))
	# 1) Already wielding this type? Level it up (primary first, then extras).
	if String(weapon.get("name", "")) == iname:
		weapon = _leveled(weapon)
		emit_signal("weapon_changed", weapon)
		emit_signal("stats_changed")
		return "%s  →  Lv %d" % [iname, int(weapon.get("lvl", 1))]
	for i in extra_weapons.size():
		if String((extra_weapons[i] as Dictionary).get("name", "")) == iname:
			extra_weapons[i] = _leveled(extra_weapons[i])
			emit_signal("stats_changed")
			return "%s  →  Lv %d" % [iname, int((extra_weapons[i] as Dictionary).get("lvl", 1))]
	# 2) Free slot → add it as a new auto-firing secondary weapon.
	if extra_weapons.size() < MAX_EXTRA_WEAPONS:
		extra_weapons.append(item.duplicate(true))
		Stats.weapon_equipped(iname)
		emit_signal("stats_changed")
		return "NEW WEAPON:  %s  (slot %d)" % [iname, extra_weapons.size() + 1]
	# 3) Slots full → pour it into your weakest weapon as a level.
	var widx: int = _weakest_weapon_index()
	if widx == 0:
		weapon = _leveled(weapon)
		emit_signal("weapon_changed", weapon)
	else:
		extra_weapons[widx - 1] = _leveled(extra_weapons[widx - 1])
	emit_signal("stats_changed")
	return "Slots full — leveled your weakest weapon"

# Rebuild a weapon dict one level higher along its evolution path.
func _leveled(w: Dictionary) -> Dictionary:
	var arch: Dictionary = _archetype_by_name(String(w.get("name", "")))
	var lvl: int = mini(WEAPON_MAX_LVL, int(w.get("lvl", 1)) + 1)
	return _build_weapon(arch, lvl, int(w.get("rarity", 0)))

# 0 = primary, 1.. = extra_weapons[idx-1]. Lowest DPS-score wins.
func _weakest_weapon_index() -> int:
	var best_i: int = 0
	var best: float = _score(weapon)
	for i in extra_weapons.size():
		var s: float = _score(extra_weapons[i])
		if s < best:
			best = s
			best_i = i + 1
	return best_i

# ── loot generation ────────────────────────────────────────────────────────
func roll_rarity() -> int:
	# Deeper floors skew rarer. Floor 1 is now mostly commons (~76%) so a Magic+
	# isn't a near-guaranteed floor-1 power spike; rarity ramps hard with depth.
	var r: float = randf()
	var d: float = float(depth)
	if r < 0.005 + d * 0.012: return 3   # legendary  (floor1 ~1.7%)
	if r < 0.05 + d * 0.025:  return 2   # rare       (floor1 ~7.5%)
	if r < 0.20 + d * 0.045:  return 1   # magic      (floor1 ~24%)
	return 0                              # common     (floor1 ~76%)

func _pick_archetype() -> Dictionary:
	# Weighted pick — archetypes default to weight 1.0; gimmick weapons can be rarer.
	var total: float = 0.0
	for a in ARCHETYPES:
		total += float(a.get("weight", 1.0))
	var r: float = randf() * total
	for a in ARCHETYPES:
		r -= float(a.get("weight", 1.0))
		if r <= 0.0:
			return a
	return ARCHETYPES[0]

func roll_weapon() -> Dictionary:
	# SIDEGRADE, not gamble: the floor drop is always a DIFFERENT archetype, scaled
	# (by level) so its effective DPS is at least on par with your current weapon —
	# never a strict downgrade, just a different playstyle. Rarity still sets how far
	# along its level path it starts (and its sell value).
	var cur_name: String = String(weapon.get("name", "")) if not weapon.is_empty() else ""
	var arch: Dictionary = _pick_archetype()
	for _t in 6:                                   # avoid re-offering the gun you already hold
		if String(arch.get("name", "")) != cur_name:
			break
		arch = _pick_archetype()
	var rar: int = roll_rarity()
	# Match on RAW throughput (dmg×count÷cooldown), NOT the pierce/bounce-inflated effective
	# DPS — raw parity keeps swaps as true sidegrades (no 5x ratchet).
	# CRUCIAL: the drop level is hard-capped by DEPTH (+rarity). Without this, a weak
	# archetype got leveled all the way to Lv8 just to match your card-leveled weapon —
	# so floor 2 handed you "Cheese Spike Lv8" with 2x DPS ("wtf"). Now floor 2 commons
	# top out around Lv2-3; the cap rises ~1 level every 2 floors.
	var target: float = _score(weapon) if not weapon.is_empty() else 0.0
	var lvl_cap: int = clampi(1 + rar + int(ceil(float(depth) / 2.0)), 1, WEAPON_MAX_LVL)
	var lvl: int = mini(lvl_cap, 1 + rar)
	var w: Dictionary = _build_weapon(arch, lvl, rar)
	while lvl < lvl_cap and _score(w) < target:
		lvl += 1
		w = _build_weapon(arch, lvl, rar)
	return w

func _score(w: Dictionary) -> float:
	# Rough DPS-ish value so "is this drop better?" is answerable.
	return float(w["dmg"]) * float(w["count"]) / maxf(0.08, float(w["cooldown"]))

# Coins you get for declining a floor drop — scales with rarity and depth so a
# rare drop you skip still feels worth something.
func weapon_sell_value(w: Dictionary) -> int:
	# Trimmed ~40%: auto-selling every floor drop was minting more gold than anyone
	# could spend. Rarer/deeper still pays more, just not a flood.
	var rar: int = clampi(int(w.get("rarity", 0)), 0, 3)
	return 1 + rar * 2 + int(depth / 2)

# Effective stats for a weapon dict (folds in global run upgrades) — used by the
# floor-pickup comparison cards so the numbers match what you'd actually deal.
func weapon_eval(w: Dictionary) -> Dictionary:
	var dmg: int = int(ceil(float(w.get("dmg", 1)) * dmg_mult)) + bonus_damage()
	var cd: float = maxf(0.06, float(w.get("cooldown", 0.34)) * cooldown_mult)
	var cnt: int = int(w.get("count", 1)) + bonus_projectiles
	# EFFECTIVE DPS — pierce/bounce catch extra enemies, so they're worth more than the raw
	# single-target number. But the bonus has DIMINISHING RETURNS and a hard CAP: a 19-bounce
	# gun does NOT do 19× — most bounces hit walls, not mobs. Without the cap the comparison
	# card read "2312 DPS" it could never actually deal. Pierce is more reliable than bounce.
	var pierce: int = int(w.get("pierce", 0))
	var bounces: int = int(w.get("bounces", 0))
	var multi: float = 1.0 + 0.5 * float(pierce) + 0.16 * float(bounces)
	multi = minf(multi, 2.4)   # at most ~2.4× from multi-hit, no matter how silly the stat
	var eff: float = (float(dmg * cnt) / cd) * multi
	return {
		"dps": eff,
		"dmg": dmg,
		"rate": 1.0 / cd,
		"count": cnt,
		"speed": float(w.get("speed", 600.0)),
		"pierce": int(w.get("pierce", 0)),
		"bounces": int(w.get("bounces", 0)),
		"ball": bool(w.get("ball", false)),
	}

func try_equip(item: Dictionary) -> bool:
	# Swapping isn't a hard reset: the new weapon CARRIES HALF your current weapon
	# level (so an evolved Lv8 doesn't drop you back to a raw Lv1 on a type change).
	var old_lvl: int = int(weapon.get("lvl", 1)) if not weapon.is_empty() else 1
	var carried: int = maxi(int(item.get("lvl", 1)), int(floor(float(old_lvl) * 0.5)))
	var arch: Dictionary = _archetype_by_name(String(item.get("name", "")))
	weapon = _build_weapon(arch, carried, int(item.get("rarity", 0)))
	Stats.weapon_equipped(String(weapon.get("name", "?")))
	emit_signal("weapon_changed", weapon)
	var col: Color = RARITY_COLORS[int(weapon.get("rarity", 0))]
	emit_signal("toast", "%s  Lv %d  equipped" % [weapon.get("name", "Weapon"), carried], col)
	emit_signal("stats_changed")
	return true

# ── kill / xp / gold ────────────────────────────────────────────────────────
func notify_kill(pos: Vector2) -> void:
	if not active:
		return
	add_xp(2 + depth)
	var g: int = randi_range(1, 2 + int(depth / 2))   # less per-kill gold
	gold += g
	Stats.gold_gained(g)
	emit_signal("stats_changed")
	# Weapon drops are DISABLED. Each hero has ONE weapon they upgrade along branching
	# paths — no floor drops, no swapping, no multi-weapon. (Reverted the loot flood.)

func add_xp(amount: int) -> void:
	xp += amount
	Stats.xp_gained(amount)
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = int(round(float(xp_to_next) * 1.35)) + 2
		Stats.leveled()
		emit_signal("leveled_up", level)
		emit_signal("toast", "LEVEL  %d" % level, Color(1.0, 0.86, 0.3))
	emit_signal("stats_changed")

func descend() -> void:
	depth += 1
	Stats.note_floor(depth)
	# Rotate to a fresh biome for the next floor (skip if a boss-portal forced a
	# backrooms stage). Themed levels also get a random design variant.
	if not backrooms_next:
		if not scripted_queue.is_empty():
			# Authored sequence (e.g. pool rooms → wheat after the backrooms portal):
			# pull the next forced scene instead of rolling a random biome.
			dungeon_path = String(scripted_queue.pop_front())
			_last_biome = dungeon_path
		else:
			dungeon_path = _pick_biome()
		pending_variant = randi_range(1, 5)
	emit_signal("stats_changed")

func _pick_biome() -> String:
	var pool: Array = BIOMES.duplicate()
	pool.erase(_last_biome)        # avoid the same biome twice in a row
	if pool.is_empty():
		pool = BIOMES.duplicate()
	_last_biome = pool[randi() % pool.size()]
	return _last_biome

# Player stat scaling from level + shop (loot supplies the weapon).
func bonus_max_health() -> int:
	# HP growth now comes from level-up CARDS + shop boons (bonus_maxhp), not a
	# passive per-level trickle. Keeps the level system meaningful (you choose).
	return bonus_maxhp

func bonus_damage() -> int:
	# Damage growth now comes from level-up cards / boons (dmg_mult), not a passive.
	return 0

func boss_hp() -> int:
	return 110 + depth * 35

# ── shop (between-floor merchant) ───────────────────────────────────────────
# Weapon-specific upgrades for the CURRENTLY equipped weapon. Each modifies the
# weapon dict directly and bumps its level (so the next one costs more). Swapping
# weapons starts fresh — invest in the one you want to keep.
func weapon_upgrade_options() -> Array:
	# Branch picks for the hero's single weapon tree. At the FIRST shop you choose a
	# PATH (two cards); after that you advance one tier at a time (one card). Empty
	# once the chosen path is fully maxed.
	var tree: Dictionary = _tree()
	var paths: Dictionary = tree["paths"]
	var wcol: Color = tree.get("color", Color(1.0, 0.8, 0.4))
	var out: Array = []
	if weapon_path == "":
		for key in paths.keys():
			var p: Dictionary = paths[key]
			var t0: Dictionary = (p["tiers"] as Array)[0]
			out.append({
				"id": "branch", "branch_path": String(key),
				"name": "%s: %s" % [String(p["name"]), String(t0["name"])],
				"desc": String(p.get("blurb", "")) + "\n→ " + String(t0["desc"]),
				"color": wcol,
			})
	elif not tree_is_maxed():
		var tiers: Array = paths[weapon_path]["tiers"]
		var t: Dictionary = tiers[weapon_tier]   # weapon_tier = #applied = index of next tier
		out.append({
			"id": "branch", "branch_path": weapon_path,
			"name": "%s: %s" % [String(paths[weapon_path]["name"]), String(t["name"])],
			"desc": String(t["desc"]),
			"color": wcol,
		})
	return out

func _weapon_upgrade_cost() -> int:
	# Branch picks cost more as you go deeper into the tree.
	return int(round((20.0 + weapon_tier * 10.0) * (1.0 + 0.15 * float(depth - 1))))

func generate_shop(_count: int = 5) -> Array:
	var offers: Array = []
	# Weapon branch offers first (1 advance card, or 2 path cards at the first shop).
	for wo0 in weapon_upgrade_options():
		var wo: Dictionary = (wo0 as Dictionary).duplicate(true)
		wo["weapon_upgrade"] = true
		wo["cost"] = _weapon_upgrade_cost()
		offers.append(wo)
	# global run upgrades fill the rest.
	var pool: Array = [
		{"id": "maxhp",     "name": "Reinforced Stuffing", "desc": "+4 Max HP",          "color": Color(0.4, 0.9, 0.5)},
		{"id": "dmg",       "name": "Sharper Toppings",     "desc": "+10% Damage (all)",  "color": Color(1.0, 0.5, 0.4)},
		{"id": "firerate",  "name": "Greased Oven",         "desc": "+12% Fire Rate (all)", "color": Color(1.0, 0.85, 0.4)},
		{"id": "crit",      "name": "Spicy Pepperoni",      "desc": "+7% Crit Chance",   "color": Color(1.0, 0.4, 0.7)},
		{"id": "speed",     "name": "Roller Skates",        "desc": "+8% Move Speed",     "color": Color(0.5, 0.8, 1.0)},
	]
	if crit_chance >= 0.50:   # crit capped — drop the dead "50% → 50%" offer
		pool = pool.filter(func(c: Dictionary) -> bool: return String(c.get("id", "")) != "crit")
	if not back_shot and level >= 5:   # gated — it's a build-defining power spike, not a lvl-2 freebie
		pool.append({"id": "back_shot", "name": "Back Shot", "desc": "Also fire out the back", "color": Color(0.7, 0.5, 1.0)})
	pool.shuffle()
	var need: int = maxi(0, 5 - offers.size())   # aim for ~5 cards total
	for i in mini(need, pool.size()):
		var item: Dictionary = pool[i].duplicate(true)
		item["cost"] = _shop_cost(String(item["id"]))
		offers.append(item)
	return offers

# Concrete "current → after" for a shop offer, so the player sees the real effect
# (not just "+7% Crit"). Returns "" if there's nothing meaningful to show.
func shop_preview(offer: Dictionary) -> String:
	# Weapon BRANCH offer — simulate applying it and compare DPS.
	if bool(offer.get("weapon_upgrade", false)) or String(offer.get("id", "")) == "branch":
		var before: Dictionary = weapon_eval(weapon)
		var save_path: String = weapon_path
		var save_tier: int = weapon_tier
		var bp: String = String(offer.get("branch_path", ""))
		if weapon_path == "":
			weapon_path = bp
			weapon_tier = 1
		elif bp == weapon_path and not tree_is_maxed():
			weapon_tier += 1
		var after: Dictionary = weapon_eval(_build_tree_weapon())
		weapon_path = save_path
		weapon_tier = save_tier
		return "DPS  %.0f → %.0f" % [float(before.get("dps", 0.0)), float(after.get("dps", 0.0))]
	match String(offer.get("id", "")):
		"crit":
			return "Crit  %d%% → %d%%" % [int(crit_chance * 100.0), int(minf(crit_chance + 0.07, 0.50) * 100.0)]
		"dmg":
			var cur: int = int(weapon_eval(weapon).get("dmg", 0))
			var nxt: int = int(ceil(float(weapon.get("dmg", 1)) * dmg_mult * 1.10)) + bonus_damage()
			return "Damage  %d → %d" % [cur, nxt]
		"firerate":
			var cd: float = weapon_cooldown()
			return "Fire rate  %.2f/s → %.2f/s" % [1.0 / cd, 1.0 / maxf(0.06, cd * 0.88)]
		"speed":
			return "Move speed  +%d%% → +%d%%" % [int(round((speed_mult - 1.0) * 100.0)), int(round((speed_mult + 0.08 - 1.0) * 100.0))]
		"maxhp":
			var hp: int = 5 + MetaSave.upgrade_level("more_plush") + bonus_maxhp
			return "Max HP  %d → %d" % [hp, hp + 4]
		"back_shot":
			return "Adds a 2nd volley out your back"
		"weapon":
			var lv: int = int(weapon.get("lvl", 1))
			return "%s Lv%d  →  Rare+ Lv%d" % [RARITY_NAMES[int(weapon.get("rarity", 0))], lv, maxi(1, lv / 2)]
	return ""

func _shop_cost(id: String) -> int:
	var base: Dictionary = {"maxhp": 18, "dmg": 26, "firerate": 24, "crit": 22, "speed": 16, "weapon": 20, "back_shot": 40}
	var b: int = int(base.get(id, 22))
	return int(round(float(b) * (1.0 + 0.25 * float(depth - 1))))

func buy(item: Dictionary) -> bool:
	var cost: int = int(item.get("cost", 999999))
	if gold < cost:
		emit_signal("toast", "Not enough gold", Color(1.0, 0.5, 0.4))
		return false
	gold -= cost
	apply_upgrade(item)
	return true

# Applies an upgrade's EFFECT (no gold cost) — shared by the shop and the level-up
# card screen.
func apply_upgrade(item: Dictionary) -> void:
	var id: String = String(item.get("id", ""))
	if bool(item.get("weapon_upgrade", false)) or id == "branch":
		# Advance the weapon tree: pick a path the first time, then step a tier.
		var bp: String = String(item.get("branch_path", ""))
		if weapon_path == "":
			weapon_path = bp
			weapon_tier = 1
		elif bp == weapon_path and not tree_is_maxed():
			weapon_tier += 1
		weapon = _build_tree_weapon()
		emit_signal("weapon_changed", weapon)
		emit_signal("stats_changed")
		return
	else:
		match id:
			"maxhp":     bonus_maxhp += 4
			"dmg":       dmg_mult *= 1.10   # true compounding +10% of CURRENT damage
			"firerate":  cooldown_mult *= 0.88
			"crit":      crit_chance = minf(crit_chance + 0.07, 0.50)   # capped at 50%
			"speed":     speed_mult += 0.08
			"back_shot": back_shot = true
	emit_signal("stats_changed")

# Three random upgrade choices shown on level-up (mix of global boons + upgrades
# for the equipped weapon). This is where build progression now happens.
func level_up_options() -> Array:
	var pool: Array = [
		{"id": "maxhp",    "name": "Reinforced Stuffing", "desc": "+4 Max HP",        "color": Color(0.4, 0.9, 0.5)},
		{"id": "dmg",      "name": "Sharper Toppings",    "desc": "+10% Damage",      "color": Color(1.0, 0.5, 0.4)},
		{"id": "firerate", "name": "Greased Oven",        "desc": "+12% Fire Rate",   "color": Color(1.0, 0.85, 0.4)},
		{"id": "crit",     "name": "Spicy Pepperoni",     "desc": "+7% Crit Chance", "color": Color(1.0, 0.4, 0.7)},
		{"id": "speed",    "name": "Roller Skates",       "desc": "+8% Move Speed",   "color": Color(0.5, 0.8, 1.0)},
	]
	if crit_chance >= 0.50:   # crit is capped — don't offer a dead "50% → 50%" card
		pool = pool.filter(func(c: Dictionary) -> bool: return String(c.get("id", "")) != "crit")
	if not back_shot and level >= 5:   # gated — it's a build-defining power spike, not a lvl-2 freebie
		pool.append({"id": "back_shot", "name": "Back Shot", "desc": "Also fire backward", "color": Color(0.7, 0.5, 1.0)})
	pool.shuffle()
	# Level-ups give GLOBAL boons only. Weapon progression happens at the shop (the
	# branching tree), so the two systems don't step on each other.
	return pool.slice(0, 3)

# Which global-upgrade id the equipped weapon's NEXT level step overlaps with
# ("firerate" / "dmg" / "") — used to de-dupe the level-up card choices.
func _weapon_step_global_id() -> String:
	var lvl: int = int(weapon.get("lvl", 1))
	var path: Array = LEVEL_PATHS.get(String(weapon.get("name", "")), [])
	if lvl - 1 < path.size():
		var step: Dictionary = path[lvl - 1]
		if step.has("cd"):
			return "firerate"
		if step.has("dmg"):
			return "dmg"
	return ""
