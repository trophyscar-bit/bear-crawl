extends Node2D

# Boss phase-3 special. A massive bear face slides across HALF the screen
# from off-screen, dealing damage to anyone caught in its path.
#
# Sequence:
#   1) Telegraph: red overlay covers the targeted half of the room.
#   2) The maw appears off-screen on the targeted side and slides across.
#   3) Anyone in the targeted half during the SLIDE phase takes damage.
#   4) Maw exits, scene frees itself.

const ROOM_W: float = 1440.0   # main scene's playable width
const ROOM_H: float = 810.0
const MAW_SHEET_PATH := "res://assets/cleave_maw.png"

@export var side: int = 0       # 0 = left half, 1 = right half
@export var damage: int = 2
@export var telegraph: float = 1.2
@export var slide_duration: float = 1.1

var _t: float = 0.0
var _state: int = 0             # 0 telegraph, 1 sliding, 2 done
var _maw: Sprite2D = null
var _overlay: ColorRect = null
var _dealt_damage: bool = false
# Overlay face — drawn ON TOP of the maw sprite so the bear has a cartoonish
# ":(" expression that wobbles as he slides.
var _face_holder: Node2D = null
var _mouth: Line2D = null
var _eye_left: Polygon2D = null
var _eye_right: Polygon2D = null
var _face_t: float = 0.0

func _ready() -> void:
	# Build the red telegraph overlay first.
	_overlay = ColorRect.new()
	_overlay.color = Color(1.0, 0.15, 0.15, 0.0)  # fades in
	_overlay.position = Vector2(0, 0) if side == 0 else Vector2(ROOM_W * 0.5, 0)
	_overlay.size = Vector2(ROOM_W * 0.5, ROOM_H)
	add_child(_overlay)
	# Build the giant maw sprite — loaded via runtime path so a missing
	# .import sidecar doesn't break parse.
	var tex: Texture2D = load(MAW_SHEET_PATH) as Texture2D
	if tex == null:
		var img := Image.new()
		if img.load(MAW_SHEET_PATH) == OK:
			tex = ImageTexture.create_from_image(img)
	if tex != null:
		_maw = Sprite2D.new()
		_maw.texture = tex
		_maw.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		# Scale so the maw fills the room vertically — much more imposing.
		var scale_factor: float = (ROOM_H * 1.05) / float(tex.get_height())
		_maw.scale = Vector2(scale_factor, scale_factor)
		_maw.modulate = Color(1, 1, 1, 0.0)  # invisible during telegraph
		_maw.position = _start_position()
		add_child(_maw)
		# (Face overlay removed — the raw photo IS the bear face; layering a
		# procedural ":(" on top was making it look like garbage.)

func _build_face_overlay() -> void:
	# Draws a goofy ":(" face on top of the maw photo. Lives on the maw so it
	# moves with it. Coordinates are in maw-LOCAL pixel space (relative to the
	# sprite's center), then scaled to whatever maw scale is in use.
	_face_holder = Node2D.new()
	_maw.add_child(_face_holder)
	# --- Eyes — two cartoony black ovals -------------------------------
	var eye_y: float = -120.0  # above the snout
	_eye_left  = _make_eye(Vector2(-130.0, eye_y))
	_eye_right = _make_eye(Vector2( 130.0, eye_y))
	_face_holder.add_child(_eye_left)
	_face_holder.add_child(_eye_right)
	# --- ":( " mouth — a downturned arc drawn with Line2D --------------
	_mouth = Line2D.new()
	_mouth.width = 18.0
	_mouth.default_color = Color(0.05, 0.04, 0.05, 1.0)
	_mouth.joint_mode = Line2D.LINE_JOINT_ROUND
	_mouth.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_mouth.end_cap_mode = Line2D.LINE_CAP_ROUND
	_mouth.points = _frown_points(0.0)
	_face_holder.add_child(_mouth)

func _make_eye(pos: Vector2) -> Polygon2D:
	var p := Polygon2D.new()
	var pts := PackedVector2Array()
	var n: int = 20
	var rx: float = 26.0
	var ry: float = 34.0
	for i in n:
		var a: float = TAU * float(i) / float(n)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	p.polygon = pts
	p.color = Color(0.05, 0.04, 0.05, 1.0)
	p.position = pos
	return p

