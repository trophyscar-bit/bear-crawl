extends Node2D

# ── Dungeon-crawler level (BSP rooms + corridors) ──────────────────────────
# Proven roguelike methodology: recursively partition the grid (BSP), place a
# room in each leaf, connect rooms with 2-wide corridors. Large layout you
# explore (camera follows, fog-of-war minimap), torch-limited vision, and a
# boss room you must clear to open the descent. Real-time — keeps the bears.
# Self-contained; reached via Dev Mode → Level Select.

const PlayerScene := preload("res://scenes/player.tscn")
const EnemyScene := preload("res://scenes/enemy.tscn")
const PlushBrawlerScene := preload("res://scenes/plush_brawler.tscn")
const GunBearScene := preload("res://scenes/gun_bear.tscn")
const ShrinkwrapBearScene := preload("res://scenes/shrinkwrap_bear.tscn")
const GrowlerScene := preload("res://scenes/growler.tscn")
const DucklingScene := preload("res://scenes/duckling.tscn")
const HoundScene := preload("res://scenes/hound.tscn")
const FrostCubScene := preload("res://scenes/frost_cub.tscn")
const SealScene := preload("res://scenes/seal.tscn")
const ArmyBearScene := preload("res://scenes/army_bear.tscn")
const PartyAnimalScene := preload("res://scenes/party_animal.tscn")
const BossScene := preload("res://scenes/boss.tscn")            # the original dark-bear boss
const DesertBossScene := preload("res://scenes/desert_boss.tscn")  # desert charger
const BeanieBearScene := preload("res://scenes/beanie_bear.tscn")
const TeddyBearScene := preload("res://scenes/teddy_bear.tscn")
const CreamBearScene := preload("res://scenes/cream_bear.tscn")
const PaleBearScene := preload("res://scenes/pale_bear.tscn")     # fast weak swarmer (white plush)
const YarnBearScene := preload("res://scenes/yarn_bear.tscn")     # tangled-in-yarn melee chaser
const PotBearScene := preload("res://scenes/pot_bear.tscn")       # slow tanky bruiser (in a pot)
const DarkAllyScene := preload("res://scenes/dark_bear_ally.tscn")
const SkeletonScene := preload("res://scenes/skeleton.tscn")
const SwordSkeletonScene := preload("res://scenes/sword_skeleton.tscn")
const KKPupScene := preload("res://scenes/kk_pup.tscn")
const LawnBearScript := preload("res://scripts/lawn_bear.gd")
const CRITTER_POOL: Array = [DucklingScene, HoundScene, FrostCubScene, SealScene, BeanieBearScene, TeddyBearScene, CreamBearScene, SkeletonScene]
const LightTex := preload("res://assets/light_radial.png")
const FloorTex := preload("res://assets/dungeon_floor.png")
const WallTex := preload("res://assets/dungeon_wall.png")
const FloorNormalTex := preload("res://assets/dungeon_floor_n.png")
const WallNormalTex := preload("res://assets/dungeon_wall_n.png")
const StalagmiteTex := preload("res://assets/stalagmite.png")
const DungeonTrapScene := preload("res://scenes/dungeon_trap.tscn")
const CandelabraTex := preload("res://assets/candelabra.png")
const WallTorchTex := preload("res://assets/wall_torch.png")
var _ui_frame_tex: Texture2D   # wood window frame for popups (loaded at runtime, no .import)
const PizzaIconTex := preload("res://assets/pizza.png")
const BallIconTex := preload("res://assets/bouncy_ball.png")
const HealthBarLib := preload("res://scripts/health_bar.gd")
const HealIconTex := preload("res://assets/pickup_heal.png")
const StairsTex := preload("res://assets/stairs_down.png")

@export var grid_w: int = 92       # ~4x area (2x each dim)
@export var grid_h: int = 64
@export var tile: float = 64.0
@export var bsp_levels: int = 6    # more splits → more rooms on the bigger map
@export var min_leaf: int = 8      # partition size → room size
@export var max_room: int = 0      # cap room size (0 = uncapped) → tighter, mazier
@export var corridor_w: int = 3    # wider corridors so you can't get blocked in
@export var enemy_count: int = 44
@export var item_count: int = 13
@export var brazier_count: int = 17   # slightly more candelabras
@export var trap_count: int = 7

var _fw: int                          # = grid_w  (named for minimap compat)
var _fh: int                          # = grid_h
var _wall: Array = []                 # _wall[y][x] : bool (true = solid)
var _rooms: Array[Rect2i] = []
var _start_room: Rect2i
var _boss_room: Rect2i
var _player: Node2D = null
var _boss: Node = null
var _boss_dead: bool = false
var _boss_alerted: bool = false
var _boss_max_hp: int = 1
var _exit_pos: Vector2 = Vector2.ZERO
var _exit_node: Node2D = null
var _items: Array[Vector2] = []
var _braziers: Array[Dictionary] = []
var _explored: Dictionary = {}
var _cleared: bool = false

@onready var _camera: Camera2D = $Camera2D
@onready var _minimap: Control = $MiniMapLayer/MiniMap
@onready var _env: Environment = ($WorldEnvironment as WorldEnvironment).environment
@onready var _ambient: CanvasModulate = $Ambient

const LightBleedShader := preload("res://shaders/light_bleed.gdshader")
const FogShader := preload("res://shaders/fog.gdshader")
const FogNoiseTex := preload("res://assets/fog_noise.png")
const MODE_NAMES: Array = ["", "Standard", "Bright", "Cool", "Noir", "Warm"]
var _gi_rect: ColorRect = null
var _fog_mat: ShaderMaterial = null
var _mode_buttons: Array[Button] = []
var _light_buttons: Array[Button] = []
var _enemy_buttons: Array[Button] = []
var _base_ambient: Color = Color(0.143, 0.132, 0.176)
var _weapon_popup_open: bool = false
var _near_loot_item: Dictionary = {}
var _near_loot_area: Area2D = null

# Theme: "cave" (default torchlit dungeon) or "backrooms" (Level 0). The
# backrooms.tscn root sets this so one script drives both looks.
@export var theme: String = "cave"
var _bk_wall: Texture2D = null
var _bk_floor: Texture2D = null
# Custom themed levels (neon / damp / hand) drive their floor+wall+props+mood from
# a per-variant config (see _variant_cfg). One scene per theme; the dev Level Lab
# picks the design variant via ArpgState.pending_variant.
@export var variant: int = 1
@export var floor_px_override: int = 0   # tile-size test: force the floor display px
@export var wall_override: String = ""   # wall test: force a specific wall tile name
@export var wall_face_override: float = 0.0  # wall test: force the front-face height
var _variant: int = 1
var _lvl_wall: Texture2D = null
var _lvl_wall_top: Texture2D = null
var _lvl_floor: Texture2D = null
var _lvl_ambient: Color = Color(0.15, 0.14, 0.21)
var _lvl_cfg: Dictionary = {}
var _tex_cache: Dictionary = {}
var _pack: int = 1                  # backrooms asset pack 1-5 (live-switchable)
var _bk_floor_node: TextureRect = null
var _pack_buttons: Array[Button] = []
const BK_WALL_FACE: float = 0.85    # backrooms wall face height (steeper "angle")
var _astar: AStarGrid2D = null      # grid pathfinding so enemies route around walls
# Energy + reach multipliers for the 1-5 light-boost levels.
const LIGHT_ENERGY_MULT: Array = [1.0, 1.35, 1.8, 2.4, 3.1]
const LIGHT_REACH_MULT: Array  = [1.0, 1.12, 1.28, 1.48, 1.72]
# Enemy self-light energy for the 1-3 brightness levels (1 = off).
const ENEMY_LIGHT_ENERGY: Array = [0.0, 0.7, 1.25]

var _hud_level: Label
var _hud_gold: Label
var _hud_weapon: Label
var _hud_xp_fill: ColorRect
var _hp_update: Callable = Callable()
var _hud_toast: Label
var _hud_boss_root: Control
var _hud_boss_fill: ColorRect
var _hud_boss_label: Label

func _ready() -> void:
	randomize()
	Engine.time_scale = 1.0   # defensive: clear any stale slow-mo from a prior scene
	# Boss-portal sent us to a backrooms stage — render this floor as backrooms.
	if ArpgState.backrooms_next:
		theme = "backrooms"
		ArpgState.backrooms_next = false
	if theme == "backrooms":
		_bk_wall = _load_tex_opt("res://assets/backrooms_wall.png")
		_bk_floor = _load_tex_opt("res://assets/backrooms_floor.png")
	elif _is_custom_theme():
		_apply_variant()
	ArpgState.active = true
	ArpgState.begin_spawn_grace(5.0)   # 5s breather — nothing shoots on level entry
	ArpgState.no_projectile_glow = _flat_lit()   # flat levels — no projectile glow
	ArpgState.dungeon_path = scene_file_path   # so the shop knows where to descend
	ArpgState.loot_dropped.connect(_spawn_loot)
	ArpgState.leveled_up.connect(_on_level_up)
	ArpgState.toast.connect(_on_toast)
	if theme == "suburb":
		_generate_suburb()
	else:
		_generate_bsp()
	_build_nav()
	_spawn_floor()
	_build_walls()
	_spawn_player()
	_spawn_boss()
	_spawn_exit()
	if theme != "backrooms" and not _is_custom_theme():
		_spawn_braziers()       # cave candelabras/stalagmites — themed levels bring their own
	_spawn_traps()
	_spawn_enemies()
	# Healing hearts per floor now scale with difficulty (was a flat 13 — that alone
	# healed ~26 HP a floor and made damage meaningless).
	match GameSettings.difficulty:
		0: item_count = 5    # EASY  (was 7)
		2: item_count = 1    # HARD  (was 2)
		_: item_count = 3    # MEDIUM (was 4)
	if GameSettings.ascension >= 1:
		item_count = maxi(1, int(round(float(item_count) * 0.7)))   # ascension floors: ~30% fewer hearts
	_spawn_items()
	if theme == "backrooms":
		_spawn_props()
	elif _is_custom_theme():
		_spawn_custom_props()
		if theme == "hand":
			_spawn_hand_wall_torches()
			_spawn_hand_pillars()
			_spawn_hand_clusters()
		elif theme == "poolrooms":
			_spawn_pools()
			_spawn_pool_wall_fixtures()
		elif theme == "wheat":
			_spawn_wheat_decor()
		elif theme == "sewer":
			_spawn_sewer_canals()
	_camera.make_current()
	if _minimap and _minimap.has_method("bind"):
		_minimap.bind(self)
	_build_hud()
	_refresh_hud()
	_build_fog()
	_apply_lighting_mode(1)   # Standard only — locked
	if theme == "backrooms":
		_build_backrooms_lighting()
	elif theme == "hand":
		_ambient.color = Color(0.90, 0.89, 0.86)   # flat normal lighting — lit white page
	elif theme == "cyber2077":
		_ambient.color = Color(0.84, 0.85, 0.90)   # flat normal lighting — cool, no neon aura
	elif theme == "wheat":
		_ambient.color = Color(0.98, 0.95, 0.80)   # warm sunny daylight — outdoor field
	elif theme == "suburb":
		_ambient.color = Color(0.94, 0.95, 0.98)   # neutral daylight — outdoor neighbourhood
		_stripe_suburb_roads()
		_scatter_suburb_houses()
		_spawn_suburb_cars()
		_spawn_lawn_bears()
	elif theme == "glitch":
		_ambient.color = Color(0.55, 0.55, 0.6)     # mid — so the flashing brick colours read
		_apply_glitch_player()
		_start_glitch_flash()
	elif theme == "poolrooms":
		# Flat-lit (no player aura / shot glow that washed everything out). Day variants
		# (1-3) are brightly lit; night variants (4-5) drop to a dim, moody pool.
		_ambient.color = Color(0.90, 0.91, 0.88) if _variant <= 3 else Color(0.34, 0.39, 0.46)
	elif theme == "toystore":
		_ambient.color = Color(0.96, 0.95, 0.92)    # bright store lighting
	elif theme == "carnival":
		_ambient.color = Color(0.95, 0.96, 0.98)    # outdoor daylight midway
	elif theme == "frozen":
		_ambient.color = Color(0.72, 0.82, 0.95)    # cold pale-blue cavern glow
	elif _is_custom_theme():
		_ambient.color = _lvl_ambient
	_apply_brightness(ArpgState.brightness_level, false)   # restore chosen darkness preset

# ── BSP generation ─────────────────────────────────────────────────────────
func _generate_bsp() -> void:
	_fw = grid_w
	_fh = grid_h
	_wall = []
	for y in _fh:
		var row: Array = []
		for x in _fw:
			row.append(true)
		_wall.append(row)
	_rooms = []
	var parts: Array[Rect2i] = [Rect2i(1, 1, grid_w - 2, grid_h - 2)]
	for _lvl in range(bsp_levels):
		var nxt: Array[Rect2i] = []
		for p in parts:
			if p.size.x <= min_leaf * 2 and p.size.y <= min_leaf * 2:
				nxt.append(p)
				continue
			var horiz: bool = p.size.x > p.size.y
			if absi(p.size.x - p.size.y) < 4:
				horiz = randf() < 0.5
			if horiz and p.size.x >= min_leaf * 2:
				var cut: int = randi_range(min_leaf, p.size.x - min_leaf)
				nxt.append(Rect2i(p.position.x, p.position.y, cut, p.size.y))
				nxt.append(Rect2i(p.position.x + cut, p.position.y, p.size.x - cut, p.size.y))
			elif p.size.y >= min_leaf * 2:
				var cut2: int = randi_range(min_leaf, p.size.y - min_leaf)
				nxt.append(Rect2i(p.position.x, p.position.y, p.size.x, cut2))
				nxt.append(Rect2i(p.position.x, p.position.y + cut2, p.size.x, p.size.y - cut2))
			else:
				nxt.append(p)
		parts = nxt
	# Carve a roomy-but-distinct room in each partition — leave a 2-4 cell rock
	# margin so rooms stay separated (linked by corridors), not merged into one
	# big arena. Min size 6 keeps every room dodge-able.
	for p in parts:
		var rw: int = clampi(p.size.x - randi_range(2, 4), 6, maxi(6, p.size.x - 2))
		var rh: int = clampi(p.size.y - randi_range(2, 4), 6, maxi(6, p.size.y - 2))
		# Cap room size for a tighter, more maze-like layout (rooms no longer fill
		# their whole partition — leaves more rock/corridors between them).
		if max_room > 0:
			rw = mini(rw, max_room)
			rh = mini(rh, max_room)
		# Soft-trim oversized rooms: past ~15 tiles, halve the excess so the biggest
		# rooms feel a bit tighter without flattening all rooms to one size.
		var soft: int = 15
		if rw > soft:
			rw = soft + (rw - soft) / 2
		if rh > soft:
			rh = soft + (rh - soft) / 2
		var rx: int = p.position.x + randi_range(1, maxi(1, p.size.x - rw - 1))
		var ry: int = p.position.y + randi_range(1, maxi(1, p.size.y - rh - 1))
		var room := Rect2i(rx, ry, rw, rh)
		_rooms.append(room)
		_carve_rect(room)
	if _rooms.is_empty():
		_rooms.append(Rect2i(2, 2, 6, 6))
		_carve_rect(_rooms[0])
	# connect rooms in a spanning chain (sorted), plus a couple of loops
	_rooms.sort_custom(func(a: Rect2i, b: Rect2i) -> bool:
		return (a.position.x + a.position.y) < (b.position.x + b.position.y))
	for i in range(_rooms.size() - 1):
		_connect_rooms(_rooms[i], _rooms[i + 1])
	for _e in range(2):
		if _rooms.size() > 2:
			_connect_rooms(_rooms[randi() % _rooms.size()], _rooms[randi() % _rooms.size()])
	_start_room = _rooms[0]
	# Boss room = a random room on the FAR side of the map from the start — never
	# adjacent to the spawn (you should have to travel to the boss, not wake up in
	# the fight). Requires at least 55% of the farthest room's distance, with an
	# absolute floor so it holds on small maps too.
	var sc: Vector2 = Vector2(_room_center_cell(_start_room))
	var far_fallback: int = _rooms.size() - 1
	var far_d: float = -1.0
	var dists: Array = []
	for i in range(1, _rooms.size()):
		var d: float = Vector2(_room_center_cell(_rooms[i])).distance_to(sc)
		dists.append([i, d])
		if d > far_d:
			far_d = d
			far_fallback = i
	var min_d: float = maxf(far_d * 0.55, 16.0)
	var candidates: Array = []
	for pair in dists:
		if float(pair[1]) >= min_d:
			candidates.append(int(pair[0]))
	_boss_room = _rooms[candidates[randi() % candidates.size()]] if not candidates.is_empty() else _rooms[far_fallback]
	_scrub_isolated_walls()

# Carve away "lone cube" wall cells — a solid cell with floor on all four sides reads
# as a random block floating in the middle of a room. Corridors/room edges keep their
# walls (those have a solid neighbour); only fully-surrounded singletons are removed.
func _scrub_isolated_walls() -> void:
	# Remove "lone cube" walls AND thin peninsula nubs — a wall cell jutting into a room
	# with 3+ open orthogonal sides reads as a random wall block in the middle of the
	# floor. Iterated a few passes since removing one nub can expose the next.
	for _pass in range(3):
		var kill: Array = []
		for y in range(1, _fh - 1):
			for x in range(1, _fw - 1):
				if not _wall[y][x]:
					continue
				var open_n: int = 0
				if not _wall[y - 1][x]: open_n += 1
				if not _wall[y + 1][x]: open_n += 1
				if not _wall[y][x - 1]: open_n += 1
				if not _wall[y][x + 1]: open_n += 1
				if open_n >= 3:
					kill.append(Vector2i(x, y))
		if kill.is_empty():
			break
		for c in kill:
			_wall[c.y][c.x] = false

func _carve_rect(r: Rect2i) -> void:
	for y in range(r.position.y, r.position.y + r.size.y):
		for x in range(r.position.x, r.position.x + r.size.x):
			_carve_cell(x, y)

func _carve_cell(x: int, y: int) -> void:
	if x >= 0 and x < _fw and y >= 0 and y < _fh:
		_wall[y][x] = false

# ── SUBURB: a connected cul-de-sac road network ─────────────────────────────────
# Roads are the walkable FLOOR; the houses fill the rest as the wall mass. Two avenues
# spanning the map, vertical connectors tying them into one loop (so EVERY road links),
# and cul-de-sac branches that dead-end in circular courts (the rooms / fight arenas).
func _carve_hroad(x0: int, x1: int, yc: int, w: int) -> void:
	var h: int = w / 2
	for x in range(x0, x1 + 1):
		for dy in range(-h, w - h):
			_carve_cell(x, yc + dy)

func _carve_vroad(y0: int, y1: int, xc: int, w: int) -> void:
	var h: int = w / 2
	for y in range(mini(y0, y1), maxi(y0, y1) + 1):
		for dx in range(-h, w - h):
			_carve_cell(xc + dx, y)

func _carve_bulb(cx: int, cy: int, r: int) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if Vector2(x - cx, y - cy).length() <= float(r) + 0.5:
				_carve_cell(x, y)
	_rooms.append(Rect2i(maxi(1, cx - r), maxi(1, cy - r),
		mini(2 * r, _fw - 2 - maxi(1, cx - r)), mini(2 * r, _fh - 2 - maxi(1, cy - r))))

func _generate_suburb() -> void:
	_fw = grid_w
	_fh = grid_h
	_wall = []
	for y in _fh:
		var row: Array = []
		for x in _fw:
			row.append(true)
		_wall.append(row)
	_rooms = []
	var W: int = 3       # road width (cells)
	var m: int = 4       # edge margin
	var ay_top: int = m + 12
	var ay_bot: int = _fh - m - 12
	var ay_mid: int = (ay_top + ay_bot) / 2
	# Two full avenues + a shorter mid avenue.
	_carve_hroad(m, _fw - m, ay_top, W)
	_carve_hroad(m, _fw - m, ay_bot, W)
	_carve_hroad(m + 8, _fw - m - 8, ay_mid, W)
	# Vertical connectors tie the avenues into one looped network — all roads link.
	var conx: Array = []
	var cn: int = 4
	for i in range(cn):
		var cx: int = int(round(lerp(float(m + 6), float(_fw - m - 6), float(i) / float(cn - 1))))
		conx.append(cx)
		_carve_vroad(ay_top, ay_bot, cx, W)
	# Cul-de-sac branches off the top & bottom avenues, each ending in a court.
	var bxx: int = m + 14
	while bxx < _fw - m - 10:
		if randf() < 0.85:
			var ty: int = randi_range(m + 5, ay_top - 6)
			_carve_vroad(ty, ay_top, bxx, W)
			_carve_bulb(bxx, ty, randi_range(4, 5))
		if randf() < 0.85:
			var by: int = randi_range(ay_bot + 6, _fh - m - 5)
			_carve_vroad(ay_bot, by, bxx, W)
			_carve_bulb(bxx, by, randi_range(4, 5))
		bxx += randi_range(14, 20)
	# Side courts off the outer connectors.
	_carve_bulb(conx[0], ay_mid, 5)
	_carve_bulb(conx[conx.size() - 1], ay_mid, 5)
	if _rooms.is_empty():
		_carve_bulb(_fw / 2, _fh / 2, 5)
	# Start = first court; boss = the farthest court.
	_start_room = _rooms[0]
	var sc: Vector2 = Vector2(_room_center_cell(_start_room))
	var far_i: int = 0
	var far_d: float = -1.0
	for i in range(_rooms.size()):
		var d: float = Vector2(_room_center_cell(_rooms[i])).distance_to(sc)
		if d > far_d:
			far_d = d
			far_i = i
	_boss_room = _rooms[far_i]

func _room_center_cell(r: Rect2i) -> Vector2i:
	return Vector2i(r.position.x + r.size.x / 2, r.position.y + r.size.y / 2)

func _connect_rooms(a: Rect2i, b: Rect2i) -> void:
	var ca := _room_center_cell(a)
	var cb := _room_center_cell(b)
	# Wide L-shaped corridor (corridor_w cells thick) so enemies can't wall you in.
	var half: int = corridor_w / 2
	for x in range(mini(ca.x, cb.x), maxi(ca.x, cb.x) + 1):
		for w in range(-half, corridor_w - half):
			_carve_cell(x, ca.y + w)
	for y in range(mini(ca.y, cb.y), maxi(ca.y, cb.y) + 1):
		for w in range(-half, corridor_w - half):
			_carve_cell(cb.x + w, y)

# ── world helpers ──────────────────────────────────────────────────────────
func _room_center_world(r: Rect2i) -> Vector2:
	var c := _room_center_cell(r)
	return Vector2((c.x + 0.5) * tile, (c.y + 0.5) * tile)

func world_to_fine(p: Vector2) -> Vector2:
	return Vector2(p.x / tile, p.y / tile)

func floor_point_near(origin: Vector2, dmin: float, dmax: float, require_los: bool = false) -> Vector2:
	# A guaranteed floor cell (inside a room) within [dmin, dmax] of `origin`. Used by
	# the boss teleport so it can't land in rock / outside the playable area. With
	# require_los, only returns a spot with a clear line back to `origin` (so the
	# boss can't blink to the far side of a wall and get lost).
	var space := get_world_2d().direct_space_state
	for _try in 120:
		var room: Rect2i = _rooms[randi() % _rooms.size()]
		var x: int = randi_range(room.position.x, room.position.x + room.size.x - 1)
		var y: int = randi_range(room.position.y, room.position.y + room.size.y - 1)
		var w := Vector2((x + 0.5) * tile, (y + 0.5) * tile)
		var d: float = w.distance_to(origin)
		if d < dmin or d > dmax:
			continue
		if require_los:
			var q := PhysicsRayQueryParameters2D.create(w, origin)
			q.collision_mask = 1
			if not space.intersect_ray(q).is_empty():
				continue   # a wall sits between this spot and the player
		return w
	# Relax LOS rather than fail outright.
	if require_los:
		return floor_point_near(origin, dmin, dmax, false)
	return _random_floor_world(0.0, false)

func _random_floor_world(min_dist_from_start: float = 0.0, avoid_start: bool = false) -> Vector2:
	var sc := _room_center_world(_start_room)
	for _try in 120:
		var room: Rect2i = _rooms[randi() % _rooms.size()]
		if avoid_start and room == _start_room:
			continue
		var x: int = randi_range(room.position.x, room.position.x + room.size.x - 1)
		var y: int = randi_range(room.position.y, room.position.y + room.size.y - 1)
		var w := Vector2((x + 0.5) * tile, (y + 0.5) * tile)
		if w.distance_to(sc) >= min_dist_from_start:
			return w
	return _room_center_world(_rooms[_rooms.size() - 1])

# ── build ──────────────────────────────────────────────────────────────────
# Glitch floor — one tile yanked from every biome in the game, rolled per cell.
const GLITCH_FLOOR_POOL := [
	"res://assets/dungeon_floor.png",
	"res://assets/backrooms_floor.png",
	"res://assets/cyber2077/floors/floor.png",
	"res://assets/damp/floors/cobble.png",
	"res://assets/damp/floors/brick.png",
	"res://assets/damp/floors/green.png",
	"res://assets/hand/floors/bricks.png",
	"res://assets/hand/floors/floor.png",
	"res://assets/neon/floors/floor.png",
	"res://assets/poolrooms/floors/deck.png",
	"res://assets/poolrooms/floors/water.png",
	"res://assets/sewer/floors/walk.png",
	"res://assets/space/floors/floor.png",
	"res://assets/suburb/floors/road.png",
	"res://assets/wheat/floors/ground.png",
	"res://assets/glitch/floors/static.png",
]

func _spawn_glitch_floor() -> void:
	# CORRUPTED floor: every tile is a different biome's floor texture, rolled per cell.
	# Heavily DARKENED so the patchwork reads as a dim backdrop — the bright flashing walls
	# and the flashing player pop against near-black instead of fighting a busy floor.
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0)
	bg.size = Vector2(_fw * tile, _fh * tile)
	bg.z_index = -21
	add_child(bg)
	var floor_dim := Color(0.2, 0.2, 0.24)
	var pool: Array = []
	for p in GLITCH_FLOOR_POOL:
		var t: Texture2D = _ctex(p)
		if t != null:
			pool.append(_upscale_tex(t, 64))
	if pool.is_empty():
		return
	for y in _fh:
		for x in _fw:
			if _wall[y][x]:
				continue
			var disp: Texture2D = pool[randi() % pool.size()]
			var ds: float = float(disp.get_width())
			var s := Sprite2D.new()
			s.texture = disp
			s.position = Vector2((x + 0.5) * tile, (y + 0.5) * tile)
			var sc: float = tile / ds
			s.scale = Vector2(sc * (-1.0 if randf() < 0.5 else 1.0), sc * (-1.0 if randf() < 0.5 else 1.0))
			s.rotation = float(randi() % 4) * (PI * 0.5)
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			s.modulate = floor_dim   # near-black so the flashing walls/player carry the scene
			s.z_index = -20
			add_child(s)

