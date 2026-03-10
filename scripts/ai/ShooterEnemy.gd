## ShooterEnemy.gd
## Ranged enemy that maintains distance and fires projectiles.
## Uses a kiting behavior: backs away when player gets too close.
extends BaseEnemy

const BULLET_SCENE   := "res://scenes/projectiles/EnemyBullet.tscn"
const PREFERRED_DIST := 200.0   # tries to maintain this distance from player
const CLOSE_THRESHOLD := 120.0  # starts backing off below this

func _ready() -> void:
	max_health      = 40.0
	move_speed      = 100.0
	attack_range    = 280.0
	detection_range = 400.0
	attack_cooldown = 1.4
	attack_damage   = 8.0
	score_value     = 150
	retreat_threshold = 0.3   # Shooters retreat earlier
	enemy_type      = "shooter"
	super._ready()

## Override to include kiting movement during attack
func _physics_process(delta: float) -> void:
	if _is_dead or not player:
		super._physics_process(delta)
		return
	# Let state machine handle non-attack states normally
	var state := _state_machine.get_current_state_name() if _state_machine else ""
	if state == "Attack":
		_kite_movement(delta)
	else:
		super._physics_process(delta)

func _kite_movement(delta: float) -> void:
	if not player:
		return
	var dist   := global_position.distance_to(player.global_position)
	var to_player := (player.global_position - global_position).normalized()

	if dist < CLOSE_THRESHOLD:
		# Back away
		velocity = -to_player * move_speed
	elif dist > PREFERRED_DIST * 1.3:
		# Close in a bit
		velocity = to_player * move_speed * 0.5
	else:
		# Strafe perpendicular
		velocity = to_player.rotated(PI / 2.0) * move_speed * 0.4

	move_and_slide()
	rotation = to_player.angle()

func perform_attack() -> void:
	if not player:
		return
	_fire_bullet()

func _fire_bullet() -> void:
	var bullet: Node2D = ObjectPool.get_instance(BULLET_SCENE, get_parent())
	if not bullet:
		return

	var dir := (player.global_position - global_position).normalized()
	# Add slight inaccuracy based on wave number (scaled by WaveManager)
	var spread := deg_to_rad(randf_range(-5.0, 5.0))
	dir = dir.rotated(spread)

	bullet.global_position = global_position
	bullet.rotation = dir.angle()
	if bullet.has_method("init"):
		bullet.init(attack_damage, 400.0, false, false, false, "enemy")
