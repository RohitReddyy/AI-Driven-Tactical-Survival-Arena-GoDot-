## RetreatState.gd
## Enemy flees from the player when health is low.
## Transition: → Chase (health recovered or player far away)
extends State
class_name RetreatState

const RETREAT_SPEED_MULTIPLIER := 1.2
const RECOVERY_THRESHOLD       := 0.35  # return to Chase above this %

func enter() -> void:
	# Brief flash to signal retreat (handled by BaseEnemy visually)
	if enemy.has_method("play_retreat_visual"):
		enemy.play_retreat_visual()

func update(_delta: float) -> String:
	if not enemy.player:
		return "Patrol"

	var hp_ratio := enemy.current_health / enemy.max_health
	var dist     := enemy.global_position.distance_to(enemy.player.global_position)

	# Resume chasing once health is somewhat recovered or player is far
	if hp_ratio > RECOVERY_THRESHOLD or dist > enemy.detection_range:
		return "Chase"

	return ""

func physics_update(_delta: float) -> void:
	if not enemy.player:
		return
	# Move directly away from player
	var dir := (enemy.global_position - enemy.player.global_position).normalized()
	enemy.velocity = dir * enemy.move_speed * RETREAT_SPEED_MULTIPLIER
	enemy.move_and_slide()

	if dir != Vector2.ZERO:
		enemy.rotation = dir.angle()
