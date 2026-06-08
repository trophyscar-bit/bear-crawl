extends Node2D

# AoE attack telegraph: pulsing yellow rings + rotating rune segments on the
# floor for `windup` seconds, then detonates — anyone inside takes damage
# and a 56-frame ring shockwave (BenHickling CC0) blows outward.

const ExplosionScene := preload("res://scenes/explosion.tscn")

# Ring shockwave: a 56-frame, 100x100/frame, 10x6 layout PNG.
const RING_SHEET_PATH := "res://assets/ring_shockwave.png"
const RING_FRAMES: int = 56
const RING_FRAME_SIZE: int = 100
const RING_HFRAMES: int = 10
const RING_VFRAMES: int = 6
const RING_DURATION: float = 0.55  # how long the 56 frames take to play

@export var radius: float = 110.0
@export var windup: float = 0.95
@export var damage: int = 1

var _t: float = 0.0
var _detonated: bool = false
@onready var ring: Line2D = $Ring
@onready var fill: Polygon2D = $Fill

# Extra procedural visual nodes built in _ready
var _inner_ring: Line2D = null      # smaller concentric ring
var _rune_holder: Node2D = null     # parent for rotating tick segments
var _rune_segments: Array = []      # of Line2D
var _crosshair: Node2D = null       # NSEW indicators

const NUM_RUNE_SEGMENTS: int = 8

func _ready() -> void:
	_build_visuals()

func _build_visuals() -> void:
	var n: int = 56
	# --- Outer ring -----------------------------------------------------
	var pts := PackedVector2Array()
	for i in n + 1:
		var ang: float = float(i) / float(n) * TAU
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	ring.points = pts
	ring.width = 4.5
	ring.default_color = Color(1.0, 0.85, 0.30, 0.95)
	# --- Filled disk underneath ----------------------------------------
	var fill_pts := PackedVector2Array()
	for i in n:
		var ang: float = float(i) / float(n) * TAU
		fill_pts.append(Vector2(cos(ang), sin(ang)) * radius)
	fill.polygon = fill_pts
	fill.color = Color(1.0, 0.85, 0.30, 0.18)
	# --- Inner concentric ring (60% radius) ----------------------------
	_inner_ring = Line2D.new()
	_inner_ring.width = 2.0
	_inner_ring.default_color = Color(1.0, 0.95, 0.55, 0.7)
	var inner_pts := PackedVector2Array()
	for i in n + 1:
		var ang: float = float(i) / float(n) * TAU
		inner_pts.append(Vector2(cos(ang), sin(ang)) * (radius * 0.6))
	_inner_ring.points = inner_pts
	add_child(_inner_ring)
	# --- Rotating rune segments ON the outer ring ----------------------
	_rune_holder = Node2D.new()
	add_child(_rune_holder)
	for i in NUM_RUNE_SEGMENTS:
		var seg := Line2D.new()
		var base_ang: float = float(i) / float(NUM_RUNE_SEGMENTS) * TAU
		var arc_span: float = TAU / float(NUM_RUNE_SEGMENTS) * 0.35  # 35% of slot
		var arc_pts := PackedVector2Array()
		var steps: int = 10
		for s in steps + 1:
			var a: float = base_ang - arc_span * 0.5 + arc_span * float(s) / float(steps)
			arc_pts.append(Vector2(cos(a), sin(a)) * (radius * 1.05))
		seg.points = arc_pts
		seg.width = 5.0
		seg.default_color = Color(1.0, 0.7, 0.15, 0.95)
		_rune_holder.add_child(seg)
		_rune_segments.append(seg)
	# --- Crosshair tick marks (NSEW) -----------------------------------
	_crosshair = Node2D.new()
	add_child(_crosshair)
	for i in 4:
		var t := Line2D.new()
		var ang2: float = float(i) * PI / 2.0
		var outer_p: Vector2 = Vector2(cos(ang2), sin(ang2)) * (radius * 0.95)
		var inner_p: Vector2 = Vector2(cos(ang2), sin(ang2)) * (radius * 0.75)
		t.points = PackedVector2Array([inner_p, outer_p])
		t.width = 3.0
		t.default_color = Color(1.0, 0.9, 0.45, 0.85)
		_crosshair.add_child(t)

