extends CharacterBody2D

const NinjaStarScene := preload("res://scenes/ninja_star.tscn")
const GroundSlamScene := preload("res://scenes/ground_slam.tscn")
const BearPawSlamScene := preload("res://scenes/bear_paw_slam.tscn")
const BearSpitScene := preload("res://scenes/bear_spit.tscn")
const HealthOrbScene := preload("res://scenes/health_orb.tscn")
const ExplosionScene := preload("res://scenes/explosion.tscn")
const BodyChunkScene := preload("res://scenes/body_chunk.tscn")
const StuffingBurstScene := preload("res://scenes/stuffing_burst.tscn")
# White "stuffing" splatter textures (blood VFX recoloured) — loaded once, shared.
static var _stuff_big: Texture2D = null
static var _stuff_small: Texture2D = null
static var _stain_tex: Array = []   # persistent floor/wall stuffing decals
var _stuffing_mult: float = 1.0     # per-enemy size of the stuffing puff (skeletons shrink it)
var shadow_abs_y: float = -1.0      # if >=0, absolute shadow feet-offset (non-bear rigs)
var shadow_abs_w: float = 64.0      # absolute shadow width when shadow_abs_y is used
const BrownUpperTexture := preload("res://assets/brown_upper.png")
const BrownLegsTexture := preload("res://assets/brown_legs.png")
const StuffingTexture := preload("res://assets/stuffing.png")

const HEALTH_DROP_CHANCE: float = 0.10
const WEAPON_DROP_CHANCE: float = 0.07

const BombPickupScene := preload("res://scenes/bomb_pickup.tscn")
const ScatterPickupScene := preload("res://scenes/scatter_pickup.tscn")
const HomingPickupScene := preload("res://scenes/homing_pickup.tscn")

@export var speed: float = 90.0
@export var max_health: int = 3
@export var touch_damage: int = 1
# Base KK throws ninja stars in the dungeon; subtypes with their own ranged
# attack (gun bear, shrinkwrap, brawler) set this false.
var throws_stars: bool = true
@export var throw_interval: float = 3.3   # was 2.7 — less frequent ninja stars on hard
@export var throw_speed: float = 391.0   # was 460 — hard-mode ninja star slowed 15%

# Dungeon guardian boss: throws a spread of glowing white ninja stars and
# periodically drops a telegraphed AoE slam under the player. Set true by the
# dungeon BEFORE add_child so _ready can tune the cadence.
var is_boss: bool = false
var _boss_aoe_timer: float = 0.0
var _boss_seen: bool = false        # has the boss laid eyes on the player yet?
var _boss_engage_t: float = 0.0     # 2s grace after first eye-contact before firing
var _boss_phase2: bool = false      # enraged: same moves + blinks around the arena
var _tp_timer: float = 0.0          # teleport cadence in phase 2
var _boss_far_t: float = 0.0        # leash timer — how long the boss has been far away
# Base KK paw-slam ground attack (ported from v1). Telegraphed drop from above
# onto the player's position. Long, readable windup (+0.5s over the v1 default).
var _paw_timer: float = 0.0
const PAW_COOLDOWN: float = 6.5
const PAW_RANGE: float = 420.0
const PAW_TELEGRAPH: float = 1.5   # v1 default 1.0 + the requested half second
const BOSS_AOE_COOLDOWN: float = 4.6
const BOSS_AOE_RADIUS: float = 158.0
const BOSS_AOE_DAMAGE: int = 2
const StarGlowTex := preload("res://assets/light_radial.png")

var health: int
var player: Node2D
var damage_cooldown: float = 0.0
var _throw_timer: float = 0.0
# ARPG: only pursue while we actually have line-of-sight + proximity. A short
# memory keeps a chase from stuttering, but breaking LOS (duck behind a wall)
# makes us give up — no more tracking you through solid rock.
const AGGRO_RANGE: float = 820.0
const AGGRO_MEMORY: float = 5.0   # keep chasing for 5s after losing line of sight
var _aggro_t: float = 0.0
var _los_check_t: float = 0.0
# When we've lost line of sight but are still aggro'd, follow an A* path around
# walls (from the dungeon) instead of grinding straight into them.
var _los_now: bool = false
var _nav_path: PackedVector2Array = PackedVector2Array()
var _nav_idx: int = 0
var _repath_t: float = 0.0
const WAYPOINT_REACH: float = 38.0
var _spit_timer: float = 0.0
var _spit_windup: float = 0.0          # >0 = telegraphing a spit
var _spit_target: Vector2 = Vector2.RIGHT
# Anti-grind: after touching the player, back off for a beat instead of
# continuing to push into him every frame.
var _backoff_time: float = 0.0
var _orbit_sign: int = 1   # which way around the player to circle when very close
var _personal_offset: Vector2 = Vector2.ZERO   # per-enemy chase offset for variance
var _personal_target_t: float = 0.0
var _speed_jitter: float = 1.0                 # ±15% per-enemy speed variance
# Dodge-when-shot: if hit repeatedly in a short window (the player holding a
# straight stream on us), juke sideways out of the line of fire for a beat.
var _dodge_time: float = 0.0          # >0 = currently strafing out of the way
var _dodge_dir: Vector2 = Vector2.ZERO
var _hit_streak: float = 0.0          # decays; each hit adds to it
const DODGE_TRIGGER: float = 1.8      # hit-streak needed to provoke a dodge
const DODGE_DURATION: float = 0.45    # how long the strafe lasts
const DODGE_STRENGTH: float = 1.6     # how hard the strafe pulls vs chase
const TOUCH_BACKOFF_DURATION: float = 0.65   # was 0.45 — longer juke-back
const PERSONAL_SPACE: float = 60.0           # was 46 — orbit kicks in farther out
const BACKOFF_SPEED_MULT: float = 1.4        # back-off vector is stronger than chase
# Short-range spit projectile (medium difficulty replacement for the boring
# lock-on AoE slam). Slow brown blob, ~240 px range, easy to dodge but adds
# meaningful pressure when bears are mid-range.
const SPIT_RANGE: float = 320.0
const SPIT_COOLDOWN: float = 2.6
const SPIT_TELEGRAPH: float = 0.35
const SPIT_SPEED: float = 280.0
var _burn_remaining: float = 0.0
var _burn_dps: int = 0
var _burn_tick: float = 0.0

