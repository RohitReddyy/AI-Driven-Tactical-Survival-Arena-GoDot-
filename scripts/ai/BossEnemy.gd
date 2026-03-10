## BossEnemy.gd
## Powerful boss that spawns every 5 waves.
## Uses three attack phases based on remaining health.
## Phase 1 (>66%): fires spread shots
## Phase 2 (33-66%): fires spiral pattern + summons helpers
## Phase 3 (<33%): all attacks + charges + rapid fire
extends BaseEnemy

const BULLET_SCENE      := "res://scenes/projectiles/EnemyBullet.tscn"
const CHASER_SCENE      := "res://scenes/enemies/ChaserEnemy.tscn"
const SUMMON_COOLDOWN   := 8.0
const SPIRAL_SHOTS      := 12
const SPREAD_SHOTS      := 5

var _phase: int = 1
var _summon_timer: float = SUMMON_COOLDOWN
var _spiral_angle: float = 0.0

func _ready() -> void:
	max_health      = 800.0
	move_speed      = 90.0
	attack_range    = 340.0
	detection_range = 600.0
	attack_cooldown = 0.6
	attack_damage   = 15.0
	score_value     = 1000
	retreat_threshold = 0.0  # Bosses never retreat
	enemy_type      = "boss"
	super._ready()

func _process(delta: float) -> void:
	if _is_dead:
		return
	_update_phase()
	_summon_timer -= delta

func _update_phase() -> void:
	var ratio := current_health / max_health
	if ratio > 0.66:
		_phase = 1
	elif ratio > 0.33:
		_phase = 2
	else:
		_phase = 3

	# Phase 3 speeds up the boss
	if _phase == 3:
		move_speed = 140.0
		attack_cooldown = 0.35

func perform_attack() -> void:
	match _phase:
		1: _attack_spread()
		2:
			_attack_spread()
			_attack_spiral()
			if _summon_timer <= 0.0:
				_summon_minions(2)
				_summon_timer = SUMMON_COOLDOWN
		3:
			_attack_spread()
			_attack_spiral()
			_attack_spiral()  # Double spiral in phase 3
			if _summon_timer <= 0.0:
				_summon_minions(3)
				_summon_timer = SUMMON_COOLDOWN
	GameManager.shake_camera(3.0, 0.1)

func _attack_spread() -> void:
	if not player:
		return
	var base_dir := (player.global_position - global_position).normalized()
	var spread_angle := deg_to_rad(15.0)
	var half := (SPREAD_SHOTS - 1) / 2.0
	for i in SPREAD_SHOTS:
		var angle := base_dir.angle() + spread_angle * (i - half)
		_fire_bullet(Vector2.RIGHT.rotated(angle), attack_damage)

func _attack_spiral() -> void:
	var step := TAU / SPIRAL_SHOTS
	for i in SPIRAL_SHOTS:
		var dir := Vector2.RIGHT.rotated(_spiral_angle + step * i)
		_fire_bullet(dir, attack_damage * 0.6)
	_spiral_angle += deg_to_rad(15.0)

func _fire_bullet(dir: Vector2, damage: float) -> void:
	var bullet: Node2D = ObjectPool.get_instance(BULLET_SCENE, get_parent())
	if not bullet:
		return
	bullet.global_position = global_position
	bullet.rotation = dir.angle()
	if bullet.has_method("init"):
		bullet.init(damage, 320.0, false, false, false, "enemy")

func _summon_minions(count: int) -> void:
	var ps: PackedScene = load(CHASER_SCENE)
	if not ps:
		return
	for i in count:
		var minion := ps.instantiate()
		var angle := TAU * i / count
		var offset := Vector2.RIGHT.rotated(angle) * 80.0
		minion.global_position = global_position + offset
		get_parent().add_child(minion)
		minion.apply_wave_scaling(
			WaveManager.get_speed_scale(WaveManager.current_wave),
			WaveManager.get_health_scale(WaveManager.current_wave) * 0.5
		)
		EnemyManager.register_enemy(minion)
