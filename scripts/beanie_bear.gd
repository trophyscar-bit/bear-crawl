extends "res://scripts/critter.gd"

# Beanie Bear — chases, and throws spinning beanies at you from range.

const BeanieProj := preload("res://scenes/beanie_proj.tscn")
var _shoot_t: float = 0.0

func _ready() -> void:
	super._ready()
	_shoot_t = randf_range(1.0, 2.4)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)   # base chase + facing
	if _dying or not is_instance_valid(player):
		return
	if ArpgState.active and ArpgState.in_spawn_grace():
		return
	_shoot_t -= delta
	var d: float = global_position.distance_to((player as Node2D).global_position)
	if _shoot_t <= 0.0 and d < 520.0 and _has_los_to_player():
		_shoot_t = 1.8 + randf_range(-0.3, 0.3)
		var dir: Vector2 = ((player as Node2D).global_position - global_position).normalized()
		var b := BeanieProj.instantiate()
		b.global_position = global_position + dir * 16.0
		b.set("direction", dir)
		get_parent().add_child(b)
