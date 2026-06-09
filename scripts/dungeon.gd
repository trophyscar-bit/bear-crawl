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
const BeanieBearScene := preload("res://scenes/beanie_bear.tscn")
const TeddyBearScene := preload("res://scenes/teddy_bear.tscn")
const CreamBearScene := preload("res://scenes/cream_bear.tscn")
const DarkAllyScene := preload("res://scenes/dark_bear_ally.tscn")
const SkeletonScene := preload("res://scenes/skeleton.tscn")
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
	ArpgState.active = true
	ArpgState.begin_spawn_grace(5.0)   # 5s breather — nothing shoots on level entry
	ArpgState.no_projectile_glow = (theme == "backrooms")   # flat level — no glow
	ArpgState.dungeon_path = scene_file_path   # so the shop knows where to descend
	ArpgState.loot_dropped.connect(_spawn_loot)
	ArpgState.leveled_up.connect(_on_level_up)
	ArpgState.toast.connect(_on_toast)
	_generate_bsp()
	_build_nav()
	_spawn_floor()
	_build_walls()
	_spawn_player()
	_spawn_boss()
	_spawn_exit()
	if theme != "backrooms":
		_spawn_braziers()       # cave candelabras/stalagmites — backrooms is bare
	_spawn_traps()
	_spawn_enemies()
	# Healing hearts per floor now scale with difficulty (was a flat 13 — that alone
	# healed ~26 HP a floor and made damage meaningless).
	match GameSettings.difficulty:
		0: item_count = 7    # EASY
		2: item_count = 2    # HARD
		_: item_count = 4    # MEDIUM
	_spawn_items()
	if theme == "backrooms":
		_spawn_props()
	_camera.make_current()
	if _minimap and _minimap.has_method("bind"):
		_minimap.bind(self)
	_build_hud()
	_refresh_hud()
	_build_fog()
	_apply_lighting_mode(1)   # Standard only — locked
	if theme == "backrooms":
		_build_backrooms_lighting()
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
	# Boss room = a RANDOM room a decent distance from the start (middle or far
	# side) — not always parked in the far corner.
	var sc: Vector2 = Vector2(_room_center_cell(_start_room))
	var far_fallback: int = _rooms.size() - 1
	var far_d: float = -1.0
	var candidates: Array = []
	for i in range(1, _rooms.size()):
		var d: float = Vector2(_room_center_cell(_rooms[i])).distance_to(sc)
		if d > far_d:
			far_d = d
			far_fallback = i
		if d >= 7.0:
			candidates.append(i)
	_boss_room = _rooms[candidates[randi() % candidates.size()]] if not candidates.is_empty() else _rooms[far_fallback]

func _carve_rect(r: Rect2i) -> void:
	for y in range(r.position.y, r.position.y + r.size.y):
		for x in range(r.position.x, r.position.x + r.size.x):
			_carve_cell(x, y)

func _carve_cell(x: int, y: int) -> void:
	if x >= 0 and x < _fw and y >= 0 and y < _fh:
		_wall[y][x] = false

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
func _spawn_floor() -> void:
	# Plain diffuse — lights fall off SMOOTHLY across the floor (no per-tile
	# normal-map shading, which read as a grid of gray boxes).
	var f := TextureRect.new()
	f.texture = _floor_texture()
	f.stretch_mode = TextureRect.STRETCH_TILE
	f.size = Vector2(_fw * tile, _fh * tile)
	f.z_index = -20
	add_child(f)
	_bk_floor_node = f   # kept so the backrooms pack switcher can re-texture it

var _wall_torch_pos: Array = []   # placed wall-sconce positions (for spacing)

