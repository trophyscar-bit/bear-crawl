extends CharacterBody2D

const PizzaScene := preload("res://scenes/pizza.tscn")
const BouncyBallTex := preload("res://assets/bouncy_ball.png")
const PizzaBombScene := preload("res://scenes/pizza_bomb.tscn")
const ExplosionScene := preload("res://scenes/explosion.tscn")
const BodyChunkScene := preload("res://scenes/body_chunk.tscn")
const BearUpperTexture := preload("res://assets/bear_upper.png")
const BearLegsTexture := preload("res://assets/bear_legs.png")
const StuffingTexture := preload("res://assets/stuffing.png")
const StuffingBurstScene := preload("res://scenes/stuffing_burst.tscn")
static var _stuff_burst_tex: Texture2D = null   # white stuffing splatter (shared)
# NOTE: loaded at runtime, NOT preloaded — if Godot hasn't imported the PNG
# yet (no .import sidecar), preload() would fail at parse time and break the
# entire script, killing input handling. load() returns null on miss instead.
var _rupert_sheet: Texture2D = null

# Rupert sprite-sheet layout (must match tools/bake_rupert_sheet.py output)
const RUPERT_FRAME_SIZE: int = 128
const RUPERT_NUM_DIRS: int = 8       # 0=E, 1=SE, 2=S, 3=SW, 4=W, 5=NW, 6=N, 7=NE
const RUPERT_FRAMES_PER_DIR: int = 6
const RUPERT_WALK_FPS: float = 10.0
# Rupert lives inside $Rig (which has its own scale), so this is on top of that.
const RUPERT_SCALE: float = 2.4

@export var base_speed: float = 220.0
@export var base_max_health: int = 5
@export var base_pizza_damage: int = 1
@export var base_pizza_speed: float = 600.0

# computed each time boons are applied
var speed: float = 220.0
var _freeze_t: float = 0.0   # >0 = frozen in place (Frost Cub)
var max_health: int = 5
var health: int

var attack_cooldown: float = 0.0
const ATTACK_RATE: float = 0.35
const TURN_LEAN_DEG: float = 8.0
const TURN_SPEED: float = 12.0

@onready var rig: Node2D = $Rig
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var camera: Camera2D = $Camera2D

const INVULN_DURATION: float = 0.45

# --- Feel / "3D-ish" tuning ----------------------------------------------
# Vertical bob applied to the rig while moving (sin wave). Pixels.
const BOB_AMPLITUDE: float = 2.6
const BOB_HZ: float = 3.2
# Forward squash/stretch on accel/decel — driven by acceleration magnitude.
const SQUASH_MAX_STRETCH: float = 0.10   # 10% — looks lively without being cartoony
const SQUASH_RECOVER: float = 9.0        # higher = snaps back faster
# Body tilt scales with horizontal velocity, on top of existing TURN_LEAN.
const VELOCITY_TILT_GAIN: float = 0.00045
const VELOCITY_TILT_CLAMP_DEG: float = 6.0
# Soft drop shadow under the bear, parented OUTSIDE the rig so it doesn't bob.
const SHADOW_RADIUS: float = 18.0
const SHADOW_OFFSET_Y: float = 14.0
const SHADOW_COLOR: Color = Color(0, 0, 0, 0.32)
# Kill-streak combo: kills within COMBO_WINDOW reset the timer; taking damage
# resets the count to 0. Pure scoreboard / juice — no gameplay multiplier yet.
const COMBO_WINDOW: float = 2.6

var _facing: int = 1
var _last_dir: Vector2 = Vector2.RIGHT
var _target_lean: float = 0.0
var _invuln_time: float = 0.0
var _dying: bool = false

var _bob_phase: float = 0.0
var _prev_speed: float = 0.0
var _squash: Vector2 = Vector2.ONE
var _rig_base_pos: Vector2 = Vector2.ZERO
var _rig_base_scale: Vector2 = Vector2.ONE  # rig's original scale from the scene
var _shadow: Node2D = null
var _rupert: Sprite2D = null
var _rupert_frame: int = 0
var _rupert_frame_t: float = 0.0
var _rupert_dir: int = 0
var combo_count: int = 0
var _combo_timer: float = 0.0

signal combo_changed(count: int)
var _soft_landing_used_this_room: bool = false  # Soft Landing legendary state
var _soft_landing_shield: Node = null            # visible orbiting pizza that IS the free-hit charge
var _pizza_wheel: Node = null                    # spawned when Pizza Wheel boon picked

