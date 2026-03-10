## WaveManager.gd
## Controls wave progression, enemy spawning, and difficulty scaling.
## Autoloaded singleton. Communicates via signals.
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal all_enemies_defeated()
signal spawn_requested(enemy_type: String, spawn_pos: Vector2)

# ---------------------------------------------------------------------------
# Wave configuration
# ---------------------------------------------------------------------------
const BASE_ENEMIES_PER_WAVE   := 5
const ENEMIES_PER_WAVE_SCALE  := 3   # extra enemies added per wave
const BOSS_WAVE_INTERVAL      := 5   # boss spawns every N waves
const BETWEEN_WAVE_DELAY      := 3.0 # seconds before next wave starts

# Enemy type weights per wave tier (higher wave = more heavies)
const ENEMY_POOL: Array[Dictionary] = [
	{"type": "chaser",  "min_wave": 1, "base_weight": 60},
	{"type": "shooter", "min_wave": 2, "base_weight": 30},
	{"type": "tank",    "min_wave": 3, "base_weight": 10},
]

# ---------------------------------------------------------------------------
# Runtime state
# ---------------------------------------------------------------------------
var current_wave: int = 0
var enemies_remaining: int = 0
var _spawn_timer: Timer = null
var _arena_size: Vector2 = Vector2(1280, 720)  # updated by Arena

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	EnemyManager.all_enemies_dead.connect(_on_all_enemies_dead)

	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = true
	_spawn_timer.timeout.connect(_do_spawn_wave)
	add_child(_spawn_timer)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------
func start_wave_sequence() -> void:
	current_wave = 0
	start_next_wave()

func start_next_wave() -> void:
	current_wave += 1
	wave_started.emit(current_wave)
	# Small delay before spawning so UI can update
	_spawn_timer.start(1.2)

func set_arena_size(size: Vector2) -> void:
	_arena_size = size

# ---------------------------------------------------------------------------
# Difficulty helpers
# ---------------------------------------------------------------------------
## Total enemies to spawn this wave.
func get_enemy_count_for_wave(wave: int) -> int:
	return BASE_ENEMIES_PER_WAVE + (wave - 1) * ENEMIES_PER_WAVE_SCALE

## Speed multiplier applied to enemies this wave.
func get_speed_scale(wave: int) -> float:
	return 1.0 + (wave - 1) * 0.08

## Health multiplier applied to enemies this wave.
func get_health_scale(wave: int) -> float:
	return 1.0 + (wave - 1) * 0.15

## True when a boss should spawn this wave.
func is_boss_wave(wave: int) -> bool:
	return wave % BOSS_WAVE_INTERVAL == 0

# ---------------------------------------------------------------------------
# Internal – spawn logic
# ---------------------------------------------------------------------------
func _do_spawn_wave() -> void:
	var count := get_enemy_count_for_wave(current_wave)
	enemies_remaining = count

	# Boss wave: spawn one boss + smaller escort
	if is_boss_wave(current_wave):
		_request_spawn("boss", _get_spawn_position())
		count = max(1, count / 2)

	# Build weighted enemy pool for this wave
	var pool := _build_weighted_pool(current_wave)

	for i in count:
		var enemy_type := _pick_from_pool(pool)
		var pos := _get_spawn_position()
		_request_spawn(enemy_type, pos)

func _request_spawn(enemy_type: String, pos: Vector2) -> void:
	spawn_requested.emit(enemy_type, pos)

## Weighted random selection from pool filtered by wave.
func _build_weighted_pool(wave: int) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for entry in ENEMY_POOL:
		if wave >= int(entry["min_wave"]):
			pool.append(entry)
	return pool

func _pick_from_pool(pool: Array[Dictionary]) -> String:
	if pool.is_empty():
		return "chaser"
	var total_weight := 0
	for entry in pool:
		total_weight += int(entry["base_weight"])
	var roll := randi_range(0, total_weight - 1)
	var cumulative := 0
	for entry in pool:
		cumulative += int(entry["base_weight"])
		if roll < cumulative:
			return String(entry["type"])
	return String(pool[-1]["type"])

## Returns a random position along the arena edge (with padding).
func _get_spawn_position() -> Vector2:
	var pad := 60.0
	var side := randi() % 4
	match side:
		0: return Vector2(randf_range(pad, _arena_size.x - pad), pad)             # top
		1: return Vector2(randf_range(pad, _arena_size.x - pad), _arena_size.y - pad) # bottom
		2: return Vector2(pad, randf_range(pad, _arena_size.y - pad))             # left
		3: return Vector2(_arena_size.x - pad, randf_range(pad, _arena_size.y - pad)) # right
	return Vector2(_arena_size / 2)

# ---------------------------------------------------------------------------
# Callbacks
# ---------------------------------------------------------------------------
func _on_all_enemies_dead() -> void:
	wave_completed.emit(current_wave)
	GameManager.trigger_wave_complete()
