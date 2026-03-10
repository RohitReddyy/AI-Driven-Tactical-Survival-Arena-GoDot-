## DamageNumber.gd
## Floating damage number that rises and fades. Spawned on enemy hit.
extends Node2D

@onready var _label: Label = $Label

const RISE_SPEED  := 60.0
const LIFETIME    := 0.9
const CRIT_COLOR  := Color(1.0, 0.9, 0.0)
const NORM_COLOR  := Color(1.0, 1.0, 1.0)

var _age: float = 0.0

func _ready() -> void:
	z_index = 10

func setup(damage: int, is_crit: bool) -> void:
	if _label:
		_label.text = ("★ %d!" % damage) if is_crit else str(damage)
		_label.add_theme_color_override("font_color", CRIT_COLOR if is_crit else NORM_COLOR)
		if is_crit:
			_label.add_theme_font_size_override("font_size", 20)
			scale = Vector2(1.3, 1.3)

func _process(delta: float) -> void:
	_age += delta
	position.y -= RISE_SPEED * delta
	modulate.a = 1.0 - (_age / LIFETIME)
	if _age >= LIFETIME:
		queue_free()
