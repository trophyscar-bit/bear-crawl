extends Control

# Title screen. Animated nebula background, drifting pizza slices, bouncing
# title, hover-scaling menu buttons, rotating pointer next to focused entry,
# and a live meta-stats teaser at the bottom.

const TAGLINES: Array[String] = [
	"a pizza-throwing plushie roguelike",
	"toss till you topple",
	"crust 'em with extra spice",
	"every floor wants you stuffed",
	"the bears are NOT okay",
	"deliver pain in 30 minutes or less",
	"bear arms with pepperoni",
]
const NUM_BG_SPECKS: int = 60      # background star/dust specks
const NUM_PIZZA_SLICES: int = 7    # foreground drifting slices
const NUM_BG_BEARS: int = 4        # tiny KK bears slowly floating in the deep bg
const PIZZA_COLOR: Color = Color(0.95, 0.82, 0.55, 0.92)
const PIZZA_CRUST: Color = Color(0.72, 0.52, 0.30, 1.0)
const PIZZA_PEPPERONI: Color = Color(0.82, 0.20, 0.20, 1.0)

@onready var difficulty_button: Button = $MenuHolder/Menu/DifficultyButton
@onready var fullscreen_button: Button = $OptionsPanel/OptionsVBox/FullscreenButton
@onready var rainbow_bar: ColorRect = $TopHolder/TopVBox/RainbowBar
@onready var menu_holder: CenterContainer = $MenuHolder
@onready var options_panel: PanelContainer = $OptionsPanel
@onready var title_label: Label = $TopHolder/TopVBox/Title
@onready var subtitle_label: Label = $TopHolder/TopVBox/Subtitle
@onready var stats_label: Label = $StatsHolder/StatsLabel
@onready var bg_gradient: TextureRect = $BgGradient
@onready var background_layer: Node2D = $BackgroundLayer
@onready var decor_layer: Node2D = $DecorLayer
@onready var menu_vbox: VBoxContainer = $MenuHolder/Menu

var _rainbow_t: float = 0.0
var _title_t: float = 0.0
var _tagline_t: float = 0.0
var _tagline_idx: int = 0
var _fullscreen: bool = false
var _menu_buttons: Array[Button] = []
var _focus_index: int = 0

# Decoration sprites — small floating slices + tiny background specks.
class FloatSpeck:
	var node: Node2D
	var vel: Vector2
	var spin: float
	var pulse_off: float
class FloatPizza:
	var node: Node2D
	var vel: Vector2
	var spin: float
	var base_scale: float
class BgBear:
	var node: Node2D
	var vel: Vector2
	var bob_off: float
	var base_y: float
	var spin: float       # rad/sec — slow lazy rotation
var _specks: Array[FloatSpeck] = []
var _pizzas: Array[FloatPizza] = []
var _bg_bears: Array[BgBear] = []

# Pointer marker that follows the focused button.
var _pointer: Node2D = null
var _pointer_target_y: float = 0.0

