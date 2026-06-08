extends "res://scripts/enemy.gd"

# Generic photo-cutout critter mob (duck / hound / frost cub …). Pure melee chaser
# — no ninja stars/paw. Each scene sets the texture + stats via the exports below.

@export var tex_path: String = ""
@export var crit_hp: int = 4
@export var crit_speed: float = 110.0
@export var crit_touch: int = 1
@export var rig_scale: float = 0.42
@export var float_mode: bool = false   # balloon: bobs up/down as it drifts in

@onready var _rig: Node2D = $Rig
@onready var sprite: Sprite2D = $Rig/Body
var _bob_t: float = 0.0

func _ready() -> void:
	max_health = crit_hp
	speed = crit_speed
	touch_damage = crit_touch
	throws_stars = false            # melee only — no stars/paw slam
	super._ready()
	if is_instance_valid(_rig):
		_rig.scale = Vector2(rig_scale, rig_scale)
	if is_instance_valid(sprite):
		var t: Texture2D = _load_tex_robust(tex_path)
		if t != null:
			sprite.texture = t
			_fit_hitbox(t)
		else:
			push_warning("[critter] missing texture %s" % tex_path)
			queue_free()

func _fit_hitbox(t: Texture2D) -> void:
	# The scene-authored CollisionShape2D never matched these runtime-loaded cutouts,
	# so shots sailed through. Size the hitbox to the ACTUAL visible sprite (texture
	# size × rig scale), trimmed in a touch so it's fair but generous.
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		return
	var vis_w: float = float(t.get_width()) * rig_scale
	var vis_h: float = float(t.get_height()) * rig_scale
	var rect := RectangleShape2D.new()
	rect.size = Vector2(maxf(18.0, vis_w * 0.74), maxf(18.0, vis_h * 0.82))
	cs.shape = rect
	if is_instance_valid(_rig):
		cs.position = _rig.position   # follow any rig offset (e.g. float bob baseline)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	# Balloon float: gently bob the rig up and down as it drifts toward the player.
	if float_mode and is_instance_valid(_rig):
		_bob_t += delta
		_rig.position.y = sin(_bob_t * 2.4) * 11.0

func _load_tex_robust(path: String) -> Texture2D:
	# Prefer the imported resource if one exists; otherwise load the raw PNG via
	# FileAccess (these cutouts have no .import sidecar). Guard load() with
	# ResourceLoader.exists so it doesn't spam "No loader found" errors.
	if ResourceLoader.exists(path):
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
