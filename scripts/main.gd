extends Node2D

const EnemyScene := preload("res://scenes/enemy.tscn")
const PlushBrawlerScene := preload("res://scenes/plush_brawler.tscn")
const ShrinkwrapBearScene := preload("res://scenes/shrinkwrap_bear.tscn")
const GunBearScene := preload("res://scenes/gun_bear.tscn")
const FaceBossScene := preload("res://scenes/face_boss.tscn")
const CylinderScene := preload("res://scenes/cylinder.tscn")
const TreeScene := preload("res://scenes/tree.tscn")
const PineTreeScene := preload("res://scenes/pine_tree.tscn")
const StoneScene := preload("res://scenes/stone.tscn")
const BushScene := preload("res://scenes/bush.tscn")
const CactusTallScene := preload("res://scenes/cactus_tall.tscn")
const CactusRoundScene := preload("res://scenes/cactus_round.tscn")
const DesertBushScene := preload("res://scenes/desert_bush.tscn")
const DesertRocksScene := preload("res://scenes/desert_rocks.tscn")
const PondScene := preload("res://scenes/pond.tscn")
const DoorScene := preload("res://scenes/door.tscn")
const BossScene := preload("res://scenes/boss.tscn")
const DesertBossScene := preload("res://scenes/desert_boss.tscn")
const VictoryScene := preload("res://scenes/victory_screen.tscn")
const BoonCardScene := preload("res://scenes/boon_card_screen.tscn")
const GameOverScene := preload("res://scenes/game_over_screen.tscn")
const DevMenuScene := preload("res://scenes/dev_menu.tscn")
const HazardScene := preload("res://scenes/hazard.tscn")
const SweeperSawScene := preload("res://scenes/sweeper_saw.tscn")

const BIOME_FOREST_COLOR := Color(0.18, 0.32, 0.16, 1)
const BIOME_DESERT_COLOR := Color(0.74, 0.59, 0.36, 1)
const BIOME_SKY_COLOR    := Color(0.78, 0.88, 0.96, 1)  # cloud-floor pale blue
const BIOME_SNOW_COLOR   := Color(0.88, 0.92, 0.97, 1)  # crusted-snow white
const BIOME_FALL_COLOR   := Color(0.48, 0.30, 0.18, 1)  # rust/leaf brown

const BIOME_HORIZONS: Dictionary = {
	"forest": preload("res://assets/horizon_forest.png"),
	"desert": preload("res://assets/horizon_desert.png"),
	"sky":    preload("res://assets/horizon_sky.png"),
	"snow":   preload("res://assets/horizon_snow.png"),
	"fall":   preload("res://assets/horizon_fall.png"),
}

const GAME_OVER_DELAY: float = 4.0  # dramatic pause — explosion peaks, chunks tumble, then pop-up

const WORLD_W: float = 1440.0
const WORLD_H: float = 810.0
const SKY_HEIGHT: float = 160.0  # top strip is the mountain-horizon backdrop (impassable)
const MARGIN: float = 60.0
const PLAY_TOP: float = SKY_HEIGHT
const PLAY_BOTTOM: float = 810.0
const PLAY_CENTER_Y: float = (PLAY_TOP + PLAY_BOTTOM) / 2.0  # 485
const SPAWN_Y_MIN: float = PLAY_TOP + MARGIN                   # 220
const SPAWN_Y_MAX: float = PLAY_BOTTOM - MARGIN                # 750
const BOSS_EVERY: int = 3
const FINAL_FLOOR: int = 10

# --- Scrolling traversal floors (prototype) --------------------------------
# Listed floors become a long left-to-right "crawl": the world is widened, a
# camera follows the player, enemies are spread across the length in clusters,
# and the exit door appears at the far side once everything is cleared.
# Boss floors are never traversal so all the fixed-arena boss choreography
# (AOE warnings, anchored Face Boss) keeps working untouched.
const TRAVERSAL_FLOORS: Array[int] = [1, 2]
const LONG_W: float = 4320.0   # 3x the standard arena width

const FINAL_FLUFF_REWARD: int = 25
const FINAL_COTTON_REWARD: int = 50

enum State { PLAYING, CLEARED, GAME_OVER, VICTORY }
var state: int = State.PLAYING
var depth: int = 1

