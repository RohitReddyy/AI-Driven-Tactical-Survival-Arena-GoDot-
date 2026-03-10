## UpgradeScreen.gd
## Post-wave upgrade selection UI. Presents 3 upgrade cards.
extends CanvasLayer

@onready var _title:       Label     = $Panel/VBox/Title
@onready var _subtitle:    Label     = $Panel/VBox/Subtitle
@onready var _cards_hbox:  HBoxContainer = $Panel/VBox/CardsRow

var _player: Node = null

const CARD_COLOR_DEFAULT := Color(0.12, 0.15, 0.22)
const CARD_COLOR_HOVER   := Color(0.18, 0.25, 0.38)

# ---------------------------------------------------------------------------
func _ready() -> void:
	hide()
	GameManager.game_state_changed.connect(_on_game_state_changed)
	UpgradeManager.upgrades_ready.connect(_on_upgrades_ready)

func _on_game_state_changed(state: int) -> void:
	if state == GameManager.GameState.UPGRADING:
		_player = get_tree().get_first_node_in_group("player")
		UpgradeManager.present_upgrades()
		show()
	else:
		hide()

func _on_upgrades_ready(options: Array[Dictionary]) -> void:
	# Clear old cards
	for child in _cards_hbox.get_children():
		child.queue_free()

	for upg in options:
		_create_card(upg)

# ---------------------------------------------------------------------------
# Card creation
# ---------------------------------------------------------------------------
func _create_card(upg: Dictionary) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 280)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	card.add_child(vbox)

	# Color swatch
	var swatch := ColorRect.new()
	swatch.color = upg.get("icon_color", Color.WHITE)
	swatch.custom_minimum_size = Vector2(60, 60)
	swatch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(swatch)

	# Name label
	var name_lbl := Label.new()
	name_lbl.text = upg["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_lbl)

	# Description
	var desc_lbl := Label.new()
	desc_lbl.text = upg["description"]
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(desc_lbl)

	# Select button
	var btn := Button.new()
	btn.text = "SELECT"
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.custom_minimum_size = Vector2(120, 36)
	btn.pressed.connect(_on_upgrade_selected.bind(upg["id"]))
	vbox.add_child(btn)

	_cards_hbox.add_child(card)

# ---------------------------------------------------------------------------
func _on_upgrade_selected(upgrade_id: String) -> void:
	if _player:
		UpgradeManager.apply_upgrade(upgrade_id, _player)
	hide()
