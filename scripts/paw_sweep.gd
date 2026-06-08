extends Node2D

# Full-width horizontal paw sweep — telegraphs a red danger band across the
# room at a chosen Y, then a giant procedural paw enters from one side and
# sweeps across at high speed, damaging anyone in the band.
#
# Sequence:
#   1) Telegraph (1.4 s) — red horizontal band at Y, pulsing brighter, with
#      dust-spec specks streaming along it for choreography.
#   2) Sweep (0.6 s) — paw enters from `side`, slides full room width at the
#      band's Y, with a dust contrail behind it.
#   3) Damage anyone inside the band during the sweep.

const ROOM_W: float = 1440.0
const ROOM_H: float = 810.0

@export var y_target: float = ROOM_H * 0.5
@export var band_height: float = 130.0
@export var telegraph: float = 1.4
@export var sweep_duration: float = 0.6
@export var damage: int = 2
@export var side: int = 0    # 0 = paw comes from left, 1 = from right

const PAW_RADIUS: float = 110.0
const PAW_BROWN: Color = Color(0.42, 0.30, 0.22, 1.0)
const PAW_PAD:   Color = Color(0.92, 0.85, 0.78, 1.0)

var _t: float = 0.0
var _state: int = 0       # 0 telegraph, 1 sweep, 2 done
var _dealt: bool = false

var _band: ColorRect = null
var _band_outline_top: Line2D = null
var _band_outline_bot: Line2D = null
var _streaks: Array = []     # Array[Polygon2D]
var _paw: Node2D = null

func _ready() -> void:
	# Red telegraph band
	_band = ColorRect.new()
	_band.color = Color(1.0, 0.18, 0.18, 0.0)
	_band.position = Vector2(0, y_target - band_height * 0.5)
	_band.size = Vector2(ROOM_W, band_height)
	add_child(_band)
	# Crisp top + bottom edge lines for readability
	_band_outline_top = Line2D.new()
	_band_outline_top.width = 4.0
	_band_outline_top.default_color = Color(1.0, 0.6, 0.55, 0.9)
	_band_outline_top.points = PackedVector2Array([
		Vector2(0, y_target - band_height * 0.5),
		Vector2(ROOM_W, y_target - band_height * 0.5),
	])
	add_child(_band_outline_top)
	_band_outline_bot = Line2D.new()
	_band_outline_bot.width = 4.0
	_band_outline_bot.default_color = Color(1.0, 0.6, 0.55, 0.9)
	_band_outline_bot.points = PackedVector2Array([
		Vector2(0, y_target + band_height * 0.5),
		Vector2(ROOM_W, y_target + band_height * 0.5),
	])
	add_child(_band_outline_bot)
	# Streaks — small light specks streaming sideways inside the band during
	# the telegraph, all moving the direction the paw will sweep.
	for i in 10:
		var s := Polygon2D.new()
		var pts := PackedVector2Array()
		var rx: float = randf_range(6, 14)
		for j in 8:
			var a: float = TAU * float(j) / 8.0
			pts.append(Vector2(cos(a) * rx, sin(a) * rx * 0.35))
		s.polygon = pts
		s.color = Color(1.0, 0.85, 0.5, 0.7)
		var ystart: float = y_target + randf_range(-band_height * 0.4, band_height * 0.4)
		s.position = Vector2(randf_range(0, ROOM_W), ystart)
		add_child(s)
		_streaks.append(s)
	# Pre-build the paw, hidden until sweep starts.
	_paw = _build_paw_node()
	var start_x: float = -PAW_RADIUS * 2.2 if side == 0 else ROOM_W + PAW_RADIUS * 2.2
	_paw.position = Vector2(start_x, y_target)
	_paw.modulate.a = 0.0
	add_child(_paw)

