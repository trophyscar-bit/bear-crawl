extends Area2D

@export var speed: float = 520.0
@export var lifetime: float = 1.6
@export var damage: int = 1
@export var spin_speed: float = 28.0

var direction: Vector2 = Vector2.RIGHT
var _age: float = 0.0
var _consumed: bool = false
var _ff_grace: float = 0.1   # ignore enemies briefly so we don't hit the shooter

func _ready() -> void:
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	direction = direction.normalized()
	rotation = direction.angle()
	set_collision_mask_value(1, true)   # walls
	set_collision_mask_value(3, true)   # enemies (friendly fire)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if _consumed:
		return
	if _ff_grace > 0.0:
		_ff_grace -= delta
	position += direction * speed * delta
	rotation += spin_speed * delta
	_age += delta
	if _age >= lifetime:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if _consumed:
		return
	if body.is_in_group("projectile_passable"):
		return
	if body.is_in_group("enemies"):
		if _ff_grace > 0.0:
			return                    # just left the shooter — ignore
		if body.has_method("take_damage"):
			body.take_damage(damage)  # friendly fire
		_consumed = true
		queue_free()
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		_consumed = true
		queue_free()
		return
	# walls and cylinders just destroy the star
	_consumed = true
	queue_free()
