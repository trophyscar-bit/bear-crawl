extends Area2D

# Frost Cub's projectile. It corkscrews — looping in a circle while it drifts
# forward — and FREEZES the player for 1s on contact. Dies on walls.

@export var direction: Vector2 = Vector2.RIGHT
@export var forward_speed: float = 165.0
@export var spin: float = 6.5          # rad/s around the travel axis
@export var radius: float = 34.0       # loop radius
@export var freeze_time: float = 1.0
@export var lifetime: float = 3.2

var _center: Vector2
var _ang: float = 0.0
var _age: float = 0.0
var _dead: bool = false
var _spr: Sprite2D

func _ready() -> void:
	direction = direction.normalized()
	_center = global_position
	_ang = randf() * TAU
	set_collision_mask_value(1, true)   # walls + player
	_spr = Sprite2D.new()
	_spr.texture = _tex("res://assets/projectiles/frost_orb.png")
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2(1.3, 1.3)
	add_child(_spr)
	# soft icy glow so the loop reads in the dark
	if not (ArpgState.active and ArpgState.no_projectile_glow):
		var gl := PointLight2D.new()
		gl.texture = _glow_tex()
		gl.color = Color(0.6, 0.85, 1.0)
		gl.energy = 0.55
		gl.texture_scale = 0.5
		add_child(gl)
	body_entered.connect(_on_body)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_center += direction * forward_speed * delta
	_ang += spin * delta
	global_position = _center + Vector2.from_angle(_ang) * radius
	if is_instance_valid(_spr):
		_spr.rotation += delta * 4.0
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
	if body.is_in_group("player"):
		if body.has_method("freeze"):
			body.freeze(freeze_time)
		_dead = true
		queue_free()

func _glow_tex() -> Texture2D:
	if ResourceLoader.exists("res://assets/light_radial.png"):
		return load("res://assets/light_radial.png") as Texture2D
	return _tex("res://assets/light_radial.png")

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