func _spawn_floor() -> void:
	if theme == "glitch":
		_spawn_glitch_floor()
		return
	# Plain diffuse — lights fall off SMOOTHLY across the floor (no per-tile
	# normal-map shading, which read as a grid of gray boxes).
	var f := TextureRect.new()
	var ftex: Texture2D = _floor_texture()
	# Themed levels use small (16-32px) pixel-art tiles. Tiled at native size they
	# read as a dense, busy repeat. Blow them up (integer nearest-neighbour) so each
	# tile is a big crisp pixel-art square — far less repetition, deliberate look.
	if _is_custom_theme():
		var fpx: int = floor_px_override if floor_px_override > 0 else int(_lvl_cfg.get("floor_px", 64))
		ftex = _upscale_tex(ftex, fpx)
		f.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	f.texture = ftex
	f.stretch_mode = TextureRect.STRETCH_TILE
	f.size = Vector2(_fw * tile, _fh * tile)
	f.z_index = -20
	add_child(f)
	_bk_floor_node = f   # kept so the backrooms pack switcher can re-texture it
	# Cyber 2077: clean floor base, with the red "blood" tile scattered over ~10% of
	# floor cells (not a wall-to-wall blood floor, which looked terrible).
	if theme == "cyber2077":
		_scatter_floor_accents("floor_blood_clean", 0.10)

func _scatter_floor_accents(tile_name: String, chance: float) -> void:
	var t: Texture2D = _ctex("res://assets/cyber2077/floors/%s.png" % tile_name)
	if t == null:
		return
	var disp: Texture2D = _upscale_tex(t, 64)
	var ds: float = float(disp.get_width())
	for y in _fh:
		for x in _fw:
			if _wall[y][x] or randf() >= chance:
				continue
			var s := Sprite2D.new()
			s.texture = disp
			s.position = Vector2((x + 0.5) * tile, (y + 0.5) * tile)
			s.scale = Vector2(tile / ds, tile / ds)
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			s.z_index = -19   # just above the base floor, below the building mass
			add_child(s)

# Integer-scale a pixel-art texture up to ~target px (nearest neighbour = crisp).
func _upscale_tex(tex: Texture2D, target: int) -> Texture2D:
	if tex == null:
		return tex
	var img: Image = tex.get_image()
	if img == null:
		return tex
	var s: int = maxi(1, int(round(float(target) / float(maxi(1, img.get_width())))))
	if s <= 1:
		return tex
	img = img.duplicate()
	img.resize(img.get_width() * s, img.get_height() * s, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)

var _glitch_white: Texture2D = null
# Flat white tile — glitch walls use this so the colour-flash modulate reads as a SOLID
# flashing cube (no brick texture underneath, just pure flashing colour).
func _glitch_white_tex() -> Texture2D:
	if _glitch_white == null:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 1))
		_glitch_white = ImageTexture.create_from_image(img)
	return _glitch_white

var _wall_torch_pos: Array = []   # placed wall-sconce positions (for spacing)

