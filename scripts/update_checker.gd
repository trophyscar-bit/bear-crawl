extends Node

# Autoload "Updater" — SILENT auto-update.
#
# On launch it checks GitHub Releases against GameSettings.VERSION. If a newer build
# exists it covers the whole screen with a cute "updating" animation (flipping
# bears + a download bar), auto-downloads the new .exe, swaps it in, and relaunches
# straight into it — no prompts, no buttons. Any failure just dismisses silently and
# lets the player keep playing the current build. In the editor it does nothing.
#
# The running exe is locked, so the swap is done by a tiny batch in the gap between
# close and reopen: rename the live exe aside (allowed while running), drop the new
# one in (retry until the lock releases), relaunch, restore-on-failure.

const OWNER := "trophyscar-bit"
const REPO := "bear-crawl"

signal status_changed(message: String, update_available: bool)

var _http: HTTPRequest
var _busy: bool = false
var _mode: String = ""
var _latest_tag: String = ""
var _exe_url: String = ""
var _download_path: String = ""

# ── overlay state ─────────────────────────────────────────────────────────────
var _overlay: CanvasLayer = null
var _bears: Array[Sprite2D] = []
var _bear_base: Array[Vector2] = []
var _status: Label = null
var _bar_fill: ColorRect = null
var _bar_w: float = 440.0
var _anim_t: float = 0.0
var _downloading: bool = false

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Check almost immediately so the update screen comes up before they settle in.
	get_tree().create_timer(0.5).timeout.connect(check_for_updates)

func current_version() -> String:
	return GameSettings.VERSION

func releases_url() -> String:
	return "https://github.com/%s/%s/releases/latest" % [OWNER, REPO]

# ── version check ─────────────────────────────────────────────────────────────
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

func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _mode == "check":
		_busy = false
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			return
		var data: Variant = JSON.parse_string(body.get_string_from_utf8())
		if typeof(data) != TYPE_DICTIONARY:
			return
		_latest_tag = str((data as Dictionary).get("tag_name", "")).strip_edges().lstrip("v")
		_exe_url = ""
		for a in (data as Dictionary).get("assets", []):
			if str((a as Dictionary).get("name", "")).to_lower().ends_with(".exe"):
				_exe_url = str((a as Dictionary).get("browser_download_url", ""))
				break
		if _is_newer(_latest_tag, current_version()) and not OS.has_feature("editor") and _exe_url != "":
			emit_signal("status_changed", "Updating to v%s" % _latest_tag, true)
			_begin_auto_update()
		else:
			emit_signal("status_changed", "Up to date (v%s)" % current_version(), false)
	elif _mode == "download":
		_busy = false
		_downloading = false
		_http.download_file = ""
		# Any failure → dismiss silently, let them play the current build.
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			_close_overlay()
			return
		var sz: int = 0
		var df := FileAccess.open(_download_path, FileAccess.READ)
		if df != null:
			sz = df.get_length()
			df.close()
		if sz < 50_000_000:   # exe is ~400 MB; tiny = redirect page / partial → abort
			_close_overlay()
			return
		_apply_update()

# ── cute updating overlay ─────────────────────────────────────────────────────
func _begin_auto_update() -> void:
	if _overlay != null:
		return
	_build_overlay()
	_start_download()

func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 200
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_overlay)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.5

	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.05, 0.10, 1.0)   # fully covers the title screen
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)

	var lf := FontFile.new()
	var has_font: bool = lf.load_dynamic_font("res://assets/anton.ttf") == OK

	var title := Label.new()
	title.text = "UPDATING…"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	if has_font:
		title.add_theme_font_override("font", lf)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(vp.x, 70)
	title.position = Vector2(0, cy - 180)
	_overlay.add_child(title)

	# Flipping bears (graceful: skipped if the texture won't load).
	_bears.clear()
	_bear_base.clear()
	var btex: Texture2D = _bear_tex()
	if btex != null:
		var longest: float = float(maxi(btex.get_width(), btex.get_height()))
		for i in 3:
			var s := Sprite2D.new()
			s.texture = btex
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			s.scale = Vector2.ONE * (118.0 / maxf(1.0, longest))
			s.position = Vector2(cx + (float(i) - 1.0) * 160.0, cy)
			_overlay.add_child(s)
			_bears.append(s)
			_bear_base.append(s.position)

	_status = Label.new()
	_status.text = "Downloading v%s…" % _latest_tag
	_status.add_theme_font_size_override("font_size", 22)
	_status.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.size = Vector2(vp.x, 30)
	_status.position = Vector2(0, cy + 120)
	_overlay.add_child(_status)

	var track := ColorRect.new()
	track.color = Color(1, 1, 1, 0.12)
	track.size = Vector2(_bar_w, 14)
	track.position = Vector2(cx - _bar_w * 0.5, cy + 160)
	_overlay.add_child(track)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(1.0, 0.82, 0.3)
	_bar_fill.size = Vector2(0, 14)
	_bar_fill.position = track.position
	_overlay.add_child(_bar_fill)

