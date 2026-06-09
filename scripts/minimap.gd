extends Control

# Corner minimap. PERFORMANCE: instead of drawing 1200+ rects every redraw (which
# tanked FPS), the discovered map is BAKED into a 1px-per-cell ImageTexture and
# only newly-explored cells are painted in. _draw then just blits that one texture
# + a few marker circles. Bound by dungeon.gd via bind().

const C_FOG      := Color(0.05, 0.05, 0.08, 1.0)
const C_FOG_EDGE := Color(0.12, 0.12, 0.17, 1.0)
const C_WALL     := Color(0.20, 0.19, 0.26, 1.0)
const C_FLOOR    := Color(0.52, 0.54, 0.64, 1.0)

var _d: Node = null
var _img: Image = null
var _tex: ImageTexture = null
var _painted: Dictionary = {}
var _fw: int = 0
var _fh: int = 0

func bind(dungeon: Node) -> void:
	_d = dungeon
	_build()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()

func _build() -> void:
	if _d == null:
		return
	_fw = _d._fw
	_fh = _d._fh
	if _fw <= 0 or _fh <= 0:
		return
	_img = Image.create(_fw, _fh, false, Image.FORMAT_RGBA8)
	_img.fill(C_FOG)
	_tex = ImageTexture.create_from_image(_img)
	_painted.clear()

# Paint cells discovered since the last bake. Returns true if the image changed.
func _bake_new_cells() -> bool:
	if _img == null:
		return false
	var changed: bool = false
	for key in _d._explored.keys():
		if _painted.has(key):
			continue
		_painted[key] = true
		var parts: PackedStringArray = String(key).split(",")
		if parts.size() != 2:
			continue
		var x: int = int(parts[0])
		var y: int = int(parts[1])
		if x < 0 or x >= _fw or y < 0 or y >= _fh:
			continue
		_img.set_pixel(x, y, C_WALL if _d._wall[y][x] else C_FLOOR)
		changed = true
		# Lighten still-fogged 4-neighbours (a soft reveal edge); overwritten
		# with wall/floor once they're explored too.
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if nx < 0 or nx >= _fw or ny < 0 or ny >= _fh:
				continue
			if not _d._explored.has("%d,%d" % [nx, ny]):
				_img.set_pixel(nx, ny, C_FOG_EDGE)
	return changed

func _draw() -> void:
	if _d == null or _img == null:
		return
	if _bake_new_cells():
		_tex.update(_img)
	var cw: float = size.x / float(_fw)
	var ch: float = size.y / float(_fh)
	# backdrop + the baked map (one texture blit)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.04, 0.88))
	draw_texture_rect(_tex, Rect2(Vector2.ZERO, size), false)
	# exit marker (only once discovered)
	var ex: Vector2 = _d.world_to_fine(_d._exit_pos)
	if _d._explored.has("%d,%d" % [int(ex.x), int(ex.y)]):
		draw_circle(Vector2(ex.x * cw, ex.y * ch), maxf(cw, 2.0), Color(0.4, 1.0, 0.7))
	# discovered items
	for it in _d._items:
		var f = _d.world_to_fine(it)
		if _d._explored.has("%d,%d" % [int(f.x), int(f.y)]):
			draw_circle(Vector2(f.x * cw, f.y * ch), maxf(cw * 0.7, 1.5), Color(0.6, 0.85, 1.0))
	# boss — hidden until you've ENCOUNTERED him once; after that he's always
	# tracked (so the teleporting boss can't be lost).
	if is_instance_valid(_d._boss) and not _d._boss_dead and _d._boss_alerted:
		var bp = _d.world_to_fine(_d._boss.global_position)
		var bc := Vector2(bp.x * cw, bp.y * ch)
		var pulse: float = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.006)
		draw_circle(bc, maxf(cw * 1.4, 4.5), Color(1.0, 0.2, 0.2, pulse))
	# player — always
	if is_instance_valid(_d._player):
		var p = _d.world_to_fine(_d._player.position)
		draw_circle(Vector2(p.x * cw, p.y * ch), maxf(cw * 0.9, 2.5), Color(1.0, 0.9, 0.3))
	# border
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.5, 0.45, 0.7, 0.7), false, 2.0)
