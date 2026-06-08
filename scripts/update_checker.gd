extends Node

# Lightweight GitHub-Releases auto-updater (autoload: Updater).
#
# Compares GameSettings.VERSION against the latest release tag on the repo. If a
# newer one exists it can download the packaged .exe and self-replace via a small
# batch script (Windows standalone builds only). In the editor it just opens the
# releases page instead of trying to swap a binary.

const OWNER := "trophyscar-bit"
const REPO := "bear-crawl"

signal status_changed(message: String, update_available: bool)

var _http: HTTPRequest
var _busy: bool = false
var _mode: String = ""
var _latest_tag: String = ""
var _exe_url: String = ""
var _download_path: String = ""

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

func current_version() -> String:
	return GameSettings.VERSION

func releases_url() -> String:
	return "https://github.com/%s/%s/releases/latest" % [OWNER, REPO]

func has_update() -> bool:
	return _exe_url != "" and _is_newer(_latest_tag, current_version())

# --- check ------------------------------------------------------------------
func check_for_updates() -> void:
	if _busy:
		return
	_busy = true
	_mode = "check"
	emit_signal("status_changed", "Checking…", false)
	var url := "https://api.github.com/repos/%s/%s/releases/latest" % [OWNER, REPO]
	var headers := PackedStringArray(["User-Agent: bear-crawl-updater", "Accept: application/vnd.github+json"])
	if _http.request(url, headers) != OK:
		_busy = false
		emit_signal("status_changed", "Check failed (offline?)", false)

func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _mode == "check":
		_busy = false
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			emit_signal("status_changed", "Check failed", false)
			return
		var data: Variant = JSON.parse_string(body.get_string_from_utf8())
		if typeof(data) != TYPE_DICTIONARY:
			emit_signal("status_changed", "Check failed", false)
			return
		_latest_tag = str((data as Dictionary).get("tag_name", "")).strip_edges().lstrip("v")
		_exe_url = ""
		for a in (data as Dictionary).get("assets", []):
			if str((a as Dictionary).get("name", "")).to_lower().ends_with(".exe"):
				_exe_url = str((a as Dictionary).get("browser_download_url", ""))
				break
		if _is_newer(_latest_tag, current_version()):
			emit_signal("status_changed", "Update available: v%s" % _latest_tag, true)
		else:
			emit_signal("status_changed", "Up to date (v%s)" % current_version(), false)
	elif _mode == "download":
		_busy = false
		_http.download_file = ""
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			emit_signal("status_changed", "Download failed", false)
			return
		_prompt_restart()

# --- download + self-replace ------------------------------------------------
func download_and_install() -> void:
	if _busy:
		return
	# No packaged exe to pull, or running from the Godot editor (can't swap a live
	# binary) — just open the releases page instead.
	if _exe_url == "" or OS.has_feature("editor"):
		OS.shell_open(releases_url())
		return
	_busy = true
	_mode = "download"
	emit_signal("status_changed", "Downloading v%s…" % _latest_tag, false)
	_download_path = OS.get_executable_path().get_base_dir().path_join("BEAR_GAME_update.exe")
	_http.download_file = _download_path
	if _http.request(_exe_url, PackedStringArray(["User-Agent: bear-crawl-updater"])) != OK:
		_busy = false
		_http.download_file = ""
		emit_signal("status_changed", "Download failed", false)

func _prompt_restart() -> void:
	# Download is on disk — ask before we close + relaunch.
	emit_signal("status_changed", "Update v%s ready" % _latest_tag, true)
	var dlg := ConfirmationDialog.new()
	dlg.title = "Bear Crawl Update"
	dlg.dialog_text = "Update v%s downloaded.\nRestart now to apply it?" % _latest_tag
	dlg.ok_button_text = "Restart now"
	dlg.cancel_button_text = "Later"
	get_tree().root.add_child(dlg)
	dlg.confirmed.connect(func() -> void:
		dlg.queue_free()
		_apply_update())
	dlg.canceled.connect(func() -> void:
		dlg.queue_free()
		emit_signal("status_changed", "Update ready — restart to apply", true))
	dlg.popup_centered()

func _apply_update() -> void:
	var exe := OS.get_executable_path()
	var bat := exe.get_base_dir().path_join("_bearcrawl_update.bat")
	# Wait for the game to close (exe is locked while running), swap, relaunch,
	# then the batch deletes itself.
	var script := "@echo off\r\n" \
		+ "timeout /t 2 /nobreak >nul\r\n" \
		+ "move /y \"%s\" \"%s\"\r\n" % [_download_path, exe] \
		+ "start \"\" \"%s\"\r\n" % exe \
		+ "del \"%%~f0\"\r\n"
	var f := FileAccess.open(bat, FileAccess.WRITE)
	if f == null:
		emit_signal("status_changed", "Update failed", false)
		return
	f.store_string(script)
	f.close()
	emit_signal("status_changed", "Restarting to update…", false)
	OS.create_process("cmd.exe", ["/c", bat])
	get_tree().quit()

func _is_newer(latest: String, current: String) -> bool:
	if latest == "":
		return false
	var la := latest.split(".")
	var ca := current.split(".")
	for i in maxi(la.size(), ca.size()):
		var lv: int = int(la[i]) if i < la.size() else 0
		var cv: int = int(ca[i]) if i < ca.size() else 0
		if lv > cv:
			return true
		if lv < cv:
			return false
	return false
