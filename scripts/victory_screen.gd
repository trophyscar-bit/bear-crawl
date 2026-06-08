extends CanvasLayer

signal restart_requested
signal menu_requested

@export var fluff_reward: int = 25
@export var cotton_reward: int = 50
@export var ascension_beaten: int = 0

@onready var stats_label: Label = $Center/Layout/StatsLabel
@onready var reward_label: Label = $Center/Layout/RewardLabel
@onready var restart_btn: Button = $Center/Layout/Buttons/RestartButton
@onready var menu_btn: Button = $Center/Layout/Buttons/MenuButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	stats_label.text = _summary_text()
	var asc_tag: String = ("   |   Ascension %d cleared" % ascension_beaten) if ascension_beaten > 0 else ""
	reward_label.text = "[ +%d Fluff   +%d Cotton Threads ]\nVictories total: %d%s" % [
		fluff_reward, cotton_reward, MetaSave.times_beaten, asc_tag
	]
	restart_btn.pressed.connect(func(): restart_requested.emit())
	menu_btn.pressed.connect(func(): menu_requested.emit())
	restart_btn.grab_focus()

func _summary_text() -> String:
	var t: float = RunState.stats_run_seconds
	var m: int = int(t) / 60
	var s: int = int(t) % 60
	return "Enemies KO'd  %d\nBombs thrown  %d\nFluff earned  %d\nRun time  %d:%02d" % [
		RunState.stats_enemies_killed,
		RunState.stats_bombs_thrown,
		RunState.stats_fluff_earned,
		m, s,
	]

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and (event as InputEventKey).pressed):
		return
	var key: int = (event as InputEventKey).keycode
	if key == KEY_R or key == KEY_ENTER or key == KEY_KP_ENTER:
		restart_requested.emit()
		get_viewport().set_input_as_handled()
	elif key == KEY_ESCAPE:
		menu_requested.emit()
		get_viewport().set_input_as_handled()
	elif key == KEY_A or key == KEY_LEFT:
		restart_btn.grab_focus()
		get_viewport().set_input_as_handled()
	elif key == KEY_D or key == KEY_RIGHT:
		menu_btn.grab_focus()
		get_viewport().set_input_as_handled()