func _ready() -> void:
	_build_bg_gradient()
	_spawn_bg_bears()    # back layer
	_spawn_specks()
	_spawn_pizzas()
	_build_pointer()
	_update_difficulty_text()
	_update_fullscreen_text()
	_update_stats_label()
	$MenuHolder/Menu/StartButton.pressed.connect(_on_start)
	$MenuHolder/Menu/DifficultyButton.pressed.connect(_on_difficulty)
	$MenuHolder/Menu/WorkshopButton.pressed.connect(_on_workshop)
	$MenuHolder/Menu/OptionsButton.pressed.connect(_on_options)
	$MenuHolder/Menu/QuitButton.pressed.connect(_on_quit)
	$OptionsPanel/OptionsVBox/FullscreenButton.pressed.connect(_on_fullscreen)
	$OptionsPanel/OptionsVBox/BackButton.pressed.connect(_on_back)
	var dev_btn := get_node_or_null("DevButton")
	if dev_btn != null:
		(dev_btn as Button).pressed.connect(func() -> void:
			get_tree().change_scene_to_file("res://scenes/level_select.tscn"))
	# DEV TEST button — top-right, just under the DEV MODE button.
	var devtest_btn := Button.new()
	devtest_btn.name = "DevTestButton"
	devtest_btn.text = "🧪 DEV TEST"
	devtest_btn.add_theme_font_size_override("font_size", 16)
	devtest_btn.anchor_left = 1.0
	devtest_btn.anchor_right = 1.0
	devtest_btn.offset_left = -156.0
	devtest_btn.offset_top = 84.0
	devtest_btn.offset_right = -16.0
	devtest_btn.offset_bottom = 120.0
	add_child(devtest_btn)
	devtest_btn.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/dev_test.tscn"))

	_setup_version_ui()

	_menu_buttons = [
		$MenuHolder/Menu/StartButton,
		$MenuHolder/Menu/DifficultyButton,
		$MenuHolder/Menu/WorkshopButton,
		$MenuHolder/Menu/OptionsButton,
		$MenuHolder/Menu/QuitButton,
	]
	for i in _menu_buttons.size():
		var b: Button = _menu_buttons[i]
		b.focus_entered.connect(_set_focus_index.bind(i))
		b.mouse_entered.connect(_on_button_hover.bind(b, true))
		b.mouse_exited.connect(_on_button_hover.bind(b, false))
		b.focus_entered.connect(_on_button_hover.bind(b, true))
		b.focus_exited.connect(_on_button_hover.bind(b, false))
		# Pivot at center so scale animates symmetrically
		b.pivot_offset = b.size * 0.5
		b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	_focus_index = 0
	_menu_buttons[0].grab_focus()

func _build_bg_gradient() -> void:
	# Vertical nebula gradient: dark navy → deep purple → near-black.
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.04, 0.02, 0.10),
		Color(0.12, 0.05, 0.24),
		Color(0.02, 0.02, 0.06),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 64
	tex.height = 256
	bg_gradient.texture = tex

func _spawn_specks() -> void:
	# Tiny twinkling dots scattered across the bg.
	var vp := get_viewport_rect().size
	for i in NUM_BG_SPECKS:
		var node := Node2D.new()
		node.position = Vector2(randf_range(0, vp.x), randf_range(0, vp.y))
		var poly := Polygon2D.new()
		var n: int = 8
		var r: float = randf_range(1.2, 3.0)
		var pts := PackedVector2Array()
		for j in n:
			var a: float = TAU * float(j) / float(n)
			pts.append(Vector2(cos(a) * r, sin(a) * r))
		poly.polygon = pts
		# pick from a soft palette — purples, golds, off-whites
		var hue: float = randf()
		if hue < 0.4:
			poly.color = Color(0.85, 0.78, 1.0, randf_range(0.45, 0.85))
		elif hue < 0.7:
			poly.color = Color(1.0, 0.92, 0.55, randf_range(0.35, 0.75))
		else:
			poly.color = Color(1.0, 0.7, 0.9, randf_range(0.3, 0.6))
		node.add_child(poly)
		background_layer.add_child(node)
		var s := FloatSpeck.new()
		s.node = node
		s.vel = Vector2(randf_range(-12, 12), randf_range(-18, -4))
		s.spin = randf_range(-0.6, 0.6)
		s.pulse_off = randf_range(0, TAU)
		_specks.append(s)

