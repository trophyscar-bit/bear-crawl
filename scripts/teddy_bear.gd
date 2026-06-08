extends "res://scripts/critter.gd"

# Teddy Bear — a suicide bomber. Flashes a warning, rushes you FAST, dies in ONE
# hit… but detonates a big blast on death. Kill it at range or get clear, or you
# eat the explosion.

@export var blast_radius: float = 132.0
@export var blast_damage: int = 3
var _flash_t: float = 0.0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)   # fast chase
	if _dying:
		return
	# Pulse between hot-red and warning-yellow so the threat reads instantly.
	_flash_t += delta
	if is_instance_valid(_rig):
		var hot: bool = int(_flash_t * 9.0) % 2 == 0
		_rig.modulate = Color(1.8, 0.35, 0.3) if hot else Color(1.85, 1.6, 0.35)

func _begin_death() -> void:
	if not _dying:
		_detonate()
	super._begin_death()

func _detonate() -> void:
	var ex := ExplosionScene.instantiate()
	(ex as Node2D).global_position = global_position
	ex.set("end_scale", blast_radius / 55.0)
	ex.set("duration", 0.5)
	(ex as CanvasItem).modulate = Color(1.0, 0.55, 0.3, 1.0)
	get_parent().add_child(ex)
	# Anyone caught in the blast (the player) takes the hit.
	var p := get_tree().get_first_node_in_group("player")
	if p != null and is_instance_valid(p) \
			and (p as Node2D).global_position.distance_to(global_position) <= blast_radius \
			and p.has_method("take_damage"):
		p.take_damage(blast_damage)
	Juice.shake(0.3)
