extends Node

# Autoload "Telemetry" — anonymous gameplay-stats upload.
#
# Sends the lifetime Stats blob to a private endpoint you host (e.g. a PHP script
# on Bluehost), keyed by a random per-install UUID. NO personal data, NO hardware
# fingerprint — just the game metrics. Disabled until you set ENDPOINT, and the
# player can opt out (Telemetry.set_enabled(false)).
#
# Set ENDPOINT + SHARED_KEY below to your own values to turn it on.

const ENDPOINT: String = ""                  # e.g. "https://mattkelly.com/bc/telemetry.php"
const SHARED_KEY: String = "CHANGE_ME"        # must match the server script
const ID_PATH := "user://install_id.txt"
const PREF_PATH := "user://telemetry_optout.txt"
const MIN_INTERVAL := 30.0                    # don't spam the server

var install_id: String = ""
var enabled: bool = true
var _http: HTTPRequest
var _last_send: float = -1000.0

func _ready() -> void:
	randomize()
	install_id = _load_or_make_id()
	enabled = not _opted_out()
	_http = HTTPRequest.new()
	add_child(_http)

func _load_or_make_id() -> String:
	if FileAccess.file_exists(ID_PATH):
		var f := FileAccess.open(ID_PATH, FileAccess.READ)
		if f != null:
			var s := f.get_as_text().strip_edges()
			f.close()
			if s != "":
				return s
	var id := _uuid()
	var w := FileAccess.open(ID_PATH, FileAccess.WRITE)
	if w != null:
		w.store_string(id); w.close()
	return id

func _uuid() -> String:
	var s := ""
	for i in 16:
		s += "%02x" % (randi() % 256)
	return s

func _opted_out() -> bool:
	return FileAccess.file_exists(PREF_PATH)

func set_enabled(on: bool) -> void:
	enabled = on
	if on:
		if FileAccess.file_exists(PREF_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PREF_PATH))
	else:
		var f := FileAccess.open(PREF_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string("1"); f.close()

# Fire-and-forget upload of the cumulative lifetime stats (overwrites server-side).
func send(stats: Dictionary) -> void:
	if not enabled or ENDPOINT == "":
		return
	var now := float(Time.get_ticks_msec()) / 1000.0
	if now - _last_send < MIN_INTERVAL:
		return
	_last_send = now
	var payload := {
		"id": install_id,
		"key": SHARED_KEY,
		"version": GameSettings.VERSION,
		"ts": int(Time.get_unix_time_from_system()),
		"stats": stats,
	}
	var headers := ["Content-Type: application/json"]
	_http.request(ENDPOINT, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
