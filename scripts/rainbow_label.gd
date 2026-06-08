extends RichTextLabel

@export var content: String = "BOSS BEAR"
@export var scroll_speed: float = 1.6
@export var per_char_offset: float = 0.09

var _t: float = 0.0

func _ready() -> void:
	bbcode_enabled = true
	fit_content = true

func _process(delta: float) -> void:
	_t += delta * scroll_speed
	var s: String = "[center]"
	for i in content.length():
		var hue: float = fposmod(_t - i * per_char_offset, 1.0)
		var c: Color = Color.from_hsv(hue, 0.95, 1.0)
		s += "[color=#%s]%s[/color]" % [_color_hex(c), content.substr(i, 1)]
	s += "[/center]"
	text = s

func _color_hex(c: Color) -> String:
	return "%02x%02x%02x" % [int(c.r * 255.0), int(c.g * 255.0), int(c.b * 255.0)]
