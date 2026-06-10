extends CharacterBody2D

# Finn — a friendly COMPANION (not an enemy). He tags along a few metres off,
# repositioning around you like a second player (not trailing your exact path), and
# mimics your weapon at half damage, firing at the nearest enemy.

const PizzaScene := preload("res://scenes/pizza.tscn")

var speed: float = 250.0
var player: Node2D = null
var _rig: Node2D
var _sprite: Sprite2D
var _retarget_t: float = 0.0
var _offset: Vector2 = Vector2(0, 680)
var _shoot_t: float = 0.6
var _facing: int = 1
var _offscreen_t: float = 0.0   # how long he's been off-camera
var _last_pos: Vector2 = Vector2.ZERO
var _stuck_t: float = 0.0
var _step_t: float = 0.0         # walk-bob phase (so he steps instead of floating)

func _ready() -> void:
	add_to_group("ally")
	collision_layer = 0                 # nothing targets or hits him
	set_collision_mask_value(1, true)   # but he still bumps walls
	set_collision_mask_value(3, false)
	_rig = Node2D.new()
	_rig.scale = Vector2(0.4, 0.4)
	add_child(_rig)
	_sprite = Sprite2D.new()
	_sprite.texture = _tex("res://assets/dark_bear.png")
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rig.add_child(_sprite)
	z_index = 4

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if not is_instance_valid(player):
			return
	var ppos: Vector2 = player.global_position
	# Reposition: pick a fresh spot around the player every couple seconds so he
	# circles/flanks instead of trailing the exact path. Kept CLOSER now.
	_retarget_t -= delta
	if _retarget_t <= 0.0:
		_retarget_t = randf_range(1.2, 2.3)
		_offset = Vector2.from_angle(randf() * TAU) * randf_range(247.0, 380.0)  # ~5% closer
	var target: Vector2 = ppos + _offset
	var to: Vector2 = target - global_position
	var far: float = global_position.distance_to(ppos)
	var desired: Vector2 = to.normalized()
	# Wall avoidance: if a wall is in the way to his target, steer ALONG it (and a
	# touch away) instead of grinding into it.
	var space := get_world_2d().direct_space_state
	var look: float = minf(to.length(), 90.0)
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + desired * look)
	q.collision_mask = 1
	q.exclude = [get_rid(), player.get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	if not hit.is_empty():
		var n: Vector2 = hit["normal"]
		var tang := Vector2(-n.y, n.x)
		if tang.dot(desired) < 0.0:
			tang = -tang
		desired = (tang * 0.85 + n * 0.3).normalized()
	var spd: float = speed + (far - 340.0) * 0.6
	spd = clampf(spd, 130.0, 520.0)
	if to.length() > 10.0:
		velocity = velocity.lerp(desired * spd, 0.3)
	else:
		velocity = velocity.lerp(Vector2.ZERO, 0.25)
	move_and_slide()
	# Self-unstick: wanted to move but didn't → shove sideways off the wall.
	var moved: float = global_position.distance_to(_last_pos)
	if velocity.length() > 30.0 and moved < 0.4:
		_stuck_t += delta
		if _stuck_t >= 0.4:
			_stuck_t = 0.0
			var perp := Vector2(-velocity.y, velocity.x).normalized()
			if randf() < 0.5:
				perp = -perp
			global_position += perp * 22.0
	else:
		_stuck_t = 0.0
	_last_pos = global_position
	# Off-screen stuck recovery: if he's been outside the visible screen for 6s
	# (wall-stuck, flung off, etc.), warp him to just beyond the screen edge near
	# you and let him fly back in normally.
	if _is_on_screen():
		_offscreen_t = 0.0
	else:
		_offscreen_t += delta
		if _offscreen_t >= 3.5:
			_warp_offscreen_near(ppos)
			_offscreen_t = 0.0
	# hard fallback if he's somehow flung far
	if far > 1100.0:
		_warp_offscreen_near(ppos)
	if absf(velocity.x) > 4.0:
		_facing = 1 if velocity.x > 0.0 else -1
		_rig.scale.x = absf(_rig.scale.x) * _facing
	# Walk-bob: little hops while moving so he reads as stepping, not flying. The
	# step rate scales with how fast he's going; he settles flat when idle.
	var sp: float = velocity.length()
	if sp > 25.0:
		_step_t += delta * (7.0 + sp * 0.02)
		_rig.position.y = -absf(sin(_step_t)) * 6.0
	else:
		_step_t = 0.0
		_rig.position.y = lerpf(_rig.position.y, 0.0, 0.2)
	# Mimic the player's weapon at half damage.
	_shoot_t -= delta
	if _shoot_t <= 0.0:
		_try_shoot()

func _is_on_screen() -> bool:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return true   # no camera info — assume visible, don't warp
	var view: Vector2 = get_viewport_rect().size / cam.zoom
	var rect := Rect2(cam.get_screen_center_position() - view * 0.5, view)
	return rect.has_point(global_position)

func _warp_offscreen_near(ppos: Vector2) -> void:
	# Drop him just beyond the screen edge near the player, already heading inward.
	var half: float = 700.0
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		var view: Vector2 = get_viewport_rect().size / cam.zoom
		half = maxf(view.x, view.y) * 0.5 + 70.0
	var dir: Vector2 = global_position - ppos
	if dir.length() < 1.0:
		dir = Vector2.from_angle(randf() * TAU)
	dir = dir.normalized()
	global_position = ppos + dir * half
	velocity = -dir * speed   # fly back in toward you

func _try_shoot() -> void:
	var e: Node2D = _nearest_enemy()   # nearest enemy he can actually SEE (LOS-gated)
	if e == null:
		_shoot_t = 0.25
		return
	if global_position.distance_to(e.global_position) > 980.0:
		_shoot_t = 0.25
		return
	var cd: float = 0.5
	if ArpgState.active and not ArpgState.weapon.is_empty():
		cd = ArpgState.weapon_cooldown()
	_shoot_t = maxf(cd * 1.25, 0.28)   # fires 25% slower than the player
	# Lead the target a touch so shots connect on movers.
	var aim: Vector2 = e.global_position
	if "velocity" in e:
		var ev: Vector2 = e.velocity
		var t: float = global_position.distance_to(e.global_position) / 620.0
		aim += ev * t * 0.5
	var dir: Vector2 = (aim - global_position).normalized()
	var p := PizzaScene.instantiate()
	p.global_position = global_position
	p.direction = dir
	p.max_bounces = 0
	var dmg: int = 2
	if ArpgState.active and not ArpgState.weapon.is_empty():
		dmg = maxi(1, int(round(float(ArpgState.weapon_damage()) * 0.45)))   # ~45% of player dmg
		p.speed = float(ArpgState.weapon.get("speed", 600.0))
	p.damage = dmg
	var spr := p.get_node_or_null("Sprite") as Sprite2D
	if spr != null:
		spr.modulate = Color(0.72, 0.6, 1.05)   # dusky violet so his shots read as "his"
		spr.scale *= 0.85
	var gl := p.get_node_or_null("Glow") as PointLight2D
	if gl != null:
		gl.energy = 0.45         # subtle halo, not a bloom bomb
		gl.texture_scale = 0.6
		gl.color = Color(0.7, 0.6, 1.0)
	get_parent().add_child(p)

func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var bd: float = INF
	var space := get_world_2d().direct_space_state
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var d: float = global_position.distance_squared_to((e as Node2D).global_position)
		if d >= bd:
			continue
		# Line-of-sight gate — don't shoot through walls (collision layer 1).
		var q := PhysicsRayQueryParameters2D.create(global_position, (e as Node2D).global_position)
		q.collision_mask = 1
		q.exclude = [self]
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty():
			continue   # a wall is in the way — can't see this one
		bd = d
		best = e
	return best

func _tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var t: Texture2D = load(path) as Texture2D
		if t != null:
			return t
	var f := FileAccess.open(path, FileAccess.READ)
	if f != null:
		var img := Image.new()
		if img.load_png_from_buffer(f.get_buffer(f.get_length())) == OK:
			return ImageTexture.create_from_image(img)
	return null
