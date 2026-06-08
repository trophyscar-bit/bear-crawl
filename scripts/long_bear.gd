extends "res://scripts/critter.gd"

# Long Bear — a crawling blocker. It doesn't attack directly; it tries to cut you
# off by heading for a point AHEAD of your movement, laying an ACID TRAIL that
# damages you if you cross it. Good at clogging chokepoints.

const AcidScene := preload("res://scenes/acid_patch.tscn")
var _acid_t: float = 0.0

const STANDOFF: float = 215.0    # the ring he tries to hold around you
var _orbit: float = 0.0          # idle sweep so he keeps crawling when you stop
var _facing_dir: Vector2 = Vector2.RIGHT
var _crawl_t: float = 0.0        # inchworm squish phase

func _physics_process(delta: float) -> void:
	if _dying:
		super._physics_process(delta)
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
	var ppos: Vector2 = (player as Node2D).global_position
	var pv: Vector2 = Vector2.ZERO
	if "velocity" in player:
		pv = player.velocity
	# Where he wants to be: a spot on the standoff ring, OUT IN FRONT of where you're
	# headed (or, if you're standing still, slowly sweeping around you). The target
	# keeps moving, so he's always smoothly crawling — never the jerky "you stop, he
	# stops" freeze.
	var head: Vector2
	if pv.length() > 25.0:
		head = pv.normalized()
		_facing_dir = head
	else:
		_orbit += delta * 0.9
		head = Vector2.from_angle(_orbit)
	var desired_pos: Vector2 = ppos + head * STANDOFF
	var to_desired: Vector2 = desired_pos - global_position
	var target_vel: Vector2
	if to_desired.length() < 42.0:
		# In position — glide sideways along the ring so he keeps creeping, laying acid.
		var tangent := Vector2(-head.y, head.x)
		target_vel = tangent * speed * 0.6
	else:
		target_vel = to_desired.normalized() * speed
	# Smoothed momentum (no instant velocity snaps) = organic crawl.
	velocity = velocity.lerp(target_vel, 5.0 * delta)
	move_and_slide()
	# Crawl squish — inchworm along his length: stretch long+thin, then pull in
	# short+fat, scaled by how fast he's actually moving (like the player's squish).
	if is_instance_valid(_rig):
		var moving: float = clampf(velocity.length() / maxf(speed, 1.0), 0.0, 1.0)
		_crawl_t += delta * (5.0 + moving * 7.0)
		var amp: float = 0.18 * moving
		var face: float = 1.0
		if absf(velocity.x) > 4.0:
			face = 1.0 if velocity.x > 0.0 else -1.0
		elif _facing_dir.x < 0.0:
			face = -1.0
		var wobble: float = sin(_crawl_t)
		_rig.scale = Vector2(rig_scale * (1.0 + wobble * amp) * face, rig_scale * (1.0 - wobble * amp * 0.7))
	# Lay the acid trail as he crawls.
	_acid_t -= delta
	if _acid_t <= 0.0:
		_acid_t = 0.32
		var a := AcidScene.instantiate()
		a.global_position = global_position
		get_parent().add_child(a)