func _build_walls() -> void:
	_wall_torch_pos.clear()
	# Cyber 2077 redesign: no square wall caps. The whole non-room area is one solid
	# dark building mass; rooms are floor cut into it; rectangular facades (door /
	# windows / circuits) stand along room edges as in-proportion set-pieces.
	if theme == "cyber2077":
		_build_walls_building()
		return
	if theme == "suburb":
		_build_walls_suburb()
		return
	for y in _fh:
		for x in _fw:
			if not _wall[y][x]:
				continue
			# Interior solid cells (no floor neighbour) get NO collision/face — but they
			# still need a top tile, otherwise the floor (drawn under the whole grid)
			# shows straight through the middle of a wall slab, so the wall reads as
			# full of diamond holes. Paint a plain cap so the mass is continuous.
			if not _touches_floor(x, y):
				var fill := Sprite2D.new()
				var ftex: Texture2D = _glitch_white_tex() if theme == "glitch" else _wall_top_texture()
				var fts: float = float(ftex.get_width())
				fill.texture = ftex
				fill.position = Vector2((x + 0.5) * tile, (y + 0.5) * tile)
				fill.scale = Vector2(tile / fts, tile / fts)
				fill.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if _is_custom_theme() else CanvasItem.TEXTURE_FILTER_LINEAR
				if theme == "glitch":
					fill.z_index = 2
					add_child(fill)
					fill.add_to_group("glitch_wall")
					continue
				fill.modulate = Color(0.72, 0.72, 0.78)   # slightly shaded — reads as "deep" rock
				fill.z_index = 2
				add_child(fill)
				continue
			var body := StaticBody2D.new()
			body.add_to_group("walls")
			body.position = Vector2((x + 0.5) * tile, (y + 0.5) * tile)
			body.collision_layer = 1
			body.collision_mask = 0
			var faces_room: bool = (y + 1 < _fh and not _wall[y + 1][x])
			var cs := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			if theme == "backrooms" and faces_room:
				# The FACE sprite is drawn tall (BK_WALL_FACE) for the angled look, but
				# the COLLISION only extends a thin sliver below the tile. The old
				# 0.85-tile collision lip poked deep into the floor cell below and
				# snagged enemies/player ("stuck at the bottom of walls").
				var ext: float = 0.16 * tile
				rect.size = Vector2(tile, tile + ext)
				cs.position = Vector2(0, ext * 0.5)
			else:
				rect.size = Vector2(tile, tile)
			cs.shape = rect
			body.add_child(cs)
			var wt: Texture2D = _wall_texture()
			var top_tex: Texture2D = _wall_top_texture()
			if theme == "glitch":
				wt = _glitch_white_tex()
				top_tex = wt
			var ts: float = float(wt.get_width())
			# Pseudo-3/4 "face": if this wall faces a room to the SOUTH, draw a
			# darker front face extending down so the wall reads as having height
			# (the angled look), with the lit top on top.
			if faces_room:
				# Backrooms uses a taller face (steeper "angle" — more wall visible).
				var fh: float = BK_WALL_FACE if theme == "backrooms" else 0.5
				var fy: float = tile * (0.5 + fh * 0.5) if theme == "backrooms" else tile * 0.55
				# Themed levels: configurable face height (taller = walls read as bigger
				# standing rectangles). wall_face_override drives the height test.
				if _is_custom_theme():
					fh = wall_face_override if wall_face_override > 0.0 else float(_lvl_cfg.get("wall_face", 0.5))
					fy = tile * (0.5 + fh * 0.5)
				var face := Sprite2D.new()
				face.name = "Face"
				face.texture = wt
				face.scale = Vector2(tile / ts, (tile * fh) / ts)
				face.position = Vector2(0, fy)
				# Themed levels can keep the face bright (so lit windows still read);
				# stone/backrooms faces stay heavily shaded for the 3/4 "angle".
				var face_shade: float = float(_lvl_cfg.get("face_shade", 0.5)) if _is_custom_theme() else 0.5
				face.modulate = Color(face_shade, face_shade, face_shade + 0.06)
				face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if _is_custom_theme() else CanvasItem.TEXTURE_FILTER_LINEAR
				face.z_index = 1
				body.add_child(face)
				if theme == "glitch":
					face.add_to_group("glitch_wall")
			var spr := Sprite2D.new()
			spr.name = "Top"
			spr.texture = top_tex
			spr.scale = Vector2(tile / ts, tile / ts)
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if _is_custom_theme() else CanvasItem.TEXTURE_FILTER_LINEAR
			spr.z_index = 2
			body.add_child(spr)
			if theme == "glitch":
				spr.add_to_group("glitch_wall")
			var occ := LightOccluder2D.new()
			var poly := OccluderPolygon2D.new()
			var h := tile / 2.0
			poly.polygon = PackedVector2Array([
				Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
			occ.occluder = poly
			body.add_child(occ)
			add_child(body)
			# Wall-mounted torch sconce on walls that face a room below — a warm
			# flickering glow on the stone (atmospheric "lights on the wall").
			if theme != "backrooms" and not _is_custom_theme() and y + 1 < _fh and not _wall[y + 1][x] and randf() < 0.06:
				var tpos := Vector2((x + 0.5) * tile, (y + 0.5) * tile + tile * 0.42)
				# Never cluster wall sconces — keep them ≥6 blocks apart.
				if not _pos_too_close(tpos, _wall_torch_pos, tile * 6.0):
					_wall_torch_pos.append(tpos)
					_add_wall_torch(tpos, body, occ)

# ── Cyber 2077: solid building mass + facade set-pieces ──────────────────────
func _build_walls_building() -> void:
	var btex: Texture2D = _ctex("res://assets/cyber2077/walls/building.png")
	if btex == null:
		btex = _wall_texture()
	var disp: Texture2D = _upscale_tex(btex, 64)
	var bts: float = float(disp.get_width())
	for y in _fh:
		for x in _fw:
			if not _wall[y][x]:
				continue
			# Every solid cell is painted with the dark building tile → one continuous
			# mass, no isolated dark squares, no black voids behind walls.
			var s := Sprite2D.new()
			s.texture = disp
			s.position = Vector2((x + 0.5) * tile, (y + 0.5) * tile)
			s.scale = Vector2(tile / bts, tile / bts)
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			s.z_index = -10
			add_child(s)
			# Collision + light occluder only where the mass borders a room.
			if not _touches_floor(x, y):
				continue
			var body := StaticBody2D.new()
			body.add_to_group("walls")
			body.position = Vector2((x + 0.5) * tile, (y + 0.5) * tile)
			body.collision_layer = 1
			body.collision_mask = 0
			var cs := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(tile, tile)
			cs.shape = rect
			body.add_child(cs)
			var occ := LightOccluder2D.new()
			var poly := OccluderPolygon2D.new()
			var h := tile / 2.0
			poly.polygon = PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
			occ.occluder = poly
			body.add_child(occ)
			add_child(body)
	_spawn_facades()

func _spawn_facades() -> void:
	# Stand the rectangular facade art (door / windows / circuits) along room TOP
	# edges as upright set-pieces — aspect locked, scaled up, never squared.
	var names: Array = _lvl_cfg.get("facades", ["fac_door", "fac_windows", "fac_circuits"])
	var pool: Array = []
	for n in names:
		var t: Texture2D = _ctex("res://assets/cyber2077/props/%s.png" % String(n))
		if t != null:
			pool.append(t)
	if pool.is_empty():
		return
	for room in _rooms:
		if room == _start_room or room == _boss_room:
			continue
		if randf() > 0.72:
			continue
		var top_y: float = float(room.position.y) * tile          # room's top floor edge
		var n: int = randi_range(1, 2) if room.size.x >= 6 else 1
		var used_x: Array = []
		for i in n:
			var t: Texture2D = pool[randi() % pool.size()]
			# INTEGER upscale (3×) so the facade pixels don't shimmer/jitter when the
			# camera moves (non-integer scale + nearest filter = crawling pixels).
			var disp: Texture2D = _upscale_tex(t, t.get_width() * 3)
			var H: float = float(disp.get_height())
			var W: float = float(disp.get_width())
			var fx: float = (float(room.position.x) + randf_range(1.2, maxf(1.2, float(room.size.x) - 1.2))) * tile
			if _pos_too_close(Vector2(fx, top_y), used_x, W * 0.9):
				continue
			used_x.append(Vector2(fx, top_y))
			var spr := Sprite2D.new()
			spr.texture = disp
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			# Base sits at the floor edge; the facade stands UP (north) into the wall.
			spr.position = Vector2(fx, top_y - H * 0.5 + tile * 0.35)
			# Wall decoration: sits in the building mass, always BEHIND the player/enemies
			# (above the building tile at -10, below the player at 0).
			spr.z_index = -5
			add_child(spr)
			# a soft sign glow on some facades
			if randf() < 0.5:
				_glow(spr.position, _lvl_cfg.get("amb", Color(0.2, 0.6, 0.9)).lerp(Color(0.4, 0.9, 1.0), 0.7), 0.6, 2.4)

func _touches_floor(x: int, y: int) -> bool:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
			Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	for d in dirs:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if nx >= 0 and nx < _fw and ny >= 0 and ny < _fh and not _wall[ny][nx]:
			return true
	return false

func _spawn_player() -> void:
	_player = PlayerScene.instantiate()
	_player.position = _room_center_world(_start_room)
	add_child(_player)
	# Single source of truth for max HP + base speed (includes the +HP cards). Doing
	# it manually here on top of apply_boons() double-counted the bonus → "15/11".
	if _player.has_method("apply_boons"):
		_player.apply_boons()   # now folds in ArpgState.speed_mult itself (no manual re-mult)
	if _player.has_method("heal"):
		# Between-floor healing is now gated by difficulty/ascension — you no longer get
		# topped off to full every floor (that let you face-tank with no consequence).
		#   • Floor 1 / Easy (no ascension): full heal (fresh start / casual).
		#   • Medium OR any ascension: heal only 50% of MISSING health.
		#   • Hard: NO heal between floors — you carry your damage forward.
		var full := true
		if int(ArpgState.depth) > 1:
			if GameSettings.difficulty == GameSettings.Difficulty.HARD:
				full = false   # 0% — handled below as no heal
			elif GameSettings.difficulty == GameSettings.Difficulty.MEDIUM or GameSettings.ascension >= 1:
				full = false
				var mh: int = int(_player.get("max_health"))
				var cur: int = int(_player.get("health"))
				_player.heal(int(round(float(mh - cur) * 0.5)))   # 50% of the gap
		if full:
			_player.heal(9999)   # Easy / floor 1: top off to max
	if _player.has_signal("died") and not _player.died.is_connected(_on_player_died):
		_player.died.connect(_on_player_died)
	# 20% chance a Dark Bear shows up as a companion for the run.
	if randf() < 0.20:
		var ally := DarkAllyScene.instantiate()
		ally.global_position = _player.position + Vector2(-70, 60)
		add_child(ally)
	var torch := _player.get_node_or_null("BearLight") as PointLight2D
	if torch != null:
		torch.energy = 0.8
		torch.texture_scale = 2.1
		torch.color = Color(1.0, 0.78, 0.5)
		# No wall shadows on the player aura — a 2D point light casts hard-edged
		# shadows that left an ugly hard line where lit floor met the wall. With
		# shadows off the aura is a clean smooth gradient everywhere.
		torch.shadow_enabled = false
		if _flat_lit():
			# Flat fully-lit space — no player light aura.
			torch.visible = false
			torch.energy = 0.0

func _spawn_boss() -> void:
	# Floor-boss roster, evenly rolled:
	#   Party Animal — panda rave (disco craters + party hats + projectiles)
	#   Army Bear    — kites at range, calls in airstrike clusters
	#   Original Boss— the dark-bear guardian (star spread + ground/paw slam, phases)
	#   Desert Charger — dash-charges, summons adds, pillars + slam (phases)
	# The last two are self-contained boss scenes (native size, no rig hacks).
	var roll: float = randf()
	var scene: PackedScene
	var hits: float          # how many of YOUR volleys the boss should take to kill
	var rig_k: float = 1.0   # extra rig scale; 1.0 = use the scene's native size
	if roll < 0.25:
		scene = PartyAnimalScene; hits = 44.0; rig_k = 1.6   # 2x tanky — its big hitbox dies too fast otherwise
	elif roll < 0.50:
		scene = ArmyBearScene; hits = 28.0; rig_k = 1.5   # kites at range → a few more
	elif roll < 0.75:
		scene = BossScene; hits = 20.0
	else:
		scene = DesertBossScene; hits = 18.0
	_boss = scene.instantiate()
	_boss.position = _room_center_world(_boss_room)
	# FIXED-HIT boss HP: scale to the player's CURRENT per-volley damage so the boss always
	# takes ~`hits` volleys to kill whether you hit for 8 or 80. The fight length is constant
	# regardless of power level (Ascension still adds its bump on top).
	var per_volley: int = maxi(1, ArpgState.weapon_damage() * ArpgState.weapon_count())
	_boss_max_hp = maxi(40, int(round(float(per_volley) * hits)))
	# Ascension HP curses (stack on top of the fixed-hit baseline):
	#   Asc 2 FORTIFIED FOES — every regular floor boss gains +30% HP
	#   Asc 5 FINAL TANK     — only the floor-10 final boss gains +50% HP
	if ArpgState.depth >= FINAL_FLOOR:
		if GameSettings.ascension >= 5:
			_boss_max_hp = int(round(float(_boss_max_hp) * 1.5))
	elif GameSettings.ascension >= 2:
		_boss_max_hp = int(round(float(_boss_max_hp) * 1.3))
	_boss.set("is_boss", true)          # boss HP bar + huge stain + death explosion
	if "touch_damage" in _boss:
		_boss.touch_damage = 2
	add_child(_boss)
	# Set HP *after* add_child: self-running bosses reset max_health in their _ready, so
	# assigning here wins and we refresh current health to full.
	if "max_health" in _boss:
		_boss.max_health = _boss_max_hp
		_boss.health = _boss_max_hp
	# Only the enemy/critter bosses get up-scaled (+ matching hitbox). The standalone
	# boss scenes already ship at their intended size.
	if rig_k != 1.0:
		var rig := _boss.get_node_or_null("Rig") as Node2D
		if rig != null:
			rig.scale *= rig_k
		var cs := _boss.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if cs != null and cs.shape is RectangleShape2D:
			var sh := (cs.shape as RectangleShape2D).duplicate() as RectangleShape2D
			sh.size = Vector2(sh.size.x * rig_k, sh.size.y * rig_k * 1.4)
			cs.shape = sh

func _boss_is_dead() -> bool:
	# A dying enemy leaves the "enemies" group at the START of its death anim
	# (well before the node frees), so check that — not is_instance_valid —
	# or the exit stays locked through the whole death sequence.
	if not is_instance_valid(_boss):
		return true
	return not _boss.is_in_group("enemies")

func _spawn_exit() -> void:
	# Sits in the boss room; only descends once the guardian is dead.
	_exit_pos = _room_center_world(_boss_room) + Vector2(0, tile * 1.2)
	var area := Area2D.new()
	area.position = _exit_pos
	area.collision_mask = 1
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 42.0
	cs.shape = c
	area.add_child(cs)
	var glow := PointLight2D.new()
	glow.texture = LightTex
	glow.color = Color(0.4, 1.0, 0.7)
	glow.energy = 1.4
	glow.texture_scale = 1.6
	area.add_child(glow)
	# Animated dimensional PORTAL to the next (normal) level.
	var portal := Sprite2D.new()
	var pt: Texture2D = _load_tex_mip("res://assets/portal_exit.png")
	if pt != null:
		portal.texture = pt
		portal.hframes = 3
		portal.vframes = 2          # 6-frame swirl (32px frames)
	portal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portal.scale = Vector2(2.6, 2.6)
	portal.z_index = 2              # a portal stands on the floor, not a hole in it
	area.add_child(portal)
	# Cycle the 6 swirl frames.
	var ptw := portal.create_tween().set_loops()
	ptw.tween_method(func(f: float) -> void: portal.frame = int(f) % 6, 0.0, 6.0, 0.66)
	# Gentle breathing pulse on the glow.
	var stw := glow.create_tween().set_loops()
	stw.tween_property(glow, "energy", 1.9, 1.4).set_trans(Tween.TRANS_SINE)
	stw.tween_property(glow, "energy", 1.2, 1.4).set_trans(Tween.TRANS_SINE)
	area.body_entered.connect(func(b: Node) -> void:
		if b.is_in_group("player"):
			_on_exit())
	_exit_node = area
	add_child(area)
	area.visible = false   # hidden until boss dies

func _add_fill_light(pos: Vector2, color: Color, energy: float, scl: float) -> PointLight2D:
	# Shadow-LESS, wide, dim light layered over a source — fakes warm INDIRECT
	# bounce filling the room (Godot 2D has no true GI; this reads as it).
	var fl := PointLight2D.new()
	fl.texture = LightTex
	fl.position = pos
	fl.color = color
	fl.energy = energy
	fl.texture_scale = scl
	fl.shadow_enabled = false
	fl.blend_mode = 0
	add_child(fl)
	return fl

func _add_wall_torch(pos: Vector2, wall_body: Node = null, occ: LightOccluder2D = null) -> void:
	# Candelabra-style lighting: the lit area is "whatever can SEE the front-middle of
	# this brick". So the shadow-casting light sits just in FRONT of the wall face (on
	# the room side) with ALL occluders — including this brick's own — left ON. The wall
	# behind blocks backward/through-wall bleed; neighbouring walls carve the natural
	# diagonal pools. (Previously the light was shoved UP into the brick and this cell's
	# occluder disabled to dodge self-shadow — which is exactly what leaked light through
	# the wall on corner pieces.)
	var lamp := PointLight2D.new()
	lamp.texture = LightTex
	# Just past the brick's front (room-facing) edge — its middle-front point.
	lamp.position = pos + Vector2(0, tile * 0.12)
	lamp.color = Color(1.0, 0.64, 0.30)
	lamp.energy = 0.94
	lamp.texture_scale = 2.6     # double the wall-torch light range (was 1.3)
	lamp.shadow_enabled = true   # other walls still block it laterally
	lamp.shadow_filter = 1
	lamp.add_to_group("venue_light")   # doused during a RUSH
	add_child(lamp)
	# Shadowless CORE glow pinned to the flame so the candle ALWAYS reads as a lit
	# source — without this the neighbouring wall occluders carve the shadowed lamp
	# into a narrow downward wedge ("only the bottom of the brick glows").
	var core := PointLight2D.new()
	core.texture = LightTex
	core.position = pos - Vector2(0, tile * 0.22)
	core.color = Color(1.0, 0.72, 0.38)
	core.energy = 0.85
	core.texture_scale = (tile * 0.95) / float(LightTex.get_width())
	core.shadow_enabled = false
	core.add_to_group("venue_light")   # doused during a RUSH
	add_child(core)
	# real wall-torch sprite (bracket + flame), bottom anchored to the wall edge
	var torch := Sprite2D.new()
	torch.texture = WallTorchTex
	var ws: float = (tile * 0.7) / float(WallTorchTex.get_height())
	torch.scale = Vector2(ws, ws)
	torch.position = pos - Vector2(0, tile * 0.18)
	torch.z_index = 3
	torch.z_as_relative = false
	torch.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(torch)
	var ph: float = randf() * TAU
	_braziers.append({"node": lamp, "base": 0.94, "phase": ph})
	_braziers.append({"node": core, "base": 0.85, "phase": ph})

func _spawn_room_ambiance() -> void:
	# Each room gets its own colour mood — a big, dim, shadowless tint light that
	# washes the room and bleeds up through the fog. Adjacent rooms differ.
	var palette: Array[Color] = [
		Color(0.85, 0.25, 0.30),  # crimson
		Color(0.30, 0.45, 0.95),  # sapphire
		Color(0.30, 0.80, 0.45),  # emerald
		Color(0.72, 0.35, 0.95),  # violet
		Color(0.25, 0.80, 0.85),  # teal
		Color(0.95, 0.55, 0.25),  # amber
		Color(0.92, 0.35, 0.70),  # rose
	]
	var last: int = -1
	for room in _rooms:
		var idx: int = randi() % palette.size()
		if idx == last:
			idx = (idx + 1) % palette.size()
		last = idx
		var amb := PointLight2D.new()
		amb.texture = LightTex
		amb.position = _room_center_world(room)
		amb.color = palette[idx]
		amb.energy = 0.3
		var room_px: float = float(maxi(room.size.x, room.size.y)) * tile
		amb.texture_scale = (room_px * 1.1) / float(LightTex.get_width())
		amb.shadow_enabled = false
		add_child(amb)

func _pos_too_close(p: Vector2, others: Array, min_d: float) -> bool:
	for o in others:
		if p.distance_to(o) < min_d:
			return true
	return false

func _spawn_braziers() -> void:
	var placed: Array = []
	var min_d: float = tile * 6.0   # never two candles within 6 blocks of each other
	for _i in brazier_count:
		var pos := _random_floor_world(tile * 3.0)
		var tries: int = 0
		while tries < 24 and _pos_too_close(pos, placed, min_d):
			pos = _random_floor_world(tile * 3.0)
			tries += 1
		if _pos_too_close(pos, placed, min_d):
			continue   # couldn't find a spot ≥4 blocks from the rest — skip this one
		placed.append(pos)
		var lamp := PointLight2D.new()
		lamp.texture = LightTex
		lamp.position = pos
		lamp.color = Color(1.0, 0.62, 0.30)
		lamp.energy = 0.9           # candelabras a touch brighter/farther
		lamp.texture_scale = 3.5    # double the light range (was 1.75)
		lamp.shadow_enabled = true
		lamp.shadow_filter = 1          # PCF5 — cheaper than PCF13 (perf)
		lamp.shadow_filter_smooth = 3.0
		lamp.position = pos - Vector2(0, tile * 0.35)   # light at the flames
		lamp.add_to_group("venue_light")   # doused during a RUSH so the invert reads clean
		add_child(lamp)
		# (No indirect "fill" — it bled through walls. The candelabra light is now
		# shadow-cast only, so stone blocks it.)
		# real candelabra sprite (metal stand + 3 lit candles)
		var cand := Sprite2D.new()
		cand.texture = CandelabraTex
		var cs2: float = (tile * 1.4) / float(CandelabraTex.get_height())
		cand.scale = Vector2(cs2, cs2)
		cand.position = pos - Vector2(0, tile * 0.35)   # base sits on the floor cell
		cand.z_index = 3
		cand.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(cand)
		# NO self-occluder: the light sits at the flames (above the base), so an occluder
		# at the base threw a hugely divergent shadow wedge fanning across the floor (the
		# "candelabra cone" bug). The flame light still casts real shadows off WALLS — that
		# was always the point. For grounding, a flat contact shadow is painted under the
		# base instead (a decal that ignores lighting, so it can't diverge).
		var shadow := Polygon2D.new()
		var sr: float = tile * 0.34
		var pts := PackedVector2Array()
		for k in range(14):
			var a: float = TAU * float(k) / 14.0
			pts.append(Vector2(cos(a) * sr, sin(a) * sr * 0.42))
		shadow.polygon = pts
		shadow.color = Color(0, 0, 0, 0.28)
		shadow.position = pos + Vector2(0, tile * 0.30)   # pooled at the foot of the stand
		shadow.z_index = 2                                 # under the candelabra sprite (z=3)
		add_child(shadow)
		_braziers.append({"node": lamp, "base": 1.54, "phase": randf() * TAU})

func _spawn_stalagmites() -> void:
	# Cave dressing — non-colliding rock spires scattered across the floor.
	for _i in int(_rooms.size() * 3):
		var pos := _random_floor_world(0.0)
		var spr := Sprite2D.new()
		spr.texture = StalagmiteTex
		spr.position = pos
		spr.scale = Vector2(randf_range(0.6, 1.3), randf_range(0.7, 1.4))
		spr.modulate = Color(0.9, 0.88, 0.95)
		if randf() < 0.5:
			spr.flip_h = true
		add_child(spr)

# ── navigation (A* grid so enemies path AROUND walls, not through them) ───────
func _build_nav() -> void:
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, _fw, _fh)
	_astar.cell_size = Vector2(tile, tile)
	_astar.offset = Vector2(tile * 0.5, tile * 0.5)   # ids map to cell CENTRES in world
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.update()
	for y in _fh:
		for x in _fw:
			if _wall[y][x]:
				_astar.set_point_solid(Vector2i(x, y), true)

# World-space waypoint path from→to that routes around walls (empty if none).
func nav_path(from_world: Vector2, to_world: Vector2) -> PackedVector2Array:
	if _astar == null:
		return PackedVector2Array()
	var fc := Vector2i(clampi(int(from_world.x / tile), 0, _fw - 1), clampi(int(from_world.y / tile), 0, _fh - 1))
	var tc := Vector2i(clampi(int(to_world.x / tile), 0, _fw - 1), clampi(int(to_world.y / tile), 0, _fh - 1))
	if _astar.is_point_solid(fc):
		return PackedVector2Array()
	if _astar.is_point_solid(tc):
		# Target sits on a wall cell — retarget to a free orthogonal neighbour.
		var ok := false
		var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		for d in dirs:
			var nc: Vector2i = tc + d
			if _astar.is_in_boundsv(nc) and not _astar.is_point_solid(nc):
				tc = nc; ok = true; break
		if not ok:
			return PackedVector2Array()
	return _astar.get_point_path(fc, tc)

func _floor_run(x: int, y: int, dx: int, dy: int) -> int:
	# Count contiguous floor cells from (x,y) in direction (dx,dy), inclusive.
	var c: int = 0
	var cx: int = x
	var cy: int = y
	while cx >= 0 and cx < _fw and cy >= 0 and cy < _fh and not _wall[cy][cx]:
		c += 1
		cx += dx
		cy += dy
	return c

func _spawn_traps() -> void:
	# Place trap gauntlets AT CHOKE POINTS — corridor cells (narrow passages you'd
	# naturally route through) — but only a spaced subset, not every one. Each is a
	# ripple line of 3 along the corridor, so you time a dash through.
	var chokes: Array = []
	for y in range(1, _fh - 1):
		for x in range(1, _fw - 1):
			if _wall[y][x]:
				continue
			if _start_room.has_point(Vector2i(x, y)):
				continue
			# Floor-run width in each axis: a corridor is narrow in one axis and
			# long in the other (rooms are wide in both).
			var h: int = _floor_run(x, y, -1, 0) + _floor_run(x, y, 1, 0) - 1
			var v: int = _floor_run(x, y, 0, -1) + _floor_run(x, y, 0, 1) - 1
			var narrow: int = mini(h, v)
			var lng: int = maxi(h, v)
			if narrow <= 3 and lng >= narrow + 2:
				chokes.append({"x": x, "y": y, "h": h <= v})   # span the NARROW axis
	chokes.shuffle()
	var placed: Array[Vector2i] = []
	var made: int = 0
	for ch in chokes:
		if made >= trap_count:
			break
		var cell := Vector2i(int(ch["x"]), int(ch["y"]))
		var near: bool = false
		for p in placed:
			if absi(p.x - cell.x) + absi(p.y - cell.y) < 10:   # spacing → not every choke
				near = true
				break
		if near:
			continue
		# Build the full span ACROSS the passage (the narrow axis), wall to wall.
		var pdx: int = 1 if bool(ch["h"]) else 0
		var pdy: int = 0 if bool(ch["h"]) else 1
		var cells: Array[Vector2i] = [cell]
		var k: int = 1
		while true:
			var nx: int = cell.x + pdx * k
			var ny: int = cell.y + pdy * k
			if nx < 0 or nx >= _fw or ny < 0 or ny >= _fh or _wall[ny][nx]:
				break
			cells.append(Vector2i(nx, ny)); k += 1
		k = 1
		while true:
			var nx2: int = cell.x - pdx * k
			var ny2: int = cell.y - pdy * k
			if nx2 < 0 or nx2 >= _fw or ny2 < 0 or ny2 >= _fh or _wall[ny2][nx2]:
				break
			cells.insert(0, Vector2i(nx2, ny2)); k += 1
		placed.append(cell)
		made += 1
		var n: int = cells.size()
		for j in n:
			var tc: Vector2i = cells[j]
			var trap := DungeonTrapScene.instantiate()
			trap.position = Vector2((tc.x + 0.5) * tile, (tc.y + 0.5) * tile)
			trap.set("tile", tile)
			trap.set("phase_offset", float(j) * (2.8 / float(maxi(1, n))))   # ripple across
			add_child(trap)
	# Fallback: if the map had too few corridors, scatter a few random lines.
	if made == 0:
		for _i in mini(3, trap_count):
			var pos := _random_floor_world(tile * 3.0, true)
			var trap := DungeonTrapScene.instantiate()
			trap.position = Vector2((int(pos.x / tile) + 0.5) * tile, (int(pos.y / tile) + 0.5) * tile)
			trap.set("tile", tile)
			add_child(trap)

func _cell_in_room(r: Rect2i) -> Vector2:
	var x: int = randi_range(r.position.x, r.position.x + r.size.x - 1)
	var y: int = randi_range(r.position.y, r.position.y + r.size.y - 1)
	return Vector2((x + 0.5) * tile, (y + 0.5) * tile)

# ── Vampire-Survivors-style timed wave director ─────────────────────────────
# Enemy types ordered EASIEST → HARDEST. They unlock over time: the floor opens
# with only the first couple, then a new type joins the spawn pool every ~38s.
# Deeper floors start further along the schedule (more variety up front).
const WAVE_UNLOCKS: Array = [
	SkeletonScene,        # 0  skeleton — the gentle melee intro
	EnemyScene,           # 1  KK bear — opens the floor alongside the skeletons; fire RATE scales by depth
	SealScene,            # 2  Long Bear — blocker, doesn't even attack
	DucklingScene,        # 3  weak fast swarmer
	PaleBearScene,        # 4  white plush — fast, weak swarmer
	CreamBearScene,       # 5  basic melee critter
	YarnBearScene,        # 6  tangled-in-yarn melee chaser
	BeanieBearScene,      # 7  lobs slow beanies
	HoundScene,           # 8  pounce
	GunBearScene,         # 9  burst rifle
	GrowlerScene,         # 10 archer
	FrostCubScene,        # 11 freeze orb
	TeddyBearScene,       # 12 suicide bomber
	ShrinkwrapBearScene,  # 13 air puff
	PotBearScene,         # 14 pressure-cooker bear — slow, tanky bruiser
	SwordSkeletonScene,   # 15 sword skeleton — melee bruiser on deeper floors
	PlushBrawlerScene,    # 16 charger
]
const WAVE_UNLOCK_INTERVAL: float = 60.0   # a new enemy type joins every minute
const WAVE_NAMES: Dictionary = {
	"skeleton": "SKELETON", "sword_skeleton": "SWORD SKELETON", "seal": "LONG BEAR", "duckling": "DUCKLING",
	"cream_bear": "CREAM BEAR", "pale_bear": "PALE BEAR", "yarn_bear": "YARN BEAR",
	"pot_bear": "PRESSURE BEAR", "beanie_bear": "BEANIE BEAR", "hound": "HOUND",
	"gun_bear": "GUN BEAR", "growler": "ARCHER", "frost_cub": "FROST CUB",
	"teddy_bear": "TEDDY BEAR", "shrinkwrap_bear": "SHRINKWRAP", "enemy": "KK BEAR",
	"kk_pup": "KK PUP",
	"plush_brawler": "BRAWLER",
}

var _wave_t: float = 0.0
var _wave_spawn_t: float = 0.0
var _wave_started: bool = false
var _wave_last_unlocked: int = 0
var _event_t: float = 35.0   # countdown to the FIRST themed RUSH event
var _cluster_t: float = 22.0 # countdown to the next tight same-type CLUSTER charge
const RUSH_DURATION: float = 15.0      # a RUSH lasts this long (screen inverted the whole time)
var _rush_active_t: float = 0.0        # >0 while a rush is ongoing
var _rush_spawn_t: float = 0.0         # cadence for sustained rush spawns
var _rush_scene: PackedScene = null    # the one enemy type pouring in this rush
var _mm_redraw_t: float = 0.0   # minimap redraw throttle
var _last_fog_cell: Vector2i = Vector2i(-99999, -99999)   # only re-reveal fog on cell change
var _stats_sample_t: float = 0.0   # analytics alive-count sampler
var _minimap_on: bool = true    # M toggles it (FPS A/B test)
var _hud_time_tl: Label = null
var _hud_time_total: Label = null   # total run time (all floors)
var _hud_fps: Label = null
var _fps_t: float = 0.0
var _hud_time_br: Label = null

func _spawn_enemies() -> void:
	# Floor opens with a SMALL batch of only the easiest unlocked types; the wave
	# director (in _process) keeps the pressure ramping from there.
	_wave_started = true
	_wave_t = 0.0
	_wave_spawn_t = 3.0
	_wave_last_unlocked = _wave_unlocked_count()
	var seed_n: int = int(_wave_alive_cap() * 0.35)   # opening is sparse
	for i in seed_n:
		_spawn_one(_wave_pick_scene(), _random_floor_world(tile * 5.0, true))

func _wave_tick(delta: float) -> void:
	if not _wave_started or _cleared:
		return
	_wave_t += delta
	var ts: String = "%d:%02d" % [int(_wave_t) / 60, int(_wave_t) % 60]
	if _hud_time_tl != null:
		_hud_time_tl.text = ts
	if _hud_time_br != null:
		_hud_time_br.text = ts
	# A new enemy type joins the fray silently — no name pop-up.
	var unlocked: int = _wave_unlocked_count()
	if unlocked > _wave_last_unlocked:
		_wave_last_unlocked = unlocked
	_wave_spawn_t -= delta
	if _wave_spawn_t <= 0.0:
		_wave_spawn_t = _wave_interval()
		_wave_spawn_batch()
	# Analytics: sample how many enemies are alive (~1 Hz).
	_stats_sample_t -= delta
	if _stats_sample_t <= 0.0:
		_stats_sample_t = 1.0
		Stats.sample_alive(get_tree().get_nodes_in_group("enemies").size())
	# Themed RUSH events — once the floor has ramped, every ~minute a horde of ONE
	# enemy type pours in around you (a wall of teddy bombers, a swarm of long
	# bears, etc.). The fun chaos beat.
	# No rush while a boss fight is live — the boss is enough chaos on its own.
	var boss_fight: bool = _boss_alerted and not _boss_dead
	if _wave_t > 15.0 and _rush_active_t <= 0.0 and not boss_fight:
		_event_t -= delta
		if _event_t <= 0.0:
			_event_t = randf_range(70.0, 105.0)   # ~1 rush every 1.5 min (was way too frequent)
			_trigger_rush_event()
	# Active RUSH window: lights stay doused and one enemy type keeps pouring in for
	# ~15s, then the lights come back. Pure timer — no "kill them all" gate.
	if _rush_active_t > 0.0:
		_rush_active_t -= delta
		_rush_spawn_t -= delta
		if _rush_spawn_t <= 0.0:
			_rush_spawn_t = 1.2
			_rush_spawn_wave()
		if _rush_active_t <= 0.0:
			_end_rush()
	# Small CLUSTER charges — a tight triplet/quad of ONE enemy type rushes in as a
	# clump. More frequent + smaller than a RUSH; a fun little "oh shit" pulse.
	if _wave_t > 18.0:
		_cluster_t -= delta
		if _cluster_t <= 0.0:
			_cluster_t = randf_range(16.0, 30.0)
			_spawn_cluster()

func _trigger_rush_event() -> void:
	if not is_instance_valid(_player):
		return
	_rush_scene = _wave_pick_scene()
	_rush_active_t = RUSH_DURATION
	_rush_spawn_t = 0.0
	var fn: String = _rush_scene.resource_path.get_file().get_basename()
	var nm: String = WAVE_NAMES.get(fn, fn.to_upper())
	_flash_event("%s  RUSH!" % nm, Color(1.0, 0.55, 0.2))
	Juice.shake(0.35)
	_start_rush_fx()
	# Opening ring so they converge from all sides immediately.
	var n: int = clampi(int(round(7.0 * _wave_power())), 6, 13)
	for i in n:
		var pos: Vector2 = floor_point_near(_player.global_position, 460.0, 880.0)
		_spawn_one(_rush_scene, pos)

func _rush_spawn_wave() -> void:
	# Sustained trickle of the rush enemy for the duration. Allows a bit over the
	# normal cap so it feels like a real flood, but still bounded.
	if _rush_scene == null or not is_instance_valid(_player):
		return
	var alive: int = get_tree().get_nodes_in_group("enemies").size()
	var cap: int = int(round(float(_wave_alive_cap()) * 1.3))
	if alive >= cap:
		return
	var n: int = mini(4, cap - alive)
	for i in n:
		var pos: Vector2 = floor_point_near(_player.global_position, 440.0, 900.0)
		_spawn_one(_rush_scene, pos)

func _set_venue_lights(on: bool) -> void:
	# Candelabras + wall torches off during a rush — their warm glow fights the
	# colour-invert and muddies it. Player torch + ambient stay on so you can see.
	for l in get_tree().get_nodes_in_group("venue_light"):
		if l is PointLight2D:
			(l as PointLight2D).enabled = on

func _start_rush_fx() -> void:
	# Rush signature: the candelabras + wall torches die out (player torch + ambient
	# stay), so the floor goes tense and dim while the horde pours in. (The old
	# full-screen colour invert was removed — it mangled the HUD and explosions.)
	_set_venue_lights(false)

func _end_rush() -> void:
	_rush_scene = null
	_set_venue_lights(true)   # relight the candelabras + wall torches

func _spawn_cluster() -> void:
	# A tight clump of 3-4 of the SAME enemy type, dropped together near the player
	# so they converge as one little pack. Respects the alive cap so it never piles on
	# top of an already-full room.
	if not is_instance_valid(_player):
		return
	var alive: int = get_tree().get_nodes_in_group("enemies").size()
	var n: int = 3 if randf() < 0.55 else 4
	if alive + n > _wave_alive_cap():
		return
	var scene: PackedScene = _wave_pick_scene()
	var center: Vector2 = floor_point_near(_player.global_position, 420.0, 780.0)
	Juice.shake(0.18)
	for i in n:
		var off: Vector2 = Vector2.from_angle(randf() * TAU) * randf_range(8.0, 46.0)
		var pos: Vector2 = floor_point_near(center + off, 0.0, 90.0)
		_spawn_one(scene, pos)

func _flash_event(text: String, color: Color) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 76)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 7)
	var lf := FontFile.new()
	if lf.load_dynamic_font("res://assets/anton.ttf") == OK:
		lbl.add_theme_font_override("font", lf)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.anchor_left = 0.0; lbl.anchor_right = 1.0
	lbl.offset_top = 200.0
	lbl.modulate.a = 0.0
	layer.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, 0.12)
	tw.tween_property(lbl, "modulate:a", 0.2, 0.14)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.12)
	tw.tween_interval(1.0)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(layer.queue_free)
	lbl.scale = Vector2(1.3, 1.3)
	lbl.create_tween().tween_property(lbl, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _wave_unlocked_count() -> int:
	var base: int = 2 + (ArpgState.depth - 1) * 2   # floor 1: BOTH skeleton types open the floor
	return clampi(base + int(_wave_t / WAVE_UNLOCK_INTERVAL), 1, WAVE_UNLOCKS.size())

func _wave_pick_scene() -> PackedScene:
	var n: int = _wave_unlocked_count()
	# Bias toward the newest (hardest) unlocks so the threat actually escalates,
	# but keep the easy types in rotation for variety.
	if n > 3 and randf() < 0.55:
		return WAVE_UNLOCKS[randi_range(maxi(0, n - 3), n - 1)]
	return WAVE_UNLOCKS[randi() % n]

# How overpowered the player is for this depth (1.0 = fair). Drives the swarm
# size so a nuke build gets BURIED in mobs instead of walking empty rooms — you
# feel strong, but you never stop fighting.
func _wave_power() -> float:
	# Much gentler scaling — the +100% version was a death wall (dead in <2 min).
	# AND ramp it in over the first ~100s so the opening minute is always calm
	# (just a few of the easiest type) even when you're over-levelled for the floor.
	var p: float = clampf(ArpgState.challenge_ratio(), 1.0, 1.8)
	var ramp: float = clampf(_wave_t / 100.0, 0.0, 1.0)
	return 1.0 + (p - 1.0) * ramp

func _wave_alive_cap() -> int:
	var base: int = 18
	match GameSettings.difficulty:
		0: base = 12   # EASY
		2: base = 26   # HARD
	var grown: int = base + int(_wave_t / 22.0) * 3
	var amt: float = float(grown) * _wave_power()
	var ceil_cap: int = 55
	if GameSettings.ascension >= 1:
		amt *= 1.5        # Asc 1 FLOODED FLOORS curse: +50% enemies per floor
		ceil_cap = 72
	return mini(int(round(amt)), ceil_cap)

func _wave_interval() -> float:
	return maxf(0.85, (3.4 - _wave_t / 90.0) / _wave_power())

func _wave_batch_size() -> int:
	return maxi(2, int(round((2.0 + _wave_t / 55.0) * _wave_power())))

func _wave_spawn_batch() -> void:
	var alive: int = get_tree().get_nodes_in_group("enemies").size()
	var cap: int = _wave_alive_cap()
	if alive >= cap:
		return
	var n: int = mini(_wave_batch_size(), cap - alive)
	for i in n:
		var pos: Vector2 = _random_floor_world(0.0, true)
		# Don't pop in right on top of the player.
		if is_instance_valid(_player) and pos.distance_to(_player.position) < tile * 6.0:
			pos = _random_floor_world(0.0, true)
		_spawn_one(_wave_pick_scene(), pos)

func _spawn_one(scene: PackedScene, pos: Vector2) -> void:
	var e := scene.instantiate()
	e.position = pos
	var t: String = scene.resource_path.get_file().get_basename()
	e.set("mob_type", t)        # so kills can be attributed by type
	Stats.mob_spawned(t)
	add_child(e)
	_configure_enemy(e)

func _configure_enemy(e: Node) -> void:
	# Scale HP AFTER add_child: subtypes set their base max_health in their OWN
	# _ready, which would overwrite a value set before. Read the final base, scale.
	if "max_health" in e:
		var base_hp: int = int(e.max_health)
		var diff: float = _difficulty_hp_mult()
		# Power scaling now tracks how over-powered you are much more aggressively: the
		# old sqrt() flattened a 3.5x challenge_ratio down to ~1.87x, so a nuke build
		# still one-shot everything. Use the ratio almost directly (pow 0.85) so spongy
		# enemies actually keep pace with a runaway build.
		var hp_power_mult: float = pow(ArpgState.challenge_ratio(), 0.85)
		e.max_health = int(round(float(base_hp) * 7.0 * diff * hp_power_mult)) + 3 + int(ArpgState.depth - 1) * 5
		e.set("health", e.max_health)
		# Contact damage ramps faster (+1 every 2 floors, was every 3) so face-tanking
		# deep floors actually costs you.
		if "touch_damage" in e:
			e.touch_damage = int(e.touch_damage) + int((ArpgState.depth - 1) / 2)

func _apply_brightness(level: int, announce: bool = true) -> void:
	# Overall darkness preset (1=dark/moody, 2=medium, 3=bright). Lifts the global
	# ambient floor + the player aura together. Persists across floors via ArpgState.
	level = clampi(level, 1, 3)
	ArpgState.brightness_level = level
	if _flat_lit():
		return   # flat-lit themes keep their bright ambient; brightness preset doesn't apply
	# Lifted the darkest preset so floors/walls read instead of sinking into murk
	# (the "everything's too dark and muddy" complaint) while staying moody.
	var amb: Color = [Color(0.21, 0.20, 0.26), Color(0.31, 0.29, 0.36), Color(0.42, 0.40, 0.47)][level - 1]
	if theme == "damp":
		amb = amb * 1.15   # +15% global light for the damp dungeon (user request)
	var energy: float = [0.8, 1.05, 1.3][level - 1]
	if _ambient != null:
		_ambient.color = amb
	if is_instance_valid(_player):
		var torch := _player.get_node_or_null("BearLight") as PointLight2D
		if torch != null:
			torch.energy = energy
	if announce:
		_on_toast("BRIGHTNESS %d" % level, Color(1.0, 0.92, 0.6))

func _difficulty_hp_mult() -> float:
	# Easy/Medium/Hard now actually affect the dungeon's enemy toughness.
	match GameSettings.difficulty:
		0: return 0.5    # EASY — toned down (was 0.7)
		2: return 1.35   # HARD
		_: return 1.0    # MEDIUM

func _load_props(cats: Array) -> Array:
	var texs: Array[Texture2D] = []
	for cat in cats:
		for entry in _load_named(String(cat)):
			texs.append(entry["tex"])
	return texs

# Returns [{name, tex}] for a category so scenes can pick by sprite role
# (chair_* / desk_* / locker / shelf / cabinet …).
func _load_named(cat: String) -> Array:
	# Export-safe: DirAccess lists "x.png.import" in packed builds, so strip the
	# suffix and dedupe (the editor lists both the png and its sidecar).
	var out: Array = []
	var dirp: String = "res://assets/backrooms/props/%s/" % cat
	var da := DirAccess.open(dirp)
	if da == null:
		return out
	var seen := {}
	for fn in da.get_files():
		var clean: String = fn
		if clean.ends_with(".import") or clean.ends_with(".remap"):
			clean = clean.get_basename()
		if not clean.to_lower().ends_with(".png") or seen.has(clean):
			continue
		seen[clean] = true
		var t := _load_tex_mip(dirp + clean)   # robust loader (falls back to load())
		if t != null:
			out.append({"name": clean.get_basename(), "tex": t})
	return out

func _corner_spot(room: Rect2i) -> Dictionary:
	# A room corner cell + the diagonal direction toward the wall corner, so
	# furniture tucks into corners the way real furniture sits.
	var x0: int = room.position.x
	var y0: int = room.position.y
	var x1: int = room.position.x + room.size.x - 1
	var y1: int = room.position.y + room.size.y - 1
	var x: int
	var y: int
	var toward: Vector2
	match randi() % 4:
		0: x = x0; y = y0; toward = Vector2(-1, -1)
		1: x = x1; y = y0; toward = Vector2(1, -1)
		2: x = x0; y = y1; toward = Vector2(-1, 1)
		_: x = x1; y = y1; toward = Vector2(1, 1)
	return {"pos": Vector2((x + 0.5) * tile, (y + 0.5) * tile), "toward": toward.normalized()}

func _perimeter_spot(room: Rect2i) -> Dictionary:
	# A random cell on the room's edge + the outward direction toward its wall, so
	# furniture lines up AGAINST the walls instead of floating in the open.
	var x: int
	var y: int
	var toward: Vector2
	match randi() % 4:
		0: x = randi_range(room.position.x, room.position.x + room.size.x - 1); y = room.position.y; toward = Vector2(0, -1)
		1: x = randi_range(room.position.x, room.position.x + room.size.x - 1); y = room.position.y + room.size.y - 1; toward = Vector2(0, 1)
		2: x = room.position.x; y = randi_range(room.position.y, room.position.y + room.size.y - 1); toward = Vector2(-1, 0)
		_: x = room.position.x + room.size.x - 1; y = randi_range(room.position.y, room.position.y + room.size.y - 1); toward = Vector2(1, 0)
	return {"pos": Vector2((x + 0.5) * tile, (y + 0.5) * tile), "toward": toward}

func _place_prop(tex: Texture2D, pos: Vector2, z: int, frac: float, flip_h: int = -1, rot: float = 0.0, sink: float = 0.0) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = tex
	var longest: float = float(maxi(tex.get_width(), tex.get_height()))
	spr.scale = Vector2.ONE * ((tile * frac) / maxf(1.0, longest))
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# "sink": crop off the bottom fraction so the piece reads as clipped into the
	# floor (half a chair poking out of the carpet — backrooms wrongness).
	if sink > 0.0:
		var w: float = float(tex.get_width())
		var h: float = float(tex.get_height())
		spr.region_enabled = true
		spr.region_rect = Rect2(0, 0, w, h * (1.0 - clampf(sink, 0.0, 0.9)))
	spr.position = pos
	spr.flip_h = (randf() < 0.5) if flip_h < 0 else (flip_h == 1)
	spr.rotation = rot
	spr.z_index = z
	add_child(spr)
	return spr

func _room_center(room: Rect2i) -> Vector2:
	return Vector2((float(room.position.x) + float(room.size.x) * 0.5) * tile,
		(float(room.position.y) + float(room.size.y) * 0.5) * tile)

func _spawn_props() -> void:
	# Backrooms furniture SCENES, not scattered trash: most rooms stay empty and
	# eerie; a minority get an arranged vignette — a ring of chairs, a desk with a
	# chair pulled up, a wall cluster — plus the occasional surreal piece clipping
	# into a wall. Decorative only, no collision.
	var furn: Array = _load_named("furniture")
	if furn.is_empty():
		return
	var chairs: Array = []
	var desks: Array = []
	var big: Array = []                 # locker / shelf / cabinet — go against walls
	for e in furn:
		var n: String = String(e["name"])
		if n.begins_with("chair"):
			chairs.append(e["tex"])
		elif n.begins_with("desk"):
			desks.append(e["tex"])
		else:
			big.append(e["tex"])
	var cont: Array = _load_props(["containers"])
	for room in _rooms:
		if room == _start_room or room == _boss_room:
			continue
		var roll: float = randf()
		var roomy: bool = room.size.x >= 5 and room.size.y >= 5
		if roll < 0.48:
			continue                                  # most rooms empty
		elif roll < 0.66 and roomy and not chairs.is_empty():
			_scene_chairs(room, chairs)
		elif roll < 0.84 and not desks.is_empty():
			_scene_desk(room, desks, chairs)
		elif not big.is_empty():
			_scene_wall_cluster(room, big, chairs, cont)
		elif not desks.is_empty():
			_scene_desk(room, desks, chairs)
	# A few surreal pieces half-buried in a wall (classic backrooms wrongness).
	var clip_pool: Array = chairs + desks
	if not clip_pool.is_empty():
		for _i in randi_range(2, 4):
			_scene_clipped(_rooms[randi() % _rooms.size()], clip_pool)
	_spawn_lamps()

func _spawn_lamps() -> void:
	# Standing lanterns set against room walls, each casting a warm pool of light —
	# adds atmosphere and breaks up the flat overhead grid.
	var lamps: Array = _load_props(["lamps"])
	if lamps.is_empty():
		return
	for room in _rooms:
		if room == _start_room:
			continue
		if randf() > 0.3:                 # ~30% of rooms get a lamp
			continue
		var spot: Dictionary = _perimeter_spot(room)
		var toward: Vector2 = spot["toward"]
		var pos: Vector2 = spot["pos"] + toward * (tile * 0.18)   # tucked to the wall
		_place_prop(lamps[randi() % lamps.size()], pos, 3, 1.6, 0)
		var glow := PointLight2D.new()
		glow.texture = LightTex
		glow.position = pos - Vector2(0, tile * 0.35)             # at the lantern head
		glow.color = Color(1.0, 0.82, 0.48)
		glow.energy = 0.85
		glow.texture_scale = (tile * 3.0) / float(LightTex.get_width())
		glow.shadow_enabled = false
		add_child(glow)

func _scene_chairs(room: Rect2i, chairs: Array) -> void:
	# A CLUSTER of 3–10 chairs grouped together in the room, each at its own random
	# orientation (toppled / facing any way), some half-sunk into the floor. Always
	# huddled around a shared centre so they read as a deliberate pile, not scatter.
	var c: Vector2 = _room_center(room)
	# Nudge the cluster centre somewhere inside the room (not dead-centre every time).
	var jitter: float = float(mini(room.size.x, room.size.y)) * tile * 0.18
	c += Vector2(randf_range(-jitter, jitter), randf_range(-jitter, jitter))
	var room_px: float = float(mini(room.size.x, room.size.y)) * tile
	var spread: float = clampf(room_px * 0.30, tile * 0.8, tile * 2.6)
	var n: int = randi_range(3, 10)
	# Sometimes a tidy ring, sometimes a loose huddle.
	var ring: bool = randf() < 0.45
	var a0: float = randf() * TAU
	for i in n:
		var tex: Texture2D = chairs[randi() % chairs.size()]
		var pos: Vector2
		if ring:
			var ang: float = a0 + TAU * float(i) / float(n)
			pos = c + Vector2(cos(ang), sin(ang)) * spread + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		else:
			pos = c + Vector2(randf_range(-spread, spread), randf_range(-spread, spread))
		var rot: float = (atan2(c.y - pos.y, c.x - pos.x) + PI * 0.5) if ring else randf_range(-PI, PI)
		var sink: float = randf_range(0.35, 0.7) if randf() < 0.22 else 0.0   # ~1/5 sunk
		_place_prop(tex, pos, 1, randf_range(0.58, 0.72), -1, rot, sink)

func _scene_desk(room: Rect2i, desks: Array, chairs: Array) -> void:
	# A desk flush against a wall with a chair pulled up on the room side.
	var spot: Dictionary = _perimeter_spot(room)
	var toward: Vector2 = spot["toward"]            # points outward to the wall
	var dpos: Vector2 = spot["pos"] + toward * (tile * 0.12)
	_place_prop(desks[randi() % desks.size()], dpos, 1, 1.05)
	if not chairs.is_empty() and randf() < 0.8:
		var cpos: Vector2 = dpos - toward * (tile * 0.62)
		_place_prop(chairs[randi() % chairs.size()], cpos, 2, 0.62)

func _scene_wall_cluster(room: Rect2i, big: Array, chairs: Array, cont: Array) -> void:
	# A tall piece (locker/shelf/cabinet) against a wall, maybe a barrel or chair
	# tucked beside it.
	var spot: Dictionary = _corner_spot(room)
	var toward: Vector2 = spot["toward"]
	var fpos: Vector2 = spot["pos"] + toward * (tile * 0.1)
	_place_prop(big[randi() % big.size()], fpos, 1, 1.0)
	var side: Vector2 = Vector2(-toward.y, toward.x).normalized()
	if not cont.is_empty() and randf() < 0.5:
		_place_prop(cont[randi() % cont.size()], fpos + side * (tile * 0.7), 1, 0.8)
	elif not chairs.is_empty() and randf() < 0.5:
		_place_prop(chairs[randi() % chairs.size()], fpos - side * (tile * 0.7), 2, 0.6)

func _scene_clipped(room: Rect2i, pool: Array) -> void:
	# One piece shoved halfway into a wall at an odd angle — sits BEHIND the wall
	# (low z) so it reads as clipping through it. Backrooms surreal touch.
	var spot: Dictionary = _perimeter_spot(room)
	var toward: Vector2 = spot["toward"]
	var pos: Vector2 = spot["pos"] + toward * (tile * 0.55)   # pushed into the wall
	_place_prop(pool[randi() % pool.size()], pos, -2, 0.85, -1, randf_range(-0.5, 0.5))

func _spawn_items() -> void:
	for _i in item_count:
		var pos := _random_floor_world(tile * 3.0)
		var area := Area2D.new()
		area.position = pos
		area.collision_mask = 1
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 30.0
		cs.shape = c
		area.add_child(cs)
		if not _flat_lit():   # flat-lit levels (hand / cyber2077): no pickup aura
			var lamp := PointLight2D.new()
			lamp.texture = LightTex
			lamp.color = Color(1.0, 0.55, 0.55)   # warm red glow = health pickup
			lamp.energy = 0.9
			lamp.texture_scale = 0.9
			area.add_child(lamp)
		# Heal-heart icon instead of a diamond — reads as a health pickup.
		var heart := Sprite2D.new()
		heart.texture = HealIconTex
		heart.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		heart.scale = Vector2(0.5, 0.5)
		area.add_child(heart)
		var hbob := heart.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		hbob.tween_property(heart, "position", Vector2(0, -6), 0.85)
		hbob.tween_property(heart, "position", Vector2(0, 0), 0.85)
		_items.append(pos)
		area.body_entered.connect(func(b: Node) -> void:
			if b.is_in_group("player"):
				_on_item(area, pos))
		add_child(area)

# ── runtime ────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	# Total run timer ticks continuously (not gated by the wave start, so it shows
	# carried-over time the instant a new floor loads).
	if _hud_time_total != null:
		var rt: int = int(ArpgState.run_time)
		_hud_time_total.text = "Σ %d:%02d" % [rt / 60, rt % 60]
	_update_perf_overlay(delta)
	_log_hitch_if_any(delta)
	if get_tree().paused:
		return   # stats screen / popups paused us — don't run gameplay or waves
	_wave_tick(delta)
	if is_instance_valid(_player):
		_camera.position = _player.position
		if _fog_mat != null:
			_fog_mat.set_shader_parameter("cam_pos", _camera.position)
		# Fog reveal is EVENT-DRIVEN: only repaint the 7x7 block when the player crosses into
		# a new cell, instead of rebuilding 49 string keys every single frame (alloc churn /
		# GC stutter). Standing still or sliding within a cell costs nothing now.
		var f := world_to_fine(_player.position)
		var fcell := Vector2i(int(f.x), int(f.y))
		# CHUNKED reveal: only when the player moves a few cells away from the last reveal
		# point do we light up a big block around them — then nothing until they reach its
		# edge. Way fewer updates than re-revealing every step.
		if Vector2(fcell - _last_fog_cell).length() >= 4.0:
			_last_fog_cell = fcell
			for dy in range(-6, 7):
				for dx in range(-6, 7):
					_explored["%d,%d" % [fcell.x + dx, fcell.y + dy]] = true
	for b in _braziers:
		var lamp: PointLight2D = b["node"]
		if is_instance_valid(lamp):
			# Slow, calm candle pulse. (Was 9.0 rad/s + a per-FRAME randf jitter, which
			# read as fast strobing — dropped the jitter and slowed the pulse ~80%.)
			b["phase"] += delta * 1.8
			lamp.energy = b["base"] * (0.90 + 0.10 * sin(b["phase"]))
	# Boss encounter: alert + reveal health bar when the player gets close.
	if not _boss_alerted and not _boss_dead and is_instance_valid(_boss) and is_instance_valid(_player):
		if _player.global_position.distance_to((_boss as Node2D).global_position) < 460.0:
			_boss_alerted = true
			Juice.shake(0.4)
			_flash_boss()
	# Boss health bar follows its current HP.
	if _hud_boss_root != null:
		var show_bar: bool = _boss_alerted and not _boss_dead and _boss_is_dead() == false
		_hud_boss_root.visible = show_bar
		if show_bar and is_instance_valid(_boss):
			var bhp: float = float(_boss.get("health"))
			_hud_boss_fill.size.x = 396.0 * clampf(bhp / float(max(1, _boss_max_hp)), 0.0, 1.0)
	# Boss death opens the descent (detected via group exit, not node free).
	if not _boss_dead and _boss != null and _boss_is_dead():
		_boss_dead = true
		if _exit_node != null:
			_exit_node.global_position = ((_boss as Node2D).global_position if floor_at_world((_boss as Node2D).global_position) else floor_point_near((_boss as Node2D).global_position, 0.0, tile * 2.5, false)); _exit_pos = _exit_node.global_position; _exit_node.visible = true
		if _hud_boss_root != null:
			_hud_boss_root.visible = false
		_on_toast("Guardian slain — the descent opens!", Color(1.0, 0.85, 0.45))
		# 10% chance: a BACKROOMS portal tears open where the guardian fell.
		if theme != "backrooms" and randf() < 0.10:
			_spawn_backrooms_portal((_boss as Node2D).global_position)
	# Minimap redraw is heavy (every cell + 8-neighbour fog lookups). Throttle it to
	# ~8 Hz instead of every frame — a big CPU win, imperceptible visually.
	_mm_redraw_t -= delta
	if _minimap and _minimap_on and _mm_redraw_t <= 0.0:
		_mm_redraw_t = 0.12
		_minimap.queue_redraw()
	if _hp_update.is_valid() and is_instance_valid(_player):
		_hp_update.call(float(_player.get("health")), float(_player.get("max_health")))
	_refresh_hud()

func _on_item(area: Area2D, pos: Vector2) -> void:
	if not is_instance_valid(area):
		return
	if is_instance_valid(_player) and _player.has_method("heal"):
		_player.heal(2)
	_items.erase(pos)
	Juice.shake(0.1)
	area.queue_free()

func _on_exit() -> void:
	if _cleared:
		return
	if not _boss_dead:
		return   # exit stays shut until the boss dies — no nag toast
	_cleared = true
	Engine.time_scale = 1.0   # never carry slow-mo into the next scene
	# Floor 10 is the finale — clearing its guardian WINS the run (and unlocks the
	# next ascension). Earlier floors just move on to the merchant.
	if ArpgState.depth >= FINAL_FLOOR:
		_win_game()
		return
	# Entered via a HUB door → clearing this room sends you back to the Hub for the next pick.
	if ArpgState.return_to_hub:
		ArpgState.return_to_hub = false
		get_tree().change_scene_to_file("res://scenes/hub.tscn")
		return
	ArpgState.descend()
	get_tree().change_scene_to_file("res://scenes/shop.tscn")

# ── floor-10 victory ─────────────────────────────────────────────────────────
const FINAL_FLOOR: int = 10
const FINAL_FLUFF_REWARD: int = 25
const FINAL_COTTON_REWARD: int = 50

func _win_game() -> void:
	Stats.note_floor(ArpgState.depth)
	Stats.end_run("won")
	var asc: int = GameSettings.ascension
	var mult: float = 1.0 + 0.2 * float(asc)
	var fluff_gain: int = int(round(float(FINAL_FLUFF_REWARD) * mult))
	var cotton_gain: int = int(round(float(FINAL_COTTON_REWARD) * mult))
	MetaSave.add_fluff(fluff_gain)
	MetaSave.add_cotton(cotton_gain)
	MetaSave.record_victory()
	# Beating the run at your current max ascension opens up the next one.
	if asc >= MetaSave.max_ascension and MetaSave.max_ascension < 5:
		MetaSave.unlock_ascension_up_to(MetaSave.max_ascension + 1)
	get_tree().paused = true
	var screen := preload("res://scenes/victory_screen.tscn").instantiate()
	screen.fluff_reward = fluff_gain
	screen.cotton_reward = cotton_gain
	screen.ascension_beaten = asc
	# Play again → back to the loadout so you can pick a (newly unlocked) ascension.
	screen.restart_requested.connect(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/loadout_screen.tscn"))
	screen.menu_requested.connect(func() -> void:
		get_tree().paused = false
		ArpgState.active = false
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn"))
	add_child(screen)

# ── Backrooms boss-portal (10% on boss death) ───────────────────────────────
func _spawn_backrooms_portal(pos: Vector2) -> void:
	# Land it on solid floor near where the boss died.
	var p: Vector2 = pos
	if floor_at_world(pos) == false:
		p = floor_point_near(pos, 0.0, 260.0)
	var area := Area2D.new()
	area.position = p
	area.collision_mask = 1
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new(); c.radius = 46.0
	cs.shape = c
	area.add_child(cs)
	var spr := Sprite2D.new()
	var t: Texture2D = _load_tex_mip("res://assets/portal_backrooms_b.png")
	if t != null:
		spr.texture = t
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	spr.scale = Vector2(0.62, 0.62)
	spr.z_index = 3
	area.add_child(spr)
	var glow := PointLight2D.new()
	glow.texture = LightTex
	glow.color = Color(1.0, 0.82, 0.4)   # warm backrooms spill
	glow.energy = 1.5
	glow.texture_scale = 1.5
	glow.position = Vector2(0, -10)
	area.add_child(glow)
	var stw := glow.create_tween().set_loops()
	stw.tween_property(glow, "energy", 2.0, 1.1).set_trans(Tween.TRANS_SINE)
	stw.tween_property(glow, "energy", 1.2, 1.1).set_trans(Tween.TRANS_SINE)
	var entered := [false]
	area.body_entered.connect(func(b: Node) -> void:
		if b.is_in_group("player") and not entered[0]:
			entered[0] = true
			_enter_backrooms_portal())
	add_child(area)
	_flash_event("A  PORTAL  OPENS…", Color(1.0, 0.8, 0.35))

func _enter_backrooms_portal() -> void:
	if _cleared:
		return
	_cleared = true
	Engine.time_scale = 1.0
	ArpgState.descend()
	ArpgState.backrooms_next = true            # next floor renders as backrooms
	# Authored descent: after the backrooms stage you spill into the POOL ROOMS, then
	# the FIELD OF WHEAT, before the run returns to the normal random biome rotation.
	ArpgState.scripted_queue = ["res://scenes/poolrooms.tscn", "res://scenes/wheat.tscn"]
	get_tree().change_scene_to_file(ArpgState.dungeon_path)   # skip the merchant — straight in

func floor_at_world(w: Vector2) -> bool:
	var cx: int = int(w.x / tile)
	var cy: int = int(w.y / tile)
	if cy < 0 or cy >= _wall.size() or cx < 0 or cx >= _wall[0].size():
		return false
	return not _wall[cy][cx]

# ── dev tools (opened from the pause menu) ──────────────────────────────────
func dev_heal() -> void:
	if is_instance_valid(_player) and _player.has_method("heal"):
		_player.heal(99999)

func dev_next_floor() -> void:
	get_tree().paused = false
	ArpgState.descend()
	get_tree().change_scene_to_file(ArpgState.dungeon_path)

func dev_add_gold() -> void:
	ArpgState.gold += 100
	ArpgState.emit_signal("stats_changed")

func dev_kill_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.has_method("take_damage"):
			e.take_damage(999999)

func dev_level_up() -> void:
	ArpgState.add_xp(ArpgState.xp_to_next)

func dev_random_weapon() -> void:
	ArpgState.weapon = ArpgState.roll_weapon()
	ArpgState.emit_signal("weapon_changed", ArpgState.weapon)
	ArpgState.emit_signal("stats_changed")

func dev_god_mode() -> void:
	DevState.invincible = not DevState.invincible

# ── death / game over ────────────────────────────────────────────────────────
func _on_player_died() -> void:
	Stats.note_floor(ArpgState.depth)
	Stats.end_run("died")
	# Let the death explosion + chunks play out, then show the game-over screen.
	# (Doubled the beat so the death animation lands before YOU DIED appears.)
	await get_tree().create_timer(3.4, true).timeout
	_show_game_over()

# Nosifer (dripping-blood) display font — PRELOADED so it's packed into the export.
# (The old runtime FontFile.load_dynamic_font() reads a res:// path that doesn't exist
# inside the exported PCK, so it silently fell back to the default font — the "old"
# plain YOU DIED players were still seeing on the biome levels.)
const DeathFont := preload("res://assets/nosifer.ttf")

func _show_game_over() -> void:
	if has_node("GameOverLayer"):
		return
	get_tree().paused = true
	var layer := CanvasLayer.new()
	layer.name = "GameOverLayer"
	layer.layer = 90
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	# World fades out behind a slowly-deepening black.
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.85, 1.4)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	center.add_child(vb)

	var title := Label.new()
	title.text = "YOU DIED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Real "Nosifer" dripping-blood display font (Google Fonts, OFL).
	title.add_theme_font_override("font", DeathFont)
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color(0.58, 0.05, 0.05))
	title.add_theme_color_override("font_outline_color", Color(0.06, 0.0, 0.0, 1.0))
	title.add_theme_constant_override("outline_size", 6)
	title.pivot_offset = Vector2(260, 60)
	title.modulate = Color(1, 1, 1, 0.0)
	vb.add_child(title)
	# Bleed in: fade up + settle down from a slightly larger scale.
	title.scale = Vector2(1.22, 1.22)
	var tt := title.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tt.tween_property(title, "modulate:a", 1.0, 1.2)
	tt.tween_property(title, "scale", Vector2.ONE, 1.4)

	var sub := Label.new()
	sub.text = "Reached Floor %d  ·  Level %d  ·  %d gold" % [ArpgState.depth, ArpgState.level, ArpgState.gold]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.82, 0.82, 0.88))
	sub.modulate = Color(1, 1, 1, 0.0)
	vb.add_child(sub)

	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 12)
	vb.add_child(pad)

	var retry := Button.new()
	retry.text = "↻   NEW RUN"
	retry.custom_minimum_size = Vector2(340, 56)
	retry.add_theme_font_size_override("font_size", 26)
	retry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	retry.modulate = Color(1, 1, 1, 0.0)
	retry.pressed.connect(_retry_run)
	vb.add_child(retry)

	var menu := Button.new()
	menu.text = "Main Menu"
	menu.custom_minimum_size = Vector2(340, 48)
	menu.add_theme_font_size_override("font_size", 20)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu.modulate = Color(1, 1, 1, 0.0)
	menu.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn"))
	vb.add_child(menu)

	# Buttons + subtitle fade in after the title has bled in.
	for n in [sub, retry, menu]:
		n.create_tween().tween_property(n, "modulate:a", 1.0, 0.6).set_delay(1.3)
	get_tree().create_timer(1.4, true).timeout.connect(func() -> void:
		if is_instance_valid(retry):
			retry.grab_focus())


