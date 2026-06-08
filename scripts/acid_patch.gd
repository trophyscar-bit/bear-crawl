extends Area2D

# An acid puddle dropped by the Long Bear. Damages the player while they stand in
# it, lingers a few seconds, then fades. Group "hazards".

@export var lifetime: float = 5.0
@export var dps: int = 2

var _t: float = 0.0
var _tick: float = 0.0
var _spr: Sprite2D

func _ready() -> void:
	add_to_group("hazards")
	set_collision_mask_value(1, true)   # player is on layer 1
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 17.0
	cs.shape = c
	add_child(cs)
	_spr = Sprite2D.new()
	_spr.texture = _tex("res://assets/acid_puddle.png")
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_spr.scale = Vector2(1.7, 1.7)
	_spr.z_index = -2
	add_child(_spr)

func _physics_process(delta: float) -> void:
	_t += delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		for b in get_overlapping_bodies():
			if b.is_in_group("player") and b.has_method("take_damage"):
				b.take_damage(dps)
	if _t >= lifetime:
		queue_free()
	elif _t >= lifetime - 1.2:
		modulate.a = (lifetime - _t) / 1.2

func _tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var t: Texture2D = load(path) as Texture2D
		if t != null:
			return t
	var f := FileAccess.open(path, FileAccess.READ)
	if f != null:
		var img := Image.new()
		if img.load_png_from_buffer(f.get_buffer(f.get_length())) == OK:
			return ImageTexture.create_from_image(img)
	return null
