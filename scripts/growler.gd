extends "res://scripts/enemy.gd"

# Growler — a tan teddy ARCHER (photo cutout, IMG_8138). Keeps his distance,
# kites away if you close in, and looses a FAST arrow from range. Reads as alive
# via a walk-bob squish + a rock/tilt toward his movement direction (like the
# player). Loses interest if he can't see you.

const TEX_PATH := "res://assets/growler.png"
const ArrowScene := preload("res://scenes/arrow.tscn")

const SHOOT_RANGE: float = 760.0
const KEEP_DIST: float = 300.0       # preferred standoff distance
const SHOOT_COOLDOWN: float = 2.2    # less spammy (was 1.3)
const SHOOT_WINDUP: float = 0.26
const ARROW_SPEED: float = 535.0     # another 15% slower (was 630)
const AGGRO_MEM: float = 5.0         # stays alert this long after losing sight

@onready var sprite: Sprite2D = $Rig/Body
@onready var _rig: Node2D = $Rig
var _bow: Sprite2D = null
const BOW_X: float = 86.0   # rig-local offset to his hand
var _rig_base_scale: Vector2 = Vector2.ONE
var _seen_t: float = 0.0
var _shoot_t: float = 0.0
var _windup: float = 0.0
var _shoot_dir: Vector2 = Vector2.RIGHT
var _anim_t: float = 0.0

func _ready() -> void:
	max_health = 7
	speed = 96.0          # nimble enough to kite
	touch_damage = 1
	super._ready()
	if is_instance_valid(_rig):
		_rig_base_scale = _rig.scale
		# Give him a little bow to carry (with a nocked arrow) so he reads as an archer.
		var bow := Sprite2D.new()
		bow.name = "Bow"
		bow.texture = load("res://assets/bow.png")
		bow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		bow.position = Vector2(BOW_X, 22.0)
		bow.z_index = 1
		_rig.add_child(bow)
		_bow = bow
	_shoot_t = randf_range(0.8, SHOOT_COOLDOWN)
	if is_instance_valid(sprite):
		var t: Texture2D = _load_tex_robust(TEX_PATH)
		if t != null:
			sprite.texture = t
		else:
			queue_free()

func _physics_process(delta: float) -> void:
	if _dying:
		super._physics_process(delta)
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		_animate(delta, 0.0)
		return
	var to_p: Vector2 = player.global_position - global_position
	var dist: float = to_p.length()
	var dir: Vector2 = to_p.normalized() if dist > 0.1 else Vector2.RIGHT
	# Aggro with a memory — needs current LOS to refresh, stays alert a while after.
	_seen_t = maxf(_seen_t - delta, 0.0)
	var has_los: bool = _has_los_to_player()
	if dist < SHOOT_RANGE and has_los:
		_seen_t = AGGRO_MEM
	var aggro: bool = (not ArpgState.active) or (_seen_t > 0.0)

	# Drawing the bow — stand still and aim, then loose. Still juke sideways if
	# he's being shot at (dodge), so he isn't a sitting duck mid-aim.
	if _windup > 0.0:
		_windup -= delta
		velocity = velocity.lerp(Vector2.ZERO, 0.35) + _dodge_tick(delta)
		modulate = Color(1.15, 1.0, 0.85)   # gentler aim-flash (was blowing out)
		move_and_slide()
		if _windup <= 0.0:
			modulate = Color(1, 1, 1)
			_fire_arrow()
		_animate(delta, velocity.length())
		return

	if not aggro:
		velocity = velocity.lerp(Vector2.ZERO, 0.2)
		move_and_slide()
		_animate(delta, velocity.length())
		return

	# Kite: back off if too close, advance if too far, else strafe.
	var desired: Vector2
	if dist < KEEP_DIST * 0.8:
		desired = -dir
	elif dist > KEEP_DIST * 1.35:
		desired = dir
	else:
		desired = Vector2(-dir.y, dir.x) * float(_orbit_sign)
	velocity = velocity.lerp(desired * speed, 0.12) + _dodge_tick(delta)
	move_and_slide()
	_contact_damage()
	_animate(delta, velocity.length())

	# Spawn grace blocks firing on level entry (no shots for the first 5s).
	if ArpgState.active and ArpgState.in_spawn_grace():
		return
	_shoot_t -= delta
	if _shoot_t <= 0.0 and dist <= SHOOT_RANGE and has_los:
		_shoot_t = SHOOT_COOLDOWN + randf_range(-0.3, 0.3)
		_shoot_dir = dir
		_windup = SHOOT_WINDUP

func _contact_damage() -> void:
	if damage_cooldown > 0.0:
		damage_cooldown -= get_physics_process_delta_time()
		return
	for i in get_slide_collision_count():
		var c := get_slide_collision(i).get_collider()
		if c and c.is_in_group("player") and c.has_method("take_damage"):
			c.take_damage(touch_damage)
			damage_cooldown = 0.6
			break

func _fire_arrow() -> void:
	var a := ArrowScene.instantiate()
	a.global_position = global_position + _shoot_dir * 20.0
	a.set("direction", _shoot_dir)
	a.set("speed", ARROW_SPEED)
	get_parent().add_child(a)
	if is_instance_valid(_rig):
		_rig.scale = Vector2(_rig_base_scale.x * 1.15, _rig_base_scale.y * 0.85)  # recoil

func _animate(delta: float, spd: float) -> void:
	if not is_instance_valid(_rig):
		return
	var moving: float = clampf(spd / 80.0, 0.0, 1.0)
	_anim_t += delta * 11.0
	var sy: float = 1.0 + sin(_anim_t) * 0.07 * moving
	var sx: float = 1.0 - (sy - 1.0) * 0.5
	_rig.scale = _rig.scale.lerp(
		Vector2(_rig_base_scale.x * sx, _rig_base_scale.y * sy), clampf(delta * 12.0, 0.0, 1.0))
	var tilt: float = clampf(velocity.x / 220.0, -1.0, 1.0) * 0.16
	_rig.rotation = lerp_angle(_rig.rotation, tilt, clampf(delta * 9.0, 0.0, 1.0))
	if is_instance_valid(sprite) and is_instance_valid(player):
		var face_left: bool = player.global_position.x < global_position.x
		sprite.flip_h = face_left
		# Keep the bow on the side he's facing, mirrored to match.
		if is_instance_valid(_bow):
			_bow.flip_h = face_left
			_bow.position.x = -BOW_X if face_left else BOW_X

func _load_tex_robust(path: String) -> Texture2D:
	var t: Texture2D = load(path) as Texture2D
	if t != null:
		return t
	if FileAccess.file_exists(path):
		var bytes := FileAccess.get_file_as_bytes(path)
		if bytes.size() > 0:
			var img := Image.new()
			if img.load_png_from_buffer(bytes) == OK:
				return ImageTexture.create_from_image(img)
	return null