func _process(delta: float) -> void:
	if _detonated:
		return
	_t += delta
	var t: float = clamp(_t / windup, 0.0, 1.0)
	# Pulse the fill brighter + redder as detonation approaches
	fill.color = Color(1.0, 0.55 + 0.35 * (1.0 - t), 0.30 - 0.20 * t, 0.18 + 0.40 * t)
	ring.default_color = Color(1.0, 0.85 - 0.55 * t, 0.30 - 0.20 * t, 0.95)
	# Outer ring throbs in thickness
	ring.width = 4.5 + sin(_t * 18.0) * 1.5 + t * 3.0
	# Inner ring counter-pulses on a different phase
	if is_instance_valid(_inner_ring):
		var inner_a: float = 0.4 + 0.5 * (0.5 + 0.5 * sin(_t * 12.0))
		_inner_ring.default_color = Color(1.0, 0.95, 0.55, inner_a)
	# Rotate the rune segments — speeds up as windup nears 1.0
	if is_instance_valid(_rune_holder):
		_rune_holder.rotation += delta * (1.2 + t * 4.5)
	# Crosshair flashes near the end
	if is_instance_valid(_crosshair):
		var flash: float = 0.6 + 0.4 * sin(_t * 22.0) if t > 0.5 else 0.5
		_crosshair.modulate = Color(1.0, 0.9, 0.45, flash)
	if _t >= windup:
		_detonate()

func _detonate() -> void:
	_detonated = true
	# Damage anyone (player) inside the ring at detonation
	var p := get_tree().get_first_node_in_group("player")
	if p and is_instance_valid(p) and (p as Node2D).global_position.distance_to(global_position) <= radius and p.has_method("take_damage"):
		p.take_damage(damage)
	# Hide all telegraph visuals immediately on detonation
	ring.visible = false
	fill.visible = false
	if is_instance_valid(_inner_ring):  _inner_ring.visible = false
	if is_instance_valid(_rune_holder): _rune_holder.visible = false
	if is_instance_valid(_crosshair):   _crosshair.visible = false
	# Spawn the ring shockwave sprite — scales to the slam radius
	_spawn_ring_shockwave()
	# Central red explosion for impact punch
	var ex := ExplosionScene.instantiate()
	ex.global_position = global_position
	(ex as Node).set("end_scale", radius / 60.0)
	(ex as Node).set("duration", 0.45)
	(ex as CanvasItem).modulate = Color(1.0, 0.45, 0.25, 1.0)
	get_parent().add_child(ex)
	# Shake
	var pl := get_tree().get_first_node_in_group("player")
	if pl and pl.has_method("shake"):
		pl.shake(12.0, 0.25)
	# Free the node after the shockwave finishes
	get_tree().create_timer(RING_DURATION + 0.05).timeout.connect(queue_free)

func _spawn_ring_shockwave() -> void:
	# Loads via runtime path so a missing .import sidecar doesn't break parse.
	var tex: Texture2D = load(RING_SHEET_PATH) as Texture2D
	if tex == null:
		var img := Image.new()
		if img.load(RING_SHEET_PATH) == OK:
			tex = ImageTexture.create_from_image(img)
	if tex == null:
		return  # graceful no-op
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.hframes = RING_HFRAMES
	sprite.vframes = RING_VFRAMES
	sprite.frame = 0
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Scale so the shockwave covers ~2x the slam radius at peak.
	var s: float = (radius * 2.2) / float(RING_FRAME_SIZE)
	sprite.scale = Vector2(s, s)
	sprite.modulate = Color(1.0, 0.85, 0.55, 1.0)
	add_child(sprite)
	# Drive the frame index with a Tween so we don't need _process.
	var t := create_tween()
	t.set_parallel(false)
	# Step through 0..55 over RING_DURATION
	for i in RING_FRAMES:
		t.tween_callback(func():
			if is_instance_valid(sprite):
				sprite.frame = i
		)
		t.tween_interval(RING_DURATION / float(RING_FRAMES))