# Active special weapon ("bomb", "scatter", "homing" or "" = default pizza)
var active_special: String = ""
var special_charges: int = 0

signal died

var _shake_time: float = 0.0
var _shake_total: float = 0.0
var _shake_strength: float = 0.0

func _ready() -> void:
	apply_boons()
	health = max_health
	anim.play("idle")
	# Enemies live on collision layer 3 so they don't push each other; we
	# need to add bit 3 to our mask so we still collide with them.
	set_collision_mask_value(3, true)
	_rig_base_pos = rig.position
	_rig_base_scale = Vector2(abs(rig.scale.x), abs(rig.scale.y))  # forget facing sign
	_spawn_shadow()
	# Rupert sprite-sheet experiment disabled — reverted to the original rig.
	# _setup_rupert()

func _setup_rupert() -> void:
	# Try the standard load() first (uses Godot's import pipeline if .import
	# sidecar exists). Falls back to loading the raw PNG directly via Image,
	# which bypasses the import pipeline entirely — works even if the editor
	# has never been opened since the PNG was added.
	_rupert_sheet = load("res://assets/rupert_sheet.png") as Texture2D
	if _rupert_sheet == null:
		var img := Image.new()
		var err := img.load("res://assets/rupert_sheet.png")
		if err == OK:
			_rupert_sheet = ImageTexture.create_from_image(img)
		else:
			push_warning("[player] could not load rupert_sheet.png (err=%d)" % err)
			return
	# Hide the old composite-bear sprites (Body + Legs) and add a single
	# region-clipped Sprite2D that shows the right frame of rupert_sheet.png.
	# Lives INSIDE $Rig so it inherits the rig's scale/position/squash.
	var body := rig.get_node_or_null("Body") as Sprite2D
	var legs := rig.get_node_or_null("Legs") as Sprite2D
	if body: body.visible = false
	if legs: legs.visible = false
	var r := Sprite2D.new()
	r.name = "Rupert"
	r.texture = _rupert_sheet
	r.region_enabled = true
	r.region_rect = Rect2(0, 0, RUPERT_FRAME_SIZE, RUPERT_FRAME_SIZE)
	r.scale = Vector2(RUPERT_SCALE, RUPERT_SCALE)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # plushie reads better smooth
	rig.add_child(r)
	_rupert = r

func _update_rupert_sprite(dir: Vector2, moving: bool, delta: float) -> void:
	if _rupert == null:
		return
	# Pick the direction column from movement vector (or last facing if idle).
	var d_vec: Vector2 = dir if dir.length() > 0.1 else _last_dir
	if d_vec.length() < 0.001:
		d_vec = Vector2.RIGHT
	# Convert angle → column index. Sheet layout: 0=E, 1=SE, 2=S, 3=SW,
	# 4=W, 5=NW, 6=N, 7=NE. angle() returns 0 for +X (east), +PI/2 for +Y
	# (south in screen-space because Y is down). So d=round(angle/(PI/4)) & 7.
	var a: float = d_vec.angle()
	_rupert_dir = int(round(a / (PI / 4.0))) & 7
	# Advance frame while moving; freeze on the rest frame when idle.
	if moving:
		_rupert_frame_t += delta * RUPERT_WALK_FPS
		while _rupert_frame_t >= 1.0:
			_rupert_frame_t -= 1.0
			_rupert_frame = (_rupert_frame + 1) % RUPERT_FRAMES_PER_DIR
	else:
		_rupert_frame = 0
		_rupert_frame_t = 0.0
	# Region rect maps column = direction, row = frame.
	_rupert.region_rect = Rect2(
		_rupert_dir * RUPERT_FRAME_SIZE,
		_rupert_frame * RUPERT_FRAME_SIZE,
		RUPERT_FRAME_SIZE, RUPERT_FRAME_SIZE
	)

func notify_killed_enemy() -> void:
	# Called by enemies on death (or from main.gd hook) so combo bumps.
	combo_count += 1
	_combo_timer = COMBO_WINDOW
	combo_changed.emit(combo_count)
	# Small reward shake on milestone combos
	if combo_count == 5 or combo_count == 10 or combo_count == 20:
		shake(6.0, 0.18)