func _build_walls() -> void:
	_wall_torch_pos.clear()
	for y in _fh:
		for x in _fw:
			if not _wall[y][x]:
				continue
			# only solid cells touching a floor cell get rendered/collide —
			# deep rock stays an unlit void (cheap + reads as walls with mass)
			if not _touches_floor(x, y):
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
			var ts: float = float(wt.get_width())
			# Pseudo-3/4 "face": if this wall faces a room to the SOUTH, draw a
			# darker front face extending down so the wall reads as having height
			# (the angled look), with the lit top on top.
			if faces_room:
				# Backrooms uses a taller face (steeper "angle" — more wall visible).
				var fh: float = BK_WALL_FACE if theme == "backrooms" else 0.5
				var fy: float = tile * (0.5 + fh * 0.5) if theme == "backrooms" else tile * 0.55
				var face := Sprite2D.new()
				face.name = "Face"
				face.texture = wt
				face.scale = Vector2(tile / ts, (tile * fh) / ts)
				face.position = Vector2(0, fy)
				face.modulate = Color(0.5, 0.5, 0.56)   # shaded front face
				face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
				face.z_index = 1
				body.add_child(face)
			var spr := Sprite2D.new()
			spr.name = "Top"
			spr.texture = wt
			spr.scale = Vector2(tile / ts, tile / ts)
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			spr.z_index = 2
			body.add_child(spr)
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
			if theme != "backrooms" and y + 1 < _fh and not _wall[y + 1][x] and randf() < 0.06:
				var tpos := Vector2((x + 0.5) * tile, (y + 0.5) * tile + tile * 0.42)
				# Never cluster wall sconces — keep them ≥6 blocks apart.
				if not _pos_too_close(tpos, _wall_torch_pos, tile * 6.0):
					_wall_torch_pos.append(tpos)
					_add_wall_torch(tpos, body, occ)

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
	var bonus: int = ArpgState.bonus_max_health()
	if bonus > 0 and "max_health" in _player:
		_player.max_health = int(_player.max_health) + bonus
	# Apply shop move-speed upgrade (fresh instance each floor, so multiply once).
	if ArpgState.speed_mult != 1.0 and "speed" in _player:
		_player.speed = float(_player.speed) * ArpgState.speed_mult
	if _player.has_method("heal"):
		_player.heal(9999)
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
		if theme == "backrooms":
			# Flat fluorescent space is already fully lit — no player light aura.
			torch.visible = false
			torch.energy = 0.0

func _spawn_boss() -> void:
	_boss = EnemyScene.instantiate()
	_boss.position = _room_center_world(_boss_room)
	_boss_max_hp = ArpgState.boss_hp()
	if "max_health" in _boss:
		_boss.max_health = _boss_max_hp
	_boss.set("is_boss", true)          # glowing white star spread + AoE slam
	if "touch_damage" in _boss:
		_boss.touch_damage = 2
	add_child(_boss)
	var rig := _boss.get_node_or_null("Rig") as Node2D
	if rig != null:
		rig.scale *= 1.8
		rig.modulate = Color(1.25, 0.55, 0.55)

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
	# Stone stairwell descending into the dark — detailed cobblestone sprite.
	var stairs := Sprite2D.new()
	var st_tex: Texture2D = _load_tex_mip("res://assets/stairs_down_v2.png")
	stairs.texture = st_tex if st_tex != null else StairsTex
	stairs.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	stairs.scale = Vector2(0.7, 0.7)
	stairs.z_index = -2          # sits on the floor, under the player
	area.add_child(stairs)
	# Gentle "breathing" pulse on the glow instead of spinning the stairs.
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
	# Disable THIS wall's own occluder so the torch can glow from the candle itself
	# (instead of being shoved down into the room to escape its own shadow). Other
	# walls keep their occluders, so the torch light still doesn't pass through them.
	if occ != null:
		occ.set_deferred("visible", false)
	var lamp := PointLight2D.new()
	lamp.texture = LightTex
	# Light sits ON the candle (matches the sconce sprite), so the flame glows.
	lamp.position = pos - Vector2(0, tile * 0.20)
	lamp.color = Color(1.0, 0.64, 0.30)
	lamp.energy = 0.94
	lamp.texture_scale = 2.6     # double the wall-torch light range (was 1.3)
	lamp.shadow_enabled = true   # other walls still block it laterally
	lamp.shadow_filter = 1
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
		lamp.shadow_filter = 2          # PCF13 — softer, higher-quality shadows
		lamp.shadow_filter_smooth = 4.0
		lamp.position = pos - Vector2(0, tile * 0.35)   # light at the flames
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
	SkeletonScene,        # 0  pure melee, no ranged — the gentle intro
	SealScene,            # 1  Long Bear — blocker, doesn't even attack
	DucklingScene,        # 2  weak fast swarmer
	CreamBearScene,       # 3  basic melee critter
	BeanieBearScene,      # 4  lobs slow beanies
	HoundScene,           # 5  pounce
	GunBearScene,         # 6  burst rifle
	GrowlerScene,         # 7  archer
	FrostCubScene,        # 8  freeze orb
	TeddyBearScene,       # 9  suicide bomber
	ShrinkwrapBearScene,  # 10 air puff
	EnemyScene,           # 11 KK — stars + paw
	PlushBrawlerScene,    # 12 charger
]
const WAVE_UNLOCK_INTERVAL: float = 60.0   # a new enemy type joins every minute
const WAVE_NAMES: Dictionary = {
	"skeleton": "SKELETON", "seal": "LONG BEAR", "duckling": "DUCKLING",
	"cream_bear": "CREAM BEAR", "beanie_bear": "BEANIE BEAR", "hound": "HOUND",
	"gun_bear": "GUN BEAR", "growler": "ARCHER", "frost_cub": "FROST CUB",
	"teddy_bear": "TEDDY BEAR", "shrinkwrap_bear": "SHRINKWRAP", "enemy": "KK BEAR",
	"plush_brawler": "BRAWLER",
}