func _retry_run() -> void:
	get_tree().paused = false
	ArpgState.reset_run()
	get_tree().change_scene_to_file(ArpgState.dungeon_path)

# ── dev: weapon testing ──────────────────────────────────────────────────────
func dev_set_weapon(idx: int) -> void:
	# Equip a specific archetype (fresh, Lv1) so you can test it directly.
	var arch: Array = ArpgState.ARCHETYPES
	if idx < 0 or idx >= arch.size():
		return
	ArpgState.weapon = ArpgState._build_weapon(arch[idx], 1, 0)
	ArpgState.emit_signal("weapon_changed", ArpgState.weapon)
	ArpgState.emit_signal("stats_changed")

func dev_upgrade_weapon(_id: String) -> void:
	# Free weapon level-up (any of the dev upgrade buttons just levels it).
	ArpgState.buy({"id": "w_level", "weapon_upgrade": true, "cost": 0})

func dev_weapon_summary() -> String:
	var w: Dictionary = ArpgState.weapon
	if w.is_empty():
		return "(no weapon)"
	var s: String = "%s  Lv%d\ndmg %d · cd %.2f · x%d" % [
		String(w.get("name", "?")), int(w.get("lvl", 0)),
		ArpgState.weapon_damage(), ArpgState.weapon_cooldown(), ArpgState.weapon_count()]
	var p: int = int(w.get("pierce", 0))
	if p > 0:
		s += " · pierce %d" % p
	if bool(w.get("ball", false)):
		s += " · bounce %d" % int(w.get("bounces", 0))
	return s

var _stats_layer: CanvasLayer = null

func _stat_line(parent: VBoxContainer, key: String, val: String, accent: Color = Color(1, 1, 1)) -> void:
	# Divider rows (dashes, empty value) → render a clean thin rule, not dash text.
	if val == "" and key.begins_with("─"):
		var rule := Panel.new()
		rule.custom_minimum_size = Vector2(0, 1)
		var rsb := StyleBoxFlat.new(); rsb.bg_color = Color(0.78, 0.64, 0.36, 0.28)
		rule.add_theme_stylebox_override("panel", rsb)
		var wrap := MarginContainer.new()
		wrap.add_theme_constant_override("margin_top", 5); wrap.add_theme_constant_override("margin_bottom", 5)
		wrap.add_child(rule)
		parent.add_child(wrap)
		return
	# Key (dim, fixed width) then value right beside it — not flung to opposite edges.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	var k := Label.new()
	k.text = key
	k.add_theme_font_size_override("font_size", 18)
	k.add_theme_color_override("font_color", Color(0.60, 0.64, 0.74))
	k.custom_minimum_size = Vector2(160, 0)
	row.add_child(k)
	var v := Label.new()
	v.text = val
	v.add_theme_font_size_override("font_size", 18)
	# One calm, readable value colour (the per-stat rainbow was the noise) — accent
	# is kept only as a faint tint so it's not a wall of identical text.
	v.add_theme_color_override("font_color", accent.lerp(Color(1.0, 0.97, 0.88), 0.78))
	row.add_child(v)

