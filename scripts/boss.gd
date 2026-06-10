extends CharacterBody2D

const PizzaScene := preload("res://scenes/pizza.tscn")
const ExplosionScene := preload("res://scenes/explosion.tscn")
const FullHealScene := preload("res://scenes/full_heal.tscn")
const BodyChunkScene := preload("res://scenes/body_chunk.tscn")
const GroundSlamScene := preload("res://scenes/ground_slam.tscn")
const CleaveMawScene := preload("res://scenes/cleave_maw.tscn")
const BearPawSlamScene := preload("res://scenes/bear_paw_slam.tscn")
const BossUpperTexture := preload("res://assets/boss_upper.png")
const BossLegsTexture := preload("res://assets/boss_legs.png")
const StuffingTexture := preload("res://assets/stuffing.png")

@export var speed: float = 115.0
@export var max_health: int = 34
@export var touch_damage: int = 1
@export var throw_interval: float = 1.75   # was 1.15 — slowed per user req, floor 3 cadence was too fast
@export var pizza_speed: float = 456.0   # was 570 — additional 20% cut per user
@export var pizza_lifetime: float = 3.0          # boss pizzas reach across the room before despawning
@export var pizza_post_bounce: float = 290.0     # ~20% of room width after first bounce
@export var hit_invuln: float = 0.28             # i-frames between successive pizza hits — stops spam-kill
# Close-range AOE shockwave punishes melee camping
@export var aoe_cooldown: float = 1.6
@export var aoe_range: float = 95.0
@export var aoe_damage: int = 1
# Telegraphed ground slam — periodic AoE under the player, harder to ignore
# than the close-range hugger AOE.
@export var slam_cooldown: float = 5.5
@export var slam_range: float = 420.0   # only slams when player is within this
# Phase-2 only: a massive bear face slides across half the room on a long cooldown.
@export var maw_cooldown: float = 11.0
# Phase-2 only: bear paw slam from above on a separate timer so it alternates
# with the Cleave Maw rather than overlapping it.
@export var paw_cooldown: float = 7.5

const AVOID_RADIUS: float = 110.0
const AVOID_REPULSION: float = 0.5
const AVOID_TANGENT: float = 1.1

const DEATH_FALL_DURATION: float = 0.4
const DEATH_FADE_DURATION: float = 4.5  # boss body lingers longer than before (was 2.0)

var health: int
var player: Node2D
var damage_cooldown: float = 0.0
var _throw_timer: float = 1.0
var _aoe_timer: float = 0.0
var _slam_timer: float = 0.0
var _maw_timer: float = 0.0
var _paw_timer: float = 0.0
# Anti-grind: same back-off / orbit logic as the trash mobs so the boss
# doesn't lock onto the player after touching him.
var _backoff_time: float = 0.0
var _orbit_sign: int = 1
const TOUCH_BACKOFF_DURATION: float = 0.5
const BOSS_PERSONAL_SPACE: float = 64.0  # boss is bigger; wider stand-off
var _hit_cooldown: float = 0.0
var _phase: int = 1
var is_final_fight: bool = false
var _dying: bool = false
var _death_time: float = 0.0
var _death_origin: Vector2 = Vector2.ZERO
var _rainbow_t: float = 0.0

const RAINBOW_SPEED: float = 1.3

func _ready() -> void:
	add_to_group("enemies")
	# Easy-mode boss is squishier and throws less often.
	if GameSettings.difficulty == GameSettings.Difficulty.EASY:
		max_health = 22
		throw_interval = 2.4   # easy: noticeably more sparse
		slam_cooldown = 8.0  # easy: rarer slams
	# Hard mode used to be a pizza-storm — slow the cadence so single-shot
	# salvos are reactable.
	elif GameSettings.difficulty == GameSettings.Difficulty.HARD:
		throw_interval = 2.0   # hard: softer cadence so it's actually playable
	health = max_health
	player = get_tree().get_first_node_in_group("player")
	_slam_timer = randf_range(3.0, slam_cooldown)
	_orbit_sign = -1 if randf() < 0.5 else 1

