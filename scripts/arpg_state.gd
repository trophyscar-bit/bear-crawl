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
var light_mode: int = 1   # which live lighting preset is active (persists across floors)
var light_boost: int = 1  # 1-5 brightness pump on all light sources (persists)
var brightness_level: int = 2  # dungeon darkness preset 1=dark 2=medium 3=bright (persists)
var auto_sell_rarity: bool = false  # auto-sell drops of same-or-lower rarity (persists)
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
	Color(0.78, 0.78, 0.82),   # common  - grey
	Color(0.45, 0.65, 1.0),    # magic   - blue
	Color(1.0, 0.82, 0.30),    # rare    - gold
	Color(1.0, 0.5, 0.2),      # legend  - orange
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

func reset_run() -> void:
	active = true
	depth = 1
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
	light_boost = 1
	enemy_bright = 1
	backrooms_pack = 5
	weapon = _starter_weapon()
	emit_signal("weapon_changed", weapon)
	emit_signal("stats_changed")

# ── effective combat stats (weapon + run upgrades) ──────────────────────────
func weapon_damage() -> int:
	return int(ceil(float(weapon.get("dmg", 1)) * dmg_mult)) + bonus_damage()

func weapon_cooldown() -> float:
	return maxf(0.06, float(weapon.get("cooldown", 0.34)) * cooldown_mult)

func weapon_count() -> int:
	return int(weapon.get("count", 1)) + bonus_projectiles

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
	var w: Dictionary = ARCHETYPES[0].duplicate(true)
	w["rarity"] = 0
	w["score"] = _score(w)
	return w

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
	var w: Dictionary = _pick_archetype().duplicate(true)
	var rar: int = roll_rarity()
	var rmult: float = 1.0 + 0.14 * float(rar)                # rarity scaling (toned down)
	var dmult: float = 1.0 + 0.07 * float(depth - 1)          # depth scaling (toned down)
	w["dmg"] = int(ceil(float(w["dmg"]) * rmult * dmult))
	w["speed"] = float(w["speed"]) * (1.0 + 0.04 * float(rar))
	w["cooldown"] = maxf(0.08, float(w["cooldown"]) * (1.0 - 0.06 * float(rar)))
	w["rarity"] = rar
	w["score"] = _score(w)
	return w

func _score(w: Dictionary) -> float:
	# Rough DPS-ish value so "is this drop better?" is answerable.
	return float(w["dmg"]) * float(w["count"]) / maxf(0.08, float(w["cooldown"]))

# Coins you get for declining a floor drop — scales with rarity and depth so a
# rare drop you skip still feels worth something.
func weapon_sell_value(w: Dictionary) -> int:
	var rar: int = clampi(int(w.get("rarity", 0)), 0, 3)
	return 2 + rar * 3 + depth

# Effective stats for a weapon dict (folds in global run upgrades) — used by the
# floor-pickup comparison cards so the numbers match what you'd actually deal.
func weapon_eval(w: Dictionary) -> Dictionary:
	var dmg: int = int(ceil(float(w.get("dmg", 1)) * dmg_mult)) + bonus_damage()
	var cd: float = maxf(0.06, float(w.get("cooldown", 0.34)) * cooldown_mult)
	var cnt: int = int(w.get("count", 1)) + bonus_projectiles
	return {
		"dps": float(dmg * cnt) / cd,
		"dmg": dmg,
		"rate": 1.0 / cd,
		"count": cnt,
		"speed": float(w.get("speed", 600.0)),
		"pierce": int(w.get("pierce", 0)),
		"bounces": int(w.get("bounces", 0)),
		"ball": bool(w.get("ball", false)),
	}

func try_equip(item: Dictionary) -> bool:
	var better: bool = weapon.is_empty() or float(item.get("score", 0.0)) >= float(weapon.get("score", 0.0))
	if better:
		weapon = item
		emit_signal("weapon_changed", weapon)
		var col: Color = RARITY_COLORS[int(item.get("rarity", 0))]
		emit_signal("toast", "%s %s  equipped" % [RARITY_NAMES[int(item.get("rarity", 0))], item.get("name", "Weapon")], col)
	else:
		gold += 3
		emit_signal("toast", "+3 gold (sold weaker drop)", Color(1.0, 0.85, 0.4))
		emit_signal("stats_changed")
	return better

