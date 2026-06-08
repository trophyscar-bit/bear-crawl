extends Node2D

# Plays the Fire-bomb burst (free pixel FX pack — frames 8-14 of the Fire-bomb
# animation, the orange fireball only). Same external API as before:
# `start_scale`, `end_scale`, `duration`, and `modulate` (tint) all still work.

const FX_DIR := "res://assets/fx/firebomb/"
# 64px frames vs the old 100px sheet — bump the base so on-screen size matches.
const BASE_SCALE_MULT: float = 1.7

@export var duration: float = 0.48
@export var start_scale: float = 0.45
@export var end_scale: float = 4.8

@onready var sprite: Sprite2D = $Sprite
@onready var _flash: PointLight2D = get_node_or_null("Flash")

var _frames: Array[Texture2D] = []
var _t: float = 0.0
var _flash_energy0: float = 3.0

func _ready() -> void:
	_frames = _load_frames(FX_DIR)
	# Single-frame sprite — we swap the texture each step (no sheet hframes).
	sprite.hframes = 1
	sprite.vframes = 1
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not _frames.is_empty():
		sprite.texture = _frames[0]
	sprite.scale = Vector2(start_scale, start_scale) * BASE_SCALE_MULT
	# AAA pop: warm HDR overdrive so flames bloom through the glow pass.
	sprite.self_modulate = Color(1.28, 1.16, 1.04)
	Juice.shake(clampf(end_scale * 0.08, 0.08, 0.7))
	if end_scale >= 3.0:
		Juice.ca_pulse(clampf(end_scale * 0.6, 3.0, 6.0))
	if _flash != null:
		_flash.texture_scale = clampf(end_scale * 0.9, 1.5, 8.0)
		_flash_energy0 = clampf(end_scale * 0.6, 1.5, 5.0)
		_flash.energy = _flash_energy0

func _process(delta: float) -> void:
	_t += delta
	var p: float = clamp(_t / duration, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - p, 2.6)   # ease-out scale
	var s: float = lerp(start_scale, end_scale, eased) * BASE_SCALE_MULT
	sprite.scale = Vector2(s, s)
	if not _frames.is_empty():
		var idx: int = clampi(int(p * float(_frames.size())), 0, _frames.size() - 1)
		sprite.texture = _frames[idx]
	if _flash != null:
		_flash.energy = _flash_energy0 * clampf(1.0 - p / 0.6, 0.0, 1.0)
	if _t >= duration:
		queue_free()

func _load_frames(dir: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var names: Array[String] = []
	var da := DirAccess.open(dir)
	if da == null:
		return out
	da.list_dir_begin()
	var fn := da.get_next()
	while fn != "":
		if fn.to_lower().ends_with(".png"):
			names.append(fn)
		fn = da.get_next()
	da.list_dir_end()
	names.sort()
	for n in names:
		var f := FileAccess.open(dir + n, FileAccess.READ)
		if f == null:
			continue
		var img := Image.new()
		if img.load_png_from_buffer(f.get_buffer(f.get_length())) == OK:
			out.append(ImageTexture.create_from_image(img))
	return out
