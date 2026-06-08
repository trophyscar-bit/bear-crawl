extends Node2D

# DEV TEST ARENA — a blank, fully-lit sandbox of walled-off boxes, each
# demonstrating one thing we've changed: the new explosion, ground AoE and
# Dark-Bolt paw slam (looping), every enemy type performing its attack when you
# walk up (arena_mode bypasses line-of-sight so penned enemies still fire), and
# a backrooms props box. You're invincible. ESC returns to the title.

const PlayerScene          := preload("res://scenes/player.tscn")
const EnemyScene           := preload("res://scenes/enemy.tscn")
const GunBearScene         := preload("res://scenes/gun_bear.tscn")
const GrowlerScene         := preload("res://scenes/growler.tscn")
const ShrinkwrapBearScene  := preload("res://scenes/shrinkwrap_bear.tscn")
const PlushBrawlerScene    := preload("res://scenes/plush_brawler.tscn")
const DucklingScene        := preload("res://scenes/duckling.tscn")
const HoundScene           := preload("res://scenes/hound.tscn")
const FrostCubScene        := preload("res://scenes/frost_cub.tscn")
const SealScene            := preload("res://scenes/seal.tscn")
const ArmyBearScene        := preload("res://scenes/army_bear.tscn")
const BeanieBearScene      := preload("res://scenes/beanie_bear.tscn")
const TeddyBearScene       := preload("res://scenes/teddy_bear.tscn")
const CreamBearScene       := preload("res://scenes/cream_bear.tscn")
const DarkAllyScene        := preload("res://scenes/dark_bear_ally.tscn")
const SkeletonScene        := preload("res://scenes/skeleton.tscn")
const ExplosionScene       := preload("res://scenes/explosion.tscn")
const GroundSlamScene      := preload("res://scenes/ground_slam.tscn")
const BearPawSlamScene     := preload("res://scenes/bear_paw_slam.tscn")
const PizzaScene           := preload("res://scenes/pizza.tscn")
const BouncyBallTex        := preload("res://assets/bouncy_ball.png")
const PizzaIconTex         := preload("res://assets/pizza.png")
const BallIconTex          := preload("res://assets/bouncy_ball.png")
const HealthBarLib         := preload("res://scripts/health_bar.gd")

const IDEAS := [
	"1. Pool Rooms level (pool core sheets): white-tile floor, water hazards, slides.",
	"2. Forest level (forest kit): grass/dirt/water tiles, trees, bushes, stones.",
	"3. Suburbia level (Level-10): houses, fences, tractor, trees — an outdoor floor.",
	"4. Level 1 / Poolrooms as deeper descent floors after the backrooms.",
	"5. Health-bar styles (this screen) — pick Segmented / Hearts / Gradient / Blocks / Ornate / Minimal.",
	"6. Parchment GUI panels (assets/ui) for the shop + pause menus.",
	"7. Pizzeria projectiles: breadstick, soda can, meatball — needs a small food pack.",
	"8. Per-weapon projectile + loot icon (drop in the HumanIsRed weapons/bullets pack).",
	"9. Reskin enemies per biome (tint/props) so each floor's bears look themed.",
	"10. Spark FX as a bullet-impact puff; Lightning as a rare elite attack.",
	"11. Destructible barrels/crates (containers) that drop coins.",
	"12. Graffiti-alphabet wall text in the backrooms (Level-0 sheets have a font).",
	"13. Beds/couches diorama rooms (abandoned office vibe).",
	"14. Water-bottle / clutter pickups as minor heals.",
	"15. Boss arena with a themed floor + ground-crack decals.",
	"16. Slow-mo + step toggles (this screen) for tuning attack timings.",
	"17. Weapon test bench: cycle every weapon and fire it (see WEAPON boxes below).",
	"18. Trap showcase: ripple lines / spike choke points to preview hazards.",
]

# Backrooms levels (Enter-the-Backrooms numbering) mapped to what we could build
# with the assets we have. ✓ = buildable now, ◐ = partial assets, · = needs a pack.
const LEVELS := [
	"0  Lobby — yellow rooms              ✓ BUILT (Backrooms)",
	"1  Lurking Danger — dim damp halls   ◐",
	"2  Pipe Dreams — pipes / boiler      ·",
	"3  Electrical Station                ·",
	"4  Abandoned Office — desks/cubicles ✓ (office furniture)",
	"5  Terror Hotel — hotel halls        ·",
	"6  Lights Out — pitch black          ✓ (fog only)",
	"7  Flooded Sewers                    ◐ (pool water)",
	"8  Forgotten Mineshaft               ·",
	"9  The Suburbs — houses              ◐ (Level-10 sheets)",
	"10 Field of Wheat                    ✓ (Level-10 farm)",
	"11 The Endless City                  ·",
	"13 Infinite Apartments               ·",
	"20 Warehouse — crates/barrels        ◐ (containers)",
	"22 Free Parking — garage             ✓ (Level-1)",
	"35 An Empty Car Park                 ✓ (Level-1)",
	"37 The Poolrooms — pools             ✓ (pool core)",
	"40 Roller Rockin' Pizza! — arcade    ★ on-theme for THIS game!",
	"45 Abyss Inc — corporate             ◐ (office)",
	"50 The Moribund Highway              ·",
	"55 Land of Ice                       ◐ (frost theme)",
	"60 A Clean Slate — white void        ✓ (flat white)",
	"100 Soundless Solitude               ·",
	"101 261 Turner Lane (house)          ◐",
	"…  full 0-999 list on the backrooms wiki",
]

const PEN := Vector2(380, 300)
const COLS := 4
const STEP := Vector2(540, 470)
const WALL_TH := 18.0
const ORIGIN := Vector2(0, 0)

var _player: Node2D = null
var _camera: Camera2D = null
var _fx: Array = []   # [{pos, kind, t, interval}]
var _hud_layer: CanvasLayer = null
var _cat: String = ""
var _cat_buttons: Dictionary = {}

func _ready() -> void:
	ArpgState.reset_run()                 # gives the starter weapon + active state
	ArpgState.spawn_grace_msec = 0        # no entry grace in the sandbox
	DevState.arena_mode = true            # penned enemies always "see" you
	DevState.invincible = true            # don't die while testing
	_build_camera()
	_build_hud()
	_spawn_player(Vector2.ZERO)
	_show_category("ENEMIES")

# Menu-driven dev room: each category button rebuilds the world with just that
# group of boxes, laid out in a 4-column grid.
func _show_category(cat: String) -> void:
	_cat = cat
	_fx.clear()
	for c in get_children():
		if c == _player or c == _camera or c == _hud_layer:
			continue
		c.queue_free()
	for k in _cat_buttons:
		var b := _cat_buttons[k] as Button
		if is_instance_valid(b):
			b.modulate = Color(1.0, 0.9, 0.4) if k == cat else Color(1, 1, 1)
	match cat:
		"FX": _grid_stations(_fx_stations(), PEN, STEP)
		"ENEMIES": _grid_stations(_enemy_stations(), PEN, STEP)
		"WEAPONS": _grid_stations(_weapon_stations(), PEN, STEP)
		"PROPS": _grid_stations(_prop_stations(), PEN, STEP)
		"LEVELS": _build_levels_grid()
	# Park the player (enemy target) and centre the drag-camera on this category.
	var view: Vector2 = ORIGIN + Vector2(STEP.x * 1.3, STEP.y * 0.6)
	if is_instance_valid(_player):
		_player.position = view
		if "velocity" in _player:
			_player.set("velocity", Vector2.ZERO)
	if is_instance_valid(_camera):
		_camera.position = view

func _grid_stations(stations: Array, box: Vector2, step: Vector2) -> void:
	for i in stations.size():
		var col: int = i % COLS
		var row: int = i / COLS
		_build_station(stations[i], ORIGIN + Vector2(float(col) * step.x, float(row) * step.y))

func _fx_stations() -> Array:
	return [
		{"title": "EXPLOSION  (Fire-bomb)", "kind": "fx_explosion", "open": true},
		{"title": "GROUND AOE  (Boss slam)", "kind": "fx_aoe", "open": true},
		{"title": "PAW SLAM  (Lightning)", "kind": "fx_paw", "open": true},
	]

func _enemy_stations() -> Array:
	return [
		{"title": "KK BEAR  —  stars + paw", "kind": "enemy", "scene": EnemyScene},
		{"title": "GUN BEAR  —  3-round burst", "kind": "enemy", "scene": GunBearScene},
		{"title": "GROWLER  —  archer + dodge", "kind": "enemy", "scene": GrowlerScene},
		{"title": "SHRINKWRAP  —  air puff", "kind": "enemy", "scene": ShrinkwrapBearScene},
		{"title": "BRAWLER  —  charge", "kind": "enemy", "scene": PlushBrawlerScene},
		{"title": "DUCKLING  —  fast swarmer", "kind": "enemy", "scene": DucklingScene},
		{"title": "HOUND  —  fast chaser", "kind": "enemy", "scene": HoundScene},
		{"title": "FROST CUB  —  floating balloon", "kind": "enemy", "scene": FrostCubScene},
		{"title": "LONG BEAR  —  acid trail", "kind": "enemy", "scene": SealScene},
		{"title": "ARMY BEAR  —  airstrike BOSS", "kind": "enemy", "scene": ArmyBearScene},
		{"title": "BEANIE BEAR  —  throws beanies", "kind": "enemy", "scene": BeanieBearScene},
		{"title": "TEDDY BEAR  —  bomber", "kind": "enemy", "scene": TeddyBearScene},
		{"title": "SKELETON  —  melee", "kind": "enemy", "scene": SkeletonScene},
		{"title": "CREAM BEAR", "kind": "enemy", "scene": CreamBearScene},
		{"title": "FINN  —  ally companion", "kind": "ally", "scene": DarkAllyScene, "open": true},
		{"title": "BOSS  —  spread + AOE", "kind": "boss", "scene": EnemyScene},
	]

