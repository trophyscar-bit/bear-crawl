extends "res://scripts/critter.gd"

# Teddy Bear — a suicide bomber that lies in wait. It creeps until it gets LINE OF
# SIGHT on you; then it lights up (flashing) and RUSHES fast. Dies in one hit but
# detonates a big blast — kill it at range or get clear.

@export var blast_radius: float = 315.0   # +25% bigger blast
@export var blast_damage: int = 4
var _flash_t: float = 0.0
var _activated: bool = false
var _fast_speed: float = 0.0

func _ready() -> void:
	super._ready()
	_fast_speed = speed     # the fast rush speed from the scene
	speed = 26.0            # just creeps until it spots you

func _physics_process(delta: float) -> void:
	# Stay dormant (slow, no flashing) until it has line of sight on the player.
	if not _dying and not _activated and is_instance_valid(player):
		if _has_los_to_player() and not (ArpgState.active and ArpgState.in_spawn_grace()):
			_activated = true
			speed = _fast_speed
	super._physics_process(delta)   # chase at current speed
	if _dying:
		return
	if _activated:
		# Pulse between hot-red and warning-yellow now that it's armed.
		_flash_t += delta
		if is_instance_valid(_rig):
			var hot: bool = int(_flash_t * 10.0) % 2 == 0
			_rig.modulate = Color(1.9, 0.35, 0.3) if hot else Color(1.95, 1.65, 0.35)
	elif is_instance_valid(_rig):
		_rig.modulate = Color(1, 1, 1)

func _begin_death() -> void:
	if not _dying:
		_detonate()
	super._begin_death()

func _detonate() -> void:
	var ex := ExplosionScene.instantiate()
	(ex as Node2D).global_position = global_position
	ex.set("end_scale", (blast_radius / 42.0) * 0.85)   # 15% smaller blast visual (radius/damage unchanged)
	ex.set("duration", 0.55)
	(ex as CanvasItem).modulate = Color(1.0, 0.55, 0.3, 1.0)
	get_parent().add_child(ex)
	var p := get_tree().get_first_node_in_group("player")
	if p != null and is_instance_valid(p) \
			and (p as Node2D).global_position.distance_to(global_position) <= blast_radius \
			and p.has_method("take_damage"):
		p.take_damage(blast_damage, true)   # dramatic blood spray — it's a point-blank blast
	# Friendly fire — the blast strips 99% of any mob's HP in range (near-kills the
	# whole crowd; lure bombers into a pack and watch it clear).
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or not is_instance_valid(e):
			continue
		if (e as Node2D).global_position.distance_to(global_position) <= blast_radius \
				and e.has_method("take_damage"):
			var hp: float = float(e.get("health")) if "health" in e else 1.0
			e.take_damage(maxi(1, int(ceil(hp * 0.99))))
	Juice.shake(0.45)