func _spawn_shadow() -> void:
	# Soft circular drop shadow drawn behind the rig. Lives on the player root
	# (not the rig) so it stays grounded while the body bobs/squashes.
	# Scale the shadow with the rig so it matches whatever size the bear is.
	var rig_scale_avg: float = (_rig_base_scale.x + _rig_base_scale.y) * 0.5
	var sh := Node2D.new()
	sh.name = "DropShadow"
	sh.z_index = -1  # behind rig sprites
	sh.position = Vector2(0, SHADOW_OFFSET_Y * rig_scale_avg)
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	var n: int = 20
	var rx: float = SHADOW_RADIUS * rig_scale_avg
	var ry: float = SHADOW_RADIUS * rig_scale_avg * 0.42
	for i in n:
		var a: float = TAU * float(i) / float(n)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	poly.polygon = pts
	poly.color = SHADOW_COLOR
	sh.add_child(poly)
	add_child(sh)
	move_child(sh, 0)  # draw under the rig
	_shadow = sh

func apply_boons() -> void:
	var old_max: int = max_health
	# Meta upgrades from MetaSave (persistent)
	var meta_hp: int = MetaSave.upgrade_level("more_plush")
	var meta_speed_mult: float = 1.0 + 0.05 * MetaSave.upgrade_level("faster_feet")
	max_health = base_max_health + meta_hp + RunState.bonus_max_health()
	speed = base_speed * meta_speed_mult * RunState.move_speed_multiplier()
	# Ascension 4: start at 3 HP instead of 5
	if GameSettings.ascension >= 4:
		max_health = max(1, max_health - 2)
	# if a Plush Armor boon was just picked, also gain that HP
	if old_max > 0 and max_health > old_max:
		health = min(health + (max_health - old_max), max_health)
	# Spawn the Pizza Wheel once if the boon is picked, despawn if it isn't
	if RunState.has_pizza_wheel() and not is_instance_valid(_pizza_wheel):
		var wheel := preload("res://scenes/pizza_wheel.tscn").instantiate()
		add_child(wheel)
		_pizza_wheel = wheel
	# Soft Landing now SHOWS its charge as a blue orbiting pizza shield.
	# Spawn it if the boon is held and the charge hasn't been used yet.
	_refresh_soft_landing_shield()

func _refresh_soft_landing_shield() -> void:
	var should_show: bool = RunState.has_soft_landing() and not _soft_landing_used_this_room
	if should_show and not is_instance_valid(_soft_landing_shield):
		var sh := preload("res://scenes/pizza_wheel.tscn").instantiate()
		# Different radius + tint from the offensive Pizza Wheel boon so they
		# don't visually collide if both are active.
		sh.set("radius", 56.0)
		sh.set("angular_speed", -2.4)  # spins the OTHER way for visual distinction
		(sh as CanvasItem).modulate = Color(0.7, 0.9, 1.15, 0.95)
		add_child(sh)
		_soft_landing_shield = sh
	elif not should_show and is_instance_valid(_soft_landing_shield):
		_soft_landing_shield.queue_free()
		_soft_landing_shield = null

func _process(delta: float) -> void:
	# Kill-streak combo decay
	if _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0 and combo_count > 0:
			combo_count = 0
			combo_changed.emit(0)
	if _shake_time > 0.0:
		_shake_time -= delta
		var k: float = clamp(_shake_time / _shake_total, 0.0, 1.0)
		if camera:
			camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength * k
	elif camera and camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO

func shake(strength: float, duration: float) -> void:
	_shake_strength = strength
	_shake_time = duration
	_shake_total = duration

