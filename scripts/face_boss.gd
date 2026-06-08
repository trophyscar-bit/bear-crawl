extends CharacterBody2D

# "The Big One" — boss whose body is just a giant bear face floating in the
# sky. Follows the player horizontally with a slow lerp; flips on midpoint
# crossing. Doesn't physics-move (velocity always 0), but is a CharacterBody2D
# so pizzas can hit it via the "enemies" group + collision pipeline.
#
# Phase 1 (100%–66% HP): paw slams + tooth projectiles.
# Phase 2 ( 66%–33% HP): + horizontal paw sweeps + floor cleaves.
# Phase 3 (<33% HP):     + tooth volleys (5-fan) + mini-paw rain.

const ROOM_W: float = 1440.0
const ROOM_H: float = 810.0

const FACE_TEX_PATH := "res://assets/sky_boss.png"
const FACE_RADIUS: float = 220.0  # used for the circular collision shape
const BearPawSlamScene := preload("res://scenes/bear_paw_slam.tscn")
const PawSweepScene    := preload("res://scenes/paw_sweep.tscn")
const ToothScene       := preload("res://scenes/tooth_projectile.tscn")
const FloorCleaveScene := preload("res://scenes/floor_cleave.tscn")
const ExplosionScene   := preload("res://scenes/explosion.tscn")
const BodyChunkScene   := preload("res://scenes/body_chunk.tscn")
const FullHealScene    := preload("res://scenes/full_heal.tscn")

@export var max_health: int = 54         # bumped from 42 — fight needs more time across 3 phases
@export var touch_damage: int = 2

# Face placement — 30% larger than the previous build (scale 0.58 → 0.75)
const FACE_HEIGHT_FRAC: float = 0.75
const FACE_Y: float = 180.0   # was 270 — back up high where it belonged
const FACE_LERP: float = 1.4
const FACE_X_MIN: float = 420.0
const FACE_X_MAX: float = ROOM_W - 420.0
const BOB_HZ: float = 0.6
const BOB_AMP: float = 14.0

# Phase 1 timers
const SLAM_COOLDOWN: float = 4.8
const TOOTH_COOLDOWN: float = 2.8
# Phase 2 timers
const SWEEP_COOLDOWN: float = 9.0
const CLEAVE_COOLDOWN: float = 9.5
# Phase 3 timers
const VOLLEY_COOLDOWN: float = 6.0
const MINI_RAIN_COOLDOWN: float = 7.5

const CLEAVE_TELEGRAPH: float = 1.8
const CLEAVE_ACTIVE: float = 0.35
const CLEAVE_DAMAGE: int = 2

var health: int
var _t: float = 0.0
var _phase: int = 1
var _facing: int = 1
var _target_x: float = ROOM_W * 0.5
var _slam_t: float = 2.0
var _tooth_t: float = 1.4
var _sweep_t: float = 9999.0
var _cleave_t: float = 9999.0
var _volley_t: float = 9999.0
var _mini_rain_t: float = 9999.0
var _hit_cooldown: float = 0.0
const HIT_INVULN: float = 0.16
# Touch damage to player when they're INSIDE the boss silhouette. Player is
# on a different collision layer (he walks through the body), but anyone
# standing inside the giant head should take damage on a cooldown.
var _touch_dmg_cooldown: float = 0.0
const TOUCH_DMG_COOLDOWN: float = 0.5
const TOUCH_DMG_RADIUS: float = 180.0   # inside this distance = inside the head

