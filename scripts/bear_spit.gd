extends Area2D

# Short-range trash-mob projectile. Slow brown blob. Telegraphed by a brief
# windup on the enemy before firing. Damages the player on contact, despawns
# on first hit or after lifetime.

@export var direction: Vector2 = Vector2.RIGHT
@export var speed: float = 280.0
@export var damage: int = 1
@export var lifetime: float = 0.85   # short range — ~240 px at default speed

const RADIUS: float = 14.0   # dialed back — 28 read as comically huge
const COLOR: Color = Color(0.42, 0.28, 0.18, 1.0)
const COLOR_HIGHLIGHT: Color = Color(0.68, 0.48, 0.32, 1.0)
const COLOR_OUTLINE: Color = Color(0.18, 0.10, 0.06, 1.0)

var _t: float = 0.0
var _spin: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	set_collision_mask_value(1, true)   # stop on walls (layer 1)
	_build_visual()

func _build_visual() -> void:
	# Wobbly elliptical brown blob. Drawn procedurally so no texture needed.
	# Dark outline → main brown blob → lighter highlight. Three layers so the
	# projectile reads as a 3D goopy ball, not a flat dot.
	# --- Dark outline ring (slightly bigger than the body) ---------------
	var outline := Polygon2D.new()
	var o_pts := PackedVector2Array()
	var n: int = 22
	for i in n:
		var a: float = TAU * float(i) / float(n)
		var r: float = (RADIUS + 2.5) * (1.0 + 0.16 * sin(a * 3.0))
		o_pts.append(Vector2(cos(a) * r, sin(a) * r))
	outline.polygon = o_pts
	outline.color = COLOR_OUTLINE
	add_child(outline)
	# --- Main brown body ------------------------------------------------
	var blob := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		var r: float = RADIUS * (1.0 + 0.16 * sin(a * 3.0))
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	blob.polygon = pts
	blob.color = COLOR
	add_child(blob)
	# --- Lighter highlight (top-left shine) -----------------------------
	var hi := Polygon2D.new()
	var hi_pts := PackedVector2Array()
	for i in 16:
		var a: float = TAU * float(i) / 16.0
		hi_pts.append(Vector2(cos(a), sin(a)) * (RADIUS * 0.42))
	hi.polygon = hi_pts
	hi.color = COLOR_HIGHLIGHT
	hi.position = Vector2(-RADIUS * 0.28, -RADIUS * 0.32)
	add_child(hi)
	# --- Collision shape (matches the body, not the outline) ------------
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	col.shape = shape
	add_child(col)

func _process(delta: float) -> void:
	_t += delta
	position += direction * speed * delta
	_spin += delta * 8.0
	rotation = _spin
	if _t >= lifetime:
		# Fade out at end
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("walls"):
		queue_free()
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
