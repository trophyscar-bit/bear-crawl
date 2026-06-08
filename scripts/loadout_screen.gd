extends Control

# Pre-run loadout. Weapon selection removed — weapons are battle-only pickups.
# Player picks an Ascension level (0..MetaSave.max_ascension).
#
# Visually shares the title screen's nebula + drifting specks + pizza-slices
# vibe, plus a few decorative "pizza-planets" in the deep background so the
# loadout feels like a different "room" you've panned into.
#
# Entry animation: slides in from the right (paired with title's swipe-left).

const ASCENSION_NAMES: Array[String] = [
	"BASE RUN",
	"FLOODED FLOORS",
	"FORTIFIED FOES",
	"NO BOUNCES",
	"GLASS BEAR",
	"FINAL TANK",
]
const ASCENSION_CURSES: Array[String] = [
	"+50% enemy count per floor",
	"Regular bosses gain +30% HP",
	"Pizzas no longer bounce off walls",
	"You start each run at 3 HP",
	"Final boss gains +50% HP",
]
const ASCENSION_REWARDS: Array[String] = [
	"reward x1.0",
	"reward x1.25",
	"reward x1.5",
	"reward x1.85",
	"reward x2.25",
	"reward x3.0",
]
const NUM_BG_SPECKS: int = 60
const NUM_PIZZA_SLICES: int = 5
const NUM_PIZZA_PLANETS: int = 3
const PIZZA_COLOR: Color = Color(0.95, 0.82, 0.55, 0.92)
const PIZZA_CRUST: Color = Color(0.72, 0.52, 0.30, 1.0)
const PIZZA_PEPPERONI: Color = Color(0.82, 0.20, 0.20, 1.0)

@onready var bg_gradient: TextureRect = $BgGradient
@onready var background_layer: Node2D = $BackgroundLayer
@onready var decor_layer: Node2D = $DecorLayer
@onready var content: Control = $Content
@onready var title_label: Label = $Content/TopHolder/TopVBox/Title
@onready var asc_big_num: Label = $Content/CenterHolder/Card/CardVBox/AscBigNum
@onready var asc_name_label: Label = $Content/CenterHolder/Card/CardVBox/AscName
@onready var asc_minus_btn: Button = $Content/CenterHolder/Card/CardVBox/AscSelector/MinusButton
@onready var asc_plus_btn: Button = $Content/CenterHolder/Card/CardVBox/AscSelector/PlusButton
@onready var pips_row: HBoxContainer = $Content/CenterHolder/Card/CardVBox/AscSelector/PipsRow
@onready var curse_label: Label = $Content/CenterHolder/Card/CardVBox/CurseLabel
@onready var stack_label: Label = $Content/CenterHolder/Card/CardVBox/StackLabel
@onready var max_unlock_label: Label = $Content/CenterHolder/Card/CardVBox/MaxUnlockLabel
@onready var start_btn: Button = $Content/BottomHolder/ButtonRow/StartButton
@onready var back_btn: Button = $Content/BottomHolder/ButtonRow/BackButton
@onready var card: PanelContainer = $Content/CenterHolder/Card

class FloatSpeck:
	var node: Node2D
	var vel: Vector2
	var spin: float
	var pulse_off: float

class FloatPizza:
	var node: Node2D
	var vel: Vector2
	var spin: float

class PizzaPlanet:
	var node: Node2D
	var spin: float
	var bob_amp: float
	var bob_off: float
	var base_y: float

var _specks: Array[FloatSpeck] = []
var _pizzas: Array[FloatPizza] = []
var _planets: Array[PizzaPlanet] = []

var _t: float = 0.0
var _asc_level: int = 0
var _pip_buttons: Array[Button] = []
var _focus_targets: Array[Button] = []

