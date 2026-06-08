extends "res://scripts/critter.gd"

# Hound — a fast attack dog. Chases, then from mid-range it CROUCHES (telegraph)
# and POUNCES in a straight-line lunge, hitting you on contact, then recovers.

const LUNGE_SPEED: float = 575.0

enum State { CHASE, WINDUP, LUNGE, RECOVER }
var _state: int = State.CHASE
var _t: float = 0.0
var _cool: float = 0.0
var _lunge_dir: Vector2 = Vector2.RIGHT

func _ready() -> void:
	super._ready()
	_cool = randf_range(1.6, 2.8)
	# The shared contact shadow sits too low for the four-legged hound (he looks
	# like he's floating) — pull it up under his paws.
	var sh := get_node_or_null("DropShadow") as Node2D
	if sh != null:
		sh.position.y -= 26.0

func _physics_process(delta: float) -> void:
	if _dying:
		super._physics_process(delta)
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if not is_instance_valid(player):
			return
	var ppos: Vector2 = (player as Node2D).global_position
	match _state:
		State.CHASE:
			super._physics_process(delta)   # normal fast chase
			_cool -= delta
			var d: float = global_position.distance_to(ppos)
			if _cool <= 0.0 and d > 110.0 and d < 380.0 and _has_los_to_player():
				if not (ArpgState.active and ArpgState.in_spawn_grace()):
					_state = State.WINDUP
					_t = 0.32
					_lunge_dir = (ppos - global_position).normalized()
					if is_instance_valid(_rig):
						_rig.modulate = Color(1.5, 0.75, 0.75)   # crouch tell
		State.WINDUP:
			velocity = velocity.lerp(Vector2.ZERO, 0.3)
			move_and_slide()
			_lunge_dir = (ppos - global_position).normalized()   # track until launch
			_t -= delta
			if _t <= 0.0:
				_state = State.LUNGE
				_t = 0.28
				if is_instance_valid(_rig):
					_rig.modulate = Color(1, 1, 1)
		State.LUNGE:
			velocity = _lunge_dir * LUNGE_SPEED
			move_and_slide()
			if is_instance_valid(_rig) and absf(velocity.x) > 4.0:
				_rig.scale.x = absf(_rig.scale.x) * (1.0 if velocity.x > 0.0 else -1.0)
			_t -= delta
			if _t <= 0.0:
				_state = State.RECOVER
				_t = 0.42
		State.RECOVER:
			velocity = velocity.lerp(Vector2.ZERO, 0.2)
			move_and_slide()
			_t -= delta
			if _t <= 0.0:
				_state = State.CHASE
				_cool = randf_range(2.2, 3.4)