# ── kill / xp / gold ────────────────────────────────────────────────────────
func notify_kill(pos: Vector2) -> void:
	if not active:
		return
	add_xp(2 + depth)
	var g: int = randi_range(1, 2 + int(depth / 2))   # less per-kill gold
	gold += g
	emit_signal("stats_changed")
	# Loot drop chance (weapons). Lowered hard so the floor isn't paved with free
	# coins (you could farm-sell trash drops into a full shop by floor 3).
	if randf() < 0.16:
		emit_signal("loot_dropped", pos, roll_weapon())

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = int(round(float(xp_to_next) * 1.35)) + 2
		emit_signal("leveled_up", level)
		emit_signal("toast", "LEVEL  %d" % level, Color(1.0, 0.86, 0.3))
	emit_signal("stats_changed")

func descend() -> void:
	depth += 1
	emit_signal("stats_changed")

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
	var wcol: Color = weapon.get("color", Color(1.0, 0.8, 0.4))
	var opts: Array = [
		{"id": "w_dmg",      "name": "Sharpen",     "desc": "+1 Damage",     "color": wcol},
		{"id": "w_firerate", "name": "Quick Hands", "desc": "-10% Cooldown", "color": wcol},
		{"id": "w_pierce",   "name": "Piercing",    "desc": "+1 Pierce",     "color": wcol},
	]
	if bool(weapon.get("ball", false)):
		opts.append({"id": "w_bounce", "name": "Super Bounce", "desc": "+3 Bounces", "color": wcol})
		# The Bouncy Blaster is a weak-but-spammy speed weapon — give it a meatier
		# damage path so you can actually build it up.
		opts.append({"id": "w_dmg2", "name": "Dense Core", "desc": "+2 Damage", "color": wcol})
	elif int(weapon.get("count_ups", 0)) < 1:
		# +1 Projectile is a huge multiplicative DPS spike — offer it at most ONCE per
		# weapon (stacking it to 4-5 shots was what broke the game).
		opts.append({"id": "w_count", "name": "Multi-Throw", "desc": "+1 Projectile (one-time)", "color": wcol})
	return opts

func _weapon_upgrade_cost() -> int:
	var lvl: int = int(weapon.get("lvl", 0))
	return int(round((30.0 + lvl * 13.0) * (1.0 + 0.2 * float(depth - 1))))