var _sprite: Sprite2D = null
var _shape: CollisionShape2D = null
var _dying: bool = false
var _death_t: float = 0.0
const DEATH_DURATION: float = 1.8

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	# Use the cleave_maw.jpg photo per user direction.
	_sprite = Sprite2D.new()
	_sprite.texture = _load_face_texture()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_sprite)
	if _sprite.texture != null:
		var th: float = float(_sprite.texture.get_height())
		var s: float = (ROOM_H * FACE_HEIGHT_FRAC) / th
		_sprite.scale = Vector2(s, s)
	# Circular hit area — matches the round head silhouette better than a rect.
	_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = FACE_RADIUS * 0.95
	_shape.shape = circle
	add_child(_shape)
	global_position = Vector2(ROOM_W * 0.5, FACE_Y)
	_target_x = ROOM_W * 0.5
	# Move to layer 4 — pizzas mask this layer so they still hit the boss,
	# but the player's mask (1+3) does NOT include 4, so the player can walk
	# freely around/under the giant floating head. Fixes "invisible geo" from
	# the 200-radius collision circle.
	set_collision_layer_value(1, false)
	set_collision_layer_value(4, true)
	# We don't move physically anyway (velocity always 0), so clear the mask
	# so we never push the player either.
	set_collision_mask_value(1, false)
	# Render ABOVE all ground sprites/decorations (which use y-sort). Force a
	# high z_index so the giant head is always on top regardless of where
	# bushes / props sit on the y axis.
	z_index = 50
	z_as_relative = false
	print("[face_boss] _ready hp=%d" % health)

func _load_face_texture() -> Texture2D:
	var t: Texture2D = load(FACE_TEX_PATH) as Texture2D
	if t != null:
		return t
	if FileAccess.file_exists(FACE_TEX_PATH):
		var bytes := FileAccess.get_file_as_bytes(FACE_TEX_PATH)
		if bytes.size() > 0:
			var img := Image.new()
			if img.load_png_from_buffer(bytes) == OK:
				return ImageTexture.create_from_image(img)
	return null

func _physics_process(delta: float) -> void:
	if _dying:
		_process_death(delta)
		return
	_t += delta
	if _hit_cooldown > 0.0:
		_hit_cooldown -= delta
	if _touch_dmg_cooldown > 0.0:
		_touch_dmg_cooldown -= delta
	# Track player horizontally
	var pl := get_tree().get_first_node_in_group("player")
	if pl is Node2D:
		_target_x = clamp((pl as Node2D).global_position.x, FACE_X_MIN, FACE_X_MAX)
		# Touch damage — if player is INSIDE the boss silhouette, hit on a
		# cooldown. Without this, the layer-4 collision lets the player
		# stand inside the head and take no damage.
		var dist: float = (pl as Node2D).global_position.distance_to(global_position)
		if dist < TOUCH_DMG_RADIUS and _touch_dmg_cooldown <= 0.0:
			if pl.has_method("take_damage"):
				pl.take_damage(touch_damage)
				_touch_dmg_cooldown = TOUCH_DMG_COOLDOWN
	var new_x: float = lerp(global_position.x, _target_x, clamp(delta * FACE_LERP, 0.0, 1.0))
	var bob: float = sin(_t * BOB_HZ * TAU) * BOB_AMP
	global_position = Vector2(new_x, FACE_Y + bob)
	# Flip to face the player by mirroring sprite scale.
	if is_instance_valid(_sprite):
		if pl is Node2D:
			var px: float = (pl as Node2D).global_position.x
			_facing = 1 if px > global_position.x else -1
		var abs_sx: float = abs(_sprite.scale.x)
		_sprite.scale = Vector2(abs_sx * _facing, _sprite.scale.y)
	# ----- Phase 1+ attacks -----
	_slam_t -= delta
	if _slam_t <= 0.0:
		_slam_t = SLAM_COOLDOWN + randf_range(-0.8, 0.8)
		_spawn_paw_slam_under_player()
	_tooth_t -= delta
	if _tooth_t <= 0.0:
		_tooth_t = TOOTH_COOLDOWN + randf_range(-0.5, 0.5)
		_spit_tooth(1)
	# ----- Phase 2+ attacks -----
	if _phase >= 2:
		_sweep_t -= delta
		if _sweep_t <= 0.0:
			_sweep_t = SWEEP_COOLDOWN + randf_range(-1.5, 1.5)
			_spawn_paw_sweep()
		_cleave_t -= delta
		if _cleave_t <= 0.0:
			_cleave_t = CLEAVE_COOLDOWN + randf_range(-1.5, 1.5)
			_spawn_floor_cleave()
	# ----- Phase 3 attacks -----
	if _phase >= 3:
		_volley_t -= delta
		if _volley_t <= 0.0:
			_volley_t = VOLLEY_COOLDOWN + randf_range(-1.0, 1.0)
			_spit_tooth_volley(5, 22.0)
		_mini_rain_t -= delta
		if _mini_rain_t <= 0.0:
			_mini_rain_t = MINI_RAIN_COOLDOWN + randf_range(-1.5, 1.5)
			_spawn_mini_paw_rain(4)

