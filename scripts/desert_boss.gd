extends CharacterBody2D

# Desert boss — slower, much tankier, charges in straight lines, summons adds.
# Uses brown-bear textures at huge scale as a placeholder until proper
# desert-bear photos come in.

const ExplosionScene := preload("res://scenes/explosion.tscn")
const FullHealScene := preload("res://scenes/full_heal.tscn")
const BodyChunkScene := preload("res://scenes/body_chunk.tscn")
const EnemyScene := preload("res://scenes/enemy.tscn")
const BrownUpperTexture := preload("res://assets/brown_upper.png")
const BrownLegsTexture := preload("res://assets/brown_legs.png")
const StuffingTexture := preload("res://assets/stuffing.png")

@export var speed: float = 85.0
@export var max_health: int = 114
@export var touch_damage: int = 2
@export var charge_speed: float = 684.0    # was 760 — additional 10% cut per user
@export var charge_duration: float = 1.35   # was 0.95 — travels far enough to read
@export var charge_telegraph: float = 0.32
@export var charge_cooldown: float = 1.5
@export var summon_cooldown: float = 4.5   # was 2.6 — significantly slower per user
@export var summons_max_alive: int = 4     # cap: don't summon if there are already this many
@export var hit_invuln: float = 0.28
@export var summons_per_wave: int = 1   # one add at a time per user req

const DEATH_FALL_DURATION: float = 0.45
const DEATH_FADE_DURATION: float = 4.5

var health: int
var player: Node2D
var damage_cooldown: float = 0.0
# Anti-grind on the IDLE chase state — back off briefly after a touch hit and
# orbit when too close instead of mashing into the player.
var _backoff_time: float = 0.0
var _orbit_sign: int = 1
const TOUCH_BACKOFF_DURATION: float = 0.5
const DESERT_PERSONAL_SPACE: float = 72.0
var _hit_cooldown: float = 0.0
var _phase: int = 1
var is_final_fight: bool = false
var _fire_trail_timer: float = 0.0
# Fire Pillars — replacement for the failed Wind Force. Every ~9s during the
# final fight, drops 5 fire patches in a ring AROUND the boss so the player
# is forced out of melee. Each pillar grows over time (fire_trail growth).
var _pillars_timer: float = 0.0
@export var pillars_cooldown: float = 9.0
@export var pillars_count: int = 5
@export var pillars_radius: float = 130.0
var _slam_timer: float = 0.0
@export var slam_cooldown: float = 4.5

enum ChargeState { IDLE, TELEGRAPH, CHARGING }
var charge_state: int = ChargeState.IDLE
var _charge_dir: Vector2 = Vector2.RIGHT
var _charge_timer: float = 0.0
var _charge_cd_timer: float = 0.0
var _summon_timer: float = 0.0

var _dying: bool = false
var _death_time: float = 0.0
var _death_origin: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("enemies")
	if GameSettings.difficulty == GameSettings.Difficulty.EASY:
		max_health = 80
		charge_cooldown = 2.0
	# Hard mode: ads were oppressive on the final boss; slow further still.
	elif GameSettings.difficulty == GameSettings.Difficulty.HARD:
		summon_cooldown = 6.0
		summons_max_alive = 4
	health = max_health
	player = get_tree().get_first_node_in_group("player")
	_charge_cd_timer = randf_range(1.5, 3.0)
	_summon_timer = summon_cooldown * 0.7
	_orbit_sign = -1 if randf() < 0.5 else 1
	# Debug: confirm we actually spawned and found the player.
	print("[desert_boss] _ready  hp=%d  speed=%s  final=%s  player=%s" % [
		health, str(speed), str(is_final_fight),
		"OK" if is_instance_valid(player) else "MISSING"
	])
	_slam_timer = 3.0  # initial delay before first slam

