## Arena.gd
## Root scene script. Manages the play area, obstacle generation,
## enemy spawning (delegates to WaveManager), and pause menu.
extends Node2D

# ---------------------------------------------------------------------------
# Arena configuration
# ---------------------------------------------------------------------------
const ARENA_WIDTH  := 1280.0
const ARENA_HEIGHT := 720.0
const WALL_THICKNESS := 24.0

const OBSTACLE_COUNT_MIN := 8
const OBSTACLE_COUNT_MAX := 14
const OBSTACLE_MIN_SIZE  := Vector2(40, 40)
const OBSTACLE_MAX_SIZE  := Vector2(120, 80)

# Enemy scene paths
const ENEMY_SCENES: Dictionary = {
	"chaser":  "res://scenes/enemies/ChaserEnemy.tscn",
	"shooter": "res://scenes/enemies/ShooterEnemy.tscn",
	"tank":    "res://scenes/enemies/TankEnemy.tscn",
	"boss":    "res://scenes/enemies/BossEnemy.tscn",
}

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------
@onready var _player:        Node2D          = $Player
@onready var _enemies_root:  Node2D          = $EnemiesRoot
@onready var _obstacles_root: Node2D         = $ObstaclesRoot
@onready var _pause_panel:   CanvasLayer     = $PausePanel
@onready var _hud:           CanvasLayer     = $HUD
@onready var _upgrade_screen: CanvasLayer    = $UpgradeScreen
@onready var _game_over:     CanvasLayer     = $GameOverScreen
@onready var _camera:        Camera2D        = $Player/Camera2D
@onready var _nav_region:    NavigationRegion2D = $NavigationRegion2D

# ---------------------------------------------------------------------------
func _ready() -> void:
	add_to_group("arena")

	# Pre-warm bullet pools
	ObjectPool.preload_pool("res://scenes/projectiles/Bullet.tscn", 40, self)
	ObjectPool.preload_pool("res://scenes/projectiles/EnemyBullet.tscn", 30, self)

	# Build arena
	_build_walls()
	_generate_obstacles()
	_bake_navigation()

	# Connect WaveManager spawn signal
	WaveManager.spawn_requested.connect(_on_spawn_requested)
	WaveManager.wave_completed.connect(_on_wave_completed)
	WaveManager.set_arena_size(Vector2(ARENA_WIDTH, ARENA_HEIGHT))

	# Connect pause
	GameManager.game_state_changed.connect(_on_game_state_changed)

	# Start the game
	GameManager.start_game()

func get_arena_size() -> Vector2:
	return Vector2(ARENA_WIDTH, ARENA_HEIGHT)

# ---------------------------------------------------------------------------
# Arena geometry
# ---------------------------------------------------------------------------
func _build_walls() -> void:
	var wall_data := [
		# Top wall
		{"pos": Vector2(ARENA_WIDTH / 2, -WALL_THICKNESS / 2),
		 "size": Vector2(ARENA_WIDTH + WALL_THICKNESS * 2, WALL_THICKNESS)},
		# Bottom wall
		{"pos": Vector2(ARENA_WIDTH / 2, ARENA_HEIGHT + WALL_THICKNESS / 2),
		 "size": Vector2(ARENA_WIDTH + WALL_THICKNESS * 2, WALL_THICKNESS)},
		# Left wall
		{"pos": Vector2(-WALL_THICKNESS / 2, ARENA_HEIGHT / 2),
		 "size": Vector2(WALL_THICKNESS, ARENA_HEIGHT)},
		# Right wall
		{"pos": Vector2(ARENA_WIDTH + WALL_THICKNESS / 2, ARENA_HEIGHT / 2),
		 "size": Vector2(WALL_THICKNESS, ARENA_HEIGHT)},
	]

	for data in wall_data:
		var wall := StaticBody2D.new()
		wall.add_to_group("wall")
		wall.collision_layer = 1
		wall.collision_mask  = 0

		var shape := CollisionShape2D.new()
		var rect  := RectangleShape2D.new()
		rect.size = data["size"]
		shape.shape = rect
		wall.add_child(shape)

		var vis := ColorRect.new()
		vis.color = Color(0.2, 0.2, 0.28)
		vis.size  = data["size"]
		vis.position = -data["size"] / 2.0
		wall.add_child(vis)

		wall.global_position = data["pos"]
		add_child(wall)

