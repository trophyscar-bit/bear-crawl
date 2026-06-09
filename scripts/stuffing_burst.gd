extends Sprite2D

# One-shot white "stuffing" splatter — plush-bear take on a blood VFX. Plays its
# strip sheet once (110px frames) then frees itself. Texture is assigned by the
# spawner before _ready (loaded at runtime since the sheet has no .import).

const FW: int = 110
@export var fps: float = 28.0
var _frames: int = 1
var _t: float = 0.0
var _f: int = 0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 6
	if texture != null:
		_frames = maxi(1, texture.get_width() / FW)
		hframes = _frames
		vframes = 1
		frame = 0

func _process(delta: float) -> void:
	_t += delta
	if _t >= 1.0 / fps:
		_t -= 1.0 / fps
		_f += 1
		if _f >= _frames:
			queue_free()
			return
		frame = _f
