extends Area2D

# One-shot floor trap. Damages anything overlapping when first stepped on,
# then stays visible (sprung) so it isn't a surprise the second time.

@export var damage: int = 1

@onready var idle_v: Node2D = $Idle
@onready var spikes_v: Node2D = $Spikes

var _triggered: bool = false

func _ready() -> void:
	idle_v.visible = true
	spikes_v.visible = false
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _triggered:
		return
	if not body.has_method("take_damage"):
		return
	_triggered = true
	idle_v.visible = false
	spikes_v.visible = true
	for b in get_overlapping_bodies():
		if b.has_method("take_damage"):
			b.take_damage(damage)
