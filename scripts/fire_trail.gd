extends Area2D

# Animated fire patch left by the final boss during a dash.
# Plays the 60-frame fire1_64 sheet (10 cols × 6 rows) at ~14 fps,
# damages anything in it on body_entered (player i-frames handle re-entry),
# fades alpha in the last second, despawns after `lifetime` seconds.

@export var lifetime: float = 5.0
@export var damage: int = 1
@export var fade_after: float = 4.0
@export var fps: float = 14.0
# Growth: the fire grows from start_scale to peak_scale over grow_for seconds,
# so a fresh trail patch is small and harmless-looking, then becomes a real
# zone-control threat as it matures. Tunes the existing fire-trail layer the
# final boss leaves while sprinting.
@export var start_scale: float = 0.55
@export var peak_scale: float = 1.55
@export var grow_for: float = 3.0   # seconds to reach peak_scale
# Collision radius scales WITH the visible flame so the danger zone matches.
const BASE_COLLISION_RADIUS: float = 22.0

@onready var sprite: Sprite2D = $Sprite
@onready var collision: CollisionShape2D = $CollisionShape2D

var _t: float = 0.0
var _frame_t: float = 0.0
var _base_sprite_scale: Vector2 = Vector2.ONE
var _base_circle_shape: CircleShape2D = null
const TOTAL_FRAMES: int = 60

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# random starting frame so multiple fire patches don't pulse in sync
	sprite.frame = randi() % TOTAL_FRAMES
	_base_sprite_scale = sprite.scale
	# Duplicate the collision shape so per-instance resizing doesn't mutate
	# the shared resource across all fire patches in the room.
	if is_instance_valid(collision) and collision.shape is CircleShape2D:
		var dup := (collision.shape as CircleShape2D).duplicate() as CircleShape2D
		collision.shape = dup
		_base_circle_shape = dup
	_apply_growth_scale(start_scale)

func _process(delta: float) -> void:
	_t += delta
	_frame_t += delta
	if _frame_t >= 1.0 / fps:
		_frame_t = 0.0
		sprite.frame = (sprite.frame + 1) % TOTAL_FRAMES
	# Growth — ease-out so the flame ramps fast then settles at peak_scale
	if _t < grow_for:
		var gp: float = clamp(_t / grow_for, 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - gp, 2.2)
		var s: float = lerp(start_scale, peak_scale, eased)
		_apply_growth_scale(s)
	if _t > fade_after:
		var ratio: float = clamp(1.0 - (_t - fade_after) / max(0.001, lifetime - fade_after), 0.0, 1.0)
		modulate.a = ratio
	if _t >= lifetime:
		queue_free()

func _apply_growth_scale(s: float) -> void:
	if is_instance_valid(sprite):
		sprite.scale = _base_sprite_scale * s
	if _base_circle_shape != null:
		_base_circle_shape.radius = BASE_COLLISION_RADIUS * s

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