func _physics_process(delta: float) -> void:
	# Frozen solid (Frost Cub orb): can't move or act until it wears off.
	if _freeze_t > 0.0:
		_freeze_t -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		if _freeze_t <= 0.0 and not _dying:
			modulate = Color(1, 1, 1)
		return
	var dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if dir.length() > 1.0:
		dir = dir.normalized()
	velocity = dir * speed * _slow_factor()
	move_and_slide()

	if dir.length() > 0.1:
		_last_dir = dir.normalized()

	if _rupert != null:
		# 8-direction Rupert sheet has dedicated frames for every facing, so
		# we no longer need to flip the rig on X.
		_facing = 1
		_update_rupert_sprite(dir, dir.length() > 0.1, delta)
	else:
		# Fall back to old left/right flip on the legacy rig.
		if dir.x > 0.05:
			_facing = 1
		elif dir.x < -0.05:
			_facing = -1

	# --- Body tilt: base lean + extra from horizontal velocity ----------
	if dir.length() > 0.1:
		var vel_tilt: float = clamp(velocity.x * VELOCITY_TILT_GAIN,
			-deg_to_rad(VELOCITY_TILT_CLAMP_DEG), deg_to_rad(VELOCITY_TILT_CLAMP_DEG))
		_target_lean = deg_to_rad(TURN_LEAN_DEG) * dir.x + vel_tilt * _facing
		if anim.current_animation != "move":
			anim.play("move")
	else:
		_target_lean = 0.0
		if anim.current_animation != "idle":
			anim.play("idle")
	rig.rotation = lerp_angle(rig.rotation, _target_lean, TURN_SPEED * delta)

	# --- Vertical bob (sin wave) only while moving, eased in/out ----------
	var speed_now: float = velocity.length()
	var move_amount: float = clamp(speed_now / max(speed, 1.0), 0.0, 1.0)
	_bob_phase += delta * BOB_HZ * TAU * move_amount
	# Scale the bob amplitude with the rig so it stays proportional regardless
	# of the rig's authored size.
	var rig_scale_avg: float = (_rig_base_scale.x + _rig_base_scale.y) * 0.5
	var bob_y: float = sin(_bob_phase) * BOB_AMPLITUDE * rig_scale_avg * move_amount

	# --- Squash / stretch on acceleration --------------------------------
	# Δspeed > 0  → launching forward → stretch X, squash Y.
	# Δspeed < 0 → braking → squash X, stretch Y. Recovers toward (1, 1).
	var dv: float = (speed_now - _prev_speed) / max(delta, 0.0001)
	_prev_speed = speed_now
	var stretch: float = clamp(dv / 4000.0, -1.0, 1.0) * SQUASH_MAX_STRETCH
	_squash.x = lerp(_squash.x, 1.0 + stretch, clamp(delta * SQUASH_RECOVER, 0.0, 1.0))
	_squash.y = lerp(_squash.y, 1.0 - stretch, clamp(delta * SQUASH_RECOVER, 0.0, 1.0))

	# Apply bob + squash to the rig. Multiply against the rig's ORIGINAL
	# scale (cached in _ready) so we don't blow up sprites that were already
	# scaled in the scene. Facing sign goes on X.
	rig.position = _rig_base_pos + Vector2(0, bob_y)
	rig.scale = Vector2(
		_rig_base_scale.x * _squash.x * _facing,
		_rig_base_scale.y * _squash.y
	)

	# (Footstep dust removed — was distracting on the player.)

	if attack_cooldown > 0.0:
		attack_cooldown -= delta
	if _invuln_time > 0.0:
		_invuln_time -= delta
	# Hold to auto-fire — attack_cooldown throttles the rate (weapon fire-rate in
	# ARPG mode, ATTACK_RATE otherwise), so holding the button keeps shooting.
	if Input.is_action_pressed("attack") and attack_cooldown <= 0.0:
		_throw_pizza()

func _throw_pizza() -> void:
	# ARPG mode: the equipped loot weapon drives fire-rate, spread and stats.
	if ArpgState.active and not ArpgState.weapon.is_empty():
		_throw_arpg_weapon()
		return
	attack_cooldown = ATTACK_RATE
	# Tiny throw punch — front-foot stretch toward the throw direction.
	_squash = Vector2(1.12, 0.92)
	# Mid-run pickup takes priority over the starting weapon.
	var weapon: String = ""
	if special_charges > 0:
		weapon = active_special
		special_charges -= 1
		if special_charges <= 0:
			active_special = ""
	else:
		weapon = GameSettings.selected_weapon
	match weapon:
		"bomb":
			_throw_pizza_bomb()
		"scatter":
			_throw_scatter()
		"homing":
			_throw_homing()
		_:
			_throw_default_pizza()

func _throw_arpg_weapon() -> void:
	attack_cooldown = ArpgState.weapon_cooldown()
	_squash = Vector2(1.12, 0.92)
	var center_dir: Vector2 = _last_dir if _last_dir != Vector2.ZERO else Vector2(_facing, 0)
	_fire_volley(center_dir, 1.0)
	# Back Shot power-up: fire an identical volley out the back (180° opposite). It's
	# SHORT-RANGE (≈45% range) so kiting + back-firing isn't a free win — you have to
	# let them get close behind you for it to connect.
	if ArpgState.back_shot:
		_fire_volley(-center_dir, 0.45)

