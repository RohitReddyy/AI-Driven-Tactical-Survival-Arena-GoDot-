## GameManager.gd
## Central game state controller. Autoloaded as singleton.
## Coordinates game flow: menu → playing → wave end → upgrade → game over.
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal game_state_changed(new_state: int)
signal score_changed(new_score: int)
signal high_score_beaten(new_high_score: int)

# ---------------------------------------------------------------------------
# Game States
# ---------------------------------------------------------------------------
enum GameState {
	MENU,
	PLAYING,
	PAUSED,
	WAVE_COMPLETE,
	UPGRADING,
	GAME_OVER
}

# ---------------------------------------------------------------------------
# Exported / configurable
# ---------------------------------------------------------------------------
@export var screen_shake_camera_path: NodePath = NodePath()

# ---------------------------------------------------------------------------
# Runtime state
# ---------------------------------------------------------------------------
var current_state: GameState = GameState.MENU
var score: int = 0
var high_score: int = 0
var waves_survived: int = 0

# Tracks cumulative player behavior for AI adaptation
var player_behavior_data: Dictionary = {
	"total_damage_dealt": 0,
	"total_damage_taken": 0,
	"dashes_used": 0,
	"shots_fired": 0,
	"avg_distance_to_enemies": 200.0,
}

# Internal references
var _camera: Camera2D = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	# Load high score from save
	high_score = SaveManager.get_high_score()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and current_state == GameState.PLAYING:
		toggle_pause()

# ---------------------------------------------------------------------------
# State management
# ---------------------------------------------------------------------------
func change_state(new_state: GameState) -> void:
	current_state = new_state
	game_state_changed.emit(new_state)

func start_game() -> void:
	score = 0
	waves_survived = 0
	player_behavior_data = {
		"total_damage_dealt": 0,
		"total_damage_taken": 0,
		"dashes_used": 0,
		"shots_fired": 0,
		"avg_distance_to_enemies": 200.0,
	}
	score_changed.emit(score)
	change_state(GameState.PLAYING)
	WaveManager.start_wave_sequence()

func toggle_pause() -> void:
	if current_state == GameState.PLAYING:
		change_state(GameState.PAUSED)
		get_tree().paused = true
	elif current_state == GameState.PAUSED:
		change_state(GameState.PLAYING)
		get_tree().paused = false

func trigger_game_over() -> void:
	get_tree().paused = false
	waves_survived = WaveManager.current_wave - 1
	_check_high_score()
	SaveManager.save_game(high_score, waves_survived)
	change_state(GameState.GAME_OVER)

func trigger_wave_complete() -> void:
	change_state(GameState.WAVE_COMPLETE)

func begin_upgrade_phase() -> void:
	change_state(GameState.UPGRADING)

func finish_upgrade_phase() -> void:
	change_state(GameState.PLAYING)
	WaveManager.start_next_wave()

# ---------------------------------------------------------------------------
# Score
# ---------------------------------------------------------------------------
func add_score(points: int) -> void:
	score += points
	score_changed.emit(score)

func _check_high_score() -> void:
	if score > high_score:
		high_score = score
		high_score_beaten.emit(high_score)

# ---------------------------------------------------------------------------
# Player behavior tracking (used by AI to adapt)
# ---------------------------------------------------------------------------
func record_damage_dealt(amount: float) -> void:
	player_behavior_data["total_damage_dealt"] += amount

func record_damage_taken(amount: float) -> void:
	player_behavior_data["total_damage_taken"] += amount

func record_dash() -> void:
	player_behavior_data["dashes_used"] += 1

func record_shot() -> void:
	player_behavior_data["shots_fired"] += 1

func update_avg_distance(dist: float) -> void:
	# Running average
	var alpha := 0.05
	player_behavior_data["avg_distance_to_enemies"] = lerp(
		player_behavior_data["avg_distance_to_enemies"], dist, alpha
	)

## Returns aggression ratio: how aggressively the player plays (0–1).
## High value → player is aggressive; AI should be more defensive / spread out.
func get_player_aggression() -> float:
	var dmg_dealt: float = player_behavior_data["total_damage_dealt"]
	var dmg_taken: float = player_behavior_data["total_damage_taken"]
	if dmg_taken == 0.0:
		return 1.0
	return clampf(dmg_dealt / (dmg_dealt + dmg_taken), 0.0, 1.0)

# ---------------------------------------------------------------------------
# Camera shake (forwarded to camera if set)
# ---------------------------------------------------------------------------
func shake_camera(intensity: float = 8.0, duration: float = 0.25) -> void:
	if _camera == null:
		_camera = get_tree().get_first_node_in_group("camera")
	if _camera and _camera.has_method("shake"):
		_camera.shake(intensity, duration)

func register_camera(cam: Camera2D) -> void:
	_camera = cam