@onready var floor_rect: ColorRect = $Floor
@onready var sky_sprite: Sprite2D = $Sky
@onready var player: Node2D = $Player
@onready var depth_label: Label = $HUD/DepthLabel
@onready var status_label: Label = $HUD/StatusLabel
@onready var health_fill: ColorRect = $HUD/HealthFill
@onready var health_label: Label = $HUD/HealthLabel
@onready var boss_health_frame: ColorRect = $HUD/BossHealthFrame
@onready var boss_health_back: ColorRect = $HUD/BossHealthBack
@onready var boss_health_fill: ColorRect = $HUD/BossHealthFill
@onready var boss_health_label: Label = $HUD/BossHealthLabel
@onready var bombs_label: Label = $HUD/BombsLabel

const HEALTH_BAR_LEFT: float = 24.0
const HEALTH_BAR_RIGHT: float = 236.0
const BOSS_BAR_HALF_W: float = 254.0

var _boss: Node = null

var _room_props: Array[Node] = []
var _door: Node = null

# Traversal-floor runtime state
var _floor_width: float = WORLD_W
var _is_traversal: bool = false

@onready var _camera: Camera2D = $GameCamera
@onready var wall_top: StaticBody2D = $WallTop
@onready var wall_bottom: StaticBody2D = $WallBottom
@onready var wall_right: StaticBody2D = $WallRight

func _ready() -> void:
	randomize()
	_camera.make_current()
	Juice.register_camera(_camera)
	var post_rect := get_node_or_null("PostFX/Vignette") as CanvasItem
	if post_rect != null and post_rect.material is ShaderMaterial:
		Juice.register_post(post_rect.material as ShaderMaterial)
	RunState.reset()  # fresh run on every load of main.tscn (including restart-after-death)
	DevState.reset()  # dev toggles reset per scene load
	if is_instance_valid(player) and player.has_signal("died"):
		player.died.connect(_on_player_died)
	# Combo readout — dynamically appended so we don't have to touch main.tscn.
	if is_instance_valid(player) and player.has_signal("combo_changed"):
		_setup_combo_label()
		player.combo_changed.connect(_on_combo_changed)
	# Lucky Start meta upgrade: 1 bomb per level
	var lucky_lvl: int = MetaSave.upgrade_level("lucky_start")
	if lucky_lvl > 0 and is_instance_valid(player) and player.has_method("grant_special"):
		player.grant_special("bomb", lucky_lvl)
	_start_room()

func _process(delta: float) -> void:
	if state != State.GAME_OVER:
		RunState.stats_run_seconds += delta
	_update_health_bar()
	_update_boss_bar()
	_update_bombs_label()
	# Scroll-floor camera + horizon follow
	if _is_traversal and is_instance_valid(_camera) and is_instance_valid(player):
		_camera.position = Vector2(player.position.x, 405.0)
		if is_instance_valid(sky_sprite):
			sky_sprite.position.x = _camera.get_screen_center_position().x
	# fallback: if player vanished without firing the died signal, still flip to game over
	if state != State.GAME_OVER and not is_instance_valid(player):
		_on_player_died()
		return
	if state == State.PLAYING:
		if get_tree().get_nodes_in_group("enemies").is_empty():
			if depth >= FINAL_FLOOR:
				_on_victory()
			else:
				_open_door()

func _update_health_bar() -> void:
	if not is_instance_valid(player):
		health_fill.offset_right = HEALTH_BAR_LEFT
		health_label.text = "HP 0"
		return
	var hp: int = player.get("health")
	var max_hp: int = player.get("max_health")
	if max_hp <= 0:
		return
	var ratio: float = clamp(float(hp) / float(max_hp), 0.0, 1.0)
	health_fill.offset_right = HEALTH_BAR_LEFT + (HEALTH_BAR_RIGHT - HEALTH_BAR_LEFT) * ratio
	# colour shifts green -> yellow -> red as HP drops
	var c: Color = Color(0.35, 0.85, 0.42)
	if ratio < 0.6:
		c = Color(0.95, 0.78, 0.25)
	if ratio < 0.3:
		c = Color(0.92, 0.32, 0.28)
	health_fill.color = c
	health_label.text = "HP %d / %d" % [hp, max_hp]

func _input(event: InputEvent) -> void:
	# R works during the brief explosion delay before the pop-up appears too
	if state == State.GAME_OVER and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		if not has_node("GameOverScreen"):
			get_tree().reload_current_scene()
		return
	# Esc during play opens the dev menu (don't open if any overlay is already active)
	if state == State.PLAYING and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if not _any_overlay_open():
			_open_dev_menu()
			get_viewport().set_input_as_handled()

func _any_overlay_open() -> bool:
	return has_node("DevMenu") or has_node("BoonCardScreen") or has_node("GameOverScreen")

func _open_dev_menu() -> void:
	get_tree().paused = true
	var menu := DevMenuScene.instantiate()
	menu.main_ref = self
	add_child(menu)

