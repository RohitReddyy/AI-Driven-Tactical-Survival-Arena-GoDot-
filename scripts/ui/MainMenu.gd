## MainMenu.gd
## Title screen with play, controls, and quit options.
extends Control

@onready var _play_btn:     Button = $CenterContainer/VBox/PlayBtn
@onready var _controls_btn: Button = $CenterContainer/VBox/ControlsBtn
@onready var _quit_btn:     Button = $CenterContainer/VBox/QuitBtn
@onready var _high_score:   Label  = $CenterContainer/VBox/HighScoreLabel
@onready var _controls_panel: Panel = $ControlsPanel

# ---------------------------------------------------------------------------
func _ready() -> void:
	if _play_btn:
		_play_btn.pressed.connect(_on_play)
	if _controls_btn:
		_controls_btn.pressed.connect(_on_controls)
	if _quit_btn:
		_quit_btn.pressed.connect(_on_quit)

	if _high_score:
		var hs := SaveManager.get_high_score()
		var ws := SaveManager.get_waves_survived()
		_high_score.text = "BEST: %d pts | Waves: %d" % [hs, ws]

	if _controls_panel:
		_controls_panel.hide()

func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/world/Arena.tscn")

func _on_controls() -> void:
	if _controls_panel:
		_controls_panel.visible = not _controls_panel.visible

func _on_quit() -> void:
	get_tree().quit()
