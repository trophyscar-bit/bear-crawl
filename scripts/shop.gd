extends Control

# Between-floor MERCHANT — clean dark "torchlit" theme (programmatic StyleBoxFlat,
# no cheap textures). Two kinds of offers:
#   • WEAPON upgrades for your CURRENT weapon (badged, accent = weapon colour) —
#     stack them to keep levelling the weapon you like.
#   • Global RUN upgrades (HP, crit, mystery box, …).

const GlowTex := preload("res://assets/light_radial.png")
var FrameTex: Texture2D   # wood window frame (Level-0-2) — loaded at runtime (no .import)

func _load_frame_tex() -> void:
	var f := FileAccess.open("res://assets/ui_frame.png", FileAccess.READ)
	if f == null:
		return
	var img := Image.new()
	if img.load_png_from_buffer(f.get_buffer(f.get_length())) == OK:
		FrameTex = ImageTexture.create_from_image(img)

const BG_TOP   := Color(0.07, 0.08, 0.12)
const BG_BOT   := Color(0.02, 0.025, 0.04)
const PANEL_BG := Color(0.105, 0.115, 0.155)
const CARD_BG  := Color(0.135, 0.145, 0.195)
const GOLD     := Color(1.0, 0.84, 0.45)
const TXT      := Color(0.93, 0.94, 0.97)
const MUTE     := Color(0.66, 0.69, 0.78)

var _offers: Array = []
var _gold_label: Label
var _buy_buttons: Array[Button] = []

func _ready() -> void:
	_load_frame_tex()
	ArpgState.stats_changed.connect(_refresh)
	_offers = ArpgState.generate_shop(5)
	_build_ui()

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

# ── framed wood-UI helpers (Kenney RPG UI, CC0) ──────────────────────────────
func _ui_tex(path: String) -> Texture2D:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var img := Image.new()
	if img.load_png_from_buffer(f.get_buffer(f.get_length())) == OK:
		return ImageTexture.create_from_image(img)
	return null

func _tex_box(path: String, tmargin: int, cmargin: int) -> StyleBox:
	var t := _ui_tex(path)
	if t == null:
		return _flat(PANEL_BG, GOLD.darkened(0.2), 2, 12, cmargin)   # fallback
	var sb := StyleBoxTexture.new()
	sb.texture = t
	sb.set_texture_margin_all(tmargin)
	sb.set_content_margin_all(cmargin)
	return sb

func _tex_button(b: Button, base: String, pressed: String, txt: Color = Color(1, 0.97, 0.9)) -> void:
	b.add_theme_stylebox_override("normal", _tex_box(base, 12, 8))
	b.add_theme_stylebox_override("hover", _tex_box(pressed, 12, 8))
	b.add_theme_stylebox_override("pressed", _tex_box(pressed, 12, 8))
	b.add_theme_stylebox_override("focus", _tex_box(pressed, 12, 8))
	b.add_theme_stylebox_override("disabled", _tex_box(base, 12, 8))
	b.add_theme_color_override("font_color", txt)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.45, 0.4))

func _label(text: String, size: int, color: Color, bold_outline: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold_outline:
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
	var dis := PANEL_BG.darkened(0.1)
	b.add_theme_stylebox_override("disabled", _flat(dis, Color(0.3, 0.3, 0.34), 1, 9, 10))
	b.add_theme_color_override("font_color", Color(1, 0.98, 0.92))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.52, 0.56))

# ── UI ───────────────────────────────────────────────────────────────────────
func _build_ui() -> void:
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

	var title := _label("THE  MERCHANT", 40, GOLD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	var sub := _label("Floor %d cleared — invest your spoils" % maxi(1, ArpgState.depth - 1), 17, MUTE)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sub)

	var pill := PanelContainer.new()
	var psb := _flat(Color(0.05, 0.055, 0.08), GOLD.darkened(0.4), 1, 10, 12)
	pill.add_theme_stylebox_override("panel", psb)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_gold_label = _label("", 22, GOLD)
	pill.add_child(_gold_label)
	root.add_child(pill)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	root.add_child(row)
	for i in _offers.size():
		row.add_child(_make_card(i))

	var descend := Button.new()
	descend.text = "▼   DESCEND   ▼"
	descend.custom_minimum_size = Vector2(380, 54)
	descend.add_theme_font_size_override("font_size", 24)
	descend.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_accent_button(descend, GOLD)
	descend.pressed.connect(_descend)
	root.add_child(descend)
	descend.grab_focus()
	_refresh()

