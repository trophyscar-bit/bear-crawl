extends CanvasLayer

signal restart_requested
signal menu_requested

@export var depth: int = 1

@onready var depth_label: Label = $Center/Layout/DepthLabel
@onready var stats_label: Label = $Center/Layout/StatsLabel
@onready var restart_btn: Button = $Center/Layout/Buttons/RestartButton
@onready var menu_btn: Button = $Center/Layout/Buttons/MenuButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	depth_label.text = "Reached Floor %d" % depth
	stats_label.text = _summary_text()
	restart_btn.pressed.connect(_emit_restart)
	menu_btn.pressed.connect(_emit_menu)
	restart_btn.grab_focus()

func _summary_text() -> String:
	var t: float = RunState.stats_run_seconds
	var m: int = int(t) / 60
	var s: int = int(t) % 60
	return "Enemies KO'd  %d\nBombs thrown  %d\nFluff earned  %d\nRun time  %d:%02d\n\nBest floor  %d   |   Total Fluff  %d" % [
		RunState.stats_enemies_killed,
		RunState.stats_bombs_thrown,
		RunState.stats_fluff_earned,
		m, s,
		MetaSave.best_floor,
		MetaSave.total_fluff,
	]

func _emit_restart() -> void:
	restart_requested.emit()

func _emit_menu() -> void:
	menu_requested.emit()

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and (event as InputEventKey).pressed):
		return
	var key: int = (event as InputEventKey).keycode
	if key == KEY_R:
		_emit_restart()
		get_viewport().set_input_as_handled()
	elif key == KEY_ESCAPE:
		_emit_menu()
		get_viewport().set_input_as_handled()
	elif key == KEY_A or key == KEY_LEFT:
		restart_btn.grab_focus()
		get_viewport().set_input_as_handled()
	elif key == KEY_D or key == KEY_RIGHT:
		menu_btn.grab_focus()
		get_viewport().set_input_as_handled()
