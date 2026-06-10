extends Node

# Autoload "Telemetry" — gameplay-stats upload (PRIVATE TESTING build).
#
# Sends the lifetime Stats blob to a private endpoint you host (e.g. a PHP script
# on Bluehost), keyed by a random per-install UUID (no hardware fingerprint).
# This build is for private testers, so it just always reports while an ENDPOINT
# is set — no in-game toggle or notice. ENDPOINT empty = off (the master switch).

const ENDPOINT: String = "https://mattkelly.com/bc/telemetry.php"
const SHARED_KEY: String = "mk-bc-7x9qR2wNpL"   # must match the server script
const ID_PATH := "user://install_id.txt"
const MIN_INTERVAL := 30.0                    # don't spam the server

var install_id: String = ""
var _http: HTTPRequest
var _last_send: float = -1000.0

func _ready() -> void:
	randomize()
	install_id = _load_or_make_id()
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

# Fire-and-forget upload of the cumulative lifetime stats (overwrites server-side).
func send(stats: Dictionary) -> void:
	if ENDPOINT == "":
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
	if _http == null:                 # defensive: created in _ready, but never assume
		_http = HTTPRequest.new()
		add_child(_http)
	var headers := ["Content-Type: application/json"]
	_http.request(ENDPOINT, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
