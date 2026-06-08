extends "res://scripts/enemy.gd"

# Animated pixel-art skeleton — a straightforward halberd melee chaser. Walks the
# 13-frame cycle and bonks you on contact (no ranged attack).

const WALK_FRAMES: int = 13
const WALK_FPS: float = 11.0

@onready var _rig: Node2D = $Rig
@onready var _spr: Sprite2D = $Rig/Body
var _frame_t: float = 0.0

func _ready() -> void:
	max_health = 6
	speed = 96.0
	touch_damage = 1
	throws_stars = false
	super._ready()
	var t := _load_png("res://assets/skeleton_walk.png")
	if t != null and is_instance_valid(_spr):
		_spr.texture = t
		_spr.hframes = WALK_FRAMES
		_spr.vframes = 1
		_spr.frame = 0
		_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _physics_process(delta: float) -> void:
	super._physics_process(delta)   # chase steering + move
	if _dying:
		return
	# Step the walk cycle.
	_frame_t += delta
	if _frame_t >= 1.0 / WALK_FPS:
		_frame_t -= 1.0 / WALK_FPS
		if is_instance_valid(_spr):
			_spr.frame = (_spr.frame + 1) % WALK_FRAMES
	# Face travel direction.
	if is_instance_valid(_rig) and absf(velocity.x) > 4.0:
		_rig.scale.x = absf(_rig.scale.x) * (1.0 if velocity.x > 0.0 else -1.0)

func _load_png(path: String) -> Texture2D:
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
