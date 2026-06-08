class_name HealthBar
extends RefCounted

# Selectable HUD health-bar styles built from the real GUI pack (healthbar_assets
# → assets/ui/hp). build() spawns the chosen style under `parent` at `pos` and
# returns a Callable(hp, mhp) that refreshes it.

const STYLE_NAMES := ["Heart Bar", "Hearts", "Health Globe", "Segmented", "Minimal"]
const HP := "res://assets/ui/hp/"

static var _cache: Dictionary = {}

static func build(parent: Node, style: int, pos: Vector2, w: float) -> Callable:
	style = clampi(style, 0, STYLE_NAMES.size() - 1)
	match style:
		0: return _icon_bar(parent, pos, w, "heart_full", false)
		1: return _hearts(parent, pos, w)
		2: return _icon_bar(parent, pos, w, "orb", false)
		3: return _segmented(parent, pos, w)
		_: return _minimal(parent, pos, w)

# ── asset helpers ────────────────────────────────────────────────────────────
static func _tex(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var t: Texture2D = null
	var f := FileAccess.open(HP + name + ".png", FileAccess.READ)
	if f != null:
		var img := Image.new()
		if img.load_png_from_buffer(f.get_buffer(f.get_length())) == OK:
			t = ImageTexture.create_from_image(img)
	_cache[name] = t
	return t

static func _trect(parent: Node, tex: Texture2D, pos: Vector2, size: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.position = pos; r.custom_minimum_size = size; r.size = size
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r

static func _npatch(parent: Node, tex: Texture2D, pos: Vector2, size: Vector2, tile: bool) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = tex
	n.position = pos; n.size = size
	n.patch_margin_left = 7; n.patch_margin_right = 7
	n.patch_margin_top = 2; n.patch_margin_bottom = 2
	if tile:
		n.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(n)
	return n

static func _label(parent: Node, pos: Vector2, size: Vector2, fs: int) -> Label:
	var l := Label.new()
	l.position = pos; l.size = size
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", Color(1, 0.96, 0.92))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

# ── styles ───────────────────────────────────────────────────────────────────
static func _icon_bar(parent: Node, pos: Vector2, w: float, icon: String, seg: bool) -> Callable:
	var h: float = 22.0
	_trect(parent, _tex(icon), pos + Vector2(0, -2), Vector2(h + 6, h + 6))
	var bx: float = h + 12.0
	var bw: float = w - bx
	var frame_name: String = "seg_frame" if seg else "bar_frame"
	var fill_name: String = "seg_fill" if seg else "bar_fill"
	# Dark backing so the EMPTY part of the bar reads as a depleted track, not as
	# see-through transparency.
	var back := ColorRect.new()
	back.position = pos + Vector2(bx + 3, 4); back.size = Vector2(bw - 6, h - 7)
	back.color = Color(0.12, 0.05, 0.06, 0.95)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(back)
	_npatch(parent, _tex(frame_name), pos + Vector2(bx, 1), Vector2(bw, h), seg)
	var clip := Control.new()
	clip.position = pos + Vector2(bx, 1); clip.size = Vector2(bw, h)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(clip)
	_npatch(clip, _tex(fill_name), Vector2.ZERO, Vector2(bw, h), seg)
	var txt := _label(parent, pos + Vector2(bx, 1), Vector2(bw, h), 13)
	return func(hp, mhp):
		clip.size.x = bw * clampf(hp / maxf(1.0, mhp), 0.0, 1.0)
		txt.text = "%d / %d" % [int(round(hp)), int(round(mhp))]

static func _segmented(parent: Node, pos: Vector2, w: float) -> Callable:
	# A row of real pack cells (full / empty) beside a heart icon — perfectly
	# aligned because each segment is its own sprite.
	var full := _tex("seg_cell_full")
	var empty := _tex("seg_cell_empty")
	_trect(parent, _tex("heart_full"), pos + Vector2(0, -2), Vector2(26, 26))
	var bx: float = 32.0
	var bw: float = w - bx
	var n: int = 14
	var cw: float = bw / float(n)
	var cells: Array = []
	for i in n:
		var c := TextureRect.new()
		c.texture = full
		c.position = pos + Vector2(bx + float(i) * cw, 1)
		c.size = Vector2(cw, 22)
		c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.stretch_mode = TextureRect.STRETCH_SCALE
		c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(c)
		cells.append(c)
	return func(hp, mhp):
		var filled: int = int(round(clampf(hp / maxf(1.0, mhp), 0.0, 1.0) * float(n)))
		for i in n:
			(cells[i] as TextureRect).texture = full if i < filled else empty

static func _hearts(parent: Node, pos: Vector2, w: float) -> Callable:
	var full := _tex("heart_full")
	var half := _tex("heart_half")
	var empty := _tex("heart_empty")
	var n: int = 10
	var sz: float = minf(w / float(n), 26.0)
	var hearts: Array = []
	for i in n:
		hearts.append(_trect(parent, full, pos + Vector2(float(i) * sz, -2), Vector2(sz, sz)))
	return func(hp, mhp):
		var f: float = clampf(hp / maxf(1.0, mhp), 0.0, 1.0) * float(n)
		for i in n:
			var r := hearts[i] as TextureRect
			if float(i) + 1.0 <= f:
				r.texture = full
			elif float(i) + 0.35 <= f:
				r.texture = half
			else:
				r.texture = empty

static func _minimal(parent: Node, pos: Vector2, w: float) -> Callable:
	var bw: float = w - 64.0
	var back := ColorRect.new()
	back.position = pos + Vector2(2, 8); back.size = Vector2(bw - 4, 10)
	back.color = Color(0.12, 0.05, 0.06, 0.95); back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(back)
	_npatch(parent, _tex("bar_frame"), pos + Vector2(0, 6), Vector2(bw, 14), false)
	var clip := Control.new()
	clip.position = pos + Vector2(0, 6); clip.size = Vector2(bw, 14)
	clip.clip_contents = true; clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(clip)
	_npatch(clip, _tex("bar_fill"), Vector2.ZERO, Vector2(bw, 14), false)
	var txt := _label(parent, pos + Vector2(bw + 6, -2), Vector2(58, 24), 18)
	txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return func(hp, mhp):
		clip.size.x = bw * clampf(hp / maxf(1.0, mhp), 0.0, 1.0)
		txt.text = "%d" % int(round(hp))