func _spawn_bg_bears() -> void:
	# Tiny KK brown bears drifting in the deep background — uses the actual
	# in-game enemy art (brown_upper.png + brown_legs.png) instead of a
	# procedural redraw, per user req.
	var vp := get_viewport_rect().size
	var upper_tex: Texture2D = load("res://assets/brown_upper.png")
	var legs_tex: Texture2D = load("res://assets/brown_legs.png")
	for i in NUM_BG_BEARS:
		var node := Node2D.new()
		# Stack the legs sprite below the upper-body sprite to recreate the
		# in-game enemy rig look.
		if legs_tex:
			var legs := Sprite2D.new()
			legs.texture = legs_tex
			legs.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			node.add_child(legs)
		if upper_tex:
			var upper := Sprite2D.new()
			upper.texture = upper_tex
			upper.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			node.add_child(upper)
		node.position = Vector2(randf_range(80, vp.x - 80), randf_range(80, vp.y - 80))
		# Same scale as in-game enemies (rig is 0.28) — but drop even smaller
		# so they read as distant background, not foreground enemies.
		var s: float = randf_range(0.14, 0.22)
		node.scale = Vector2(s, s)
		node.modulate = Color(1, 1, 1, 0.30)
		background_layer.add_child(node)
		background_layer.move_child(node, 0)  # behind specks
		var bb := BgBear.new()
		bb.node = node
		bb.vel = Vector2(randf_range(-10, 10), 0.0)
		if abs(bb.vel.x) < 3.0: bb.vel.x = 6.0
		bb.bob_off = randf_range(0, TAU)
		bb.base_y = node.position.y
		# Slow lazy rotation — ±0.15 rad/sec, sign randomized per bear so
		# the swarm doesn't all spin the same way.
		bb.spin = randf_range(-0.15, 0.15)
		if abs(bb.spin) < 0.04: bb.spin = 0.08 if randf() < 0.5 else -0.08
		_bg_bears.append(bb)

func _spawn_pizzas() -> void:
	# Drifting cartoon pizza slices across the background.
	var vp := get_viewport_rect().size
	for i in NUM_PIZZA_SLICES:
		var node := _build_pizza_slice()
		node.position = Vector2(
			randf_range(60, vp.x - 60),
			randf_range(60, vp.y - 60)
		)
		var s := randf_range(0.7, 1.4)
		node.scale = Vector2(s, s)
		node.rotation = randf_range(0, TAU)
		decor_layer.add_child(node)
		var p := FloatPizza.new()
		p.node = node
		p.vel = Vector2(randf_range(-35, 35), randf_range(-20, 20))
		if abs(p.vel.x) < 8.0: p.vel.x = 18.0
		p.spin = randf_range(-0.4, 0.4)
		p.base_scale = s
		_pizzas.append(p)

func _build_pizza_slice() -> Node2D:
	# Original three-layer slice — crust triangle → cheese triangle → 3
	# pepperoni dots. Reverted from the busy multi-layer version per user req.
	var n2d := Node2D.new()
	var size: float = 38.0
	# Crust (slightly larger triangle, darker)
	var crust := Polygon2D.new()
	crust.polygon = PackedVector2Array([
		Vector2(0, -size * 0.55),
		Vector2(size * 0.55, size * 0.55),
		Vector2(-size * 0.55, size * 0.55),
	])
	crust.color = PIZZA_CRUST
	n2d.add_child(crust)
	# Cheese (inner triangle, golden)
	var cheese := Polygon2D.new()
	var inset: float = 0.86
	cheese.polygon = PackedVector2Array([
		Vector2(0, -size * 0.55 * inset),
		Vector2(size * 0.55 * inset, size * 0.55 * inset - 4),
		Vector2(-size * 0.55 * inset, size * 0.55 * inset - 4),
	])
	cheese.color = PIZZA_COLOR
	n2d.add_child(cheese)
	# 3 pepperoni dots
	for i in 3:
		var dot := Polygon2D.new()
		var dpts := PackedVector2Array()
		var r: float = size * 0.10
		for j in 12:
			var a: float = TAU * float(j) / 12.0
			dpts.append(Vector2(cos(a) * r, sin(a) * r))
		dot.polygon = dpts
		dot.color = PIZZA_PEPPERONI
		dot.position = Vector2(
			randf_range(-size * 0.22, size * 0.22),
			randf_range(-size * 0.18, size * 0.25)
		)
		n2d.add_child(dot)
	return n2d

