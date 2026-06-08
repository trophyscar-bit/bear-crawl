extends "res://scripts/critter.gd"

# Frost Cub — a floating balloon bear that drifts toward you and lobs a slow,
# corkscrewing FROST ORB that freezes you for a second if it catches you.

const FrostOrb := preload("res://scenes/frost_orb.tscn")
var _shoot_t: float = 0.0

func _ready() -> void:
	super._ready()
	_shoot_t = randf_range(1.4, 2.8)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)   # slow float-chase + bob
	if _dying or not is_instance_valid(player):
		return
	if ArpgState.active and ArpgState.in_spawn_grace():
		return
	_shoot_t -= delta
	var d: float = global_position.distance_to((player as Node2D).global_position)
	if _shoot_t <= 0.0 and d < 620.0 and _has_los_to_player():
		_shoot_t = 3.0 + randf_range(-0.4, 0.6)
		var dir: Vector2 = ((player as Node2D).global_position - global_position).normalized()
		var o := FrostOrb.instantiate()
		o.global_position = global_position
		o.set("direction", dir)
		get_parent().add_child(o)