func _fire_volley(center_dir: Vector2, range_mult: float) -> void:
	var count: int = ArpgState.weapon_count()
	var spread_deg: float = 9.0 * float(count - 1)
	for i in count:
		var offset: float = 0.0
		if count > 1:
			offset = lerp(-spread_deg, spread_deg, float(i) / float(count - 1))
		_range_mult = range_mult
		_spawn_pizza(center_dir.rotated(deg_to_rad(offset)), false)
	_range_mult = 1.0

func _throw_default_pizza() -> void:
	# Double Pep: extra pizzas in a tight spread
	var extra: int = RunState.extra_pizzas()
	var count_total: int = 1 + extra
	var spread_deg: float = 10.0 * float(extra)
	var center_dir: Vector2 = _last_dir if _last_dir != Vector2.ZERO else Vector2(_facing, 0)
	for i in count_total:
		var offset: float = 0.0
		if count_total > 1:
			offset = lerp(-spread_deg, spread_deg, float(i) / float(count_total - 1))
		var dir: Vector2 = center_dir.rotated(deg_to_rad(offset))
		_spawn_pizza(dir, false)

var _range_mult: float = 1.0   # shortens projectile range (Back Shot rear volley)
var _proj_cache: Dictionary = {}
func _proj_tex(name: String) -> Texture2D:
	if _proj_cache.has(name):
		return _proj_cache[name]
	var t: Texture2D = null
	var path: String = "res://assets/projectiles/%s.png" % name
	var f := FileAccess.open(path, FileAccess.READ)
	if f != null:
		var img := Image.new()
		if img.load_png_from_buffer(f.get_buffer(f.get_length())) == OK:
			t = ImageTexture.create_from_image(img)
	_proj_cache[name] = t
	return t

func _spawn_pizza(dir: Vector2, hostile_flag: bool) -> void:
	var pizza := PizzaScene.instantiate()
	pizza.global_position = global_position
	pizza.direction = dir
	pizza.damage = base_pizza_damage + MetaSave.upgrade_level("sharper_crust") + RunState.pizza_damage_bonus()
	pizza.speed = base_pizza_speed * RunState.pizza_speed_multiplier()
	pizza.max_bounces = _bounces_for_run()
	pizza.apply_burn = RunState.has_spicy()
	pizza.burst_on_impact = RunState.has_pepperoni_burst()
	pizza.pierce = RunState.pizza_pierce()
	# Stuffed Crust — scale up sprite + collision before adding to tree
	var size_mult: float = RunState.pizza_size_multiplier()
	if size_mult != 1.0:
		var sprite := pizza.get_node("Sprite") as Sprite2D
		sprite.scale *= size_mult
		var col := pizza.get_node("CollisionShape2D") as CollisionShape2D
		if col and col.shape is CircleShape2D:
			var dup := (col.shape as CircleShape2D).duplicate() as CircleShape2D
			dup.radius *= size_mult
			col.shape = dup
	# ARPG: the equipped weapon overrides damage/speed and tints the projectile.
	if ArpgState.active and not ArpgState.weapon.is_empty():
		var w: Dictionary = ArpgState.weapon
		var dmg: int = ArpgState.weapon_damage()
		var col: Color = w.get("color", Color(1, 1, 1))
		var spr := pizza.get_node_or_null("Sprite") as Sprite2D
		var themed: bool = false   # weapon-specific projectile art (keep its colours)
		if bool(w.get("ball", false)):
			# Bouncy Blaster: random-colour ball, many bounces, long life, and it
			# ignores the post-bounce distance cap so it keeps ricocheting.
			col = Color.from_hsv(randf(), 0.85, 1.0)
			pizza.max_bounces = int(w.get("bounces", 8))
			pizza.lifetime = 4.0
			pizza.max_distance_after_bounce = 100000.0
			pizza.spin_speed = 5.0
			if spr != null:
				spr.texture = BouncyBallTex
				spr.scale = Vector2(0.5, 0.5)
		else:
			pizza.max_bounces = 1   # one proper ricochet off walls (reflects forward)
			# Weapon-specific projectile sprite (pepperoni / cheese / deep-dish / ice)
			# so the pizza weapons don't all look identical.
			if spr != null and w.has("proj"):
				var pt: Texture2D = _proj_tex(String(w["proj"]))
				if pt != null:
					spr.texture = pt
					var psc: float = float(w.get("proj_scale", 0.6))
					spr.scale = Vector2(psc, psc)
					themed = true
		if ArpgState.rolled_crit():
			dmg = int(round(float(dmg) * 2.0))
			col = Color(1.0, 0.95, 0.4)            # crit = golden flash
			if spr != null:
				spr.scale *= 1.5
			pizza.is_crit = true
		pizza.damage = dmg
		pizza.speed = float(w.get("speed", 600.0))
		pizza.pierce = int(w.get("pierce", 0))
		if _range_mult < 1.0:
			pizza.lifetime = float(pizza.lifetime) * _range_mult   # Back Shot: short rear range
		if spr != null:
			# HDR-boost the tint (push the brightest channel well past the bloom
			# threshold) so EVERY projectile glows consistently via post-process
			# bloom — independent of how many 2D lights are nearby, which was
			# dropping/washing-out the additive halo in the now-brighter cave.
			if themed:
				# Keep the sprite's own colours; just a mild bloom boost (no full
				# hue-replace, which would flatten the art back to one tint).
				spr.modulate = Color(1.0, 1.0, 1.0) if ArpgState.no_projectile_glow else Color(1.12, 1.12, 1.12)
			elif ArpgState.no_projectile_glow:
				spr.modulate = col
			else:
				var m: float = maxf(col.r, maxf(col.g, col.b))
				var hue: Color = col if m < 0.01 else Color(col.r / m, col.g / m, col.b / m)
				spr.modulate = Color(hue.r * 1.25, hue.g * 1.25, hue.b * 1.25, 1.0)
		var gl := pizza.get_node_or_null("Glow") as PointLight2D
		if gl != null:
			gl.color = col
			gl.energy = 0.6            # subtle halo (toned down — was a bloom bomb)
			gl.texture_scale = 0.7
			if ArpgState.no_projectile_glow:
				gl.visible = false   # backrooms: flat level, no projectile glow
	get_parent().add_child(pizza)

