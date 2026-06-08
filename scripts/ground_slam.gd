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

# FF14-style decal marker: an orange disc with a bright border (static), plus a
# soft core that fills outward as the cast charges.
var _marker: Sprite2D = null
var _core: Sprite2D = null

func _ready() -> void:
	_build_visuals()

func _build_visuals() -> void:
	# The old Line2D ring + Polygon2D fill are unused now.
	ring.visible = false
	fill.visible = false
	var mtex := _decal_tex("res://assets/fx/aoe_marker.png")
	var ctex := _decal_tex("res://assets/fx/aoe_core.png")
	if mtex != null:
		_marker = Sprite2D.new()
		_marker.texture = mtex
		_marker.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		# The bright border ring sits at ~0.97 of the texture half-width.
		_marker.scale = Vector2.ONE * ((radius * 2.0) / (float(mtex.get_width()) * 0.97))
		_marker.modulate = Color(1, 1, 1, 0.0)
		add_child(_marker)
	if ctex != null:
		_core = Sprite2D.new()
		_core.texture = ctex
		_core.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_core.modulate = Color(1.0, 0.55, 0.25, 0.0)
		_core.scale = Vector2.ZERO
		add_child(_core)

func _process(delta: float) -> void:
	if _detonated:
		return
	_t += delta
	var t: float = clamp(_t / windup, 0.0, 1.0)
	if is_instance_valid(_marker):
		# Fade the marker in, then pulse its border faster as detonation nears.
		var puls: float = 0.78 + 0.18 * sin(_t * (8.0 + t * 22.0))
		_marker.modulate.a = lerpf(0.0, 1.0, clampf(_t / 0.18, 0.0, 1.0)) * puls
	if is_instance_valid(_core):
		# Core charges outward to fill the circle as the cast completes.
		var core_w: float = float(_core.texture.get_width())
		var target: float = (radius * 2.0) / core_w
		var s: float = target * ease(t, 2.2)            # accelerate the fill
		_core.scale = Vector2(s, s)
		_core.modulate.a = 0.25 + 0.55 * t
	if _t >= windup:
		_detonate()

func _decal_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var t: Texture2D = load(path) as Texture2D
		if t != null:
			return t
	if FileAccess.file_exists(path):
		var b := FileAccess.get_file_as_bytes(path)
		if b.size() > 0:
			var img := Image.new()
			if img.load_png_from_buffer(b) == OK:
				return ImageTexture.create_from_image(img)
	return null

func _detonate() -> void:
	_detonated = true
	# Damage anyone (player) inside the ring at detonation
	var p := get_tree().get_first_node_in_group("player")
	if p and is_instance_valid(p) and (p as Node2D).global_position.distance_to(global_position) <= radius and p.has_method("take_damage"):
		p.take_damage(damage)
	# Hide all telegraph visuals immediately on detonation
	ring.visible = false
	fill.visible = false
	if is_instance_valid(_marker):
		_marker.visible = false
	if is_instance_valid(_core):
		_core.visible = false
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