# --- Dev menu helpers ---

func dev_heal_player() -> void:
	if is_instance_valid(player) and player.has_method("heal"):
		player.heal(999)

func dev_skip_floor() -> void:
	# Clear enemies, advance, reset position. Skips boon screen entirely.
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.queue_free()
	state = State.CLEARED
	depth += 1
	if is_instance_valid(player):
		player.position = Vector2(80.0, PLAY_CENTER_Y)
	_start_room()

func dev_spawn_boss() -> void:
	if is_instance_valid(_boss):
		_boss.queue_free()
		_boss = null
	_spawn_boss()

func dev_give_random_boon() -> void:
	# Reach into the full pool, not the offer roll, so a maxed boon doesn't block this.
	var pool: Array = RunState.COMMON_POOL.duplicate()
	pool.shuffle()
	for b in pool:
		if not RunState.is_maxed(b.id):
			RunState.add(b.id)
			if is_instance_valid(player) and player.has_method("apply_boons"):
				player.apply_boons()
			status_label.modulate = Color(1, 0.95, 0.4, 1)
			status_label.text = "+ %s" % b.name
			var tw := create_tween()
			tw.tween_interval(1.2)
			tw.tween_property(status_label, "modulate:a", 0.0, 0.6)
			return

func dev_give_bombs(n: int) -> void:
	dev_grant_special("bomb", n)

func dev_grant_special(weapon: String, n: int) -> void:
	if is_instance_valid(player) and player.has_method("grant_special"):
		player.grant_special(weapon, n)

func dev_kill_all_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.has_method("take_damage"):
			e.take_damage(99999)

func _start_room() -> void:
	state = State.PLAYING
	_clear_room()
	_apply_biome()
	RunState.stats_floors_reached = max(RunState.stats_floors_reached, depth)
	MetaSave.note_floor_reached(depth)
	if is_instance_valid(player) and player.has_method("on_room_entered"):
		player.on_room_entered()
	var is_final_floor: bool = (depth == FINAL_FLOOR)
	var is_boss_floor: bool = is_final_floor or (depth % BOSS_EVERY == 0)
	var biome: String = _current_biome()
	# Decide arena shape (wide scroll vs fixed screen) and set up walls/camera
	# BEFORE anything spawns, so spawn ranges use the right width.
	var traversal: bool = (not is_boss_floor) and (depth in TRAVERSAL_FLOORS)
	_setup_floor_extent(traversal)
	if is_boss_floor:
		if is_final_floor:
			_spawn_final_boss()
		else:
			_spawn_boss()
		# Boss rooms: ZERO props (no trees/rocks/cacti) — clean arena so the
		# boss + player can move freely without snagging on residual collision
		# from cached old asset versions. Decorations stay (no collision).
		var biome_for_boss: String = _current_biome()
		_spawn_props(0)
		_spawn_decorations(28 if biome_for_boss == "sky" else 18)
		var label_tag: String = "FINAL BOSS" if is_final_floor else "BOSS"
		depth_label.text = "Floor %d  —  %s  (%s, %s)" % [depth, label_tag, biome.to_upper(), GameSettings.difficulty_name()]
	else:
		var prop_count: int = clamp(4 + depth, 5, 12)        # less cluttered cover (was 5+depth, max 16)
		_spawn_props(prop_count)
		_spawn_decorations(14)                                # less floor clutter (was 22)
		if biome == "forest":
			_spawn_ponds(randi_range(1, 2))                   # 1-2 ponds in forest floors
		# Hazards/saws disabled — user wants zero non-water blockers in arenas.
		# Spawn function still exists in case we re-enable later.
		# var saw_count: int = clamp((depth - 1) / 2, 1, 3)
		# _spawn_sweeper_saws(saw_count)
		var asc_enemy_mult: float = 1.0 + (0.5 if GameSettings.ascension >= 1 else 0.0)
		var base_count: float = float(2 + depth) * GameSettings.enemy_count_multiplier() * asc_enemy_mult
		var enemy_count: int = max(1, int(round(base_count)))
		if _is_traversal:
			# Spread the wave (a bit denser to fill the longer floor) across
			# clusters the player pushes through left-to-right.
			_spawn_traversal_enemies(int(round(enemy_count * 1.6)))
			depth_label.text = "Floor %d  (%s, %s)   →  reach the far side" % [depth, biome.to_upper(), GameSettings.difficulty_name()]
		else:
			for i in enemy_count:
				_spawn_enemy()
			depth_label.text = "Floor %d  (%s, %s)" % [depth, biome.to_upper(), GameSettings.difficulty_name()]
	status_label.text = ""

