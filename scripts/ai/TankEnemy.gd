## TankEnemy.gd
## Slow, high-health enemy. Bulldozes through obstacles.
## Uses a charge attack every few seconds.
extends BaseEnemy

const CHARGE_COOLDOWN  := 4.0
const CHARGE_SPEED     := 380.0
const CHARGE_DURATION  := 0.4
const CHARGE_DAMAGE    := 25.0

var _charge_timer: float = 0.0
var _is_charging: bool = false
var _charge_time_left: float = 0.0
var _charge_direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	max_health      = 200.0
	move_speed      = 70.0
	attack_range    = 55.0
	detection_range = 320.0
	attack_cooldown = 2.0
	attack_damage   = 20.0
	score_value     = 250
	retreat_threshold = 0.10  # Tanks almost never retreat
	enemy_type      = "tank"
	super._ready()

func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if _is_charging:
		_charge_time_left -= delta
		velocity = _charge_direction * CHARGE_SPEED
		move_and_slide()

		# Damage player if we hit them during charge
		if player:
			var dist := global_position.distance_to(player.global_position)
			if dist < 50.0 and player.has_method("take_damage"):
				player.take_damage(CHARGE_DAMAGE)

		if _charge_time_left <= 0.0:
			_is_charging = false
		return

	super._physics_process(delta)

	# Charge timer ticks during chase/attack
	_charge_timer -= delta

func perform_attack() -> void:
	# Regular melee
	if not player or not player.has_method("take_damage"):
		return
	var dist := global_position.distance_to(player.global_position)
	if dist <= attack_range * 1.2:
		player.take_damage(attack_damage)

	# Trigger charge on cooldown
	if _charge_timer <= 0.0 and player:
		_start_charge()
		_charge_timer = CHARGE_COOLDOWN

func _start_charge() -> void:
	if not player:
		return
	_is_charging = true
	_charge_time_left = CHARGE_DURATION
	_charge_direction = (player.global_position - global_position).normalized()
	GameManager.shake_camera(5.0, 0.2)