func _throw_pizza_bomb() -> void:
	var bomb := PizzaBombScene.instantiate()
	bomb.global_position = global_position
	bomb.direction = _last_dir if _last_dir != Vector2.ZERO else Vector2(_facing, 0)
	var base: int = base_pizza_damage + MetaSave.upgrade_level("sharper_crust") + RunState.pizza_damage_bonus()
	bomb.damage = max(1, int(round(float(base) * 1.5)))
	get_parent().add_child(bomb)
	RunState.stats_bombs_thrown += 1

func _throw_scatter() -> void:
	# Three pizzas in a cone, half-range. Each does normal damage.
	var center_dir: Vector2 = _last_dir if _last_dir != Vector2.ZERO else Vector2(_facing, 0)
	var spread_deg: float = 18.0
	for offset_deg in [-spread_deg, 0.0, spread_deg]:
		var p := PizzaScene.instantiate()
		p.global_position = global_position
		p.direction = center_dir.rotated(deg_to_rad(offset_deg))
		p.damage = base_pizza_damage + MetaSave.upgrade_level("sharper_crust") + RunState.pizza_damage_bonus()
		p.speed = base_pizza_speed * 0.85 * RunState.pizza_speed_multiplier()
		p.lifetime = 0.7  # short range — close-quarters spread
		p.max_bounces = _bounces_for_run()
		p.apply_burn = RunState.has_spicy()
		p.burst_on_impact = RunState.has_pepperoni_burst()
		p.pierce = RunState.pizza_pierce()
		get_parent().add_child(p)

func _throw_homing() -> void:
	# Slower pizza that curves toward the nearest enemy. Longer lifetime to track.
	var p := PizzaScene.instantiate()
	p.global_position = global_position
	p.direction = _last_dir if _last_dir != Vector2.ZERO else Vector2(_facing, 0)
	p.damage = base_pizza_damage + MetaSave.upgrade_level("sharper_crust") + RunState.pizza_damage_bonus()
	# Heavy nerf: speed × 0.5, lifetime 1.0 → max ~300 px (~1/4 stage) at base speed.
	p.speed = base_pizza_speed * 0.5 * RunState.pizza_speed_multiplier()
	p.lifetime = 1.0
	p.homing = true
	p.max_bounces = _bounces_for_run()
	p.apply_burn = RunState.has_spicy()
	p.burst_on_impact = RunState.has_pepperoni_burst()
	p.pierce = RunState.pizza_pierce()
	get_parent().add_child(p)

func grant_special(weapon: String, n: int) -> void:
	# A new pickup overrides whatever was active. Cleaner than juggling pools.
	active_special = weapon
	special_charges = n

