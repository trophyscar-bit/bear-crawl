extends Area2D

# Telegraphed cyclic floor spike trap for the dungeon. Cycle: dormant plate →
# plate reddens (warning) → spikes stab up (damaging) → retract. Always
# telegraphed on a readable rhythm so it's dodgeable, not a cheap-shot.
# Spike art: "Animated traps and obstacles" by Irina Mir (CC-BY 3.0).

const SpikeTex := preload("res://assets/trap_spikes.png")

@export var cycle: float = 2.8
@export var damage: int = 1
@export var tile: float = 64.0
@export var phase_offset: float = -1.0   # >=0 → fixed start phase (ripple lines)

var _t: float = 0.0
var _spikes: Sprite2D
var _plate: ColorRect
var _spike_base_y: float = 1.0
var _dmg_cd: float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	z_index = -2
	z_as_relative = false
	_t = phase_offset if phase_offset >= 0.0 else randf() * cycle
	_plate = ColorRect.new()
	_plate.size = Vector2(tile, tile)
	_plate.position = Vector2(-tile / 2.0, -tile / 2.0)
	_plate.color = Color(0.11, 0.10, 0.13)
	add_child(_plate)
	_spikes = Sprite2D.new()
	_spikes.texture = SpikeTex
	_spike_base_y = (tile * 0.94) / float(SpikeTex.get_width())
	_spikes.scale = Vector2(_spike_base_y, _spike_base_y)
	_spikes.offset = Vector2(0, -float(SpikeTex.get_height()) * 0.5)  # rise from floor
	_spikes.position = Vector2(0, tile * 0.45)
	_spikes.modulate = Color(1, 1, 1, 0)
	_spikes.z_index = 1
	add_child(_spikes)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(tile * 0.82, tile * 0.82)
	cs.shape = rect
	add_child(cs)

func _process(delta: float) -> void:
	_t += delta
	if _dmg_cd > 0.0:
		_dmg_cd -= delta
	var p: float = fmod(_t, cycle) / cycle
	if p < 0.62:
		_plate.color = _plate.color.lerp(Color(0.11, 0.10, 0.13), clampf(delta * 8.0, 0, 1))
		_spikes.modulate.a = lerpf(_spikes.modulate.a, 0.0, clampf(delta * 12.0, 0, 1))
		_spikes.scale.y = lerpf(_spikes.scale.y, _spike_base_y * 0.25, clampf(delta * 12.0, 0, 1))
	elif p < 0.78:
		var tp: float = (p - 0.62) / 0.16
		_plate.color = Color(0.11 + 0.28 * tp, 0.09, 0.11)
		_spikes.modulate.a = tp * 0.45
		_spikes.scale.y = _spike_base_y * (0.25 + 0.35 * tp)
	else:
		_spikes.modulate.a = 1.0
		_spikes.scale.y = _spike_base_y
		_plate.color = Color(0.22, 0.09, 0.10)
		if _dmg_cd <= 0.0:
			for b in get_overlapping_bodies():
				if b.is_in_group("player") and b.has_method("take_damage"):
					b.take_damage(damage)
					_dmg_cd = 0.7
					Juice.shake(0.16)
					break
