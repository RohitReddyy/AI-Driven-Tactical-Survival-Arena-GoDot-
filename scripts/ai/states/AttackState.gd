## AttackState.gd
## Enemy executes its attack while within range.
## Transition: → Chase (player out of range), → Retreat (low health)
extends State
class_name AttackState

var _attack_timer: float = 0.0

func enter() -> void:
	_attack_timer = 0.0

func update(delta: float) -> String:
	if not enemy.player:
		return "Patrol"

	# Retreat if health drops low
	if enemy.current_health / enemy.max_health < enemy.retreat_threshold:
		return "Retreat"

	var dist := enemy.global_position.distance_to(enemy.player.global_position)

	# Return to chase if player moved away
	if dist > enemy.attack_range * 1.3:
		return "Chase"

	# Attack cooldown
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		enemy.perform_attack()
		_attack_timer = enemy.attack_cooldown

	# Dynamic aggression: if player is aggressive, enemies act faster
	var aggression := GameManager.get_player_aggression()
	_attack_timer -= delta * aggression * 0.3  # bonus tick speed

	return ""

func physics_update(_delta: float) -> void:
	if not enemy.player:
		return
	# Face the player while attacking
	var dir := (enemy.player.global_position - enemy.global_position).normalized()
	if dir != Vector2.ZERO:
		enemy.rotation = dir.angle()
	enemy.velocity = Vector2.ZERO
	enemy.move_and_slide()