func _ready() -> void:
	# When embedded in the title screen, skip our own bg + decor build —
	# the parent title screen already has them visible and they'd just
	# double up. Same goes for the entrance animation; the title drives it.
	var embedded: bool = has_meta("embedded_in_title")
	# Planets always spawn — they're the loadout's signature element AND the
	# targets for the "zoom into a pizza planet" Start-the-Crawl transition.
	_spawn_planets()
	if not embedded:
		_build_bg_gradient()
		_spawn_specks()
		_spawn_pizzas()
	else:
		# Hide unused root-level visuals so they don't paint on top
		if has_node("BgFallback"):  $BgFallback.visible = false
		if has_node("BgGradient"):  $BgGradient.visible = false
	_build_card_style()
	_asc_level = clamp(GameSettings.ascension, 0, MetaSave.max_ascension)
	_build_pips()
	_refresh()
	asc_minus_btn.pressed.connect(_on_asc_minus)
	asc_plus_btn.pressed.connect(_on_asc_plus)
	start_btn.pressed.connect(_on_start)
	back_btn.pressed.connect(_on_back)
	for b in [asc_minus_btn, asc_plus_btn, start_btn, back_btn]:
		b.mouse_entered.connect(_on_button_hover.bind(b, true))
		b.mouse_exited.connect(_on_button_hover.bind(b, false))
		b.focus_entered.connect(_on_button_hover.bind(b, true))
		b.focus_exited.connect(_on_button_hover.bind(b, false))
		b.pivot_offset = b.size * 0.5
		b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	if not embedded:
		# Standalone scene — run our own entrance animation
		_play_swipe_in()
	else:
		# Embedded — title's tween drives our position, make content visible
		content.modulate = Color(1, 1, 1, 1)
	start_btn.grab_focus()

func _build_bg_gradient() -> void:
	# Same nebula gradient as title screen — continuity sells the camera pan.
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

func _build_card_style() -> void:
	# Programmatic StyleBoxFlat so we don't need to set up sub-resources in .tscn
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.04, 0.14, 0.78)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.65, 0.45, 0.95, 0.55)
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_right = 16
	sb.corner_radius_bottom_left = 16
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	sb.shadow_size = 28
	sb.content_margin_left = 32.0
	sb.content_margin_top = 28.0
	sb.content_margin_right = 32.0
	sb.content_margin_bottom = 28.0
	card.add_theme_stylebox_override("panel", sb)

# ---------------------------------------------------------------------------
# Background decorations
# ---------------------------------------------------------------------------

func _spawn_specks() -> void:
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

func _spawn_pizzas() -> void:
	var vp := get_viewport_rect().size
	for i in NUM_PIZZA_SLICES:
		var node := _build_pizza_slice()
		node.position = Vector2(
			randf_range(60, vp.x - 60),
			randf_range(60, vp.y - 60)
		)
		var s := randf_range(0.6, 1.2)
		node.scale = Vector2(s, s)
		node.rotation = randf_range(0, TAU)
		decor_layer.add_child(node)
		var p := FloatPizza.new()
		p.node = node
		p.vel = Vector2(randf_range(-30, 30), randf_range(-18, 18))
		if abs(p.vel.x) < 6.0: p.vel.x = 14.0
		p.spin = randf_range(-0.35, 0.35)
		_pizzas.append(p)

func _build_pizza_slice() -> Node2D:
	var n2d := Node2D.new()
	var size: float = 38.0
	var crust := Polygon2D.new()
	crust.polygon = PackedVector2Array([
		Vector2(0, -size * 0.55),
		Vector2(size * 0.55, size * 0.55),
		Vector2(-size * 0.55, size * 0.55),
	])
	crust.color = PIZZA_CRUST
	n2d.add_child(crust)
	var cheese := Polygon2D.new()
	var inset: float = 0.86
	cheese.polygon = PackedVector2Array([
		Vector2(0, -size * 0.55 * inset),
		Vector2(size * 0.55 * inset, size * 0.55 * inset - 4),
		Vector2(-size * 0.55 * inset, size * 0.55 * inset - 4),
	])
	cheese.color = PIZZA_COLOR
	n2d.add_child(cheese)
	for i in 3:
		var dot := Polygon2D.new()
		var dpts := PackedVector2Array()
		var r: float = size * 0.10
		for j in 12:
			var a: float = TAU * float(j) / 12.0
			dpts.append(Vector2(cos(a) * r, sin(a) * r))
		dot.polygon = dpts
		dot.color = PIZZA_PEPPERONI
		dot.position = Vector2(randf_range(-size * 0.22, size * 0.22),
			randf_range(-size * 0.18, size * 0.25))
		n2d.add_child(dot)
	return n2d

func _spawn_planets() -> void:
	# Big pizza-planets in the deep background. Different sizes, slow drift,
	# subtle bob. Behind the speck layer.
	var vp := get_viewport_rect().size
	var xs: Array = [vp.x * 0.18, vp.x * 0.82, vp.x * 0.55]
	var ys: Array = [vp.y * 0.78, vp.y * 0.22, vp.y * 0.85]
	var radii: Array = [120.0, 90.0, 60.0]
	for i in NUM_PIZZA_PLANETS:
		var planet := _build_pizza_planet(radii[i])
		planet.position = Vector2(xs[i], ys[i])
		# Behind everything but the gradient
		background_layer.add_child(planet)
		background_layer.move_child(planet, 0)
		var p := PizzaPlanet.new()
		p.node = planet
		p.spin = randf_range(-0.10, 0.10)
		p.bob_amp = randf_range(4, 10)
		p.bob_off = randf_range(0, TAU)
		p.base_y = planet.position.y
		_planets.append(p)

