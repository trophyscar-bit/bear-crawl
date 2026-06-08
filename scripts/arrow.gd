extends Area2D

# Fast arrow fired by the Growler archer. Rotates to face its travel direction,
# dies on walls, damages the player. Faster than the other enemy projectiles.

@export var direction: Vector2 = Vector2.RIGHT
@export var speed: float = 760.0
@export var damage: int = 1
@export var lifetime: float = 2.2

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
	# Faint glow so the arrow reads in dark rooms.
	if not (ArpgState.active and ArpgState.no_projectile_glow):
		var gl := PointLight2D.new()
		if ResourceLoader.exists("res://assets/light_radial.png"):
			gl.texture = load("res://assets/light_radial.png") as Texture2D
		gl.color = Color(1.0, 0.85, 0.55)
		gl.energy = 0.35
		gl.texture_scale = 0.3
		add_child(gl)

func _physics_process(delta: float) -> void:
	if _consumed:
		return
	if _ff_grace > 0.0:
		_ff_grace -= delta
	position += direction * speed * delta
	_age += delta
	if _age >= lifetime:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if _consumed:
		return
	if body.is_in_group("walls"):
		_consumed = true
		queue_free()
		return
	if body.is_in_group("enemies"):
		if _ff_grace > 0.0:
			return
		if body.has_method("take_damage"):
			body.take_damage(damage)   # friendly fire
		_consumed = true
		queue_free()
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		_consumed = true
		queue_free()