func _build_pointer() -> void:
	# Slice-shaped pointer that follows the focused button.
	_pointer = _build_pizza_slice()
	_pointer.scale = Vector2(0.7, 0.7)
	add_child(_pointer)
	_pointer.visible = false

func _process(delta: float) -> void:
	_rainbow_t += delta * 0.35      # was 0.7 — half-speed rainbow per user req
	_title_t += delta
	_tagline_t += delta
	if rainbow_bar:
		rainbow_bar.modulate = Color.from_hsv(fposmod(_rainbow_t, 1.0), 0.85, 1.0)
	# Title vertical bob + gentle scale pulse — sells "alive."
	# Bob/pulse frequencies are 25% slower than the original tuning per user.
	if title_label:
		var bob: float = sin(_title_t * 1.2) * 4.0     # was 1.6
		title_label.position.y = bob
		title_label.pivot_offset = title_label.size * 0.5
		var s_pulse: float = 1.0 + 0.012 * sin(_title_t * 1.8)  # was 2.4
		title_label.scale = Vector2(s_pulse, s_pulse)
	# Rotate tagline every 6 s
	if _tagline_t >= 6.0:
		_tagline_t = 0.0
		_tagline_idx = (_tagline_idx + 1) % TAGLINES.size()
		if subtitle_label:
			_fade_subtitle(TAGLINES[_tagline_idx])
	# Specks
	var vp := get_viewport_rect().size
	for s in _specks:
		s.node.position += s.vel * delta
		s.node.rotation += s.spin * delta
		if s.node.position.y < -10:
			s.node.position.y = vp.y + 10
			s.node.position.x = randf_range(0, vp.x)
		# twinkle
		var twink: float = 0.65 + 0.35 * sin(_title_t * 2.4 + s.pulse_off)
		s.node.modulate.a = twink
	# Pizzas
	for p in _pizzas:
		p.node.position += p.vel * delta
		p.node.rotation += p.spin * delta
		# wrap around
		if p.node.position.x < -80:  p.node.position.x = vp.x + 80
		if p.node.position.x > vp.x + 80: p.node.position.x = -80
		if p.node.position.y < -80:  p.node.position.y = vp.y + 80
		if p.node.position.y > vp.y + 80: p.node.position.y = -80
	# Background bears — drift horizontally with subtle bob + slow spin
	for bb in _bg_bears:
		bb.node.position.x += bb.vel.x * delta
		bb.node.position.y = bb.base_y + sin(_title_t * 0.7 + bb.bob_off) * 8.0
		bb.node.rotation += bb.spin * delta
		if bb.node.position.x < -60: bb.node.position.x = vp.x + 60
		if bb.node.position.x > vp.x + 60: bb.node.position.x = -60
	# Pointer — follow the focused button
	_update_pointer(delta)

func _update_pointer(delta: float) -> void:
	if _menu_buttons.is_empty() or not menu_holder.visible:
		_pointer.visible = false
		return
	_pointer.visible = true
	var btn: Button = _menu_buttons[_focus_index]
	if not is_instance_valid(btn):
		return
	var btn_rect: Rect2 = btn.get_global_rect()
	var target := Vector2(btn_rect.position.x - 36, btn_rect.position.y + btn_rect.size.y * 0.5)
	_pointer.position = _pointer.position.lerp(target, clamp(delta * 14.0, 0.0, 1.0))
	_pointer.rotation += delta * 1.8

func _fade_subtitle(new_text: String) -> void:
	if not is_instance_valid(subtitle_label):
		return
	var tw := subtitle_label.create_tween()
	tw.tween_property(subtitle_label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): subtitle_label.text = new_text)
	tw.tween_property(subtitle_label, "modulate:a", 1.0, 0.4)

func _on_button_hover(btn: Button, hovered: bool) -> void:
	if not is_instance_valid(btn):
		return
	var target_scale: Vector2 = Vector2(1.06, 1.06) if hovered else Vector2(1.0, 1.0)
	var tw := btn.create_tween()
	tw.tween_property(btn, "scale", target_scale, 0.12).set_trans(Tween.TRANS_QUAD)