func _weapon_stations() -> Array:
	var st: Array = []
	for w in ArpgState.ARCHETYPES:
		st.append({"title": "WEAPON:  " + String(w.get("name", "?")), "kind": "weapon", "weapon": w, "open": true})
	return st

func _prop_stations() -> Array:
	return [{"title": "BACKROOMS PROPS", "kind": "props", "open": true}]

func _build_levels_grid() -> Vector2:
	var biomes: Array = [
		{"title": "BACKROOMS", "floor": "res://assets/backrooms_pack5_floor.png", "wall": "res://assets/backrooms_pack5_wall.png", "layout": "tiles"},
		{"title": "POOL ROOMS", "floor": "res://assets/fx/pool/subway.png", "layout": "pool"},
		{"title": "FOREST", "floor": "res://assets/forest_kit/texture only/Forest Tileset - Free/grass.png", "layout": "trees"},
		{"title": "FIELD OF WHEAT (Lv 10)", "floor": "res://assets/fx/biome/wheat_floor.png", "layout": "wheat"},
		{"title": "DUNGEON (Kenney tiles)", "floor": "res://assets/fx/biome/dng_floor.png", "wall": "res://assets/fx/biome/dng_wall.png", "layout": "dungeon"},
		{"title": "DUNGEON · CAVE  (alt)", "floor": "res://assets/texlib/cave_floor.png", "wall": "res://assets/texlib/cave_wall.png", "layout": "dungeon", "tex_note": "Cave Floor 2  +  Cave Wall 2", "swatch": "res://assets/texlib/cave_floor.png"},
		{"title": "DUNGEON · HELL  (alt)", "floor": "res://assets/texlib/hell_floor.png", "wall": "res://assets/texlib/hell_wall.png", "layout": "dungeon", "tex_note": "Hell 2  +  Stone Wall 13", "swatch": "res://assets/texlib/hell_floor.png"},
		{"title": "DUNGEON · CRYPT  (alt)", "floor": "res://assets/texlib/crypt_floor.png", "wall": "res://assets/texlib/crypt_wall.png", "layout": "dungeon", "tex_note": "Cobble 2  +  Stone Wall 1", "swatch": "res://assets/texlib/crypt_floor.png"},
		{"title": "FLOODED SEWERS (Lv 7)", "floor": "res://assets/fx/biome/sewer_floor.png", "layout": "sewers"},
		{"title": "THE SUBURBS (Lv 9)", "floor": "res://assets/fx/biome/tt_grass.png", "layout": "suburbs"},
		{"title": "SPACE HANGAR (Kenney)", "floor": "res://assets/fx/biome/space_floor.png", "layout": "space"},
		{"title": "LEVEL 1 — PARKING GARAGE", "floor": "res://assets/fx/biome/garage_floor.png", "layout": "garage"},
		{"title": "LEVEL 4 — ABANDONED OFFICE", "floor": "res://assets/fx/biome/office_carpet.png", "layout": "office"},
		{"title": "TOY STORE", "floor": "res://assets/fx/biome/toy_floor.png", "layout": "toystore"},
		{"title": "CARNIVAL", "floor": "res://assets/fx/biome/carn_grass.png", "layout": "carnival"},
		{"title": "FROZEN CAVERN", "floor": "res://assets/fx/biome/ice_floor.png", "layout": "frozen"},
		{"title": "SUBWAY PLATFORM", "floor": "res://assets/fx/biome/subway_floor.png", "layout": "subway"},
	]
	# Doubled-area previews in a 4-column grid (rows added after the fourth).
	var bsize := Vector2(780, 620)
	var step := Vector2(bsize.x + 130.0, bsize.y + 150.0)
	for i in biomes.size():
		var col: int = i % COLS
		var row: int = i / COLS
		var center: Vector2 = ORIGIN + Vector2(float(col) * step.x, float(row) * step.y) + bsize * 0.5
		var cfg: Dictionary = biomes[i]
		if bool(cfg.get("board", false)):
			_build_text_board(String(cfg["title"]), cfg["lines"], int(cfg["fs"]), center, bsize)
		else:
			_big_biome(cfg, center, bsize)
	return ORIGIN + Vector2(step.x * 1.5, -bsize.y * 0.35)

func _exit_tree() -> void:
	DevState.arena_mode = false
	DevState.invincible = false
	Engine.time_scale = 1.0

# ── world building ───────────────────────────────────────────────────────────
func _build_floor(rows: int) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.13, 0.13, 0.17)
	bg.position = ORIGIN + Vector2(-STEP.x, -STEP.y * 0.6)
	bg.size = Vector2(STEP.x * (COLS + 0.5), STEP.y * (rows + 0.4))
	bg.z_index = -50
	add_child(bg)

func _build_station(st: Dictionary, center: Vector2) -> void:
	var half: Vector2 = PEN * 0.5
	# tinted floor
	var floor_r := ColorRect.new()
	floor_r.color = Color(0.17, 0.17, 0.22)
	floor_r.position = center - half
	floor_r.size = PEN
	floor_r.z_index = -40
	add_child(floor_r)
	_pen_walls(center, half, bool(st.get("open", false)))
	_label(String(st["title"]), center + Vector2(0, -half.y - 40))
	match String(st["kind"]):
		"fx_explosion":
			_fx.append({"pos": center, "kind": "explosion", "t": 0.6, "interval": 1.6})
		"fx_aoe":
			_fx.append({"pos": center, "kind": "aoe", "t": 1.0, "interval": 3.2})
		"fx_paw":
			_fx.append({"pos": center, "kind": "paw", "t": 1.2, "interval": 2.8})
		"enemy":
			_spawn_enemy(st["scene"], center, false)
		"ally":
			var ally: Node = st["scene"].instantiate()
			ally.set("global_position", center)
			add_child(ally)
		"boss":
			_spawn_enemy(st["scene"], center, true)
		"props":
			_build_props(center)
		"weapon":
			_build_weapon_showcase(st["weapon"], center)

func _pen_walls(center: Vector2, half: Vector2, open_front: bool) -> void:
	var th: float = WALL_TH
	# top, left, right
	_wall(center + Vector2(0, -half.y), Vector2(half.x * 2.0 + th, th))
	_wall(center + Vector2(-half.x, 0), Vector2(th, half.y * 2.0 + th))
	_wall(center + Vector2(half.x, 0), Vector2(th, half.y * 2.0 + th))
	# bottom — solid, or split with a gap so you can walk in
	if open_front:
		var seg: float = (half.x * 2.0 - 150.0) * 0.5
		if seg > 0.0:
			_wall(center + Vector2(-half.x + seg * 0.5, half.y), Vector2(seg, th))
			_wall(center + Vector2(half.x - seg * 0.5, half.y), Vector2(seg, th))
	else:
		_wall(center + Vector2(0, half.y), Vector2(half.x * 2.0 + th, th))

