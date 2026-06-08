extends Area2D

# Spinning beanie thrown by the Beanie Bear. Travels toward the player while
# slowly rotating; dies on walls, damages the player.

@export var direction: Vector2 = Vector2.RIGHT
@export var speed: float = 280.0
@export var damage: int = 1
@export var lifetime: float = 2.6

var _age: float = 0.0
var _consumed: bool = false
var _spr: Sprite2D

func _ready() -> void:
	direction = direction.normalized()
	set_collision_mask_value(1, true)   # walls + player
	set_collision_mask_value(3, true)   # enemies (friendly fire none, but harmless)
	_spr = Sprite2D.new()
	_spr.texture = _tex("res://assets/beanie.png")
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2(1.4, 1.4)
	add_child(_spr)
	body_entered.connect(_on_body)

func _physics_process(delta: float) -> void:
	if _consumed:
		return
	position += direction * speed * delta
	if is_instance_valid(_spr):
		_spr.rotation += delta * 7.0   # slow spin
	_age += delta
	if _age >= lifetime:
		queue_free()

func _on_body(body: Node) -> void:
	if _consumed:
		return
	if body.is_in_group("walls"):
		_consumed = true
		queue_free()
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		_consumed = true
		queue_free()

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