func _set_focus_index(idx: int) -> void:
	_focus_index = idx

func _update_stats_label() -> void:
	if not is_instance_valid(stats_label):
		return
	# Pull lifetime stats from MetaSave if available.
	var kills: int = 0
	var fluff: int = 0
	if Engine.has_singleton("MetaSave"):
		pass  # singletons are auto-loaded as globals in GDScript; no-op
	# These properties may not exist depending on game version — guard reads.
	var ms = get_node_or_null("/root/MetaSave")
	if ms:
		var k_v: Variant = ms.get("total_kills") if "total_kills" in ms else null
		var f_v: Variant = ms.get("total_fluff") if "total_fluff" in ms else null
		if k_v is int: kills = k_v
		if f_v is int: fluff = f_v
		# Fallback to direct fluff balance if total_fluff doesn't exist
		if fluff == 0 and "fluff" in ms:
			var bal_v: Variant = ms.get("fluff")
			if bal_v is int: fluff = bal_v
	stats_label.text = "🐻 %d  defeated     🧶 %d  fluff" % [kills, fluff]

var _update_btn: Button = null
var _update_ready: bool = false

func _setup_version_ui() -> void:
	# Clean version label (top-right) + a tiny "check for updates" line under it.
	var vlabel := get_node_or_null("VersionLabel") as Label
	if vlabel != null:
		vlabel.text = "v" + GameSettings.VERSION
	_update_btn = Button.new()
	_update_btn.name = "UpdateButton"
	_update_btn.flat = true
	_update_btn.text = "check for updates"
	_update_btn.focus_mode = Control.FOCUS_NONE
	_update_btn.add_theme_font_size_override("font_size", 11)
	_update_btn.add_theme_color_override("font_color", Color(0.6, 0.55, 0.8, 0.7))
	_update_btn.anchor_left = 1.0
	_update_btn.anchor_right = 1.0
	_update_btn.offset_left = -200.0
	_update_btn.offset_top = 26.0
	_update_btn.offset_right = -8.0
	_update_btn.offset_bottom = 44.0
	_update_btn.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_update_btn)
	_update_btn.pressed.connect(_on_update_pressed)
	Updater.status_changed.connect(_on_update_status)
	Updater.check_for_updates()   # quiet auto-check on launch

func _on_update_pressed() -> void:
	if _update_ready:
		Updater.download_and_install()   # downloads the new exe + self-restarts
	else:
		Updater.check_for_updates()

func _on_update_status(msg: String, available: bool) -> void:
	_update_ready = available
	if not is_instance_valid(_update_btn):
		return
	_update_btn.text = ("⬇ " + msg) if available else msg
	_update_btn.add_theme_color_override("font_color",
		Color(0.5, 1.0, 0.6, 0.95) if available else Color(0.6, 0.55, 0.8, 0.7))

func _on_start() -> void:
	# Original v1 intro: fly out to the Ascension / loadout screen, which then
	# dives into a pizza planet to drop you into the run.
	_swipe_out_to_loadout()

var _loadout_panel: Control = null
var _ui_holder_nodes: Array = []   # cached so show/hide animations target the same list
var _ui_original_positions: Array[Vector2] = []   # holders' anchored positions, captured once

