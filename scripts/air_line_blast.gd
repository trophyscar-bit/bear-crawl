extends Node2D

# Frontal air-puff attack from the Shrinkwrap (plastic bag) bear.
# Replaces the previous ugly procedural Line2D + rectangle with REAL Kenney
# CC0 smoke puff sprites animated as a chain blowing forward.
#
# Sequence:
#   1) Telegraph (0.55 s) — small "winding up" puff at the bear's mouth
#      that pulses + grows. Tells the player where the blast lands.
#   2) Blast (0.55 s) — 3 puff sprites travel forward from the bear at
#      staggered start times, each playing the 25-frame smoke animation.
#      Anyone in the path during the active window takes damage.

const PUFF_SHEET_PATH := "res://assets/white_puff_sheet.png"
const FRAMES := 25
const HFRAMES := 5
const VFRAMES := 5
const FRAME_SIZE := 128

@export var direction: Vector2 = Vector2.RIGHT
@export var length: float = 300.0
@export var width: float = 60.0
@export var telegraph: float = 0.55
@export var active: float = 0.55
@export var damage: int = 1

var _t: float = 0.0
var _state: int = 0      # 0 telegraph, 1 active, 2 done
var _dealt: bool = false

var _tex: Texture2D = null
var _aim_puff: Sprite2D = null   # the telegraph puff
var _blast_puffs: Array = []     # Array[Sprite2D] — three puffs traveling along path

class PuffState:
	var node: Sprite2D
	var start_t: float     # when this puff starts moving (offset from active state)
	var start_pos: Vector2
	var end_pos: Vector2
	var travel: float      # duration of one puff's journey

func _ready() -> void:
	rotation = direction.angle()
	# Clamp the blast length to the first wall so it can't puff through stone.
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(
		global_position, global_position + direction.normalized() * length)
	q.collision_mask = 1
	var hit: Dictionary = space.intersect_ray(q)
	if hit.has("position"):
		length = maxf(40.0, global_position.distance_to(hit["position"]) - 12.0)
	_tex = _load_sheet()
	if _tex == null:
		queue_free()
		return
	# Telegraph puff at the bear's mouth — small, then pulses bigger
	_aim_puff = Sprite2D.new()
	_aim_puff.texture = _tex
	_aim_puff.hframes = HFRAMES
	_aim_puff.vframes = VFRAMES
	_aim_puff.frame = 6
	_aim_puff.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_aim_puff.position = Vector2(0, 0)
	_aim_puff.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_aim_puff.scale = Vector2(0.18, 0.18)
	add_child(_aim_puff)
	# Pre-build the 3 blast puffs (hidden until active phase)
	for i in 3:
		var s := Sprite2D.new()
		s.texture = _tex
		s.hframes = HFRAMES
		s.vframes = VFRAMES
		s.frame = 0
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		s.visible = false
		add_child(s)
		var p := PuffState.new()
		p.node = s
		p.start_t = float(i) * 0.08
		p.start_pos = Vector2(0, randf_range(-width * 0.10, width * 0.10))
		p.end_pos = Vector2(length, randf_range(-width * 0.10, width * 0.10))
		p.travel = active - p.start_t
		_blast_puffs.append(p)

func _load_sheet() -> Texture2D:
	var t: Texture2D = load(PUFF_SHEET_PATH) as Texture2D
	if t != null:
		return t
	if FileAccess.file_exists(PUFF_SHEET_PATH):
		var bytes := FileAccess.get_file_as_bytes(PUFF_SHEET_PATH)
		if bytes.size() > 0:
			var img := Image.new()
			if img.load_png_from_buffer(bytes) == OK:
				return ImageTexture.create_from_image(img)
	return null

func _process(delta: float) -> void:
	_t += delta
	if _state == 0:
		var p: float = clamp(_t / telegraph, 0.0, 1.0)
		# Telegraph puff fades in + grows + cycles through early animation frames
		_aim_puff.modulate.a = lerp(0.0, 0.85, p) * (0.7 + 0.3 * sin(_t * 14.0))
		_aim_puff.scale = Vector2.ONE * lerp(0.18, 0.42, p)
		_aim_puff.frame = int(lerp(0, 8, p)) % FRAMES
		if _t >= telegraph:
			_state = 1
			_t = 0.0
			_aim_puff.visible = false
	elif _state == 1:
		# Update each blast puff's position + animation frame
		for ps in _blast_puffs:
			var local_t: float = _t - ps.start_t
			if local_t < 0.0:
				continue
			ps.node.visible = true
			var tp: float = clamp(local_t / ps.travel, 0.0, 1.0)
			ps.node.position = ps.start_pos.lerp(ps.end_pos, tp)
			ps.node.frame = clamp(int(tp * float(FRAMES)), 0, FRAMES - 1)
			# Scale grows over the journey + alpha fades at the tail end
			ps.node.scale = Vector2.ONE * lerp(0.6, 1.4, tp)
			ps.node.modulate.a = clamp(1.0 - pow(tp, 3.0), 0.0, 1.0)
		# Continuous hit check across the WHOLE active window (was a single early
		# snapshot that the travelling puff usually outran → felt like no damage).
		if not _dealt:
			_try_apply_damage()
		if _t >= active:
			queue_free()

func _try_apply_damage() -> void:
	var pl := get_tree().get_first_node_in_group("player")
	if not (pl is Node2D):
		return
	var off: Vector2 = (pl as Node2D).global_position - global_position
	var fwd: Vector2 = direction.normalized()
	var side: Vector2 = Vector2(-fwd.y, fwd.x)
	var along: float = off.dot(fwd)
	var lateral: float = abs(off.dot(side))
	# Wider lateral band so the hitbox matches the fat visual puff.
	if along >= -20.0 and along <= length and lateral <= maxf(width, 100.0) * 0.5:
		if pl.has_method("take_damage"):
			pl.take_damage(damage)
			_dealt = true