func _current_biome() -> String:
	# 5-biome rotation across a 10-floor run; final boss in fall.
	if depth == FINAL_FLOOR:
		return "fall"
	match depth:
		1, 2, 3: return "forest"
		4, 5, 6: return "desert"
		7:       return "sky"
		8:       return "snow"
		9:       return "sky"
		_:       return "fall"

func _apply_biome() -> void:
	var biome: String = _current_biome()
	if sky_sprite and BIOME_HORIZONS.has(biome):
		sky_sprite.texture = BIOME_HORIZONS[biome]
	if floor_rect:
		match biome:
			"desert": floor_rect.color = BIOME_DESERT_COLOR
			"sky":    floor_rect.color = BIOME_SKY_COLOR
			"snow":   floor_rect.color = BIOME_SNOW_COLOR
			"fall":   floor_rect.color = BIOME_FALL_COLOR
			_:        floor_rect.color = BIOME_FOREST_COLOR

func _setup_floor_extent(traversal: bool) -> void:
	# Widen (or restore) the playfield and reposition the bounding walls, then
	# attach/detach the follow-camera. Called before any spawning each room.
	_is_traversal = traversal
	_floor_width = LONG_W if traversal else WORLD_W
	if floor_rect:
		floor_rect.offset_right = _floor_width
	if is_instance_valid(wall_right):
		wall_right.position.x = _floor_width + 25.0
	# Top/bottom walls must span the whole length so the player can't slip out.
	var span: float = (_floor_width + 80.0) if traversal else 1480.0
	for w in [wall_top, wall_bottom]:
		if is_instance_valid(w):
			w.position.x = _floor_width / 2.0
			var cs: CollisionShape2D = w.get_node_or_null("CollisionShape2D")
			if cs and cs.shape is RectangleShape2D:
				(cs.shape as RectangleShape2D).size.x = span
	# Fixed floors keep the horizon centred; scroll floors track it in _process.
	if not traversal and is_instance_valid(sky_sprite):
		sky_sprite.position.x = WORLD_W / 2.0
	_setup_camera(traversal)

func _setup_camera(traversal: bool) -> void:
	# One persistent camera for the whole game (so screen-shake always has a
	# target). Traversal floors follow the player across a wide limit; fixed
	# floors lock it dead-centre over the single screen.
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_bottom = int(WORLD_H)
	if traversal:
		_camera.limit_right = int(_floor_width)
		_camera.position_smoothing_enabled = true
		_camera.position_smoothing_speed = 7.0
		if is_instance_valid(player):
			_camera.position = Vector2(player.position.x, 405.0)
	else:
		_camera.limit_right = int(WORLD_W)
		_camera.position_smoothing_enabled = false
		_camera.position = Vector2(WORLD_W / 2.0, 405.0)

func _spawn_traversal_enemies(total: int) -> void:
	if total <= 0:
		return
	# Three clusters along the length. Leave the first ~700px clear so the
	# player isn't dog-piled at the entrance.
	var bands: Array = [
		Vector2(700.0, _floor_width * 0.35),
		Vector2(_floor_width * 0.40, _floor_width * 0.70),
		Vector2(_floor_width * 0.72, _floor_width - MARGIN - 60.0),
	]
	for i in total:
		var band: Vector2 = bands[i % bands.size()]
		_spawn_enemy_in_band(band.x, band.y)

func _clear_room() -> void:
	for p in _room_props:
		if is_instance_valid(p):
			p.queue_free()
	_room_props.clear()
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.queue_free()
	# Boss may have already left the "enemies" group via _begin_death (which
	# removes from the group BEFORE the death animation completes). Sweep the
	# direct _boss reference too so a mid-death-animation boss doesn't persist.
	if is_instance_valid(_boss):
		_boss.queue_free()
		_boss = null
	# Also nuke any lingering hostile projectiles, telegraphs, fire patches,
	# slam rings, etc that belong to the room we're leaving.
	for n in get_children():
		if not is_instance_valid(n):
			continue
		if n is Node and (n.is_in_group("hostile_projectile") or n.is_in_group("hazards")):
			n.queue_free()
	if is_instance_valid(_door):
		_door.queue_free()
	_door = null