func _swipe_out_to_loadout() -> void:
	# New approach: instead of changing scenes (which blinks + drops the
	# stars/pizzas), we EMBED loadout_screen.tscn as a child of this scene
	# and slide it in from the right while title UI slides out to the left.
	# The bg gradient + specks + decor stay put — they're persistent across
	# the entire title↔loadout navigation. Treat title + loadout as one big
	# scene that we just pan within.
	if is_instance_valid(_loadout_panel):
		return
	for b in _menu_buttons:
		b.disabled = true
	set_process_input(false)
	_ui_holder_nodes = [$TopHolder, menu_holder, $HintHolder, $StatsHolder, $VersionLabel]
	# Capture the ORIGINAL (anchored) positions ONCE so we can offset from
	# them during the tween and restore them at end. Direct position.x = 0
	# was breaking layout because anchored controls don't have position (0,0).
	if _ui_original_positions.is_empty():
		for n in _ui_holder_nodes:
			_ui_original_positions.append((n as Control).position)

	# Build the loadout overlay
	_loadout_panel = load("res://scenes/loadout_screen.tscn").instantiate() as Control
	# Tell loadout it's embedded so it skips its own bg/decor and entrance anim
	_loadout_panel.set_meta("embedded_in_title", true)
	add_child(_loadout_panel)
	var vp_w: float = get_viewport_rect().size.x
	var vp_size: Vector2 = get_viewport_rect().size
	# Force size before pivot calc so scale rotates around the actual center
	_loadout_panel.size = vp_size
	_loadout_panel.position.x = vp_w  # start off-screen right
	_loadout_panel.pivot_offset = vp_size * 0.5
	# Loadout starts WAY smaller for a more dramatic camera pull-back.
	const PANEL_SCALE_OUT: float = 0.40
	const BG_PARALLAX: float = 0.35      # bg layers move 2× faster (was 0.18)
	const ZOOM_DUR: float = 0.45
	const PAN_DUR: float = 0.55
	const ARC_PX: float = 130.0          # swoop height (was 55)
	const TILT_DEG: float = 9.0          # pan tilt (was 4)
	const PHASE_A_TILT_DEG: float = 3.0  # title tilts while zooming out
	_loadout_panel.scale = Vector2(PANEL_SCALE_OUT, PANEL_SCALE_OUT)
	# Pre-set pivots on title UI nodes
	for n in _ui_holder_nodes:
		var c: Control = n as Control
		c.pivot_offset = c.size * 0.5

	# THREE DISTINCT PHASES — now WAY more dramatic:
	#   A) Zoom out — title scales 1.0 → 0.40 + slight tilt as it rocks back
	#   B) Pan right — swoop arc 130 px + 9° tilt, bg parallax-accelerates
	#   C) Zoom in — loadout scales 0.40 → 1.0 with TRANS_BACK overshoot
	var twA := create_tween()
	twA.set_parallel(true)
	twA.set_trans(Tween.TRANS_CUBIC)
	twA.set_ease(Tween.EASE_IN)         # accelerate INTO the pull-back
	for n in _ui_holder_nodes:
		twA.tween_property(n, "scale", Vector2(PANEL_SCALE_OUT, PANEL_SCALE_OUT), ZOOM_DUR)
		twA.tween_property(n, "rotation", deg_to_rad(-PHASE_A_TILT_DEG), ZOOM_DUR)

	twA.chain().tween_callback(func():
		# Phase B: BIG swoop pan. Bigger arc + bigger tilt + bg layers also
		# rotate for full parallax depth.
		var twB := create_tween()
		twB.set_trans(Tween.TRANS_QUART)
		twB.set_ease(Tween.EASE_IN_OUT)
		twB.tween_method(func(t: float):
			var arc: float = sin(t * PI)
			var arc_y: float = -arc * ARC_PX
			# Tilt blends from the Phase-A end tilt to the swoop tilt
			var tilt: float = lerp(deg_to_rad(-PHASE_A_TILT_DEG), 0.0, t) + arc * deg_to_rad(-TILT_DEG)
			for i in _ui_holder_nodes.size():
				var c: Control = _ui_holder_nodes[i] as Control
				var orig: Vector2 = _ui_original_positions[i]
				c.position.x = orig.x + lerp(0.0, -vp_w, t)
				c.position.y = orig.y + arc_y
				c.rotation = tilt
			_loadout_panel.position.x = lerp(vp_w, 0.0, t)
			_loadout_panel.position.y = arc_y
			_loadout_panel.rotation = tilt
			background_layer.position.x = lerp(0.0, -vp_w * BG_PARALLAX, t)
			decor_layer.position.x = lerp(0.0, -vp_w * BG_PARALLAX * 1.5, t)
			background_layer.rotation = tilt * 0.3
			decor_layer.rotation = tilt * 0.5
		, 0.0, 1.0, PAN_DUR)
		twB.chain().tween_callback(func():
			# Snap rotation back to 0 and restore y to original anchored value
			for i in _ui_holder_nodes.size():
				var c: Control = _ui_holder_nodes[i] as Control
				var orig: Vector2 = _ui_original_positions[i]
				c.rotation = 0.0
				c.position.y = orig.y     # restore anchored Y
				c.position.x = orig.x + -vp_w   # keep title off-screen left for now
			_loadout_panel.rotation = 0.0
			_loadout_panel.position.y = 0.0
			background_layer.rotation = 0.0
			decor_layer.rotation = 0.0
			# Phase C: OVERSHOOT punch — TRANS_BACK ease produces a small
			# bounce past 1.0 before settling. Adds impact on arrival.
			var twC := create_tween()
			twC.set_trans(Tween.TRANS_BACK)
			twC.set_ease(Tween.EASE_OUT)
			twC.tween_property(_loadout_panel, "scale", Vector2.ONE, ZOOM_DUR)
		)
	)

