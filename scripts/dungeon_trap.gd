extends Area2D

# Telegraphed cyclic floor SPIKE TRAP. Cycle: retracted plate → reddens (warning)
# → spikes stab up (damaging) → retract. Always telegraphed on a readable rhythm
# so it's dodgeable. Uses the animated 14-frame spike sheet (32px frames).

const SHEET_PATH := "res://assets/trap_spike.png"
const FRAMES := 14
const DANGER_P := 0.78   # phase at/after which the spikes are up and hurt
const StuffingBurstScene := preload("res://scenes/stuffing_burst.tscn")
static var _spike_stuff_tex: Texture2D = null   # gif-1 stuffing for spike hits

@export var cycle: float = 2.8
@export var damage: int = 1
@export var tile: float = 64.0
@export var phase_offset: float = -1.0   # >=0 → fixed start phase (ripple lines)

var _t: float = 0.0
var _spr: Sprite2D
var _dmg_cd: float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	z_index = -2
	z_as_relative = false
	add_to_group("hazards")          # enemies dodge it while the spikes are UP
	_t = phase_offset if phase_offset >= 0.0 else randf() * cycle
	_spr = Sprite2D.new()
	_spr.texture = _load_tex(SHEET_PATH)
	_spr.hframes = FRAMES
	_spr.vframes = 1
	_spr.frame = 0
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var s: float = tile / 32.0
	_spr.scale = Vector2(s, s)
	add_child(_spr)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(tile * 0.82, tile * 0.82)
	cs.shape = rect
	add_child(cs)

func is_dangerous() -> bool:
	return fmod(_t, cycle) / cycle >= DANGER_P

func _frame_for(p: float) -> int:
	if p < 0.62:
		return 0
	if p < DANGER_P:
		return clampi(int((p - 0.62) / 0.16 * 8.0), 0, 8)        # rising
	if p < 0.90:
		return clampi(8 + int((p - DANGER_P) / 0.12 * 3.0), 8, 11)  # fully up
	return clampi(11 + int((p - 0.90) / 0.10 * 3.0), 11, 13)         # retracting

func _process(delta: float) -> void:
	_t += delta
	if _dmg_cd > 0.0:
		_dmg_cd -= delta
	var p: float = fmod(_t, cycle) / cycle
	if is_instance_valid(_spr):
		_spr.frame = _frame_for(p)
		# Redden as a warning telegraph just before the spikes come up.
		if p >= 0.62 and p < DANGER_P:
			var tp: float = (p - 0.62) / (DANGER_P - 0.62)
			_spr.modulate = Color(1.0, 1.0 - 0.45 * tp, 1.0 - 0.5 * tp)
		elif p >= DANGER_P:
			_spr.modulate = Color(1.0, 0.78, 0.74)
		else:
			_spr.modulate = Color(1, 1, 1)
	# Damage while the spikes are up.
	if p >= DANGER_P and _dmg_cd <= 0.0:
		for b in get_overlapping_bodies():
			if b.is_in_group("player") and b.has_method("take_damage"):
				b.take_damage(damage)
				_spike_stuffing((b as Node2D).global_position)
				_dmg_cd = 0.7
				Juice.shake(0.16)
				break

func _spike_stuffing(pos: Vector2) -> void:
	if _spike_stuff_tex == null:
		_spike_stuff_tex = _load_tex("res://assets/stuffing_spike.png")
	if _spike_stuff_tex == null or not is_instance_valid(get_parent()):
		return
	var s := StuffingBurstScene.instantiate()
	s.texture = _spike_stuff_tex
	s.global_position = pos
	s.scale = Vector2.ONE * 1.8
	s.rotation = randf() * TAU
	s.z_index = 5
	get_parent().add_child(s)

func _load_tex(path: String) -> Texture2D:
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
