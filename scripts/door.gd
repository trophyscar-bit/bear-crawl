extends Area2D

signal entered_by_player

const ACTIVATION_DELAY: float = 0.55  # grace period so it doesn't trigger on the player who just dropped the last enemy at centre

var _active: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(ACTIVATION_DELAY).timeout.connect(_activate)

func _activate() -> void:
	_active = true
	# re-check in case the player was already standing on the portal when it activated
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			entered_by_player.emit()
			return

func _on_body_entered(body: Node) -> void:
	if not _active:
		return
	if body.is_in_group("player"):
		entered_by_player.emit()
