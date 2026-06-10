extends Node

# Always-processing input catcher for the character (TAB) screen. The dungeon
# itself is PAUSABLE so gameplay actually freezes while the screen is open — which
# means the dungeon's own _input can't fire to CLOSE it. This tiny node runs while
# paused and forwards TAB/ESC back to the dungeon to toggle the screen shut.

var target: Node

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB or event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if is_instance_valid(target) and target.has_method("_toggle_stats"):
				target._toggle_stats()