func _bear_tex() -> Texture2D:
	for p in ["res://assets/dark_bear.png", "res://assets/bear_portrait.png"]:
		if ResourceLoader.exists(p):
			var t := load(p) as Texture2D
			if t != null:
				return t
		if FileAccess.file_exists(p):
			var b := FileAccess.get_file_as_bytes(p)
			if b.size() > 0:
				var img := Image.new()
				if img.load_png_from_buffer(b) == OK:
					return ImageTexture.create_from_image(img)
	return null

func _process(delta: float) -> void:
	if _overlay == null:
		return
	_anim_t += delta
	# Bears spin, flip, and bob — playful "working on it" motion.
	for i in _bears.size():
		var s := _bears[i]
		if not is_instance_valid(s):
			continue
		var ph: float = float(i) * 1.6
		s.rotation = sin(_anim_t * 3.2 + ph) * 0.55
		var flip: float = 1.0 if sin(_anim_t * 4.0 + ph) >= 0.0 else -1.0
		s.scale.x = absf(s.scale.x) * flip
		s.position.y = _bear_base[i].y + sin(_anim_t * 5.0 + ph) * 24.0
	# Download progress.
	if _downloading and is_instance_valid(_bar_fill):
		var got: float = float(_http.get_downloaded_bytes())
		var total: float = float(_http.get_body_size())
		if total > 0.0:
			var f: float = clampf(got / total, 0.0, 1.0)
			_bar_fill.size.x = _bar_w * f
			if _status != null:
				_status.text = "Downloading v%s…  %d%%" % [_latest_tag, int(f * 100.0)]
		elif _status != null:
			_status.text = "Downloading v%s…  %.0f MB" % [_latest_tag, got / 1048576.0]

# ── download + swap ───────────────────────────────────────────────────────────
func _start_download() -> void:
	if _busy:
		return
	_busy = true
	_mode = "download"
	_downloading = true
	_download_path = OS.get_executable_path().get_base_dir().path_join("BEAR_GAME_update.exe")
	_http.download_file = _download_path
	if _http.request(_exe_url, PackedStringArray(["User-Agent: bear-crawl-updater"])) != OK:
		_busy = false
		_downloading = false
		_http.download_file = ""
		_close_overlay()

func _apply_update() -> void:
	if _status != null:
		_status.text = "Restarting…"
	if is_instance_valid(_bar_fill):
		_bar_fill.size.x = _bar_w
	var exe := OS.get_executable_path()
	var dir := exe.get_base_dir()
	var name := exe.get_file()                        # e.g. BEAR_GAME.exe
	var old_name := name.get_basename() + "_old.exe"  # BEAR_GAME_old.exe
	var old_full := dir.path_join(old_name)
	var log := dir.path_join("_bearcrawl_update.log")
	var bat := dir.path_join("_bearcrawl_update.bat")
	var q := "\""
	# Windows lets you RENAME a running .exe even though it can't be OVERWRITTEN — so
	# rename the live exe aside, drop the new build into its place, then relaunch. The
	# move retries until the process exits and releases the lock; restores on failure.
	var s := "@echo off\r\n"
	s += "echo Bear Crawl updater > " + q + log + q + "\r\n"
	s += "del /f /q " + q + old_full + q + " >nul 2>&1\r\n"
	s += "timeout /t 1 /nobreak >nul\r\n"
	s += "ren " + q + exe + q + " " + q + old_name + q + " >> " + q + log + q + " 2>&1\r\n"
	s += "set tries=0\r\n"
	s += ":movetry\r\n"
	s += "move /y " + q + _download_path + q + " " + q + exe + q + " >> " + q + log + q + " 2>&1\r\n"
	s += "if not exist " + q + _download_path + q + " goto launch\r\n"
	s += "set /a tries+=1\r\n"
	s += "if %tries% geq 30 goto launch\r\n"
	s += "timeout /t 1 /nobreak >nul\r\n"
	s += "goto movetry\r\n"
	s += ":launch\r\n"
	s += "if not exist " + q + exe + q + " ren " + q + old_full + q + " " + q + name + q + "\r\n"
	s += "start " + q + q + " " + q + exe + q + "\r\n"
	s += "del /f /q " + q + old_full + q + " >nul 2>&1\r\n"
	s += "del /f /q " + q + bat + q + "\r\n"
	var f := FileAccess.open(bat, FileAccess.WRITE)
	if f == null:
		_close_overlay()
		return
	f.store_string(s)
	f.close()
	OS.create_process("cmd.exe", ["/c", bat])
	get_tree().quit()

func _close_overlay() -> void:
	_downloading = false
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_bears.clear()
	_bear_base.clear()
	_status = null
	_bar_fill = null

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