func _physics_process(delta: float) -> void:
	if _dying:
		_process_death(delta)
		return

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return

	var to_player: Vector2 = player.global_position - global_position
	var desired: Vector2 = to_player.normalized()
	# Anti-grind: don't keep mashing into the player after a touch hit.
	if _backoff_time > 0.0:
		_backoff_time -= delta
		desired = -desired
	elif to_player.length() < BOSS_PERSONAL_SPACE:
		var tang: Vector2 = Vector2(-desired.y, desired.x) * float(_orbit_sign)
		desired = (desired * 0.15 + tang * 0.85).normalized()
	var avoid: Vector2 = Vector2.ZERO
	for obs in get_tree().get_nodes_in_group("obstacles"):
		if obs is Node2D:
			var off: Vector2 = global_position - (obs as Node2D).global_position
			var dist: float = off.length()
			if dist < AVOID_RADIUS and dist > 0.5:
				var strength: float = 1.0 - dist / AVOID_RADIUS
				var away: Vector2 = off / dist
				var tang: Vector2 = Vector2(-away.y, away.x)
				if tang.dot(to_player) < 0.0:
					tang = -tang
				avoid += (away * AVOID_REPULSION + tang * AVOID_TANGENT) * strength
	var steer: Vector2 = (desired + avoid).normalized()
	velocity = steer * speed * _slow_factor()
	move_and_slide()

	var rig := get_node_or_null("Rig")
	if rig and absf(to_player.x) > 1.0:
		rig.scale.x = absf(rig.scale.x) * (1 if to_player.x > 0 else -1)
	if rig:
		_rainbow_t += delta * RAINBOW_SPEED
		(rig as Node2D).modulate = Color.from_hsv(fposmod(_rainbow_t, 1.0), 1.0, 1.0)

	if damage_cooldown > 0.0:
		damage_cooldown -= delta
	if damage_cooldown <= 0.0 and global_position.distance_to(player.global_position) < 52.0:
		if player.has_method("take_damage"):
			player.take_damage(touch_damage)
			damage_cooldown = 0.6
			_backoff_time = TOUCH_BACKOFF_DURATION  # back off after the touch hit

	if _hit_cooldown > 0.0:
		_hit_cooldown -= delta

	_throw_timer -= delta
	if _throw_timer <= 0.0:
		_throw_timer = throw_interval
		# Hard mode used to add a 3-pizza fan in phase 2 — that was undodgeable.
		# Now: single shot in all phases (phase 2 just fires faster via cooldown).
		_throw_pizza(to_player.normalized())

	# Close-range AOE shockwave — punishes the player for hugging the boss.
	_aoe_timer -= delta
	if _aoe_timer <= 0.0 and to_player.length() < aoe_range:
		_trigger_aoe()

	# Telegraphed ground slam — periodic AoE under the player's current
	# position. Forces movement instead of let-them-stand-and-shoot.
	_slam_timer -= delta
	if _slam_timer <= 0.0 and to_player.length() <= slam_range:
		_slam_timer = slam_cooldown + randf_range(-1.0, 1.0)
		_spawn_slam()

	# Phase 2+: occasionally fire the Cleave Maw — half-screen wipe attack.
	if _phase >= 2:
		_maw_timer -= delta
		if _maw_timer <= 0.0:
			_maw_timer = maw_cooldown + randf_range(-2.0, 2.0)
			_spawn_cleave_maw()
		_paw_timer -= delta
		if _paw_timer <= 0.0:
			_paw_timer = paw_cooldown + randf_range(-1.5, 1.5)
			_spawn_paw_slam()

func _throw_pizza(dir: Vector2) -> void:
	var pz := PizzaScene.instantiate()
	pz.global_position = global_position
	pz.direction = dir
	pz.hostile = true
	pz.speed = pizza_speed
	pz.lifetime = pizza_lifetime
	pz.max_distance_after_bounce = pizza_post_bounce
	get_parent().add_child(pz)

func _throw_pizza_fan(center_dir: Vector2, count: int, spread_deg: float) -> void:
	# Symmetric fan around center_dir. `count` should be odd for a true center
	# shot — for 3 you get [-spread, 0, +spread].
	for i in count:
		var offset: float = 0.0
		if count > 1:
			offset = lerp(-spread_deg, spread_deg, float(i) / float(count - 1))
		_throw_pizza(center_dir.rotated(deg_to_rad(offset)))

func _spawn_paw_slam() -> void:
	# Drops on the player's CURRENT position — locks at spawn so the player
	# has to move during the 1 s telegraph window.
	if not is_instance_valid(player):
		return
	var paw := BearPawSlamScene.instantiate()
	paw.global_position = player.global_position
	get_parent().add_child(paw)