func _physics_process(delta: float) -> void:
	if _dying:
		_process_death(delta)
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return

	if _hit_cooldown > 0.0:
		_hit_cooldown -= delta

	var to_player: Vector2 = player.global_position - global_position

	match charge_state:
		ChargeState.IDLE:
			# Anti-grind: back off post-touch, orbit when too close, else chase.
			var chase_dir: Vector2 = to_player.normalized()
			if _backoff_time > 0.0:
				_backoff_time -= delta
				chase_dir = -chase_dir
			elif to_player.length() < DESERT_PERSONAL_SPACE:
				var tang: Vector2 = Vector2(-chase_dir.y, chase_dir.x) * float(_orbit_sign)
				chase_dir = (chase_dir * 0.15 + tang * 0.85).normalized()
			velocity = chase_dir * speed * _slow_factor()
			move_and_slide()
			_charge_cd_timer -= delta
			if _charge_cd_timer <= 0.0 and to_player.length() > 80.0:
				charge_state = ChargeState.TELEGRAPH
				_charge_dir = to_player.normalized()
				_charge_timer = charge_telegraph
				modulate = Color(1.4, 1.0, 0.6)  # warning glow
		ChargeState.TELEGRAPH:
			velocity = Vector2.ZERO
			move_and_slide()
			_charge_timer -= delta
			if _charge_timer <= 0.0:
				charge_state = ChargeState.CHARGING
				_charge_timer = charge_duration
				modulate = Color(1, 1, 1)
				if is_final_fight:
					_spawn_smoke_puff(_charge_dir)  # smoke forward at dash start
					# Wind force removed — the cone didn't read well in play.
				_fire_trail_timer = 0.0
		ChargeState.CHARGING:
			var pre_pos: Vector2 = global_position
			velocity = _charge_dir * charge_speed
			move_and_slide()
			# Stuck detection — if the dash made almost no forward progress
			# this frame, the boss is grinding on an obstacle. Terminate the
			# charge instead of "sitting in a tree" the whole duration.
			var traveled: float = global_position.distance_to(pre_pos)
			if traveled < charge_speed * delta * 0.25:
				_charge_timer = 0.0
			_charge_timer -= delta
			# Final-fight VFX: leave a fire trail behind the boss while dashing
			if is_final_fight:
				_fire_trail_timer -= delta
				if _fire_trail_timer <= 0.0:
					_fire_trail_timer = 0.08
					_spawn_fire_trail()
			# touch damage on connect during charge
			for i in get_slide_collision_count():
				var col := get_slide_collision(i)
				var c := col.get_collider()
				if c and c.is_in_group("player") and c.has_method("take_damage"):
					c.take_damage(touch_damage)
					_charge_timer = 0.0
					break
			if _charge_timer <= 0.0:
				charge_state = ChargeState.IDLE
				_charge_cd_timer = charge_cooldown
				# Wind force was removed — used to spawn a forward shockwave here.

	var rig := get_node_or_null("Rig")
	if rig and absf(to_player.x) > 1.0:
		rig.scale.x = absf(rig.scale.x) * (1 if to_player.x > 0 else -1)

	if damage_cooldown > 0.0:
		damage_cooldown -= delta
	if charge_state == ChargeState.IDLE and damage_cooldown <= 0.0:
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			var c := col.get_collider()
			if c and c.is_in_group("player") and c.has_method("take_damage"):
				c.take_damage(touch_damage)
				damage_cooldown = 0.8
				_backoff_time = TOUCH_BACKOFF_DURATION
				break

	# Phase-2 only: summon brown-bear adds periodically. Gated by a cap on
	# how many ads can be alive at once — keeps the room from drowning in
	# bears if the player is having trouble cleaning them up.
	if _phase == 2:
		_summon_timer -= delta
		if _summon_timer <= 0.0:
			_summon_timer = summon_cooldown
			if _count_ads_alive() < summons_max_alive:
				_summon_add()
	# Final-fight only: telegraphed Ground Slam under the player on a timer
	if is_final_fight:
		_slam_timer -= delta
		if _slam_timer <= 0.0:
			_slam_timer = slam_cooldown + randf_range(-0.6, 0.6)
			_spawn_ground_slam()
		# Fire Pillars — ring of growing fire patches forces player away
		_pillars_timer -= delta
		if _pillars_timer <= 0.0:
			_pillars_timer = pillars_cooldown + randf_range(-1.0, 1.0)
			_spawn_fire_pillars()

func _count_ads_alive() -> int:
	# All enemies except this boss itself.
	var n: int = 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and is_instance_valid(e):
			n += 1
	return n