func _make_card(index: int) -> Control:
	var offer: Dictionary = _offers[index]
	var accent: Color = offer.get("color", Color(0.6, 0.5, 0.9))
	var is_weapon: bool = bool(offer.get("weapon_upgrade", false))

	# Clean dark slate card with a rarity/accent-colored top header bar.
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(210, 286)
	card.pivot_offset = Vector2(105, 143)
	var csb := _flat(CARD_BG, accent.darkened(0.15), 2, 12, 0)
	card.add_theme_stylebox_override("panel", csb)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.mouse_entered.connect(func() -> void: _hover(card, true))
	card.mouse_exited.connect(func() -> void: _hover(card, false))

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	vb.alignment = BoxContainer.ALIGNMENT_BEGIN
	card.add_child(vb)

	# Colored header strip — replaces the glow orb. Category + accent identity.
	var head := PanelContainer.new()
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = accent.darkened(0.32) if is_weapon else accent.darkened(0.45)
	hsb.set_corner_radius_all(0)
	hsb.corner_radius_top_left = 11; hsb.corner_radius_top_right = 11
	hsb.content_margin_top = 8; hsb.content_margin_bottom = 8
	hsb.content_margin_left = 10; hsb.content_margin_right = 10
	head.add_theme_stylebox_override("panel", hsb)
	var badge := _label("⚔  WEAPON" if is_weapon else "◆  RUN UPGRADE", 13, Color(1, 0.97, 0.9))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(badge)
	vb.add_child(head)

	# Body with inner padding.
	var body := MarginContainer.new()
	body.add_theme_constant_override("margin_left", 14)
	body.add_theme_constant_override("margin_right", 14)
	body.add_theme_constant_override("margin_top", 14)
	body.add_theme_constant_override("margin_bottom", 14)
	vb.add_child(body)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	body.add_child(col)

	var name_l := _label(String(offer.get("name", "?")), 20, accent.lightened(0.45))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(name_l)

	var rule := Panel.new()
	rule.custom_minimum_size = Vector2(0, 2)
	var rsb := StyleBoxFlat.new(); rsb.bg_color = accent.darkened(0.1); rsb.bg_color.a = 0.5
	rule.add_theme_stylebox_override("panel", rsb)
	col.add_child(rule)

	var desc_l := _label(String(offer.get("desc", "")), 14, TXT)
	desc_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(desc_l)

	if is_weapon:
		var wname := _label("› %s" % String(offer.get("weapon_name", "")), 12, MUTE)
		wname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(wname)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	var buy := Button.new()
	buy.text = "⛁ %d" % int(offer.get("cost", 0))
	buy.add_theme_font_size_override("font_size", 19)
	buy.custom_minimum_size = Vector2(0, 44)
	_accent_button(buy, accent)
	buy.pressed.connect(_buy.bind(index))
	col.add_child(buy)
	_buy_buttons.append(buy)
	return card

func _hover(card: Control, on: bool) -> void:
	var tw := create_tween().set_trans(Tween.TRANS_QUAD)
	tw.tween_property(card, "scale", Vector2.ONE * (1.05 if on else 1.0), 0.12)

func _buy(index: int) -> void:
	if ArpgState.buy(_offers[index]):
		var b: Button = _buy_buttons[index]
		# Everything (including the one weapon level-up) sells out per visit.
		b.text = "✓ SOLD"
		b.disabled = true
		Juice.shake(0.05)
		_refresh()

func _refresh() -> void:
	if _gold_label != null:
		_gold_label.text = "⛁  %d  gold" % ArpgState.gold
	for i in _buy_buttons.size():
		var b: Button = _buy_buttons[i]
		if b.text == "✓ SOLD":
			continue
		b.disabled = ArpgState.gold < int(_offers[i].get("cost", 0))

func _descend() -> void:
	get_tree().change_scene_to_file(ArpgState.dungeon_path)