func _spawn_cleave_maw() -> void:
	# Pick the side the PLAYER is on so they have to move across. Telegraph
	# gives them time. CleaveMaw is parented to the boss's parent so it
	# doesn't move with the boss while it slides.
	var maw := CleaveMawScene.instantiate()
	var room_w: float = 1440.0
	if is_instance_valid(player):
		maw.set("side", 0 if player.global_position.x < room_w * 0.5 else 1)
	get_parent().add_child(maw)

func _spawn_slam() -> void:
	if not is_instance_valid(player):
		return
	# Slam under the player's current position. Slightly smaller + shorter
	# windup than the final-boss version since the first boss is earlier-game.
	var slam := GroundSlamScene.instantiate()
	slam.global_position = player.global_position
	slam.set("radius", 78.0)
	slam.set("windup", 1.0)
	slam.set("damage", 1)
	get_parent().add_child(slam)

func _trigger_aoe() -> void:
	_aoe_timer = aoe_cooldown
	# Visual: small explosion-flash at boss position, red-orange tint
	var ex := ExplosionScene.instantiate()
	ex.global_position = global_position
	(ex as Node).set("end_scale", 2.4)
	(ex as Node).set("duration", 0.45)
	(ex as CanvasItem).modulate = Color(1, 0.45, 0.32, 0.9)
	get_parent().add_child(ex)
	# Damage: anyone (player) inside the AOE range when it triggers
	var p := get_tree().get_first_node_in_group("player")
	if p and is_instance_valid(p) and p.has_method("take_damage"):
		if (p as Node2D).global_position.distance_to(global_position) < aoe_range:
			p.take_damage(aoe_damage)

func take_damage(amount: int, crit: bool = false, from_back: bool = false) -> void:
	if _dying or _hit_cooldown > 0.0:
		return
	# Dev one-shot toggle: skip HP math, go straight to death.
	if DevState.oneshot_kills:
		health = 0
		_begin_death()
		return
	_hit_cooldown = hit_invuln
	health -= amount
	modulate = Color(1, 0.4, 0.4)
	get_tree().create_timer(0.08).timeout.connect(_clear_hit_flash)
	if health <= 0:
		_begin_death()
		return
	if _phase == 1 and health <= max_health / 2:
		_enter_phase_2()
	elif _phase == 2 and is_final_fight and health <= max_health / 4:
		_enter_phase_3()

func _enter_phase_3() -> void:
	# Final-floor phase 3 — desperate, fast, dense pattern.
	_phase = 3
	throw_interval *= 0.55
	speed *= 1.25
	aoe_cooldown *= 0.6
	_hit_cooldown = 0.7
	var flash := ExplosionScene.instantiate()
	flash.global_position = global_position
	(flash as Node).set("end_scale", 3.0)
	(flash as Node).set("duration", 0.7)
	(flash as CanvasItem).modulate = Color(1, 0.25, 0.45, 1)  # angry red flash
	get_parent().add_child(flash)
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("shake"):
		p.shake(22.0, 0.45)

func _enter_phase_2() -> void:
	_phase = 2
	# Speed + throw cadence ramp up at half HP. Boss bear gets MAD.
	throw_interval *= 0.65
	speed *= 1.35
	aoe_cooldown *= 0.75
	slam_cooldown *= 0.7  # slams come more often once he's mad
	_maw_timer = 2.5      # fire the first Cleave Maw shortly after phase 2 begins
	_paw_timer = 5.5      # first Paw Slam comes a few seconds after the Maw
	# brief invuln + visual flash to signal the transition
	_hit_cooldown = 0.6
	var flash := ExplosionScene.instantiate()
	flash.global_position = global_position
	(flash as Node).set("end_scale", 2.2)
	(flash as Node).set("duration", 0.55)
	(flash as CanvasItem).modulate = Color(1, 0.7, 0.2, 0.9)
	get_parent().add_child(flash)
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("shake"):
		p.shake(14.0, 0.3)

func _slow_factor() -> float:
	for s in get_tree().get_nodes_in_group("slow_zones"):
		if s is Area2D and (s as Area2D).overlaps_body(self):
			return 0.55
	return 1.0

func _clear_hit_flash() -> void:
	if is_instance_valid(self) and not _dying:
		modulate = Color(1, 1, 1)

