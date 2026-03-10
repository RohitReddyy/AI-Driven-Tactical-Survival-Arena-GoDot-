## Bullet.gd
## Pooled projectile. Handles movement, collision, effects, and ricochet.
## Works for both player and enemy bullets (differentiated by `source` group).
extends Area2D

# ---------------------------------------------------------------------------
# Configuration (set by init())
# ---------------------------------------------------------------------------
var damage:      float  = 10.0
var speed:       float  = 550.0
var is_critical: bool   = false
var is_explosive: bool  = false
var can_ricochet: bool  = false
var source:      String = "player"   # "player" or "enemy"

# Internal
var _direction:      Vector2 = Vector2.RIGHT
var _ricochet_used:  bool    = false
var _lifetime:       float   = 3.0
var _age:            float   = 0.0

const EXPLOSION_RADIUS  := 80.0
const EXPLOSION_DAMAGE  := 0.6   # fraction of bullet damage

@onready var _sprite:   Polygon2D = $Sprite
@onready var _particles: GPUParticles2D = $TrailParticles

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= _lifetime:
		_return_to_pool()
		return
	global_position += _direction * speed * delta

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------
func init(dmg: float, spd: float, crit: bool, explosive: bool, ricochet: bool, src: String) -> void:
	damage       = dmg
	speed        = spd
	is_critical  = crit
	is_explosive = explosive
	can_ricochet = ricochet
	source       = src
	_direction   = Vector2.RIGHT.rotated(rotation)
	_age         = 0.0
	_ricochet_used = false

	# Set collision layers based on source
	if source == "player":
		collision_layer = 8    # layer 4
		collision_mask  = 4    # layer 3 (enemies)
		add_to_group("player_bullet")
		if _sprite:
			_sprite.color = Color.YELLOW if crit else Color(0.2, 0.9, 1.0)
	else:
		collision_layer = 16   # layer 5
		collision_mask  = 2    # layer 2 (player)
		add_to_group("enemy_bullet")
		if _sprite:
			_sprite.color = Color(1.0, 0.3, 0.3)

func get_damage() -> float:
	return damage

## Called by ObjectPool when returned.
func on_returned() -> void:
	remove_from_group("player_bullet")
	remove_from_group("enemy_bullet")

## Called by ObjectPool when activated.
func on_spawned() -> void:
	_age = 0.0
	_ricochet_used = false

# ---------------------------------------------------------------------------
# Collision
# ---------------------------------------------------------------------------
func _on_area_entered(area: Area2D) -> void:
	_handle_hit(area)

func _on_body_entered(body: Node) -> void:
	# Wall/obstacle collision → ricochet or destroy
	if body.is_in_group("obstacle") or body.is_in_group("wall"):
		if can_ricochet and not _ricochet_used:
			_do_ricochet(body)
		else:
			_on_impact()

func _handle_hit(area: Area2D) -> void:
	# Player bullet hitting enemy hurtbox
	if source == "player" and area.is_in_group("enemy_hurtbox"):
		_on_impact()
	# Enemy bullet hitting player hurtbox
	elif source == "enemy" and area.is_in_group("player_hurtbox"):
		var player := area.get_parent()
		if player and player.has_method("take_damage"):
			player.take_damage(damage)
		_on_impact()

func _on_impact() -> void:
	if is_explosive:
		_explode()
	_return_to_pool()

func _explode() -> void:
	# AoE damage to all enemies in radius
	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = EXPLOSION_RADIUS
	query.shape = shape
	query.transform = Transform2D(0, global_position)
	query.collision_mask = 4  # enemies layer

	var results := space.intersect_shape(query, 16)
	for result in results:
		var node := result["collider"]
		if node.has_method("take_damage"):
			node.take_damage(damage * EXPLOSION_DAMAGE)

	# Visual explosion (screen shake)
	GameManager.shake_camera(5.0, 0.2)

func _do_ricochet(body: Node) -> void:
	_ricochet_used = true
	# Reflect direction based on collision normal
	var normal := (global_position - body.global_position).normalized()
	_direction = _direction.bounce(normal)
	rotation = _direction.angle()

func _return_to_pool() -> void:
	ObjectPool.return_instance(self)
