extends Area2D

# Small generic enemy projectile (duckling spit). Travels straight, dies on walls,
# damages the player. Carries a faint glow so it's visible in dark rooms.

@export var direction: Vector2 = Vector2.RIGHT
@export var speed: float = 240.0
@export var damage: int = 1
@export var lifetime: float = 2.4
@export var tint: Color = Color(1.0, 0.85, 0.4)

var _age: float = 0.0
var _dead: bool = false
var _spr: Sprite2D

func _ready() -> void:
	direction = direction.normalized()
	set_collision_mask_value(1, true)   # walls + player
	_spr = Sprite2D.new()
	_spr.texture = _tex("res://assets/projectiles/pellet.png")
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.modulate = tint
	add_child(_spr)
	if not (ArpgState.active and ArpgState.no_projectile_glow):
		var gl := PointLight2D.new()
		gl.texture = _tex("res://assets/light_radial.png")
		gl.color = tint
		gl.energy = 0.35           # very light — just enough to spot in the dark
		gl.texture_scale = 0.32
		add_child(gl)
	body_entered.connect(_on_body)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	position += direction * speed * delta
	_age += delta
	if _age >= lifetime:
		queue_free()

func _on_body(body: Node) -> void:
	if _dead:
		return
	if body.is_in_group("walls"):
		_dead = true
		queue_free()
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		_dead = true
		queue_free()

func _tex(path: String) -> Texture2D:
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