func generate_shop(_count: int = 5) -> Array:
	var offers: Array = []
	# 2 upgrades for the current weapon (badged "WEAPON").
	var wopts: Array = weapon_upgrade_options()
	wopts.shuffle()
	var wcost: int = _weapon_upgrade_cost()
	for i in mini(2, wopts.size()):
		var wo: Dictionary = wopts[i].duplicate(true)
		wo["weapon_upgrade"] = true
		wo["cost"] = wcost
		if String(wo.get("id", "")) == "w_count":
			wo["cost"] = int(round(float(wcost) * 2.5))   # premium price on the +projectile
		wo["weapon_name"] = String(weapon.get("name", "Weapon"))
		offers.append(wo)
	# 3 global run upgrades.
	var pool: Array = [
		{"id": "maxhp",     "name": "Reinforced Stuffing", "desc": "+4 Max HP",          "color": Color(0.4, 0.9, 0.5)},
		{"id": "dmg",       "name": "Sharper Toppings",     "desc": "+10% Damage (all)",  "color": Color(1.0, 0.5, 0.4)},
		{"id": "firerate",  "name": "Greased Oven",         "desc": "+12% Fire Rate (all)", "color": Color(1.0, 0.85, 0.4)},
		{"id": "crit",      "name": "Spicy Pepperoni",      "desc": "+10% Crit Chance",   "color": Color(1.0, 0.4, 0.7)},
		{"id": "speed",     "name": "Roller Skates",        "desc": "+8% Move Speed",     "color": Color(0.5, 0.8, 1.0)},
		{"id": "weapon",    "name": "Mystery Box",          "desc": "New random weapon — Rare+ (resets weapon upgrades)", "color": Color(0.85, 0.85, 0.9)},
	]
	if not back_shot:
		pool.append({"id": "back_shot", "name": "Back Shot", "desc": "Also fire out the back", "color": Color(0.7, 0.5, 1.0)})
	pool.shuffle()
	for i in mini(3, pool.size()):
		var item: Dictionary = pool[i].duplicate(true)
		item["cost"] = _shop_cost(String(item["id"]))
		offers.append(item)
	return offers

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
	if bool(item.get("weapon_upgrade", false)):
		match id:
			"w_dmg":      weapon["dmg"] = int(weapon.get("dmg", 1)) + 1
			"w_dmg2":     weapon["dmg"] = int(weapon.get("dmg", 1)) + 2
			"w_firerate": weapon["cooldown"] = maxf(0.07, float(weapon.get("cooldown", 0.34)) * 0.9)
			"w_pierce":   weapon["pierce"] = int(weapon.get("pierce", 0)) + 1
			"w_count":
				weapon["count"] = int(weapon.get("count", 1)) + 1
				weapon["count_ups"] = int(weapon.get("count_ups", 0)) + 1
			"w_bounce":   weapon["bounces"] = int(weapon.get("bounces", 1)) + 3
		weapon["lvl"] = int(weapon.get("lvl", 0)) + 1
		emit_signal("weapon_changed", weapon)
	else:
		match id:
			"maxhp":     bonus_maxhp += 4
			"dmg":       dmg_mult += 0.10
			"firerate":  cooldown_mult *= 0.88
			"crit":      crit_chance = minf(crit_chance + 0.10, 0.75)
			"speed":     speed_mult += 0.08
			"back_shot": back_shot = true
			"weapon":
				# Mystery Box: a fresh random weapon, but guaranteed Rare or better so
				# it's a real gamble on TYPE (not a downgrade in rarity). It does reset
				# weapon-specific upgrades since it's a brand-new weapon.
				var rolled: Dictionary = roll_weapon()
				for _try in 8:
					if int(rolled.get("rarity", 0)) >= 2:
						break
					rolled = roll_weapon()
				weapon = rolled
				emit_signal("weapon_changed", weapon)
	emit_signal("stats_changed")

# Three random upgrade choices shown on level-up (mix of global boons + upgrades
# for the equipped weapon). This is where build progression now happens.
func level_up_options() -> Array:
	var pool: Array = [
		{"id": "maxhp",    "name": "Reinforced Stuffing", "desc": "+4 Max HP",        "color": Color(0.4, 0.9, 0.5)},
		{"id": "dmg",      "name": "Sharper Toppings",    "desc": "+10% Damage",      "color": Color(1.0, 0.5, 0.4)},
		{"id": "firerate", "name": "Greased Oven",        "desc": "+12% Fire Rate",   "color": Color(1.0, 0.85, 0.4)},
		{"id": "crit",     "name": "Spicy Pepperoni",     "desc": "+10% Crit Chance", "color": Color(1.0, 0.4, 0.7)},
		{"id": "speed",    "name": "Roller Skates",       "desc": "+8% Move Speed",   "color": Color(0.5, 0.8, 1.0)},
	]
	if not back_shot:
		pool.append({"id": "back_shot", "name": "Back Shot", "desc": "Also fire backward", "color": Color(0.7, 0.5, 1.0)})
	# Upgrades specific to the equipped weapon.
	for wo in weapon_upgrade_options():
		var w2: Dictionary = (wo as Dictionary).duplicate(true)
		w2["weapon_upgrade"] = true
		pool.append(w2)
	pool.shuffle()
	return pool.slice(0, mini(3, pool.size()))