var _wave_t: float = 0.0
var _wave_spawn_t: float = 0.0
var _wave_started: bool = false
var _wave_last_unlocked: int = 0
var _event_t: float = 70.0   # countdown to the next themed RUSH event
var _hud_time_tl: Label = null
var _hud_time_br: Label = null

func _spawn_enemies() -> void:
	# Floor opens with a SMALL batch of only the easiest unlocked types; the wave
	# director (in _process) keeps the pressure ramping from there.
	_wave_started = true
	_wave_t = 0.0
	_wave_spawn_t = 3.0
	_wave_last_unlocked = _wave_unlocked_count()
	var seed_n: int = int(_wave_alive_cap() * 0.45)
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
	# Themed RUSH events — once the floor has ramped, every ~minute a horde of ONE
	# enemy type pours in around you (a wall of teddy bombers, a swarm of long
	# bears, etc.). The fun chaos beat.
	if _wave_t > 40.0:
		_event_t -= delta
		if _event_t <= 0.0:
			_event_t = randf_range(55.0, 85.0)
			_trigger_rush_event()

func _trigger_rush_event() -> void:
	if not is_instance_valid(_player):
		return
	var scene: PackedScene = _wave_pick_scene()
	var fn: String = scene.resource_path.get_file().get_basename()
	var nm: String = WAVE_NAMES.get(fn, fn.to_upper())
	var n: int = clampi(int(round(10.0 * _wave_power())), 9, 22)
	_flash_event("%s  RUSH!" % nm, Color(1.0, 0.55, 0.2))
	Juice.shake(0.35)
	# Spawn them in a ring around the player so they converge from all sides.
	for i in n:
		var pos: Vector2 = floor_point_near(_player.global_position, 460.0, 880.0)
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
	var base: int = 1 + (ArpgState.depth - 1) * 2   # floor 1: skeletons only for the 1st minute
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
	return clampf(ArpgState.challenge_ratio(), 1.0, 2.8)

func _wave_alive_cap() -> int:
	var base: int = 24
	match GameSettings.difficulty:
		0: base = 16   # EASY
		2: base = 34   # HARD
	var grown: int = base + int(_wave_t / 14.0) * 4
	return mini(int(round(float(grown) * _wave_power())), 85)   # capped for perf (was 130)

func _wave_interval() -> float:
	# Batches come faster the longer you're in + the stronger you are.
	return maxf(0.40, (2.6 - _wave_t / 60.0) / _wave_power())

func _wave_batch_size() -> int:
	return maxi(3, int(round((3.0 + _wave_t / 32.0) * _wave_power())))

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
	add_child(e)
	_configure_enemy(e)

func _configure_enemy(e: Node) -> void:
	# Scale HP AFTER add_child: subtypes set their base max_health in their OWN
	# _ready, which would overwrite a value set before. Read the final base, scale.
	if "max_health" in e:
		var base_hp: int = int(e.max_health)
		var diff: float = _difficulty_hp_mult()
		var hp_power_mult: float = sqrt(ArpgState.challenge_ratio())
		e.max_health = int(round(float(base_hp) * 6.0 * diff * hp_power_mult)) + 3 + int(ArpgState.depth - 1) * 4
		e.set("health", e.max_health)
		# Enemies hit a little harder the deeper you go (+1 contact dmg every 3 floors).
		if "touch_damage" in e:
			e.touch_damage = int(e.touch_damage) + int((ArpgState.depth - 1) / 3)