func _toggle_stats() -> void:
	if is_instance_valid(_stats_layer):
		_stats_layer.queue_free()
		_stats_layer = null
		get_tree().paused = false
		return
	# Full PAUSE while the character screen is open. The dungeon stays PAUSABLE so
	# gameplay (enemies/projectiles) actually freezes; an always-processing input
	# catcher on the overlay handles TAB/ESC to close it (the paused dungeon can't).
	get_tree().paused = true
	_stats_layer = CanvasLayer.new()
	_stats_layer.layer = 94
	_stats_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_stats_layer)
	var catcher := preload("res://scripts/stats_input_catcher.gd").new()
	catcher.process_mode = Node.PROCESS_MODE_ALWAYS
	catcher.set("target", self)
	_stats_layer.add_child(catcher)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.04, 0.84)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stats_layer.add_child(dim)
	var panel := PanelContainer.new()
	panel.position = Vector2(350, 120)
	panel.custom_minimum_size = Vector2(720, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.12, 0.98)
	sb.set_border_width_all(3); sb.border_color = Color(0.78, 0.64, 0.36)
	sb.set_corner_radius_all(14); sb.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel", sb)
	_stats_layer.add_child(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 26)
	panel.add_child(hb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 9)
	vb.custom_minimum_size = Vector2(430, 0)
	hb.add_child(vb)
	var title := Label.new()
	title.text = "CHARACTER"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	var tf := FontFile.new()
	if tf.load_dynamic_font("res://assets/anton.ttf") == OK:
		title.add_theme_font_override("font", tf)
	vb.add_child(title)
	var hp: int = int(_player.max_health) if is_instance_valid(_player) and "max_health" in _player else 0
	var w: Dictionary = ArpgState.weapon
	var base_dmg: int = int(w.get("dmg", 1))
	_stat_line(vb, "Level", "%d   ·   Floor %d" % [ArpgState.level, ArpgState.depth])
	_stat_line(vb, "Gold", "%d" % ArpgState.gold, Color(1.0, 0.85, 0.35))
	_stat_line(vb, "─────────────", "")
	_stat_line(vb, "Max HP", "%d" % hp, Color(0.5, 1.0, 0.6))
	_stat_line(vb, "Damage", "%d   (base %d × %.2f)" % [ArpgState.weapon_damage(), base_dmg, ArpgState.dmg_mult], Color(1.0, 0.6, 0.5))
	_stat_line(vb, "Crit Chance", "%d%%" % int(ArpgState.crit_chance * 100.0), Color(1.0, 0.5, 0.75))
	_stat_line(vb, "Fire Rate", "%.2f / s" % (1.0 / ArpgState.weapon_cooldown()), Color(1.0, 0.85, 0.4))
	_stat_line(vb, "Move Speed", "+%d%%" % int((ArpgState.speed_mult - 1.0) * 100.0), Color(0.5, 0.8, 1.0))
	_stat_line(vb, "─────────────", "")
	var rar: int = int(w.get("rarity", 0))
	_stat_line(vb, "Weapon", "%s %s" % [ArpgState.RARITY_NAMES[rar], w.get("name", "—")], ArpgState.RARITY_COLORS[rar])
	_stat_line(vb, "   Level", "%d / %d" % [int(w.get("lvl", 1)), ArpgState.WEAPON_MAX_LVL])
	_stat_line(vb, "   DPS", "%.0f" % float(ArpgState.weapon_eval(w).get("dps", 0.0)), Color(1.0, 0.72, 0.5))
	_stat_line(vb, "   Per-shot Dmg", "%d" % ArpgState.weapon_damage())
	_stat_line(vb, "   Proj. Speed", "%d" % int(w.get("speed", 600.0)))
	_stat_line(vb, "   Projectiles", "%d" % ArpgState.weapon_count())
	_stat_line(vb, "   Pierce", "%d" % int(w.get("pierce", 0)))
	if bool(w.get("ball", false)):
		_stat_line(vb, "   Bounces", "%d" % int(w.get("bounces", 1)))
	_stat_line(vb, "   Back Shot", "Yes" if ArpgState.back_shot else "No")
	var hint := Label.new()
	hint.text = "TAB to close"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.7))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)
	# Right column — a close-up portrait of the player (a bit narrower).
	var pcol := VBoxContainer.new()
	pcol.add_theme_constant_override("separation", 10)
	pcol.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(pcol)
	var pframe := PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.05, 0.05, 0.09, 0.92)
	psb.set_corner_radius_all(12)
	psb.set_border_width_all(2); psb.border_color = Color(0.78, 0.64, 0.36, 0.6)
	psb.set_content_margin_all(8)
	pframe.add_theme_stylebox_override("panel", psb)
	pframe.clip_contents = true
	pcol.add_child(pframe)
	var portrait := TextureRect.new()
	# bear_portrait.png has no .import sidecar -> load() returns null. Load the raw
	# PNG at runtime (FileAccess), falling back to the imported upper-body sprite.
	var ptex: Texture2D = _load_tex_mip("res://assets/bear_portrait.png")
	if ptex == null:
		ptex = load("res://assets/bear_upper.png")
	portrait.texture = ptex
	portrait.custom_minimum_size = Vector2(300, 372)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	pframe.add_child(portrait)
	var pname := Label.new()
	pname.text = "RUPERT"
	pname.add_theme_font_size_override("font_size", 24)
	pname.add_theme_color_override("font_color", Color(0.92, 0.86, 0.6))
	pname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if tf.load_dynamic_font("res://assets/anton.ttf") == OK:
		pname.add_theme_font_override("font", tf)
	pcol.add_child(pname)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if is_instance_valid(_stats_layer):
				get_viewport().set_input_as_handled()
				_toggle_stats()   # Esc closes the character screen
				return
			if ArpgState.level_lab:
				# Launched from dev Level Select → Esc exits back to it. Remember which
				# level we were in so Level Select can offer "Resume" (back to the game)
				# instead of only "Back to Title".
				get_viewport().set_input_as_handled()
				var cur := get_tree().current_scene
				if cur != null and cur.scene_file_path != "":
					ArpgState.last_lab_scene = cur.scene_file_path
				ArpgState.level_lab = false
				get_tree().change_scene_to_file("res://scenes/level_select.tscn")
				return
			if not has_node("PauseMenu"):
				var pm := preload("res://scenes/pause_menu.tscn").instantiate()
				pm.name = "PauseMenu"
				add_child(pm)
				get_viewport().set_input_as_handled()
		# Press E to inspect/compare a weapon you're standing on (opt-in so you
		# don't accidentally trigger it while moving or firing).
		elif (event.keycode == KEY_E or event.keycode == KEY_Q) and not _weapon_popup_open:
			if not _near_loot_item.is_empty() and is_instance_valid(_near_loot_area):
				get_viewport().set_input_as_handled()
				_offer_weapon(_near_loot_item, _near_loot_area)
		elif event.keycode == KEY_TAB:
			get_viewport().set_input_as_handled()
			_toggle_stats()
		elif event.keycode == KEY_M:
			# Toggle the minimap (FPS A/B test) — hides it AND stops its redraw.
			get_viewport().set_input_as_handled()
			_minimap_on = not _minimap_on
			if _minimap:
				_minimap.visible = _minimap_on
			_on_toast("Minimap %s" % ("ON" if _minimap_on else "OFF"), Color(0.7, 0.85, 1.0))
		elif event.keycode == KEY_F3:
			get_viewport().set_input_as_handled()
			_toggle_perf_overlay()

# ── PERF OVERLAY (press F3) ──────────────────────────────────────────────────
# Live frame-time + object/draw-call counters so we can SEE what's spiking during a
# heavy fight instead of guessing. Cheap: text only, refreshed ~5x/sec.
var _perf_label: Label = null
var _perf_t: float = 0.0

func _toggle_perf_overlay() -> void:
	if _perf_label == null:
		var cl := CanvasLayer.new()
		cl.layer = 200
		add_child(cl)
		_perf_label = Label.new()
		_perf_label.add_theme_font_size_override("font_size", 16)
		_perf_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.5))
		_perf_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		_perf_label.add_theme_constant_override("outline_size", 4)
		_perf_label.position = Vector2(14, 150)
		cl.add_child(_perf_label)
	_perf_label.visible = not _perf_label.visible
	_on_toast("Perf overlay %s" % ("ON" if _perf_label.visible else "OFF"), Color(0.6, 1.0, 0.5))

var _perf_hitches: Array = []
var _perf_flush_t: float = 0.0

func _log_hitch_if_any(delta: float) -> void:
	# AUTO-CAPTURE: whenever a frame takes too long (a hitch), snapshot the live counts so I
	# can read which metric correlates with the stutter — no manual overlay reading needed.
	# Writes user://perf_hitches.json (latest 300 hitches), flushed every ~4s.
	if not ArpgState.active:
		return
	if delta > 0.033 and delta < 0.30:        # 33-300ms = a gameplay hitch (skip level-load spikes)
		_perf_hitches.append({
			"ms": int(delta * 1000.0),
			"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
			"draws": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			"phys_ms": snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.1),
			"enemies": get_tree().get_nodes_in_group("enemies").size(),
			"theme": theme,
			"depth": ArpgState.depth,
			"t": int(Time.get_ticks_msec()),
		})
		if _perf_hitches.size() > 300:
			_perf_hitches = _perf_hitches.slice(_perf_hitches.size() - 300)
	_perf_flush_t -= delta
	if _perf_flush_t <= 0.0 and not _perf_hitches.is_empty():
		_perf_flush_t = 4.0
		var f := FileAccess.open("user://perf_hitches.json", FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(_perf_hitches))
			f.close()

func _update_perf_overlay(delta: float) -> void:
	if _perf_label == null or not _perf_label.visible:
		return
	_perf_t -= delta
	if _perf_t > 0.0:
		return
	_perf_t = 0.2
	var fps: float = Engine.get_frames_per_second()
	var proc_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var phys_ms: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var draws: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var enemies: int = get_tree().get_nodes_in_group("enemies").size()
	var pizzas: int = get_tree().get_nodes_in_group("player_projectiles").size()
	_perf_label.text = "FPS %d   frame: proc %.1fms / phys %.1fms\nnodes %d  orphans %d  draws %d\nenemies %d  pizzas %d" % [
		fps, proc_ms, phys_ms, nodes, orphans, draws, enemies, pizzas]
	_perf_label.modulate = Color(1, 0.4, 0.4) if fps < 50 else Color(1, 1, 1)

# ── lighting modes (live-switchable) ────────────────────────────────────────
func _build_gi_layer() -> void:
	var layer := CanvasLayer.new()
	layer.name = "GILayer"
	layer.layer = 2                          # above world, below UI (layer 6+)
	add_child(layer)
	var bbc := BackBufferCopy.new()
	bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	layer.add_child(bbc)
	_gi_rect = ColorRect.new()
	_gi_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gi_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = LightBleedShader
	_gi_rect.material = mat
	_gi_rect.visible = false
	layer.add_child(_gi_rect)

func _build_fog() -> void:
	# Super-light drifting fog haze over everything (above the GI post, below UI).
	var layer := CanvasLayer.new()
	layer.name = "FogLayer"
	layer.layer = 3
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog_mat = ShaderMaterial.new()
	_fog_mat.shader = FogShader
	_fog_mat.set_shader_parameter("noise_tex", FogNoiseTex)
	_fog_mat.set_shader_parameter("density", 0.006)
	_fog_mat.set_shader_parameter("vp", get_viewport_rect().size)
	rect.material = _fog_mat
	layer.add_child(rect)

func _set_fog(col: Color, density: float) -> void:
	if _fog_mat != null:
		_fog_mat.set_shader_parameter("fog_color", Vector3(col.r, col.g, col.b))
		_fog_mat.set_shader_parameter("density", density)

func _build_light_panel() -> void:
	# Top-right brightness controls: LIGHT 1-5 (pump all light sources) and
	# ENEMIES 1-3 (self-illuminate enemy models so they show in the dark).
	var layer := CanvasLayer.new()
	layer.name = "LightSwitch"
	layer.layer = 7
	add_child(layer)
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -210.0
	panel.offset_top = 12.0
	panel.offset_right = -12.0
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.05, 0.04, 0.08, 0.9)
	psb.set_border_width_all(1)
	psb.border_color = Color(0.6, 0.5, 0.3, 0.7)
	psb.set_corner_radius_all(6)
	psb.content_margin_left = 8; psb.content_margin_right = 8
	psb.content_margin_top = 6; psb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", psb)
	layer.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)

	_light_buttons = _build_level_row(vb, "LIGHT", 5, _apply_light_boost)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vb.add_child(spacer)
	_enemy_buttons = _build_level_row(vb, "ENEMIES", 3, _apply_enemy_brightness)

func _build_level_row(parent: Node, label: String, count: int, cb: Callable) -> Array[Button]:
	var hdr := Label.new()
	hdr.text = label
	hdr.add_theme_font_size_override("font_size", 11)
	hdr.add_theme_color_override("font_color", Color(0.8, 0.78, 0.62))
	parent.add_child(hdr)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var btns: Array[Button] = []
	for i in range(1, count + 1):
		var b := Button.new()
		b.text = str(i)
		b.custom_minimum_size = Vector2(30, 28)
		b.add_theme_font_size_override("font_size", 14)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(cb.bind(i))
		row.add_child(b)
		btns.append(b)
	return btns

func _style_level_buttons(btns: Array[Button], active: int) -> void:
	for i in btns.size():
		var on: bool = (i + 1 == active)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.95, 0.78, 0.34, 0.95) if on else Color(0.13, 0.12, 0.17, 0.85)
		sb.set_corner_radius_all(4)
		btns[i].add_theme_stylebox_override("normal", sb)
		btns[i].add_theme_stylebox_override("hover", sb)
		btns[i].add_theme_stylebox_override("pressed", sb)
		btns[i].add_theme_color_override("font_color", Color(0.12, 0.09, 0.04) if on else Color(0.9, 0.88, 0.92))

# Scale every PointLight2D's energy + reach from its captured base, and lift the
# ambient floor a touch, so the whole scene brightens from its light sources.
func _apply_light_boost(level: int) -> void:
	level = clampi(level, 1, 5)
	ArpgState.light_boost = level
	var ef: float = LIGHT_ENERGY_MULT[level - 1]
	var sf: float = LIGHT_REACH_MULT[level - 1]
	for n in _all_lights(self):
		if n.name == "SelfLight":
			continue   # enemy self-lights are controlled separately
		if not n.has_meta("base_e"):
			n.set_meta("base_e", n.energy)
			n.set_meta("base_s", n.texture_scale)
		n.energy = float(n.get_meta("base_e")) * ef
		n.texture_scale = float(n.get_meta("base_s")) * sf
	# Small ambient lift so deep-black corners aren't pure void at high settings.
	_ambient.color = _base_ambient + Color(0.02, 0.02, 0.025) * float(level - 1)
	if not _light_buttons.is_empty():
		_style_level_buttons(_light_buttons, level)

func _all_lights(node: Node, acc: Array = []) -> Array:
	for c in node.get_children():
		if c is PointLight2D:
			acc.append(c)
		if c.get_child_count() > 0:
			_all_lights(c, acc)
	return acc

# Give each enemy a faint self-light so its model is visible in pitch black.
func _apply_enemy_brightness(level: int) -> void:
	level = clampi(level, 1, 3)
	ArpgState.enemy_bright = level
	var energy: float = ENEMY_LIGHT_ENERGY[level - 1]
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node2D):
			continue
		var sl := e.get_node_or_null("SelfLight") as PointLight2D
		if sl == null:
			sl = PointLight2D.new()
			sl.name = "SelfLight"
			sl.texture = LightTex
			sl.color = Color(1.0, 0.86, 0.72)
			sl.texture_scale = 0.5      # tight — mostly lights the bear itself
			sl.z_index = 1
			(e as Node2D).add_child(sl)
		sl.energy = energy
		sl.visible = energy > 0.01
	if not _enemy_buttons.is_empty():
		_style_level_buttons(_enemy_buttons, level)

func _apply_lighting_mode(m: int) -> void:
	# Clean lighting presets — smooth radial light falloff, no per-tile normal
	# shading and no screen-space bleed (both produced artifacts). Each is a
	# distinct brightness/colour/contrast mood.
	m = clampi(m, 1, 5)
	ArpgState.light_mode = m
	var e: Environment = _env
	match m:
		1:  # Standard — warm, moody, balanced · neutral grey haze
			e.glow_intensity = 0.8; e.glow_strength = 1.2; e.glow_bloom = 0.18; e.glow_hdr_threshold = 0.75
			e.adjustment_contrast = 1.1; e.adjustment_saturation = 1.15
			_ambient.color = Color(0.143, 0.132, 0.176)   # +10% general lighting
			_set_fog(Color(0.5, 0.52, 0.6), 0.003)
		2:  # Bright — well-lit · thin pale fog
			e.glow_intensity = 1.1; e.glow_strength = 1.3; e.glow_bloom = 0.3; e.glow_hdr_threshold = 0.6
			e.adjustment_contrast = 1.05; e.adjustment_saturation = 1.15
			_ambient.color = Color(0.24, 0.23, 0.27)
			_set_fog(Color(0.7, 0.72, 0.78), 0.004)
		3:  # Cool — moonlit blue · blue mist
			e.glow_intensity = 0.85; e.glow_strength = 1.2; e.glow_bloom = 0.2; e.glow_hdr_threshold = 0.72
			e.adjustment_contrast = 1.12; e.adjustment_saturation = 1.1
			_ambient.color = Color(0.10, 0.13, 0.20)
			_set_fog(Color(0.4, 0.52, 0.78), 0.010)
		4:  # Noir — dark high-contrast · heavy murky fog
			e.glow_intensity = 0.4; e.glow_strength = 1.0; e.glow_bloom = 0.06; e.glow_hdr_threshold = 0.88
			e.adjustment_contrast = 1.4; e.adjustment_saturation = 0.7
			_ambient.color = Color(0.05, 0.05, 0.08)
			_set_fog(Color(0.26, 0.26, 0.32), 0.012)
		5:  # Warm — cozy firelight · amber smoke
			e.glow_intensity = 1.0; e.glow_strength = 1.3; e.glow_bloom = 0.3; e.glow_hdr_threshold = 0.58
			e.adjustment_contrast = 1.1; e.adjustment_saturation = 1.45
			_ambient.color = Color(0.2, 0.14, 0.11)
			_set_fog(Color(0.58, 0.48, 0.36), 0.008)
	for i in _mode_buttons.size():
		var active: bool = (i + 1 == m)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.9, 0.74, 0.34, 0.95) if active else Color(0.13, 0.12, 0.17, 0.85)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 8; sb.content_margin_right = 8
		sb.content_margin_top = 4; sb.content_margin_bottom = 4
		_mode_buttons[i].add_theme_stylebox_override("normal", sb)
		_mode_buttons[i].add_theme_stylebox_override("hover", sb)
		_mode_buttons[i].add_theme_stylebox_override("pressed", sb)
		_mode_buttons[i].add_theme_color_override("font_color", Color(0.12, 0.09, 0.04) if active else Color(0.9, 0.88, 0.92))

# ── themed levels: neon / damp / hand (5 design variants each) ───────────────
func _is_custom_theme() -> bool:
	return theme == "neon" or theme == "damp" or theme == "hand" or theme == "cyber2077" or theme == "space" or theme == "poolrooms" or theme == "wheat" or theme == "sewer" or theme == "suburb" or theme == "glitch" or theme == "toystore" or theme == "carnival" or theme == "frozen" or theme == "subway"

# Flat, fully-lit themes (backrooms-style): bright global ambient, NO player aura,
# no prop/projectile glows. The hand-drawn + cyberpunk levels use normal lighting.
func _flat_lit() -> bool:
	return theme == "backrooms" or theme == "hand" or theme == "cyber2077" or theme == "wheat" or theme == "poolrooms" or theme == "suburb" or theme == "glitch" or theme == "toystore" or theme == "carnival" or theme == "frozen"

func _ctex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t: Texture2D = _load_tex_mip(path)
	_tex_cache[path] = t
	return t

func _apply_variant() -> void:
	# Dev Level Lab passes the chosen design through ArpgState; otherwise use the
	# scene's exported `variant`. Clamp to the 5 designs.
	_variant = variant
	if ArpgState.pending_variant > 0:
		_variant = ArpgState.pending_variant
		ArpgState.pending_variant = 0
	_variant = clampi(_variant, 1, 5)
	var list: Array = _theme_variants().get(theme, [])
	if list.is_empty():
		return
	_lvl_cfg = list[(_variant - 1) % list.size()]
	var base: String = "res://assets/%s/" % theme
	_lvl_floor = _ctex(base + "floors/" + String(_lvl_cfg["floor"]) + ".png")
	var wall_name: String = wall_override if wall_override != "" else String(_lvl_cfg["wall"])
	_lvl_wall = _ctex(base + "walls/" + wall_name + ".png")
	if _lvl_cfg.has("wall_top"):
		_lvl_wall_top = _ctex(base + "walls/" + String(_lvl_cfg["wall_top"]) + ".png")
	_lvl_ambient = _lvl_cfg.get("amb", Color(0.15, 0.14, 0.21))

func _glow(pos: Vector2, color: Color, energy: float, reach_tiles: float) -> void:
	if _flat_lit():
		return   # flat-lit themes: nothing casts an aura
	var g := PointLight2D.new()
	g.texture = LightTex
	g.position = pos
	g.color = color
	g.energy = energy
	g.texture_scale = (tile * reach_tiles) / float(LightTex.get_width())
	g.shadow_enabled = false
	add_child(g)

# Build a prop pool [{tex,frac,col,en,reach}] from a list of [name,frac,col,en,reach].
func _prop_pool(specs: Array) -> Array:
	var base: String = "res://assets/%s/props/" % theme
	var pool: Array = []
	for s in specs:
		var nm: String = String(s[0])
		# "pack/cat/name" = pull from another pack; bare name = this theme's props dir.
		var path: String = ("res://assets/" + nm + ".png") if nm.contains("/") else (base + nm + ".png")
		var t: Texture2D = _ctex(path)
		if t != null:
			pool.append({"tex": t, "frac": float(s[1]),
				"col": (s[2] if s.size() > 2 else null),
				"en": (float(s[3]) if s.size() > 3 else 0.0),
				"reach": (float(s[4]) if s.size() > 4 else 3.0)})
	return pool

func _spawn_custom_props() -> void:
	# Tall pieces tuck against room walls (some cast coloured light); low clutter
	# scatters across the floor near corners. Purely decorative — no collision.
	var wall_pool: Array = _prop_pool(_lvl_cfg.get("wall_props", []))
	var floor_pool: Array = _prop_pool(_lvl_cfg.get("floor_props", []))
	if wall_pool.is_empty() and floor_pool.is_empty():
		return
	var wall_chance: float = float(_lvl_cfg.get("wall_chance", 0.7))
	var floor_chance: float = float(_lvl_cfg.get("floor_chance", 0.5))
	for room in _rooms:
		if room == _start_room or room == _boss_room:
			continue
		if not wall_pool.is_empty() and randf() < wall_chance:
			var p: Dictionary = wall_pool[randi() % wall_pool.size()]
			var spot: Dictionary = _perimeter_spot(room)
			var toward: Vector2 = spot["toward"]
			# Light-casting pieces (torches / braziers / crystals) are wall fixtures —
			# mount them flush against the wall and lifted onto its face, drawn in front.
			var mounted: bool = p["col"] != null
			var pos: Vector2
			if mounted:
				# Mount flush ON the wall: `toward` points AT the wall, so push the torch
				# out to the floor/wall boundary and draw it in front. (Previously this
				# used `-toward`, shoving torches INTO the room — the floating-in-the-middle bug.)
				pos = spot["pos"] + toward * (tile * 0.5)
				_place_prop(p["tex"], pos, 3, float(p["frac"]), 0)
			else:
				# z=0 → the prop y-sorts with the player/enemies (parent has y_sort on), so
				# you walk IN FRONT of wall props when below them, not always behind.
				pos = spot["pos"] + toward * (tile * 0.16)
				_place_prop(p["tex"], pos, 0, float(p["frac"]), 0)
			if p["col"] != null:
				var head: Vector2 = pos - Vector2(0, tile * float(p["frac"]) * 0.32)
				_glow(head, p["col"], float(p["en"]), float(p["reach"]))
		if not floor_pool.is_empty() and randf() < floor_chance:
			var spot3: Dictionary = _corner_spot(room)
			var fbase: Vector2 = spot3["pos"] + Vector2(spot3["toward"]) * (tile * 0.12)
			for i in randi_range(1, 3):
				var fp: Dictionary = floor_pool[randi() % floor_pool.size()]
				var off := Vector2(randf_range(-tile * 0.5, tile * 0.5), randf_range(-tile * 0.4, tile * 0.4))
				_place_prop(fp["tex"], fbase + off, 0, float(fp["frac"]))
				if fp["col"] != null:
					_glow(fbase + off - Vector2(0, tile * 0.2), fp["col"], float(fp["en"]), float(fp["reach"]))

# Hand level only: mount sconce torches on the LEFT/RIGHT exposed faces of wall runs.
# In a left-to-right row of wall blocks the leftmost block borders floor on its LEFT
# (→ torch on its left face) and the rightmost borders floor on its RIGHT (→ torch on
# its right face); interior blocks are walled on both sides and stay bare. Vertical
# faces are thinned to one torch every few cells so tall walls don't get a ladder of them.
func _spawn_hand_wall_torches() -> void:
	var tex: Texture2D = _ctex("res://assets/hand/props/isowalltorch.png")
	if tex == null:
		return
	var gap: int = 6                       # min vertical cell spacing along a face (halved torch density)
	var last_left: Dictionary = {}         # column x -> last y a left-face torch was placed
	var last_right: Dictionary = {}        # column x -> last y a right-face torch was placed
	for y in range(_fh):
		for x in range(_fw):
			if not _wall[y][x]:
				continue
			# Left face exposed: floor immediately to the left → flame points into the room.
			if x - 1 >= 0 and not _wall[y][x - 1] and y - int(last_left.get(x, -99)) >= gap:
				last_left[x] = y
				_place_prop(tex, Vector2(x * tile - tile * 0.06, (y + 0.5) * tile), 4, 0.9, 1)
			# Right face exposed: floor immediately to the right.
			if x + 1 < _fw and not _wall[y][x + 1] and y - int(last_right.get(x, -99)) >= gap:
				last_right[x] = y
				_place_prop(tex, Vector2((x + 1) * tile + tile * 0.06, (y + 0.5) * tile), 4, 0.9, 0)

# Hand level only: stand columns against walls so the base rises out of the floor and
# the top tucks up behind the wall face/top — reads like a pillar built INTO the wall
# rather than a free-standing sprite floating in the room.
func _spawn_hand_pillars() -> void:
	var texes: Array = []
	for nm in ["IsoPillar", "IsoPillar2", "isosquare-pillar1"]:
		var t: Texture2D = _ctex("res://assets/hand/props/%s.png" % nm)
		if t != null:
			texes.append(t)
	if texes.is_empty():
		return
	# Candidates: solid cells with floor directly BELOW (south-facing wall). A column
	# placed here pokes its base into that floor cell; its top is hidden by the wall's
	# front face (z=1) and lit top (z=2), since props draw at z=0 behind both.
	var cands: Array = []
	for y in range(_fh - 1):
		for x in range(_fw):
			if _wall[y][x] and not _wall[y + 1][x]:
				cands.append(Vector2i(x, y))
	cands.shuffle()
	var placed: Array = []
	var want: int = clampi(_rooms.size() / 2, 2, 9)
	for c in cands:
		if placed.size() >= want:
			break
		var pc := Vector2((c.x + 0.5) * tile, (c.y + 1) * tile)
		if _pos_too_close(pc, placed, tile * 5.0):
			continue
		placed.append(pc)
		# nudged down so the lit base sits out in the room; tall frac so it spans the wall.
		_place_prop(texes[randi() % texes.size()], pc + Vector2(0, tile * 0.34), 0, 1.9, 0)

# Hand level only: crates and barrels are piled in mixed clusters tucked into a few
# room corners (a little stack here and there) instead of scattered as lone props.
func _spawn_hand_clusters() -> void:
	var pool: Array = []
	var crate: Texture2D = _ctex("res://assets/hand/props/isocrate.png")
	var barrel: Texture2D = _ctex("res://assets/hand/props/IsoBarrel.png")
	if crate != null:
		pool.append({"tex": crate, "frac": 0.82})
	if barrel != null:
		pool.append({"tex": barrel, "frac": 0.96})
	if pool.is_empty():
		return
	for room in _rooms:
		if room == _start_room or room == _boss_room:
			continue
		if randf() >= 0.55:
			continue
		var spot: Dictionary = _corner_spot(room)
		var base: Vector2 = Vector2(spot["pos"]) + Vector2(spot["toward"]) * (tile * 0.18)
		var slots: Array = []
		for i in range(randi_range(2, 4)):
			slots.append(Vector2(randf_range(-tile * 0.45, tile * 0.45), randf_range(-tile * 0.30, tile * 0.36)))
		slots.sort_custom(func(a, b): return a.y < b.y)   # back-to-front so nearer crates overlap
		for off in slots:
			var it: Dictionary = pool[randi() % pool.size()]
			_place_prop(it["tex"], base + off, 0, float(it["frac"]))

