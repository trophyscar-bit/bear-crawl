extends CanvasLayer

# Drop-in pause overlay. Pauses the tree on entry, runs while paused
# (PROCESS_MODE_ALWAYS), and offers Resume / Level Select / Main Menu. Esc or
# Resume closes it. Always unpauses before any scene change.
#
# Escape is handled in _input (not _unhandled_input) so a focused button can't
# swallow it, and is "armed" one frame after opening so the same keypress that
# opened the menu can't immediately close it.

var _armed: bool = false
var _dev_panel: PanelContainer = null
var _dev_summary: Label = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 80
	get_tree().paused = true
	$Dim/Center/Panel/VBox/Resume.pressed.connect(_resume)
	$Dim/Center/Panel/VBox/LevelSelect.pressed.connect(_go.bind("res://scenes/level_select.tscn"))
	$Dim/Center/Panel/VBox/MainMenu.pressed.connect(_go.bind("res://scenes/title_screen.tscn"))
	$Dim/Center/Panel/VBox/Resume.grab_focus()
	# Dev Tools — only if the current scene exposes them (the dungeon does).
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("dev_heal"):
		var devbtn := Button.new()
		devbtn.text = "🛠  Dev Tools"
		devbtn.custom_minimum_size = Vector2(360, 54)
		devbtn.pressed.connect(_toggle_dev.bind(scene))
		var vb := $Dim/Center/Panel/VBox as VBoxContainer
		vb.add_child(devbtn)
		vb.move_child(devbtn, 1)
	# Arm Escape-to-resume shortly after opening (timer ticks during pause).
	await get_tree().create_timer(0.12, true).timeout
	_armed = true

func _toggle_dev(scene: Node) -> void:
	if _dev_panel != null:
		_dev_panel.visible = not _dev_panel.visible
		return
	_dev_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.12, 0.97)
	sb.set_border_width_all(2); sb.border_color = Color(0.6, 0.45, 0.9, 0.8)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 18; sb.content_margin_right = 18
	sb.content_margin_top = 14; sb.content_margin_bottom = 14
	_dev_panel.add_theme_stylebox_override("panel", sb)
	_dev_panel.position = Vector2(34, 140)
	$Dim.add_child(_dev_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_dev_panel.add_child(vb)
	var title := Label.new()
	title.text = "🛠  DEV TOOLS"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	vb.add_child(title)
	var actions := [
		["❤  Heal Full", "dev_heal"],
		["⬇  Next Floor", "dev_next_floor"],
		["⛁  +100 Gold", "dev_add_gold"],
		["💀  Kill Enemies", "dev_kill_enemies"],
		["⭐  Level Up", "dev_level_up"],
		["🗡  Random Weapon", "dev_random_weapon"],
		["🛡  Toggle God Mode", "dev_god_mode"],
	]
	for a in actions:
		var b := Button.new()
		b.text = a[0]
		b.custom_minimum_size = Vector2(230, 38)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var method: String = a[1]
		b.pressed.connect(func() -> void:
			if is_instance_valid(scene) and scene.has_method(method):
				scene.call(method))
		vb.add_child(b)

	# ── Weapon test bench ────────────────────────────────────────────────────
	var wtitle := Label.new()
	wtitle.text = "🗡  WEAPON TEST"
	wtitle.add_theme_font_size_override("font_size", 16)
	wtitle.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	vb.add_child(wtitle)

	_dev_summary = Label.new()
	_dev_summary.add_theme_font_size_override("font_size", 13)
	_dev_summary.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	vb.add_child(_dev_summary)
	if not ArpgState.stats_changed.is_connected(_update_dev_summary):
		ArpgState.stats_changed.connect(_update_dev_summary)
	_update_dev_summary()

	# Pick weapon (one button per archetype).
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	vb.add_child(grid)
	for i in ArpgState.ARCHETYPES.size():
		var wb := Button.new()
		wb.text = String(ArpgState.ARCHETYPES[i].get("name", "?"))
		wb.add_theme_font_size_override("font_size", 12)
		wb.custom_minimum_size = Vector2(113, 30)
		var idx: int = i
		wb.pressed.connect(func() -> void:
			if is_instance_valid(scene) and scene.has_method("dev_set_weapon"):
				scene.call("dev_set_weapon", idx))
		grid.add_child(wb)

	# Upgrade the equipped weapon (free, repeatable).
	var ups := [
		["＋Dmg", "w_dmg"], ["Faster", "w_firerate"],
		["＋Pierce", "w_pierce"], ["＋Proj", "w_count"], ["＋Bounce", "w_bounce"],
	]
	var ugrid := GridContainer.new()
	ugrid.columns = 3
	ugrid.add_theme_constant_override("h_separation", 4)
	ugrid.add_theme_constant_override("v_separation", 4)
	vb.add_child(ugrid)
	for u in ups:
		var ub := Button.new()
		ub.text = u[0]
		ub.add_theme_font_size_override("font_size", 12)
		ub.custom_minimum_size = Vector2(74, 30)
		var uid: String = u[1]
		ub.pressed.connect(func() -> void:
			if is_instance_valid(scene) and scene.has_method("dev_upgrade_weapon"):
				scene.call("dev_upgrade_weapon", uid))
		ugrid.add_child(ub)

func _update_dev_summary() -> void:
	if _dev_summary == null or not is_instance_valid(_dev_summary):
		return
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("dev_weapon_summary"):
		_dev_summary.text = scene.call("dev_weapon_summary")

func _resume() -> void:
	get_tree().paused = false
	queue_free()

func _go(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)

func _input(event: InputEvent) -> void:
	if not _armed:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		# Escape closes the Dev Tools panel first (a "back"), then resumes the game.
		# It never navigates to the main menu — that needs the explicit button.
		if _dev_panel != null and _dev_panel.visible:
			_dev_panel.visible = false
		else:
			_resume()