func _bounces_for_run() -> int:
	if GameSettings.ascension >= 3:
		return 0
	return 1 + RunState.extra_bounces()

# main.gd calls this whenever a new room starts so Soft Landing refreshes
func on_room_entered() -> void:
	_soft_landing_used_this_room = false
	_refresh_soft_landing_shield()  # re-spawn the orbiting shield for the new room

# Backwards-compat shim for the old pickup-bomb API:
func add_pizza_bombs(n: int) -> void:
	grant_special("bomb", n)

func _spawn_hit_stuffing() -> void:
	if _stuff_burst_tex == null:
		var path := "res://assets/stuffing_hit.png"   # gif 3 — the player's hit puff
		if FileAccess.file_exists(path):
			var b := FileAccess.get_file_as_bytes(path)
			if b.size() > 0:
				var img := Image.new()
				if img.load_png_from_buffer(b) == OK:
					_stuff_burst_tex = ImageTexture.create_from_image(img)
	if _stuff_burst_tex == null or not is_instance_valid(get_parent()):
		return
	var s := StuffingBurstScene.instantiate()
	s.texture = _stuff_burst_tex
	s.global_position = global_position
	s.scale = Vector2.ONE * 2.0
	s.rotation = randf() * TAU
	get_parent().add_child(s)

func take_damage(amount: int) -> void:
	if _dying or _invuln_time > 0.0:
		return
	if DevState.invincible:
		# Dev: show a floating damage number above the player so you can
		# see WHICH source hit you during debugging — invincible mode only.
		_spawn_dev_damage_popup(amount)
		return
	# Soft Landing legendary — eat one hit per room. The orbiting blue pizza
	# shield IS the visual representation of this charge; consume it now.
	if RunState.has_soft_landing() and not _soft_landing_used_this_room:
		_soft_landing_used_this_room = true
		_invuln_time = INVULN_DURATION
		# brief soft-blue flash to signal the save
		modulate = Color(0.6, 0.85, 1.0)
		get_tree().create_timer(0.15).timeout.connect(func(): if not _dying: modulate = Color(1, 1, 1))
		# Pop & free the shield where it currently is, so the player can SEE
		# it get used. Spawn an explosion at the shield's position for impact.
		if is_instance_valid(_soft_landing_shield):
			var ex := ExplosionScene.instantiate()
			ex.global_position = (_soft_landing_shield as Node2D).global_position
			(ex as Node).set("end_scale", 1.4)
			(ex as Node).set("duration", 0.35)
			(ex as CanvasItem).modulate = Color(0.7, 0.9, 1.2, 0.9)
			get_parent().add_child(ex)
			_soft_landing_shield.queue_free()
			_soft_landing_shield = null
		shake(5.0, 0.18)
		return
	_invuln_time = INVULN_DURATION
	health -= amount
	_spawn_hit_stuffing()   # Rupert puffs stuffing when hit
	modulate = Color(1, 0.4, 0.4)
	# AAA game-feel: kick the camera + a sliver of hit-stop so damage lands hard,
	# plus a quick chromatic-aberration flare.
	Juice.shake(0.55)
	Juice.hitstop(0.06, 0.06)
	Juice.ca_pulse(4.5)
	# Pop the squash buffer so the bear visibly recoils for one frame.
	_squash = Vector2(0.78, 1.22)
	# Reset combo on damage — encourages no-hit play.
	if combo_count > 0:
		combo_count = 0
		_combo_timer = 0.0
		combo_changed.emit(0)
	get_tree().create_timer(0.1).timeout.connect(func(): if not _dying: modulate = Color(1, 1, 1))
	if health <= 0:
		_begin_death()

func _begin_death() -> void:
	if _dying:
		return
	_dying = true
	# Death punch: heavy shake + a longer freeze for a cinematic beat.
	Juice.shake(1.0)
	Juice.hitstop(0.16, 0.04)
	rig.visible = false
	if is_instance_valid(_shadow):
		_shadow.visible = false
	set_physics_process(false)
	velocity = Vector2.ZERO
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	remove_from_group("player")
	# Bigger explosion than the boss (end_scale was 4.8, duration 0.95)
	var ex := ExplosionScene.instantiate()
	ex.global_position = global_position
	(ex as Node).set("end_scale", 7.5)
	(ex as Node).set("duration", 1.4)
	get_parent().add_child(ex)
	# Lingering body chunks
	_spawn_death_chunks()
	# Camera shake stays on the still-living (but invisible) player
	shake(38.0, 0.8)
	died.emit()
	_chain_explode_nearby_enemies()
	# IMPORTANT: do NOT queue_free here — keep the camera alive so the view
	# stays put while chunks animate and the pop-up appears.

