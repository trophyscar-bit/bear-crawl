extends Node

# GitHub-Releases auto-updater (autoload: Updater).
#
# On launch it checks the latest release tag against GameSettings.VERSION. If a
# newer build exists it pops a SPLASH over the title screen — Update Now downloads
# the new .exe in-game, then a 5s countdown (or button) relaunches into it. The
# running exe is locked, so the actual swap is done by a tiny batch in the gap
# between close and reopen. In the editor it just opens the releases page.

const OWNER := "trophyscar-bit"
const REPO := "bear-crawl"

signal status_changed(message: String, update_available: bool)

var _http: HTTPRequest
var _busy: bool = false
var _mode: String = ""
var _latest_tag: String = ""
var _exe_url: String = ""
var _download_path: String = ""

# Splash UI
var _overlay: CanvasLayer = null
var _panel_vbox: VBoxContainer = null
var _relaunch_t: float = 0.0
var _relaunching: bool = false

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	# Auto-check shortly after launch (give the title screen a beat to appear).
	get_tree().create_timer(1.3).timeout.connect(check_for_updates)

func current_version() -> String:
	return GameSettings.VERSION

func releases_url() -> String:
	return "https://github.com/%s/%s/releases/latest" % [OWNER, REPO]

# ── version check ───────────────────────────────────────────────────────────
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
			_show_update_splash()
		else:
			emit_signal("status_changed", "Up to date (v%s)" % current_version(), false)
	elif _mode == "download":
		_busy = false
		_http.download_file = ""
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			_set_panel("Download failed.", "Couldn't fetch the update — try again later.", [
				{"text": "Close", "cb": _close_overlay}])
			return
		# Guard: the exe is ~400 MB. Anything tiny means a redirect page / partial
		# download — swapping that in would brick the install, so reject it.
		var sz: int = 0
		var df := FileAccess.open(_download_path, FileAccess.READ)
		if df != null:
			sz = df.get_length()
			df.close()
		if sz < 50_000_000:
			_set_panel("Download failed.", "The update looked incomplete (%d KB). Please try again." % int(sz / 1024), [
				{"text": "Close", "cb": _close_overlay}])
			return
		_show_relaunch_prompt()

# ── splash UI ───────────────────────────────────────────────────────────────
func _show_update_splash() -> void:
	if _overlay != null:
		return
	# In the editor (or with no packaged exe) we can't self-replace a binary — just
	# point at the releases page if the user manually asks.
	if OS.has_feature("editor") or _exe_url == "":
		return
	_overlay = CanvasLayer.new()
	_overlay.layer = 200
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.04, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	# Centre via a full-rect CenterContainer so the splash is always on screen at any
	# resolution (the old fixed position pushed it off the edge).
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 250)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.09, 0.13, 0.98)
	sb.set_border_width_all(3); sb.border_color = Color(1.0, 0.82, 0.3)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	_panel_vbox = VBoxContainer.new()
	_panel_vbox.add_theme_constant_override("separation", 16)
	_panel_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(_panel_vbox)
	_set_panel("🐻  UPDATE AVAILABLE", "A new version (v%s) is ready.\nYou're on v%s." % [_latest_tag, current_version()], [
		{"text": "Update Now", "cb": _start_download, "accent": true},
		{"text": "Later", "cb": _close_overlay}])

func _set_panel(title: String, body: String, buttons: Array) -> void:
	if not is_instance_valid(_panel_vbox):
		return
	for c in _panel_vbox.get_children():
		c.queue_free()
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var lf := FontFile.new()
	if lf.load_dynamic_font("res://assets/anton.ttf") == OK:
		t.add_theme_font_override("font", lf)
	_panel_vbox.add_child(t)
	var b := Label.new()
	b.text = body
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Color(0.86, 0.88, 0.94))
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel_vbox.add_child(b)
	if not buttons.is_empty():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		_panel_vbox.add_child(row)
		for spec in buttons:
			var btn := Button.new()
			btn.text = String(spec.get("text", "OK"))
			btn.custom_minimum_size = Vector2(180, 46)
			btn.add_theme_font_size_override("font_size", 20)
			btn.focus_mode = Control.FOCUS_NONE
			if bool(spec.get("accent", false)):
				btn.add_theme_color_override("font_color", Color(0.1, 0.08, 0.02))
				var bsb := StyleBoxFlat.new()
				bsb.bg_color = Color(1.0, 0.82, 0.3); bsb.set_corner_radius_all(8); bsb.set_content_margin_all(8)
				btn.add_theme_stylebox_override("normal", bsb)
				btn.add_theme_stylebox_override("hover", bsb)
			var cb: Callable = spec["cb"]
			btn.pressed.connect(cb)
			row.add_child(btn)

