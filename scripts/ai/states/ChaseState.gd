## ChaseState.gd
## Enemy pursues the player using NavigationAgent2D if available.
## Transition: → Attack (in range), → Retreat (low health), → Patrol (lost player)
extends State
class_name ChaseState

var _lost_timer: float = 0.0
const LOSE_TIMER_MAX := 3.0
const NAV_UPDATE_INTERVAL := 0.25  # seconds between path updates

var _nav_timer: float = 0.0
var _nav_agent: NavigationAgent2D = null

func enter() -> void:
	_lost_timer = 0.0
	_nav_agent = enemy.get_node_or_null("NavigationAgent2D")
	if _nav_agent:
		_nav_agent.max_speed = enemy.move_speed

func update(delta: float) -> String:
	if not enemy.player:
		return "Patrol"

	# Retreat if health is critically low
	if enemy.current_health / enemy.max_health < enemy.retreat_threshold:
		return "Retreat"

	var dist := enemy.global_position.distance_to(enemy.player.global_position)

	# Attack when in range
	if dist <= enemy.attack_range:
		return "Attack"

	# Lost player
	if dist > enemy.detection_range * 1.5:
		_lost_timer += delta
		if _lost_timer > LOSE_TIMER_MAX:
			return "Patrol"
	else:
		_lost_timer = 0.0

	# Update navigation path
	if _nav_agent:
		_nav_timer -= delta
		if _nav_timer <= 0.0:
			_nav_agent.target_position = enemy.player.global_position
			_nav_timer = NAV_UPDATE_INTERVAL
	return ""

func physics_update(_delta: float) -> void:
	if not enemy.player:
		return

	var dir: Vector2
	if _nav_agent and not _nav_agent.is_navigation_finished():
		var next := _nav_agent.get_next_path_position()
		dir = (next - enemy.global_position).normalized()
	else:
		dir = (enemy.player.global_position - enemy.global_position).normalized()

	enemy.velocity = dir * enemy.move_speed
	enemy.move_and_slide()

	# Face movement direction
	if dir != Vector2.ZERO:
		enemy.rotation = dir.angle()
