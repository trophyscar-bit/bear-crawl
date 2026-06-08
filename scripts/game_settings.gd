extends Node

# Autoloaded singleton — accessed as GameSettings.* from any script.

# Game version. Bump this on every change (2.1, 2.2, 2.3 …). The title screen
# shows it and the auto-updater compares it against the latest GitHub release tag.
const VERSION: String = "2.1"

enum Difficulty { EASY, MEDIUM, HARD }

var difficulty: int = Difficulty.MEDIUM
var selected_weapon: String = "default"  # "default", "scatter", "homing", "bomb"
var ascension: int = 0                    # 0 = no curses, 1-5 stack curses
var health_bar_style: int = 0             # locked to Heart Bar (heart icon + fill bar)

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