# ── download + relaunch ─────────────────────────────────────────────────────
func _start_download() -> void:
	if _busy:
		return
	_busy = true
	_mode = "download"
	_set_panel("DOWNLOADING…", "Fetching v%s. This is a big file — hang tight." % _latest_tag, [])
	_download_path = OS.get_executable_path().get_base_dir().path_join("BEAR_GAME_update.exe")
	_http.download_file = _download_path
	if _http.request(_exe_url, PackedStringArray(["User-Agent: bear-crawl-updater"])) != OK:
		_busy = false
		_http.download_file = ""
		_set_panel("Download failed.", "Couldn't start the download.", [{"text": "Close", "cb": _close_overlay}])

func _show_relaunch_prompt() -> void:
	_relaunch_t = 5.0
	_relaunching = true
	_set_panel("UPDATE READY!", "Relaunching in 5…", [{"text": "Relaunch Now", "cb": _apply_update, "accent": true}])

func _process(delta: float) -> void:
	if not _relaunching:
		return
	_relaunch_t -= delta
	if is_instance_valid(_panel_vbox) and _panel_vbox.get_child_count() > 1:
		var lbl := _panel_vbox.get_child(1) as Label
		if lbl != null:
			lbl.text = "Relaunching in %d…" % maxi(0, ceili(_relaunch_t))
	if _relaunch_t <= 0.0:
		_relaunching = false
		_apply_update()

func _apply_update() -> void:
	_relaunching = false
	var exe := OS.get_executable_path()
	var dir := exe.get_base_dir()
	var name := exe.get_file()                        # e.g. BEAR_GAME.exe
	var old_name := name.get_basename() + "_old.exe"  # BEAR_GAME_old.exe
	var old_full := dir.path_join(old_name)
	var log := dir.path_join("_bearcrawl_update.log")
	var bat := dir.path_join("_bearcrawl_update.bat")
	var q := "\""
	# Windows lets you RENAME a running .exe even though it can't be OVERWRITTEN —
	# so rename the live exe aside, drop the new build into its place, then relaunch.
	# This sidesteps the file lock that made the old move-based swap silently fail
	# and relaunch the old version. A safety branch restores the backup if the move
	# didn't land, and every step is logged to _bearcrawl_update.log for diagnosis.
	# Built with plain concatenation (no % format operator) to avoid batch %-escaping.
	var s := "@echo off\r\n"
	s += "echo Bear Crawl updater > " + q + log + q + "\r\n"
	s += "del /f /q " + q + old_full + q + " >nul 2>&1\r\n"
	s += "timeout /t 1 /nobreak >nul\r\n"
	# Try to rename the live exe aside (works on a running exe via FILE_SHARE_DELETE).
	s += "ren " + q + exe + q + " " + q + old_name + q + " >> " + q + log + q + " 2>&1\r\n"
	# Drop the new build in. If the rename didn't free the name (exe still locked),
	# the move retries until the game process fully exits and releases the lock.
	s += "set tries=0\r\n"
	s += ":movetry\r\n"
	s += "move /y " + q + _download_path + q + " " + q + exe + q + " >> " + q + log + q + " 2>&1\r\n"
	s += "if not exist " + q + _download_path + q + " goto launch\r\n"
	s += "set /a tries+=1\r\n"
	s += "if %tries% geq 30 goto launch\r\n"
	s += "timeout /t 1 /nobreak >nul\r\n"
	s += "goto movetry\r\n"
	s += ":launch\r\n"
	# Safety: if the new exe somehow isn't in place, restore the backup so the
	# install isn't bricked.
	s += "if not exist " + q + exe + q + " ren " + q + old_full + q + " " + q + name + q + "\r\n"
	s += "start " + q + q + " " + q + exe + q + "\r\n"
	s += "del /f /q " + q + old_full + q + " >nul 2>&1\r\n"
	s += "del /f /q " + q + bat + q + "\r\n"
	var f := FileAccess.open(bat, FileAccess.WRITE)
	if f == null:
		_set_panel("Update failed.", "Couldn't write the updater script.", [{"text": "Close", "cb": _close_overlay}])
		return
	f.store_string(s)
	f.close()
	OS.create_process("cmd.exe", ["/c", bat])
	get_tree().quit()

func _close_overlay() -> void:
	_relaunching = false
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_panel_vbox = null

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
