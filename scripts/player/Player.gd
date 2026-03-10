## Player.gd
## Handles all player logic: movement, dash, shooting, health, and upgrades.
## Uses CharacterBody2D physics. Communicates via signals.
extends CharacterBody2D

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal health_changed(current: float, maximum: float)
signal died()
signal dash_cooldown_changed(remaining: float, total: float)

# ---------------------------------------------------------------------------
# Stats (modified by UpgradeManager)
# ---------------------------------------------------------------------------
var stats := {
	"speed":         280.0,
	"max_health":    100.0,
	"damage":         20.0,
	"fire_rate":       0.18,  # seconds between shots
	"dash_cooldown":   1.2,
	"dash_speed":    700.0,
	"dash_duration":   0.12,
	"bullet_speed":  550.0,
	"bullet_count":    1,     # number of bullets per shot
	"crit_chance":     0.05,
	"explosive":       0,     # 0 = no, ≥1 = yes
	"ricochet":        0,     # 0 = no, ≥1 = yes
}

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------
var current_health: float
var _fire_timer: float = 0.0
var _dash_timer: float = 0.0     # cooldown remaining
var _dash_active: float = 0.0    # dash duration remaining
var _dash_direction: Vector2 = Vector2.ZERO
var _is_dashing: bool = false
var _is_dead: bool = false
var _shoot_pressed: bool = false

# Node references
@onready var _sprite:         Polygon2D  = $Sprite
@onready var _gun_pivot:      Node2D     = $GunPivot
@onready var _muzzle:         Marker2D   = $GunPivot/Muzzle
@onready var _collision:      CollisionShape2D = $CollisionShape2D
@onready var _invuln_timer:   Timer      = $InvulnTimer
@onready var _anim_player:    AnimationPlayer = $AnimationPlayer
@onready var _dash_particles: GPUParticles2D  = $DashParticles
@onready var _hit_particles:  GPUParticles2D  = $HitParticles

const BULLET_SCENE := "res://scenes/projectiles/Bullet.tscn"

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	current_health = stats["max_health"]
	add_to_group("player")
	health_changed.emit(current_health, stats["max_health"])

func _process(delta: float) -> void:
	_handle_aim()
	_handle_shooting(delta)
	_update_dash_cooldown(delta)

func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_handle_movement(delta)
	move_and_slide()

# ---------------------------------------------------------------------------
# Movement
# ---------------------------------------------------------------------------
func _handle_movement(delta: float) -> void:
	if _is_dashing:
		_dash_active -= delta
		velocity = _dash_direction * stats["dash_speed"]
		if _dash_active <= 0.0:
			_end_dash()
		return

	var dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up",   "move_down")
	).normalized()

	velocity = dir * stats["speed"]

	if Input.is_action_just_pressed("dash") and _dash_timer <= 0.0 and dir != Vector2.ZERO:
		_start_dash(dir)

func _start_dash(dir: Vector2) -> void:
	_is_dashing = true
	_dash_active = stats["dash_duration"]
	_dash_timer  = stats["dash_cooldown"]
	_dash_direction = dir

	# Invulnerability during dash
	_invuln_timer.start(stats["dash_duration"] + 0.05)

	if _dash_particles:
		_dash_particles.emitting = true

	GameManager.record_dash()
	dash_cooldown_changed.emit(_dash_timer, stats["dash_cooldown"])

func _end_dash() -> void:
	_is_dashing = false
	if _dash_particles:
		_dash_particles.emitting = false

func _update_dash_cooldown(delta: float) -> void:
	if _dash_timer > 0.0:
		_dash_timer = maxf(_dash_timer - delta, 0.0)
		dash_cooldown_changed.emit(_dash_timer, stats["dash_cooldown"])

# ---------------------------------------------------------------------------
# Aim
# ---------------------------------------------------------------------------
func _handle_aim() -> void:
	if _gun_pivot:
		var mouse := get_global_mouse_position()
		_gun_pivot.look_at(mouse)

# ---------------------------------------------------------------------------
# Shooting
# ---------------------------------------------------------------------------
func _handle_shooting(delta: float) -> void:
	_fire_timer = maxf(_fire_timer - delta, 0.0)

	if Input.is_action_pressed("shoot") and _fire_timer <= 0.0 and not _is_dead:
		_fire()
		_fire_timer = stats["fire_rate"]

func _fire() -> void:
	GameManager.record_shot()
	var count: int = int(stats["bullet_count"])
	var spread := 0.0

	if count > 1:
		spread = deg_to_rad(12.0)  # spread angle between extra bullets

	var base_angle: float = _gun_pivot.global_rotation if _gun_pivot else 0.0
	var start_angle := base_angle - spread * (count - 1) / 2.0

	for i in count:
		var angle := start_angle + spread * i
		_spawn_bullet(angle)

func _spawn_bullet(angle: float) -> void:
	var bullet: Node2D = ObjectPool.get_instance(BULLET_SCENE, get_parent())
	if not bullet:
		return

	bullet.global_position = _muzzle.global_position if _muzzle else global_position
	bullet.rotation = angle

	# Calculate damage with crit
	var dmg: float = stats["damage"]
	var is_crit: bool = randf() < float(stats["crit_chance"])
	if is_crit:
		dmg *= 2.0

	bullet.init(
		dmg,
		float(stats["bullet_speed"]),
		is_crit,
		int(stats["explosive"]) > 0,
		int(stats["ricochet"]) > 0,
		"player"
	)

# ---------------------------------------------------------------------------
# Health & Damage
# ---------------------------------------------------------------------------
func take_damage(amount: float) -> void:
	if _is_dead or not _invuln_timer.is_stopped():
		return

	current_health = maxf(current_health - amount, 0.0)
	GameManager.record_damage_taken(amount)
	health_changed.emit(current_health, stats["max_health"])
	GameManager.shake_camera(6.0, 0.2)

	# Brief invulnerability after hit
	_invuln_timer.start(0.5)

	if _hit_particles:
		_hit_particles.restart()

	if current_health <= 0.0:
		_die()

func heal(amount: float) -> void:
	current_health = minf(current_health + amount, stats["max_health"])
	health_changed.emit(current_health, stats["max_health"])

func _die() -> void:
	_is_dead = true
	died.emit()
	GameManager.trigger_game_over()
	# Visual death effect
	if _anim_player and _anim_player.has_animation("die"):
		_anim_player.play("die")
	else:
		queue_free()

# ---------------------------------------------------------------------------
# Upgrade system
# ---------------------------------------------------------------------------
## Called by UpgradeManager when the player picks an upgrade.
func apply_upgrade(upg: Dictionary) -> void:
	var key: String = upg["stat_key"]
	var val: float = float(upg["value"])

	if not stats.has(key):
		return

	if upg["type"] == "add":
		stats[key] += val
		# Special: if max_health increased, heal by the same amount
		if key == "max_health":
			current_health = minf(current_health + val, stats["max_health"])
			health_changed.emit(current_health, stats["max_health"])
	elif upg["type"] == "mul":
		stats[key] *= (1.0 + val)
		# Clamp fire_rate to minimum 0.05
		if key == "fire_rate":
			stats["fire_rate"] = maxf(stats["fire_rate"], 0.05)
		if key == "dash_cooldown":
			stats["dash_cooldown"] = maxf(stats["dash_cooldown"], 0.3)
