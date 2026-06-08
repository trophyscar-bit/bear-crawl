extends Area2D

# Saw blade that slides back and forth along a fixed axis. Always dangerous.
# Damages anything overlapping on a tick. Smart enemies steer around it.

@export var travel_distance: float = 340.0
@export var speed: float = 230.0
@export var direction_angle_deg: float = 0.0  # 0 = horizontal, 90 = vertical
@export var damage: int = 1
@export var damage_interval: float = 0.4
@export var spin_speed: float = 28.0
@export var redirect_chance: float = 0.45  # chance at each end to pick a new random direction

var _origin: Vector2
var _direction: Vector2
var _offset: float = 0.0
var _moving_forward: bool = true
var _damage_timer: float = 0.0

@onready var blade: Node2D = $Blade

func _ready() -> void:
	add_to_group("hazards")
	_origin = position
	_direction = Vector2.from_angle(deg_to_rad(direction_angle_deg))
	_offset = randf_range(-travel_distance / 2.0, travel_distance / 2.0)
	_moving_forward = randf() > 0.5
	_update_position()

func _process(delta: float) -> void:
	var d: float = speed * delta * (1.0 if _moving_forward else -1.0)
	_offset += d
	if _offset >= travel_distance / 2.0:
		_offset = travel_distance / 2.0
		_moving_forward = false
		_maybe_redirect()
	elif _offset <= -travel_distance / 2.0:
		_offset = -travel_distance / 2.0
		_moving_forward = true
		_maybe_redirect()
	_update_position()
	if blade:
		blade.rotation += spin_speed * delta
	_damage_timer -= delta
	if _damage_timer <= 0.0:
		_damage_timer = damage_interval
		_hurt_overlapping()

func _update_position() -> void:
	position = _origin + _direction * _offset

func _hurt_overlapping() -> void:
	for body in get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(damage)

func is_dangerous() -> bool:
	return true

func _maybe_redirect() -> void:
	# At each end-of-sweep, randomly rotate the travel axis. Makes the saw
	# feel less predictable instead of repeating the same line forever.
	if randf() > redirect_chance:
		return
	# Pick any of 8 random directions (every 45°)
	var angle_deg: float = float(randi() % 8) * 45.0
	_direction = Vector2.from_angle(deg_to_rad(angle_deg))
	# also pick a fresh starting offset so the new sweep isn't anchored to old position
	_origin = global_position
	_offset = 0.0
