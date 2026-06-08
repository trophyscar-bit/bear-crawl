extends Node

# Autoloaded singleton — accessed as DevState.* from any script.
# Holds dev/testing toggles. Off by default.

var invincible: bool = false
var oneshot_kills: bool = false
var no_enemies: bool = false
var auto_pickup: bool = false
var show_fps: bool = false
# Dev test arena: penned enemies always "see" the player (LOS bypass) so they
# perform their attacks on cue when you walk up to their box.
var arena_mode: bool = false

func reset() -> void:
	invincible = false
	oneshot_kills = false
	no_enemies = false
	auto_pickup = false
	show_fps = false
	arena_mode = false