func _summon_add() -> void:
	# Spawn N adds at random positions across the room (not bunched next to boss)
	var parent := get_parent()
	if not (parent is Node):
		return
	for i in summons_per_wave:
		var e := EnemyScene.instantiate()
		var p_pos: Vector2 = Vector2(720, 405)
		var player_node := get_tree().get_first_node_in_group("player")
		if player_node is Node2D:
			p_pos = (player_node as Node2D).global_position
		var spawn: Vector2 = Vector2(720, 405)
		for _attempt in 20:
			var candidate := Vector2(
				randf_range(140.0, 1300.0),
				randf_range(140.0, 670.0)
			)
			# don't spawn on top of player or boss
			if candidate.distance_to(p_pos) < 220.0:
				continue
			if candidate.distance_to(global_position) < 120.0:
				continue
			spawn = candidate
			break
		e.position = spawn
		# scrappier than a regular bear — faster, fewer HP
		e.speed = 130.0
		e.max_health = 1   # one-shot kill per user req
		parent.add_child(e)

const FireTrailScene := preload("res://scenes/fire_trail.tscn")

const GroundSlamScene := preload("res://scenes/ground_slam.tscn")

const WindForceScene := preload("res://scenes/wind_force.tscn")

func _spawn_wind_force(dir: Vector2) -> void:
	var w := WindForceScene.instantiate()
	w.global_position = global_position
	(w as Node).set("direction", dir.normalized())
	get_parent().add_child(w)

func _spawn_ground_slam() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if not (p is Node2D):
		return
	var slam := GroundSlamScene.instantiate()
	slam.global_position = (p as Node2D).global_position
	get_parent().add_child(slam)

func _spawn_fire_trail() -> void:
	# Real animated fire (CC0 fire1_64 sprite sheet, 60-frame). Each patch
	# damages the player on contact (1 dmg, i-frames protect from spam).
	var f := FireTrailScene.instantiate()
	f.global_position = global_position
	get_parent().add_child(f)

func _spawn_fire_pillars() -> void:
	# Spawn `pillars_count` fire patches in an evenly-spaced ring around the
	# boss. Each starts small via fire_trail's growth and matures into a real
	# zone within ~3 s. Forces the player to disengage briefly.
	var room_w: float = 1440.0
	var room_h: float = 810.0
	for i in pillars_count:
		var ang: float = TAU * float(i) / float(pillars_count) + randf_range(-0.1, 0.1)
		var spawn := global_position + Vector2(cos(ang), sin(ang)) * pillars_radius
		# clamp into the room
		spawn.x = clamp(spawn.x, 60.0, room_w - 60.0)
		spawn.y = clamp(spawn.y, 60.0, room_h - 60.0)
		var f := FireTrailScene.instantiate()
		f.global_position = spawn
		# Longer-lived than dash-trail patches; will grow and persist as terrain.
		(f as Node).set("lifetime", 6.5)
		(f as Node).set("fade_after", 5.0)
		(f as Node).set("grow_for", 2.2)
		(f as Node).set("peak_scale", 1.85)
		get_parent().add_child(f)

func _spawn_smoke_puff(forward: Vector2) -> void:
	# Big grey puff just ahead of the boss — punctuates the dash start/stop.
	var ex := ExplosionScene.instantiate()
	ex.global_position = global_position + forward.normalized() * 38.0
	(ex as Node).set("end_scale", 2.6)
	(ex as Node).set("duration", 0.55)
	(ex as CanvasItem).modulate = Color(0.78, 0.78, 0.82, 0.85)
	get_parent().add_child(ex)

func _slow_factor() -> float:
	for s in get_tree().get_nodes_in_group("slow_zones"):
		if s is Area2D and (s as Area2D).overlaps_body(self):
			return 0.55
	return 1.0

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

func _clear_hit_flash() -> void:
	if is_instance_valid(self) and not _dying:
		modulate = Color(1, 1, 1)

func _enter_phase_3() -> void:
	# Final-floor phase 3 — nerfed from earlier version, but still meaner than phase 2.
	_phase = 3
	speed *= 1.1
	charge_cooldown *= 0.7
	charge_speed *= 1.1
	# charge_duration stays — phase 2 already doubled it
	summon_cooldown *= 0.78   # was 0.6 — softer ramp now that we cap simultaneous ads
	_summon_timer = 0.6
	slam_cooldown *= 0.6  # Ground slams come faster in phase 3
	_hit_cooldown = 0.7
	var flash := ExplosionScene.instantiate()
	flash.global_position = global_position
	(flash as Node).set("end_scale", 3.0)
	(flash as Node).set("duration", 0.7)
	(flash as CanvasItem).modulate = Color(1, 0.25, 0.45, 1)
	get_parent().add_child(flash)
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("shake"):
		p.shake(22.0, 0.45)