# Stuck detection — when pinned against geometry, pick a random escape vector.
var _last_pos: Vector2 = Vector2.ZERO
var _stuck_time: float = 0.0
var _unstuck_dir: Vector2 = Vector2.ZERO
var _unstuck_remaining: float = 0.0
const STUCK_PIN_TIME: float = 0.22   # react sooner to being pinned
const STUCK_ESCAPE_TIME: float = 0.5
const STUCK_MIN_MOVEMENT: float = 0.6
# Universal pinned-on-geometry monitor (runs for EVERY enemy regardless of which
# movement code it uses — base chase, wander, or a custom subclass).
var _mon_last: Vector2 = Vector2.ZERO
var _mon_stuck: float = 0.0

func _process(delta: float) -> void:
	if _dying:
		return
	var moved: float = global_position.distance_to(_mon_last)
	_mon_last = global_position
	# Wants to move (has velocity) but isn't actually moving → it's wedged on a wall
	# corner/prop. Shove it sideways (perpendicular to its heading) to slide it free.
	if velocity.length() > 22.0 and moved < 0.35:
		_mon_stuck += delta
		if _mon_stuck >= 0.5:
			_mon_stuck = 0.0
			var perp: Vector2 = Vector2(-velocity.y, velocity.x).normalized()
			if randf() < 0.5:
				perp = -perp
			global_position += perp * 18.0
	else:
		_mon_stuck = 0.0

var _dying: bool = false
var _death_time: float = 0.0
var _death_origin: Vector2 = Vector2.ZERO
const DEATH_FALL_DURATION: float = 0.18
const DEATH_FADE_DURATION: float = 1.1

const AVOID_RADIUS: float = 95.0
const AVOID_REPULSION: float = 0.6
const AVOID_TANGENT: float = 1.2

const HAZARD_AVOID_RADIUS: float = 110.0
const HAZARD_AVOID_REPULSION: float = 1.8
const HAZARD_AVOID_TANGENT: float = 0.7

# Enemy-to-enemy separation — fixes the "all bears clump into one tile while
# being kited" problem. Below this distance, two enemies push apart from each
# other; at zero distance they get a random shove to break the deadlock.
const SEPARATION_RADIUS: float = 56.0
const SEPARATION_REPULSION: float = 1.4

# Per-instance steering variance so enemies don't all chase the exact same
# vector. Each enemy picks a random small offset around the player's position
# as its actual chase target, biased by `_orbit_sign`. Re-rolled occasionally.
const PERSONAL_TARGET_RADIUS: float = 70.0
const PERSONAL_TARGET_REROLL_INTERVAL: float = 2.6

func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	_orbit_sign = -1 if randf() < 0.5 else 1
	_speed_jitter = randf_range(0.86, 1.15)        # ±15% individual speed
	_reroll_personal_target()                       # initial unique chase offset
	# Move trash enemies to layer 3 so they don't physically push each
	# other — the swarm spreads via separation steering instead of grinding
	# into a wall of bears around the player. Player.gd sets mask bit 3 too
	# so the player still collides with them normally.
	set_collision_layer_value(1, false)
	set_collision_layer_value(3, true)
	if GameSettings.enemies_throw():
		_throw_timer = randf_range(0.8, throw_interval)
	if GameSettings.enemies_spit():
		# Stagger initial cooldowns so bears don't all spit at once on entry.
		_spit_timer = randf_range(1.0, SPIT_COOLDOWN)
	_spawn_contact_shadow()
	if is_boss:
		throws_stars = true
		throw_interval = 2.1              # a bit more breathing room between volleys
		_throw_timer = randf_range(1.0, 2.1)
		_boss_aoe_timer = randf_range(2.5, BOSS_AOE_COOLDOWN)
	elif ArpgState.active and throws_stars:
		_paw_timer = randf_range(3.0, PAW_COOLDOWN)   # base KK gets the paw slam
	if ArpgState.active:
		_build_hpbar()

var _hpbar_bg: ColorRect = null
var _hpbar_fill: ColorRect = null
var _hpbar_hi: ColorRect = null
const HPBAR_W: float = 40.0

func _build_hpbar() -> void:
	var rig := get_node_or_null("Rig") as Node2D
	var top_y: float = -46.0 * (rig.scale.y / 0.28 if rig != null else 1.0)
	# Frame (dark border + backing)
	_hpbar_bg = _mk_bar(Vector2(HPBAR_W + 4.0, 9.0), Vector2(-(HPBAR_W + 4.0) / 2.0, top_y - 1.0), Color(0.04, 0.03, 0.05, 0.9), 40)
	# Fill
	_hpbar_fill = _mk_bar(Vector2(HPBAR_W, 5.0), Vector2(-HPBAR_W / 2.0, top_y + 1.0), Color(0.4, 0.85, 0.4), 41)
	# Glossy highlight strip
	_hpbar_hi = _mk_bar(Vector2(HPBAR_W, 2.0), Vector2(-HPBAR_W / 2.0, top_y + 1.0), Color(1, 1, 1, 0.28), 42)

func _mk_bar(sz: Vector2, pos: Vector2, col: Color, z: int) -> ColorRect:
	var r := ColorRect.new()
	r.size = sz
	r.position = pos
	r.color = col
	r.z_index = z
	r.z_as_relative = false
	r.visible = false
	add_child(r)
	return r

