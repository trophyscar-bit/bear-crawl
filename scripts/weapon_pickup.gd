extends Area2D

# Generic special-weapon pickup. Three scenes use this: bomb / scatter / homing.

@export var weapon_type: String = "bomb"
@export var charges: int = 4
@export var bob_speed: float = 2.4
@export var bob_amount: float = 4.0
@export var spin_speed: float = 0.6

var _t: float = 0.0
var _base_y: float = 0.0
var _consumed: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_base_y = position.y
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
	if not body.has_method("grant_special"):
		return
	var grant_count: int = charges
	# Stack bonus: every 5th pickup of the same type grants double charges.
	if RunState.add_pickup_stack(weapon_type):
		grant_count = charges * 2
	body.grant_special(weapon_type, grant_count)
	_consumed = true
	queue_free()
