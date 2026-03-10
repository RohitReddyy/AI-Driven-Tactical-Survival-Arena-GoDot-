## PatrolState.gd
## Enemy wanders between random waypoints in the arena.
## Transition: → Chase (player detected), → Idle (waypoint reached)
extends State
class_name PatrolState

var _target_pos: Vector2 = Vector2.ZERO
var _stuck_timer: float = 0.0
const STUCK_THRESHOLD := 2.0
const WAYPOINT_RADIUS := 32.0
const ARENA_MARGIN := 80.0

func enter() -> void:
	_pick_waypoint()
	_stuck_timer = 0.0

func update(delta: float) -> String:
	if not enemy.player:
		return ""

	# Detect player
	var dist_to_player := enemy.global_position.distance_to(enemy.player.global_position)
	if dist_to_player < enemy.detection_range:
		return "Chase"

	# Check arrival
	if enemy.global_position.distance_to(_target_pos) < WAYPOINT_RADIUS:
		return "Idle"

	# Stuck check
	if enemy.velocity.length() < 10.0:
		_stuck_timer += delta
		if _stuck_timer > STUCK_THRESHOLD:
			_pick_waypoint()
			_stuck_timer = 0.0
	else:
		_stuck_timer = 0.0

	return ""

func physics_update(_delta: float) -> void:
	var dir := ((_target_pos - enemy.global_position).normalized())
	enemy.velocity = dir * enemy.move_speed * 0.5  # slower during patrol
	enemy.move_and_slide()

func _pick_waypoint() -> void:
	# Pick a random point inside the arena bounds
	var arena := enemy.get_tree().get_first_node_in_group("arena")
	var size := Vector2(1280, 720)
	if arena and arena.has_method("get_arena_size"):
		size = arena.get_arena_size()
	_target_pos = Vector2(
		randf_range(ARENA_MARGIN, size.x - ARENA_MARGIN),
		randf_range(ARENA_MARGIN, size.y - ARENA_MARGIN)
	)