func _apply_brightness(level: int, announce: bool = true) -> void:
	# Overall darkness preset (1=dark/moody, 2=medium, 3=bright). Lifts the global
	# ambient floor + the player aura together. Persists across floors via ArpgState.
	level = clampi(level, 1, 3)
	ArpgState.brightness_level = level
	if theme == "backrooms":
		return
	var amb: Color = [Color(0.15, 0.14, 0.21), Color(0.27, 0.25, 0.32), Color(0.40, 0.38, 0.45)][level - 1]
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
	var out: Array = []
	var dirp: String = "res://assets/backrooms/props/%s/" % cat
	var da := DirAccess.open(dirp)
	if da == null:
		return out
	da.list_dir_begin()
	var fn := da.get_next()
	while fn != "":
		if fn.to_lower().ends_with(".png"):
			var t := _load_tex_mip(dirp + fn)
			if t != null:
				out.append({"name": fn.get_basename(), "tex": t})
		fn = da.get_next()
	da.list_dir_end()
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
	if get_tree().paused:
		return   # stats screen / popups paused us — don't run gameplay or waves
	_wave_tick(delta)
	if is_instance_valid(_player):
		_camera.position = _player.position
		if _fog_mat != null:
			_fog_mat.set_shader_parameter("cam_pos", _camera.position)
		var f := world_to_fine(_player.position)
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				_explored["%d,%d" % [int(f.x) + dx, int(f.y) + dy]] = true
	for b in _braziers:
		var lamp: PointLight2D = b["node"]
		if is_instance_valid(lamp):
			b["phase"] += delta * 9.0
			lamp.energy = b["base"] * (0.86 + 0.14 * sin(b["phase"]) + randf() * 0.05)
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
			_exit_node.visible = true
		if _hud_boss_root != null:
			_hud_boss_root.visible = false
		_on_toast("Guardian slain — the descent opens!", Color(1.0, 0.85, 0.45))
		# 10% chance: a BACKROOMS portal tears open where the guardian fell.
		if theme != "backrooms" and randf() < 0.10:
			_spawn_backrooms_portal((_boss as Node2D).global_position)
	if _minimap:
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
	ArpgState.descend()
	get_tree().change_scene_to_file("res://scenes/shop.tscn")

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
	# Let the death explosion + chunks play out, then show the game-over screen.
	# (Doubled the beat so the death animation lands before YOU DIED appears.)
	await get_tree().create_timer(3.4, true).timeout
	_show_game_over()

const _StuffingTex := preload("res://assets/stuffing.png")
const _DripCream := Color(0.96, 0.92, 0.83)   # plushie stuffing colour

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
	# Real "Nosifer" dripping-blood display font (Google Fonts, OFL). Loaded
	# directly from the .ttf so it works whether or not Godot has imported it.
	var death_font := FontFile.new()
	if death_font.load_dynamic_font("res://assets/nosifer.ttf") == OK:
		title.add_theme_font_override("font", death_font)
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