# The 5 design variants for each themed level. Colours are PointLight2D tints.
func _theme_variants() -> Dictionary:
	var CY := Color(0.35, 0.85, 1.0)
	var MA := Color(1.0, 0.25, 0.65)
	var RE := Color(1.0, 0.30, 0.28)
	var WA := Color(1.0, 0.72, 0.42)
	var GR := Color(0.45, 1.0, 0.55)
	var PU := Color(0.7, 0.4, 1.0)
	# neon shares one floor/wall set; variants are mood + light-palette swaps.
	var neon_signs := func(c1: Color, c2: Color) -> Array:
		return [["sign_neon", 1.05, c1, 1.15, 3.4], ["vending_a", 1.45, c2, 0.55, 2.2],
			["vending_b", 1.45, c2, 0.55, 2.2], ["vending_c", 1.45, c1, 0.6, 2.2],
			["lamp_a", 2.1, c2, 0.9, 3.6], ["lamp_b", 2.1, c2, 0.9, 3.6],
			["lamp_c", 1.9, WA, 0.9, 3.4], ["light_red_a", 1.9, c1, 0.95, 3.0],
			["light_red_b", 1.9, c1, 0.95, 3.0]]
	var neon_floor := [["crates", 1.15], ["bin_a", 0.85], ["bin_b", 0.85], ["canister", 0.85]]
	var nbase := {"floor": "floor", "wall": "wall", "wall_top": "wall_top",
		"face_shade": 0.78, "wall_props": [], "floor_props": neon_floor, "wall_chance": 0.72}
	return {
		"neon": [
			_merge(nbase, {"amb": Color(0.16, 0.17, 0.27), "wall_props": neon_signs.call(MA, CY)}),
			_merge(nbase, {"amb": Color(0.24, 0.11, 0.15), "wall_props": neon_signs.call(RE, WA)}),
			_merge(nbase, {"amb": Color(0.18, 0.12, 0.28), "wall_props": neon_signs.call(MA, PU)}),
			_merge(nbase, {"amb": Color(0.12, 0.20, 0.17), "wall_props": neon_signs.call(GR, CY)}),
			_merge(nbase, {"amb": Color(0.22, 0.18, 0.11), "wall_props": neon_signs.call(WA, RE)}),
		],
		"damp": _damp_variants(WA, CY),
		"hand": _hand_variants(WA),
		"cyber2077": _cyber_variants(CY, MA, RE, WA, GR, PU),
		"space": _space_variants(CY),
		"poolrooms": _poolrooms_variants(),
		"wheat": _wheat_variants(),
		"sewer": _sewer_variants(),
		"suburb": _suburb_variants(),
		"glitch": _glitch_variants(),
		"toystore": _toystore_variants(),
		"carnival": _carnival_variants(),
		"frozen": _frozen_variants(),
		"subway": _subway_variants(),
	}

func _glitch_variants() -> Array:
	# Corrupted level: static-noise floor + the original dungeon brick walls, which strobe
	# through random glitch colours (see _glitch_flash). Props are bare.
	var base := {"floor": "static", "wall": "brick", "wall_top": "brick",
		"face_shade": 0.85, "wall_chance": 0.0, "wall_props": [], "floor_props": []}
	var v: Array = []
	for i in range(5):
		v.append(_merge(base, {"amb": Color(0.55, 0.55, 0.6)}))
	return v

# Glitch level: every wall brick strobes to a new random bright colour 4x/sec.
func _start_glitch_flash() -> void:
	var t := Timer.new()
	t.wait_time = 0.22
	t.autostart = true
	t.timeout.connect(_glitch_flash)
	add_child(t)

# Flat-colour shader: render the textured sprite as a SOLID silhouette of `flat_col`,
# keeping only the texture's alpha. Used to make the player a flashing solid shape.
const _GLITCH_PLAYER_SHADER := "shader_type canvas_item;\nuniform vec4 flat_col : source_color = vec4(1.0);\nvoid fragment() {\n\tvec4 t = texture(TEXTURE, UV);\n\tCOLOR = vec4(flat_col.rgb, t.a);\n}"

func _apply_glitch_player() -> void:
	# In the glitch level the player becomes a solid-colour silhouette that flashes with
	# the walls (same vibe as falling INTO the glitch).
	if _player == null:
		return
	var rig := _player.get_node_or_null("Rig")
	if rig == null:
		return
	var sh := Shader.new()
	sh.code = _GLITCH_PLAYER_SHADER
	for n in rig.get_children():
		if n is Sprite2D:
			var m := ShaderMaterial.new()
			m.shader = sh
			m.set_shader_parameter("flat_col", Color.from_hsv(randf(), 0.9, 1.0))  # seed so it isn't white for the first 0.22s
			(n as Sprite2D).material = m
			(n as Sprite2D).add_to_group("glitch_player")

func _glitch_flash() -> void:
	# Walls are flat white tiles, so the modulate IS the colour they show — pure flashing
	# cubes. Roll vivid, fully-saturated hues so they flash THROUGH the colour wheel.
	for w in get_tree().get_nodes_in_group("glitch_wall"):
		if is_instance_valid(w):
			(w as CanvasItem).modulate = Color.from_hsv(randf(), randf_range(0.85, 1.0), randf_range(0.85, 1.0), 1.0)
	# The player flashes as a solid silhouette too.
	var pcol := Color.from_hsv(randf(), randf_range(0.85, 1.0), 1.0)
	for s in get_tree().get_nodes_in_group("glitch_player"):
		if is_instance_valid(s):
			var mm := (s as CanvasItem).material as ShaderMaterial
			if mm != null:
				mm.set_shader_parameter("flat_col", pcol)

func _toystore_variants() -> Array:
	# Toy Store: bright checkerboard floor, store-wall maze, shelving + toy-box clutter.
	var base := {"floor": "floor", "wall": "wall", "wall_top": "wall_top",
		"face_shade": 0.9, "wall_chance": 0.5,
		"wall_props": [["backrooms/props/furniture/shelf", 1.4]],
		"floor_props": [["fx/biome/toybox_blue", 0.9], ["fx/biome/toybox_green", 0.9],
			["fx/biome/toybox_orange", 0.9], ["fx/biome/toybox_purple", 0.9],
			["fx/biome/counter", 1.3]]}
	var v: Array = []
	for i in range(5):
		v.append(_merge(base, {"amb": Color(0.96, 0.95, 0.92)}))
	return v

func _carnival_variants() -> Array:
	# Carnival: grassy midway, hedge-maze walls, carousel + striped tents + prize booths.
	var base := {"floor": "floor", "wall": "wall", "wall_top": "wall_top",
		"face_shade": 0.92, "wall_chance": 0.45, "wall_props": [],
		"floor_props": [["fx/biome/carousel", 3.0], ["fx/biome/tent_red", 2.2],
			["fx/biome/tent_blue", 2.2], ["fx/biome/tent_green", 2.2], ["fx/biome/booth", 1.5]]}
	var v: Array = []
	for i in range(5):
		v.append(_merge(base, {"amb": Color(0.95, 0.96, 0.98)}))
	return v

func _frozen_variants() -> Array:
	# Frozen Cavern: pale ice floor, rocky-ice walls, ice boulders + frozen pools.
	var base := {"floor": "floor", "wall": "wall", "wall_top": "wall_top",
		"face_shade": 0.8, "wall_chance": 0.6, "wall_props": [],
		"floor_props": [["fx/biome/ice_rock", 1.2], ["fx/biome/ice_pool", 1.6]]}
	var v: Array = []
	for i in range(5):
		v.append(_merge(base, {"amb": Color(0.72, 0.82, 0.95)}))
	return v

func _subway_variants() -> Array:
	# Subway Platform: concrete platform floor, white tiled walls, track sections.
	var base := {"floor": "floor", "wall": "wall", "wall_top": "wall_top",
		"face_shade": 0.7, "wall_chance": 0.6, "wall_props": [],
		"floor_props": [["fx/biome/track", 1.5]]}
	var v: Array = []
	for i in range(5):
		v.append(_merge(base, {"amb": Color(0.45, 0.47, 0.55)}))
	return v

func _suburb_variants() -> Array:
	# Suburban neighbourhood: a connected CUL-DE-SAC road network (see _generate_suburb).
	# Roads are the floor; houses (siding walls + shingle roofs) are the wall mass.
	# Courts dressed with trees + parked cars, mailboxes & hedges against the houses.
	# wall FACE uses the grey concrete "roof" tile (was the blue "house" siding strip that
	# clashed under the iso house sprites); the houses themselves now carry the suburb look.
	var base := {"floor": "road", "wall": "roof", "wall_top": "roof",
		"face_shade": 0.8, "wall_chance": 0.6, "floor_chance": 0.6,
		"wall_props": [],
		"floor_props": [["tree", 1.4]]}   # mailboxes go beside the houses; cars park on the road
	return [
		_merge(base, {"amb": Color(0.94, 0.95, 0.98)}),
		_merge(base, {"amb": Color(0.96, 0.95, 0.9), "floor_props": [["tree", 1.5]]}),
		_merge(base, {"amb": Color(0.92, 0.94, 0.98), "floor_props": [["tree", 1.5]]}),
		_merge(base, {"amb": Color(0.95, 0.95, 0.96), "floor_props": [["tree", 1.3]]}),
		_merge(base, {"amb": Color(0.93, 0.95, 0.97), "floor_props": [["tree", 1.4]]}),
	]

func _build_walls_suburb() -> void:
	# Suburb is open-air: the non-road mass is flat GRASS yards (not raised grey blocks),
	# still solid so you stay on the streets. Houses / lawns / fences layer on top later.
	var grass: Texture2D = _ctex("res://assets/kenney_roguelike/grass.png")
	var gs: float = float(maxi(1, grass.get_width())) if grass != null else 1.0
	for y in _fh:
		for x in _fw:
			if not _wall[y][x]:
				continue
			if grass != null:
				var g := Sprite2D.new()
				g.texture = grass
				g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				g.position = Vector2((x + 0.5) * tile, (y + 0.5) * tile)
				g.scale = Vector2(tile / gs, tile / gs)
				g.z_index = -12
				add_child(g)
			if not _touches_floor(x, y):
				continue                      # interior yard cells are unreachable → no collider
			var body := StaticBody2D.new()
			body.add_to_group("walls")
			body.position = Vector2((x + 0.5) * tile, (y + 0.5) * tile)
			body.collision_layer = 1
			body.collision_mask = 0
			var cs := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(tile, tile)
			cs.shape = rect
			body.add_child(cs)
			add_child(body)

func _add_strip(center: Vector2, size: Vector2, col: Color, z: int) -> void:
	var r := Polygon2D.new()
	var hw: float = size.x * 0.5
	var hh: float = size.y * 0.5
	r.polygon = PackedVector2Array([Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)])
	r.color = col
	r.position = center
	r.z_index = z
	add_child(r)

func _stripe_suburb_roads() -> void:
	# Paint a light curb where the asphalt meets a yard, and a solid DOUBLE-YELLOW line down
	# the centre of every 3-wide street (American road markings) — read off the road shape.
	var YELLOW := Color(0.86, 0.72, 0.18)
	var CURB := Color(0.6, 0.6, 0.64)
	for y in range(1, _fh - 1):
		for x in range(1, _fw - 1):
			if _wall[y][x]:
				continue
			var cxw: float = (x + 0.5) * tile
			var cyw: float = (y + 0.5) * tile
			# curb strips at the road/yard boundary
			if _wall[y - 1][x]:
				_add_strip(Vector2(cxw, y * tile + tile * 0.05), Vector2(tile, tile * 0.1), CURB, -16)
			if _wall[y + 1][x]:
				_add_strip(Vector2(cxw, (y + 1) * tile - tile * 0.05), Vector2(tile, tile * 0.1), CURB, -16)
			if _wall[y][x - 1]:
				_add_strip(Vector2(x * tile + tile * 0.05, cyw), Vector2(tile * 0.1, tile), CURB, -16)
			if _wall[y][x + 1]:
				_add_strip(Vector2((x + 1) * tile - tile * 0.05, cyw), Vector2(tile * 0.1, tile), CURB, -16)
			# centre line: a road cell flanked by road then yard two cells out
			var horiz: bool = false
			var vert: bool = false
			if y >= 2 and y + 2 < _fh:
				horiz = (not _wall[y - 1][x]) and (not _wall[y + 1][x]) and _wall[y - 2][x] and _wall[y + 2][x]
			if x >= 2 and x + 2 < _fw:
				vert = (not _wall[y][x - 1]) and (not _wall[y][x + 1]) and _wall[y][x - 2] and _wall[y][x + 2]
			if horiz and not vert:
				_add_strip(Vector2(cxw, cyw - tile * 0.06), Vector2(tile, tile * 0.045), YELLOW, -15)
				_add_strip(Vector2(cxw, cyw + tile * 0.06), Vector2(tile, tile * 0.045), YELLOW, -15)
			elif vert and not horiz:
				_add_strip(Vector2(cxw - tile * 0.06, cyw), Vector2(tile * 0.045, tile), YELLOW, -15)
				_add_strip(Vector2(cxw + tile * 0.06, cyw), Vector2(tile * 0.045, tile), YELLOW, -15)

func _scatter_suburb_houses() -> void:
	# Houses sit BACK on their grass lawns, all facing the street the same way (down) so the
	# rows read cleanly — a concrete driveway runs out to the kerb and picket fences divide
	# the lots. Placed on yard cells that front a road (south preferred → faces straight in).
	var texes: Array = []
	for c in ["blue", "pink", "green"]:
		for s in ["00", "01", "02", "03"]:
			var t: Texture2D = _ctex("res://assets/suburb/houses/house_%s_%s.png" % [c, s])
			if t != null:
				texes.append(t)
	if texes.is_empty():
		return
	var fronts: Array = []
	for y in range(1, _fh - 1):
		for x in range(1, _fw - 1):
			if not _wall[y][x]:
				continue
			var rs: bool = not _wall[y + 1][x]
			var re: bool = not _wall[y][x + 1]
			var rw: bool = not _wall[y][x - 1]
			if not (rs or re or rw):
				continue
			fronts.append({"x": x, "y": y, "rs": rs})
	fronts.shuffle()
	var placed: Array = []
	var infos: Array = []
	var min_gap: float = tile * 1.9
	var house_h: float = tile * 1.45
	for cd in fronts:
		var cx: int = cd["x"]; var cy: int = cd["y"]
		# Sit the house back on its lawn; body is drawn UPWARD from the base so it never spills
		# onto the street → safe at a high z without occluding the player below.
		var base_w := Vector2((cx + 0.5) * tile, (cy + 0.62) * tile)
		var ok := true
		for pp in placed:
			if (pp as Vector2).distance_to(base_w) < min_gap:
				ok = false
				break
		if not ok:
			continue
		placed.append(base_w)
		var tex: Texture2D = texes[randi() % texes.size()]
		var sc: float = house_h / float(maxi(1, tex.get_height()))
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.scale = Vector2(sc, sc)
		spr.offset = Vector2(0, -float(tex.get_height()) * 0.5)
		spr.position = base_w
		spr.z_index = 3
		spr.add_to_group("suburb_house")
		add_child(spr)
		infos.append({"pos": base_w, "hw": tex.get_width() * sc * 0.5, "rs": cd["rs"]})
	# Asphalt DRIVEWAY (same dark tone as the road tile) from each street-facing house out to
	# the kerb — a wide flat strip, not a pole.
	for inf in infos:
		if not inf["rs"]:
			continue
		var hp2: Vector2 = inf["pos"]
		var side2: float = -1.0 if randf() < 0.5 else 1.0
		var dwx: float = hp2.x + side2 * float(inf["hw"]) * 0.45
		_add_strip(Vector2(dwx, hp2.y + tile * 0.34), Vector2(tile * 0.5, tile * 0.66), Color(0.2, 0.2, 0.22), -10)
	# A mailbox sat BESIDE the house (out on the lawn toward the kerb) — never in the road.
	var mailbox: Texture2D = _ctex("res://assets/suburb/props/mailbox.png")
	if mailbox != null:
		for inf in infos:
			if randf() > 0.55:
				continue                      # only ~half the houses get one
			var hp: Vector2 = inf["pos"]
			var side: float = -1.0 if randf() < 0.5 else 1.0
			var mb := Sprite2D.new()
			mb.texture = mailbox
			mb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var msz: float = (tile * 0.55) / float(maxi(1, mailbox.get_height()))
			mb.scale = Vector2(msz, msz)
			mb.offset = Vector2(0, -float(mailbox.get_height()) * 0.5)   # post anchored at its base
			mb.position = hp + Vector2(side * (float(inf["hw"]) + tile * 0.16), tile * 0.26)
			mb.z_index = 3
			mb.add_to_group("suburb_mailbox")
			add_child(mb)

func _spawn_lawn_bears() -> void:
	# A few friendly neighbourhood KKs ambling around the FRONT lawns — pure flavour, harmless.
	# Pick yard cells with a road within ~2 tiles so the player actually walks past them.
	var lawn_cells: Array = []
	for y in range(1, _fh - 1):
		for x in range(1, _fw - 1):
			if not _wall[y][x]:
				continue
			var near_road := false
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var ny: int = y + dy
					var nx: int = x + dx
					if ny >= 0 and ny < _fh and nx >= 0 and nx < _fw and not _wall[ny][nx]:
						near_road = true
						break
				if near_road:
					break
			if near_road:
				lawn_cells.append(Vector2i(x, y))
	lawn_cells.shuffle()
	var n: int = mini(9, lawn_cells.size())
	for i in range(n):
		var c: Vector2i = lawn_cells[i]
		var b := LawnBearScript.new()
		b.position = Vector2((c.x + 0.5) * tile, (c.y + 0.5) * tile)
		add_child(b)

func _spawn_suburb_cars() -> void:
	# Park cars along the streets, ALIGNED to traffic. The sprite points up/down, so an
	# east-west street rotates it 90°; tuck each against the kerb (the yard side), spaced out.
	var car: Texture2D = _ctex("res://assets/suburb/props/car.png")
	if car == null:
		return
	var spots: Array = []
	for y in range(1, _fh - 1):
		for x in range(1, _fw - 1):
			if _wall[y][x]:
				continue
			var fl_w: bool = not _wall[y][x - 1]
			var fl_e: bool = not _wall[y][x + 1]
			var fl_n: bool = not _wall[y - 1][x]
			var fl_s: bool = not _wall[y + 1][x]
			if fl_w and fl_e and (not fl_n or not fl_s):       # E-W street with a kerb above/below
				var oy: float = -0.26 if _wall[y - 1][x] else 0.26
				spots.append({"pos": Vector2((x + 0.5) * tile, (y + 0.5 + oy) * tile), "rot": PI * 0.5})
			elif fl_n and fl_s and (not fl_w or not fl_e):     # N-S street with a kerb left/right
				var ox: float = -0.26 if _wall[y][x - 1] else 0.26
				spots.append({"pos": Vector2((x + 0.5 + ox) * tile, (y + 0.5) * tile), "rot": 0.0})
	spots.shuffle()
	var placed: Array = []
	var want: int = 10
	for sp in spots:
		if placed.size() >= want:
			break
		var pos: Vector2 = sp["pos"]
		var ok := true
		for pp in placed:
			if (pp as Vector2).distance_to(pos) < tile * 3.5:
				ok = false
				break
		if not ok:
			continue
		placed.append(pos)
		var s := Sprite2D.new()
		s.texture = car
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2.ONE * (tile * 1.55 / 80.0)   # ~1.5 tiles long
		s.rotation = sp["rot"]
		s.position = pos
		s.z_index = 1
		s.add_to_group("suburb_car")
		add_child(s)

func _spawn_friendly_bears(n: int) -> void:
	# A few harmless wandering Finn KKs on the floor (the drawn level's resident neighbours).
	for i in range(n):
		var b := LawnBearScript.new()
		b.position = _random_floor_world(tile * 6.0, true)
		add_child(b)

func _add_driveway_strip(center: Vector2, w: float, h: float) -> void:
	# Light-grey concrete drive from the house lawn out to the kerb.
	var dw := Polygon2D.new()
	var hw: float = w * 0.5
	var hh: float = h * 0.5
	dw.polygon = PackedVector2Array([Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)])
	dw.color = Color(0.52, 0.52, 0.55)
	dw.position = center
	dw.z_index = -8
	add_child(dw)

func _sewer_variants() -> Array:
	# Flooded sewers — wet mossy brick (AI-generated tiles), dark and dank. Dressed with
	# barrels/rubble/bones borrowed from the damp dungeon pack. Different murk tints per design.
	var base := {"floor": "walk", "wall": "brick", "wall_top": "brick_top",
		"face_shade": 0.68, "wall_chance": 0.55,
		"wall_props": [["damp/props/barrel", 1.1], ["damp/props/bookstack", 1.0], ["damp/props/crate", 1.0]],
		"floor_props": [["damp/props/rock", 0.9], ["damp/props/bone", 0.7], ["damp/props/skulls", 0.8], ["damp/props/skull", 0.6]]}
	return [
		_merge(base, {"amb": Color(0.13, 0.18, 0.16)}),   # 1 Green Murk
		_merge(base, {"amb": Color(0.16, 0.15, 0.12)}),   # 2 Brown Sludge
		_merge(base, {"amb": Color(0.11, 0.15, 0.21)}),   # 3 Flooded Blue
		_merge(base, {"amb": Color(0.12, 0.17, 0.15)}),   # 4 Damp Stone
		_merge(base, {"amb": Color(0.10, 0.13, 0.17)}),   # 5 Deep Drain
	]

# Sewers only: one CONNECTED water network — every connecting corridor becomes a water
# channel, and each room gets a full-span canal through its centre that meets those
# channels at the edges, so all the water links into a maze. Rooms keep dry ground to
# fight on either side of their canal. Drain grates dot the water.
func _spawn_sewer_canals() -> void:
	var water: Texture2D = _ctex("res://assets/fx/pool/water_clean.png")
	if water == null:
		water = _ctex("res://assets/fx/pool/water.png")
	if water == null:
		return
	var grate: Texture2D = _ctex("res://assets/sewer/props/grate.png")
	var wts: float = float(water.get_width())
	var tint := Color(0.5, 0.66, 0.5)   # murky green sewer water
	var is_water: Array = []   # dedupe so corridor + room canals don't double-stack
	for y in range(_fh):
		is_water.append([])
		for x in range(_fw):
			is_water[y].append(false)
	# 1) every corridor cell (floor outside the rooms) → water channel
	for y in range(_fh):
		for x in range(_fw):
			if not _wall[y][x] and not _in_any_room(x, y):
				is_water[y][x] = true
	# 2) a full-span centre canal across each room (reaches the edges → meets corridors)
	for room in _rooms:
		var horiz: bool = room.size.x >= room.size.y
		var w_cells: int = 2 if mini(room.size.x, room.size.y) >= 7 else 1
		if horiz:
			var cyc: int = room.position.y + int(room.size.y / 2)
			for ty in range(cyc - (w_cells - 1), cyc + 1):
				for tx in range(room.position.x, room.position.x + room.size.x):
					if ty >= 0 and ty < _fh and not _wall[ty][tx]:
						is_water[ty][tx] = true
		else:
			var cxc: int = room.position.x + int(room.size.x / 2)
			for tx in range(cxc - (w_cells - 1), cxc + 1):
				for ty in range(room.position.y, room.position.y + room.size.y):
					if tx >= 0 and tx < _fw and not _wall[ty][tx]:
						is_water[ty][tx] = true
	var grate_pos: Array = []
	for y in range(_fh):
		for x in range(_fw):
			if not is_water[y][x]:
				continue
			var w := Sprite2D.new()
			w.texture = water
			w.position = Vector2((float(x) + 0.5) * tile, (float(y) + 0.5) * tile)
			w.scale = Vector2(tile / wts, tile / wts)
			w.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			w.modulate = tint
			w.z_index = -2
			add_child(w)
			if grate != null and randf() < 0.04 and not _pos_too_close(w.position, grate_pos, tile * 5.0):
				grate_pos.append(w.position)
				_place_prop(grate, w.position, 0, 1.2)

func _in_any_room(x: int, y: int) -> bool:
	for r in _rooms:
		if x >= r.position.x and x < r.position.x + r.size.x and y >= r.position.y and y < r.position.y + r.size.y:
			return true
	return false

func _wheat_variants() -> Array:
	# Outdoor wheat field. "Walls" are standing-wheat hedgerows, so the BSP layout
	# reads as a maze of cut paths through the crop. Flat sunny daylight (set in
	# _ready). Decor (haystack field cover, haybale pyramids, grass clearings) is placed
	# by _spawn_wheat_decor() — the busted barn/tractor/fence sprites are NOT used.
	var base := {"floor": "ground", "wall": "stalks", "wall_top": "stalks_top",
		"face_shade": 0.9, "wall_chance": 0.5, "wall_props": [], "floor_props": []}
	var v: Array = []
	for i in range(5):
		v.append(_merge(base, {"amb": Color(0.98, 0.95, 0.80)}))
	return v

# Field of Wheat only: scatter haystacks as field cover (you partly vanish into them),
# stack haybales in real pyramid piles, and drop the odd grass clearing in a corner.
func _spawn_wheat_decor() -> void:
	var haystack: Texture2D = _ctex("res://assets/wheat/props/haystack.png")
	var haybale: Texture2D = _ctex("res://assets/wheat/props/haybale.png")
	for room in _rooms:
		if room == _start_room or room == _boss_room:
			continue
		var rx: int = room.position.x
		var ry: int = room.position.y
		var rsx: int = room.size.x
		var rsy: int = room.size.y
		# HAYSTACK field cover — open rooms get a scatter of tall hay you walk into;
		# bigger rooms get denser patches ("you disappear into the wheat field").
		if haystack != null and rsx >= 4 and rsy >= 4 and randf() < 0.75:
			# Clump them — a few tight stands of tall hay rather than an even sprinkle.
			var clumps: int = clampi(int(float(rsx * rsy) / 24.0), 1, 4)
			for c in range(clumps):
				var ccx: float = (float(rx) + randf_range(1.0, float(rsx) - 1.0)) * tile
				var ccy: float = (float(ry) + randf_range(1.0, float(rsy) - 1.0)) * tile
				for i in range(randi_range(3, 6)):
					var off := Vector2(randf_range(-tile * 0.9, tile * 0.9), randf_range(-tile * 0.9, tile * 0.9))
					_place_prop(haystack, Vector2(ccx, ccy) + off, 0, randf_range(1.1, 1.7))
		# HAYBALE pyramid pile — placed INSIDE the room with clearance above (the stack
		# rises ~1.3 tiles, so keep it ≥3 cells off the top wall or the top bale clips in).
		if haybale != null and rsy >= 5 and randf() < 0.45:
			var pbx: int = randi_range(rx + 1, rx + rsx - 2)
			var pby: int = randi_range(ry + 3, ry + rsy - 1)
			_place_haybale_pyramid(haybale, Vector2((float(pbx) + 0.5) * tile, (float(pby) + 0.5) * tile))
		# (grass clearings removed — the grass asset read badly in the field)

