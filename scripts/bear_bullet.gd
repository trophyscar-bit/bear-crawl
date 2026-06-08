extends Area2D

# Slow fluff ball fired by the gun bear. Soft cottony projectile — easy to
# see and dodge if you're paying attention. Procedural, no texture needed.

@export var direction: Vector2 = Vector2.RIGHT
@export var speed: float = 220.0
@export var damage: int = 1
@export var lifetime: float = 2.4

const RADIUS: float = 13.0
const FLUFF_CORE := Color(0.96, 0.94, 0.88, 1.0)
const FLUFF_MID  := Color(0.86, 0.82, 0.74, 1.0)
const FLUFF_EDGE := Color(0.62, 0.58, 0.50, 0.55)

var _t: float = 0.0
var _spin: float = 0.0
var _ff_grace: float = 0.1   # ignore enemies briefly so we don't hit the shooter

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	set_collision_mask_value(1, true)   # walls
	set_collision_mask_value(3, true)   # enemies (friendly fire)
	_build_visual()
	rotation = direction.angle()
	if direction.length() > 0:
		direction = direction.normalized()

const BulletTex := preload("res://assets/bullet.png")

func _build_visual() -> void:
	# Real bullet/tracer sprite (replaces the old procedural fluff ball).
	var spr := Sprite2D.new()
	spr.texture = BulletTex
	spr.scale = Vector2(0.9, 0.9)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(spr)
	# Light glow so the tracer is visible in the dark.
	if not (ArpgState.active and ArpgState.no_projectile_glow):
		var gl := PointLight2D.new()
		if ResourceLoader.exists("res://assets/light_radial.png"):
			gl.texture = load("res://assets/light_radial.png") as Texture2D
		gl.color = Color(1.0, 0.8, 0.5)
		gl.energy = 0.35
		gl.texture_scale = 0.28
		add_child(gl)
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 8.0
	col.shape = shape
	add_child(col)

func _wobbly_circle(r: float, n: int, wobble: float) -> PackedVector2Array:
	# Closed contour with small per-vertex radius noise so it reads cottony.
	var pts := PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		# multi-frequency wobble so it doesn't look perfectly periodic
		var w: float = 1.0 + sin(a * 5.0 + r * 0.1) * wobble + sin(a * 11.0) * (wobble * 0.4)
		pts.append(Vector2(cos(a) * r * w, sin(a) * r * w))
	return pts

func _process(delta: float) -> void:
	_t += delta
	if _ff_grace > 0.0:
		_ff_grace -= delta
	# Fly straight in the fired direction (it's a bullet now, not floating fluff).
	position += direction * speed * delta
	rotation = direction.angle()
	if _t >= lifetime:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("walls"):
		queue_free()
		return
	if body.is_in_group("enemies"):
		if _ff_grace > 0.0:
			return
		if body.has_method("take_damage"):
			body.take_damage(damage)   # friendly fire
		queue_free()
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
