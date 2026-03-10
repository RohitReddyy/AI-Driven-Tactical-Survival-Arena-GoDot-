## HUD.gd
## In-game heads-up display. Shows health, wave, score, enemy count, dash cooldown.
extends CanvasLayer

@onready var _health_bar:     ProgressBar = $MarginContainer/VBox/TopRow/HealthBar
@onready var _health_label:   Label       = $MarginContainer/VBox/TopRow/HealthLabel
@onready var _wave_label:     Label       = $MarginContainer/VBox/TopRow/WaveLabel
@onready var _score_label:    Label       = $MarginContainer/VBox/TopRow/ScoreLabel
@onready var _enemy_label:    Label       = $MarginContainer/VBox/TopRow/EnemyLabel
@onready var _dash_bar:       ProgressBar = $MarginContainer/VBox/DashRow/DashBar
@onready var _dash_label:     Label       = $MarginContainer/VBox/DashRow/DashLabel
@onready var _wave_announce:  Label       = $WaveAnnounce

var _wave_announce_tween: Tween = null

# ---------------------------------------------------------------------------
func _ready() -> void:
	# Connect to game systems
	GameManager.score_changed.connect(_on_score_changed)
	WaveManager.wave_started.connect(_on_wave_started)
	EnemyManager.enemy_died.connect(_on_enemy_count_changed)
	EnemyManager.enemy_registered.connect(_on_enemy_count_changed)

	# Connect to player when available
	call_deferred("_connect_player")

	_update_enemy_label()
	_on_score_changed(GameManager.score)

func _connect_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.health_changed.connect(_on_player_health_changed)
		player.dash_cooldown_changed.connect(_on_dash_cooldown_changed)
		# Initialize bars
		_on_player_health_changed(player.current_health, player.stats["max_health"])

# ---------------------------------------------------------------------------
# Callbacks
# ---------------------------------------------------------------------------
func _on_player_health_changed(current: float, maximum: float) -> void:
	if _health_bar:
		_health_bar.max_value = maximum
		_health_bar.value     = current
	if _health_label:
		_health_label.text = "%d / %d" % [int(current), int(maximum)]
	# Color health bar by percentage
	var ratio := current / maximum
	if _health_bar:
		if ratio > 0.6:
			_health_bar.modulate = Color(0.2, 1.0, 0.3)
		elif ratio > 0.3:
			_health_bar.modulate = Color(1.0, 0.8, 0.0)
		else:
			_health_bar.modulate = Color(1.0, 0.2, 0.2)

func _on_dash_cooldown_changed(remaining: float, total: float) -> void:
	if _dash_bar:
		_dash_bar.max_value = total
		_dash_bar.value     = total - remaining
	if _dash_label:
		if remaining <= 0.0:
			_dash_label.text = "DASH READY"
			_dash_label.modulate = Color(0.2, 1.0, 1.0)
		else:
			_dash_label.text = "DASH %.1fs" % remaining
			_dash_label.modulate = Color.WHITE

func _on_score_changed(score: int) -> void:
	if _score_label:
		_score_label.text = "SCORE: %d" % score

func _on_wave_started(wave: int) -> void:
	if _wave_label:
		_wave_label.text = "WAVE %d" % wave
	_flash_wave_announce(wave)
	_update_enemy_label()

func _on_enemy_count_changed(_enemy = null) -> void:
	_update_enemy_label()

func _update_enemy_label() -> void:
	if _enemy_label:
		_enemy_label.text = "ENEMIES: %d" % EnemyManager.get_enemy_count()

# ---------------------------------------------------------------------------
# Wave announcement banner
# ---------------------------------------------------------------------------
func _flash_wave_announce(wave: int) -> void:
	if not _wave_announce:
		return
	var is_boss := WaveManager.is_boss_wave(wave)
	_wave_announce.text = ("⚠ BOSS WAVE %d ⚠" if is_boss else "WAVE %d") % wave
	_wave_announce.modulate = Color(1.0, 0.3, 0.1) if is_boss else Color.WHITE
	_wave_announce.modulate.a = 1.0

	if _wave_announce_tween:
		_wave_announce_tween.kill()
	_wave_announce_tween = create_tween()
	_wave_announce_tween.tween_property(_wave_announce, "modulate:a", 1.0, 0.0)
	_wave_announce_tween.tween_interval(2.0)
	_wave_announce_tween.tween_property(_wave_announce, "modulate:a", 0.0, 1.0)
