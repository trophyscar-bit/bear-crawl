extends Control

# Workshop — permanent meta-progression (Vampire-Survivors style).
#   • STAT tracks bought with FLUFF (the common currency): small, permanent
#     bonuses that carry into every run, each with a hard cap.
#   • WEAPON unlocks bought with COTTON (the rare boss-drop currency).
# Clean dark card grid matching the merchant.

const STAT_IDS: Array[String] = ["more_plush", "sharper_crust", "faster_feet", "hot_oven", "sharp_eye", "greedy_paws"]
const WEAPON_IDS: Array[String] = ["scatter", "homing", "bomb"]

const ACCENT: Dictionary = {
	"more_plush":    Color(0.45, 0.90, 0.55),
	"sharper_crust": Color(1.00, 0.50, 0.42),
	"faster_feet":   Color(0.50, 0.80, 1.00),
	"hot_oven":      Color(1.00, 0.70, 0.35),
	"sharp_eye":     Color(1.00, 0.45, 0.70),
	"greedy_paws":   Color(1.00, 0.85, 0.40),
}

const BG_TOP   := Color(0.07, 0.08, 0.12)
const BG_BOT   := Color(0.02, 0.025, 0.04)
const CARD_BG  := Color(0.135, 0.145, 0.195)
const GOLD     := Color(1.0, 0.84, 0.45)
const COTTON   := Color(0.85, 0.92, 1.0)
const TXT      := Color(0.93, 0.94, 0.97)
const MUTE     := Color(0.66, 0.69, 0.78)

var _fluff_label: Label
var _stat_rows: Dictionary = {}    # id -> { pips: Label, level: Label, button: Button }
var _weapon_btns: Dictionary = {}  # id -> Button

func _ready() -> void:
	for c in get_children():
		c.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_refresh()

# ── style helpers ────────────────────────────────────────────────────────────
func _flat(bg: Color, border_col: Color, border: int, radius: int, pad: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(border)
	sb.border_color = border_col
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad; sb.content_margin_right = pad
	sb.content_margin_top = pad; sb.content_margin_bottom = pad
	return sb

func _label(text: String, size: int, color: Color, outline: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("outline_size", 5)
	return l

func _accent_button(b: Button, accent: Color) -> void:
	var base := accent.darkened(0.55); base.a = 1.0
	var hov := accent.darkened(0.30)
	var prs := accent.darkened(0.62)
	b.add_theme_stylebox_override("normal",  _flat(base, accent.darkened(0.1), 2, 9, 10))
	b.add_theme_stylebox_override("hover",   _flat(hov,  accent.lightened(0.2), 2, 9, 10))
	b.add_theme_stylebox_override("pressed", _flat(prs,  accent.darkened(0.1), 2, 9, 10))
	b.add_theme_stylebox_override("focus",   _flat(hov,  accent.lightened(0.2), 2, 9, 10))
	b.add_theme_stylebox_override("disabled", _flat(CARD_BG.darkened(0.1), Color(0.3, 0.3, 0.34), 1, 9, 10))
	b.add_theme_color_override("font_color", Color(1, 0.98, 0.92))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.52, 0.56))

# ── UI ───────────────────────────────────────────────────────────────────────
func _build() -> void:
	var grad := Gradient.new()
	grad.set_color(0, BG_TOP); grad.set_color(1, BG_BOT)
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad; gtex.fill_from = Vector2(0.5, 0.0); gtex.fill_to = Vector2(0.5, 1.0)
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.texture = gtex; bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var window := PanelContainer.new()
	var wsb := _flat(Color(0.085, 0.095, 0.135), GOLD.darkened(0.25), 2, 16, 30)
	wsb.shadow_color = Color(0, 0, 0, 0.5); wsb.shadow_size = 18
	window.add_theme_stylebox_override("panel", wsb)
	center.add_child(window)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	window.add_child(root)

	var title := _label("THE  WORKSHOP", 40, GOLD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	var sub := _label("Permanent upgrades — carried into every run", 17, MUTE)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sub)

	# Currency pill.
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", _flat(Color(0.05, 0.055, 0.08), GOLD.darkened(0.4), 1, 10, 12))
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_fluff_label = _label("", 22, GOLD)
	pill.add_child(_fluff_label)
	root.add_child(pill)

	# Stat-track grid (3 columns).
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	root.add_child(grid)
	for id in STAT_IDS:
		grid.add_child(_make_stat_card(id))

	# Weapon unlocks (Cotton).
	var whead := _label("WEAPON  UNLOCKS   ·   Cotton", 18, COTTON)
	whead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(whead)
	var wrow := HBoxContainer.new()
	wrow.alignment = BoxContainer.ALIGNMENT_CENTER
	wrow.add_theme_constant_override("separation", 14)
	root.add_child(wrow)
	for id in WEAPON_IDS:
		wrow.add_child(_make_weapon_card(id))

	# Bottom buttons.
	var btmrow := HBoxContainer.new()
	btmrow.alignment = BoxContainer.ALIGNMENT_CENTER
	btmrow.add_theme_constant_override("separation", 16)
	root.add_child(btmrow)
	var reset := Button.new()
	reset.text = "RESET  (refund Fluff)"
	reset.custom_minimum_size = Vector2(260, 50)
	reset.add_theme_font_size_override("font_size", 18)
	_accent_button(reset, Color(0.8, 0.45, 0.45))
	reset.pressed.connect(_on_reset)
	btmrow.add_child(reset)
	var back := Button.new()
	back.text = "◄  BACK"
	back.custom_minimum_size = Vector2(220, 50)
	back.add_theme_font_size_override("font_size", 20)
	_accent_button(back, GOLD)
	back.pressed.connect(_on_back)
	btmrow.add_child(back)
	back.grab_focus()

