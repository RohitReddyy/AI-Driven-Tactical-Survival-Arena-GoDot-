## EnemyManager.gd
## Tracks all living enemies. Broadcasts when all are dead.
## Also provides spatial queries used by the AI system.
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal all_enemies_dead()
signal enemy_registered(enemy: Node)
signal enemy_died(enemy: Node)

# ---------------------------------------------------------------------------
# Runtime
# ---------------------------------------------------------------------------
var _enemies: Array[Node] = []

# ---------------------------------------------------------------------------
# Registration
# ---------------------------------------------------------------------------
func register_enemy(enemy: Node) -> void:
	if enemy not in _enemies:
		_enemies.append(enemy)
		enemy.tree_exiting.connect(_on_enemy_exiting.bind(enemy))
		enemy_registered.emit(enemy)

func unregister_enemy(enemy: Node) -> void:
	_enemies.erase(enemy)
	enemy_died.emit(enemy)
	if _enemies.is_empty():
		all_enemies_dead.emit()

func get_enemy_count() -> int:
	return _enemies.size()

func get_all_enemies() -> Array[Node]:
	return _enemies.duplicate()

# ---------------------------------------------------------------------------
# Spatial queries (used by AI)
# ---------------------------------------------------------------------------
## Returns the nearest enemy to position, excluding `exclude` node.
func get_nearest_enemy(pos: Vector2, exclude: Node = null) -> Node:
	var nearest: Node = null
	var best_dist := INF
	for e in _enemies:
		if e == exclude:
			continue
		var d := pos.distance_squared_to(e.global_position)
		if d < best_dist:
			best_dist = d
			nearest = e
	return nearest

## Returns enemies within radius of position.
func get_enemies_in_radius(pos: Vector2, radius: float) -> Array[Node]:
	var result: Array[Node] = []
	var r2 := radius * radius
	for e in _enemies:
		if pos.distance_squared_to(e.global_position) <= r2:
			result.append(e)
	return result

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------
func _on_enemy_exiting(enemy: Node) -> void:
	unregister_enemy(enemy)