func _spawn_props(count: int) -> void:
	# Biome-themed obstacle cover (trees/stones in forest, cacti/rocks in desert).
	var avoid_positions: Array[Vector2] = []
	if is_instance_valid(player):
		avoid_positions.append(player.position)
	for n in get_children():
		if n.is_in_group("enemies") and n is Node2D:
			avoid_positions.append((n as Node2D).position)
	var placed: Array[Vector2] = []
	for i in count:
		for _attempt in 20:
			var p := Vector2(
				randf_range(MARGIN, _floor_width - MARGIN),
				randf_range(SPAWN_Y_MIN, SPAWN_Y_MAX)
			)
			var too_close: bool = false
			for ap in avoid_positions:
				if p.distance_to(ap) < 140.0:
					too_close = true
					break
			if too_close:
				continue
			for ep in placed:
				if p.distance_to(ep) < 110.0:
					too_close = true
					break
			if too_close:
				continue
			placed.append(p)
			var scene_to_use: PackedScene = _pick_prop_scene()
			# Sky biome returns null — skip placing a prop entirely so the
			# slot is just open ground.
			if scene_to_use == null:
				break
			var c := scene_to_use.instantiate()
			c.position = p
			if c is Node2D:
				var s: float = randf_range(0.92, 1.10)
				var sprite := c.get_node_or_null("Sprite")
				if sprite is Sprite2D:
					(sprite as Sprite2D).scale *= s
			add_child(c)
			_room_props.append(c)
			break

func _pick_prop_scene() -> PackedScene:
	var biome: String = _current_biome()
	# Sky biome (Floor 9 / Face Boss) — NO blocking props. Trees + rocks at
	# this altitude were just snagging the player and the bosses' charges.
	# We return null and _spawn_props handles that as "skip this slot."
	if biome == "sky":
		return null
	if biome == "desert":
		var r: float = randf()
		if r < 0.45:
			return CactusTallScene
		elif r < 0.80:
			return CactusRoundScene
		else:
			return DesertRocksScene
	# forest
	var r2: float = randf()
	if r2 < 0.40:
		return TreeScene
	elif r2 < 0.75:
		return PineTreeScene
	else:
		return StoneScene

func _pick_decoration_scene() -> PackedScene:
	# Sky biome uses extra bushes too — the only ground texture there now.
	return DesertBushScene if _current_biome() == "desert" else BushScene

func _spawn_decorations(count: int) -> void:
	# Pure decoration — no collision, no obstacle. Biome-appropriate.
	var player_pos: Vector2 = player.position if is_instance_valid(player) else Vector2(WORLD_W / 2.0, PLAY_CENTER_Y)
	for i in count:
		for _attempt in 12:
			var p := Vector2(
				randf_range(MARGIN, _floor_width - MARGIN),
				randf_range(SPAWN_Y_MIN, SPAWN_Y_MAX)
			)
			if p.distance_to(player_pos) < 70.0:
				continue
			var on_prop: bool = false
			for prop in _room_props:
				if is_instance_valid(prop) and (prop as Node2D).position.distance_to(p) < 60.0:
					on_prop = true
					break
			if on_prop:
				continue
			var b := _pick_decoration_scene().instantiate()
			b.position = p
			if b is Sprite2D:
				var sb: float = randf_range(0.85, 1.25)
				(b as Sprite2D).scale = (b as Sprite2D).scale * sb
				if randf() < 0.5:
					(b as Sprite2D).flip_h = true
				# subtle transparency so decorations read as floor-detail not cover
				(b as Sprite2D).modulate.a = 0.78
			add_child(b)
			_room_props.append(b)
			break

func _spawn_ponds(count: int) -> void:
	# Slow-zone ponds. Placed away from spawn + away from each other so they
	# can't trap the player or wall off a quadrant.
	var player_pos: Vector2 = player.position if is_instance_valid(player) else Vector2(WORLD_W / 2.0, PLAY_CENTER_Y)
	var placed: Array[Vector2] = []
	for i in count:
		for _attempt in 20:
			var p := Vector2(
				randf_range(MARGIN + 150.0, _floor_width - MARGIN - 150.0),
				randf_range(SPAWN_Y_MIN + 60.0, SPAWN_Y_MAX - 60.0)
			)
			if p.distance_to(player_pos) < 260.0:
				continue
			var too_close: bool = false
			for ep in placed:
				if p.distance_to(ep) < 320.0:
					too_close = true
					break
			if too_close:
				continue
			# don't overlap an obstacle
			for prop in _room_props:
				if is_instance_valid(prop) and (prop as Node2D).position.distance_to(p) < 110.0:
					too_close = true
					break
			if too_close:
				continue
			placed.append(p)
			var pond := PondScene.instantiate()
			pond.position = p
			add_child(pond)
			_room_props.append(pond)
			break

