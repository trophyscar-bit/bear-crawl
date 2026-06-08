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

# Inward-marching chevron markers built in _ready
var _chevrons: Array = []           # of {node: Polygon2D, ang: float}
const NUM_CHEV: int = 4

func _ready() -> void:
	_build_visuals()

func _build_visuals() -> void:
	var n: int = 56
	# --- Outer ring — thin red danger outline ---------------------------
	var pts := PackedVector2Array()
	for i in n + 1:
		var ang: float = float(i) / float(n) * TAU
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	ring.points = pts
	ring.width = 3.0
	ring.default_color = Color(1.0, 0.3, 0.22, 0.9)
	# --- Filled disk — charges up red as the strike lands ---------------
	var fill_pts := PackedVector2Array()
	for i in n:
		var ang: float = float(i) / float(n) * TAU
		fill_pts.append(Vector2(cos(ang), sin(ang)) * radius)
	fill.polygon = fill_pts
	fill.color = Color(0.9, 0.15, 0.12, 0.10)
	# --- Four chevrons that march inward toward the impact point --------
	for i in NUM_CHEV:
		var ang: float = float(i) / float(NUM_CHEV) * TAU + PI / 4.0
		var chev := Polygon2D.new()
		chev.polygon = PackedVector2Array([Vector2(12, 0), Vector2(-8, -9), Vector2(-3, 0), Vector2(-8, 9)])
		chev.color = Color(1.0, 0.35, 0.2, 0.95)
		add_child(chev)
		_chevrons.append({"node": chev, "ang": ang})

func _process(delta: float) -> void:
	if _detonated:
		return
	_t += delta
	var t: float = clamp(_t / windup, 0.0, 1.0)
	# Disk fills up + deepens to angry red as it charges.
	fill.color = Color(0.95, 0.18 * (1.0 - t), 0.12 * (1.0 - t), 0.10 + 0.50 * t)
	# Ring throbs + reddens.
	ring.width = 3.0 + t * 3.0 + sin(_t * 16.0) * 1.0
	ring.default_color = Color(1.0, 0.3 - 0.2 * t, 0.22 - 0.15 * t, 0.9)
	# Chevrons converge on the centre + pulse — the closer in, the sooner it hits.
	var d: float = lerpf(radius * 1.18, radius * 0.42, t)
	var puls: float = 1.0 + 0.25 * sin(_t * 18.0)
	for c in _chevrons:
		var node: Polygon2D = c["node"]
		var ang: float = c["ang"]
		node.position = Vector2(cos(ang), sin(ang)) * d
		node.rotation = ang + PI            # arrow tip points inward
		node.scale = Vector2(puls, puls)
		node.modulate = Color(1, 1, 1, 0.7 + 0.3 * t)
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
	for c in _chevrons:
		if is_instance_valid(c["node"]):
			(c["node"] as Node2D).visible = false
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
	sprite.modulate = Color(1.0, 0.45, 0.28, 1.0)   # red-orange to match the danger reticle
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