# ---------------------------------------------------------------------------
# Attack spawners
# ---------------------------------------------------------------------------

func _spawn_paw_slam_under_player() -> void:
	var pl := get_tree().get_first_node_in_group("player")
	if not (pl is Node2D):
		return
	var paw := BearPawSlamScene.instantiate()
	paw.global_position = (pl as Node2D).global_position
	get_parent().add_child(paw)

func _spit_tooth(count: int) -> void:
	# Spits `count` teeth at the player from the face's mouth area.
	var pl := get_tree().get_first_node_in_group("player")
	if not (pl is Node2D):
		return
	var origin: Vector2 = global_position + Vector2(0, 60.0)
	for i in count:
		var dir: Vector2 = ((pl as Node2D).global_position - origin).normalized()
		var tooth := ToothScene.instantiate()
		tooth.global_position = origin
		tooth.set("direction", dir)
		# Phase 3 teeth move a bit faster and home harder
		if _phase >= 3:
			tooth.set("speed", 380.0)
			tooth.set("homing", 1.6)
		get_parent().add_child(tooth)

func _spit_tooth_volley(count: int, spread_deg: float) -> void:
	# Fan of teeth in a cone toward the player. No homing on volley shots —
	# they're meant to lock down territory, not curve back.
	var pl := get_tree().get_first_node_in_group("player")
	if not (pl is Node2D):
		return
	var origin: Vector2 = global_position + Vector2(0, 60.0)
	var center: Vector2 = ((pl as Node2D).global_position - origin).normalized()
	for i in count:
		var t: float = 0.0 if count == 1 else float(i) / float(count - 1)
		var offset: float = lerp(-spread_deg, spread_deg, t)
		var dir: Vector2 = center.rotated(deg_to_rad(offset))
		var tooth := ToothScene.instantiate()
		tooth.global_position = origin
		tooth.set("direction", dir)
		tooth.set("homing", 0.0)
		tooth.set("speed", 360.0)
		get_parent().add_child(tooth)

func _spawn_paw_sweep() -> void:
	# Horizontal sweep at a random Y BELOW the face. Band is taller so the
	# telegraph reads clearly across the entire side of the screen instead of
	# just looking like a band in the clouds.
	var sweep := PawSweepScene.instantiate()
	var y: float = randf_range(ROOM_H * 0.48, ROOM_H * 0.78)
	sweep.set("y_target", y)
	sweep.set("band_height", 220.0)   # was 130 — fills more of the side
	sweep.set("telegraph", 2.2)        # was 1.4 — more dodge time
	sweep.set("side", 0 if randf() < 0.5 else 1)
	get_parent().add_child(sweep)

func _spawn_floor_cleave() -> void:
	var pl := get_tree().get_first_node_in_group("player")
	var side: int = 0
	if pl is Node2D and (pl as Node2D).global_position.x > ROOM_W * 0.5:
		side = 1
	var cleave := FloorCleaveScene.instantiate()
	cleave.set("side", side)
	cleave.set("telegraph", CLEAVE_TELEGRAPH)
	cleave.set("active", CLEAVE_ACTIVE)
	cleave.set("damage", CLEAVE_DAMAGE)
	get_parent().add_child(cleave)

func _spawn_mini_paw_rain(count: int) -> void:
	# Spawn `count` paw slams at random positions across the room — chaos
	# but each is telegraphed individually so the player can read them.
	for i in count:
		var paw := BearPawSlamScene.instantiate()
		paw.global_position = Vector2(
			randf_range(120.0, ROOM_W - 120.0),
			randf_range(ROOM_H * 0.35, ROOM_H * 0.85)
		)
		# Stagger the telegraph slightly so they don't all detonate at once
		(paw as Node).set("telegraph", randf_range(0.85, 1.35))
		get_parent().add_child(paw)

