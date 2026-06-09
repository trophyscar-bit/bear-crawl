extends "res://scripts/enemy.gd"

# Sword Skeleton — an animated pixel-art melee bruiser. Chases you (walk cycle),
# stops in melee range to wind up a SWORD SWING (damage lands on the connect
# frame, with a white slash VFX baked into the sheet), and plays a full collapse
# animation on death. Built from 48x64 strip sheets (idle/walk/attack/die).

const FW: int = 48
const FH: int = 64
const ANIMS: Dictionary = {
	"idle":   {"path": "res://assets/sword_skel_idle.png",    "frames": 16, "fps": 10.0, "loop": true},
	"walk":   {"path": "res://assets/sword_skel_walk.png",    "frames": 20, "fps": 15.0, "loop": true},
	"attack": {"path": "res://assets/sword_skel_attack1.png", "frames": 20, "fps": 24.0, "loop": false},
	"die":    {"path": "res://assets/sword_skel_die.png",     "frames": 26, "fps": 22.0, "loop": false},
}
const ATTACK_RANGE: float = 82.0
const ATTACK_HIT_FRAME: int = 11     # the swing connect
const ATTACK_DAMAGE: int = 2
const ATTACK_COOLDOWN: float = 1.25

@onready var _rig: Node2D = $Rig
@onready var _spr: Sprite2D = $Rig/Body
var _textures: Dictionary = {}
var _cur: String = ""
var _frame: int = 0
var _frame_t: float = 0.0
var _attacking: bool = false
var _atk_cd: float = 0.0
var _atk_hit_done: bool = false
var _die_started: bool = false
var _death_fade: float = 0.0

func _ready() -> void:
	max_health = 7
	speed = 86.0
	touch_damage = 1
	throws_stars = false
	super._ready()
	# Pin the shared HP bar just over his head (rig scale is large).
	if is_instance_valid(_hpbar_bg):
		_hpbar_bg.position.y = -60.0
	if is_instance_valid(_hpbar_fill):
		_hpbar_fill.position.y = -58.0
	if is_instance_valid(_hpbar_hi):
		_hpbar_hi.position.y = -58.0
	for k in ANIMS.keys():
		_textures[k] = _load_png(String(ANIMS[k]["path"]))
	_set_anim("idle")

func _set_anim(anim: String) -> void:
	if _cur == anim:
		return
	_cur = anim
	_frame = 0
	_frame_t = 0.0
	_atk_hit_done = false
	var t: Texture2D = _textures.get(anim)
	if t != null and is_instance_valid(_spr):
		_spr.texture = t
		_spr.hframes = int(ANIMS[anim]["frames"])
		_spr.vframes = 1
		_spr.frame = 0
		_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

# Advance the current animation; returns true the frame a non-looping anim finishes.
func _step_anim(delta: float) -> bool:
	var info: Dictionary = ANIMS[_cur]
	_frame_t += delta
	var done: bool = false
	if _frame_t >= 1.0 / float(info["fps"]):
		_frame_t -= 1.0 / float(info["fps"])
		_frame += 1
		if _frame >= int(info["frames"]):
			if bool(info["loop"]):
				_frame = 0
			else:
				_frame = int(info["frames"]) - 1
				done = true
		if is_instance_valid(_spr):
			_spr.frame = _frame
	return done

func _physics_process(delta: float) -> void:
	if _dying:
		super._physics_process(delta)   # routes to our _process_death override
		return
	_atk_cd = maxf(0.0, _atk_cd - delta)
	# Mid-swing: hold ground, land the hit on the connect frame, then recover.
	if _attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		_face_player()
		if not _atk_hit_done and _frame >= ATTACK_HIT_FRAME:
			_atk_hit_done = true
			_do_sword_hit()
		if _step_anim(delta):
			_attacking = false
			_atk_cd = ATTACK_COOLDOWN
			_set_anim("idle")
		return
	super._physics_process(delta)   # chase + move + contact chip
	if _dying:
		return
	var d: float = INF
	if is_instance_valid(player):
		d = global_position.distance_to(player.global_position)
	var aggro_ok: bool = (not ArpgState.active) or _aggro_t > 0.0
	if _atk_cd <= 0.0 and d <= ATTACK_RANGE and aggro_ok:
		_attacking = true
		_set_anim("attack")
		return
	if velocity.length() > 8.0:
		_set_anim("walk")
	else:
		_set_anim("idle")
	_step_anim(delta)
	_face_player()

func _face_player() -> void:
	if not is_instance_valid(_rig):
		return
	var dx: float = 0.0
	if is_instance_valid(player):
		dx = player.global_position.x - global_position.x
	if absf(dx) > 4.0:
		_rig.scale.x = absf(_rig.scale.x) * (1.0 if dx > 0.0 else -1.0)

func _do_sword_hit() -> void:
	if not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) <= ATTACK_RANGE + 26.0:
		if player.has_method("take_damage"):
			player.take_damage(ATTACK_DAMAGE)
		Juice.shake(0.06)

# Override the death visual: play the collapse animation, then fade out.
func _process_death(delta: float) -> void:
	if not _die_started:
		_die_started = true
		_set_anim("die")
	var done: bool = _step_anim(delta)
	if done:
		_death_fade += delta
		modulate.a = clampf(1.0 - _death_fade / 0.45, 0.0, 1.0)
		if _death_fade >= 0.45:
			queue_free()

func _load_png(path: String) -> Texture2D:
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