## Procedurally place obstacles using random noise-guided positions.
func _generate_obstacles() -> void:
	var count := randi_range(OBSTACLE_COUNT_MIN, OBSTACLE_COUNT_MAX)
	var placed: Array[Rect2] = []
	var margin := 80.0
	var attempts := 0

	while placed.size() < count and attempts < 200:
		attempts += 1
		var size := Vector2(
			randf_range(OBSTACLE_MIN_SIZE.x, OBSTACLE_MAX_SIZE.x),
			randf_range(OBSTACLE_MIN_SIZE.y, OBSTACLE_MAX_SIZE.y)
		)
		var pos := Vector2(
			randf_range(margin, ARENA_WIDTH  - margin - size.x),
			randf_range(margin, ARENA_HEIGHT - margin - size.y)
		)
		var candidate := Rect2(pos, size)

		# Reject if too close to the player spawn point (arena center)
		var arena_center := Vector2(ARENA_WIDTH / 2, ARENA_HEIGHT / 2)
		if (pos + size / 2.0).distance_to(arena_center) < 150.0:
			continue

		# Reject if overlapping another obstacle
		var overlap := false
		for r in placed:
			if r.intersects(candidate.grow(12)):
				overlap = true
				break
		if overlap:
			continue

		placed.append(candidate)
		_create_obstacle(pos + size / 2.0, size)

func _create_obstacle(center: Vector2, size: Vector2) -> void:
	var obs := StaticBody2D.new()
	obs.add_to_group("obstacle")
	obs.collision_layer = 1
	obs.collision_mask  = 0
	obs.global_position = center

	var shape := CollisionShape2D.new()
	var rect  := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	obs.add_child(shape)

	var vis := ColorRect.new()
	vis.color = Color(randf_range(0.25, 0.40), randf_range(0.25, 0.40), randf_range(0.30, 0.45))
	vis.size     = size
	vis.position = -size / 2.0
	obs.add_child(vis)

	_obstacles_root.add_child(obs)

## Trigger NavigationRegion2D bake after obstacles are in the tree.
func _bake_navigation() -> void:
	if _nav_region:
		# Defer so all StaticBody2D obstacles are fully registered before baking.
		call_deferred("_do_bake")

func _do_bake() -> void:
	if _nav_region:
		_nav_region.bake_navigation_polygon()

# ---------------------------------------------------------------------------
# Enemy spawning
# ---------------------------------------------------------------------------
func _on_spawn_requested(enemy_type: String, spawn_pos: Vector2) -> void:
	var path: String = ENEMY_SCENES.get(enemy_type, ENEMY_SCENES["chaser"])
	var ps: PackedScene = load(path)
	if not ps:
		return
	var enemy: Node2D = ps.instantiate()
	enemy.global_position = spawn_pos
	_enemies_root.add_child(enemy)

	# Apply wave difficulty scaling
	if enemy.has_method("apply_wave_scaling"):
		enemy.apply_wave_scaling(
			WaveManager.get_speed_scale(WaveManager.current_wave),
			WaveManager.get_health_scale(WaveManager.current_wave)
		)

	EnemyManager.register_enemy(enemy)

# ---------------------------------------------------------------------------
# Wave events
# ---------------------------------------------------------------------------
func _on_wave_completed(_wave: int) -> void:
	# Short pause then show upgrade screen
	await get_tree().create_timer(1.5).timeout
	GameManager.begin_upgrade_phase()

# ---------------------------------------------------------------------------
# Game state
# ---------------------------------------------------------------------------
func _on_game_state_changed(state: int) -> void:
	match state:
		GameManager.GameState.PAUSED:
			if _pause_panel:
				_pause_panel.show()
		GameManager.GameState.PLAYING:
			if _pause_panel:
				_pause_panel.hide()
