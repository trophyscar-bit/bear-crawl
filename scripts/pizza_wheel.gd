extends Area2D

# Orbital pizza slice. Spawned as child of player when Pizza Wheel boon is picked.
# Slowly spins around the player and damages enemies on contact.

@export var damage: int = 1
@export var radius: float = 86.0
@export var angular_speed: float = 3.2  # rad/sec

var _angle: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Trash enemies on layer 3, face boss on layer 4 — mask both.
	set_collision_mask_value(3, true)
	set_collision_mask_value(4, true)

func _process(delta: float) -> void:
	_angle += angular_speed * delta
	position = Vector2(cos(_angle), sin(_angle)) * radius
	rotation = _angle + PI / 2

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(damage)
