## MiniMap.gd
## Renders a small overview of the arena with player and enemy blips.
extends Control

@export var arena_size: Vector2 = Vector2(1280, 720)
@export var map_size:   Vector2 = Vector2(160, 90)
@export var player_color: Color = Color(0.2, 1.0, 0.4)
@export var enemy_color:  Color = Color(1.0, 0.2, 0.2)
@export var boss_color:   Color = Color(1.0, 0.5, 0.0)

var _player: Node2D = null

func _ready() -> void:
	custom_minimum_size = map_size
	_player = get_tree().get_first_node_in_group("player")

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	# Background
	draw_rect(Rect2(Vector2.ZERO, map_size), Color(0.05, 0.05, 0.15, 0.8))
	draw_rect(Rect2(Vector2.ZERO, map_size), Color(0.3, 0.3, 0.5), false, 1.0)

	# Scale factor
	var scale_x := map_size.x / arena_size.x
	var scale_y := map_size.y / arena_size.y

	# Player blip
	if _player and is_instance_valid(_player):
		var pp: Vector2 = _player.global_position * Vector2(scale_x, scale_y)
		draw_circle(pp, 3.5, player_color)

	# Enemy blips
	for enemy in EnemyManager.get_all_enemies():
		if is_instance_valid(enemy):
			var ep: Vector2 = (enemy as Node2D).global_position * Vector2(scale_x, scale_y)
			var color := boss_color if enemy.get("enemy_type") == "boss" else enemy_color
			draw_circle(ep, 2.5, color)
