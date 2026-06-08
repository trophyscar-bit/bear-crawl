extends Control

# Corner minimap for the dungeon. Reads the generator's wall grid + explored set
# (fog of war) and draws a compact top-down plan with the player, exit and item
# markers. Bound by dungeon.gd via bind().

var _d: Node = null

func bind(dungeon: Node) -> void:
	_d = dungeon
	queue_redraw()

func _draw() -> void:
	if _d == null:
		return
	var fw: int = _d._fw
	var fh: int = _d._fh
	if fw <= 0 or fh <= 0:
		return
	# panel backdrop
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.03, 0.05, 0.82))
	var cw: float = size.x / float(fw)
	var ch: float = size.y / float(fh)
	for y in fh:
		for x in fw:
			var explored: bool = _d._explored.has("%d,%d" % [x, y])
			var r := Rect2(x * cw, y * ch, cw + 1.0, ch + 1.0)
			if _d._wall[y][x]:
				draw_rect(r, Color(0.16, 0.15, 0.20, 0.95 if explored else 0.30))
			else:
				draw_rect(r, Color(0.45, 0.45, 0.55, 0.85 if explored else 0.18))
	# exit marker
	var ex: Vector2 = _d.world_to_fine(_d._exit_pos)
	draw_circle(Vector2(ex.x * cw, ex.y * ch), maxf(cw, 2.0), Color(0.4, 1.0, 0.7))
	# items
	for it in _d._items:
		var f = _d.world_to_fine(it)
		draw_circle(Vector2(f.x * cw, f.y * ch), maxf(cw * 0.7, 1.5), Color(0.6, 0.85, 1.0))
	# player
	if is_instance_valid(_d._player):
		var p = _d.world_to_fine(_d._player.position)
		draw_circle(Vector2(p.x * cw, p.y * ch), maxf(cw * 0.9, 2.5), Color(1.0, 0.9, 0.3))
	# border
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.5, 0.45, 0.7, 0.7), false, 2.0)
