## BaseEnemy.gd
## Foundation for all enemy types. Manages health, stats, death, and FSM.
## Subclasses override perform_attack() and configure stats.
extends CharacterBody2D
class_name BaseEnemy

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal health_changed(current: float, maximum: float)
signal died(enemy: BaseEnemy)
signal state_changed(state_name: String)

# ---------------------------------------------------------------------------
# Base stats (overridden per enemy type)
# ---------------------------------------------------------------------------
@export var max_health:         float = 60.0
@export var move_speed:         float = 120.0
@export var attack_range:       float = 80.0
@export var detection_range:    float = 350.0
@export var attack_cooldown:    float = 1.2
@export var attack_damage:      float = 10.0
@export var score_value:        int   = 100
@export var retreat_threshold:  float = 0.25   # retreat below this HP ratio
@export var enemy_type:         String = "base"

# ---------------------------------------------------------------------------
# Runtime
# ---------------------------------------------------------------------------
var current_health: float
var player: Node2D = null       # set by _find_player()
var _is_dead: bool = false
var _wave_speed_scale: float = 1.0
var _wave_health_scale: float = 1.0

# Node references (set up in scene)
@onready var _sprite:          Polygon2D = $Sprite
@onready var _health_bar:      ProgressBar = $HealthBar
@onready var _state_machine:   StateMachine = $StateMachine
@onready var _nav_agent:       NavigationAgent2D = $NavigationAgent2D
@onready var _hit_flash_timer: Timer = $HitFlashTimer
@onready var _death_particles: GPUParticles2D = $DeathParticles

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	current_health = max_health
	add_to_group("enemy")

	player = _find_player()
	if not player:
		# Defer in case player isn't in tree yet
		call_deferred("_find_player_deferred")

	EnemyManager.register_enemy(self)

	if _health_bar:
		_health_bar.max_value = max_health
		_health_bar.value = current_health

	if _state_machine:
		_state_machine.state_changed.connect(_on_state_changed)

## Apply wave difficulty scaling (called by Arena on spawn).
func apply_wave_scaling(speed_scale: float, health_scale: float) -> void:
	_wave_speed_scale  = speed_scale
	_wave_health_scale = health_scale
	move_speed   *= speed_scale
	max_health   *= health_scale
	current_health = max_health
	if _health_bar:
		_health_bar.max_value = max_health
		_health_bar.value = current_health

# ---------------------------------------------------------------------------
# Player lookup
# ---------------------------------------------------------------------------
func _find_player() -> Node:
	return get_tree().get_first_node_in_group("player")

func _find_player_deferred() -> void:
	player = _find_player()

# ---------------------------------------------------------------------------
# Health & damage
# ---------------------------------------------------------------------------
func take_damage(amount: float) -> void:
	if _is_dead:
		return

	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health, max_health)

	if _health_bar:
		_health_bar.value = current_health

	# Hit flash
	_flash_sprite(Color(1, 0.3, 0.3))

	if current_health <= 0.0:
		_die()

func _flash_sprite(color: Color) -> void:
	if _sprite:
		_sprite.modulate = color
	if _hit_flash_timer:
		_hit_flash_timer.start(0.1)

func _on_hit_flash_timeout() -> void:
	if _sprite:
		_sprite.modulate = Color.WHITE

func play_retreat_visual() -> void:
	_flash_sprite(Color(0.3, 0.3, 1.0))

func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	died.emit(self)
	GameManager.add_score(score_value)

	if _death_particles:
		_death_particles.restart()
		_death_particles.emitting = true

	GameManager.shake_camera(4.0, 0.15)
	set_physics_process(false)
	set_process(false)

	# Wait for death particles then free
	await get_tree().create_timer(0.5).timeout
	queue_free()

# ---------------------------------------------------------------------------
# Attack – subclasses override this
# ---------------------------------------------------------------------------
func perform_attack() -> void:
	pass  # implemented by ChaserEnemy, ShooterEnemy, etc.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
func _on_state_changed(old_state: String, new_state: String) -> void:
	state_changed.emit(new_state)

# ---------------------------------------------------------------------------
# Area hit detection (connected in scene)
# ---------------------------------------------------------------------------
func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_bullet"):
		if area.has_method("get_damage"):
			var dmg: float = area.get_damage()
			take_damage(dmg)
			GameManager.record_damage_dealt(dmg)
			# Spawn floating damage number
			_spawn_damage_number(dmg, area.is_critical if "is_critical" in area else false)
			# Return bullet to pool
			ObjectPool.return_instance(area)

func _spawn_damage_number(dmg: float, crit: bool) -> void:
	var dn_scene: PackedScene = load("res://scenes/ui/DamageNumber.tscn")
	if not dn_scene:
		return
	var dn := dn_scene.instantiate()
	get_parent().add_child(dn)
	dn.global_position = global_position + Vector2(randf_range(-15, 15), -20)
	if dn.has_method("setup"):
		dn.setup(int(dmg), crit)