func _make_stat_card(id: String) -> Control:
	var data: Dictionary = MetaSave.UPGRADE_DATA.get(id, {})
	var accent: Color = ACCENT.get(id, Color(0.6, 0.6, 0.7))

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(244, 150)
	card.add_theme_stylebox_override("panel", _flat(CARD_BG, accent.darkened(0.15), 2, 12, 0))

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)

	# header strip
	var head := PanelContainer.new()
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = accent.darkened(0.40)
	hsb.corner_radius_top_left = 11; hsb.corner_radius_top_right = 11
	hsb.content_margin_top = 7; hsb.content_margin_bottom = 7
	hsb.content_margin_left = 10; hsb.content_margin_right = 10
	head.add_theme_stylebox_override("panel", hsb)
	var name_l := _label(String(data.get("name", id)), 19, accent.lightened(0.5))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(name_l)
	col.add_child(head)

	var body := MarginContainer.new()
	body.add_theme_constant_override("margin_left", 14)
	body.add_theme_constant_override("margin_right", 14)
	body.add_theme_constant_override("margin_top", 4)
	body.add_theme_constant_override("margin_bottom", 12)
	col.add_child(body)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	body.add_child(inner)

	var desc_l := _label(String(data.get("desc", "")) + "  per level", 14, TXT)
	desc_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(desc_l)

	var pips := _label("", 20, accent)
	pips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(pips)

	var lvl_l := _label("", 13, MUTE)
	lvl_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(lvl_l)

	var buy := Button.new()
	buy.add_theme_font_size_override("font_size", 17)
	buy.custom_minimum_size = Vector2(0, 40)
	_accent_button(buy, accent)
	buy.pressed.connect(_on_buy.bind(id))
	inner.add_child(buy)

	_stat_rows[id] = {"pips": pips, "level": lvl_l, "button": buy}
	return card

func _make_weapon_card(id: String) -> Control:
	var data: Dictionary = MetaSave.WEAPON_DATA.get(id, {})
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(232, 120)
	card.add_theme_stylebox_override("panel", _flat(CARD_BG, COTTON.darkened(0.45), 2, 12, 12))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	card.add_child(col)
	var n := _label(String(data.get("name", id)), 17, COTTON)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(n)
	var d := _label(String(data.get("desc", "")), 13, MUTE)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(d)
	var sp := Control.new(); sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(sp)
	var b := Button.new()
	b.add_theme_font_size_override("font_size", 16)
	b.custom_minimum_size = Vector2(0, 38)
	_accent_button(b, COTTON.darkened(0.1))
	b.pressed.connect(_on_buy_weapon.bind(id))
	col.add_child(b)
	_weapon_btns[id] = b
	return card

# ── refresh / actions ─────────────────────────────────────────────────────────
func _refresh() -> void:
	_fluff_label.text = "FLUFF  %d        COTTON  %d        VICTORIES  %d" % [
		MetaSave.total_fluff, MetaSave.cotton_threads, MetaSave.times_beaten
	]
	for id in STAT_IDS:
		var data: Dictionary = MetaSave.UPGRADE_DATA.get(id, {})
		var lvl: int = MetaSave.upgrade_level(id)
		var maxl: int = int(data.get("max", 0))
		var w: Dictionary = _stat_rows[id]
		var pips := ""
		for i in maxl:
			pips += "●" if i < lvl else "○"
		(w.pips as Label).text = pips
		(w.level as Label).text = "Level %d / %d" % [lvl, maxl]
		var btn := w.button as Button
		var cost: int = MetaSave.next_cost(id)
		if cost < 0:
			btn.text = "MAXED"; btn.disabled = true
		else:
			btn.text = "Buy   %d" % cost
			btn.disabled = MetaSave.total_fluff < cost
	for id in WEAPON_IDS:
		var b: Button = _weapon_btns[id]
		var cost: int = int(MetaSave.WEAPON_DATA.get(id, {}).get("cost", 999))
		if MetaSave.is_weapon_unlocked(id):
			b.text = "✓ UNLOCKED"; b.disabled = true
		else:
			b.text = "Unlock   %d" % cost
			b.disabled = MetaSave.cotton_threads < cost

func _on_buy(id: String) -> void:
	if MetaSave.purchase(id):
		_refresh()

func _on_buy_weapon(id: String) -> void:
	if MetaSave.purchase_weapon(id):
		_refresh()

func _on_reset() -> void:
	MetaSave.reset_upgrades()
	_refresh()

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		_on_back()
		get_viewport().set_input_as_handled()
