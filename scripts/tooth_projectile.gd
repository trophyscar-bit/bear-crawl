extends Area2D

# Magic orb projectile fired by the Face Boss. Uses Kenney's CC0 magic_03
# particle PNG (sparkling glow with 4 spike rays) with additive blending and
# a pink/magenta tint so it reads clearly against the sky background.

const SPRITE_PATH := "res://assets/kenney_particles/magic_03.png"
const ORB_SCALE: float = 0.13          # downscale 512x512 → ~67 px
const ORB_TINT: Color = Color(1.0, 0.55, 0.85, 1.0)   # magenta-pink glow
const COLLISION_RADIUS: float = 18.0

@export var direction: Vector2 = Vector2.DOWN
@export var speed: float = 220.0       # was 320 — slowed per user
@export var damage: int = 1
@export var lifetime: float = 6.0
@export var homing: float = 0.9        # was 1.2 — less aggressive curve

var _t: float = 0.0
var _player: Node2D = null
var _sprite: Sprite2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_build_visual()
	_player = get_tree().get_first_node_in_group("player") as Node2D
	if direction.length() > 0:
		direction = direction.normalized()

func _build_visual() -> void:
	# Load the magic glow texture and add as a Sprite2D with additive blending
	# so the black background of the source renders as transparent and the
	# sparkle adds to whatever it's over.
	var tex: Texture2D = _load_tex(SPRITE_PATH)
	if tex != null:
		_sprite = Sprite2D.new()
		_sprite.texture = tex
		_sprite.scale = Vector2(ORB_SCALE, ORB_SCALE)
		_sprite.modulate = ORB_TINT
		_sprite.material = CanvasItemMaterial.new()
		(_sprite.material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(_sprite)
	# Collision shape
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = COLLISION_RADIUS
	col.shape = shape
	add_child(col)

func _load_tex(path: String) -> Texture2D:
	var t: Texture2D = load(path) as Texture2D
	if t != null:
		return t
	if FileAccess.file_exists(path):
		var bytes := FileAccess.get_file_as_bytes(path)
		if bytes.size() > 0:
			var img := Image.new()
			if img.load_png_from_buffer(bytes) == OK:
				return ImageTexture.create_from_image(img)
	return null

func _process(delta: float) -> void:
	_t += delta
	# Mild homing — curve direction toward the player
	if homing > 0.0 and is_instance_valid(_player):
		var desired: Vector2 = ((_player as Node2D).global_position - global_position).normalized()
		var current_angle: float = direction.angle()
		var target_angle: float = desired.angle()
		var diff: float = wrapf(target_angle - current_angle, -PI, PI)
		var step: float = clamp(diff, -homing * delta, homing * delta)
		direction = Vector2.RIGHT.rotated(current_angle + step)
	position += direction * speed * delta
	# Slow spin on the sprite so the sparkle rays rotate — looks more alive
	if is_instance_valid(_sprite):
		_sprite.rotation += delta * 1.8
	if _t >= lifetime:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