func _build_pizza_planet(radius: float) -> Node2D:
	# Cheese disc + thicker crust ring + larger pepperoni dots spread around.
	# Slightly dimmed so they read as background atmosphere, not foreground.
	var n2d := Node2D.new()
	# Crust (outer disc)
	var crust := Polygon2D.new()
	var n: int = 48
	var cpts := PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		cpts.append(Vector2(cos(a) * radius, sin(a) * radius))
	crust.polygon = cpts
	crust.color = Color(0.55, 0.38, 0.20, 0.55)
	n2d.add_child(crust)
	# Cheese (inner)
	var cheese := Polygon2D.new()
	var cheese_pts := PackedVector2Array()
	var r2: float = radius * 0.86
	for i in n:
		var a: float = TAU * float(i) / float(n)
		cheese_pts.append(Vector2(cos(a) * r2, sin(a) * r2))
	cheese.polygon = cheese_pts
	cheese.color = Color(0.78, 0.65, 0.40, 0.6)
	n2d.add_child(cheese)
	# Pepperoni (6–8 around)
	var count: int = int(round(6 + radius / 40.0))
	for i in count:
		var ang: float = TAU * float(i) / float(count)
		var rd: float = radius * randf_range(0.30, 0.66)
		var dot := Polygon2D.new()
		var dpts := PackedVector2Array()
		var dotr: float = radius * 0.13
		for j in 16:
			var a: float = TAU * float(j) / 16.0
			dpts.append(Vector2(cos(a) * dotr, sin(a) * dotr))
		dot.polygon = dpts
		dot.color = Color(0.62, 0.18, 0.16, 0.7)
		dot.position = Vector2(cos(ang) * rd, sin(ang) * rd)
		n2d.add_child(dot)
	# Soft rim glow as a slightly larger semi-transparent disc behind
	var rim := Polygon2D.new()
	var rim_pts := PackedVector2Array()
	var rim_r: float = radius * 1.08
	for i in n:
		var a: float = TAU * float(i) / float(n)
		rim_pts.append(Vector2(cos(a) * rim_r, sin(a) * rim_r))
	rim.polygon = rim_pts
	rim.color = Color(1.0, 0.85, 0.5, 0.10)
	n2d.add_child(rim)
	n2d.move_child(rim, 0)  # behind everything
	return n2d

# ---------------------------------------------------------------------------
# Ascension pips
# ---------------------------------------------------------------------------

func _build_pips() -> void:
	# A row of round pip buttons — one per ascension level 0..max_ascension.
	# Click to jump straight to that level (in addition to ◀ ▶ buttons).
	for child in pips_row.get_children():
		child.queue_free()
	_pip_buttons.clear()
	var max_unlocked: int = MetaSave.max_ascension
	# Show all levels 0..5 even if not unlocked — locked ones are dimmed
	for i in range(0, 6):
		var b := Button.new()
		b.text = str(i)
		b.custom_minimum_size = Vector2(46, 46)
		b.add_theme_font_size_override("font_size", 18)
		# Pip styling: pill with hover glow
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.08, 0.20, 0.65)
		sb.corner_radius_top_left = 23
		sb.corner_radius_top_right = 23
		sb.corner_radius_bottom_right = 23
		sb.corner_radius_bottom_left = 23
		b.add_theme_stylebox_override("normal", sb)
		var sb_hover := sb.duplicate() as StyleBoxFlat
		sb_hover.bg_color = Color(0.32, 0.16, 0.48, 0.9)
		sb_hover.border_width_bottom = 2
		sb_hover.border_color = Color(1.0, 0.85, 0.4, 1.0)
		b.add_theme_stylebox_override("hover", sb_hover)
		b.add_theme_stylebox_override("focus", sb_hover)
		b.add_theme_stylebox_override("pressed", sb_hover)
		if i > max_unlocked:
			b.disabled = true
			b.modulate = Color(0.4, 0.4, 0.5)
		var idx: int = i
		b.pressed.connect(func(): _on_pip_pressed(idx))
		pips_row.add_child(b)
		_pip_buttons.append(b)

func _on_pip_pressed(idx: int) -> void:
	if idx > MetaSave.max_ascension:
		return
	_asc_level = idx
	_refresh()

# ---------------------------------------------------------------------------
# Card refresh
# ---------------------------------------------------------------------------

