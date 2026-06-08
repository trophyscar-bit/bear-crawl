extends Area2D

# Pulsing on/off floor hazard. Cycles OFF -> TELEGRAPH (warning) -> ON (damage) -> OFF.
# Damages anything inside when ON. Enemies steer away from it when ON or telegraphing.

@export var off_duration: float = 2.1
@export var telegraph_duration: float = 0.55
@export var on_duration: float = 1.2
@export var damage: int = 1
@export var damage_interval: float = 0.8  # less punishing tick rate when standing in zone (was 0.5)

# While ON, periodically emit a randomised-radius AOE shockwave. Less frequent
# and smaller than before — they're a flourish, not a constant gut-punch.
@export var burst_interval: float = 1.3
@export var burst_min_radius: float = 65.0
@export var burst_max_radius: float = 100.0
@export var burst_damage: int = 1

@onready var outer: Polygon2D = $Outer
@onready var inner: Polygon2D = $Inner

enum State { OFF, TELEGRAPH, ON }

const COLOR_OFF_OUTER := Color(0.34, 0.10, 0.08, 0.55)
const COLOR_OFF_INNER := Color(0.55, 0.18, 0.14, 0.55)
const COLOR_TELE_OUTER := Color(1.0, 0.85, 0.25, 0.85)
const COLOR_TELE_INNER := Color(1.0, 0.95, 0.45, 0.95)
const COLOR_ON_OUTER := Color(1.0, 0.35, 0.18, 0.97)
const COLOR_ON_INNER := Color(1.0, 0.80, 0.30, 0.97)

var state: int = State.OFF
var _state_time: float = 0.0
var _damage_timer: float = 0.0
var _pulse_t: float = 0.0
var _burst_timer: float = 0.0

func _ready() -> void:
	add_to_group("hazards")
	# stagger initial state per-instance
	_state_time = randf() * off_duration
	_apply_visuals()

func _process(delta: float) -> void:
	_state_time += delta
	_pulse_t += delta
	match state:
		State.OFF:
			if _state_time >= off_duration:
				state = State.TELEGRAPH
				_state_time = 0.0
				_apply_visuals()
		State.TELEGRAPH:
			# fast yellow blink as the warning intensifies
			var blink: float = 0.6 + 0.4 * abs(sin(_pulse_t * 28.0))
			outer.modulate = Color(1, 1, 1, blink)
			inner.modulate = Color(1, 1, 1, blink)
			if _state_time >= telegraph_duration:
				state = State.ON
				_state_time = 0.0
				_damage_timer = 0.0
				_apply_visuals()
				_hurt_overlapping()
		State.ON:
			if _state_time >= on_duration:
				state = State.OFF
				_state_time = 0.0
				_apply_visuals()
				return
			_damage_timer -= delta
			if _damage_timer <= 0.0:
				_damage_timer = damage_interval
				_hurt_overlapping()
			_burst_timer -= delta
			if _burst_timer <= 0.0:
				_burst_timer = burst_interval + randf_range(-0.18, 0.18)
				_fire_burst()
			var pulse: float = 0.85 + 0.15 * sin(_pulse_t * 12.0)
			outer.modulate = Color(1, 1, 1, pulse)
			inner.modulate = Color(1, 1, 1, pulse)

func _apply_visuals() -> void:
	match state:
		State.OFF:
			outer.color = COLOR_OFF_OUTER
			inner.color = COLOR_OFF_INNER
		State.TELEGRAPH:
			outer.color = COLOR_TELE_OUTER
			inner.color = COLOR_TELE_INNER
		State.ON:
			outer.color = COLOR_ON_OUTER
			inner.color = COLOR_ON_INNER
	outer.modulate = Color(1, 1, 1, 1)
	inner.modulate = Color(1, 1, 1, 1)

func _hurt_overlapping() -> void:
	for body in get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(damage)

func _fire_burst() -> void:
	var radius: float = randf_range(burst_min_radius, burst_max_radius)
	# Damage by distance — hits player + enemies
	var p := get_tree().get_first_node_in_group("player")
	if p and is_instance_valid(p) and p.has_method("take_damage"):
		if (p as Node2D).global_position.distance_to(global_position) <= radius:
			p.take_damage(burst_damage)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if not (e is Node2D):
			continue
		if (e as Node2D).global_position.distance_to(global_position) <= radius:
			if e.has_method("take_damage"):
				e.take_damage(burst_damage)
	_spawn_burst_ring(radius)

func _spawn_burst_ring(radius: float) -> void:
	# Expanding outlined ring + fade — purely visual feedback.
	var ring := Line2D.new()
	var n: int = 36
	var pts := PackedVector2Array()
	for i in n + 1:
		var ang: float = float(i) / n * TAU
		pts.append(Vector2(cos(ang), sin(ang)))  # unit circle
	ring.points = pts
	ring.width = 4.0
	ring.default_color = Color(1, 0.55, 0.25, 0.95)
	ring.scale = Vector2(8.0, 8.0)
	ring.global_position = global_position
	ring.z_index = 5
	get_parent().add_child(ring)
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(radius, radius), 0.38)
	tw.tween_property(ring, "modulate:a", 0.0, 0.38)
	tw.chain().tween_callback(ring.queue_free)

func is_dangerous() -> bool:
	return state != State.OFF
