extends CharacterBody2D

# Dark Bear — a friendly COMPANION (not an enemy). He tags along a few metres off,
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
	# circles/flanks instead of trailing the exact path.
	_retarget_t -= delta
	if _retarget_t <= 0.0:
		_retarget_t = randf_range(1.2, 2.3)
		_offset = Vector2.from_angle(randf() * TAU) * randf_range(560.0, 780.0)
	var target: Vector2 = ppos + _offset
	var to: Vector2 = target - global_position
	var far: float = global_position.distance_to(ppos)
	var spd: float = speed + (far - 680.0) * 0.6   # speed up if he's lagging behind
	spd = clampf(spd, 120.0, 520.0)
	if to.length() > 10.0:
		velocity = to.normalized() * spd
	else:
		velocity = velocity.lerp(Vector2.ZERO, 0.25)
	move_and_slide()
	# snap-catch if he somehow gets stranded
	if far > 1500.0:
		global_position = ppos - _offset.normalized() * 760.0
	if absf(velocity.x) > 4.0:
		_facing = 1 if velocity.x > 0.0 else -1
		_rig.scale.x = absf(_rig.scale.x) * _facing
	# Mimic the player's weapon at half damage.
	_shoot_t -= delta
	if _shoot_t <= 0.0:
		_try_shoot()

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
