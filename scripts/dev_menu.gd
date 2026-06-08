extends CanvasLayer

# Dev/test menu — opened with Esc during play. Pauses the game.
# Main scene gives us a reference (`main_ref`) so we can invoke its dev helpers.

var main_ref: Node = null

@onready var invincible_btn: CheckButton = $Center/Panel/VBox/Invincible
@onready var oneshot_btn: CheckButton = $Center/Panel/VBox/OneShot
@onready var no_enemies_btn: CheckButton = $Center/Panel/VBox/NoEnemies
@onready var auto_pickup_btn: CheckButton = $Center/Panel/VBox/AutoPickup
@onready var heal_btn: Button = $Center/Panel/VBox/HealButton
@onready var skip_btn: Button = $Center/Panel/VBox/SkipFloor
@onready var spawn_boss_btn: Button = $Center/Panel/VBox/SpawnBoss
@onready var give_boon_btn: Button = $Center/Panel/VBox/GiveBoon
@onready var give_bombs_btn: Button = $Center/Panel/VBox/GiveBombs
@onready var give_scatter_btn: Button = $Center/Panel/VBox/GiveScatter
@onready var give_homing_btn: Button = $Center/Panel/VBox/GiveHoming
@onready var kill_all_btn: Button = $Center/Panel/VBox/KillAll
@onready var resume_btn: Button = $Center/Panel/VBox/Resume

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# initialise toggles from current DevState
	invincible_btn.button_pressed = DevState.invincible
	oneshot_btn.button_pressed = DevState.oneshot_kills
	no_enemies_btn.button_pressed = DevState.no_enemies
	auto_pickup_btn.button_pressed = DevState.auto_pickup

	invincible_btn.toggled.connect(func(p): DevState.invincible = p)
	oneshot_btn.toggled.connect(func(p): DevState.oneshot_kills = p)
	no_enemies_btn.toggled.connect(func(p): DevState.no_enemies = p)
	auto_pickup_btn.toggled.connect(func(p): DevState.auto_pickup = p)

	heal_btn.pressed.connect(_on_heal)
	skip_btn.pressed.connect(_on_skip)
	spawn_boss_btn.pressed.connect(_on_spawn_boss)
	give_boon_btn.pressed.connect(_on_give_boon)
	give_bombs_btn.pressed.connect(_on_give_bombs)
	give_scatter_btn.pressed.connect(_on_give_scatter)
	give_homing_btn.pressed.connect(_on_give_homing)
	kill_all_btn.pressed.connect(_on_kill_all)
	resume_btn.pressed.connect(_close)

	resume_btn.grab_focus()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_close()
			get_viewport().set_input_as_handled()

func _close() -> void:
	get_tree().paused = false
	queue_free()

func _on_heal() -> void:
	if main_ref and main_ref.has_method("dev_heal_player"):
		main_ref.dev_heal_player()

func _on_skip() -> void:
	if main_ref and main_ref.has_method("dev_skip_floor"):
		main_ref.dev_skip_floor()
	_close()

func _on_spawn_boss() -> void:
	if main_ref and main_ref.has_method("dev_spawn_boss"):
		main_ref.dev_spawn_boss()

func _on_give_boon() -> void:
	if main_ref and main_ref.has_method("dev_give_random_boon"):
		main_ref.dev_give_random_boon()

func _on_give_bombs() -> void:
	if main_ref and main_ref.has_method("dev_grant_special"):
		main_ref.dev_grant_special("bomb", 5)

func _on_give_scatter() -> void:
	if main_ref and main_ref.has_method("dev_grant_special"):
		main_ref.dev_grant_special("scatter", 8)

func _on_give_homing() -> void:
	if main_ref and main_ref.has_method("dev_grant_special"):
		main_ref.dev_grant_special("homing", 6)

func _on_kill_all() -> void:
	if main_ref and main_ref.has_method("dev_kill_all_enemies"):
		main_ref.dev_kill_all_enemies()
