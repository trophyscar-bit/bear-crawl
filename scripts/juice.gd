extends Node

# Global "game feel" singleton — the cheap tricks that sell impact:
#   • screen shake (trauma-based, decays smoothly, with a touch of roll)
#   • hit-stop (a few ms of near-frozen time on big hits for weight)
# A camera registers itself each room; calls are no-ops until one does, so this
# is safe to call from anywhere (menus, projectiles, bosses) without guards.

var _camera: Camera2D = null
var _trauma: float = 0.0          # 0..1, squared when applied so small hits stay subtle
var _trauma_decay: float = 1.5
var _max_offset: float = 24.0     # px at full trauma
var _max_roll: float = 0.05       # radians at full trauma
var _hitstop_until_ms: int = 0

# Chromatic-aberration pulse on the screen-space post material.
var _post: ShaderMaterial = null
var _ca_base: float = 1.4
var _ca: float = 1.4

func register_camera(cam: Camera2D) -> void:
	_camera = cam

func register_post(mat: ShaderMaterial) -> void:
	_post = mat
	if mat != null:
		var v: Variant = mat.get_shader_parameter("ca_amount")
		if v is float:
			_ca_base = v
			_ca = v

func ca_pulse(amount: float) -> void:
	_ca = max(_ca, amount)

func shake(amount: float) -> void:
	_trauma = clamp(_trauma + amount, 0.0, 1.0)

func hitstop(duration: float = 0.06, scale: float = 0.05) -> void:
	# Drop time scale briefly; recovery is driven off the real clock so it can't
	# stall itself (a scaled timer would decay in slow-mo and freeze forever).
	Engine.time_scale = min(Engine.time_scale, scale)
	_hitstop_until_ms = max(_hitstop_until_ms, Time.get_ticks_msec() + int(duration * 1000.0))

func _process(_delta: float) -> void:
	# Recover from hit-stop on the unscaled wall clock.
	if Engine.time_scale < 1.0 and Time.get_ticks_msec() >= _hitstop_until_ms:
		Engine.time_scale = 1.0
	# Ease chromatic aberration back to its resting value after a pulse.
	if _post != null:
		_ca = lerp(_ca, _ca_base, clampf(_delta * 6.0, 0.0, 1.0))
		_post.set_shader_parameter("ca_amount", _ca)
	if not is_instance_valid(_camera):
		return
	if _trauma > 0.0:
		_trauma = max(_trauma - _trauma_decay * _delta, 0.0)
		var s: float = _trauma * _trauma
		_camera.offset = Vector2(
			_max_offset * s * randf_range(-1.0, 1.0),
			_max_offset * s * randf_range(-1.0, 1.0))
		_camera.rotation = _max_roll * s * randf_range(-1.0, 1.0)
	elif _camera.offset != Vector2.ZERO or _camera.rotation != 0.0:
		_camera.offset = Vector2.ZERO
		_camera.rotation = 0.0
