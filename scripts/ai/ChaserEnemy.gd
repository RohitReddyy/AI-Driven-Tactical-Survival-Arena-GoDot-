## ChaserEnemy.gd
## Fast melee enemy that charges directly at the player.
## Performs a contact damage attack when adjacent.
extends BaseEnemy

func _ready() -> void:
	# Configure stats
	max_health      = 50.0
	move_speed      = 160.0
	attack_range    = 45.0
	detection_range = 380.0
	attack_cooldown = 0.8
	attack_damage   = 12.0
	score_value     = 100
	retreat_threshold = 0.15  # Chasers are brave — retreat at 15%
	enemy_type      = "chaser"
	super._ready()

func perform_attack() -> void:
	if not player or not player.has_method("take_damage"):
		return
	# Melee lunge — only deal damage if still close
	var dist := global_position.distance_to(player.global_position)
	if dist <= attack_range * 1.2:
		player.take_damage(attack_damage)
		# Quick visual burst
		if _sprite:
			_sprite.modulate = Color(1.5, 0.5, 0.5)
			await get_tree().create_timer(0.1).timeout
			_sprite.modulate = Color.WHITE
