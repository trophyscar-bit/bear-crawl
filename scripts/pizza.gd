extends Area2D

@export var speed: float = 600.0
@export var lifetime: float = 1.4
@export var damage: int = 1
@export var spin_speed: float = 14.0
@export var hostile: bool = false  # false = thrown by player; true = thrown at player
@export var max_distance_after_bounce: float = 720.0  # half a room width (overridable per-instance)
@export var homing: bool = false
@export var homing_turn_rate: float = 5.5  # rad/sec — how aggressively pizza chases nearest enemy
@export var max_bounces: int = 1
@export var burst_on_impact: bool = false
@export var apply_burn: bool = false
@export var pierce: int = 0  # how many additional enemies the pizza passes through

const ExplosionScene := preload("res://scenes/explosion.tscn")

const BURST_RADIUS: float = 78.0
const BURN_DPS: int = 1
const BURN_DURATION: float = 3.0

var direction: Vector2 = Vector2.RIGHT
var _age: float = 0.0
var _consumed: bool = false
var _bounces_done: int = 0
var _post_bounce_distance: float = 0.0
var _wall_grace: float = 0.0   # brief window after a bounce where walls are ignored
var _hit_ids: Dictionary = {}  # enemy instance_ids already damaged by this pizza

func _ready() -> void:
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	direction = direction.normalized()
	rotation = direction.angle()
	body_entered.connect(_on_body_entered)
	# Trash enemies live on layer 3, face boss on layer 4 — mask both.
	set_collision_mask_value(3, true)
	set_collision_mask_value(4, true)

func _physics_process(delta: float) -> void:
	if _consumed:
		return
	if homing and not hostile:
		var target := _find_nearest_enemy()
		if target:
			var to_t: Vector2 = ((target as Node2D).global_position - global_position).normalized()
			var t_angle: float = to_t.angle()
			var cur_angle: float = direction.angle()
			var new_angle: float = lerp_angle(cur_angle, t_angle, clamp(homing_turn_rate * delta, 0.0, 1.0))
			direction = Vector2.RIGHT.rotated(new_angle)
	if _wall_grace > 0.0:
		_wall_grace -= delta
	var travel: float = speed * delta
	position += direction * travel
	rotation += spin_speed * delta
	_age += delta
	if hostile:
		var hue: float = fposmod(_age * 2.5, 1.0)
		modulate = Color.from_hsv(hue, 0.9, 1.0)
	if _age >= lifetime:
		queue_free()
		return
	if _bounces_done > 0:
		_post_bounce_distance += travel
		if _post_bounce_distance >= max_distance_after_bounce:
			queue_free()

func _pop_burst() -> void:
	var ex := ExplosionScene.instantiate()
	ex.global_position = global_position
	(ex as Node).set("end_scale", 2.0)
	(ex as Node).set("duration", 0.4)
	get_parent().add_child(ex)
	# splash damage to nearby enemies (minus the primary target, but harmless dupes are OK)
	var splash: int = max(1, int(round(float(damage) * 0.75)))
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node2D):
			continue
		if (e as Node2D).global_position.distance_to(global_position) <= BURST_RADIUS:
			if e.has_method("take_damage"):
				e.take_damage(splash)

func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node2D):
			continue
		var d: float = (e as Node2D).global_position.distance_to(global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e as Node2D
	return nearest

func _wall_normal(body: Node) -> Vector2:
	# Arena walls carry a flip_axis hint; dungeon blocks don't, so derive the
	# struck face from which axis the pizza is most offset on.
	var axis: String = body.get_meta("flip_axis", "")
	if axis == "x":
		return Vector2(1, 0)
	if axis == "y":
		return Vector2(0, 1)
	if body is Node2D:
		var off: Vector2 = global_position - (body as Node2D).global_position
		if abs(off.x) >= abs(off.y):
			return Vector2(signf(off.x), 0.0) if off.x != 0.0 else Vector2(1, 0)
		return Vector2(0.0, signf(off.y))
	return -direction

func _on_body_entered(body: Node) -> void:
	if _consumed:
		return
	# Pizzas fly OVER lakes / projectile-passable obstacles.
	if body.is_in_group("projectile_passable"):
		return
	# Walls bounce up to `max_bounces` times, then destroy.
	if body.is_in_group("walls"):
		# Just bounced off a wall (or spawned hugging one) — ignore walls for a
		# beat so we don't get absorbed by a double-hit on the same corner.
		if _wall_grace > 0.0:
			return
		if _bounces_done < max_bounces:
			# Reflect off the wall's actual normal so glancing hits ricochet
			# FORWARD along the wall (only a head-on hit reverses).
			var n: Vector2 = _wall_normal(body)
			direction = (direction - 2.0 * direction.dot(n) * n).normalized()
			rotation = direction.angle()
			# Shove out of the wall along the new heading so we clear it.
			position += direction * 26.0
			_wall_grace = 0.08
			_bounces_done += 1
			_post_bounce_distance = 0.0
			speed *= 1.05
			return
		_consumed = true
		queue_free()
		return
	# Friendly pizza (player threw it): ignore player, damage enemies.
	# Hostile pizza (boss threw it): ignore enemies, damage player.
	if not hostile:
		if body.is_in_group("player"):
			return
		if body.is_in_group("enemies") and body.has_method("take_damage"):
			var id: int = body.get_instance_id()
			if _hit_ids.has(id):
				return  # already hit this one (pierced)
			_hit_ids[id] = true
			body.take_damage(damage)
			if apply_burn and body.has_method("apply_burn"):
				body.apply_burn(BURN_DPS, BURN_DURATION)
			if burst_on_impact:
				_pop_burst()
			if pierce > 0:
				pierce -= 1
				return  # keep flying
			_consumed = true
			queue_free()
			return
	else:
		if body.is_in_group("enemies"):
			return
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(damage)
			_consumed = true
			queue_free()
			return
	# Cylinder or other obstacle: destroyed.
	_consumed = true
	queue_free()