func _refresh() -> void:
	asc_big_num.text = "ASCENSION %d" % _asc_level
	var name_idx: int = min(_asc_level, ASCENSION_NAMES.size() - 1)
	asc_name_label.text = ASCENSION_NAMES[name_idx]
	asc_minus_btn.disabled = _asc_level <= 0
	asc_plus_btn.disabled = _asc_level >= MetaSave.max_ascension
	if _asc_level <= 0:
		curse_label.text = "no curses active"
		stack_label.text = ""
	else:
		var curse_idx: int = _asc_level - 1
		if curse_idx < ASCENSION_CURSES.size():
			curse_label.text = "[NEW]  %s" % ASCENSION_CURSES[curse_idx]
		else:
			curse_label.text = ""
		# Stack of all previous curses
		var lines: Array = []
		for i in range(0, _asc_level):
			lines.append("• " + ASCENSION_CURSES[i])
		stack_label.text = "\n".join(lines)
	# Reward multiplier
	var reward_idx: int = min(_asc_level, ASCENSION_REWARDS.size() - 1)
	max_unlock_label.text = "%s     •     max unlocked: %d" % [
		ASCENSION_REWARDS[reward_idx], MetaSave.max_ascension
	]
	# Pip highlight
	for i in _pip_buttons.size():
		var b: Button = _pip_buttons[i]
		if i == _asc_level:
			b.modulate = Color(1.0, 1.0, 1.0)
			b.add_theme_color_override("font_color", Color(1.0, 0.92, 0.40))
		elif i > MetaSave.max_ascension:
			b.modulate = Color(0.4, 0.4, 0.5)
		else:
			b.modulate = Color(1, 1, 1)
			b.add_theme_color_override("font_color", Color(0.85, 0.82, 0.92, 0.85))

func _on_asc_minus() -> void:
	_asc_level = max(0, _asc_level - 1)
	_refresh()

func _on_asc_plus() -> void:
	_asc_level = min(MetaSave.max_ascension, _asc_level + 1)
	_refresh()

# ---------------------------------------------------------------------------
# Animation
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	# Title vertical bob — matches the title screen's "alive" feel
	if title_label:
		title_label.pivot_offset = title_label.size * 0.5
		title_label.position.y = sin(_t * 1.6) * 3.0
	# Specks
	var vp := get_viewport_rect().size
	for s in _specks:
		s.node.position += s.vel * delta
		s.node.rotation += s.spin * delta
		if s.node.position.y < -10:
			s.node.position.y = vp.y + 10
			s.node.position.x = randf_range(0, vp.x)
		var twink: float = 0.65 + 0.35 * sin(_t * 2.4 + s.pulse_off)
		s.node.modulate.a = twink
	# Pizzas
	for p in _pizzas:
		p.node.position += p.vel * delta
		p.node.rotation += p.spin * delta
		if p.node.position.x < -80:  p.node.position.x = vp.x + 80
		if p.node.position.x > vp.x + 80: p.node.position.x = -80
		if p.node.position.y < -80:  p.node.position.y = vp.y + 80
		if p.node.position.y > vp.y + 80: p.node.position.y = -80
	# Planets — slow spin + gentle bob
	for pl in _planets:
		pl.node.rotation += pl.spin * delta
		pl.node.position.y = pl.base_y + sin(_t * 0.6 + pl.bob_off) * pl.bob_amp

func _play_swipe_in() -> void:
	# Simple fade-zoom entrance that mirrors title's exit.
	# Content starts at scale 1.08 + alpha 0 → tweens to 1.0 + alpha 1 over
	# 0.35 s. No pan, no rotation. Reads as a clean cross-fade.
	const ZOOM_IN_START: float = 1.08
	const DUR: float = 0.35
	content.pivot_offset = content.size * 0.5
	content.scale = Vector2(ZOOM_IN_START, ZOOM_IN_START)
	content.modulate.a = 0.0
	# Layers don't move, just fade in matching alpha
	background_layer.modulate.a = 1.0
	decor_layer.modulate.a = 1.0

	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(content, "scale", Vector2.ONE, DUR)
	tw.tween_property(content, "modulate:a", 1.0, DUR)

func _on_button_hover(btn: Button, hovered: bool) -> void:
	if not is_instance_valid(btn):
		return
	var target_scale: Vector2 = Vector2(1.05, 1.05) if hovered else Vector2(1.0, 1.0)
	var tw := btn.create_tween()
	tw.tween_property(btn, "scale", target_scale, 0.12).set_trans(Tween.TRANS_QUAD)

# ---------------------------------------------------------------------------
# Navigation
# ---------------------------------------------------------------------------