func _place_haybale_pyramid(tex: Texture2D, base: Vector2) -> void:
	# 3-2-1 stack: each higher row is shorter and sits up/back, like piled bales.
	var bw: float = tile * 0.66
	var rows: Array = [3, 2, 1]
	for r in range(rows.size()):
		var n: int = rows[r]
		var ry: float = base.y - float(r) * tile * 0.42
		var startx: float = base.x - float(n - 1) * bw * 0.5
		for i in range(n):
			_place_prop(tex, Vector2(startx + float(i) * bw, ry), 0, 0.95, -1)

# Pool Rooms only: drop a real swimming pool (the pre-made pool_big sprite, which has
# its own tiled coping border) into the bigger rooms, with a curvy slide feeding in and
# a colourful inner tube floating on the water.
func _spawn_pools() -> void:
	var night: bool = _variant > 3
	var pool_tex: Texture2D = _ctex("res://assets/fx/pool/pool_big.png")
	if pool_tex == null:
		return
	var slide: Texture2D = _ctex("res://assets/fx/pool/slide_curvy.png")
	var chair: Texture2D = _ctex("res://assets/backrooms/props/furniture/chair_padded.png")
	var tubes: Array = []
	for nm in ["tube_blue", "tube_lime", "tube_red"]:
		var t: Texture2D = _ctex("res://assets/fx/pool/%s.png" % nm)
		if t != null:
			tubes.append(t)
	var ptw: float = float(pool_tex.get_width())
	var pth: float = float(pool_tex.get_height())
	var night_tint := Color(0.55, 0.64, 0.82)   # cool, dimmed for the night pool
	for room in _rooms:
		if room == _start_room or room == _boss_room:
			continue
		if room.size.x < 6 or room.size.y < 6 or randf() > 0.7:
			continue
		# Pool footprint, inset 2 cells so there's a deck to fight on around it.
		var px0: int = room.position.x + 2
		var py0: int = room.position.y + 2
		var px1: int = room.position.x + room.size.x - 3
		var py1: int = room.position.y + room.size.y - 3
		if px1 - px0 < 2 or py1 - py0 < 2:
			continue
		var rw: float = float(px1 - px0 + 1) * tile
		var rh: float = float(py1 - py0 + 1) * tile
		var cx: float = (float(px0 + px1 + 1) * 0.5) * tile
		var cy: float = (float(py0 + py1 + 1) * 0.5) * tile
		# the pool sprite, scaled to FILL the footprint (it's a proper top-down pool).
		var pool := Sprite2D.new()
		pool.texture = pool_tex
		pool.position = Vector2(cx, cy)
		pool.scale = Vector2(rw / ptw, rh / pth)
		pool.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # no sub-pixel shimmer on camera move
		pool.z_index = -2
		if night:
			pool.modulate = night_tint
		add_child(pool)
		# curvy slide — 25% bigger, placed at a varied spot along the top edge so its
		# bottom END dips INTO the water (not stranded in a corner).
		if slide != null:
			var sx: float = randf_range(float(px0) + 0.6, float(px1) + 0.4) * tile
			var sl := _place_prop(slide, Vector2(sx, (float(py0) + 0.5) * tile), 2, 3.75, 0)
			sl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # stop the quarter-pixel vibrate
			if night:
				sl.modulate = night_tint
		# an inner tube bobbing on the water
		if not tubes.is_empty():
			var off := Vector2(randf_range(-rw * 0.2, rw * 0.2), randf_range(-rh * 0.2, rh * 0.2))
			_place_prop(tubes[randi() % tubes.size()], Vector2(cx, cy) + off, -1, 1.1, -1)
		# NIGHT: a poolside round table with two chairs on the deck, like people lounging.
		if night and chair != null and randf() < 0.6:
			var ty: float = (float(py1) + 1.7) * tile
			var tx: float = cx + randf_range(-tile, tile)
			_place_prop(chair, Vector2(tx - tile * 0.7, ty), 0, 1.0, 0)
			_place_prop(chair, Vector2(tx + tile * 0.7, ty), 0, 1.0, 1)

# Pool Rooms (NIGHT only): mount coloured neon light bars flush on exposed wall faces,
# oriented along the wall. Each glows its own colour (HDR-bright modulate → the scene's
# bloom picks it up). Sparse — a few accent lights, not a wall of them. The DAY pool is
# left clean (bright daylight, no fixtures).
func _spawn_pool_wall_fixtures() -> void:
	if _variant <= 3:
		return   # night variants only
	var strip: Texture2D = _ctex("res://assets/poolrooms/props/neon_strip.png")
	if strip == null:
		return
	# HDR colours (channels > 1) so they bloom as fluorescent neon — pink, blue, violet, cyan.
	var neon := [Color(2.2, 0.6, 1.4), Color(0.4, 0.9, 2.2), Color(1.3, 0.6, 2.2), Color(0.5, 2.0, 1.9)]
	# Detect contiguous wall RUNS per exposed face and place lights evenly + centred on
	# each run (so a run is symmetrical about its midpoint), not scattered randomly.
	for nd in [Vector2i(0, -1), Vector2i(0, 1)]:   # horizontal faces → scan rows
		for y in range(1, _fh - 1):
			var x: int = 1
			while x < _fw - 1:
				if _wall[y][x] and not _wall[y + nd.y][x]:
					var x0: int = x
					while x < _fw - 1 and _wall[y][x] and not _wall[y + nd.y][x]:
						x += 1
					_run_lights(true, y, x0, x - 1, nd, strip, neon)
				else:
					x += 1
	for nd2 in [Vector2i(-1, 0), Vector2i(1, 0)]:   # vertical faces → scan columns
		for x2 in range(1, _fw - 1):
			var y2: int = 1
			while y2 < _fh - 1:
				if _wall[y2][x2] and not _wall[y2][x2 + nd2.x]:
					var y0: int = y2
					while y2 < _fh - 1 and _wall[y2][x2] and not _wall[y2][x2 + nd2.x]:
						y2 += 1
					_run_lights(false, x2, y0, y2 - 1, nd2, strip, neon)
				else:
					y2 += 1

# Place N evenly-spaced, centred fluorescent bars along one wall run, each with a soft
# forward-only colour aura (a glow pushed INTO the room — it can't go through the wall).
func _run_lights(horiz: bool, fixed: int, a0: int, a1: int, nd: Vector2i, strip: Texture2D, neon: Array) -> void:
	var L: int = a1 - a0 + 1
	# Far fewer lights now: skip short runs and ~45% of runs entirely, ~1 light per 10 tiles.
	if L < 3 or randf() < 0.45:
		return
	var n: int = clampi(int(round(float(L) / 10.0)), 1, L)
	var col: Color = neon[randi() % neon.size()]
	var rot: float = 0.0 if horiz else PI * 0.5
	for i in range(n):
		var c: float = float(a0) * tile + (float(i) + 0.5) * float(L) * tile / float(n)
		var pos: Vector2
		if horiz:
			pos = Vector2(c, (float(fixed) + 0.5) * tile + float(nd.y) * tile * 0.42)
		else:
			pos = Vector2((float(fixed) + 0.5) * tile + float(nd.x) * tile * 0.42, c)
		var s := _place_prop(strip, pos, 4, 1.4, 0, rot)
		s.modulate = col
		# forward aura — glow hugs the light (small offset), brighter + more diffused
		var glow := Sprite2D.new()
		glow.texture = LightTex
		glow.position = pos + Vector2(nd.x, nd.y) * (tile * 0.45)
		var gs: float = (tile * 3.2) / float(LightTex.get_width())
		glow.scale = Vector2(gs, gs)
		glow.modulate = Color(col.r * 0.85, col.g * 0.85, col.b * 0.85, 0.78)
		glow.z_index = 1
		add_child(glow)
		# expansive, super-faint OUTER halo on top of the bright core — reads like soft
		# volumetric haze: dense colour at the light, fading way out to a pale tint.
		var halo := Sprite2D.new()
		halo.texture = LightTex
		halo.position = pos + Vector2(nd.x, nd.y) * (tile * 1.0)
		var hls: float = (tile * 7.5) / float(LightTex.get_width())
		halo.scale = Vector2(hls, hls)
		halo.modulate = Color(col.r * 0.5, col.g * 0.5, col.b * 0.5, 0.15)
		halo.z_index = 1
		add_child(halo)

func _poolrooms_variants() -> Array:
	# Liminal indoor pool. Two moods carried by the tile palette + light colour:
	# DAY (sunlit cream ceramic, warm fluorescents) and NIGHT (cool grey ceramic,
	# cold cyan fluorescents). Walls stay bright (ceramic), so face_shade is high.
	# poollights are NOT scattered here — _spawn_pool_wall_fixtures() mounts them flush
	# on wall faces (oriented along the wall). Real pools are carved by _spawn_pools().
	var day := {"floor": "deck", "wall": "tile", "wall_top": "top", "face_shade": 0.86,
		"wall_chance": 0.5,
		"wall_props": [["lifering", 0.85], ["ladder", 1.1]],
		"floor_props": [["drain", 0.6], ["floatring", 0.8]]}
	var night := {"floor": "deck_n", "wall": "tile_n", "wall_top": "top_n", "face_shade": 0.8,
		"wall_chance": 0.5,
		"wall_props": [["lifering", 0.85], ["ladder", 1.1]],
		"floor_props": [["drain", 0.6], ["floatring", 0.8]]}
	return [
		_merge(day, {"amb": Color(0.50, 0.50, 0.46)}),     # 1 Sunlit
		_merge(day, {"amb": Color(0.46, 0.48, 0.50)}),     # 2 Overcast Day
		_merge(day, {"amb": Color(0.52, 0.50, 0.42)}),     # 3 Warm Afternoon
		_merge(night, {"amb": Color(0.16, 0.20, 0.26)}),   # 4 Midnight
		_merge(night, {"amb": Color(0.12, 0.16, 0.22)}),   # 5 Deep Night
	]

func _space_variants(CY: Color) -> Array:
	# Moon/asteroid surface — dark void ambient, rocky floor, scattered craters and
	# asteroid debris. One accent prop glows faint cyan (impact energy).
	var base := {"floor": "floor", "wall": "wall", "wall_top": "wall_top",
		"face_shade": 0.7, "wall_chance": 0.6,
		"wall_props": [["boulder3", 1.0], ["boulder4", 1.0], ["rubble", 0.9], ["ramp", 1.0]],
		"floor_props": [["smallrock", 0.7], ["boulder1", 0.85], ["boulder2", 0.85], ["rubble", 0.8]]}
	return [
		_merge(base, {"amb": Color(0.10, 0.12, 0.22)}),   # 1 Deep Space
		_merge(base, {"amb": Color(0.20, 0.10, 0.13)}),   # 2 Red Nebula
		_merge(base, {"amb": Color(0.10, 0.18, 0.15)}),   # 3 Alien Green
		_merge(base, {"amb": Color(0.16, 0.11, 0.22)}),   # 4 Cosmic Violet
		_merge(base, {"amb": Color(0.14, 0.14, 0.16)}),   # 5 Lunar Gray
	]

func _cyber_variants(CY: Color, MA: Color, RE: Color, WA: Color, GR: Color, PU: Color) -> Array:
	# Built from the player's own cut tileset (floors + 32px wall units cropped from
	# the 48x32 facades). Each design swaps the wall facade, floor, mood + neon dressing.
	# Shared neon street props are pulled from the neon pack via "neon/props/…".
	# Reskinned to dylestorm's "Pixel Cyberpunk Interior" pack: metal panel floor + server
	# racks / consoles / vending / neon signs / arcade cabs as wall fixtures, chairs + bunks
	# as floor clutter. Walls keep the cut facade tiles (the interior pack ships no wall tile).
	var tech := func(glow: Color) -> Array:
		return [["server_bank", 2.6], ["server_desk", 2.2], ["console", 1.9],
			["vending1", 1.4], ["vending2", 1.4], ["cabinet", 1.6],
			["door_orange", 1.5], ["door", 1.5],
			["neon_home", 1.7, MA, 1.0, 3.0], ["arcade", 1.9, glow, 0.9, 2.8]]
	var furn := [["chair_red", 0.9], ["chair_red2", 0.9], ["chair_blue", 0.9],
		["bed", 1.3], ["bed_blue", 1.3], ["bed_orange", 1.3]]
	var base := {"floor": "floor_interior", "wall_top": "wall_top", "face_shade": 0.82,
		"wall_chance": 0.7, "floor_chance": 0.55}
	return [
		# 1 Server Farm
		_merge(base, {"wall": "circuits", "amb": Color(0.13, 0.17, 0.25),
			"wall_props": tech.call(CY), "floor_props": furn}),
		# 2 Red Sector
		_merge(base, {"wall": "door", "amb": Color(0.24, 0.11, 0.14),
			"wall_props": tech.call(RE), "floor_props": furn}),
		# 3 Habitation Block
		_merge(base, {"wall": "windows", "amb": Color(0.16, 0.13, 0.26),
			"wall_props": tech.call(PU), "floor_props": furn}),
		# 4 Toxic Lab
		_merge(base, {"wall": "drips", "amb": Color(0.12, 0.20, 0.16),
			"wall_props": tech.call(GR), "floor_props": furn}),
		# 5 Checkpoint
		_merge(base, {"wall": "doors", "amb": Color(0.22, 0.18, 0.12),
			"wall_props": tech.call(WA), "floor_props": furn}),
	]

func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var r: Dictionary = a.duplicate(true)
	for k in b:
		r[k] = b[k]
	return r

func _damp_variants(WA: Color, CY: Color) -> Array:
	# Each design = a different floor/wall material + prop dressing from the kit.
	var dec := [["brazier", 1.1, WA, 1.0, 3.2]]
	return [
		# 1 Mossy Catacomb
		{"floor": "cobble", "wall": "stone_dark", "amb": Color(0.17, 0.18, 0.20),
			"wall_props": [["skullbanner", 1.6], ["barrel", 1.1], ["crate", 1.0], ["bookstack", 1.0]] + dec,
			"floor_props": [["mushrooms", 0.9], ["bone", 0.6], ["skulls", 0.8], ["rock", 1.0]]},
		# 2 Stone Keep
		{"floor": "brick", "wall": "brick", "amb": Color(0.20, 0.18, 0.16),
			"wall_props": [["throne", 1.6], ["chest", 1.1], ["barrel", 1.1], ["crate2", 1.0]] + dec,
			"floor_props": [["gold", 0.8], ["crate", 1.0], ["box", 0.7]]},
		# 3 Overgrown Ruin
		{"floor": "green", "wall": "cobble", "amb": Color(0.16, 0.21, 0.17),
			"wall_props": [["vine", 1.2], ["fern", 1.0], ["stalagmite", 1.3], ["rock2", 1.1]],
			"floor_props": [["mushrooms", 0.9], ["mushroom3", 0.8], ["fern2", 0.9], ["rock3", 1.0]]},
		# 4 Flooded Crypt
		{"floor": "blue", "wall": "stone_dark", "amb": Color(0.13, 0.17, 0.24),
			"wall_props": [["cauldron", 1.0, CY, 0.7, 2.6], ["skulls2", 0.9], ["rock", 1.0], ["pot", 1.0]],
			"floor_props": [["bone", 0.6], ["skull", 0.6], ["rock2", 1.0], ["skulls", 0.8]]},
		# 5 Crystal Cavern
		{"floor": "stone_dark", "wall": "cobble", "amb": Color(0.13, 0.15, 0.22),
			"wall_props": [["crystal2", 1.3, CY, 0.95, 3.2], ["stalagmite", 1.3], ["boulder", 1.7]] + dec,
			"floor_props": [["crystal", 0.95, CY, 0.6, 2.0], ["rock2", 1.0], ["gold", 0.7]]},
	]

func _hand_variants(WA: Color) -> Array:
	# Pen-and-ink dungeon: one ink floor/wall, recoloured per design by the ambient
	# tint, with white line-art props. Torches glow warm.
	# Torches are NOT placed via perimeter props — _spawn_hand_wall_torches()
	# mounts them on the LEFT/RIGHT exposed faces of wall runs (hand level only).
	var torch := []
	var base := {"floor": "floor", "wall": "wall", "wall_top": "wall_top", "face_shade": 0.72}
	return [
		# Pillars and crate/barrel clusters are placed by dedicated hand passes
		# (_spawn_hand_pillars / _spawn_hand_clusters), so they're kept OUT of these
		# scatter pools — otherwise they'd also appear as lone singles.
		# 1 Ink Slate (neutral)
		_merge(base, {"amb": Color(0.20, 0.21, 0.26),
			"wall_props": [["isoChest", 1.0]] + torch,
			"floor_props": [["isobones", 0.7], ["isorock", 0.9]]}),
		# 2 Sepia Catacomb
		_merge(base, {"amb": Color(0.26, 0.21, 0.15),
			"wall_props": [["isoChest2", 1.0], ["isobookcase", 1.4]] + torch,
			"floor_props": [["isobones", 0.7], ["isobones2", 0.7], ["isogold", 0.6], ["isorock2", 0.9]]}),
		# 3 Moonlit Blue
		_merge(base, {"amb": Color(0.15, 0.18, 0.27),
			"wall_props": [["isobed", 1.0], ["isobanner", 1.3]] + torch,
			"floor_props": [["isorock", 0.9], ["isobush", 0.8], ["isobones", 0.7]]}),
		# 4 Cursed Crimson
		_merge(base, {"amb": Color(0.27, 0.14, 0.15),
			"wall_props": [["isoChest", 1.0], ["isobanner", 1.3]] + torch,
			"floor_props": [["isobones2", 0.7], ["isogold", 0.6], ["isolever", 0.8]]}),
		# 5 Mossy Green
		_merge(base, {"amb": Color(0.16, 0.23, 0.17),
			"wall_props": [["isotree", 1.6], ["isobush", 1.0]] + torch,
			"floor_props": [["isobush", 0.8], ["isorock2", 0.9], ["isobones", 0.7]]}),
	]

func _floor_texture() -> Texture2D:
	if _lvl_floor != null:
		return _lvl_floor
	return _bk_floor if _bk_floor != null else FloorTex

func _wall_texture() -> Texture2D:
	if _lvl_wall != null:
		return _lvl_wall
	return _bk_wall if _bk_wall != null else WallTex

# Cap texture for the lit TOP of walls. A theme can supply a plain slab so roofs
# don't read as a wall of floating windows; otherwise caps with its body tex.
func _wall_top_texture() -> Texture2D:
	if _lvl_wall_top != null:
		return _lvl_wall_top
	return _wall_texture()

func _load_tex_opt(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

# Load a PNG and build a texture WITH mipmaps so tight high-frequency detail
# doesn't shimmer/moiré when the camera moves (the backrooms wall flicker fix).
func _load_tex_mip(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return _load_tex_opt(path)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return _load_tex_opt(path)
	var img := Image.new()
	if img.load_png_from_buffer(f.get_buffer(f.get_length())) != OK:
		return _load_tex_opt(path)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _has_los(a: Vector2, b: Vector2) -> bool:
	# Clear line of sight if no wall (layer 1) blocks the segment a→b.
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(a, b)
	q.collision_mask = 1
	return space.intersect_ray(q).is_empty()

func _build_backrooms_lighting() -> void:
	# Flat, evenly-lit fluorescent space — no dramatic shadows (that IS the look).
	# Kept a touch below 0.8 so light-coloured mobs (growler/shrinkwrap) don't blow
	# out / bloom against the bright floor.
	_ambient.color = Color(0.74, 0.72, 0.63)
	_apply_pack(5)            # locked to the chosen pack; switcher panel removed

# Swap the wall + floor textures to asset pack 1-5 live (re-textures the existing
# floor + wall sprites, no regen). Each pack is a real CC0 texture tinted yellow.
func _apply_pack(n: int) -> void:
	n = clampi(n, 1, 5)
	_pack = n
	ArpgState.backrooms_pack = n
	# Mipmapped so the tight pattern doesn't shimmer when the camera moves.
	var w := _load_tex_mip("res://assets/backrooms_pack%d_wall.png" % n)
	var f := _load_tex_mip("res://assets/backrooms_pack%d_floor.png" % n)
	if w != null:
		_bk_wall = w
	if f != null:
		_bk_floor = f
	const MIP := CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if is_instance_valid(_bk_floor_node):
		_bk_floor_node.texture = _floor_texture()
		_bk_floor_node.texture_filter = MIP
	var wt: Texture2D = _wall_texture()
	var ts: float = float(wt.get_width())
	for body in get_tree().get_nodes_in_group("walls"):
		var top := body.get_node_or_null("Top") as Sprite2D
		if top != null:
			top.texture = wt
			top.scale = Vector2(tile / ts, tile / ts)
			top.texture_filter = MIP
		var face := body.get_node_or_null("Face") as Sprite2D
		if face != null:
			face.texture = wt
			face.scale = Vector2(tile / ts, (tile * BK_WALL_FACE) / ts)
			face.texture_filter = MIP
	if not _pack_buttons.is_empty():
		_style_level_buttons(_pack_buttons, _pack)

func _build_pack_panel() -> void:
	var layer := CanvasLayer.new()
	layer.name = "BackroomsPanel"
	layer.layer = 7
	add_child(layer)
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0; panel.anchor_right = 1.0
	panel.offset_left = -210.0; panel.offset_top = 182.0; panel.offset_right = -12.0
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.05, 0.04, 0.08, 0.9)
	psb.set_border_width_all(1); psb.border_color = Color(0.7, 0.62, 0.3, 0.7)
	psb.set_corner_radius_all(6)
	psb.content_margin_left = 8; psb.content_margin_right = 8
	psb.content_margin_top = 6; psb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", psb)
	layer.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)
	_pack_buttons = _build_level_row(vb, "ASSET PACK", 5, _apply_pack)
	_style_level_buttons(_pack_buttons, _pack)

# ── loot ───────────────────────────────────────────────────────────────────
func _spawn_loot(pos: Vector2, item: Dictionary) -> void:
	var rar: int = int(item.get("rarity", 0))
	var col: Color = ArpgState.RARITY_COLORS[rar]
	var area := Area2D.new()
	area.position = pos
	area.collision_mask = 1
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 34.0
	cs.shape = c
	area.add_child(cs)
	if not _flat_lit():   # flat-lit levels (backrooms / hand / cyber2077): no pickup aura
		var lamp := PointLight2D.new()
		lamp.texture = LightTex
		lamp.color = col
		lamp.energy = 1.3
		lamp.texture_scale = 1.3
		area.add_child(lamp)
	# Weapon-type icon instead of a generic diamond: ball weapons show the bouncy
	# ball, everything else shows a pizza slice (tinted to the weapon's colour).
	var is_ball: bool = bool(item.get("ball", false))
	var icon := Sprite2D.new()
	var proj_t: Texture2D = _load_tex_mip("res://assets/projectiles/%s.png" % String(item["proj"])) if item.has("proj") else null
	icon.texture = proj_t if proj_t != null else (BallIconTex if is_ball else PizzaIconTex)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.scale = Vector2(1.2, 1.2) if proj_t != null else Vector2(0.62, 0.62)
	icon.modulate = item.get("color", Color(1, 1, 1)) if is_ball else Color(1, 1, 1)
	area.add_child(icon)
	var ibob := icon.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	ibob.tween_property(icon, "position", Vector2(0, -7), 0.9)
	ibob.tween_property(icon, "position", Vector2(0, 0), 0.9)
	# Auto-collect on contact (Vampire-Survivors style). A drop levels a weapon you
	# already hold, fills a free secondary slot as an AUTO-FIRING weapon, or (slots
	# full) levels your weakest weapon. Your hero's PRIMARY is never swapped out — so
	# no more obnoxious "give up the weapon you like?" pop-up.
	area.body_entered.connect(func(b: Node) -> void:
		if b.is_in_group("player"):
			var msg: String = ArpgState.collect_weapon(item)
			ArpgState.emit_signal("toast", msg, item.get("color", Color(1.0, 0.85, 0.4)))
			if is_instance_valid(area):
				area.queue_free())
	add_child(area)

# ── weapon pickup comparison ─────────────────────────────────────────────────
func _weapon_is_junk(item: Dictionary) -> bool:
	# True when the floor weapon's DPS is 10+ below your current weapon — not worth
	# stopping for, so it auto-sells instead of opening the compare screen.
	if ArpgState.weapon.is_empty() or item.is_empty():
		return false
	if ArpgState.depth <= 1:
		return false   # floor 1: show every drop so early choices aren't auto-eaten
	var fe: Dictionary = ArpgState.weapon_eval(item)
	var ce: Dictionary = ArpgState.weapon_eval(ArpgState.weapon)
	return float(fe.get("dps", 0.0)) <= float(ce.get("dps", 0.0)) - 10.0

func _offer_weapon(item: Dictionary, area: Area2D) -> void:
	if _weapon_popup_open:
		return
	_weapon_popup_open = true
	get_tree().paused = true
	var cur: Dictionary = ArpgState.weapon

	var layer := CanvasLayer.new()
	layer.name = "WeaponCompare"
	layer.layer = 88
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)

	# Centred menu panel (reliable — sizes to content via CenterContainer).
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var panel := PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.07, 0.07, 0.10, 0.97)
	psb.set_border_width_all(2)
	psb.border_color = Color(0.78, 0.64, 0.36, 0.55)
	psb.set_corner_radius_all(14)
	psb.content_margin_left = 28; psb.content_margin_right = 28
	psb.content_margin_top = 22; psb.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", psb)
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	panel.add_child(root)

	var title := Label.new()
	title.text = "⚔   WEAPON FOUND"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	root.add_child(title)
	var sub := Label.new()
	sub.text = "Keep what you have, or swap to the one on the floor?"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
	root.add_child(sub)

	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 48)
	root.add_child(cards)
	cards.add_child(_weapon_card("EQUIPPED", cur, {}))
	var vs := Label.new()
	vs.text = "VS"
	vs.add_theme_font_size_override("font_size", 26)
	vs.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cards.add_child(vs)
	cards.add_child(_weapon_card("ON FLOOR", item, cur))

	root.add_child(HSeparator.new())
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 16)
	root.add_child(btns)
	var keep := Button.new()
	keep.text = "Q   Sell Drop  (+%d)" % ArpgState.weapon_sell_value(item)
	keep.custom_minimum_size = Vector2(0, 52)
	keep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keep.add_theme_font_size_override("font_size", 20)
	keep.shortcut = _key_shortcut(KEY_Q)
	keep.pressed.connect(_close_weapon_popup.bind(layer, area, false, item))
	btns.add_child(keep)
	var take := Button.new()
	take.text = "E   Equip This  ⤵"
	take.custom_minimum_size = Vector2(0, 52)
	take.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	take.add_theme_font_size_override("font_size", 20)
	take.shortcut = _key_shortcut(KEY_E)
	take.pressed.connect(_close_weapon_popup.bind(layer, area, true, item))
	btns.add_child(take)
	take.grab_focus()

