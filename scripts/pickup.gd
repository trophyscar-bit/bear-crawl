extends Area2D

@export var heal_amount: int = 1
@export var full_heal: bool = false
@export var bob_speed: float = 2.4
@export var bob_amount: float = 4.0
@export var spin_speed: float = 0.8

var _t: float = 0.0
var _base_y: float = 0.0
var _consumed: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_base_y = position.y
	# pick up immediately if the player already overlaps the orb at spawn
	call_deferred("_check_initial_overlap")

func _check_initial_overlap() -> void:
	if _consumed:
		return
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			_on_body_entered(body)
			return

func _process(delta: float) -> void:
	_t += delta
	var p := get_tree().get_first_node_in_group("player")
	if DevState.auto_pickup:
		if p is Node2D:
			position = position.move_toward((p as Node2D).global_position, 700.0 * delta)
			_base_y = position.y
			return
	# Pizza Magnet boon — pull pickups within range
	if RunState.has_pizza_magnet() and p is Node2D:
		var d: float = position.distance_to((p as Node2D).global_position)
		if d < 240.0:
			position = position.move_toward((p as Node2D).global_position, 360.0 * delta)
			_base_y = position.y
			return
	position.y = _base_y + sin(_t * bob_speed) * bob_amount
	rotation += delta * spin_speed

func _on_body_entered(body: Node) -> void:
	if _consumed:
		return
	if not body.is_in_group("player"):
		return
	if not body.has_method("heal"):
		return
	if full_heal:
		body.heal(body.get("max_health"))
	else:
		body.heal(heal_amount)
		# Stack bonus: every 5th health orb grants a permanent +1 max HP for this run.
		if RunState.add_pickup_stack("health"):
			if body.has_method("grant_stack_bonus_max_hp"):
				body.grant_stack_bonus_max_hp(1)
	_consumed = true
	queue_free()