func show_title_again() -> void:
	# Reverse of the forward 3-phase move:
	#   A) Zoom out loadout (1.0 → 0.55)
	#   B) Pan left (loadout off right, title in from left)
	#   C) Zoom in title (0.55 → 1.0)
	if not is_instance_valid(_loadout_panel):
		return
	set_process_input(false)
	var vp_w: float = get_viewport_rect().size.x
	const PANEL_SCALE_OUT: float = 0.40
	const BG_PARALLAX: float = 0.35
	const ZOOM_DUR: float = 0.45
	const PAN_DUR: float = 0.55
	const ARC_PX: float = 130.0
	const TILT_DEG: float = 9.0
	const PHASE_A_TILT_DEG: float = 3.0

	# Phase A: zoom out loadout + tilt
	var twA := create_tween()
	twA.set_parallel(true)
	twA.set_trans(Tween.TRANS_CUBIC)
	twA.set_ease(Tween.EASE_IN)
	twA.tween_property(_loadout_panel, "scale", Vector2(PANEL_SCALE_OUT, PANEL_SCALE_OUT), ZOOM_DUR)
	twA.tween_property(_loadout_panel, "rotation", deg_to_rad(PHASE_A_TILT_DEG), ZOOM_DUR)

	twA.chain().tween_callback(func():
		# Phase B: BIG SWOOP pan back — opposite-signed tilt so it reads as
		# going the other way.
		var twB := create_tween()
		twB.set_trans(Tween.TRANS_QUART)
		twB.set_ease(Tween.EASE_IN_OUT)
		twB.tween_method(func(t: float):
			var arc: float = sin(t * PI)
			var arc_y: float = -arc * ARC_PX
			var tilt: float = lerp(deg_to_rad(PHASE_A_TILT_DEG), 0.0, t) + arc * deg_to_rad(TILT_DEG)
			for i in _ui_holder_nodes.size():
				var c: Control = _ui_holder_nodes[i] as Control
				var orig: Vector2 = _ui_original_positions[i]
				c.position.x = orig.x + lerp(-vp_w, 0.0, t)
				c.position.y = orig.y + arc_y
				c.rotation = tilt
			_loadout_panel.position.x = lerp(0.0, vp_w, t)
			_loadout_panel.position.y = arc_y
			_loadout_panel.rotation = tilt
			background_layer.position.x = lerp(-vp_w * BG_PARALLAX, 0.0, t)
			decor_layer.position.x = lerp(-vp_w * BG_PARALLAX * 1.5, 0.0, t)
			background_layer.rotation = tilt * 0.3
			decor_layer.rotation = tilt * 0.5
		, 0.0, 1.0, PAN_DUR)
		twB.chain().tween_callback(func():
			# Snap orientation back to 0 and restore positions to anchored values
			for i in _ui_holder_nodes.size():
				var c: Control = _ui_holder_nodes[i] as Control
				c.rotation = 0.0
				c.position = _ui_original_positions[i]
			_loadout_panel.rotation = 0.0
			_loadout_panel.position.y = 0.0
			background_layer.rotation = 0.0
			decor_layer.rotation = 0.0
			# Phase C: OVERSHOOT zoom into title
			var twC := create_tween()
			twC.set_parallel(true)
			twC.set_trans(Tween.TRANS_BACK)
			twC.set_ease(Tween.EASE_OUT)
			for n in _ui_holder_nodes:
				twC.tween_property(n, "scale", Vector2.ONE, ZOOM_DUR)
			twC.chain().tween_callback(func():
				if is_instance_valid(_loadout_panel):
					_loadout_panel.queue_free()
					_loadout_panel = null
				# SAFETY: restore every title UI node to its ORIGINAL anchored
				# position (NOT (0, 0) — anchored controls aren't at origin).
				for i in _ui_holder_nodes.size():
					var c: Control = _ui_holder_nodes[i] as Control
					c.position = _ui_original_positions[i]
					c.rotation = 0.0
					c.scale = Vector2.ONE
				background_layer.position = Vector2.ZERO
				background_layer.rotation = 0.0
				decor_layer.position = Vector2.ZERO
				decor_layer.rotation = 0.0
				for b in _menu_buttons:
					b.disabled = false
					b.scale = Vector2.ONE
				set_process_input(true)
				_menu_buttons[_focus_index].grab_focus()
			)
		)
	)