func _on_start() -> void:
	# Weapons are battle-only pickups now — always start with the default pizza.
	GameSettings.selected_weapon = "default"
	GameSettings.ascension = _asc_level
	RunState.reset()
	# Clean fade-zoom OUT: content scales 1.0 → 1.05, alpha to 0, plus a
	# black flash so the cut into the main game isn't jarring.
	for b in [asc_minus_btn, asc_plus_btn, start_btn, back_btn]:
		b.disabled = true
	set_process_input(false)
	set_process(false)   # stop the planet drift/bob so the zoom target stays put

	# --- "Pull back, then dive into a pizza planet" transition -----------
	# Phase A: zoom OUT to reveal the whole starfield + planets.
	# Phase B: dramatic zoom IN, rocketing the chosen planet until it fills
	#          the screen, then cut to the main game.
	const OUT_DUR: float = 0.45
	const IN_DUR: float = 0.75
	var screen: Vector2 = get_viewport_rect().size
	var screen_center: Vector2 = screen * 0.5

	# Target planet: the largest one (index 0 spawns at radius 120). Fall back
	# to screen center if planets somehow didn't spawn.
	var target: Node2D = null
	if _planets.size() > 0 and is_instance_valid(_planets[0].node):
		target = _planets[0].node
	var planet_pos: Vector2 = target.position if target != null else screen_center

	# Phase A target: shrink the field around screen centre.
	const OUT_S: float = 0.78
	var bg_out_pos: Vector2 = screen_center * (1.0 - OUT_S)

	# Phase B target: zoom so the pizza fills the view (diagonal / diameter).
	var zoom_s: float = max(6.0, screen.length() / 200.0)
	# For a Node2D scaled by S with the planet's local point fixed to the
	# screen centre: position = center - S * planet_pos.
	var bg_in_pos: Vector2 = screen_center - planet_pos * zoom_s

	# Fade-to-black overlay so the new scene cuts in cleanly at full zoom.
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.size = screen
	add_child(fade)
	content.pivot_offset = content.size * 0.5

	var tw := create_tween()
	tw.set_parallel(true)

	# --- Phase A: ease-OUT pull-back ---
	tw.tween_property(background_layer, "scale", Vector2(OUT_S, OUT_S), OUT_DUR) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(background_layer, "position", bg_out_pos, OUT_DUR) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(content, "scale", Vector2(0.9, 0.9), OUT_DUR) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# --- Phase B: ease-IN plunge into the planet (waits for A via chain) ---
	tw.chain()
	tw.tween_property(background_layer, "scale", Vector2(zoom_s, zoom_s), IN_DUR) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(background_layer, "position", bg_in_pos, IN_DUR) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# UI + decor rush past and fade out as we dive.
	tw.tween_property(content, "scale", Vector2(1.25, 1.25), IN_DUR * 0.7) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(content, "modulate:a", 0.0, IN_DUR * 0.5)
	tw.tween_property(decor_layer, "modulate:a", 0.0, IN_DUR * 0.55)
	# Black flash on the back half of the dive.
	tw.tween_property(fade, "color:a", 1.0, IN_DUR * 0.5).set_delay(IN_DUR * 0.5)

	tw.chain().tween_callback(func():
		ArpgState.reset_run()
		get_tree().change_scene_to_file("res://scenes/dungeon.tscn")
	)

func _on_back() -> void:
	# When embedded in title screen, ask the parent to slide us out.
	# Otherwise (standalone), fall back to a scene change.
	if has_meta("embedded_in_title"):
		var parent_node := get_parent()
		if parent_node and parent_node.has_method("show_title_again"):
			parent_node.show_title_again()
			return
	# Standalone path
	for b in [asc_minus_btn, asc_plus_btn, start_btn, back_btn]:
		b.disabled = true
	set_process_input(false)
	const ZOOM_OUT: float = 0.92
	const DUR: float = 0.35
	content.pivot_offset = content.size * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN)
	tw.tween_property(content, "scale", Vector2(ZOOM_OUT, ZOOM_OUT), DUR)
	tw.tween_property(content, "modulate:a", 0.0, DUR)
	tw.chain().tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
	)

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and (event as InputEventKey).pressed):
		return
	var key: int = (event as InputEventKey).keycode
	if key == KEY_ESCAPE:
		_on_back()
		get_viewport().set_input_as_handled()
	elif key == KEY_LEFT or key == KEY_A:
		_on_asc_minus()
		get_viewport().set_input_as_handled()
	elif key == KEY_RIGHT or key == KEY_D:
		_on_asc_plus()
		get_viewport().set_input_as_handled()
