extends Control

# Corner minimap for the dungeon. Reads the generator's wall grid + explored set
# (fog of war) and draws a compact top-down plan with the player, exit and item
# markers. Bound by dungeon.gd via bind().
#
# Fog of war: undiscovered cells are covered by a solid fog tile (the layout
# ahead is hidden). Cells bordering explored ground get a lighter "frontier"
# fog so the edge feels like it's peeling back as you move. Exit/item markers
# only appear once their cell has actually been discovered.

var _d: Node = null

func bind(dungeon: Node) -> void:
	_d = dungeon
	queue_redraw()

func _seen(x: int, y: int) -> bool:
	return _d._explored.has("%d,%d" % [x, y])

func _frontier(x: int, y: int) -> bool:
	# undiscovered cell touching a discovered one → soften it (reveal edge)
	return _seen(x - 1, y) or _seen(x + 1, y) or _seen(x, y - 1) or _seen(x, y + 1) \
		or _seen(x - 1, y - 1) or _seen(x + 1, y - 1) or _seen(x - 1, y + 1) or _seen(x + 1, y + 1)

func _draw() -> void:
	if _d == null:
		return
	var fw: int = _d._fw
	var fh: int = _d._fh
	if fw <= 0 or fh <= 0:
		return
	# panel backdrop
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.04, 0.88))
	var cw: float = size.x / float(fw)
	var ch: float = size.y / float(fh)
	var WALL := Color(0.20, 0.19, 0.26, 0.98)
	var FLOOR := Color(0.52, 0.54, 0.64, 0.95)
	var FOG := Color(0.05, 0.05, 0.08, 0.96)        # solid cover over the unknown
	var FOG_EDGE := Color(0.12, 0.12, 0.17, 0.9)    # softer fog at the reveal edge
	for y in fh:
		for x in fw:
			var r := Rect2(x * cw, y * ch, cw + 1.0, ch + 1.0)
			if _seen(x, y):
				draw_rect(r, WALL if _d._wall[y][x] else FLOOR)
			else:
				draw_rect(r, FOG_EDGE if _frontier(x, y) else FOG)
	# exit marker — only once its cell is discovered (fog keeps it secret)
	var ex: Vector2 = _d.world_to_fine(_d._exit_pos)
	if _seen(int(ex.x), int(ex.y)):
		draw_circle(Vector2(ex.x * cw, ex.y * ch), maxf(cw, 2.0), Color(0.4, 1.0, 0.7))
	# items — only the discovered ones
	for it in _d._items:
		var f = _d.world_to_fine(it)
		if _seen(int(f.x), int(f.y)):
			draw_circle(Vector2(f.x * cw, f.y * ch), maxf(cw * 0.7, 1.5), Color(0.6, 0.85, 1.0))
	# player — always
	if is_instance_valid(_d._player):
		var p = _d.world_to_fine(_d._player.position)
		draw_circle(Vector2(p.x * cw, p.y * ch), maxf(cw * 0.9, 2.5), Color(1.0, 0.9, 0.3))
	# border
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.5, 0.45, 0.7, 0.7), false, 2.0)