func _on_difficulty() -> void:
	GameSettings.cycle_difficulty()
	_update_difficulty_text()

func _on_workshop() -> void:
	get_tree().change_scene_to_file("res://scenes/workshop.tscn")

func _on_options() -> void:
	options_panel.visible = true
	menu_holder.visible = false
	$OptionsPanel/OptionsVBox/BackButton.grab_focus()

func _on_back() -> void:
	options_panel.visible = false
	menu_holder.visible = true
	$MenuHolder/Menu/StartButton.grab_focus()

func _on_fullscreen() -> void:
	_fullscreen = not _fullscreen
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if _fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	_update_fullscreen_text()

func _on_quit() -> void:
	get_tree().quit()

func _update_difficulty_text() -> void:
	var name: String = GameSettings.difficulty_name()
	# Add emoji per difficulty
	var icon: String = "🟢" if name == "EASY" else ("🟡" if name == "MEDIUM" else "🔴")
	difficulty_button.text = "%s  DIFFICULTY: %s" % [icon, name]

func _update_fullscreen_text() -> void:
	fullscreen_button.text = "FULLSCREEN: %s" % ("ON" if _fullscreen else "OFF")

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and (event as InputEventKey).pressed):
		return
	var key: int = (event as InputEventKey).keycode
	if key == KEY_ESCAPE and options_panel.visible:
		_on_back()
		get_viewport().set_input_as_handled()
		return
	if not menu_holder.visible:
		return
	if key == KEY_W or key == KEY_UP:
		_move_focus(-1)
		get_viewport().set_input_as_handled()
	elif key == KEY_S or key == KEY_DOWN:
		_move_focus(1)
		get_viewport().set_input_as_handled()
	elif key == KEY_A or key == KEY_LEFT:
		_move_focus(-1)
		get_viewport().set_input_as_handled()
	elif key == KEY_D or key == KEY_RIGHT:
		_move_focus(1)
		get_viewport().set_input_as_handled()

func _move_focus(step: int) -> void:
	if _menu_buttons.is_empty():
		return
	_focus_index = (_focus_index + step) % _menu_buttons.size()
	if _focus_index < 0:
		_focus_index += _menu_buttons.size()
	_menu_buttons[_focus_index].grab_focus()