func _update_hpbar() -> void:
	if _hpbar_fill == null:
		return
	var frac: float = clampf(float(health) / float(maxi(1, max_health)), 0.0, 1.0)
	# green → yellow → red as it drops
	var col: Color = Color(0.9, 0.25, 0.25)
	if frac > 0.5:
		col = Color(0.95, 0.78, 0.25).lerp(Color(0.4, 0.85, 0.42), (frac - 0.5) * 2.0)
	else:
		col = Color(0.9, 0.25, 0.25).lerp(Color(0.95, 0.78, 0.25), frac * 2.0)
	_hpbar_fill.size.x = HPBAR_W * frac
	_hpbar_fill.color = col
	_hpbar_hi.size.x = HPBAR_W * frac
	var damaged: bool = health < max_health and health > 0
	_hpbar_bg.visible = damaged
	_hpbar_fill.visible = damaged
	_hpbar_hi.visible = damaged

const SoftShadowTex := preload("res://assets/soft_shadow.png")

func _spawn_contact_shadow() -> void:
	# Soft, feathered ground shadow under the bear (radial-gradient sprite, not a
	# hard ellipse) so it reads as a real contact shadow. Drawn behind the rig.
	if has_node("DropShadow"):
		return
	var rig := get_node_or_null("Rig") as Node2D
	var k: float = absf(rig.scale.x) if rig != null else 0.28
	var sh := Sprite2D.new()
	sh.name = "DropShadow"
	sh.texture = SoftShadowTex
	sh.z_index = -1
	var tw: float = float(SoftShadowTex.get_width())
	# The bear formula (108*k etc.) assumes a ~0.3 rig scale on a 256px sprite. Mobs
	# with a very different rig (skeletons at 1.9-2.8) set absolute values instead,
	# otherwise the shadow lands hundreds of px below them and reads as "no shadow".
	if shadow_abs_y >= 0.0:
		sh.position = Vector2(0, shadow_abs_y)
		sh.scale = Vector2(shadow_abs_w / tw, (shadow_abs_w * 0.42) / tw)
	else:
		sh.position = Vector2(0, 108.0 * k)
		sh.scale = Vector2((300.0 * k) / tw, (120.0 * k) / tw)   # wide, short ellipse
	sh.modulate = Color(0.0, 0.0, 0.0, 0.9)                  # alpha lives in the texture
	add_child(sh)
	move_child(sh, 0)

var _avoid_cached: Vector2 = Vector2.ZERO
var _avoid_t: float = 0.0

# Accumulated steer-away from obstacles, live hazards, and neighbouring enemies.
# Called on a throttle (not every frame) so the swarm stays cheap.
func _compute_avoidance(to_player: Vector2) -> Vector2:
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
	for h in get_tree().get_nodes_in_group("hazards"):
		if not (h is Node2D):
			continue
		if h.has_method("is_dangerous") and not (h as Node).is_dangerous():
			continue
		var hoff: Vector2 = global_position - (h as Node2D).global_position
		var hdist: float = hoff.length()
		if hdist < HAZARD_AVOID_RADIUS and hdist > 0.5:
			var hstrength: float = 1.0 - hdist / HAZARD_AVOID_RADIUS
			var haway: Vector2 = hoff / hdist
			var htang: Vector2 = Vector2(-haway.y, haway.x)
			if htang.dot(to_player) < 0.0:
				htang = -htang
			avoid += (haway * HAZARD_AVOID_REPULSION + htang * HAZARD_AVOID_TANGENT) * hstrength
	# Enemy separation — cheap squared-distance reject before any sqrt.
	var sep_sq: float = SEPARATION_RADIUS * SEPARATION_RADIUS
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not (other is Node2D):
			continue
		var off2: Vector2 = global_position - (other as Node2D).global_position
		var dsq: float = off2.length_squared()
		if dsq > 0.001 and dsq < sep_sq:
			var d: float = sqrt(dsq)
			var s: float = 1.0 - d / SEPARATION_RADIUS
			if d < 4.0:
				off2 = Vector2.RIGHT.rotated(randf() * TAU)
			avoid += (off2 / max(d, 1.0)) * SEPARATION_REPULSION * s
	return avoid

