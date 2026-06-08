extends "res://scripts/enemy.gd"

# Brown plush bear with a rifle. Tankier than KK, slower, fires a fast bullet
# every few seconds with a brief windup. Prefers mid-range — backs off if you
# get too close so he can keep shooting.

const BearBulletScene := preload("res://scenes/bear_bullet.tscn")
const TEX_PATH := "res://assets/gun_bear.png"

@onready var sprite: Sprite2D = $Rig/Body

# Shooting tuning
const SHOOT_COOLDOWN: float = 4.2
const SHOOT_WINDUP: float = 0.45
const SHOOT_RANGE: float = 460.0
const SHOOT_MIN_DIST: float = 90.0     # too close — kite back instead
const BULLET_SPEED: float = 460.0   # real bullet — snappy
const KITE_DISTANCE: float = 220.0     # preferred standoff range

var _shoot_t: float = 0.0
var _shoot_windup: float = 0.0
var _shoot_dir: Vector2 = Vector2.RIGHT

func _ready() -> void:
	max_health = 5         # tankier than KK (3) but less than MB (6)
	throws_stars = false   # has its own bullet
	speed = 78.0           # slower than KK
	touch_damage = 1
	super._ready()
	if is_instance_valid(sprite):
		var t: Texture2D = _load_tex(TEX_PATH)
		sprite.texture = t
		if t == null:
			push_warning("[gun_bear] couldn't load %s — removing self" % TEX_PATH)
			queue_free()
			return
	_shoot_t = randf_range(1.5, SHOOT_COOLDOWN)  # stagger initial cooldown

func _load_tex(path: String) -> Texture2D:
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

func _physics_process(delta: float) -> void:
	# Wind-up phase: gun bear stops moving and "aims" briefly before firing.
	if _shoot_windup > 0.0:
		_shoot_windup -= delta
		velocity = Vector2.ZERO
		modulate = Color(1.4, 1.0, 0.7)   # bright tint = aiming
		move_and_slide()
		if _shoot_windup <= 0.0:
			modulate = Color(1, 1, 1)
			_fire_bullet()
		return
	# Normal behavior — defer to base enemy steering but enforce a standoff.
	super._physics_process(delta)
	if not is_instance_valid(player):
		return
	# Cooldown tick — only fires when player is in shooting range.
	_shoot_t -= delta
	if _shoot_t <= 0.0:
		_shoot_t = SHOOT_COOLDOWN + randf_range(-0.5, 0.5)
		var d: float = global_position.distance_to(player.global_position)
		var grace: bool = ArpgState.active and ArpgState.in_spawn_grace()
		if not grace and d >= SHOOT_MIN_DIST and d <= SHOOT_RANGE and (not ArpgState.active or _has_los_to_player()):
			_shoot_dir = (player.global_position - global_position).normalized()
			_shoot_windup = SHOOT_WINDUP

func _fire_bullet() -> void:
	# Up his game: a 3-round burst fan instead of one lonely bullet — same slow
	# cadence between bursts, but now it actually threatens you.
	for off in [-0.13, 0.0, 0.13]:
		var bullet := BearBulletScene.instantiate()
		var dir: Vector2 = _shoot_dir.rotated(off)
		bullet.global_position = global_position + dir * 14.0
		bullet.set("direction", dir)
		bullet.set("speed", BULLET_SPEED)
		get_parent().add_child(bullet)

# Override the inherited KK spit attack — gun bear has its own ranged attack
# (the fluff ball). Without this, on Medium difficulty he'd also fire a brown
# spit blob in addition to the fluff, looking like "two projectiles."
func _tick_spit(_delta: float) -> void:
	pass
