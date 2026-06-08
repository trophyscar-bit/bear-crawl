extends Node2D

# Forward-facing shockwave the final boss blows when he stops sprinting.
# Expanding wedge of dust that damages the player if caught in the cone.

@export var direction: Vector2 = Vector2.RIGHT
@export var max_range: float = 230.0
@export var arc_deg: float = 70.0
@export var damage: int = 1
@export var duration: float = 0.5
@export var damage_at: float = 0.18  # ratio of duration when the hit registers

@onready var outer: Polygon2D = $Outer
@onready var inner: Polygon2D = $Inner

var _t: float = 0.0
var _damaged: bool = false

func _ready() -> void:
	direction = direction.normalized()
	rotation = direction.angle()
	_build_wedge()

func _build_wedge() -> void:
	var n: int = 24
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	var half: float = deg_to_rad(arc_deg / 2.0)
	for i in n + 1:
		var a: float = lerp(-half, half, float(i) / float(n))
		pts.append(Vector2(cos(a), sin(a)))
	outer.polygon = pts
	outer.color = Color(0.96, 0.95, 0.90, 0.55)
	inner.polygon = pts
	inner.color = Color(0.75, 0.72, 0.65, 0.75)
	inner.scale = Vector2(0.68, 0.68)

func _process(delta: float) -> void:
	_t += delta
	var p: float = clamp(_t / duration, 0.0, 1.0)
	# Expand the whole node — children are unit-sized so this scales the wedge
	var s: float = max_range * p
	scale = Vector2(s, s)
	modulate.a = 1.0 - p
	if not _damaged and p >= damage_at:
		_damaged = true
		_check_player_hit()
	if _t >= duration:
		queue_free()

func _check_player_hit() -> void:
	var pl := get_tree().get_first_node_in_group("player")
	if not (pl is Node2D):
		return
	var off: Vector2 = (pl as Node2D).global_position - global_position
	if off.length() > max_range:
		return
	if off.normalized().dot(direction) < cos(deg_to_rad(arc_deg / 2.0)):
		return
	if pl.has_method("take_damage"):
		pl.take_damage(damage)
	# Small shake for the gust
	if pl.has_method("shake"):
		pl.shake(8.0, 0.18)