func _physics_process(delta: float) -> void:
	if _dying:
		_process_death(delta)
		return

	# Burn status: tick damage every 1s while remaining > 0
	if _burn_remaining > 0.0:
		_burn_remaining -= delta
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick = 1.0
			take_damage(_burn_dps)
			if _dying:
				return

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
	# ARPG: pursue only while we can SEE the player (LOS + in range), with a
	# short memory. Lose sight → we stop. No charging through walls.
	if ArpgState.active:
		_los_check_t -= delta
		if _los_check_t <= 0.0:
			_los_check_t = 0.15
			_los_now = global_position.distance_to(player.global_position) < AGGRO_RANGE and _has_los_to_player()
			if _los_now:
				_aggro_t = AGGRO_MEMORY
		_aggro_t = maxf(_aggro_t - delta, 0.0)
		if _aggro_t <= 0.0:
			_wander(delta)
			return
	# Re-roll personal chase offset every few seconds so each enemy doesn't
	# converge to the exact same spot when kited.
	_personal_target_t -= delta
	if _personal_target_t <= 0.0:
		_reroll_personal_target()
	# Aim at the player — but if we've lost sight (still aggro'd), aim at the next
	# waypoint of a path that routes AROUND walls instead of straight through them.
	var target_pos: Vector2 = player.global_position
	if ArpgState.active and not _los_now:
		target_pos = _path_target(delta)
	var chase_anchor: Vector2 = target_pos + _personal_offset
	var to_player: Vector2 = chase_anchor - global_position
	var desired: Vector2 = to_player.normalized()
	# Anti-grind: don't keep pushing INTO the player.
	if _backoff_time > 0.0:
		_backoff_time -= delta
		desired = -desired * BACKOFF_SPEED_MULT  # stronger juke-back
	elif to_player.length() < PERSONAL_SPACE:
		# Too close — circle the player instead of grinding into him.
		var tang: Vector2 = Vector2(-desired.y, desired.x) * float(_orbit_sign)
		desired = (desired * 0.15 + tang * 0.85).normalized()
	# Avoidance (obstacles + hazards + enemy separation) is O(N) per enemy → O(N²)
	# for the swarm. It doesn't need 60 Hz precision, so recompute ~11×/sec and
	# reuse the cached vector in between. Huge FPS win with big swarms.
	_avoid_t -= delta
	if _avoid_t <= 0.0:
		_avoid_t = 0.09
		_avoid_cached = _compute_avoidance(to_player)
	var avoid: Vector2 = _avoid_cached
	# Dodge-when-shot: a brief sideways juke layered over the normal chase so the
	# enemy slides out of a held stream of fire. Decays the hit-streak too.
	_hit_streak = maxf(0.0, _hit_streak - delta * 1.2)
	if _dodge_time > 0.0:
		_dodge_time -= delta
		desired = (desired * 0.35 + _dodge_dir * DODGE_STRENGTH).normalized()
	var steer: Vector2 = (desired + avoid).normalized()

	# Stuck detection — if movement is being denied (pinned against a prop),
	# pick a random escape direction and commit to it briefly.
	if _unstuck_remaining > 0.0:
		_unstuck_remaining -= delta
		steer = _unstuck_dir
	else:
		var moved: float = global_position.distance_to(_last_pos)
		if moved < STUCK_MIN_MOVEMENT:
			_stuck_time += delta
			if _stuck_time >= STUCK_PIN_TIME:
				# perpendicular to the desired direction, side toward player
				var perp: Vector2 = Vector2(-desired.y, desired.x)
				if randf() < 0.5:
					perp = -perp
				_unstuck_dir = (perp * 1.4 + desired * 0.2).normalized()
				_unstuck_remaining = STUCK_ESCAPE_TIME
				_stuck_time = 0.0
		else:
			_stuck_time = 0.0
		_last_pos = global_position

	velocity = steer * speed * _speed_jitter * _slow_factor()
	move_and_slide()

	var rig := get_node_or_null("Rig")
	if rig and absf(to_player.x) > 1.0:
		rig.scale.x = absf(rig.scale.x) * (1 if to_player.x > 0 else -1)

	if damage_cooldown > 0.0:
		damage_cooldown -= delta
	if damage_cooldown <= 0.0:
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			var c := col.get_collider()
			if c and c.is_in_group("player") and c.has_method("take_damage"):
				c.take_damage(touch_damage)
				damage_cooldown = 0.6
				_backoff_time = TOUCH_BACKOFF_DURATION  # back off, don't grind
				break

	# Spawn safety: nothing fires during the level-entry grace. The boss also gets
	# a 2s "eye-contact" grace the first time it sees the player.
	var shoot_ok: bool = not (ArpgState.active and ArpgState.in_spawn_grace())
	if is_boss and ArpgState.active:
		if not _boss_seen and _has_los_to_player():
			_boss_seen = true
			_boss_engage_t = 2.0
		if _boss_engage_t > 0.0:
			_boss_engage_t -= delta
			shoot_ok = false

	# Dungeon: every KK throws ninja stars (LOS-gated). Main game: difficulty-based.
	if shoot_ok and throws_stars and (ArpgState.active or GameSettings.enemies_throw()):
		_throw_timer -= delta
		if _throw_timer <= 0.0:
			_throw_timer = throw_interval + randf_range(-0.4, 0.4)
			if not ArpgState.active or _has_los_to_player():
				_throw_ninja_star()

	# Base KK paw slam: telegraphed giant paw drops on the player's position.
	if shoot_ok and throws_stars and not is_boss and ArpgState.active:
		_paw_timer -= delta
		if _paw_timer <= 0.0:
			_paw_timer = PAW_COOLDOWN + randf_range(-1.0, 1.5)
			if global_position.distance_to(player.global_position) <= PAW_RANGE and _has_los_to_player():
				_paw_slam()

	# Boss AoE: periodically drop a telegraphed slam under the player (dodgeable).
	if shoot_ok and is_boss and ArpgState.active:
		_boss_aoe_timer -= delta
		if _boss_aoe_timer <= 0.0:
			_boss_aoe_timer = BOSS_AOE_COOLDOWN + randf_range(-0.6, 0.8)
			if _has_los_to_player():
				_boss_aoe()

	# Boss phase 2 (enrage at <45% HP): keeps the same moves but blinks around the
	# arena, so you can't just sit behind cover and plink it.
	if is_boss and ArpgState.active and not _dying:
		if not _boss_phase2 and float(health) <= float(max_health) * 0.45:
			_boss_phase2 = true
			_tp_timer = 1.7
			modulate = Color(2.0, 0.7, 1.2)   # enrage flash
			Juice.shake(0.3)
		if _boss_phase2:
			_tp_timer -= delta
			if _tp_timer <= 0.0:
				_tp_timer = randf_range(1.9, 3.1)   # ~25% faster blink cadence
				_boss_teleport()
		# Leash: if the boss is far from the player for a few seconds (stuck behind
		# walls / teleported somewhere awkward), warp him back into view. Stops the
		# "boss at 10% vanished and I can't find him" dead-end.
		if global_position.distance_to(player.global_position) > 820.0:
			_boss_far_t += delta
			if _boss_far_t >= 3.5:
				_boss_far_t = 0.0
				_boss_teleport()
		else:
			_boss_far_t = 0.0

	# Brown spit blob is legacy main-game only (looked bad) — never in the dungeon.
	if not ArpgState.active and GameSettings.enemies_spit():
		_tick_spit(delta)