func _spawn_death_drips(layer: CanvasLayer, title: Label) -> void:
	var rect := Rect2(title.global_position, title.size)
	var top := rect.position.y + rect.size.y * 0.62
	# Oozing stuffing drips — rounded cream capsules that slowly grow downward.
	for i in 16:
		var w: float = randf_range(7.0, 16.0)
		var x: float = rect.position.x + rect.size.x * randf_range(0.06, 0.94)
		var drip := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = _DripCream.lerp(Color(0.85, 0.32, 0.30), randf() * 0.35)  # mostly fluff, faint blood tint
		sb.set_corner_radius_all(int(w * 0.5))
		drip.add_theme_stylebox_override("panel", sb)
		drip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		drip.position = Vector2(x - w * 0.5, top + randf_range(-6.0, 8.0))
		drip.size = Vector2(w, 0.0)
		layer.add_child(drip)
		var len: float = randf_range(40.0, 170.0)
		var dur: float = randf_range(1.3, 2.6)
		var tw := drip.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_interval(randf() * 0.7)
		tw.tween_property(drip, "size:y", len, dur)
		tw.parallel().tween_property(drip, "modulate:a", 0.25, dur).set_delay(dur * 0.4)
	# Fluff motes drifting down from the wound.
	for j in 10:
		var f := TextureRect.new()
		f.texture = _StuffingTex
		f.modulate = Color(_DripCream.r, _DripCream.g, _DripCream.b, 0.0)
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var s: float = randf_range(0.18, 0.4)
		f.scale = Vector2(s, s)
		var fx: float = rect.position.x + rect.size.x * randf_range(0.0, 1.0)
		var fy: float = top + randf_range(0.0, 20.0)
		f.position = Vector2(fx, fy)
		layer.add_child(f)
		var fall: float = randf_range(120.0, 280.0)
		var fdur: float = randf_range(1.8, 3.2)
		var ftw := f.create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
		ftw.tween_property(f, "position:y", fy + fall, fdur).set_ease(Tween.EASE_IN)
		ftw.tween_property(f, "position:x", fx + randf_range(-40.0, 40.0), fdur)
		ftw.tween_property(f, "rotation", randf_range(-1.5, 1.5), fdur)
		var fade := f.create_tween()
		fade.tween_property(f, "modulate:a", 0.8, fdur * 0.25)
		fade.tween_property(f, "modulate:a", 0.0, fdur * 0.75)

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
	var row := HBoxContainer.new()
	parent.add_child(row)
	var k := Label.new()
	k.text = key
	k.add_theme_font_size_override("font_size", 19)
	k.add_theme_color_override("font_color", Color(0.66, 0.7, 0.8))
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(k)
	var v := Label.new()
	v.text = val
	v.add_theme_font_size_override("font_size", 19)
	v.add_theme_color_override("font_color", accent)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)

func _toggle_stats() -> void:
	if is_instance_valid(_stats_layer):
		_stats_layer.queue_free()
		_stats_layer = null
		Engine.time_scale = 1.0          # back to full speed
		return
	# Don't pause — run the world in slow-mo (25%) so you can read your stats while
	# the action keeps creeping along. Input/UI run in real time (time_scale only
	# affects in-game delta), so Tab/Esc still close instantly.
	Engine.time_scale = 0.25
	_stats_layer = CanvasLayer.new()
	_stats_layer.layer = 94
	_stats_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_stats_layer)
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

# ── backrooms theme (Level 0) ────────────────────────────────────────────────
func _floor_texture() -> Texture2D:
	return _bk_floor if _bk_floor != null else FloorTex