func _spawn_hazards(count: int) -> void:
	if count <= 0:
		return
	var player_pos: Vector2 = player.position if is_instance_valid(player) else Vector2(WORLD_W / 2.0, PLAY_CENTER_Y)
	var placed: Array[Vector2] = []
	for i in count:
		for _attempt in 25:
			var p := Vector2(
				randf_range(MARGIN + 50.0, _floor_width - MARGIN - 50.0),
				randf_range(SPAWN_Y_MIN + 30.0, SPAWN_Y_MAX - 30.0)
			)
			if p.distance_to(player_pos) < 180.0:
				continue
			var too_close: bool = false
			for ep in placed:
				if p.distance_to(ep) < 130.0:
					too_close = true
					break
			if too_close:
				continue
			# don't overlap a cylinder either
			var on_cylinder: bool = false
			for prop in _room_props:
				if is_instance_valid(prop) and (prop as Node2D).position.distance_to(p) < 80.0:
					on_cylinder = true
					break
			if on_cylinder:
				continue
			placed.append(p)
			var h := HazardScene.instantiate()
			h.position = p
			add_child(h)
			_room_props.append(h)
			break

func _spawn_sweeper_saws(count: int) -> void:
	if count <= 0:
		return
	var player_pos: Vector2 = player.position if is_instance_valid(player) else Vector2(WORLD_W / 2.0, PLAY_CENTER_Y)
	var placed: Array[Vector2] = []
	for i in count:
		for _attempt in 30:
			var p := Vector2(
				randf_range(MARGIN + 140.0, _floor_width - MARGIN - 140.0),
				randf_range(SPAWN_Y_MIN + 70.0, SPAWN_Y_MAX - 70.0)
			)
			# saw blade needs clearance for its sweep — keep it far from player spawn
			if p.distance_to(player_pos) < 220.0:
				continue
			var too_close: bool = false
			for ep in placed:
				if p.distance_to(ep) < 260.0:
					too_close = true
					break
			if too_close:
				continue
			var on_prop: bool = false
			for prop in _room_props:
				if is_instance_valid(prop) and (prop as Node2D).position.distance_to(p) < 130.0:
					on_prop = true
					break
			if on_prop:
				continue
			placed.append(p)
			var s := SweeperSawScene.instantiate()
			s.position = p
			# random axis: horizontal or vertical (only) so the motion reads cleanly
			s.set("direction_angle_deg", 0.0 if randf() > 0.5 else 90.0)
			add_child(s)
			_room_props.append(s)
			break

func _spawn_enemy() -> void:
	_spawn_enemy_in_band(MARGIN, _floor_width - MARGIN)

func _spawn_enemy_in_band(x_min: float, x_max: float) -> void:
	if DevState.no_enemies:
		return
	var player_pos: Vector2 = player.position if is_instance_valid(player) else Vector2(_floor_width / 2.0, PLAY_CENTER_Y)
	for _attempt in 30:
		var p := Vector2(
			randf_range(x_min, x_max),
			randf_range(SPAWN_Y_MIN, SPAWN_Y_MAX)
		)
		if p.distance_to(player_pos) < 200.0:
			continue
		# Variant roll across four mob types:
		#   25% KK (regular brown bear)
		#   25% MB (plush brawler — charges)
		#   25% Shrinkwrap (plastic-deflect bag bear)
		#   25% Gun Bear (mid-range bullet shooter)
		var roll: float = randf()
		var scene: PackedScene = EnemyScene
		if roll < 0.25:
			scene = PlushBrawlerScene
		elif roll < 0.50:
			scene = ShrinkwrapBearScene
		elif roll < 0.75:
			scene = GunBearScene
		var e := scene.instantiate()
		e.position = p
		add_child(e)
		return

func _spawn_final_boss() -> void:
	# Floor 10 — Desert Boss with is_final_fight enabled (gets phase 3 at 25% HP).
	var b := DesertBossScene.instantiate()
	var player_pos: Vector2 = player.position if is_instance_valid(player) else Vector2(WORLD_W / 2.0, PLAY_CENTER_Y)
	var pos: Vector2 = Vector2(WORLD_W * 0.72, PLAY_CENTER_Y)
	for _attempt in 30:
		var p := Vector2(
			randf_range(MARGIN + 150.0, _floor_width - MARGIN - 150.0),
			randf_range(SPAWN_Y_MIN + 60.0, SPAWN_Y_MAX - 60.0)
		)
		if p.distance_to(player_pos) >= 420.0:
			pos = p
			break
	b.position = pos
	b.is_final_fight = true
	# crank up base stats so the final fight is meatier; asc bumps it further
	var hp_mult: float = 1.4
	if GameSettings.ascension >= 2:
		hp_mult += 0.3
	if GameSettings.ascension >= 5:
		hp_mult += 0.5
	b.max_health = int(b.max_health * hp_mult)
	# tint red so the player reads "this one's different"
	var rig := b.get_node_or_null("Rig")
	if rig:
		(rig as Node2D).modulate = Color(1.05, 0.7, 0.55, 1.0)
	add_child(b)
	_boss = b