# ---------------------------------------------------------------------------
# Damage / phase / death
# ---------------------------------------------------------------------------

func take_damage(amount: int, crit: bool = false) -> void:
	if _dying or _hit_cooldown > 0.0:
		return
	if DevState.oneshot_kills:
		health = 0
		_begin_death()
		return
	_hit_cooldown = HIT_INVULN
	health -= amount
	modulate = Color(1.4, 0.45, 0.45)
	get_tree().create_timer(0.08).timeout.connect(_clear_hit_flash)
	if health <= 0:
		_begin_death()
		return
	# Phase transitions at 66% and 33% of max HP.
	var two_thirds: int = int(max_health * 2.0 / 3.0)
	var one_third:  int = int(max_health * 1.0 / 3.0)
	if _phase == 1 and health <= two_thirds:
		_enter_phase_2()
	elif _phase == 2 and health <= one_third:
		_enter_phase_3()

func _clear_hit_flash() -> void:
	if is_instance_valid(self) and not _dying:
		modulate = Color(1, 1, 1)

func _enter_phase_2() -> void:
	_phase = 2
	_sweep_t = 3.5
	_cleave_t = 5.0
	modulate = Color(1.0, 0.75, 0.75)
	get_tree().create_timer(0.4).timeout.connect(func(): if is_instance_valid(self) and not _dying: modulate = Color(1, 1, 1))
	var pl := get_tree().get_first_node_in_group("player")
	if pl and pl.has_method("shake"):
		pl.shake(18.0, 0.4)

func _enter_phase_3() -> void:
	_phase = 3
	_volley_t = 2.0
	_mini_rain_t = 4.0
	# Tighten phase 1 timers too — at low HP everything ramps
	_slam_t = min(_slam_t, 2.5)
	_tooth_t = min(_tooth_t, 1.5)
	modulate = Color(1.2, 0.4, 0.4)
	get_tree().create_timer(0.6).timeout.connect(func(): if is_instance_valid(self) and not _dying: modulate = Color(1, 1, 1))
	var pl := get_tree().get_first_node_in_group("player")
	if pl and pl.has_method("shake"):
		pl.shake(28.0, 0.55)

func _begin_death() -> void:
	_dying = true
	remove_from_group("enemies")
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	var ex := ExplosionScene.instantiate()
	ex.global_position = global_position
	(ex as Node).set("end_scale", 6.0)
	get_parent().add_child(ex)
	for i in 26:
		var puff := BodyChunkScene.instantiate()
		puff.texture = preload("res://assets/stuffing.png")
		puff.global_position = global_position
		var ang: float = randf_range(0.0, TAU)
		puff.velocity = Vector2.RIGHT.rotated(ang) * randf_range(180, 460)
		puff.angular_velocity = randf_range(-12.0, 12.0)
		puff.initial_scale = randf_range(0.7, 1.5)
		puff.lifetime = randf_range(1.0, 1.6)
		get_parent().add_child(puff)
	MetaSave.add_fluff(5)
	RunState.stats_fluff_earned += 5
	var pl := get_tree().get_first_node_in_group("player")
	if pl is Node2D:
		var hp_v: Variant = pl.get("health")
		var max_v: Variant = pl.get("max_health")
		if hp_v is int and max_v is int and (hp_v as int) < (max_v as int):
			var heal_drop := FullHealScene.instantiate()
			heal_drop.global_position = global_position
			get_parent().add_child(heal_drop)
	if pl and pl.has_method("shake"):
		pl.shake(36.0, 0.7)

func _process_death(delta: float) -> void:
	_death_t += delta
	var p: float = clamp(_death_t / DEATH_DURATION, 0.0, 1.0)
	if is_instance_valid(_sprite):
		_sprite.modulate.a = 1.0 - p
		_sprite.rotation = sin(_death_t * 18.0) * 0.2 * (1.0 - p)
	if _death_t >= DEATH_DURATION:
		queue_free()

func chain_explode() -> void:
	if _dying:
		return
	health = 0
	_begin_death()