func _anchor_quadrant(ctrl: Control, q: int, margin: float) -> void:
	# Position a content-sized control in one of 4 screen regions: top-right,
	# bottom-right, bottom-left, or centre. Uses corner anchors + grow direction so
	# the panel keeps its own min size and just hugs the chosen corner.
	match q:
		0:  # top-right
			ctrl.anchor_left = 1.0; ctrl.anchor_right = 1.0; ctrl.anchor_top = 0.0; ctrl.anchor_bottom = 0.0
			ctrl.grow_horizontal = Control.GROW_DIRECTION_BEGIN; ctrl.grow_vertical = Control.GROW_DIRECTION_END
			ctrl.offset_left = -margin; ctrl.offset_right = -margin; ctrl.offset_top = margin; ctrl.offset_bottom = margin
		1:  # bottom-right
			ctrl.anchor_left = 1.0; ctrl.anchor_right = 1.0; ctrl.anchor_top = 1.0; ctrl.anchor_bottom = 1.0
			ctrl.grow_horizontal = Control.GROW_DIRECTION_BEGIN; ctrl.grow_vertical = Control.GROW_DIRECTION_BEGIN
			ctrl.offset_left = -margin; ctrl.offset_right = -margin; ctrl.offset_top = -margin; ctrl.offset_bottom = -margin
		2:  # bottom-left
			ctrl.anchor_left = 0.0; ctrl.anchor_right = 0.0; ctrl.anchor_top = 1.0; ctrl.anchor_bottom = 1.0
			ctrl.grow_horizontal = Control.GROW_DIRECTION_END; ctrl.grow_vertical = Control.GROW_DIRECTION_BEGIN
			ctrl.offset_left = margin; ctrl.offset_right = margin; ctrl.offset_top = -margin; ctrl.offset_bottom = -margin
		_:  # centre
			ctrl.set_anchors_preset(Control.PRESET_CENTER)
			ctrl.grow_horizontal = Control.GROW_DIRECTION_BOTH; ctrl.grow_vertical = Control.GROW_DIRECTION_BOTH

func _key_shortcut(keycode: Key) -> Shortcut:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	var sc := Shortcut.new()
	sc.events = [ev]
	return sc

func _weapon_card(badge: String, w: Dictionary, compare: Dictionary) -> Control:
	var rar: int = clampi(int(w.get("rarity", 0)), 0, 3)
	var rcol: Color = ArpgState.RARITY_COLORS[rar]
	var ev: Dictionary = ArpgState.weapon_eval(w)
	var cv: Dictionary = ArpgState.weapon_eval(compare) if not compare.is_empty() else {}
	var neutral: bool = compare.is_empty()

	# Clean card: rarity-bordered panel with a coloured header (badge + name +
	# rarity) over a dark stat body.
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(264, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.11, 0.15, 1.0)
	sb.border_color = rcol
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	card.add_child(vb)

	# Header bar tinted by rarity.
	var header := PanelContainer.new()
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(rcol.r * 0.4 + 0.05, rcol.g * 0.4 + 0.05, rcol.b * 0.4 + 0.05, 1.0)
	hsb.corner_radius_top_left = 8; hsb.corner_radius_top_right = 8
	hsb.content_margin_left = 12; hsb.content_margin_right = 12
	hsb.content_margin_top = 9; hsb.content_margin_bottom = 9
	header.add_theme_stylebox_override("panel", hsb)
	vb.add_child(header)
	var hvb := VBoxContainer.new()
	hvb.add_theme_constant_override("separation", 1)
	header.add_child(hvb)
	var bl := Label.new()
	bl.text = badge
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bl.add_theme_font_size_override("font_size", 12)
	bl.add_theme_color_override("font_color", Color(0.85, 0.86, 0.92))
	hvb.add_child(bl)
	var nm := Label.new()
	var lvl: int = int(w.get("lvl", 0))
	nm.text = String(w.get("name", "Weapon")) + ("  Lv%d" % lvl if lvl > 0 else "")
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.add_theme_font_size_override("font_size", 21)
	nm.add_theme_color_override("font_color", Color(1, 1, 1))
	hvb.add_child(nm)
	var rname := Label.new()
	rname.text = ArpgState.RARITY_NAMES[rar].to_upper()
	rname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rname.add_theme_font_size_override("font_size", 12)
	rname.add_theme_color_override("font_color", rcol.lightened(0.25))
	hvb.add_child(rname)

	# Stat body.
	var body := MarginContainer.new()
	for mm in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		body.add_theme_constant_override(mm, 14)
	vb.add_child(body)
	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 6)
	body.add_child(stats)

	_stat_row(stats, "DPS",        "%.1f" % float(ev.dps),  float(ev.dps),  float(cv.get("dps", ev.dps)),  neutral)
	_stat_row(stats, "Damage",     "%d" % int(ev.dmg),      float(ev.dmg),  float(cv.get("dmg", ev.dmg)),  neutral)
	_stat_row(stats, "Fire Rate",  "%.2f/s" % float(ev.rate), float(ev.rate), float(cv.get("rate", ev.rate)), neutral)
	_stat_row(stats, "Shots",      "%d" % int(ev.count),    float(ev.count), float(cv.get("count", ev.count)), neutral)
	_stat_row(stats, "Speed",      "%d" % int(round(float(ev.speed))), float(ev.speed), float(cv.get("speed", ev.speed)), neutral)
	if int(ev.pierce) > 0 or int(cv.get("pierce", 0)) > 0:
		_stat_row(stats, "Pierce", "%d" % int(ev.pierce), float(ev.pierce), float(cv.get("pierce", ev.pierce)), neutral)
	if bool(ev.ball) or bool(cv.get("ball", false)):
		_stat_row(stats, "Bounces", "%d" % int(ev.bounces), float(ev.bounces), float(cv.get("bounces", ev.bounces)), neutral)
	return card

func _stat_row(vb: VBoxContainer, name: String, text: String, val: float, ref: float, neutral: bool) -> void:
	var row := HBoxContainer.new()
	var nl := Label.new()
	nl.text = name
	nl.add_theme_font_size_override("font_size", 15)
	nl.add_theme_color_override("font_color", Color(0.72, 0.74, 0.8))
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(nl)
	var vl := Label.new()
	var arrow: String = ""
	var col: Color = Color(0.95, 0.95, 1.0)
	if not neutral:
		if val > ref + 0.001:
			col = Color(0.45, 0.95, 0.5); arrow = "  ▲"
		elif val < ref - 0.001:
			col = Color(0.95, 0.42, 0.42); arrow = "  ▼"
		else:
			col = Color(0.7, 0.72, 0.78)
	vl.text = text + arrow
	vl.add_theme_font_size_override("font_size", 15)
	vl.add_theme_color_override("font_color", col)
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(vl)
	vb.add_child(row)

func _close_weapon_popup(layer: CanvasLayer, area: Area2D, take: bool, item: Dictionary) -> void:
	if take:
		ArpgState.try_equip(item)   # carries half your current weapon level
	else:
		# Decline = sell the drop for coins (you get paid for passing on it).
		var sell: int = ArpgState.weapon_sell_value(item)
		ArpgState.gold += sell
		ArpgState.emit_signal("stats_changed")
		ArpgState.emit_signal("toast", "+%d gold (sold drop)" % sell, Color(1.0, 0.85, 0.4))
	# Either way the floor drop is consumed.
	if is_instance_valid(area):
		area.queue_free()
	_near_loot_item = {}
	_near_loot_area = null
	if is_instance_valid(layer):
		layer.queue_free()
	_weapon_popup_open = false
	get_tree().paused = false

var _levelup_queue: int = 0
var _levelup_open: bool = false

func _on_level_up(_lvl: int) -> void:
	Juice.shake(0.3)
	if is_instance_valid(_player) and _player.has_method("heal"):
		_player.heal(2)   # small heal reward
	_refresh_hud()
	# Vampire-Survivors-style: pause and offer a choice of upgrades.
	_levelup_queue += 1
	if not _levelup_open:
		_show_level_up()

func _show_level_up() -> void:
	var opts: Array = ArpgState.level_up_options()
	if opts.is_empty():
		_levelup_queue = maxi(0, _levelup_queue - 1)
		return
	_levelup_open = true
	get_tree().paused = true
	var layer := CanvasLayer.new()
	layer.name = "LevelUpLayer"
	layer.layer = 92
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.05, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var title := Label.new()
	title.text = "LEVEL  %d" % ArpgState.level
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.45, 0.95, 0.85))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 6)
	var lf := FontFile.new()
	if lf.load_dynamic_font("res://assets/anton.ttf") == OK:
		title.add_theme_font_override("font", lf)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.0; title.anchor_right = 1.0
	title.offset_top = 150.0
	layer.add_child(title)
	# ── current-stats panel (left) — hovering a card previews its effect ──────────
	var sp := PanelContainer.new()
	var spsb := StyleBoxFlat.new()
	spsb.bg_color = Color(0.08, 0.10, 0.15, 0.96)
	spsb.set_border_width_all(2); spsb.border_color = Color(0.27, 0.85, 0.74, 0.5)
	spsb.set_corner_radius_all(12); spsb.set_content_margin_all(16)
	sp.add_theme_stylebox_override("panel", spsb)
	# Centre the whole [stats | cards] group in the viewport (was hard-coded left).
	var _vp: Vector2 = get_viewport_rect().size
	var _group_w: float = 258.0 + 54.0 + 776.0   # stats + gap + 3 cards
	var _gx: float = (_vp.x - _group_w) * 0.5
	var _gy: float = _vp.y * 0.5 - 60.0
	sp.position = Vector2(_gx, _gy)
	sp.custom_minimum_size = Vector2(258, 0)
	layer.add_child(sp)
	var spv := VBoxContainer.new()
	spv.add_theme_constant_override("separation", 9)
	sp.add_child(spv)
	var sphdr := Label.new()
	sphdr.text = "YOUR  STATS"
	sphdr.add_theme_font_size_override("font_size", 20)
	sphdr.add_theme_color_override("font_color", Color(0.45, 0.95, 0.85))
	spv.add_child(sphdr)
	var hp_now: int = int(_player.max_health) if is_instance_valid(_player) and "max_health" in _player else 0
	var stat_defs: Array = [
		["dmg",   "Damage",     "%d" % ArpgState.weapon_damage()],
		["rate",  "Fire Rate",  "%.2f/s" % (1.0 / ArpgState.weapon_cooldown())],
		["crit",  "Crit",       "%d%%" % int(ArpgState.crit_chance * 100.0)],
		["shots", "Shots",      "%d" % ArpgState.weapon_count()],
		["hp",    "Max HP",     "%d" % hp_now],
		["speed", "Move Speed", "+%d%%" % int((ArpgState.speed_mult - 1.0) * 100.0)],
	]
	var vlabels: Dictionary = {}
	var base_text: Dictionary = {}
	for sd in stat_defs:
		var line := HBoxContainer.new()
		var kl := Label.new()
		kl.text = String(sd[1]); kl.add_theme_font_size_override("font_size", 16)
		kl.add_theme_color_override("font_color", Color(0.7, 0.73, 0.82))
		kl.custom_minimum_size = Vector2(140, 0)
		line.add_child(kl)
		var vl := Label.new()
		vl.text = String(sd[2]); vl.add_theme_font_size_override("font_size", 16)
		vl.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
		line.add_child(vl)
		spv.add_child(line)
		vlabels[String(sd[0])] = vl
		base_text[String(sd[0])] = String(sd[2])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.position = Vector2(_gx + 258.0 + 54.0, _gy + 18.0)
	layer.add_child(row)
	var pf := FontFile.new()
	pf.load_dynamic_font("res://assets/luckiest_guy.ttf")
	for opt in opts:
		var card := Button.new()
		card.custom_minimum_size = Vector2(240, 180)
		card.focus_mode = Control.FOCUS_NONE
		var col: Color = opt.get("color", Color(1, 0.9, 0.5))
		# Modern-dark card: dark surface + the rarity colour as a bright accent border.
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.10, 0.13, 0.18)
		sb.set_border_width_all(3); sb.border_color = col
		sb.set_corner_radius_all(12)
		sb.shadow_color = Color(0, 0, 0, 0.5); sb.shadow_size = 8; sb.shadow_offset = Vector2(2, 5)
		card.add_theme_stylebox_override("normal", sb)
		var hov := sb.duplicate() as StyleBoxFlat
		hov.bg_color = Color(0.14, 0.20, 0.25)
		hov.set_border_width_all(4)
		card.add_theme_stylebox_override("hover", hov)
		card.add_theme_stylebox_override("pressed", hov)
		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 12)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(vb)
		var nm := Label.new()
		nm.text = String(opt.get("name", "?"))
		nm.add_theme_font_size_override("font_size", 22)
		nm.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
		nm.add_theme_font_override("font", pf)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(nm)
		var ds := Label.new()
		ds.text = String(opt.get("desc", ""))
		ds.add_theme_font_size_override("font_size", 17)
		ds.add_theme_color_override("font_color", Color(0.64, 0.72, 0.82))
		ds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(ds)
		var prev := _upgrade_preview(opt)
		if prev != "":
			var pl := Label.new()
			pl.text = prev
			pl.add_theme_font_size_override("font_size", 15)
			pl.add_theme_color_override("font_color", Color(0.45, 0.85, 0.78))
			pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vb.add_child(pl)
		# Hover → light up the affected stat in the panel with its new value.
		var chg: Array = _levelup_change(opt)
		var ck: String = String(chg[0])
		card.mouse_entered.connect(func() -> void:
			if ck != "" and vlabels.has(ck):
				var v2 := vlabels[ck] as Label
				v2.text = "%s → %s" % [base_text[ck], chg[1]]
				v2.add_theme_color_override("font_color", col))
		card.mouse_exited.connect(func() -> void:
			if ck != "" and vlabels.has(ck):
				var v2 := vlabels[ck] as Label
				v2.text = String(base_text[ck])
				v2.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0)))
		card.pressed.connect(_pick_level_up.bind(layer, opt))
		row.add_child(card)

func _upgrade_preview(opt: Dictionary) -> String:
	# A concrete "before → after" so +1 Damage vs +10% Damage is readable at a glance.
	var w: Dictionary = ArpgState.weapon
	var cur_dmg: int = ArpgState.weapon_damage()
	match String(opt.get("id", "")):
		"w_level":    return "Weapon  Lv %d → %d" % [int(w.get("lvl", 1)), int(w.get("lvl", 1)) + 1]
		"w_dmg":      return "Damage  %d → %d" % [cur_dmg, cur_dmg + 1]
		"w_dmg2":     return "Damage  %d → %d" % [cur_dmg, cur_dmg + 2]
		"dmg":        return "Damage  %d → %d" % [cur_dmg, int(ceil(float(w.get("dmg", 1)) * ArpgState.dmg_mult * 1.10)) + ArpgState.bonus_damage()]
		"maxhp":      return "Max HP  +4"
		"firerate":   return "Fire rate  +12%"
		"w_firerate": return "Fire rate  +11%"
		"crit":       return "Crit  %d%% → %d%%" % [int(ArpgState.crit_chance * 100.0), int(minf(ArpgState.crit_chance + 0.07, 0.50) * 100.0)]
		"speed":      return "Move speed  +8%"
		"w_pierce":   return "Pierce  %d → %d" % [int(w.get("pierce", 0)), int(w.get("pierce", 0)) + 1]
		"w_bounce":   return "Bounces  %d → %d" % [int(w.get("bounces", 1)), int(w.get("bounces", 1)) + 3]
		"w_count":    return "Shots  %d → %d" % [ArpgState.weapon_count(), ArpgState.weapon_count() + 1]
		"back_shot":  return "Also fires behind you"
	return ""

# Which stat a level-up card changes, and its new value — drives the hover
# preview on the YOUR STATS panel. Returns ["", ""] for cards with no tracked stat.
func _levelup_change(opt: Dictionary) -> Array:
	var w: Dictionary = ArpgState.weapon
	var cur_dmg: int = ArpgState.weapon_damage()
	var hp_now: int = int(_player.max_health) if is_instance_valid(_player) and "max_health" in _player else 0
	match String(opt.get("id", "")):
		"w_level":
			var arch: Dictionary = ArpgState._archetype_by_name(String(w.get("name", "")))
			var nxt: Dictionary = ArpgState._build_weapon(arch, int(w.get("lvl", 1)) + 1, int(w.get("rarity", 0)))
			if int(nxt.get("count", 1)) > int(w.get("count", 1)):
				return ["shots", "%d" % (int(nxt.get("count", 1)) + ArpgState.bonus_projectiles)]
			if float(nxt.get("cooldown", 1.0)) < float(w.get("cooldown", 1.0)) - 0.0001:
				return ["rate", "%.2f/s" % (1.0 / maxf(0.06, float(nxt.get("cooldown", 0.34)) * ArpgState.cooldown_mult))]
			return ["dmg", "%d" % int(ceil(float(nxt.get("dmg", 1)) * ArpgState.dmg_mult))]
		"w_dmg":      return ["dmg", "%d" % (cur_dmg + 1)]
		"w_dmg2":     return ["dmg", "%d" % (cur_dmg + 2)]
		"dmg":        return ["dmg", "%d" % (int(ceil(float(w.get("dmg", 1)) * ArpgState.dmg_mult * 1.10)) + ArpgState.bonus_damage())]
		"firerate":   return ["rate", "%.2f/s" % (1.0 / maxf(0.06, ArpgState.weapon_cooldown() * 0.88))]
		"w_firerate": return ["rate", "%.2f/s" % (1.0 / maxf(0.06, ArpgState.weapon_cooldown() * 0.9))]
		"crit":       return ["crit", "%d%%" % int(minf(ArpgState.crit_chance + 0.07, 0.50) * 100.0)]
		"maxhp":      return ["hp", "%d" % (hp_now + 4)]
		"speed":      return ["speed", "+%d%%" % int((ArpgState.speed_mult + 0.08 - 1.0) * 100.0)]
		"w_count":    return ["shots", "%d" % (ArpgState.weapon_count() + 1)]
	return ["", ""]

func _pick_level_up(layer: CanvasLayer, opt: Dictionary) -> void:
	Stats.upgrade_picked(String(opt.get("id", "?")))
	ArpgState.apply_upgrade(opt)
	# Re-apply boons so stat changes (esp. +4 Max HP) take effect immediately —
	# apply_boons raises max_health AND heals by the increase.
	if is_instance_valid(_player) and _player.has_method("apply_boons"):
		_player.apply_boons()
	_refresh_hud()
	if is_instance_valid(layer):
		layer.queue_free()
	_levelup_open = false
	_levelup_queue = maxi(0, _levelup_queue - 1)
	if _levelup_queue > 0:
		call_deferred("_show_level_up")   # stacked level-ups: show the next card
	else:
		get_tree().paused = false

# ── HUD ────────────────────────────────────────────────────────────────────
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ArpgHUD"
	layer.layer = 6                  # above the GI post layer (2)
	add_child(layer)
	# Top-left stat plate — a clean rounded panel holding HP/XP bars + the
	# level / weapon / gold readouts (objective line removed).
	var plate := Panel.new()
	plate.position = Vector2(12, 12); plate.size = Vector2(292, 126)
	var plsb := StyleBoxFlat.new()
	plsb.bg_color = Color(0.05, 0.05, 0.08, 0.82)
	plsb.set_border_width_all(1); plsb.border_color = Color(0.78, 0.64, 0.36, 0.5)
	plsb.set_corner_radius_all(10)
	plate.add_theme_stylebox_override("panel", plsb)
	layer.add_child(plate)

	# Health bar — style chosen in the dev screen (GameSettings.health_bar_style).
	_hp_update = HealthBarLib.build(layer, GameSettings.health_bar_style, Vector2(24, 22), 268.0)
	var xp_bg := ColorRect.new()
	xp_bg.position = Vector2(24, 48); xp_bg.size = Vector2(268, 7)
	xp_bg.color = Color(0.05, 0.04, 0.08, 0.95); layer.add_child(xp_bg)
	_hud_xp_fill = ColorRect.new()
	_hud_xp_fill.position = Vector2(25, 49); _hud_xp_fill.size = Vector2(0, 5)
	_hud_xp_fill.color = Color(0.5, 0.8, 1.0); layer.add_child(_hud_xp_fill)
	_hud_level = _mk_label(layer, Vector2(24, 60), 19, Color(1.0, 0.95, 0.6))
	_hud_weapon = _mk_label(layer, Vector2(24, 86), 15, Color(0.8, 0.85, 1.0))
	_hud_gold = _mk_label(layer, Vector2(24, 108), 15, Color(1.0, 0.85, 0.35))
	_hud_toast = _mk_label(layer, Vector2(0, 150), 30, Color(1, 1, 1))
	_hud_toast.size = Vector2(1440, 40)
	_hud_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_toast.modulate.a = 0.0
	# Stylized display font (Anton — heavy condensed) for toasts + the run timer.
	var ui_font := FontFile.new()
	var has_ui_font: bool = ui_font.load_dynamic_font("res://assets/anton.ttf") == OK
	if has_ui_font:
		_hud_toast.add_theme_font_override("font", ui_font)
	# Run timer — a neat little box in the BOTTOM-RIGHT (stage time + Σ total run time).
	var tpanel := Panel.new()
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.04, 0.05, 0.09, 0.55)
	tsb.set_corner_radius_all(8)
	tsb.set_border_width_all(1); tsb.border_color = Color(1, 1, 1, 0.12)
	tpanel.add_theme_stylebox_override("panel", tsb)
	tpanel.position = Vector2(1264, 722); tpanel.size = Vector2(172, 66)
	tpanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(tpanel)
	_hud_time_tl = _mk_label(layer, Vector2(1274, 728), 22, Color(0.9, 0.94, 1.0))
	_hud_time_tl.text = "0:00"
	_hud_time_tl.size = Vector2(152, 28); _hud_time_tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if has_ui_font:
		_hud_time_tl.add_theme_font_override("font", ui_font)
	_hud_time_total = _mk_label(layer, Vector2(1274, 760), 14, Color(0.62, 0.7, 0.86))
	_hud_time_total.text = "Σ 0:00"
	_hud_time_total.size = Vector2(152, 20); _hud_time_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if has_ui_font:
		_hud_time_total.add_theme_font_override("font", ui_font)
	# (FPS counter removed — no longer needed.)
	# (Auto-sell toggle moved to the pause menu — press Esc → Options.)
	# Boss health bar (top-centre, hidden until the guardian is engaged).
	_hud_boss_root = Control.new()
	_hud_boss_root.position = Vector2(522, 18)
	_hud_boss_root.visible = false
	layer.add_child(_hud_boss_root)
	var bb_bg := ColorRect.new()
	bb_bg.position = Vector2(0, 22); bb_bg.size = Vector2(400, 18)
	bb_bg.color = Color(0.06, 0.03, 0.04, 0.92); _hud_boss_root.add_child(bb_bg)
	_hud_boss_fill = ColorRect.new()
	_hud_boss_fill.position = Vector2(2, 24); _hud_boss_fill.size = Vector2(396, 14)
	_hud_boss_fill.color = Color(0.9, 0.25, 0.28); _hud_boss_root.add_child(_hud_boss_fill)
	_hud_boss_label = Label.new()
	_hud_boss_label.position = Vector2(0, -2); _hud_boss_label.size = Vector2(400, 22)
	_hud_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_boss_label.text = "DUNGEON GUARDIAN"
	_hud_boss_label.add_theme_font_size_override("font_size", 16)
	_hud_boss_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.7))
	_hud_boss_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_hud_boss_label.add_theme_constant_override("outline_size", 4)
	_hud_boss_root.add_child(_hud_boss_label)

func _mk_label(parent: Node, pos: Vector2, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	parent.add_child(l)
	return l

func _refresh_hud() -> void:
	if _hud_level == null:
		return
	_hud_level.text = "Lv %d   ·   Floor %d" % [ArpgState.level, ArpgState.depth]
	_hud_gold.text = "⛁ %d gold" % ArpgState.gold
	var w: Dictionary = ArpgState.weapon
	var rar: int = int(w.get("rarity", 0))
	# Primary "<Name> Lv", coloured by rarity, then any auto-firing secondaries.
	var line: String = "%s Lv%d" % [w.get("name", "—"), int(w.get("lvl", 1))]
	var extras: Array = ArpgState.extra_weapons
	for e in extras:
		line += "  +  %s Lv%d" % [String((e as Dictionary).get("name", "?")), int((e as Dictionary).get("lvl", 1))]
	_hud_weapon.text = line
	_hud_weapon.add_theme_color_override("font_color", ArpgState.RARITY_COLORS[rar])
	var frac: float = float(ArpgState.xp) / float(max(1, ArpgState.xp_to_next))
	_hud_xp_fill.size.x = 238.0 * clampf(frac, 0.0, 1.0)

func _flash_boss() -> void:
	# Big "BOSS" that flashes a couple times then fades — replaces the guardian toast.
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var lbl := Label.new()
	lbl.text = "BOSS"
	lbl.add_theme_font_size_override("font_size", 110)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.22, 0.22))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 8)
	var lf := FontFile.new()
	if lf.load_dynamic_font("res://assets/anton.ttf") == OK:
		lbl.add_theme_font_override("font", lf)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.anchor_left = 0.0; lbl.anchor_right = 1.0
	lbl.offset_top = 270.0
	lbl.pivot_offset = Vector2(720, 60)
	lbl.modulate.a = 0.0
	layer.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, 0.12)   # flash on
	tw.tween_property(lbl, "modulate:a", 0.15, 0.14)  # off
	tw.tween_property(lbl, "modulate:a", 1.0, 0.12)   # on again
	tw.tween_interval(0.7)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.4)
	tw.tween_callback(layer.queue_free)
	lbl.scale = Vector2(1.35, 1.35)
	lbl.create_tween().tween_property(lbl, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_toast(text: String, color: Color) -> void:
	if _hud_toast == null:
		return
	_hud_toast.text = text
	_hud_toast.add_theme_color_override("font_color", color)
	_hud_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.3)
	tw.tween_property(_hud_toast, "modulate:a", 0.0, 0.7)