func _wall_texture() -> Texture2D:
	return _bk_wall if _bk_wall != null else WallTex

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
	# Floating "Press E" prompt, hidden until the player stands on the drop.
	var prompt := Label.new()
	prompt.name = "Prompt"
	prompt.text = "Press E"
	prompt.add_theme_font_size_override("font_size", 15)
	prompt.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	prompt.add_theme_constant_override("outline_size", 4)
	prompt.position = Vector2(-30, -46)
	prompt.visible = false
	area.add_child(prompt)
	area.body_entered.connect(func(b: Node) -> void:
		if b.is_in_group("player"):
			# Auto-sell SAME-or-lower rarity (opt-in): commit to your weapon and only
			# stop for genuinely rarer drops. Higher rarity always stays for an E pick.
			if ArpgState.auto_sell_rarity and not ArpgState.weapon.is_empty() \
					and int(item.get("rarity", 0)) <= int(ArpgState.weapon.get("rarity", 0)):
				var v: int = ArpgState.weapon_sell_value(item)
				ArpgState.gold += v
				ArpgState.emit_signal("stats_changed")
				ArpgState.emit_signal("toast", "+%d gold (auto-sold %s)" % [v, ArpgState.RARITY_NAMES[int(item.get("rarity", 0))]], Color(1.0, 0.85, 0.4))
				if is_instance_valid(area):
					area.queue_free()
				return
			# Clearly-weaker drops auto-sell for coins on contact — no pop-up nag.
			if _weapon_is_junk(item):
				# Trash auto-sells for a token amount only — not a farmable income.
				var sell: int = mini(ArpgState.weapon_sell_value(item), 3)
				ArpgState.gold += sell
				ArpgState.emit_signal("stats_changed")
				ArpgState.emit_signal("toast", "+%d gold (scrapped weak drop)" % sell, Color(1.0, 0.85, 0.4))
				if is_instance_valid(area):
					area.queue_free()
				return
			_near_loot_item = item
			_near_loot_area = area
			prompt.visible = true)
	area.body_exited.connect(func(b: Node) -> void:
		if b.is_in_group("player"):
			prompt.visible = false
			if _near_loot_area == area:
				_near_loot_item = {}
				_near_loot_area = null)
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
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.3))
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
	spsb.bg_color = Color(0.07, 0.07, 0.11, 0.96)
	spsb.set_border_width_all(2); spsb.border_color = Color(0.5, 0.55, 0.7, 0.7)
	spsb.set_corner_radius_all(12); spsb.set_content_margin_all(16)
	sp.add_theme_stylebox_override("panel", spsb)
	sp.position = Vector2(46, 392)
	sp.custom_minimum_size = Vector2(258, 0)
	layer.add_child(sp)
	var spv := VBoxContainer.new()
	spv.add_theme_constant_override("separation", 9)
	sp.add_child(spv)
	var sphdr := Label.new()
	sphdr.text = "YOUR  STATS"
	sphdr.add_theme_font_size_override("font_size", 20)
	sphdr.add_theme_color_override("font_color", Color(0.95, 0.86, 0.5))
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
	row.position = Vector2(356, 410)
	layer.add_child(row)
	for opt in opts:
		var card := Button.new()
		card.custom_minimum_size = Vector2(240, 180)
		card.focus_mode = Control.FOCUS_NONE
		var col: Color = opt.get("color", Color(1, 0.9, 0.5))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.10, 0.10, 0.14, 0.96)
		sb.set_border_width_all(3); sb.border_color = col
		sb.set_corner_radius_all(12)
		card.add_theme_stylebox_override("normal", sb)
		var hov := sb.duplicate() as StyleBoxFlat
		hov.bg_color = Color(0.16, 0.16, 0.21, 0.98)
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
		nm.add_theme_color_override("font_color", col)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(nm)
		var ds := Label.new()
		ds.text = String(opt.get("desc", ""))
		ds.add_theme_font_size_override("font_size", 17)
		ds.add_theme_color_override("font_color", Color(0.85, 0.87, 0.92))
		ds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(ds)
		var prev := _upgrade_preview(opt)
		if prev != "":
			var pl := Label.new()
			pl.text = prev
			pl.add_theme_font_size_override("font_size", 15)
			pl.add_theme_color_override("font_color", Color(0.62, 0.68, 0.78))
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
		"dmg":        return "Damage  %d → %d" % [cur_dmg, int(ceil(float(w.get("dmg", 1)) * (ArpgState.dmg_mult + 0.10)))]
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
		"dmg":        return ["dmg", "%d" % int(ceil(float(w.get("dmg", 1)) * (ArpgState.dmg_mult + 0.10)))]
		"firerate":   return ["rate", "%.2f/s" % (1.0 / maxf(0.06, ArpgState.weapon_cooldown() * 0.88))]
		"w_firerate": return ["rate", "%.2f/s" % (1.0 / maxf(0.06, ArpgState.weapon_cooldown() * 0.9))]
		"crit":       return ["crit", "%d%%" % int(minf(ArpgState.crit_chance + 0.07, 0.50) * 100.0)]
		"maxhp":      return ["hp", "%d" % (hp_now + 4)]
		"speed":      return ["speed", "+%d%%" % int((ArpgState.speed_mult + 0.08 - 1.0) * 100.0)]
		"w_count":    return ["shots", "%d" % (ArpgState.weapon_count() + 1)]
	return ["", ""]

func _pick_level_up(layer: CanvasLayer, opt: Dictionary) -> void:
	ArpgState.apply_upgrade(opt)
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
	# Run timer — top-left info panel (beside the level row) AND big bottom-right.
	_hud_time_tl = _mk_label(layer, Vector2(196, 60), 18, Color(0.85, 0.9, 1.0))
	_hud_time_tl.text = "0:00"
	if has_ui_font:
		_hud_time_tl.add_theme_font_override("font", ui_font)
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
	# Just "<Rarity> <Name>", coloured by rarity — the stats string overflowed the panel.
	_hud_weapon.text = "%s %s" % [ArpgState.RARITY_NAMES[rar], w.get("name", "—")]
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
