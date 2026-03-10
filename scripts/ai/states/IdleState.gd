## IdleState.gd
## Enemy stands still briefly, then transitions to Patrol.
## Transition: → Patrol (after timer), → Chase (player nearby)
extends State
class_name IdleState

var _timer: float = 0.0
const IDLE_DURATION := 1.5

func enter() -> void:
	_timer = IDLE_DURATION
	enemy.velocity = Vector2.ZERO

func update(delta: float) -> String:
	_timer -= delta

	# If player is close, start chasing immediately
	if enemy.player and enemy.global_position.distance_to(enemy.player.global_position) < enemy.detection_range:
		return "Chase"

	if _timer <= 0.0:
		return "Patrol"

	return ""
