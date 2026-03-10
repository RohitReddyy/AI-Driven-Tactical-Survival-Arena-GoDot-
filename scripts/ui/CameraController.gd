## CameraController.gd
## Smooth-following camera with screen shake support.
## Attach to Camera2D. Register with GameManager on ready.
extends Camera2D

@export var follow_speed: float = 8.0
@export var lookahead_strength: float = 40.0  # looks ahead in movement direction

var _shake_intensity: float = 0.0
var _shake_duration:  float = 0.0
var _target: Node2D = null

func _ready() -> void:
	add_to_group("camera")
	GameManager.register_camera(self)
	_target = get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
	if not _target or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player")
		return

	# Smooth follow with lookahead
	var look_offset := Vector2.ZERO
	if "velocity" in _target:
		look_offset = (_target as CharacterBody2D).velocity.normalized() * lookahead_strength

	var target_pos: Vector2 = _target.global_position + look_offset
	global_position = global_position.lerp(target_pos, follow_speed * delta)

	# Screen shake — Godot 4 Camera2D uses offset: Vector2 (not offset_h/offset_v)
	if _shake_duration > 0.0:
		_shake_duration -= delta
		offset = Vector2(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity)
		)
	else:
		offset = offset.lerp(Vector2.ZERO, 20.0 * delta)

func shake(intensity: float, duration: float) -> void:
	_shake_intensity = intensity
	_shake_duration  = duration
