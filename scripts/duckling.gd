extends "res://scripts/critter.gd"

# Duckling — a fast little swarmer that darts in and SPITS a 3-pellet quack-burst
# at you from short range, then keeps harassing.

const Pellet := preload("res://scenes/enemy_pellet.tscn")
var _shoot_t: float = 0.0

func _ready() -> void:
	super._ready()
	_shoot_t = randf_range(1.0, 2.2)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)   # fast chase/swarm
	if _dying or not is_instance_valid(player):
		return
	if ArpgState.active and ArpgState.in_spawn_grace():
		return
	_shoot_t -= delta
	var d: float = global_position.distance_to((player as Node2D).global_position)
	if _shoot_t <= 0.0 and d < 430.0 and _has_los_to_player():
		_shoot_t = 2.2 + randf_range(-0.3, 0.5)
		var dir: Vector2 = ((player as Node2D).global_position - global_position).normalized()
		for off in [-0.22, 0.0, 0.22]:
			var p := Pellet.instantiate()
			p.global_position = global_position + dir * 12.0
			p.set("direction", dir.rotated(off))
			p.set("speed", 250.0)
			get_parent().add_child(p)
