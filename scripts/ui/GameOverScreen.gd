## GameOverScreen.gd
## Shown when player dies. Displays score, best, waves. Offers restart/menu.
extends CanvasLayer

@onready var _title:         Label  = $Panel/VBox/Title
@onready var _score_label:   Label  = $Panel/VBox/ScoreLabel
@onready var _high_score_lbl: Label = $Panel/VBox/HighScoreLabel
@onready var _waves_label:   Label  = $Panel/VBox/WavesLabel
@onready var _new_best_lbl:  Label  = $Panel/VBox/NewBestLabel
@onready var _restart_btn:   Button = $Panel/VBox/Buttons/RestartBtn
@onready var _menu_btn:      Button = $Panel/VBox/Buttons/MenuBtn

# ---------------------------------------------------------------------------
func _ready() -> void:
	hide()
	GameManager.game_state_changed.connect(_on_game_state_changed)
	GameManager.high_score_beaten.connect(_on_high_score_beaten)

	if _restart_btn:
		_restart_btn.pressed.connect(_on_restart)
	if _menu_btn:
		_menu_btn.pressed.connect(_on_menu)
	if _new_best_lbl:
		_new_best_lbl.hide()

func _on_game_state_changed(state: int) -> void:
	if state == GameManager.GameState.GAME_OVER:
		_show_results()
	else:
		hide()

func _show_results() -> void:
	if _score_label:
		_score_label.text = "SCORE: %d" % GameManager.score
	if _high_score_lbl:
		_high_score_lbl.text = "BEST: %d" % GameManager.high_score
	if _waves_label:
		_waves_label.text = "WAVES SURVIVED: %d" % GameManager.waves_survived
	if _new_best_lbl:
		_new_best_lbl.hide()
	show()

func _on_high_score_beaten(_score: int) -> void:
	if _new_best_lbl:
		_new_best_lbl.show()

func _on_restart() -> void:
	get_tree().reload_current_scene()

func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
