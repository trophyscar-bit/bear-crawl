extends "res://scripts/enemy.gd"

# Tankier brown-bear variant scanned from a real plush. Single sprite
# (front only — the back-view sprite was too jarring on each direction
# change). Adds a telegraphed shoulder-charge so he's not just a slow
# bigger version of the basic bear.
#
# Charge sequence:
#   1) When in CHARGE_MIN_DIST..CHARGE_MAX_DIST and cooldown is up, lock
#      target direction and freeze for CHARGE_TELEGRAPH seconds (red glow).
#   2) Dash in a straight line at CHARGE_SPEED for CHARGE_DURATION seconds.
#      Touch damage on hit (handled by existing enemy.gd collision check).
#   3) Long cooldown before another attempt.

@onready var sprite_front: Sprite2D = $Rig/Front

const FRONT_PATH := "res://assets/plush_brawler_front.png"

const CHARGE_COOLDOWN: float = 5.0
const CHARGE_TELEGRAPH: float = 0.55
const CHARGE_DURATION: float = 0.45
const CHARGE_SPEED: float = 360.0
const CHARGE_MIN_DIST: float = 110.0   # too close, body-check is fine
const CHARGE_MAX_DIST: float = 480.0   # too far, charge would waste

enum BrawlerState { CHASE, TELEGRAPH, CHARGING, DEATH_LUNGE, DEAD }
# Room bounds — MB must explode if he reaches the edge instead of flying off
# and shaking the camera forever.
const ROOM_W: float = 1440.0
const ROOM_H: float = 810.0
const ROOM_EDGE_PAD: float = 24.0
var _brawler_state: int = BrawlerState.CHASE
var _brawler_t: float = 0.0
var _charge_cd: float = 0.0
var _charge_dir: Vector2 = Vector2.RIGHT

# Death-lunge tuning. When MB dies, he flashes red, lunges toward the player,
# then explodes for AoE damage. Player can dodge by moving sideways.
const DEATH_FLASH_DURATION: float = 0.18
const DEATH_LUNGE_DURATION: float = 0.42
const DEATH_LUNGE_SPEED: float = 480.0
const DEATH_EXPLODE_RADIUS: float = 70.0
const DEATH_EXPLODE_DAMAGE: int = 2
var _death_lunge_dir: Vector2 = Vector2.RIGHT

func _ready() -> void:
	# Tune stats before super._ready() so health = max_health bakes the value
	max_health = 6         # tankier (was 3, prev variant was 5)
	speed = 78.0           # slow chase
	touch_damage = 2       # heavier hit
	throws_stars = false   # pure melee charger
	super._ready()
	if is_instance_valid(sprite_front):
		var tex := _load_texture(FRONT_PATH)
		sprite_front.texture = tex
		# Safety: if the texture really can't load, free this enemy entirely
		# instead of leaving an invisible 42x42 blocker on the map.
		if tex == null:
			push_warning("[plush_brawler] couldn't load %s — removing self" % FRONT_PATH)
			queue_free()
			return
	_charge_cd = randf_range(1.5, CHARGE_COOLDOWN)

func _physics_process(delta: float) -> void:
	# Terminal state — explosion fired, base death pipeline running.
	if _brawler_state == BrawlerState.DEAD:
		super._physics_process(delta)
		return
	# Death-lunge takes priority over everything — MB is dead but we hold
	# off the actual cleanup until the lunge + explosion play.
	if _brawler_state == BrawlerState.DEATH_LUNGE:
		_tick_death_lunge(delta)
		return
	# When CHARGING, skip the base enemy steering — pure straight-line dash.
	if _brawler_state == BrawlerState.CHARGING:
		_tick_charge(delta)
		return
	if _brawler_state == BrawlerState.TELEGRAPH:
		_tick_telegraph(delta)
		return
	# CHASE: defer to base behavior.
	super._physics_process(delta)
	_charge_cd -= delta
	# Don't telegraph/charge at a player we can't see (aggro needs recent LOS).
	var can_charge: bool = (not ArpgState.active) or (_aggro_t > 0.0 and _has_los_to_player())
	if _charge_cd <= 0.0 and is_instance_valid(player) and can_charge:
		var d: float = global_position.distance_to(player.global_position)
		if d >= CHARGE_MIN_DIST and d <= CHARGE_MAX_DIST:
			_brawler_state = BrawlerState.TELEGRAPH
			_brawler_t = CHARGE_TELEGRAPH
			_charge_dir = (player.global_position - global_position).normalized()
			velocity = Vector2.ZERO

func _tick_telegraph(delta: float) -> void:
	_brawler_t -= delta
	# Red glow ramping up so player can tell what's coming
	var p: float = 1.0 - clamp(_brawler_t / CHARGE_TELEGRAPH, 0.0, 1.0)
	modulate = Color(1.0 + p * 0.6, 1.0 - p * 0.4, 1.0 - p * 0.4)
	velocity = Vector2.ZERO
	move_and_slide()
	if _brawler_t <= 0.0:
		modulate = Color(1, 1, 1)
		_brawler_state = BrawlerState.CHARGING
		_brawler_t = CHARGE_DURATION