func _frown_points(wobble_phase: float) -> PackedVector2Array:
	# Builds a downturned arc — ":(" mouth shape — from 9 sample points.
	# wobble_phase shifts the arc slightly so the mouth wibbles as he moves.
	var pts := PackedVector2Array()
	var span_x: float = 220.0
	var depth: float = -55.0   # negative = downturned (concave-up in screen coords means smile, so we want concave-down)
	# Actually screen Y is down — to make a sad frown, the ENDS go DOWN and
	# the middle goes UP. So endpoints have positive Y (below center) and
	# the middle has lower Y. We invert that for ":(":
	# Sad mouth: endpoints LOW (+Y), middle HIGH (-Y from endpoints, so +Y less).
	var n: int = 9
	for i in n:
		var t: float = float(i) / float(n - 1)
		var x: float = lerp(-span_x * 0.5, span_x * 0.5, t)
		# parabola: dips toward middle (smiling) or peaks toward middle (frowning)
		# Want frown — middle goes UP (less +Y), ends go DOWN (more +Y).
		var y_base: float = 60.0 - (4.0 * t * (1.0 - t)) * depth  # frown
		var wobble: float = sin(wobble_phase + t * PI) * 4.0
		pts.append(Vector2(x, y_base + wobble))
	return pts

func _start_position() -> Vector2:
	# Off-screen on the side we're attacking from.
	var y: float = ROOM_H * 0.5
	if side == 0:
		return Vector2(-ROOM_W * 0.3, y)   # comes in from the left
	return Vector2(ROOM_W * 1.3, y)        # comes in from the right

func _end_position() -> Vector2:
	# Slides across to the center of the targeted half (still in-frame)
	# then continues off-screen the other way.
	var y: float = ROOM_H * 0.5
	if side == 0:
		return Vector2(ROOM_W * 0.55, y)   # ends just past the half line
	return Vector2(ROOM_W * 0.45, y)

func _process(delta: float) -> void:
	_t += delta
	if _state == 0:  # telegraph
		var p: float = clamp(_t / telegraph, 0.0, 1.0)
		# overlay pulses brighter as detonation approaches
		var pulse: float = 0.5 + 0.5 * sin(_t * 12.0)
		_overlay.color.a = lerp(0.0, 0.45, p) * (0.7 + 0.3 * pulse)
		if _t >= telegraph:
			_state = 1
			_t = 0.0
			if is_instance_valid(_maw):
				_maw.modulate.a = 1.0
	elif _state == 1:  # sliding
		var p: float = clamp(_t / slide_duration, 0.0, 1.0)
		if is_instance_valid(_maw):
			_maw.position = _start_position().lerp(_end_position(), p)
			# Slight tilt/wobble as he comes in
			_maw.rotation = sin(_t * 14.0) * 0.05
		# overlay fades during the slide
		_overlay.color.a = lerp(0.45, 0.0, p)
		# Deal damage ONCE near the middle of the slide (when maw is on-screen).
		if not _dealt_damage and p > 0.4:
			_dealt_damage = true
			_apply_damage()
		if _t >= slide_duration:
			_state = 2
			queue_free()

func _animate_face(delta: float, slide_p: float) -> void:
	if not is_instance_valid(_face_holder):
		return
	_face_t += delta
	# Mouth wibble — sine wave moves the frown's amplitude over time so it
	# reads as a worried, animated face rather than a static decal.
	if is_instance_valid(_mouth):
		_mouth.points = _frown_points(_face_t * 8.0)
	# Eye blink — every ~0.55 s the eyes squish vertically (closing).
	if is_instance_valid(_eye_left) and is_instance_valid(_eye_right):
		var blink: float = pow(0.5 + 0.5 * cos(_face_t * 11.0), 8.0)  # sharp dips
		var sy: float = lerp(1.0, 0.15, blink)
		_eye_left.scale.y = sy
		_eye_right.scale.y = sy
	# Whole face nudges a hair downward in screen-space toward end of slide
	# (he's looking more pitiful as he passes through)
	var droop: float = slide_p * 6.0
	_face_holder.position.y = droop

func _apply_damage() -> void:
	var pl := get_tree().get_first_node_in_group("player")
	if not (pl is Node2D):
		return
	var px: float = (pl as Node2D).global_position.x
	var in_left: bool = px < ROOM_W * 0.5
	var hit: bool = (side == 0 and in_left) or (side == 1 and not in_left)
	if hit and pl.has_method("take_damage"):
		pl.take_damage(damage)
	if pl.has_method("shake"):
		pl.shake(28.0, 0.5)