func _wall(center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("walls")
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	body.add_child(cs)
	var vis := ColorRect.new()
	vis.color = Color(0.30, 0.28, 0.36)
	vis.size = size
	vis.position = -size * 0.5
	body.add_child(vis)
	add_child(body)

func _label(text: String, pos: Vector2) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	l.size = Vector2(PEN.x + 80, 30)
	l.position = pos - Vector2(l.size.x * 0.5, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.z_index = 50
	add_child(l)

func _spawn_enemy(scene: PackedScene, pos: Vector2, is_boss: bool) -> void:
	var e: Node = scene.instantiate()
	e.set("position", pos)
	if is_boss:
		if "max_health" in e:
			e.max_health = 400
		e.set("is_boss", true)
		if "touch_damage" in e:
			e.touch_damage = 2
	add_child(e)
	# Hold position in the box — they track + fire at you but don't chase out.
	# (Brawler still charges via its own CHARGE_SPEED, which is its whole attack.)
	if "speed" in e:
		e.set("speed", 0.0)
	if is_boss:
		var rig := e.get_node_or_null("Rig") as Node2D
		if rig != null:
			rig.scale *= 1.8
			rig.modulate = Color(1.25, 0.55, 0.55)

func _build_props(center: Vector2) -> void:
	var chairs := _load_dir("res://assets/backrooms/props/furniture/")
	var lamps := _load_dir("res://assets/backrooms/props/lamps/")
	# a small cluster of chairs
	for i in 4:
		if chairs.is_empty():
			break
		var t: Texture2D = chairs[randi() % chairs.size()]
		var p: Vector2 = center + Vector2(randf_range(-90, 90), randf_range(-50, 70))
		_prop_sprite(t, p, randf_range(-PI, PI))
	if not lamps.is_empty():
		_prop_sprite(lamps[0], center + Vector2(120, -90), 0.0)

func _tile_field(tex: Texture2D, origin: Vector2, nx: int, ny: int, px: int, z: int) -> void:
	# A single sprite that GPU-repeats the tile across the whole field — no per-tile
	# seams, overlaps, or grout doubling.
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, float(nx * tex.get_width()), float(ny * tex.get_height()))
	s.scale = Vector2.ONE * (float(px) / float(tex.get_width()))
	s.position = Vector2(round(origin.x), round(origin.y))
	s.z_index = z
	add_child(s)

func _tile(tex: Texture2D, pos: Vector2, px: int, z: int) -> void:
	# Integer-positioned, NEAREST-filtered, 1px-overlap tile (no seam flicker).
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2.ONE * (float(px + 1) / float(tex.get_width()))
	s.position = Vector2(round(pos.x), round(pos.y))
	s.z_index = z
	add_child(s)

func _big_biome(cfg: Dictionary, center: Vector2, size: Vector2) -> void:
	var half: Vector2 = size * 0.5
	var bg := ColorRect.new()
	bg.color = Color(0.14, 0.14, 0.18)
	bg.position = center - half; bg.size = size; bg.z_index = -45
	add_child(bg)
	_pen_walls(center, half, true)
	_label(String(cfg["title"]), center + Vector2(0, -half.y - 42))
	# "Which texture?" swatch + note for alt biomes — shows what's used at a glance.
	if cfg.has("tex_note"):
		var note := Label.new()
		note.text = String(cfg["tex_note"])
		note.add_theme_font_size_override("font_size", 19)
		note.add_theme_color_override("font_color", Color(0.72, 0.8, 0.95))
		note.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		note.add_theme_constant_override("outline_size", 4)
		note.size = Vector2(half.x * 2.0, 26)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.position = center + Vector2(-half.x, -half.y - 20)
		add_child(note)
		var sw_t: Texture2D = _load_tex(String(cfg.get("swatch", cfg["floor"])))
		if sw_t != null:
			var sw := Sprite2D.new()
			sw.texture = sw_t
			sw.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			sw.scale = Vector2.ONE * (96.0 / float(sw_t.get_width()))
			sw.position = center + Vector2(-half.x + 64, -half.y + 64)
			sw.z_index = 5
			add_child(sw)
	var floor_t: Texture2D = _load_tex(String(cfg["floor"]))
	if floor_t == null:
		return
	var px: int = int((size.x - 28.0) / 14.0)
	var nx: int = int((size.x - 24.0) / px)
	var ny: int = int((size.y - 24.0) / px)
	var origin: Vector2 = center - Vector2(float(px * nx), float(px * ny)) * 0.5
	var layout: String = String(cfg.get("layout", "tiles"))
	var wall_t: Texture2D = _load_tex(String(cfg.get("wall", ""))) if String(cfg.get("wall", "")) != "" else null
	var water_t: Texture2D = _load_tex(String(cfg.get("water", ""))) if String(cfg.get("water", "")) != "" else null
	# Floor field — ONE GPU-repeating sprite (no per-tile seams/overlap artifacts).
	_tile_field(floor_t, origin, nx, ny, px, -30)
	# Optional wall border (backrooms) drawn as edge tiles over the floor.
	if wall_t != null:
		for gy in ny:
			for gx in nx:
				if gx == 0 or gy == 0 or gx == nx - 1 or gy == ny - 1:
					_tile(wall_t, origin + Vector2(float(gx * px), float(gy * px)), px, -29)
	match layout:
		"pool": _layout_pool(origin, nx, ny, px, center, half, water_t)
		"garage": _layout_garage(origin, nx, ny, px, center, half)
		"trees": _scatter_trees(center, half)
		"office": _layout_office(center, half)
		"wheat": _layout_wheat(center, half)
		"warehouse": _layout_warehouse(center, half)
		"dungeon": _layout_dungeon(center, half)
		"sewers": _layout_sewers(center, half)
		"suburbs": _layout_suburbs(center, half)
		"space": _layout_space(center, half)
		"toystore": _layout_toystore(center, half)
		"carnival": _layout_carnival(center, half)
		"frozen": _layout_frozen(center, half)
		"subway": _layout_subway(center, half)

func _layout_pool(_origin: Vector2, _nx: int, _ny: int, px: int, center: Vector2, half: Vector2, _water_t: Texture2D) -> void:
	# Poolrooms (Level 37): white subway-tile deck + ONE big pre-made pool sprite
	# (turquoise water with a real tile coping border baked in) + a slide, a chrome
	# ladder, inner-tubes in the water, and white tile pillars. No tiled-water seams.
	var pool := _load_tex("res://assets/fx/pool/pool_big.png")
	var pool_rect := Rect2(center, Vector2.ZERO)
	if pool != null:
		var s := Sprite2D.new()
		s.texture = pool
		s.centered = true
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var sc: float = minf((half.x * 1.55) / float(pool.get_width()), (half.y * 1.55) / float(pool.get_height()))
		s.scale = Vector2(sc, sc)
		s.position = center
		s.z_index = -28
		add_child(s)
		pool_rect = Rect2(center - Vector2(pool.get_width(), pool.get_height()) * sc * 0.5,
			Vector2(pool.get_width(), pool.get_height()) * sc)
	# White tile pillars at the deck corners (poolroom columns).
	for cx in [-1.0, 1.0]:
		for cy in [-1.0, 1.0]:
			_pool_pillar(center + Vector2(cx * half.x * 0.82, cy * half.y * 0.76), float(px))
	# A water slide whose exit dips INTO the pool water (over the top edge).
	_biome_prop("res://assets/fx/pool/slide_curvy.png", Vector2(center.x + pool_rect.size.x * 0.24, pool_rect.position.y + 24.0), float(px) * 3.2, 4)
	# Chrome ladder on the near edge of the pool.
	_pool_ladder(Vector2(center.x - pool_rect.size.x * 0.18, pool_rect.position.y + pool_rect.size.y - 6.0))
	# Inner-tubes floating in the water.
	_biome_prop("res://assets/fx/pool/tube_red.png", center + Vector2(-pool_rect.size.x * 0.18, 0), 56.0, 4)
	_biome_prop("res://assets/fx/pool/tube_blue.png", center + Vector2(pool_rect.size.x * 0.14, pool_rect.size.y * 0.12), 56.0, 4)
	_biome_prop("res://assets/fx/pool/tube_lime.png", center + Vector2(pool_rect.size.x * 0.05, -pool_rect.size.y * 0.18), 50.0, 4)
	# Hazmat researcher + a lounge chair on the deck.
	_biome_prop("res://assets/fx/biome/hazmat.png", center + Vector2(-half.x * 0.78, -half.y * 0.66), 110.0, 6)
	_biome_prop("res://assets/backrooms/props/furniture/chair_padded.png", center + Vector2(half.x * 0.82, half.y * 0.4), 50.0, 5)

func _pool_pillar(pos: Vector2, px: float) -> void:
	# A white tiled square column (top-down) with a soft shadow.
	var sz: float = px * 1.4
	var shadow := ColorRect.new()
	shadow.color = Color(0, 0, 0, 0.22)
	shadow.position = Vector2(round(pos.x - sz * 0.5 + 5), round(pos.y - sz * 0.5 + 6)); shadow.size = Vector2(sz, sz)
	shadow.z_index = 1; add_child(shadow)
	var col := ColorRect.new()
	col.color = Color(0.93, 0.94, 0.96)
	col.position = Vector2(round(pos.x - sz * 0.5), round(pos.y - sz * 0.5)); col.size = Vector2(sz, sz)
	col.z_index = 2; add_child(col)
	# grout cross so it reads as tiled
	var gv := ColorRect.new()
	gv.color = Color(0.74, 0.78, 0.82); gv.position = Vector2(round(pos.x - 1), round(pos.y - sz * 0.5)); gv.size = Vector2(2, sz)
	gv.z_index = 3; add_child(gv)
	var gh := ColorRect.new()
	gh.color = Color(0.74, 0.78, 0.82); gh.position = Vector2(round(pos.x - sz * 0.5), round(pos.y - 1)); gh.size = Vector2(sz, 2)
	gh.z_index = 3; add_child(gh)

func _pool_ladder(pos: Vector2) -> void:
	# Two chrome rails with rungs — a pool entry ladder.
	for rx in [-7.0, 7.0]:
		var rail := ColorRect.new()
		rail.color = Color(0.85, 0.88, 0.92)
		rail.position = Vector2(round(pos.x + rx - 2), round(pos.y - 34)); rail.size = Vector2(4, 40)
		rail.z_index = 5; add_child(rail)
	for ry in [0.0, 12.0, 24.0]:
		var rung := ColorRect.new()
		rung.color = Color(0.8, 0.84, 0.88)
		rung.position = Vector2(round(pos.x - 9), round(pos.y - 30 + ry)); rung.size = Vector2(18, 3)
		rung.z_index = 5; add_child(rung)

func _layout_office(center: Vector2, half: Vector2) -> void:
	# Abandoned office — mazy rows of desk+chair "cubicles" as partitions, lockers
	# and shelves against the back wall, a couple of barrels. (Level 4.)
	var F := "res://assets/backrooms/props/furniture/"
	var C := "res://assets/backrooms/props/containers/"
	var desks := [F + "desk_big.png", F + "desk_small.png", F + "desk_papers.png"]
	var chairs := [F + "chair_padded.png", F + "chair_fold_front.png"]
	var big := [F + "locker.png", F + "shelf.png", F + "cabinet.png"]
	# Cubicle rows (the "maze"): desks in 4 columns x 3 rows, each with a chair.
	for r in 3:
		for c in 4:
			var p: Vector2 = center + Vector2(lerp(-half.x * 0.62, half.x * 0.62, c / 3.0), lerp(-half.y * 0.18, half.y * 0.62, r / 2.0))
			_biome_prop(desks[randi() % desks.size()], p, 60.0, 1)
			_biome_prop(chairs[randi() % chairs.size()], p + Vector2(0, 36), 38.0, 2)
	# Lockers / shelves lined along the back wall.
	for i in 6:
		var x: float = lerp(-half.x * 0.72, half.x * 0.72, float(i) / 5.0)
		_biome_prop(big[randi() % big.size()], center + Vector2(x, -half.y * 0.66), 58.0, 1)
	# Wall-mounted air-conditioner units high on the back wall.
	for ax in [-0.35, 0.35]:
		var ac := ColorRect.new()
		ac.color = Color(0.82, 0.84, 0.88); ac.size = Vector2(50, 24)
		ac.position = center + Vector2(half.x * ax - 25, -half.y * 0.82); ac.z_index = 3
		add_child(ac)
		var vent := ColorRect.new()
		vent.color = Color(0.5, 0.52, 0.56); vent.size = Vector2(44, 5)
		vent.position = center + Vector2(half.x * ax - 22, -half.y * 0.82 + 15); vent.z_index = 4
		add_child(vent)
	# A couple of barrels.
	_biome_prop(C + "barrel_steel.png", center + Vector2(half.x * 0.7, half.y * 0.6), 54.0, 1)
	_biome_prop(C + "barrel_open.png", center + Vector2(half.x * 0.55, half.y * 0.66), 54.0, 1)
	# Windows on the back wall with daylight spilling in (pretend it's outside).
	for wx in [-0.55, 0.0, 0.55]:
		_office_window(center + Vector2(half.x * wx, -half.y * 0.88))
	# CHAOS: a teetering pile of chairs at random angles (thin at the top) +
	# a sideways desk — backrooms wrongness.
	var chair_paths := [F + "chair_padded.png", F + "chair_fold_front.png", F + "chair_fold_side.png"]
	var pile_base: Vector2 = center + Vector2(half.x * 0.42, half.y * 0.28)
	for i in 18:
		var t: float = float(i) / 18.0
		var spread: float = lerp(58.0, 8.0, t)
		var p: Vector2 = pile_base + Vector2(randf_range(-spread, spread), -t * 150.0 + randf_range(-6, 6))
		var ch := Sprite2D.new()
		ch.texture = _load_tex(chair_paths[randi() % chair_paths.size()])
		ch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if ch.texture != null:
			ch.scale = Vector2.ONE * (44.0 / float(maxi(ch.texture.get_width(), ch.texture.get_height())))
		ch.position = p; ch.rotation = randf_range(-PI, PI)
		ch.z_index = 4 + i
		add_child(ch)
	var sd := Sprite2D.new()
	sd.texture = _load_tex(desks[1]); sd.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if sd.texture != null:
		sd.scale = Vector2.ONE * (62.0 / float(maxi(sd.texture.get_width(), sd.texture.get_height())))
	sd.position = center + Vector2(-half.x * 0.5, half.y * 0.52); sd.rotation = PI * 0.5; sd.z_index = 1
	add_child(sd)

func _office_window(pos: Vector2) -> void:
	# Window frame on the wall + a warm light beam spilling onto the floor.
	var beam := Polygon2D.new()
	beam.polygon = PackedVector2Array([
		pos + Vector2(-26, 6), pos + Vector2(26, 6), pos + Vector2(60, 150), pos + Vector2(-60, 150)])
	beam.color = Color(1.0, 0.95, 0.7, 0.16); beam.z_index = -10
	add_child(beam)
	var frame := ColorRect.new()
	frame.color = Color(0.55, 0.58, 0.62); frame.size = Vector2(56, 40)
	frame.position = Vector2(round(pos.x - 28), round(pos.y - 24)); frame.z_index = 2
	add_child(frame)
	var glass := ColorRect.new()
	glass.color = Color(0.75, 0.86, 0.95); glass.size = Vector2(48, 32)
	glass.position = Vector2(round(pos.x - 24), round(pos.y - 20)); glass.z_index = 3
	add_child(glass)
	var mull_v := ColorRect.new()
	mull_v.color = Color(0.55, 0.58, 0.62); mull_v.size = Vector2(3, 32)
	mull_v.position = Vector2(round(pos.x - 2), round(pos.y - 20)); mull_v.z_index = 4
	add_child(mull_v)

func _layout_garage(_origin: Vector2, _nx: int, _ny: int, px: int, center: Vector2, half: Vector2) -> void:
	# OPEN parking lot/garage: a winding ASPHALT road (darkened concrete tile) with a
	# dashed yellow centre line runs across the middle; angled parking bays branch off
	# above and below it with a few cars; spread-out columns + wall vents.
	var concrete := _load_tex("res://assets/fx/biome/garage_floor.png")
	var cars := ["car_red", "car_blue", "car_green", "car_yellow"]
	var rsz: int = 30
	var road_pts: Array = []
	var x: float = -half.x + 8.0
	while x <= half.x - 8.0:
		var ry: float = 0.0                       # straight road (no winding)
		road_pts.append(center + Vector2(x, ry))
		# 3-tile-tall asphalt band (darkened concrete = asphalt, uses the real tile)
		if concrete != null:
			for band in [-1, 0, 1]:
				_dark_tile(concrete, center + Vector2(x, ry + float(band) * float(rsz)), rsz, Color(0.4, 0.4, 0.44))
		x += float(rsz) * 0.8
	# Dashed yellow centre line along the road.
	for i in range(0, road_pts.size(), 2):
		var dash := ColorRect.new()
		dash.color = Color(0.95, 0.82, 0.2)
		dash.position = road_pts[i] - Vector2(7, 2); dash.size = Vector2(14, 4); dash.z_index = -26
		add_child(dash)
	# Parking bays above and below the road (cars nose-in toward the road).
	for side in [-1.0, 1.0]:
		var bay_y: float = center.y + side * half.y * 0.58
		var bay_w: float = float(px) * 1.7
		var n_bays: int = 5
		var bx0: float = center.x - bay_w * float(n_bays) * 0.5
		for i in n_bays + 1:
			var line := ColorRect.new()
			line.color = Color(0.9, 0.9, 0.86, 0.8)
			line.position = Vector2(round(bx0 + bay_w * float(i)), round(bay_y)); line.size = Vector2(3, float(px) * 2.0 * -side if side < 0 else float(px) * 2.0)
			if side < 0:
				line.position.y -= float(px) * 2.0
				line.size.y = float(px) * 2.0
			line.z_index = -25; add_child(line)
		# POST-APOCALYPTIC: some cars parked straight in bays, others abandoned at
		# random angles (slid out of the bay, crashed askew).
		for bay in [0, 2, 3]:
			var bpos := Vector2(bx0 + bay_w * (float(bay) + 0.5), bay_y - side * float(px) * 1.0)
			var rot: float = 0.0 if randf() < 0.45 else randf_range(-1.0, 1.0)   # half neatly parked, half askew
			_abandoned_car("res://assets/fx/biome/%s.png" % cars[(bay + int(side)) % cars.size()], bpos, float(px) * 1.8, rot)
	# A couple of cars abandoned diagonally OUT in the driving lane + one on fire.
	_abandoned_car("res://assets/fx/biome/car_yellow.png", center + Vector2(-half.x * 0.32, half.y * 0.12), float(px) * 1.8, 0.7)
	_abandoned_car("res://assets/fx/biome/car_green.png", center + Vector2(half.x * 0.18, -half.y * 0.1), float(px) * 1.8, -0.5)
	_burning_car(center + Vector2(half.x * 0.42, half.y * 0.16), float(px) * 1.8)
	# Spread-out concrete columns (open layout), wall vents, extinguisher, tires, cones.
	for pfx in [-0.72, -0.26, 0.26, 0.72]:
		_concrete_column(center + Vector2(half.x * pfx, half.y * 0.04), 40.0)
	for vfx in [-0.55, -0.18, 0.2, 0.58]:
		_wall_vent(center + Vector2(half.x * vfx, -half.y * 0.88))
	var ext := ColorRect.new()
	ext.color = Color(0.82, 0.16, 0.13); ext.size = Vector2(16, 26)
	ext.position = center + Vector2(-half.x * 0.9, -half.y * 0.7); ext.z_index = -19
	add_child(ext)
	_biome_prop("res://assets/fx/biome/tires.png", center + Vector2(half.x * 0.78, -half.y * 0.7), 60.0, 3)
	_biome_prop("res://assets/fx/biome/cones.png", center + Vector2(-half.x * 0.2, center.y * 0.0 + half.y * 0.02), 46.0, 3)

func _layout_wheat(center: Vector2, half: Vector2) -> void:
	# Field of Wheat (Lv 10). Reference: golden field cut by a straight DIRT PATH, the
	# crop bunched denser in patches, fences dividing fields, a tractor on the path.
	# (assets: wheat floor, haystack = wheat bunch, fence_h, tractor)
	var B := "res://assets/fx/biome/"
	# A straight dirt path running vertically through the field (tyre-track dirt).
	var grass := _load_tex(B + "wheat_floor.png")
	if grass != null:
		var y: float = -half.y + 12.0
		while y <= half.y - 12.0:
			_dark_tile(grass, center + Vector2(0, y), 30, Color(0.62, 0.5, 0.34))
			y += 28.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	# Wheat sheaves scattered naturally across both fields (denser away from the path),
	# growing in loose rows like a real crop — not two tight blobs.
	for fieldx in [-1.0, 1.0]:
		for row in 5:
			var ry: float = lerp(-half.y * 0.72, half.y * 0.72, float(row) / 4.0)
			for col in 5:
				var bx: float = fieldx * lerp(half.x * 0.34, half.x * 0.82, float(col) / 4.0)
				var p: Vector2 = center + Vector2(bx + rng.randf_range(-16, 16), ry + rng.randf_range(-18, 18))
				_biome_prop(B + "haystack.png", p, rng.randf_range(40.0, 58.0), 2)
	# A few round hay bales dotted at the field edges.
	for _h in 4:
		var hb: Vector2 = center + Vector2(rng.randf_range(-1, 1) * half.x * 0.7, rng.randf_range(-1, 1) * half.y * 0.7)
		if abs(hb.x - center.x) > half.x * 0.18:
			_biome_prop(B + "haybale.png", hb, rng.randf_range(46.0, 60.0), 3)
	# Continuous post-and-rail fences running down BOTH sides of the dirt path
	# (vertical fence segments stacked), with a gap to step through.
	for fx in [-0.2, 0.2]:
		var gap: int = rng.randi_range(2, 5)
		for k in 8:
			if k == gap:
				continue
			_biome_prop(B + "fence_vert.png", center + Vector2(half.x * fx, lerp(-half.y * 0.78, half.y * 0.78, float(k) / 7.0)), 46.0, 1)

func _layout_warehouse(center: Vector2, half: Vector2) -> void:
	# Warehouse (Lv 20). Reference: ROW-SHAPED racking — parallel rack rows in one
	# orientation with WIDE aisles between (~40% racking / 60% aisles), racking along
	# the back wall. (assets: shelf = racking, dng_crate/barrel = pallet goods)
	var B := "res://assets/fx/biome/"
	var F := "res://assets/backrooms/props/furniture/"
	# Racking along the back wall.
	for i in 6:
		_biome_prop(F + "shelf.png", center + Vector2(lerp(-half.x * 0.78, half.x * 0.78, float(i) / 5.0), -half.y * 0.82), 56.0, 1)
	# THREE parallel rack rows (vertical) with wide aisles between them.
	for rx in [-0.55, 0.0, 0.55]:
		var x: float = center.x + half.x * rx
		# Rack frame backing (a long dark bay).
		var rack := ColorRect.new()
		rack.color = Color(0.22, 0.2, 0.18)
		rack.position = Vector2(round(x - 26), round(center.y - half.y * 0.4)); rack.size = Vector2(52, half.y * 1.15)
		rack.z_index = -24; add_child(rack)
		# Pallet goods stacked down the rack (crates + the odd barrel), aligned.
		for j in 5:
			var y: float = lerp(-half.y * 0.32, half.y * 0.66, float(j) / 4.0)
			_biome_prop(B + ("dng_crate.png" if j % 3 != 2 else "dng_barrel.png"), Vector2(x, center.y + y), 46.0, 2)
	# Yellow aisle floor markings between the rows.
	for ax in [-0.27, 0.27]:
		var lane := ColorRect.new()
		lane.color = Color(0.95, 0.8, 0.2, 0.5)
		lane.position = Vector2(round(center.x + half.x * ax - 2), round(center.y - half.y * 0.35)); lane.size = Vector2(4, half.y * 1.0)
		lane.z_index = -25; add_child(lane)
	# Staging pallets near the front-left.
	for s in 3:
		_biome_prop(B + "dng_crate.png", center + Vector2(-half.x * 0.84 + float(s) * 8.0, half.y * 0.74 - float(s) * 10.0), 44.0, 3)

func _layout_dungeon(center: Vector2, half: Vector2) -> void:
	# Dungeon (Kenney tiny-dungeon). Reference: a stone room — entrance door + torches
	# top, breakable barrels/crates lined along the SIDE walls, a treasure cache
	# (chests) grouped bottom-centre, monsters guarding the middle.
	var B := "res://assets/fx/biome/"
	# Entrance door + flanking torches (top-centre).
	_biome_prop(B + "dng_door.png", center + Vector2(0, -half.y * 0.9), 58.0, 3)
	_torch(center + Vector2(-half.x * 0.22, -half.y * 0.86))
	_torch(center + Vector2(half.x * 0.22, -half.y * 0.86))
	# Barrels/crates lined neatly along the left + right walls.
	for j in 4:
		var y: float = lerp(-half.y * 0.45, half.y * 0.45, float(j) / 3.0)
		_biome_prop(B + "dng_barrel.png", center + Vector2(-half.x * 0.82, y), 46.0, 2)
		_biome_prop(B + "dng_crate.png", center + Vector2(half.x * 0.82, y), 46.0, 2)
	# Treasure cache — three chests grouped bottom-centre (the reward).
	_biome_prop(B + "dng_chest.png", center + Vector2(-half.x * 0.16, half.y * 0.66), 56.0, 2)
	_biome_prop(B + "dng_chest.png", center + Vector2(half.x * 0.16, half.y * 0.66), 56.0, 2)
	_biome_prop(B + "dng_chest.png", center + Vector2(0, half.y * 0.76), 60.0, 3)
	# Monsters guarding the middle, between you and the loot.
	_biome_prop(B + "dng_ghost.png", center + Vector2(0, -half.y * 0.05), 58.0, 4)
	_biome_prop(B + "dng_spider.png", center + Vector2(-half.x * 0.3, half.y * 0.2), 44.0, 4)
	_biome_prop(B + "dng_spider.png", center + Vector2(half.x * 0.32, half.y * 0.25), 42.0, 4)

func _torch(pos: Vector2) -> void:
	var stick := ColorRect.new()
	stick.color = Color(0.36, 0.25, 0.16); stick.size = Vector2(5, 16)
	stick.position = Vector2(round(pos.x - 2), round(pos.y)); stick.z_index = 3; add_child(stick)
	var flame := Polygon2D.new()
	flame.polygon = PackedVector2Array([pos + Vector2(0, -12), pos + Vector2(7, 0), pos + Vector2(0, 4), pos + Vector2(-7, 0)])
	flame.color = Color(1.6, 0.9, 0.3); flame.z_index = 4; add_child(flame)

func _layout_toystore(center: Vector2, half: Vector2) -> void:
	# Toy Store. Reference: bright checkerboard floor, long parallel SHELF AISLES packed
	# with boxed toys, end-cap displays at the aisle heads, a row of checkout counters at
	# the front. (assets: backrooms shelf = gondola, toybox_* = stock, counter = till)
	var B := "res://assets/fx/biome/"
	var shelf := "res://assets/backrooms/props/furniture/shelf.png"
	var boxes := ["toybox_blue.png", "toybox_green.png", "toybox_orange.png", "toybox_purple.png"]
	var rng := RandomNumberGenerator.new(); rng.seed = 12
	# Three gondola aisle rows (vertical), wide aisles between, stock on each shelf.
	for rx in [-0.55, 0.0, 0.55]:
		var x: float = center.x + half.x * rx
		for j in 6:
			var y: float = lerp(-half.y * 0.5, half.y * 0.42, float(j) / 5.0)
			_biome_prop(shelf, Vector2(x, center.y + y), 58.0, int(center.y + y + 200.0))
			# a couple of toy boxes sitting on the shelf face
			for s in 2:
				_biome_prop(B + boxes[rng.randi() % boxes.size()], Vector2(x - 14.0 + float(s) * 26.0, center.y + y - 6.0), 22.0, int(center.y + y + 210.0))
		# End-cap display stack at the head of the aisle.
		for e in 3:
			_biome_prop(B + boxes[rng.randi() % boxes.size()], Vector2(x, center.y - half.y * 0.66 + float(e) * 18.0), 26.0, 4)
	# Checkout counters in a row across the front (bottom).
	for i in 3:
		_biome_prop(B + "counter.png", center + Vector2(lerp(-half.x * 0.55, half.x * 0.55, float(i) / 2.0), half.y * 0.8), 72.0, 5)

func _layout_carnival(center: Vector2, half: Vector2) -> void:
	# Carnival / Funfair. Reference: a carousel centrepiece, striped big-top tents ringing
	# a central midway, prize booths lining the path, bunting strung overhead.
	# (assets: carousel, tent_red/blue/green, booth)
	var B := "res://assets/fx/biome/"
	var tents := ["tent_red.png", "tent_blue.png", "tent_green.png"]
	# Carousel centrepiece (upper centre).
	_biome_prop(B + "carousel.png", center + Vector2(0, -half.y * 0.28), 150.0, int(center.y + half.y * 0.4))
	# Big-top tents ringing the midway.
	var tpos := [Vector2(-0.62, -0.42), Vector2(0.62, -0.42), Vector2(-0.72, 0.28), Vector2(0.72, 0.28)]
	for i in tpos.size():
		var p: Vector2 = center + Vector2(half.x * tpos[i].x, half.y * tpos[i].y)
		_biome_prop(B + tents[i % tents.size()], p, 104.0, int(p.y + 200.0))
	# Prize booths lining the lower midway.
	for i in 4:
		var bx: float = lerp(-half.x * 0.6, half.x * 0.6, float(i) / 3.0)
		_biome_prop(B + "booth.png", center + Vector2(bx, half.y * 0.62), 66.0, int(center.y + half.y * 0.62 + 200.0))
	# Bunting / string lights strung across the top between the tents.
	var bunting := Line2D.new()
	bunting.width = 2.0
	bunting.default_color = Color(0.85, 0.8, 0.5, 0.7)
	bunting.points = PackedVector2Array([
		center + Vector2(-half.x * 0.82, -half.y * 0.5),
		center + Vector2(-half.x * 0.3, -half.y * 0.36),
		center + Vector2(half.x * 0.3, -half.y * 0.36),
		center + Vector2(half.x * 0.82, -half.y * 0.5)])
	bunting.z_index = 6
	add_child(bunting)
	for f in 13:
		var t: float = float(f) / 12.0
		var lx: float = lerp(-half.x * 0.82, half.x * 0.82, t)
		var dip: float = -half.y * 0.5 + sin(t * PI) * half.y * 0.16
		var bulb := ColorRect.new()
		bulb.color = [Color(1, 0.4, 0.4), Color(1, 0.9, 0.4), Color(0.5, 0.8, 1)][f % 3]
		bulb.size = Vector2(5, 5)
		bulb.position = Vector2(round(center.x + lx - 2), round(center.y + dip))
		bulb.z_index = 7
		add_child(bulb)

func _layout_frozen(center: Vector2, half: Vector2) -> void:
	# Frozen Cavern. Reference: pale-blue ice floor, frozen pools, clusters of ice
	# columns/stalagmites as cover, scattered frozen boulders, cold ambient light.
	# (assets: ice_floor, ice_pool, icicle, ice_rock)
	var B := "res://assets/fx/biome/"
	var pool := _load_tex(B + "ice_pool.png")
	var rng := RandomNumberGenerator.new(); rng.seed = 24
	# A couple of frozen pools (blobs of ice_pool tiles).
	if pool != null:
		for pc in [Vector2(-0.42, 0.32), Vector2(0.45, -0.28)]:
			var pcx: Vector2 = center + Vector2(half.x * pc.x, half.y * pc.y)
			for ox in range(-2, 3):
				for oy in range(-2, 3):
					if abs(ox) + abs(oy) <= 3:
						_water_tile(pool, pcx + Vector2(float(ox), float(oy)) * 30.0, 30)
	# Ice columns clustered as cover (avoid the centre so you can move).
	for i in 12:
		var p: Vector2 = center + Vector2(rng.randf_range(-1, 1) * half.x * 0.85, rng.randf_range(-1, 1) * half.y * 0.85)
		if p.distance_to(center) < half.y * 0.25:
			continue
		_biome_prop(B + "icicle.png", p, rng.randf_range(40.0, 58.0), int(p.y + 200.0))
	# Frozen boulders dotted around.
	for i in 6:
		var r: Vector2 = center + Vector2(rng.randf_range(-1, 1) * half.x * 0.8, rng.randf_range(-1, 1) * half.y * 0.8)
		_biome_prop(B + "ice_rock.png", r, rng.randf_range(36.0, 50.0), int(r.y + 190.0))
	# Cold blue ambient wash over the cavern.
	var chill := ColorRect.new()
	chill.color = Color(0.4, 0.6, 0.9, 0.12)
	chill.position = center - half; chill.size = half * 2.0
	chill.z_index = 20
	add_child(chill)

func _layout_subway(center: Vector2, half: Vector2) -> void:
	# Subway Platform. Reference: two platforms split by a recessed TRACK bed (hazard),
	# yellow tactile safety edges, support pillars down each platform, benches against the
	# back walls, turnstiles at one end. (assets: track, concrete columns, bench, turnstile)
	var B := "res://assets/fx/biome/"
	var track := _load_tex(B + "track.png")
	# Track bed running horizontally through the middle (3 tiles tall).
	var bandh: float = 90.0
	if track != null:
		var x: float = -half.x + 14.0
		while x <= half.x - 14.0:
			for row in [-1, 0, 1]:
				_dark_tile(track, center + Vector2(x, float(row) * 30.0), 30, Color(1, 1, 1))
			x += 28.0
	# Yellow tactile safety edges either side of the track bed.
	for ey in [-1.0, 1.0]:
		var edge := ColorRect.new()
		edge.color = Color(0.95, 0.82, 0.2, 0.9)
		edge.size = Vector2(half.x * 1.7, 6)
		edge.position = Vector2(round(center.x - half.x * 0.85), round(center.y + ey * (bandh * 0.5 + 4.0)))
		edge.z_index = -22
		add_child(edge)
	# Support pillars down each platform.
	for i in 5:
		var px: float = lerp(-half.x * 0.7, half.x * 0.7, float(i) / 4.0)
		_concrete_column(center + Vector2(px, -half.y * 0.66), 26.0)
		_concrete_column(center + Vector2(px, half.y * 0.66), 26.0)
	# Benches against the back walls.
	for i in 3:
		var bx: float = lerp(-half.x * 0.5, half.x * 0.5, float(i) / 2.0)
		_biome_prop(B + "bench.png", center + Vector2(bx, -half.y * 0.84), 56.0, 3)
		_biome_prop(B + "bench.png", center + Vector2(bx, half.y * 0.84), 56.0, 3)
	# Turnstiles at the left entrance.
	for i in 2:
		_biome_prop(B + "turnstile.png", center + Vector2(-half.x * 0.86, -half.y * 0.3 + float(i) * 60.0), 40.0, 4)

func _layout_sewers(center: Vector2, half: Vector2) -> void:
	# Flooded Sewers — a tidy but large MAZE. Corridors 3 tiles wide separated by
	# 1-tile brick walls (recursive-backtracker), with a murky water channel running
	# the central corridor. Reference: brick utility tunnels, neat grid, water gutters.
	var B := "res://assets/fx/biome/"
	var wall_t := _load_tex(B + "sewer_wall.png")
	var water_t := _load_tex(B + "sewer_water.png")
	var t: int = 26
	var inner: Vector2 = half - Vector2(18, 18)
	var cols: int = int(inner.x * 2.0 / float(t))
	var rows: int = int(inner.y * 2.0 / float(t))
	var origin: Vector2 = center - Vector2(float(cols), float(rows)) * float(t) * 0.5
	# wall grid (true = wall), start solid
	var wall: Array = []
	for gx in cols:
		var colarr: Array = []
		for gy in rows:
			colarr.append(true)
		wall.append(colarr)
	var unit: int = 4   # 3-wide room + 1-wide wall
	var mcols: int = (cols - 1) / unit
	var mrows: int = (rows - 1) / unit
	if mcols < 2 or mrows < 2:
		return
	# carve a 3x3 room for a maze-cell
	var carve_room := func(mx: int, my: int) -> void:
		var bx: int = 1 + mx * unit
		var by: int = 1 + my * unit
		for ox in 3:
			for oy in 3:
				wall[bx + ox][by + oy] = false
	# recursive backtracker over maze cells
	var visited: Array = []
	for i in mcols:
		var v: Array = []
		for j in mrows:
			v.append(false)
		visited.append(v)
	var stack: Array = [Vector2i(0, 0)]
	visited[0][0] = true
	carve_room.call(0, 0)
	while not stack.is_empty():
		var cur: Vector2i = stack[-1]
		var nbrs: Array = []
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = cur.x + d.x
			var ny: int = cur.y + d.y
			if nx >= 0 and nx < mcols and ny >= 0 and ny < mrows and not visited[nx][ny]:
				nbrs.append(d)
		if nbrs.is_empty():
			stack.pop_back()
			continue
		var dir: Vector2i = nbrs[randi() % nbrs.size()]
		var nc := Vector2i(cur.x + dir.x, cur.y + dir.y)
		visited[nc.x][nc.y] = true
		carve_room.call(nc.x, nc.y)
		# knock out the 1-tile wall between the two 3-wide rooms (carve 3 tiles)
		var bx: int = 1 + cur.x * unit
		var by: int = 1 + cur.y * unit
		if dir == Vector2i(1, 0):
			for oy in 3: wall[bx + 3][by + oy] = false
		elif dir == Vector2i(-1, 0):
			for oy in 3: wall[bx - 1][by + oy] = false
		elif dir == Vector2i(0, 1):
			for ox in 3: wall[bx + ox][by + 3] = false
		else:
			for ox in 3: wall[bx + ox][by - 1] = false
		stack.append(nc)
	# draw walls (textured brick + collision so it's a real walkable maze)
	for gx in cols:
		for gy in rows:
			if wall[gx][gy]:
				var pos: Vector2 = origin + Vector2(float(gx) + 0.5, float(gy) + 0.5) * float(t)
				if wall_t != null:
					_dark_tile(wall_t, pos, t, Color(1, 1, 1))
				var body := StaticBody2D.new()
				body.position = pos
				body.collision_layer = 1; body.collision_mask = 0
				body.add_to_group("walls")
				var cs := CollisionShape2D.new()
				var rect := RectangleShape2D.new(); rect.size = Vector2(t, t)
				cs.shape = rect; body.add_child(cs)
				add_child(body)
	# water channel — flood the central horizontal corridor band
	if water_t != null:
		var my: int = mrows / 2
		var wy0: int = 1 + my * unit + 1   # middle tile-row of that corridor
		for gx in cols:
			if not wall[gx][wy0]:
				_water_tile(water_t, origin + Vector2(float(gx) + 0.5, float(wy0) + 0.5) * float(t), t)
	# a grate/door marking the entrance, a few barrels at dead-ends
	_biome_prop(B + "dng_door.png", center + Vector2(0, -half.y * 0.94), 54.0, 3)

func _layout_suburbs(center: Vector2, half: Vector2) -> void:
	# The Suburbs (Lv 9). Reference: rows of HOUSES with front yards facing a STREET,
	# fences between yards, trees in yards, cars parked on the street. Grid layout.
	# (assets: composed tiny-town houses, fence_h, tree_green, cars)
	var B := "res://assets/fx/biome/"
	var grass := _load_tex(B + "tt_grass.png")
	# Horizontal grey street across the middle with a dashed centre line.
	if grass != null:
		var x: float = -half.x + 12.0
		while x <= half.x - 12.0:
			for band in [-1, 0, 1]:
				_dark_tile(grass, center + Vector2(x, float(band) * 26.0), 28, Color(0.42, 0.43, 0.46))
			x += 26.0
	for i in 8:
		var dash := ColorRect.new()
		dash.color = Color(0.92, 0.86, 0.4)
		dash.position = Vector2(round(lerp(center.x - half.x * 0.8, center.x + half.x * 0.8, float(i) / 7.0) - 8), round(center.y - 2)); dash.size = Vector2(16, 4); dash.z_index = -24
		add_child(dash)
	# Two rows of houses facing the street. Varied types/sizes, jittered spacing,
	# real post-and-rail fences with a gap for the front path, scattered bushes.
	var houses := ["house_grey.png", "house_red.png", "house_tan.png", "house_redS.png"]
	var bushes := ["shrub.png", "bush_big.png", "bush_sm.png"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	for side in [-1.0, 1.0]:
		var hy: float = side * half.y * 0.6
		for i in 3:
			var base_x: float = lerp(-half.x * 0.62, half.x * 0.62, float(i) / 2.0)
			var hx: float = base_x + rng.randf_range(-26.0, 26.0)
			var hsz: float = rng.randf_range(104.0, 132.0)
			var htype: String = houses[rng.randi() % houses.size()]
			# yard sign: house sits on its plot, slightly varied vertical offset
			var hyy: float = hy + rng.randf_range(-14.0, 14.0)
			_biome_prop(B + htype, center + Vector2(hx, hyy), hsz, int(center.y + hyy + 200.0))
			# driveway slab running from the house down to the street
			var drive := ColorRect.new()
			drive.color = Color(0.5, 0.5, 0.54, 0.85)
			var dw: float = 24.0
			var house_y: float = center.y + hyy
			var dh: float = abs(house_y - center.y) - 24.0
			if dh > 8.0:
				drive.size = Vector2(dw, dh)
				var dy: float = minf(house_y, center.y) + 28.0
				drive.position = Vector2(round(center.x + hx + rng.randf_range(-22, 22) - dw * 0.5), round(dy))
				drive.z_index = -26
				add_child(drive)
			# a tree + a couple bushes scattered in the FRONT yard (toward the street)
			_biome_prop(B + "tree_green.png", center + Vector2(hx + rng.randf_range(-50, 50), hyy - side * 52.0), rng.randf_range(48.0, 64.0), int(center.y + hyy + 260.0))
			for _b in 2:
				_biome_prop(B + bushes[rng.randi() % bushes.size()], center + Vector2(hx + rng.randf_range(-58, 58), hyy - side * rng.randf_range(40, 64)), rng.randf_range(26.0, 40.0), int(center.y + hyy + 280.0))
		# fence line along the yard frontage with a random gate gap
		var gate: int = rng.randi_range(1, 4)
		for k in 6:
			if k == gate:
				continue   # gap for the front path
			var fx: float = lerp(-half.x * 0.82, half.x * 0.82, float(k) / 5.0) + rng.randf_range(-6, 6)
			_biome_prop(B + "fence_full.png", center + Vector2(fx, side * half.y * 0.3), 78.0, 1)
	# Cars parked along the street, slightly askew.
	_biome_prop(B + "car_red.png", center + Vector2(-half.x * 0.45, -half.y * 0.05), 58.0, 3)
	_biome_prop(B + "car_blue.png", center + Vector2(half.x * 0.15, half.y * 0.05), 58.0, 3)
	_biome_prop(B + "car_red.png", center + Vector2(half.x * 0.55, -half.y * 0.04), 56.0, 3)

func _layout_space(center: Vector2, half: Vector2) -> void:
	# Space Hangar. Reference: ships parked in a NEAT ROW on circular landing pads,
	# a cargo area stacked along one wall, fuel drums lined along another, bay lines.
	var B := "res://assets/fx/biome/"
	var ships := ["ship_blue", "ship_cyan", "ship_lime", "ship_gold"]
	var n: int = 4
	# Bay divider lines.
	for i in n + 1:
		var lx: float = lerp(-half.x * 0.85, half.x * 0.85, float(i) / float(n))
		var div := ColorRect.new()
		div.color = Color(0.85, 0.7, 0.2, 0.4)
		div.position = Vector2(round(center.x + lx - 1), round(center.y - half.y * 0.7)); div.size = Vector2(2, half.y * 0.9)
		div.z_index = -25; add_child(div)
	# One neat row of ships, each on a landing pad, all facing the same way.
	for i in n:
		var x: float = lerp(-half.x * 0.64, half.x * 0.64, float(i) / float(n - 1))
		var p: Vector2 = center + Vector2(x, -half.y * 0.22)
		_landing_pad(p, 46.0)
		_biome_prop(B + ships[i] + ".png", p, 76.0, 3)
	# Cargo: a neat 3x2 stack of crates in the bottom-left.
	for j in 6:
		var col: int = j % 3
		var row: int = j / 3
		_biome_prop(B + "dng_crate.png", center + Vector2(-half.x * 0.74 + float(col) * 42.0, half.y * 0.45 + float(row) * 40.0), 42.0, 2)
	# Fuel drums lined along the bottom-right.
	for k in 4:
		_biome_prop(B + "dng_barrel.png", center + Vector2(half.x * 0.4 + float(k) * 38.0, half.y * 0.62), 46.0, 2)

func _landing_pad(pos: Vector2, r: float) -> void:
	# Flat painted floor panel + corner hazard ticks (no dumb circle).
	var panel := ColorRect.new()
	panel.color = Color(0.10, 0.12, 0.16, 0.55)
	panel.size = Vector2(r * 2.2, r * 1.9)
	panel.position = pos - panel.size * 0.5
	panel.z_index = -25
	add_child(panel)
	var hw: float = r * 1.05
	var hh: float = r * 0.9
	var tick: float = r * 0.5
	for corner in [Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(-hw, hh), Vector2(hw, hh)]:
		var sx: float = -1.0 if corner.x > 0.0 else 1.0
		var sy: float = -1.0 if corner.y > 0.0 else 1.0
		var hbar := ColorRect.new()
		hbar.color = Color(0.92, 0.78, 0.2, 0.8)
		hbar.size = Vector2(tick, 3); hbar.position = pos + corner - Vector2(0 if sx > 0 else tick, 0)
		hbar.z_index = -24; add_child(hbar)
		var vbar := ColorRect.new()
		vbar.color = Color(0.92, 0.78, 0.2, 0.8)
		vbar.size = Vector2(3, tick); vbar.position = pos + corner - Vector2(0, 0 if sy > 0 else tick)
		vbar.z_index = -24; add_child(vbar)

func _abandoned_car(path: String, pos: Vector2, target: float, rot: float) -> void:
	var tex := _load_tex(path)
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2.ONE * (target / float(maxi(tex.get_width(), tex.get_height())))
	s.position = pos
	s.rotation = rot
	s.z_index = 2
	add_child(s)

func _burning_car(pos: Vector2, target: float) -> void:
	_abandoned_car("res://assets/fx/biome/car_red.png", pos, target, randf_range(-0.8, 0.8))
	# Scorch + flames + a soft fire glow.
	_draw_ellipse(pos, Vector2(target * 0.6, target * 0.4), Color(0.04, 0.04, 0.05, 0.55), 1)
	for _i in 7:
		var fl := Polygon2D.new()
		var fx: float = randf_range(-target * 0.25, target * 0.25)
		var h: float = randf_range(18.0, 34.0)
		fl.polygon = PackedVector2Array([pos + Vector2(fx - 7, 0), pos + Vector2(fx + 7, 0), pos + Vector2(fx, -h)])
		fl.color = Color(2.0, randf_range(0.5, 0.9), 0.2)
		fl.z_index = 6
		add_child(fl)
	# Smoke puffs above the flames.
	for _s in 3:
		_draw_ellipse(pos + Vector2(randf_range(-12, 12), randf_range(-40, -22)), Vector2(14, 10), Color(0.2, 0.2, 0.22, 0.4), 7)

func _dark_tile(tex: Texture2D, pos: Vector2, sz: int, tint: Color) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = true
	s.modulate = tint
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2.ONE * (float(sz + 2) / float(tex.get_width()))
	s.position = Vector2(round(pos.x), round(pos.y))
	s.z_index = -28
	add_child(s)

func _concrete_column(pos: Vector2, sz: float) -> void:
	var shadow := ColorRect.new()
	shadow.color = Color(0, 0, 0, 0.28)
	shadow.position = Vector2(round(pos.x - sz * 0.5 + 6), round(pos.y - sz * 0.5 + 7)); shadow.size = Vector2(sz, sz)
	shadow.z_index = -23; add_child(shadow)
	var col := ColorRect.new()
	col.color = Color(0.5, 0.5, 0.54)
	col.position = Vector2(round(pos.x - sz * 0.5), round(pos.y - sz * 0.5)); col.size = Vector2(sz, sz)
	col.z_index = -22; add_child(col)
	var hi := ColorRect.new()                       # lit left edge
	hi.color = Color(0.62, 0.62, 0.66)
	hi.position = Vector2(round(pos.x - sz * 0.5), round(pos.y - sz * 0.5)); hi.size = Vector2(5, sz)
	hi.z_index = -21; add_child(hi)
	var stripe := ColorRect.new()                   # yellow safety stripe
	stripe.color = Color(0.95, 0.8, 0.2)
	stripe.position = Vector2(round(pos.x - sz * 0.5), round(pos.y + sz * 0.2)); stripe.size = Vector2(sz, 5)
	stripe.z_index = -21; add_child(stripe)

func _wall_vent(pos: Vector2) -> void:
	var frame := ColorRect.new()
	frame.color = Color(0.32, 0.33, 0.36); frame.size = Vector2(46, 26)
	frame.position = Vector2(round(pos.x - 23), round(pos.y - 13)); frame.z_index = -20
	add_child(frame)
	for i in 4:
		var slat := ColorRect.new()
		slat.color = Color(0.18, 0.19, 0.21); slat.size = Vector2(40, 3)
		slat.position = Vector2(round(pos.x - 20), round(pos.y - 10 + float(i) * 6)); slat.z_index = -19
		add_child(slat)

func _scatter_trees(center: Vector2, half: Vector2) -> void:
	var oak := _load_tex("res://assets/fx/biome/tree_oak.png")
	var pine := _load_tex("res://assets/fx/biome/tree_pine.png")
	var bushes := _load_tex("res://assets/forest_kit/texture only/Forest Tileset - Free/bushes.png")
	var stones := _load_tex("res://assets/forest_kit/texture only/Forest Tileset - Free/stones.png")
	var water := _load_tex("res://assets/fx/biome/forest_water.png")
	# 1) A real WATER river that winds horizontally through the level (using the
	#    forest tileset's water tile — no more drawn blobs).
	var river_pts: Array = []
	if water != null:
		var wpx: int = 28
		var amp: float = half.y * 0.4
		var freq: float = randf_range(0.010, 0.015)
		var phase: float = randf() * TAU
		var x: float = -half.x + 10.0
		while x <= half.x - 10.0:
			var ry: float = sin(x * freq + phase) * amp
			river_pts.append(center + Vector2(x, ry))
			for band in [-1, 0, 1]:
				_water_tile(water, center + Vector2(x, ry + float(band) * float(wpx)), wpx)
			x += float(wpx) * 0.8
		# Rocks along the banks for a natural edge.
		if stones != null:
			for i in range(0, river_pts.size(), 5):
				var pt: Vector2 = river_pts[i]
				_prop_sprite(stones, pt + Vector2(randf_range(-10, 10), -float(wpx) * 1.7), 0.0)
				_prop_sprite(stones, pt + Vector2(randf_range(-10, 10), float(wpx) * 1.7), 0.0)
	# 2) Trees on a grid, but only on dry land (skip anything over the river).
	for r in 3:
		for c in 4:
			if randf() < 0.18:
				continue
			var t: Texture2D = oak if ((c + r) % 2 == 0) else pine
			if t == null:
				continue
			var gx: float = lerp(-half.x * 0.82, half.x * 0.82, float(c) / 3.0)
			var gy: float = lerp(-half.y * 0.78, half.y * 0.78, float(r) / 2.0)
			var p: Vector2 = center + Vector2(gx + randf_range(-18, 18), gy + randf_range(-14, 14))
			if _near_river(p, river_pts, 64.0):
				continue
			var tr := Sprite2D.new()
			tr.texture = t
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tr.scale = Vector2.ONE * (110.0 / float(t.get_height()))
			tr.position = p
			tr.z_index = int(p.y)
			add_child(tr)
	# 3) Bushes on the banks / dry land.
	if bushes != null:
		for i in 6:
			var bp: Vector2 = center + Vector2(randf_range(-half.x * 0.8, half.x * 0.8), randf_range(-half.y * 0.8, half.y * 0.8))
			if not _near_river(bp, river_pts, 50.0):
				_prop_sprite(bushes, bp, 0.0)

func _water_tile(tex: Texture2D, pos: Vector2, sz: int) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = true
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2.ONE * (float(sz + 2) / float(tex.get_width()))
	s.position = Vector2(round(pos.x), round(pos.y))
	s.z_index = -29
	add_child(s)

func _near_river(p: Vector2, pts: Array, radius: float) -> bool:
	for rp in pts:
		if p.distance_to(rp) < radius:
			return true
	return false

func _draw_ellipse(pos: Vector2, rad: Vector2, col: Color, z: int) -> Polygon2D:
	var p := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 24:
		var a: float = TAU * float(i) / 24.0
		pts.append(pos + Vector2(cos(a) * rad.x, sin(a) * rad.y))
	p.polygon = pts; p.color = col; p.z_index = z
	add_child(p)
	return p

func _biome_prop(path: String, pos: Vector2, target: float, z: int) -> void:
	var tex := _load_tex(path)
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2.ONE * (target / float(maxi(tex.get_width(), tex.get_height())))
	s.position = pos
	s.z_index = z
	add_child(s)

func _build_text_board(title: String, lines: Array, font_size: int, center: Vector2, size: Vector2) -> void:
	var half: Vector2 = size * 0.5
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.12, 0.97)
	bg.position = center - half; bg.size = size; bg.z_index = -10
	add_child(bg)
	_pen_walls(center, half, true)
	_label(title, center + Vector2(0, -half.y - 42))
	var l := Label.new()
	l.text = "\n".join(lines)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_constant_override("line_spacing", 3)
	l.size = size - Vector2(36, 26)
	l.position = center - l.size * 0.5
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.z_index = 50
	add_child(l)

func _build_weapon_showcase(w: Dictionary, center: Vector2) -> void:
	# Floor icon for the weapon, and an auto-firing projectile so you see it live.
	var is_ball: bool = bool(w.get("ball", false))
	var icon := Sprite2D.new()
	var proj_t: Texture2D = _load_tex("res://assets/projectiles/%s.png" % String(w["proj"])) if w.has("proj") else null
	icon.texture = proj_t if proj_t != null else (BallIconTex if is_ball else PizzaIconTex)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.scale = Vector2(1.4, 1.4) if proj_t != null else Vector2(0.7, 0.7)
	icon.modulate = w.get("color", Color(1, 1, 1)) if is_ball else Color(1, 1, 1)
	icon.position = center + Vector2(-PEN.x * 0.5 + 50, 0)
	icon.z_index = 5
	add_child(icon)
	var dps: float = float(w.get("dmg", 1)) * float(w.get("count", 1)) / maxf(0.08, float(w.get("cooldown", 0.3)))
	_label("DPS %.0f  ·  spd %d" % [dps, int(w.get("speed", 600))], center + Vector2(0, PEN.y * 0.5 - 8))
	_fx.append({"kind": "weapon", "weapon": w, "pos": icon.position + Vector2(24, 0),
		"t": 0.4, "interval": float(w.get("cooldown", 0.4))})

func _prop_sprite(tex: Texture2D, pos: Vector2, rot: float) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	var longest: float = float(maxi(tex.get_width(), tex.get_height()))
	s.scale = Vector2.ONE * (60.0 / maxf(1.0, longest))
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = pos
	s.rotation = rot
	add_child(s)

func _load_tex(path: String) -> Texture2D:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var img := Image.new()
	if img.load_png_from_buffer(f.get_buffer(f.get_length())) == OK:
		return ImageTexture.create_from_image(img)
	return null

func _load_dir(dir: String) -> Array:
	var out: Array = []
	var da := DirAccess.open(dir)
	if da == null:
		return out
	da.list_dir_begin()
	var fn := da.get_next()
	while fn != "":
		if fn.to_lower().ends_with(".png"):
			var f := FileAccess.open(dir + fn, FileAccess.READ)
			if f != null:
				var img := Image.new()
				if img.load_png_from_buffer(f.get_buffer(f.get_length())) == OK:
					out.append(ImageTexture.create_from_image(img))
		fn = da.get_next()
	da.list_dir_end()
	return out

func _spawn_player(pos: Vector2) -> void:
	_player = PlayerScene.instantiate()
	_player.position = pos
	add_child(_player)

func _build_camera() -> void:
	_camera = Camera2D.new()
	_camera.zoom = Vector2(0.62, 0.62)
	add_child(_camera)
	_camera.make_current()

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	_hud_layer = layer
	add_child(layer)
	# Category menu — clicking rebuilds the room with just that group.
	var cats := HBoxContainer.new()
	cats.add_theme_constant_override("separation", 6)
	cats.position = Vector2(16, 10)
	layer.add_child(cats)
	for c in ["ENEMIES", "WEAPONS", "FX", "PROPS", "LEVELS"]:
		var cb := Button.new()
		cb.text = c
		cb.focus_mode = Control.FOCUS_NONE
		cb.add_theme_font_size_override("font_size", 16)
		cb.pressed.connect(_show_category.bind(c))
		cats.add_child(cb)
		_cat_buttons[c] = cb

func _dev_button(parent: Node, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	b.pressed.connect(func() -> void: cb.call(b))
	parent.add_child(b)

# ── loop ─────────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	for d in _fx:
		d["t"] -= delta
		if d["t"] <= 0.0:
			d["t"] = d["interval"]
			if String(d["kind"]) == "weapon":
				_fire_weapon(d["weapon"], d["pos"])
			else:
				_spawn_fx(String(d["kind"]), d["pos"])

func _spawn_fx(kind: String, pos: Vector2) -> void:
	match kind:
		"explosion":
			var e := ExplosionScene.instantiate()
			e.global_position = pos
			add_child(e)
		"aoe":
			var g := GroundSlamScene.instantiate()
			g.global_position = pos
			g.set("radius", 110.0)
			g.set("windup", 1.7)
			g.set("damage", 0)
			add_child(g)
		"paw":
			var p := BearPawSlamScene.instantiate()
			p.global_position = pos
			p.set("telegraph", 1.0)
			p.set("radius", 95.0)
			p.set("damage", 0)
			add_child(p)

func _fire_weapon(w: Dictionary, pos: Vector2) -> void:
	var pizza := PizzaScene.instantiate()
	pizza.global_position = pos
	pizza.set("direction", Vector2.RIGHT)
	pizza.set("damage", 0)
	pizza.set("speed", float(w.get("speed", 600.0)))
	var col: Color = w.get("color", Color(1, 1, 1))
	var spr := pizza.get_node_or_null("Sprite") as Sprite2D
	if bool(w.get("ball", false)):
		col = Color.from_hsv(randf(), 0.85, 1.0)
		pizza.set("max_bounces", int(w.get("bounces", 8)))
		pizza.set("lifetime", 1.6)
		if spr != null:
			spr.texture = BouncyBallTex
			spr.scale = Vector2(0.5, 0.5)
	else:
		pizza.set("max_bounces", 1)
		if spr != null and w.has("proj"):
			var pt: Texture2D = _load_tex("res://assets/projectiles/%s.png" % String(w["proj"]))
			if pt != null:
				spr.texture = pt
				var psc: float = float(w.get("proj_scale", 0.6))
				spr.scale = Vector2(psc, psc)
				spr.modulate = Color(1.35, 1.35, 1.35)
				add_child(pizza)
				return
	if spr != null:
		var m: float = maxf(col.r, maxf(col.g, col.b))
		var hue: Color = col if m < 0.01 else Color(col.r / m, col.g / m, col.b / m)
		spr.modulate = Color(hue.r * 1.7, hue.g * 1.7, hue.b * 1.7, 1.0)
	add_child(pizza)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		DevState.arena_mode = false
		DevState.invincible = false
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
		return
	if not is_instance_valid(_camera):
		return
	# Drag (any mouse button held) pans the camera; wheel zooms.
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.button_mask != 0:
			_camera.position -= mm.relative / _camera.zoom
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera.zoom = (_camera.zoom * 1.1).clamp(Vector2(0.25, 0.25), Vector2(2.0, 2.0))
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera.zoom = (_camera.zoom * 0.9).clamp(Vector2(0.25, 0.25), Vector2(2.0, 2.0))