func _chain_explode_nearby_enemies() -> void:
	const CHAIN_RADIUS: float = 360.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node2D and e.has_method("chain_explode")):
			continue
		var d: float = global_position.distance_to((e as Node2D).global_position)
		if d > CHAIN_RADIUS:
			continue
		# stagger by distance so it cascades outward
		var delay: float = clamp(d / 700.0, 0.0, 0.55)
		var target: Node = e
		get_tree().create_timer(delay).timeout.connect(func():
			if is_instance_valid(target) and target.has_method("chain_explode"):
				target.chain_explode()
		)

func _spawn_death_chunks() -> void:
	# upper body fragment
	var upper := BodyChunkScene.instantiate()
	upper.texture = BearUpperTexture
	upper.global_position = global_position + Vector2(0, -10)
	upper.velocity = Vector2.RIGHT.rotated(randf_range(-PI * 0.85, -PI * 0.15)) * randf_range(320.0, 420.0)
	upper.angular_velocity = randf_range(-7.0, 7.0)
	upper.initial_scale = 0.5
	upper.lifetime = 5.5
	upper.fade_after = 0.78
	upper.drag = 0.025
	get_parent().add_child(upper)
	# legs fragment
	var legs := BodyChunkScene.instantiate()
	legs.texture = BearLegsTexture
	legs.global_position = global_position + Vector2(0, 10)
	legs.velocity = Vector2.RIGHT.rotated(randf_range(PI * 0.15, PI * 0.85)) * randf_range(300.0, 400.0)
	legs.angular_velocity = randf_range(-7.0, 7.0)
	legs.initial_scale = 0.5
	legs.lifetime = 5.5
	legs.fade_after = 0.78
	legs.drag = 0.025
	get_parent().add_child(legs)
	# lots of cotton stuffing puffs that linger
	for i in 14:
		var puff := BodyChunkScene.instantiate()
		puff.texture = StuffingTexture
		puff.global_position = global_position
		puff.velocity = Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * randf_range(220.0, 460.0)
		puff.angular_velocity = randf_range(-12.0, 12.0)
		puff.initial_scale = randf_range(0.55, 1.3)
		puff.lifetime = randf_range(4.0, 5.5)
		puff.fade_after = 0.72
		puff.drag = 0.02
		get_parent().add_child(puff)

func grant_stack_bonus_max_hp(n: int) -> void:
	# Pickup stack bonus — permanent for this run, doesn't replay through apply_boons.
	max_health += n
	health = min(health + n, max_health)
	modulate = Color(1.2, 1.0, 0.6)
	get_tree().create_timer(0.25).timeout.connect(func(): if not _dying: modulate = Color(1, 1, 1))

func heal(amount: int) -> void:
	health = min(health + amount, max_health)
	modulate = Color(0.6, 1.0, 0.7)
	get_tree().create_timer(0.15).timeout.connect(func(): modulate = Color(1, 1, 1))

func freeze(duration: float) -> void:
	# Frost Cub orb hit — locked in an ice-blue freeze for `duration` seconds.
	if _dying:
		return
	_freeze_t = maxf(_freeze_t, duration)
	modulate = Color(0.5, 0.78, 1.25)   # icy tint, held while frozen

func _spawn_dev_damage_popup(amount: int) -> void:
	# Floating "-N" text above player. Only used in dev invincible mode.
	var lbl := Label.new()
	lbl.text = "-%d" % amount
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.30, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.position = global_position + Vector2(-12, -54)
	# Add to parent so it lives in world space, not on the player.
	var parent := get_parent()
	if parent:
		parent.add_child(lbl)
		var tw := lbl.create_tween()
		tw.set_parallel(true)
		tw.tween_property(lbl, "position:y", lbl.position.y - 32.0, 0.75)
		tw.tween_property(lbl, "modulate:a", 0.0, 0.75).set_delay(0.25)
		tw.chain().tween_callback(lbl.queue_free)

func _slow_factor() -> float:
	# Standing in any slow zone (e.g. a pond) reduces movement speed.
	for s in get_tree().get_nodes_in_group("slow_zones"):
		if s is Area2D and (s as Area2D).overlaps_body(self):
			return 0.55
	return 1.0
