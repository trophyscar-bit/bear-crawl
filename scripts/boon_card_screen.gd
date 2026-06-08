extends CanvasLayer

signal boon_selected(boon_id)

var _offered: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_offered = RunState.roll_offers(3)
	var cards: Array[Button] = [
		$Center/Layout/HBox/Card1,
		$Center/Layout/HBox/Card2,
		$Center/Layout/HBox/Card3,
	]
	if _offered.is_empty():
		# every boon is maxed — nothing to offer; just advance.
		boon_selected.emit("")
		queue_free()
		return
	for i in cards.size():
		if i < _offered.size():
			_populate(cards[i], _offered[i])
			cards[i].pressed.connect(_pick.bind(i))
		else:
			cards[i].visible = false
	cards[0].grab_focus()

func _populate(card: Button, offer: Dictionary) -> void:
	(card.get_node("V/Title") as Label).text = offer.name
	(card.get_node("V/Desc") as Label).text = offer.desc
	# Rarity tint on the card itself + title colour
	var rarity: String = String(offer.get("rarity", "common"))
	var title_color: Color = Color(1, 0.97, 0.72, 1)
	var card_modulate: Color = Color(1, 1, 1, 1)
	match rarity:
		"rare":
			title_color = Color(0.55, 0.85, 1.0)
			card_modulate = Color(0.78, 0.92, 1.10, 1.0)
		"legendary":
			title_color = Color(1.0, 0.86, 0.35)
			card_modulate = Color(1.15, 1.02, 0.65, 1.0)
		_:
			pass
	(card.get_node("V/Title") as Label).modulate = title_color
	card.modulate = card_modulate

func _pick(idx: int) -> void:
	var boon: Dictionary = _offered[idx]
	boon_selected.emit(boon.id)
	queue_free()

func _input(event: InputEvent) -> void:
	# WASD/AD as alternates for arrow key navigation between cards
	if not (event is InputEventKey and (event as InputEventKey).pressed):
		return
	var key: int = (event as InputEventKey).keycode
	var focus_target: Control = null
	if key == KEY_A or key == KEY_D or key == KEY_LEFT or key == KEY_RIGHT:
		var current: Control = get_viewport().gui_get_focus_owner()
		if current == null:
			return
		var all_cards: Array = [
			$Center/Layout/HBox/Card1,
			$Center/Layout/HBox/Card2,
			$Center/Layout/HBox/Card3,
		]
		var visible_cards: Array = []
		for c in all_cards:
			if (c as Control).visible:
				visible_cards.append(c)
		if visible_cards.size() <= 1:
			return
		var idx: int = visible_cards.find(current)
		if idx < 0:
			return
		var step: int = -1 if (key == KEY_A or key == KEY_LEFT) else 1
		focus_target = visible_cards[(idx + step + visible_cards.size()) % visible_cards.size()]
	if focus_target:
		focus_target.grab_focus()
		get_viewport().set_input_as_handled()
