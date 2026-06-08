extends Area2D

# A thrown pizza bomb. Travels briefly, lands on first solid impact (wall,
# cylinder, enemy), then fuses for `fuse_time` seconds before exploding in
# an AOE that damages any enemies inside.

const ExplosionScene := preload("res://scenes/explosion.tscn")

@export var travel_distance: float = 230.0
@export var speed: float = 460.0
@export var fuse_time: float = 0.5
@export var damage: int = 2
@export var aoe_radius: float = 110.0

var direction: Vector2 = Vector2.RIGHT
var _start_pos: Vector2 = Vector2.ZERO
var _distance_traveled: float = 0.0
var _landed: bool = false
var _fuse_remaining: float = 0.0
var _consumed: bool = false

func _ready() -> void:
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	direction = direction.normalized()
	rotation = direction.angle()
	_start_pos = position
	body_entered.connect(_on_body_entered)
	# Trash enemies on layer 3, face boss on layer 4 — mask both.
	set_collision_mask_value(3, true)
	set_collision_mask_value(4, true)

func _physics_process(delta: float) -> void:
	if _consumed:
		return
	if _landed:
		_fuse_remaining -= delta
		# blink rate ramps up as the fuse runs down
		var t: float = clamp(1.0 - (_fuse_remaining / fuse_time), 0.0, 1.0)
		var blink_hz: float = 6.0 + 30.0 * t
		var phase: float = sin(get_ticks() * blink_hz)
		modulate = Color(1, 1, 1) if phase > 0.0 else Color(1, 0.45, 0.35)
		if _fuse_remaining <= 0.0:
			_explode()
		return
	var step: float = speed * delta
	position += direction * step
	rotation += 14.0 * delta
	_distance_traveled += step
	if _distance_traveled >= travel_distance:
		_land()

func get_ticks() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

func _on_body_entered(body: Node) -> void:
	if _landed or _consumed:
		return
	if body.is_in_group("player"):
		return
	if body.is_in_group("projectile_passable"):
		return  # bombs sail over ponds too
	# wall/cylinder/enemy — stop here and start the fuse
	_land()

func _land() -> void:
	if _landed:
		return
	_landed = true
	_fuse_remaining = fuse_time

func _explode() -> void:
	_consumed = true
	# damage every enemy in the AOE
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node2D):
			continue
		if (e as Node2D).global_position.distance_to(global_position) <= aoe_radius:
			if e.has_method("take_damage"):
				e.take_damage(damage)
	# visual: scaled-up explosion
	var ex := ExplosionScene.instantiate()
	ex.global_position = global_position
	(ex as Node).set("end_scale", 3.6)
	(ex as Node).set("duration", 0.6)
	get_parent().add_child(ex)
	# small camera shake
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("shake"):
		p.shake(10.0, 0.22)
	queue_free()