func _boss_teleport() -> void:
	if not is_instance_valid(player):
		return
	var space := get_world_2d().direct_space_state
	# Collapse/vanish at the old spot.
	_boss_warp_fx(global_position, false)
	# Preferred: ask the level for a guaranteed FLOOR cell near the player — this is
	# what stops him warping into rock / outside the playable area.
	var parent := get_parent()
	if parent != null and parent.has_method("floor_point_near"):
		# require_los → always reappears where the player can see/reach him.
		global_position = parent.call("floor_point_near", player.global_position, 190.0, 380.0, true)
		_boss_arrive()
		return
	# Fallback (non-dungeon): a few candidates, rejecting any that's inside a wall or
	# on the far side of one.
	for _attempt in 10:
		var ang: float = randf() * TAU
		var dist: float = randf_range(190.0, 360.0)
		var cand: Vector2 = player.global_position + Vector2(cos(ang), sin(ang)) * dist
		var pq := PhysicsPointQueryParameters2D.new()
		pq.position = cand
		pq.collision_mask = 1
		if not space.intersect_point(pq).is_empty():
			continue   # candidate is inside a wall
		var q := PhysicsRayQueryParameters2D.create(cand, player.global_position)
		q.collision_mask = 1
		q.exclude = [self]
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty() or hit.get("collider") == player:
			global_position = cand
			_boss_arrive()
			return
	global_position = player.global_position + Vector2(cos(randf() * TAU), sin(randf() * TAU)) * 230.0
	_boss_arrive()

