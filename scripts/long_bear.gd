extends "res://scripts/critter.gd"

# Long Bear — a crawling blocker. It doesn't attack directly; it tries to cut you
# off by heading for a point AHEAD of your movement, laying an ACID TRAIL that
# damages you if you cross it. Good at clogging chokepoints.

const AcidScene := preload("res://scenes/acid_patch.tscn")
var _acid_t: float = 0.0

const KEEP_DIST: float = 240.0   # never crowd the player — stay at least this far
const BLOCK_LEAD: float = 260.0  # how far ahead of the player to set up the roadblock

func _physics_process(delta: float) -> void:
	if _dying:
		super._physics_process(delta)
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
	var ppos: Vector2 = (player as Node2D).global_position
	var to_player: Vector2 = ppos - global_position
	var dist: float = to_player.length()
	var pv: Vector2 = Vector2.ZERO
	if "velocity" in player:
		pv = player.velocity
	var desired: Vector2 = Vector2.ZERO
	if dist < KEEP_DIST:
		# Too close — he is NOT an attacker. Peel away from the player.
		desired = -to_player.normalized()
	elif pv.length() > 30.0:
		# Player is on the move: slide ahead onto their path and clog it.
		var block: Vector2 = ppos + pv.normalized() * BLOCK_LEAD
		desired = (block - global_position).normalized()
	else:
		# Player idle: hold the line, just keep spacing. Don't creep in.
		desired = Vector2.ZERO
	velocity = desired * speed
	move_and_slide()
	if is_instance_valid(_rig) and absf(velocity.x) > 4.0:
		_rig.scale.x = absf(_rig.scale.x) * (1.0 if velocity.x > 0.0 else -1.0)
	# Lay the acid trail as he crawls into position.
	_acid_t -= delta
	if _acid_t <= 0.0:
		_acid_t = 0.32
		var a := AcidScene.instantiate()
		a.global_position = global_position
		get_parent().add_child(a)
