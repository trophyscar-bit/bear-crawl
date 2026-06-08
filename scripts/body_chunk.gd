extends Sprite2D

@export var velocity: Vector2 = Vector2.ZERO
@export var angular_velocity: float = 0.0
@export var lifetime: float = 1.4
@export var initial_scale: float = 1.0
@export var drag: float = 0.04  # per-frame velocity scale-down
@export var gravity: float = 220.0
@export var fade_after: float = 0.55  # ratio of lifetime when alpha starts fading

var _t: float = 0.0

func _ready() -> void:
	scale = Vector2(initial_scale, initial_scale)

func _process(delta: float) -> void:
	_t += delta
	position += velocity * delta
	velocity.y += gravity * delta  # gentle gravity so stuff arcs back down
	velocity *= (1.0 - drag)
	rotation += angular_velocity * delta
	var ratio: float = _t / lifetime
	if ratio > fade_after:
		modulate.a = clamp(1.0 - (ratio - fade_after) / (1.0 - fade_after), 0.0, 1.0)
	if _t >= lifetime:
		queue_free()
