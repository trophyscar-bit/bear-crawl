extends "res://scripts/critter.gd"

# Army Bear (BOSS) — keeps his distance and radios in AIRSTRIKE clusters. When you
# close in he backs off / strafes to deny you a clean angle, then calls a 3-4 hit
# telegraphed strike pattern that leads your movement.

const StrikeScene := preload("res://scenes/ground_slam.tscn")
var _strike_t: float = 0.0

func _ready() -> void:
	super._ready()
	_strike_t = randf_range(2.5, 4.0)

func _physics_process(delta: float) -> void:
	if _dying:
		super._physics_process(delta)
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
	var to: Vector2 = (player as Node2D).global_position - global_position
	var d: float = to.length()
	var desired: Vector2
	if d < 340.0:
		desired = -to.normalized()                       # too close — back off
	elif d > 490.0:
		desired = to.normalized()                        # reposition closer
	else:
		desired = Vector2(-to.y, to.x).normalized() * 0.65   # strafe to deny the angle
	velocity = desired * speed
	move_and_slide()
	if is_instance_valid(_rig) and absf(to.x) > 1.0:
		_rig.scale.x = absf(_rig.scale.x) * (1.0 if to.x > 0.0 else -1.0)
	if ArpgState.active and ArpgState.in_spawn_grace():
		return
	_strike_t -= delta
	if _strike_t <= 0.0 and _has_los_to_player():
		_strike_t = 5.5 + randf_range(-0.5, 1.0)
		_call_airstrike()

func _call_airstrike() -> void:
	if not is_instance_valid(player):
		return
	var pv: Vector2 = Vector2.ZERO
	if "velocity" in player:
		pv = player.velocity
	var base: Vector2 = (player as Node2D).global_position
	# 4 staggered strikes that march along the player's heading.
	for i in 4:
		var off: Vector2 = pv * float(i) * 0.18 + Vector2(randf_range(-50, 50), randf_range(-50, 50))
		var pos: Vector2 = base + off
		get_tree().create_timer(0.35 * float(i)).timeout.connect(_spawn_strike.bind(pos))

func _spawn_strike(pos: Vector2) -> void:
	var s := StrikeScene.instantiate()
	s.global_position = pos
	s.set("radius", 86.0)
	s.set("windup", 0.85)
	s.set("damage", 2)
	get_parent().add_child(s)