func _boss_arrive() -> void:
	_boss_warp_fx(global_position, true)
	# Pop the body back in (snap from small with an overshoot) so the reappear reads.
	var rig := get_node_or_null("Rig") as Node2D
	if rig != null:
		var base: Vector2 = rig.scale
		rig.scale = base * 0.35
		var tw := rig.create_tween()
		tw.tween_property(rig, "scale", base, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _boss_warp_fx(pos: Vector2, appearing: bool) -> void:
	var parent := get_parent()
	if parent == null:
		return
	if not appearing:
		# VANISH — eight shards streak inward to a point, then wink out (implosion).
		for i in 8:
			var a: float = TAU * float(i) / 8.0
			var seg := Line2D.new()
			var dir := Vector2(cos(a), sin(a))
			seg.points = PackedVector2Array([dir * 46.0, dir * 26.0])
			seg.width = 4.0
			seg.default_color = Color(1.5, 0.6, 1.7, 0.95)
			seg.global_position = pos
			seg.z_index = 50
			parent.add_child(seg)
			var tw := seg.create_tween()
			tw.set_parallel(true)
			tw.tween_property(seg, "position", pos, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(seg, "modulate:a", 0.0, 0.18)
			tw.chain().tween_callback(seg.queue_free)
	else:
		# ARRIVE — a sharp 4-point star flash + a quick thin shockwave ring.
		var star := Polygon2D.new()
		star.polygon = PackedVector2Array([
			Vector2(0, -34), Vector2(7, -7), Vector2(34, 0), Vector2(7, 7),
			Vector2(0, 34), Vector2(-7, 7), Vector2(-34, 0), Vector2(-7, -7)])
		star.color = Color(1.7, 1.0, 1.9, 0.95)
		star.global_position = pos
		star.z_index = 51
		parent.add_child(star)
		var ts := star.create_tween()
		ts.set_parallel(true)
		ts.tween_property(star, "scale", Vector2(1.6, 1.6), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ts.tween_property(star, "rotation", PI * 0.5, 0.22)
		ts.tween_property(star, "modulate:a", 0.0, 0.22)
		ts.chain().tween_callback(star.queue_free)
		var ring := Line2D.new()
		var pts := PackedVector2Array()
		for i in 17:
			var aa: float = TAU * float(i) / 16.0
			pts.append(Vector2(cos(aa), sin(aa)) * 8.0)
		ring.points = pts
		ring.width = 3.0
		ring.default_color = Color(1.4, 0.8, 1.6, 0.85)
		ring.global_position = pos
		ring.z_index = 50
		parent.add_child(ring)
		var tr := ring.create_tween()
		tr.set_parallel(true)
		tr.tween_property(ring, "scale", Vector2(5.5, 5.5), 0.24)
		tr.tween_property(ring, "modulate:a", 0.0, 0.24)
		tr.chain().tween_callback(ring.queue_free)

func _paw_slam() -> void:
	if not is_instance_valid(player):
		return
	var paw := BearPawSlamScene.instantiate()
	(paw as Node2D).global_position = (player as Node2D).global_position
	paw.set("telegraph", PAW_TELEGRAPH)
	paw.set("radius", 95.0)
	paw.set("damage", 2)
	get_parent().add_child(paw)

func _boss_aoe() -> void:
	if not is_instance_valid(player):
		return
	var slam := GroundSlamScene.instantiate()
	slam.global_position = (player as Node2D).global_position
	slam.set("radius", BOSS_AOE_RADIUS)
	slam.set("windup", 1.7)   # slower telegraph — was way too fast to react to
	slam.set("damage", BOSS_AOE_DAMAGE)
	get_parent().add_child(slam)

func _tick_spit(delta: float) -> void:
	if _spit_windup > 0.0:
		# Telegraph phase: brief modulate flash on the bear's body.
		_spit_windup -= delta
		modulate = Color(1.0, 0.8, 0.5)
		if _spit_windup <= 0.0:
			modulate = Color(1, 1, 1)
			_fire_spit()
		return
	_spit_timer -= delta
	if _spit_timer <= 0.0:
		_spit_timer = SPIT_COOLDOWN + randf_range(-0.6, 0.6)
		if is_instance_valid(player):
			var d: float = global_position.distance_to(player.global_position)
			if d <= SPIT_RANGE and d > 40.0 and (not ArpgState.active or _has_los_to_player()):
				_spit_target = (player.global_position - global_position).normalized()
				_spit_windup = SPIT_TELEGRAPH

func _path_target(delta: float) -> Vector2:
	# Re-query a path to the player periodically and steer toward the current
	# waypoint, so we round corners instead of pushing into the wall between us.
	if not is_instance_valid(player):
		return global_position
	_repath_t -= delta
	if _repath_t <= 0.0 or _nav_path.is_empty():
		_repath_t = 0.5
		var nav := get_parent()
		if nav != null and nav.has_method("nav_path"):
			_nav_path = nav.call("nav_path", global_position, player.global_position)
			_nav_idx = 0
	if _nav_path.is_empty():
		return player.global_position
	while _nav_idx < _nav_path.size() and global_position.distance_to(_nav_path[_nav_idx]) < WAYPOINT_REACH:
		_nav_idx += 1
	if _nav_idx >= _nav_path.size():
		return player.global_position
	return _nav_path[_nav_idx]

func _has_los_to_player() -> bool:
	# Raycast against walls (layer 1). Clear if nothing blocks, or the first
	# thing the ray meets IS the player (walls share layer 1 with the player,
	# so a wall in between registers as the nearer hit).
	if not is_instance_valid(player):
		return false
	if DevState.arena_mode:
		return true   # dev test: penned enemies always "see" you so they attack
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, (player as Node2D).global_position)
	q.collision_mask = 1
	q.exclude = [self]
	var hit: Dictionary = space.intersect_ray(q)
	return hit.is_empty() or hit.get("collider") == player

func _reroll_personal_target() -> void:
	# Pick a fresh small offset around the player so this enemy chases a
	# slightly different point. Biased to one side via `_orbit_sign` so the
	# enemy tends to approach from a consistent angle within a target window.
	var ang: float = randf_range(-PI * 0.4, PI * 0.4) * float(_orbit_sign)
	var dist: float = randf_range(20.0, PERSONAL_TARGET_RADIUS)
	_personal_offset = Vector2.RIGHT.rotated(ang) * dist
	_personal_target_t = PERSONAL_TARGET_REROLL_INTERVAL + randf_range(-0.4, 0.4)

func _fire_spit() -> void:
	var s := BearSpitScene.instantiate()
	s.global_position = global_position
	s.set("direction", _spit_target)
	s.set("speed", SPIT_SPEED)
	get_parent().add_child(s)

func _throw_ninja_star() -> void:
	if not is_instance_valid(player):
		return
	var dir: Vector2 = (player.global_position - global_position).normalized()
	if is_boss:
		# Glowing white 3-star spread — wide spacing so you can slip between them.
		for off in [-0.5, 0.0, 0.5]:
			_spawn_ninja_star(dir.rotated(off), true)
	else:
		_spawn_ninja_star(dir, false)

func _spawn_ninja_star(dir: Vector2, glowing: bool) -> void:
	var s := NinjaStarScene.instantiate()
	s.global_position = global_position
	s.direction = dir
	s.speed = throw_speed * (0.78 if glowing else 1.0)   # boss stars slowed — easier to dodge
	if glowing:
		s.damage = 2
		# Same star art as the grunt KK bears — just a little bigger, glowing slightly
		# less. (The custom boss shuriken looked dumb.)
		(s as Node2D).modulate = Color(1.2, 1.2, 1.3)
		(s as Node2D).scale *= 1.35
		if not ArpgState.no_projectile_glow:
			var glow := PointLight2D.new()
			glow.texture = StarGlowTex
			glow.color = Color(0.95, 0.92, 1.0)
			glow.energy = 0.4
			glow.texture_scale = 0.5
			s.add_child(glow)
	else:
		# Regular thrown stars get a very light glow so you can spot them in the dark.
		if not (ArpgState.active and ArpgState.no_projectile_glow):
			var g2 := PointLight2D.new()
			g2.texture = StarGlowTex
			g2.color = Color(0.9, 0.9, 1.0)
			g2.energy = 0.35
			g2.texture_scale = 0.3
			s.add_child(g2)
	get_parent().add_child(s)

func _spawn_damage_number(amount: int, crit: bool) -> void:
	if amount <= 0:
		return
	var lbl := Label.new()
	lbl.text = ("%d!" % amount) if crit else str(amount)
	lbl.add_theme_font_size_override("font_size", 30 if crit else 20)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.18) if crit else Color(1.0, 0.96, 0.92))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.z_index = 60
	lbl.z_as_relative = false
	lbl.global_position = global_position + Vector2(randf_range(-14.0, 14.0), -38.0)
	get_parent().add_child(lbl)
	var rise: float = 46.0 + (18.0 if crit else 0.0)
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position:y", lbl.global_position.y - rise, 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.6).set_delay(0.22)
	if crit:
		lbl.scale = Vector2(0.5, 0.5)
		tw.tween_property(lbl, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(lbl.queue_free)

func _stuffing_tex(big: bool) -> Texture2D:
	var path: String = "res://assets/stuffing_burst.png" if big else "res://assets/stuffing_hit.png"
	if big:
		if _stuff_big == null:
			_stuff_big = _stuffing_load(path)
		return _stuff_big
	if _stuff_small == null:
		_stuff_small = _stuffing_load(path)
	return _stuff_small

func _stuffing_load(path: String) -> Texture2D:
	if FileAccess.file_exists(path):
		var b := FileAccess.get_file_as_bytes(path)
		if b.size() > 0:
			var img := Image.new()
			if img.load_png_from_buffer(b) == OK:
				return ImageTexture.create_from_image(img)
	return null

func _spawn_stuffing(big: bool) -> void:
	var tex: Texture2D = _stuffing_tex(big)
	if tex == null or not is_instance_valid(get_parent()):
		return
	var s := StuffingBurstScene.instantiate()
	s.texture = tex
	s.global_position = global_position
	s.scale = Vector2.ONE * (2.1 if big else 1.25) * _stuffing_mult
	s.rotation = randf() * TAU
	get_parent().add_child(s)

# Leave a lingering stuffing STAIN on the floor (or the wall, if killed next to
# one) — fades after a while so they don't pile up and cost FPS.
func _spawn_kill_stain() -> void:
	pass   # every kill leaves a stain now (was a 40% gate — felt inconsistent)
	var parent := get_parent()
	if not is_instance_valid(parent):
		return
	if _stain_tex.is_empty():
		for p in ["res://assets/stuffing_stain1.png", "res://assets/stuffing_stain2.png"]:
			var t: Texture2D = _stuffing_load(p)
			if t != null:
				_stain_tex.append(t)
	if _stain_tex.is_empty():
		return
	var pos: Vector2 = global_position
	var zi: int = -3                      # on the floor, under everything
	var rot: float = randf() * TAU
	if parent.has_method("floor_at_world") and "tile" in parent:
		var t: float = parent.tile
		for dir in [Vector2(t, 0), Vector2(-t, 0), Vector2(0, t), Vector2(0, -t)]:
			if not parent.floor_at_world(global_position + dir):   # a wall is there
				pos = global_position + dir * 0.55   # climb onto the wall face
				zi = 1                                # drawn over the wall base
				rot = dir.angle() + PI * 0.5
				break
	var s := Sprite2D.new()
	s.texture = _stain_tex[randi() % _stain_tex.size()]
	s.global_position = pos
	s.rotation = rot
	s.scale = Vector2.ONE * randf_range(0.7, 1.05) * (4.0 if is_boss else 1.0)   # boss stain huge
	s.z_index = zi
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.modulate = Color(1, 1, 1, 0.85)
	parent.add_child(s)
	var tw := s.create_tween()
	tw.tween_interval(10.0)                              # hold for 10s…
	tw.tween_property(s, "modulate:a", 0.0, 5.0)        # …then slowly fade
	tw.tween_callback(s.queue_free)

func take_damage(amount: int, crit: bool = false) -> void:
	if _dying:
		return
	_spawn_damage_number(amount, crit)
	if randf() < 0.22:
		_spawn_stuffing(false)   # small stuffing puff on some hits
	if DevState.oneshot_kills:
		health = 0
		_begin_death()
		return
	health -= amount
	_update_hpbar()
	# Dodge-when-shot: accumulate a hit-streak; once it crosses the threshold,
	# juke perpendicular to the incoming line (toward/away from the player) so
	# standing still and holding fire on us stops being a free kill.
	_hit_streak += 1.0
	if _hit_streak >= DODGE_TRIGGER and _dodge_time <= 0.0 and health > 0:
		_start_dodge()
	# Overdriven white hit-flash (HDR > 1 so it blooms), plus a sliver of shake.
	modulate = Color(2.4, 1.7, 1.7)
	Juice.shake(0.05)
	get_tree().create_timer(0.08).timeout.connect(_clear_hit_flash)
	# Dev arena: immortal — flash + dodge still play, but it never dies so you can
	# keep studying its attacks.
	if DevState.arena_mode:
		health = max_health
		_update_hpbar()
		return
	if health <= 0:
		Juice.shake(0.14)
		_begin_death()

# For subclasses that override _physics_process (they don't run the base steering
# dodge): ticks the dodge timers and returns a velocity to ADD this frame.
var _wander_dir: Vector2 = Vector2.ZERO
var _wander_t: float = 0.0

func _wander(delta: float) -> void:
	# No line of sight on the player — slowly amble in a random direction (with the
	# odd pause) instead of standing frozen. New heading every few seconds.
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = randf_range(1.6, 3.6)
		_wander_dir = Vector2.ZERO if randf() < 0.25 else Vector2.from_angle(randf() * TAU)
	velocity = velocity.lerp(_wander_dir * speed * 0.32, 0.06)
	move_and_slide()

func _dodge_tick(delta: float) -> Vector2:
	_hit_streak = maxf(0.0, _hit_streak - delta * 1.2)
	if _dodge_time > 0.0:
		_dodge_time -= delta
		return _dodge_dir * speed * DODGE_STRENGTH
	return Vector2.ZERO

func _start_dodge() -> void:
	# Strafe perpendicular to the line between us and the player, picking the side
	# we're already leaning toward so the juke looks intentional.
	var to_player: Vector2 = Vector2.RIGHT
	if is_instance_valid(player):
		to_player = (player.global_position - global_position).normalized()
	var perp: Vector2 = Vector2(-to_player.y, to_player.x)
	if perp.dot(velocity) < 0.0:
		perp = -perp
	if randf() < 0.2:                      # occasional flip keeps it unpredictable
		perp = -perp
	_dodge_dir = perp
	_dodge_time = DODGE_DURATION
	_hit_streak = 0.0

func apply_burn(dps: int, duration: float) -> void:
	if _dying:
		return
	# stack: take the longer remaining time, the bigger dps
	_burn_remaining = max(_burn_remaining, duration)
	_burn_dps = max(_burn_dps, dps)
	if _burn_tick <= 0.0:
		_burn_tick = 1.0
	# subtle red tint while burning
	modulate = Color(1, 0.55, 0.45)

func _slow_factor() -> float:
	for s in get_tree().get_nodes_in_group("slow_zones"):
		if s is Area2D and (s as Area2D).overlaps_body(self):
			return 0.55
	return 1.0

func _clear_hit_flash() -> void:
	if is_instance_valid(self) and not _dying:
		modulate = Color(1, 1, 1)

# Strip ALL collision the instant we die so the corpse never blocks the player
# during the death animation. (Enemies live on layer 3 — clearing only layer 1,
# as the old code did, left the body solid until it freed.)
func _kill_collision() -> void:
	collision_layer = 0
	collision_mask = 0
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs != null:
		cs.set_deferred("disabled", true)

func _begin_death() -> void:
	_dying = true
	_spawn_stuffing(true)    # big stuffing burst on death
	_spawn_kill_stain()      # + a lingering floor/wall stain
	if is_boss:
		# The guardian goes out with a bang.
		var bex := ExplosionScene.instantiate()
		bex.global_position = global_position
		(bex as Node).set("end_scale", 6.5)
		(bex as Node).set("duration", 0.9)
		get_parent().add_child(bex)
		Juice.shake(0.75)
	# ARPG: award XP/gold and maybe drop loot (no-op in the legacy main game).
	if ArpgState.active:
		ArpgState.notify_kill(global_position)
	remove_from_group("enemies")
	_kill_collision()
	velocity = Vector2.ZERO
	_death_origin = position
	_death_time = 0.0
	var ap := get_node_or_null("AnimationPlayer")
	if ap:
		ap.stop()
	modulate = Color(1, 1, 1)
	# Lucky Crumbs boon doubles drop chances
	var drop_mult: float = RunState.drop_chance_multiplier()
	if randf() < HEALTH_DROP_CHANCE * drop_mult and _player_needs_health():
		var orb := HealthOrbScene.instantiate()
		orb.global_position = global_position
		get_parent().add_child(orb)
	# Always award fluff currency + bump kill stat
	RunState.stats_enemies_killed += 1
	# Notify player so the kill-streak combo counter increments.
	var pl := get_tree().get_first_node_in_group("player")
	if pl and pl.has_method("notify_killed_enemy"):
		pl.notify_killed_enemy()
	var fluff_drop: int = 1
	var greed: int = MetaSave.upgrade_level("greedy_paws")   # Workshop: +12%/lvl bonus fluff
	if greed > 0 and randf() < 0.12 * float(greed):
		fluff_drop += 1
	MetaSave.add_fluff(fluff_drop)
	RunState.stats_fluff_earned += fluff_drop
	# Old special-weapon pickups (bomb/scatter/homing) only exist in the legacy
	# main game — in the ARPG the loot system handles drops, and these specials
	# are ignored by the equipped-weapon attack (so they'd do nothing).
	if not ArpgState.active and randf() < WEAPON_DROP_CHANCE * drop_mult:
		var roll: int = randi() % 3
		var scene: PackedScene
		match roll:
			0: scene = BombPickupScene
			1: scene = ScatterPickupScene
			_: scene = HomingPickupScene
		var pickup := scene.instantiate()
		pickup.global_position = global_position
		get_parent().add_child(pickup)

func _player_needs_health() -> bool:
	var p := get_tree().get_first_node_in_group("player")
	if not is_instance_valid(p):
		return false
	var hp_v: Variant = p.get("health")
	var max_v: Variant = p.get("max_health")
	if not (hp_v is int) or not (max_v is int):
		return false
	return (hp_v as int) < (max_v as int)

func chain_explode() -> void:
	# Called when the player explodes nearby — pop in a small burst, fling chunks, vanish.
	if _dying:
		return
	_dying = true
	remove_from_group("enemies")
	_kill_collision()
	velocity = Vector2.ZERO
	var ap := get_node_or_null("AnimationPlayer")
	if ap:
		ap.stop()
	var rig := get_node_or_null("Rig")
	if rig:
		(rig as Node2D).visible = false
	# Small explosion
	var ex := ExplosionScene.instantiate()
	ex.global_position = global_position
	(ex as Node).set("end_scale", 3.5)
	(ex as Node).set("duration", 0.75)
	get_parent().add_child(ex)
	# Brown-bear chunks
	var upper := BodyChunkScene.instantiate()
	upper.texture = BrownUpperTexture
	upper.global_position = global_position + Vector2(0, -6)
	upper.velocity = Vector2.RIGHT.rotated(randf_range(-PI * 0.9, -PI * 0.1)) * randf_range(220.0, 320.0)
	upper.angular_velocity = randf_range(-7.0, 7.0)
	upper.initial_scale = 0.38
	upper.lifetime = 2.4
	upper.fade_after = 0.7
	upper.drag = 0.03
	get_parent().add_child(upper)
	var legs := BodyChunkScene.instantiate()
	legs.texture = BrownLegsTexture
	legs.global_position = global_position + Vector2(0, 6)
	legs.velocity = Vector2.RIGHT.rotated(randf_range(PI * 0.1, PI * 0.9)) * randf_range(200.0, 300.0)
	legs.angular_velocity = randf_range(-7.0, 7.0)
	legs.initial_scale = 0.38
	legs.lifetime = 2.4
	legs.fade_after = 0.7
	legs.drag = 0.03
	get_parent().add_child(legs)
	for i in 6:
		var puff := BodyChunkScene.instantiate()
		puff.texture = StuffingTexture
		puff.global_position = global_position
		puff.velocity = Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * randf_range(160.0, 340.0)
		puff.angular_velocity = randf_range(-12.0, 12.0)
		puff.initial_scale = randf_range(0.45, 1.05)
		puff.lifetime = randf_range(2.0, 3.2)
		puff.fade_after = 0.7
		puff.drag = 0.025
		get_parent().add_child(puff)
	queue_free()

func _process_death(delta: float) -> void:
	_death_time += delta
	# fall over (rotate to horizontal)
	if _death_time <= DEATH_FALL_DURATION:
		var t := _death_time / DEATH_FALL_DURATION
		rotation = lerp(0.0, deg_to_rad(90.0), t)
	else:
		rotation = deg_to_rad(90.0)
		var fade_t := (_death_time - DEATH_FALL_DURATION) / DEATH_FADE_DURATION
		# vibrate
		position = _death_origin + Vector2(
			randf_range(-3.0, 3.0),
			randf_range(-3.0, 3.0)
		)
		# fade
		var a: float = clamp(1.0 - fade_t, 0.0, 1.0)
		modulate = Color(1, 1, 1, a)
		if fade_t >= 1.0:
			queue_free()