func _spawn_boss() -> void:
	# Boss rotation by biome:
	#   forest  → BossScene (original first boss)
	#   desert  → DesertBossScene (charge-dash boss)
	#   sky     → FaceBossScene (giant floating teddy, photo from 7.jpg)
	var biome: String = _current_biome()
	var scene: PackedScene = BossScene
	if biome == "desert":
		scene = DesertBossScene
	elif biome == "sky":
		scene = FaceBossScene
	var b := scene.instantiate()
	# Ascension 2: regular bosses +30% HP
	if GameSettings.ascension >= 2:
		b.max_health = int(b.max_health * 1.3)
	var player_pos: Vector2 = player.position if is_instance_valid(player) else Vector2(WORLD_W / 2.0, PLAY_CENTER_Y)
	var pos: Vector2 = Vector2(WORLD_W * 0.72, PLAY_CENTER_Y)  # fallback
	for _attempt in 30:
		var p := Vector2(
			randf_range(MARGIN + 150.0, _floor_width - MARGIN - 150.0),
			randf_range(SPAWN_Y_MIN + 60.0, SPAWN_Y_MAX - 60.0)
		)
		if p.distance_to(player_pos) >= 420.0:
			pos = p
			break
	b.position = pos
	add_child(b)
	_boss = b

func _update_boss_bar() -> void:
	if not is_instance_valid(_boss):
		_set_boss_bar_visible(false)
		return
	var hp_v: Variant = _boss.get("health")
	var max_v: Variant = _boss.get("max_health")
	if not (hp_v is int) or not (max_v is int):
		_set_boss_bar_visible(false)
		return
	var hp: int = hp_v
	var mx: int = max_v
	if hp <= 0 or mx <= 0:
		_set_boss_bar_visible(false)
		return
	_set_boss_bar_visible(true)
	var ratio: float = clamp(float(hp) / float(mx), 0.0, 1.0)
	boss_health_fill.offset_right = -BOSS_BAR_HALF_W + 2.0 * BOSS_BAR_HALF_W * ratio
	var is_final_v: Variant = _boss.get("is_final_fight")
	var prefix: String = "FINAL BOSS" if (is_final_v is bool and is_final_v) else "BOSS BEAR"
	boss_health_label.text = "%s    %d / %d" % [prefix, hp, mx]
	if is_final_v is bool and is_final_v:
		boss_health_fill.color = Color(1.0, 0.32, 0.32, 1.0)
	else:
		boss_health_fill.color = Color(0.85, 0.22, 0.35, 1.0)

func _set_boss_bar_visible(v: bool) -> void:
	boss_health_frame.visible = v
	boss_health_back.visible = v
	boss_health_fill.visible = v
	boss_health_label.visible = v

func _update_bombs_label() -> void:
	if not is_instance_valid(player):
		bombs_label.visible = false
		return
	var n_v: Variant = player.get("special_charges")
	var name_v: Variant = player.get("active_special")
	var n: int = (n_v as int) if n_v is int else 0
	var weapon_name: String = (name_v as String) if name_v is String else ""
	if n > 0 and weapon_name != "":
		bombs_label.text = "%s x %d" % [weapon_name.to_upper(), n]
		bombs_label.visible = true
	else:
		bombs_label.visible = false

func _open_door() -> void:
	state = State.CLEARED
	_door = DoorScene.instantiate()
	if _is_traversal:
		# Exit sits at the far end of the crawl — the reward for pushing through.
		_door.position = Vector2(_floor_width - 220.0, PLAY_CENTER_Y) \
			+ Vector2(randf_range(-40.0, 40.0), randf_range(-130.0, 130.0))
	else:
		# pop randomly NEAR the centre of the room — not exactly on it
		var angle: float = randf_range(0.0, TAU)
		var dist: float = randf_range(140.0, 240.0)
		var centre: Vector2 = Vector2(WORLD_W / 2.0, PLAY_CENTER_Y)
		_door.position = centre + Vector2(cos(angle), sin(angle)) * dist
	_door.entered_by_player.connect(_advance_room)
	add_child(_door)
	status_label.modulate = Color(1, 0.95, 0.4, 1)
	status_label.text = "FLOOR CLEARED"
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(status_label, "modulate:a", 0.0, 1.0)

