extends Control

# Dev-mode level select. Jump straight into the new/demo levels to test them
# without playing through the normal game. Reached via the title's DEV MODE button.

func _ready() -> void:
	$Panel/VBox/Dungeon.pressed.connect(_go.bind("res://scenes/dungeon.tscn"))
	$Panel/VBox/DungeonLarge.pressed.connect(_go.bind("res://scenes/dungeon_large.tscn"))
	$Panel/VBox/Backrooms.pressed.connect(_go.bind("res://scenes/backrooms.tscn"))
	$Panel/VBox/Game.pressed.connect(_go.bind("res://scenes/main.tscn"))
	$Panel/VBox/Back.pressed.connect(_go.bind("res://scenes/title_screen.tscn"))
	$Panel/VBox/Dungeon.grab_focus()

func _go(path: String) -> void:
	# Entering a dungeon / the backrooms starts a fresh ARPG run.
	if path.contains("dungeon") or path.contains("backrooms"):
		ArpgState.reset_run()
	else:
		ArpgState.active = false
	get_tree().change_scene_to_file(path)

# Escape intentionally does NOT auto-return to the title here — use the explicit
# "Back to Title" button so you don't get kicked to the main menu by accident.