func _enter_phase_2() -> void:
	_phase = 2
	speed *= 1.3
	charge_cooldown *= 0.6
	charge_duration *= 2.0  # DOUBLE charge distance — phase 2 dashes go way further
	_summon_timer = 1.0
	var flash := ExplosionScene.instantiate()
	flash.global_position = global_position
	(flash as Node).set("end_scale", 2.4)
	(flash as Node).set("duration", 0.55)
	(flash as CanvasItem).modulate = Color(1, 0.65, 0.25, 0.95)
	get_parent().add_child(flash)
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("shake"):
		p.shake(16.0, 0.32)

func chain_explode() -> void:
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

func _begin_death() -> void:
	_dying = true
	remove_from_group("enemies")
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	velocity = Vector2.ZERO
	_death_origin = position
	_death_time = 0.0
	MetaSave.add_fluff(5)
	MetaSave.add_cotton(1)   # bosses are the Cotton source (Workshop premium currency)
	RunState.stats_fluff_earned += 5
	var rig := get_node_or_null("Rig")
	if rig:
		(rig as Node2D).visible = false
	var ex := ExplosionScene.instantiate()
	ex.global_position = global_position
	get_parent().add_child(ex)
	_spawn_body_chunks()
	# Chain-explode any adds still alive in the room — they go up with the
	# boss but deal damage to the player if they're close. Door opens after.
	_chain_explode_remaining_ads()
	if _player_needs_health():
		var heal_drop := FullHealScene.instantiate()
		heal_drop.global_position = global_position
		get_parent().add_child(heal_drop)
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("shake"):
		p.shake(28.0, 0.55)

func _chain_explode_remaining_ads() -> void:
	# Stagger ad detonations by distance so it cascades outward, and damage
	# the player only if they're within the small AoE of an ad.
	const AD_AOE_RADIUS: float = 95.0
	const AD_AOE_DAMAGE: int = 1
	var pl := get_tree().get_first_node_in_group("player")
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or not is_instance_valid(e) or not (e is Node2D):
			continue
		var d: float = global_position.distance_to((e as Node2D).global_position)
		var delay: float = clamp(d / 900.0, 0.05, 0.7)
		var target: Node = e
		get_tree().create_timer(delay).timeout.connect(func():
			if not is_instance_valid(target):
				return
			# Quick orange explosion at the ad's position
			var ex := ExplosionScene.instantiate()
			ex.global_position = (target as Node2D).global_position
			(ex as Node).set("end_scale", 1.6)
			(ex as Node).set("duration", 0.4)
			(ex as CanvasItem).modulate = Color(1.0, 0.55, 0.30, 1.0)
			get_parent().add_child(ex)
			# Damage player if they're inside the AoE
			if is_instance_valid(pl) and pl.has_method("take_damage"):
				var off: Vector2 = (pl as Node2D).global_position - (target as Node2D).global_position
				if off.length() <= AD_AOE_RADIUS:
					pl.take_damage(AD_AOE_DAMAGE)
			target.queue_free()
		)

func _spawn_body_chunks() -> void:
	var upper := BodyChunkScene.instantiate()
	upper.texture = BrownUpperTexture
	upper.global_position = global_position + Vector2(0, -10)
	upper.velocity = Vector2.RIGHT.rotated(randf_range(-PI * 0.85, -PI * 0.15)) * randf_range(280, 380)
	upper.angular_velocity = randf_range(-7.0, 7.0)
	upper.initial_scale = 0.55
	upper.lifetime = 1.5
	get_parent().add_child(upper)
	var legs := BodyChunkScene.instantiate()
	legs.texture = BrownLegsTexture
	legs.global_position = global_position + Vector2(0, 10)
	legs.velocity = Vector2.RIGHT.rotated(randf_range(PI * 0.15, PI * 0.85)) * randf_range(260, 360)
	legs.angular_velocity = randf_range(-7.0, 7.0)
	legs.initial_scale = 0.55
	legs.lifetime = 1.5
	get_parent().add_child(legs)
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
		position = _death_origin + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
		var a: float = clamp(1.0 - fade_t, 0.0, 1.0)
		modulate = Color(1, 1, 1, a)
		if fade_t >= 1.0:
			queue_free()