func _advance_room() -> void:
	if state != State.CLEARED:
		return
	_show_boon_screen()

func _show_boon_screen() -> void:
	get_tree().paused = true
	var screen := BoonCardScene.instantiate()
	screen.boon_selected.connect(_on_boon_selected)
	add_child(screen)

func _on_boon_selected(boon_id: String) -> void:
	if boon_id != "":
		RunState.add(boon_id)  # empty string = skipped (all boons maxed)
	get_tree().paused = false
	if is_instance_valid(player) and player.has_method("apply_boons"):
		player.apply_boons()
	depth += 1
	if is_instance_valid(player):
		player.position = Vector2(80.0, PLAY_CENTER_Y)
	_start_room()

func _on_victory() -> void:
	if state == State.VICTORY:
		return
	state = State.VICTORY
	# Ascension multiplier: +20% rewards per active asc level
	var asc: int = GameSettings.ascension
	var mult: float = 1.0 + 0.2 * float(asc)
	var fluff_gain: int = int(round(float(FINAL_FLUFF_REWARD) * mult))
	var cotton_gain: int = int(round(float(FINAL_COTTON_REWARD) * mult))
	MetaSave.add_fluff(fluff_gain)
	MetaSave.add_cotton(cotton_gain)
	MetaSave.record_victory()
	# If you just beat the highest asc you'd unlocked, the next asc opens up
	if asc >= MetaSave.max_ascension and MetaSave.max_ascension < 5:
		MetaSave.unlock_ascension_up_to(MetaSave.max_ascension + 1)
	RunState.stats_fluff_earned += fluff_gain
	status_label.modulate = Color(1, 0.95, 0.4, 1)
	status_label.text = "FLOOR CLEARED"
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(status_label, "modulate:a", 0.0, 0.8)
	# Wait for boss death animation to play out before the victory screen
	var t := get_tree().create_timer(3.0)
	t.timeout.connect(_show_victory_screen)

func _show_victory_screen() -> void:
	if has_node("VictoryScreen"):
		return
	var screen := VictoryScene.instantiate()
	var mult: float = 1.0 + 0.2 * float(GameSettings.ascension)
	screen.fluff_reward = int(round(float(FINAL_FLUFF_REWARD) * mult))
	screen.cotton_reward = int(round(float(FINAL_COTTON_REWARD) * mult))
	screen.ascension_beaten = GameSettings.ascension
	screen.restart_requested.connect(_on_restart_requested)
	screen.menu_requested.connect(_on_menu_requested)
	add_child(screen)

func _on_player_died() -> void:
	if state == State.GAME_OVER:
		return
	state = State.GAME_OVER
	status_label.text = ""
	# delay the pop-up so the death explosion + chunks have a moment to breathe
	var t := get_tree().create_timer(GAME_OVER_DELAY)
	t.timeout.connect(_show_game_over_screen)

func _show_game_over_screen() -> void:
	if has_node("GameOverScreen"):
		return
	var screen := GameOverScene.instantiate()
	screen.depth = depth
	screen.restart_requested.connect(_on_restart_requested)
	screen.menu_requested.connect(_on_menu_requested)
	add_child(screen)

func _on_restart_requested() -> void:
	get_tree().reload_current_scene()

func _on_menu_requested() -> void:
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")

# --- Combo HUD --------------------------------------------------------------
var _combo_label: Label = null

func _setup_combo_label() -> void:
	var hud := get_node_or_null("HUD")
	if not (hud is CanvasItem):
		return
	var lbl := Label.new()
	lbl.name = "ComboLabel"
	lbl.text = ""
	lbl.modulate = Color(1.0, 0.92, 0.55, 0.0)  # starts invisible
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 4)
	# Anchor top-right
	lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lbl.position = Vector2(-260, 20)
	lbl.size = Vector2(240, 40)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(lbl)
	_combo_label = lbl

func _on_combo_changed(count: int) -> void:
	if not is_instance_valid(_combo_label):
		return
	if count < 2:
		# Below 2 = nothing worth shouting about. Fade out.
		var tw := _combo_label.create_tween()
		tw.tween_property(_combo_label, "modulate:a", 0.0, 0.25)
		return
	_combo_label.text = "COMBO ×%d" % count
	# Snap to full alpha + scale punch + fade back to readable steady state
	_combo_label.modulate = Color(1.0, 0.92, 0.55, 1.0)
	_combo_label.scale = Vector2(1.35, 1.35)
	var tw2 := _combo_label.create_tween()
	tw2.tween_property(_combo_label, "scale", Vector2(1.0, 1.0), 0.18)
