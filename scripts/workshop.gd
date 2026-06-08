extends Control

# Workshop — spend Fluff on permanent starting upgrades.
# Opened from the title screen.

const UPGRADE_IDS: Array[String] = ["more_plush", "sharper_crust", "faster_feet", "lucky_start"]
const WEAPON_IDS: Array[String] = ["scatter", "homing", "bomb"]

@onready var fluff_label: Label = $TopBar/FluffLabel
@onready var rows_container: VBoxContainer = $Center/Layout/Rows
@onready var back_btn: Button = $Bottom/BackButton

var _row_data: Dictionary = {}     # id -> { level Label, button Button } (stat upgrade rows)
var _weapon_data: Dictionary = {}  # id -> { button Button }

func _ready() -> void:
	_build_rows()
	_build_weapon_rows()
	_refresh()
	back_btn.pressed.connect(_on_back)
	back_btn.grab_focus()

func _build_rows() -> void:
	for id in UPGRADE_IDS:
		var data: Dictionary = MetaSave.UPGRADE_DATA.get(id, {})
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var name_label := Label.new()
		name_label.text = data.get("name", id)
		name_label.add_theme_font_size_override("font_size", 22)
		name_label.add_theme_color_override("font_color", Color(0.97, 0.95, 0.92))
		name_label.custom_minimum_size = Vector2(190, 0)
		row.add_child(name_label)
		var desc_label := Label.new()
		desc_label.text = data.get("desc", "")
		desc_label.add_theme_font_size_override("font_size", 14)
		desc_label.add_theme_color_override("font_color", Color(0.78, 0.78, 0.85))
		desc_label.custom_minimum_size = Vector2(260, 0)
		row.add_child(desc_label)
		var level_label := Label.new()
		level_label.add_theme_font_size_override("font_size", 18)
		level_label.custom_minimum_size = Vector2(70, 0)
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(level_label)
		var btn := Button.new()
		btn.add_theme_font_size_override("font_size", 18)
		btn.custom_minimum_size = Vector2(150, 38)
		btn.pressed.connect(_on_buy.bind(id))
		row.add_child(btn)
		rows_container.add_child(row)
		_row_data[id] = {
			"row": row,
			"level": level_label,
			"button": btn,
		}

func _build_weapon_rows() -> void:
	# Header for weapon section
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	rows_container.add_child(spacer)
	var header := Label.new()
	header.text = "—  WEAPON UNLOCKS  (Cotton Threads)  —"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	rows_container.add_child(header)
	for id in WEAPON_IDS:
		var data: Dictionary = MetaSave.WEAPON_DATA.get(id, {})
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var name_label := Label.new()
		name_label.text = data.get("name", id)
		name_label.add_theme_font_size_override("font_size", 22)
		name_label.add_theme_color_override("font_color", Color(0.97, 0.95, 0.92))
		name_label.custom_minimum_size = Vector2(190, 0)
		row.add_child(name_label)
		var desc_label := Label.new()
		desc_label.text = data.get("desc", "")
		desc_label.add_theme_font_size_override("font_size", 14)
		desc_label.add_theme_color_override("font_color", Color(0.78, 0.78, 0.85))
		desc_label.custom_minimum_size = Vector2(330, 0)
		row.add_child(desc_label)
		var btn := Button.new()
		btn.add_theme_font_size_override("font_size", 18)
		btn.custom_minimum_size = Vector2(150, 38)
		btn.pressed.connect(_on_buy_weapon.bind(id))
		row.add_child(btn)
		rows_container.add_child(row)
		_weapon_data[id] = {"button": btn}

func _refresh() -> void:
	fluff_label.text = "FLUFF: %d    COTTON: %d    VICTORIES: %d" % [
		MetaSave.total_fluff, MetaSave.cotton_threads, MetaSave.times_beaten
	]
	for id in UPGRADE_IDS:
		var data: Dictionary = MetaSave.UPGRADE_DATA.get(id, {})
		var lvl: int = MetaSave.upgrade_level(id)
		var max_lvl: int = int(data.get("max", 0))
		var entry: Dictionary = _row_data[id]
		(entry.level as Label).text = "%d / %d" % [lvl, max_lvl]
		var btn := entry.button as Button
		var cost: int = MetaSave.next_cost(id)
		if cost < 0:
			btn.text = "MAXED"
			btn.disabled = true
		elif MetaSave.total_fluff < cost:
			btn.text = "Buy (%d)" % cost
			btn.disabled = true
		else:
			btn.text = "Buy (%d)" % cost
			btn.disabled = false
	# Weapon unlock rows
	for id in WEAPON_IDS:
		var btn: Button = (_weapon_data[id] as Dictionary).button
		var unlocked: bool = MetaSave.is_weapon_unlocked(id)
		var cost: int = int(MetaSave.WEAPON_DATA.get(id, {}).get("cost", 999))
		if unlocked:
			btn.text = "UNLOCKED"
			btn.disabled = true
		elif MetaSave.cotton_threads < cost:
			btn.text = "%d Cotton" % cost
			btn.disabled = true
		else:
			btn.text = "Unlock (%d)" % cost
			btn.disabled = false

func _on_buy(id: String) -> void:
	if MetaSave.purchase(id):
		_refresh()

func _on_buy_weapon(id: String) -> void:
	if MetaSave.purchase_weapon(id):
		_refresh()

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		_on_back()
		get_viewport().set_input_as_handled()
