extends "res://scripts/enemy.gd"

# Bear vacuum-sealed in a plastic bag. Squishes vertically as he walks
# (Y-scale "crunch" wave). The plastic deflects pizzas briefly after every
# hit — short invuln window so you can't burst him down without pause.
# Every few seconds, he puffs a wide line of compressed air straight ahead.

const AirLineBlastScene := preload("res://scenes/air_line_blast.tscn")

const PLASTIC_DEFLECT_DURATION: float = 0.55  # i-frames after each hit
const CRUNCH_HZ: float = 4.2                  # waddle frequency
const CRUNCH_AMP: float = 0.18                # Y-scale wobble
# Frontal line AoE attack — wide white air-puff straight ahead.
const PUFF_COOLDOWN: float = 4.0
const PUFF_RANGE: float = 360.0
const PUFF_FACING_DOT: float = 0.55           # only fire if player is roughly in front

@onready var sprite: Sprite2D = $Rig/Body

const TEX_PATH := "res://assets/shrinkwrap_bear.png"

var _crunch_t: float = 0.0
var _plastic_t: float = 0.0
var _puff_t: float = 0.0
var _facing_x: int = 1
var _rig_base_scale: Vector2 = Vector2.ONE
var _rig: Node2D = null

func _ready() -> void:
	# Slightly tankier than basic, but not a sponge (plastic-deflect i-frames
	# already make him feel durable).
	max_health = 4
	throws_stars = false   # has the air-puff attack
	speed = 65.0   # slow waddle
	touch_damage = 1
	super._ready()
	_puff_t = randf_range(2.0, PUFF_COOLDOWN)  # stagger between bears
	_rig = $Rig
	if is_instance_valid(_rig):
		_rig_base_scale = _rig.scale
	# Runtime-load the texture so a missing .import doesn't blank the sprite.
	if is_instance_valid(sprite):
		var t: Texture2D = _load_tex_robust(TEX_PATH)
		sprite.texture = t
		# Safety: if the texture really can't load, free this enemy entirely
		# rather than leaving an invisible 38x32 blocker on the map.
		if t == null:
			push_warning("[shrinkwrap_bear] couldn't load %s — removing self" % TEX_PATH)
			queue_free()
			return

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

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _plastic_t > 0.0:
		_plastic_t -= delta
	# Track facing — flips when the player's X is on the opposite side.
	if is_instance_valid(player):
		if player.global_position.x > global_position.x + 8.0:
			_facing_x = 1
		elif player.global_position.x < global_position.x - 8.0:
			_facing_x = -1
	# Frontal line-AoE puff on a long cooldown. Only fires if the player is
	# roughly in front so we don't waste the attack.
	_puff_t -= delta
	# Only puff when we actually have eyes on the player (aggro requires recent
	# LOS) — no whooshing through walls at someone we can't see.
	var can_attack: bool = (not ArpgState.active) or (_aggro_t > 0.0 and _has_los_to_player() and not ArpgState.in_spawn_grace())
	if _puff_t <= 0.0 and is_instance_valid(player) and can_attack:
		var to_pl: Vector2 = player.global_position - global_position
		var dist: float = to_pl.length()
		var fwd: Vector2 = Vector2(float(_facing_x), 0.0)
		if dist <= PUFF_RANGE and dist > 40.0 and to_pl.normalized().dot(fwd) > PUFF_FACING_DOT:
			_puff_t = PUFF_COOLDOWN + randf_range(-1.0, 1.0)
			_fire_air_line(fwd)
		else:
			# No good shot — short retry instead of full cooldown
			_puff_t = 1.0
	# Y-scale crunch — scales the rig sinusoidally while moving. PRESERVE the facing
	# sign that the base class set on scale.x (face the player) so the flip is a clean
	# mirror; never lerp scale.x through 0 (that zero-crossing was the "flat line").
	if is_instance_valid(_rig):
		var fsign: float = -1.0 if _rig.scale.x < 0.0 else 1.0
		if velocity.length() > 5.0:
			_crunch_t += delta * CRUNCH_HZ * TAU
			var sy: float = 1.0 + sin(_crunch_t) * CRUNCH_AMP
			var sx: float = 1.0 - (sy - 1.0) * 0.5  # opposite so volume roughly preserved
			_rig.scale = Vector2(_rig_base_scale.x * sx * fsign, _rig_base_scale.y * sy)
		else:
			var target := Vector2(_rig_base_scale.x * fsign, _rig_base_scale.y)
			_rig.scale = _rig.scale.lerp(target, clamp(delta * 8.0, 0.0, 1.0))

func _fire_air_line(fwd: Vector2) -> void:
	var blast := AirLineBlastScene.instantiate()
	blast.global_position = global_position + fwd * 18.0
	blast.set("direction", fwd)
	get_parent().add_child(blast)
	# Tiny squish to sell the "puff" — exhale animation. Recovery handled by
	# the crunch lerp in _physics_process.
	if is_instance_valid(_rig):
		_rig.scale = Vector2(_rig_base_scale.x * 1.18, _rig_base_scale.y * 0.85)

func take_damage(amount: int, crit: bool = false) -> void:
	# Dev one-shot bypasses the plastic deflect — straight to super, which
	# routes to _begin_death().
	if DevState.oneshot_kills:
		super.take_damage(amount, crit)
		return
	# Plastic bag deflects — first hit ignored if we're in the deflect window.
	if _plastic_t > 0.0:
		# Visual: brief white flash, no HP loss
		modulate = Color(1.4, 1.4, 1.6)
		get_tree().create_timer(0.08).timeout.connect(_clear_hit_flash)
		return
	_plastic_t = PLASTIC_DEFLECT_DURATION
	super.take_damage(amount, crit)