func _tick_charge(delta: float) -> void:
	_brawler_t -= delta
	var pre_pos: Vector2 = global_position
	velocity = _charge_dir * CHARGE_SPEED
	move_and_slide()
	# Stuck during charge — bail out instead of grinding on a rock.
	var traveled: float = global_position.distance_to(pre_pos)
	if traveled < CHARGE_SPEED * delta * 0.25:
		_brawler_t = 0.0
	# touch damage on connect
	if damage_cooldown <= 0.0:
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			var c := col.get_collider()
			if c and c.is_in_group("player") and c.has_method("take_damage"):
				c.take_damage(touch_damage)
				damage_cooldown = 0.6
				_backoff_time = TOUCH_BACKOFF_DURATION
				_brawler_t = 0.0   # charge ends on connect
				break
	if _brawler_t <= 0.0:
		_brawler_state = BrawlerState.CHASE
		_charge_cd = CHARGE_COOLDOWN + randf_range(-1.0, 1.0)

func take_damage(amount: int, crit: bool = false) -> void:
	# Intercept the lethal hit. If this damage would drop HP to 0 or below,
	# enter DEATH_LUNGE instead of going straight to the normal _begin_death.
	# Dev one-shot also routes through here so it gets the kamikaze finale.
	if _dying or _brawler_state == BrawlerState.DEATH_LUNGE:
		return
	var would_kill: bool = (health - amount) <= 0 or DevState.oneshot_kills
	if would_kill:
		_begin_death_lunge()
		return
	super.take_damage(amount, crit)

func _begin_death_lunge() -> void:
	_brawler_state = BrawlerState.DEATH_LUNGE
	_brawler_t = DEATH_FLASH_DURATION + DEATH_LUNGE_DURATION
	modulate = Color(1.6, 0.45, 0.45)  # angry red flash
	# Lock in the lunge vector at the moment of death so the player can dodge
	# by moving sideways.
	if is_instance_valid(player):
		_death_lunge_dir = (player.global_position - global_position).normalized()
	# Awareness of incoming kamikaze — wobble a hair, ramp glow
	# Don't drop from "enemies" group yet so the room doesn't open the door
	# prematurely (that happens when the explosion finishes).

func _tick_death_lunge(delta: float) -> void:
	_brawler_t -= delta
	# Phase 1: brief red-flash freeze. Phase 2: lunge.
	if _brawler_t > DEATH_LUNGE_DURATION:
		# Flash phase — stand and tremble
		velocity = Vector2(randf_range(-15, 15), randf_range(-15, 15))
		# Pulse the red glow brighter
		var t: float = (DEATH_FLASH_DURATION - (_brawler_t - DEATH_LUNGE_DURATION)) / DEATH_FLASH_DURATION
		modulate = Color(1.4 + t * 0.6, 0.45 - t * 0.2, 0.45 - t * 0.2)
	else:
		# Lunge phase — straight-line dash toward the player's old position
		velocity = _death_lunge_dir * DEATH_LUNGE_SPEED
		# Touch damage on connect during lunge (extra bite if you don't dodge)
		if damage_cooldown <= 0.0:
			for i in get_slide_collision_count():
				var col := get_slide_collision(i)
				var c := col.get_collider()
				if c and c.is_in_group("player") and c.has_method("take_damage"):
					c.take_damage(1)
					damage_cooldown = 0.6
					_brawler_t = 0.0   # detonate now
					break
	move_and_slide()
	# Explode on room edge — MB used to fly off-screen and shake forever
	# because nothing terminated the lunge state once it left the play area.
	var pos := global_position
	if pos.x <= ROOM_EDGE_PAD or pos.x >= ROOM_W - ROOM_EDGE_PAD \
		or pos.y <= ROOM_EDGE_PAD or pos.y >= ROOM_H - ROOM_EDGE_PAD:
		_explode_and_die()
		return
	if _brawler_t <= 0.0:
		_explode_and_die()

func _explode_and_die() -> void:
	# Guard: this is the loop-bug fix — _tick_death_lunge was hitting the
	# `_brawler_t <= 0.0` branch every frame after the first detonation,
	# spawning a chain of body chunks + camera shakes forever. Lock state.
	if _brawler_state == BrawlerState.DEAD:
		return
	_brawler_state = BrawlerState.DEAD
	velocity = Vector2.ZERO
	# Big red AoE explosion at current position
	var ex := ExplosionScene.instantiate()
	ex.global_position = global_position
	(ex as Node).set("end_scale", DEATH_EXPLODE_RADIUS / 35.0)
	(ex as Node).set("duration", 0.55)
	(ex as CanvasItem).modulate = Color(1.0, 0.45, 0.30, 1.0)
	get_parent().add_child(ex)
	# AoE damage check on the player
	var pl := get_tree().get_first_node_in_group("player")
	if pl is Node2D and pl.has_method("take_damage"):
		var off: Vector2 = (pl as Node2D).global_position - global_position
		if off.length() <= DEATH_EXPLODE_RADIUS:
			pl.take_damage(DEATH_EXPLODE_DAMAGE)
	if pl and pl.has_method("shake"):
		pl.shake(16.0, 0.3)
	# Now hand off to the base enemy death pipeline (drops, fluff, queue_free).
	# We need to ensure health is 0 so super._begin_death drops loot etc.
	health = 0
	super._begin_death()

func _load_texture(path: String) -> Texture2D:
	# Try Godot's normal resource pipeline first (uses .import sidecar).
	var t: Texture2D = load(path) as Texture2D
	if t != null:
		return t
	# Fall back to reading the raw bytes — works even when Godot has never
	# generated a .import sidecar for the PNG (e.g. game launched without the
	# editor ever opening since the asset was dropped in).
	if FileAccess.file_exists(path):
		var bytes := FileAccess.get_file_as_bytes(path)
		if bytes.size() > 0:
			var img := Image.new()
			if img.load_png_from_buffer(bytes) == OK:
				return ImageTexture.create_from_image(img)
	return null
