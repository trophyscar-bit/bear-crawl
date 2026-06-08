extends Node2D

# Half-screen cleave telegraph for the Face Boss. Red flashing overlay on
# the targeted half of the room for `telegraph` seconds, then an `active`
# burst that damages anyone still on that side.

const ROOM_W: float = 1440.0
const ROOM_H: float = 810.0

@export var side: int = 0           # 0 = left, 1 = right
@export var telegraph: float = 2.0
@export var active: float = 0.35
@export var damage: int = 2

var _t: float = 0.0
var _state: int = 0    # 0 telegraph, 1 active, 2 done
var _dealt: bool = false

var _flash: ColorRect = null        # the red telegraph overlay
var _ring: Line2D = null            # white border for clarity

func _ready() -> void:
	# main.tscn has y_sort_enabled, so a Node2D at y=0 normally renders
	# BEHIND everything else (bushes, decorations, enemies are all at high
	# y values). Force z_index high enough to draw on top of all gameplay
	# elements but still below the face boss (z=50).
	z_index = 45
	z_as_relative = false
	# Build the overlay rectangle.
	_flash = ColorRect.new()
	_flash.color = Color(1.0, 0.18, 0.18, 0.0)
	_flash.position = Vector2(0.0, 0.0) if side == 0 else Vector2(ROOM_W * 0.5, 0.0)
	_flash.size = Vector2(ROOM_W * 0.5, ROOM_H)
	add_child(_flash)
	# Crisp border line for readability
	_ring = Line2D.new()
	_ring.width = 6.0
	_ring.default_color = Color(1.0, 0.7, 0.6, 0.9)
	_ring.closed = true
	var x0: float = 0.0 if side == 0 else ROOM_W * 0.5
	var x1: float = ROOM_W * 0.5 if side == 0 else ROOM_W
	_ring.points = PackedVector2Array([
		Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, ROOM_H), Vector2(x0, ROOM_H)
	])
	add_child(_ring)

func _process(delta: float) -> void:
	_t += delta
	if _state == 0:
		var p: float = clamp(_t / telegraph, 0.0, 1.0)
		# Pulse alpha — accelerating as detonation approaches
		var pulse_hz: float = lerp(4.0, 18.0, p)
		var pulse: float = 0.5 + 0.5 * sin(_t * pulse_hz)
		_flash.color.a = lerp(0.18, 0.55, p) * (0.6 + 0.4 * pulse)
		_ring.default_color.a = 0.7 + 0.3 * pulse
		_ring.width = 6.0 + 4.0 * p
		if _t >= telegraph:
			_state = 1
			_t = 0.0
			# Hard flash white on detonation
			_flash.color = Color(1.0, 1.0, 1.0, 0.85)
	elif _state == 1:
		var p2: float = clamp(_t / active, 0.0, 1.0)
		_flash.color = Color(1.0, 0.2, 0.2, lerp(0.85, 0.0, p2))
		_ring.default_color.a = lerp(1.0, 0.0, p2)
		if not _dealt:
			_dealt = true
			_apply_damage()
		if _t >= active:
			queue_free()

func _apply_damage() -> void:
	var pl := get_tree().get_first_node_in_group("player")
	if not (pl is Node2D):
		return
	var px: float = (pl as Node2D).global_position.x
	var in_left: bool = px < ROOM_W * 0.5
	var hit: bool = (side == 0 and in_left) or (side == 1 and not in_left)
	if hit and pl.has_method("take_damage"):
		pl.take_damage(damage)
	if pl and pl.has_method("shake"):
		pl.shake(26.0, 0.45)