func _begin_death() -> void:
	_dying = true
	remove_from_group("enemies")
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	velocity = Vector2.ZERO
	_death_origin = position
	_death_time = 0.0
	# Boss drops a juicy 5 fluff
	MetaSave.add_fluff(5)
	MetaSave.add_cotton(1)   # bosses are the Cotton source (Workshop premium currency)
	RunState.stats_fluff_earned += 5
	var ap := get_node_or_null("AnimationPlayer")
	if ap:
		ap.stop()
	var lbl := get_node_or_null("NameLabel")
	if lbl:
		lbl.visible = false
	modulate = Color(1, 1, 1)
	# Hide the boss rig so the chunks visually take over from him.
	var rig := get_node_or_null("Rig")
	if rig:
		(rig as Node2D).visible = false
	# Huge explosion at boss position
	var ex := ExplosionScene.instantiate()
	ex.global_position = global_position
	get_parent().add_child(ex)
	# Body bursts into chunks flying outward
	_spawn_body_chunks()
	# Drop a full-heal pickup — but only if the player actually needs it
	if _player_needs_health():
		var heal_drop := FullHealScene.instantiate()
		heal_drop.global_position = global_position
		get_parent().add_child(heal_drop)
	# Camera shake via player
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("shake"):
		p.shake(28.0, 0.55)

func chain_explode() -> void:
	# When player explodes near the boss — just route into the normal full-power death.
	if _dying:
		return
	health = 0
	_begin_death()

func _player_needs_health() -> bool:
	var p := get_tree().get_first_node_in_group("player")
	if not is_instance_valid(p):
		return false
	var hp_v: Variant = p.get("health")
	var max_v: Variant = p.get("max_health")
	if not (hp_v is int) or not (max_v is int):
		return false
	return (hp_v as int) < (max_v as int)

func _spawn_body_chunks() -> void:
	# Upper-body chunk flies up & out (away from the floor)
	var upper := BodyChunkScene.instantiate()
	upper.texture = BossUpperTexture
	upper.texture_filter = 1
	upper.global_position = global_position + Vector2(0, -10)
	var upper_angle: float = randf_range(-PI * 0.85, -PI * 0.15)
	upper.velocity = Vector2.RIGHT.rotated(upper_angle) * randf_range(280, 380)
	upper.angular_velocity = randf_range(-7.0, 7.0)
	upper.initial_scale = 0.45
	upper.lifetime = 1.5
	get_parent().add_child(upper)
	# Legs chunk flies down & out
	var legs := BodyChunkScene.instantiate()
	legs.texture = BossLegsTexture
	legs.texture_filter = 1
	legs.global_position = global_position + Vector2(0, 10)
	var legs_angle: float = randf_range(PI * 0.15, PI * 0.85)
	legs.velocity = Vector2.RIGHT.rotated(legs_angle) * randf_range(260, 360)
	legs.angular_velocity = randf_range(-7.0, 7.0)
	legs.initial_scale = 0.45
	legs.lifetime = 1.5
	get_parent().add_child(legs)
	# Cotton stuffing puffs flung everywhere — lots of them
	for i in 18:
		var puff := BodyChunkScene.instantiate()
		puff.texture = StuffingTexture
		puff.global_position = global_position
		var ang: float = randf_range(0.0, TAU)
		puff.velocity = Vector2.RIGHT.rotated(ang) * randf_range(180, 420)
		puff.angular_velocity = randf_range(-12.0, 12.0)
		puff.initial_scale = randf_range(0.55, 1.25)
		puff.lifetime = randf_range(0.9, 1.4)
		get_parent().add_child(puff)

func _process_death(delta: float) -> void:
	_death_time += delta
	if _death_time <= DEATH_FALL_DURATION:
		var t: float = _death_time / DEATH_FALL_DURATION
		rotation = lerp(0.0, deg_to_rad(90.0), t)
	else:
		rotation = deg_to_rad(90.0)
		var fade_t: float = (_death_time - DEATH_FALL_DURATION) / DEATH_FADE_DURATION
		position = _death_origin + Vector2(
			randf_range(-6.0, 6.0),
			randf_range(-6.0, 6.0)
		)
		var a: float = clamp(1.0 - fade_t, 0.0, 1.0)
		modulate = Color(1, 1, 1, a)
		if fade_t >= 1.0:
			queue_free()
