extends Node2D

# Telegraphed slam from above — a Lightning strike (free pixel FX pack).
#
# Sequence:
#   1) A target indicator (shadow + pulsing ring) appears on the ground at the
#      player's position (locked at spawn) for `telegraph` seconds.
#   2) The Lightning animation cracks down onto the target.
#   3) Impact: anyone inside the radius takes damage + camera shake.

@export var radius: float = 95.0
@export var telegraph: float = 1.0
@export var damage: int = 2

const FX_DIR := "res://assets/fx/lightning/"
const STRIKE_DURATION: float = 0.55
const DAMAGE_AT: float = 0.55          # fraction of the strike when the bolt lands
const SHADOW: Color = Color(0, 0, 0, 0.35)

var _t: float = 0.0
var _state: int = 0          # 0 telegraph, 1 strike, 2 done
var _impacted: bool = false
var _indicator: Node2D = null
var _bolt: Sprite2D = null
var _frames: Array[Texture2D] = []

func _ready() -> void:
	_frames = _load_frames(FX_DIR)
	_build_indicator()
	_bolt = Sprite2D.new()
	_bolt.centered = true
	_bolt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bolt.visible = false
	var fh: float = float(_frames[0].get_height()) if not _frames.is_empty() else 88.0
	_bolt.offset = Vector2(0, -fh * 0.5)        # anchor the bottom (impact) at origin
	var sc: float = radius / 30.0               # strike roughly spans the radius
	_bolt.scale = Vector2(sc, sc)
	_bolt.z_index = 40
	if not _frames.is_empty():
		_bolt.texture = _frames[0]
	add_child(_bolt)

func _build_indicator() -> void:
	_indicator = Node2D.new()
	add_child(_indicator)
	var shadow := Polygon2D.new()
	var pts := PackedVector2Array()
	var n: int = 28
	for i in n:
		var a: float = TAU * float(i) / float(n)
		pts.append(Vector2(cos(a) * radius, sin(a) * radius * 0.55))
	shadow.polygon = pts
	shadow.color = SHADOW
	_indicator.add_child(shadow)
	var ring := Line2D.new()
	var ring_pts := PackedVector2Array()
	for i in n + 1:
		var a: float = TAU * float(i) / float(n)
		ring_pts.append(Vector2(cos(a) * radius, sin(a) * radius * 0.55))
	ring.points = ring_pts
	ring.width = 3.5
	ring.default_color = Color(1.0, 0.85, 0.3, 0.9)   # yellow to match the lightning
	_indicator.add_child(ring)
	for i in 4:
		var t := Line2D.new()
		var ang: float = float(i) * PI / 2.0
		var v: Vector2 = Vector2(cos(ang), sin(ang) * 0.55)
		t.points = PackedVector2Array([v * (radius * 0.7), v * (radius * 0.95)])
		t.width = 3.0
		t.default_color = Color(0.95, 0.8, 0.35, 0.85)
		_indicator.add_child(t)

func _process(delta: float) -> void:
	_t += delta
	if _state == 0:
		_indicator.modulate = Color(1, 1, 1, 0.55 + 0.45 * (0.5 + 0.5 * sin(_t * 14.0)))
		if _t >= telegraph:
			_state = 1
			_t = 0.0
			_bolt.visible = true
	elif _state == 1:
		var p: float = clamp(_t / STRIKE_DURATION, 0.0, 1.0)
		if not _frames.is_empty():
			var idx: int = clampi(int(p * float(_frames.size())), 0, _frames.size() - 1)
			_bolt.texture = _frames[idx]
		_indicator.modulate.a = 1.0 - p          # indicator fades as the bolt lands
		if not _impacted and p >= DAMAGE_AT:
			_on_impact()
		if _t >= STRIKE_DURATION:
			queue_free()

func _on_impact() -> void:
	if _impacted:
		return
	_impacted = true
	Juice.shake(0.3)
	var pl := get_tree().get_first_node_in_group("player")
	if pl is Node2D and pl.has_method("take_damage"):
		var off: Vector2 = (pl as Node2D).global_position - global_position
		var nx: float = off.x / radius
		var ny: float = off.y / (radius * 0.55)
		if nx * nx + ny * ny <= 1.0:
			pl.take_damage(damage)
	if pl and pl.has_method("shake"):
		pl.shake(22.0, 0.35)

func _load_frames(dir: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var names: Array[String] = []
	var da := DirAccess.open(dir)
	if da == null:
		return out
	da.list_dir_begin()
	var fn := da.get_next()
	while fn != "":
		if fn.to_lower().ends_with(".png"):
			names.append(fn)
		fn = da.get_next()
	da.list_dir_end()
	names.sort()
	for n in names:
		var f := FileAccess.open(dir + n, FileAccess.READ)
		if f == null:
			continue
		var img := Image.new()
		if img.load_png_from_buffer(f.get_buffer(f.get_length())) == OK:
			out.append(ImageTexture.create_from_image(img))
	return out
