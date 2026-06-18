extends Node

# Autoloaded singleton — accessed as GameSettings.* from any script.

# Game version. Bump this on every change (2.1, 2.2, 2.3 …). The title screen
# shows it and the auto-updater compares it against the latest GitHub release tag.
const VERSION: String = "3.99"

enum Difficulty { EASY, MEDIUM, HARD }

var difficulty: int = Difficulty.MEDIUM
var selected_weapon: String = "default"  # "default", "scatter", "homing", "bomb"
var ascension: int = 0                    # 0 = no curses, 1-5 stack curses
var health_bar_style: int = 0             # Heart Bar (heart icon + fill bar + N / M)

const ENEMY_COUNT_MULT: Dictionary = {
	Difficulty.EASY: 0.6,    # fewer enemies on Easy (was 0.7)
	Difficulty.MEDIUM: 1.0,
	Difficulty.HARD: 1.35,
}

func enemy_count_multiplier() -> float:
	return ENEMY_COUNT_MULT.get(difficulty, 1.0)

func enemies_throw() -> bool:
	return difficulty == Difficulty.HARD

# MEDIUM-only: trash mobs spit a short-range brown blob (slow, telegraphed,
# easy to dodge but adds real shot-trading pressure). Replaces the lock-on
# AoE slam which felt non-interactive.
func enemies_spit() -> bool:
	return difficulty == Difficulty.MEDIUM

func difficulty_name() -> String:
	match difficulty:
		Difficulty.EASY:
			return "EASY"
		Difficulty.MEDIUM:
			return "MEDIUM"
		Difficulty.HARD:
			return "HARD"
		_:
			return "MEDIUM"

func cycle_difficulty() -> void:
	difficulty = (difficulty + 1) % 3

# ── Gamepad support (PlayStation / Xbox / generic) ──────────────────────────
# Bound at runtime so we don't have to hand-edit the serialized input map. Menus
# already navigate via Godot's built-in ui_* joypad defaults (d-pad + face buttons).
func _ready() -> void:
	_setup_gamepad()

func _setup_gamepad() -> void:
	# Tighter deadzone than the keyboard default so the analog stick feels responsive.
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		if InputMap.has_action(a):
			InputMap.action_set_deadzone(a, 0.2)
	# Left stick + D-pad → movement
	_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_joy_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_joy_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)
	_joy_btn("move_left", JOY_BUTTON_DPAD_LEFT)
	_joy_btn("move_right", JOY_BUTTON_DPAD_RIGHT)
	_joy_btn("move_up", JOY_BUTTON_DPAD_UP)
	_joy_btn("move_down", JOY_BUTTON_DPAD_DOWN)
	# Attack: R1 (bumper), R2 (trigger), and Cross / A — all fire (auto-aim handles dir)
	_joy_btn("attack", JOY_BUTTON_RIGHT_SHOULDER)
	_joy_btn("attack", JOY_BUTTON_A)
	_joy_axis("attack", JOY_AXIS_TRIGGER_RIGHT, 1.0)

func _joy_axis(action: String, axis: int, val: float) -> void:
	if not InputMap.has_action(action):
		return
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = val
	InputMap.action_add_event(action, e)

func _joy_btn(action: String, btn: int) -> void:
	if not InputMap.has_action(action):
		return
	var e := InputEventJoypadButton.new()
	e.button_index = btn
	InputMap.action_add_event(action, e)