func _build_paw_node() -> Node2D:
	# Same procedural cartoon paw geometry as bear_paw_slam, rotated to sweep
	# horizontally (paw "fingers" pointing in the sweep direction).
	var n2d := Node2D.new()
	# Palm
	var palm := Polygon2D.new()
	var palm_pts := PackedVector2Array()
	var n: int = 36
	var rx: float = PAW_RADIUS * 1.05
	var ry: float = PAW_RADIUS * 0.95
	for i in n:
		var a: float = TAU * float(i) / float(n)
		palm_pts.append(Vector2(cos(a) * rx, sin(a) * ry + PAW_RADIUS * 0.1))
	palm.polygon = palm_pts
	palm.color = PAW_BROWN
	n2d.add_child(palm)
	# Palm pad
	var palm_pad := Polygon2D.new()
	var pad_pts := PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		pad_pts.append(Vector2(cos(a) * PAW_RADIUS * 0.45, sin(a) * PAW_RADIUS * 0.5))
	palm_pad.polygon = pad_pts
	palm_pad.color = PAW_PAD
	palm_pad.position = Vector2(0, PAW_RADIUS * 0.1)
	n2d.add_child(palm_pad)
	# Toes — pointed in the sweep direction (the paw is rotated below).
	# Toes go on the FORWARD side relative to the paw's local +X.
	var toe_angles: Array = [-0.55, -0.18, 0.18, 0.55]
	var toe_distance: float = PAW_RADIUS * 1.05
	for i in 4:
		var ang: float = toe_angles[i]
		var toe_center: Vector2 = Vector2(cos(ang), sin(ang)) * toe_distance
		var toe := Polygon2D.new()
		var tpts := PackedVector2Array()
		for j in 24:
			var a2: float = TAU * float(j) / 24.0
			tpts.append(Vector2(cos(a2), sin(a2)) * PAW_RADIUS * 0.32)
		toe.polygon = tpts
		toe.color = PAW_BROWN
		toe.position = toe_center
		n2d.add_child(toe)
		var toe_pad := Polygon2D.new()
		var ppts := PackedVector2Array()
		for j in 18:
			var a2: float = TAU * float(j) / 18.0
			ppts.append(Vector2(cos(a2), sin(a2)) * PAW_RADIUS * 0.18)
		toe_pad.polygon = ppts
		toe_pad.color = PAW_PAD
		toe_pad.position = toe_center
		n2d.add_child(toe_pad)
	# Rotate so the toes point in the sweep direction.
	if side == 0:
		n2d.rotation = 0.0       # toes face +X (right) — sweep left→right
	else:
		n2d.rotation = PI        # toes face -X (left) — sweep right→left
	return n2d

func _process(delta: float) -> void:
	_t += delta
	if _state == 0:
		var p: float = clamp(_t / telegraph, 0.0, 1.0)
		# Band ramps in alpha + pulses brighter
		var pulse_hz: float = lerp(5.0, 20.0, p)
		var pulse: float = 0.5 + 0.5 * sin(_t * pulse_hz)
		_band.color.a = lerp(0.18, 0.60, p) * (0.65 + 0.35 * pulse)
		_band_outline_top.default_color.a = 0.7 + 0.3 * pulse
		_band_outline_bot.default_color.a = 0.7 + 0.3 * pulse
		# Streaks fly across in sweep direction (faster as detonation nears)
		var streak_speed: float = lerp(140.0, 520.0, p)
		var dir: float = 1.0 if side == 0 else -1.0
		for s in _streaks:
			s.position.x += streak_speed * dir * delta
			if dir > 0 and s.position.x > ROOM_W + 40: s.position.x = -40
			if dir < 0 and s.position.x < -40: s.position.x = ROOM_W + 40
		if _t >= telegraph:
			_state = 1
			_t = 0.0
			_paw.modulate.a = 1.0
			# Hide streaks during the actual sweep
			for s in _streaks:
				s.visible = false
	elif _state == 1:
		var p2: float = clamp(_t / sweep_duration, 0.0, 1.0)
		# Ease-in for the paw — slow start, then BOOSH
		var eased: float = p2 * p2
		var x_start: float = -PAW_RADIUS * 2.2 if side == 0 else ROOM_W + PAW_RADIUS * 2.2
		var x_end:   float = ROOM_W + PAW_RADIUS * 2.2 if side == 0 else -PAW_RADIUS * 2.2
		_paw.position = Vector2(lerp(x_start, x_end, eased), y_target + sin(_t * 24.0) * 6.0)
		# Band fades out during sweep
		_band.color.a = lerp(0.6, 0.0, p2)
		_band_outline_top.default_color.a = lerp(1.0, 0.0, p2)
		_band_outline_bot.default_color.a = lerp(1.0, 0.0, p2)
		# Damage once when the paw passes the middle
		if not _dealt and p2 > 0.4:
			_dealt = true
			_apply_damage()
		if _t >= sweep_duration:
			queue_free()

func _apply_damage() -> void:
	var pl := get_tree().get_first_node_in_group("player")
	if not (pl is Node2D):
		return
	var py: float = (pl as Node2D).global_position.y
	if abs(py - y_target) <= band_height * 0.5:
		if pl.has_method("take_damage"):
			pl.take_damage(damage)
	if pl and pl.has_method("shake"):
		pl.shake(24.0, 0.4)
