## UpgradeManager.gd
## Defines all upgrades and applies them to the player.
## Presents random selection of upgrades after each wave.
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal upgrades_ready(options: Array[Dictionary])
signal upgrade_applied(upgrade: Dictionary)

# ---------------------------------------------------------------------------
# Upgrade definitions
## Each entry: id, name, description, stat_key, value, type ("add"|"mul")
# ---------------------------------------------------------------------------
const ALL_UPGRADES: Array[Dictionary] = [
	{
		"id": "speed_up",
		"name": "Swift Feet",
		"description": "Move speed +15%",
		"stat_key": "speed",
		"value": 0.15,
		"type": "mul",
		"icon_color": Color(0.2, 0.8, 1.0)
	},
	{
		"id": "damage_up",
		"name": "Sharp Rounds",
		"description": "Bullet damage +20%",
		"stat_key": "damage",
		"value": 0.20,
		"type": "mul",
		"icon_color": Color(1.0, 0.3, 0.3)
	},
	{
		"id": "fire_rate_up",
		"name": "Rapid Fire",
		"description": "Fire rate +25%",
		"stat_key": "fire_rate",
		"value": 0.25,
		"type": "mul",
		"icon_color": Color(1.0, 0.8, 0.0)
	},
	{
		"id": "health_up",
		"name": "Iron Body",
		"description": "Max health +30",
		"stat_key": "max_health",
		"value": 30.0,
		"type": "add",
		"icon_color": Color(0.2, 1.0, 0.4)
	},
	{
		"id": "dash_cooldown_down",
		"name": "Nimble",
		"description": "Dash cooldown -20%",
		"stat_key": "dash_cooldown",
		"value": -0.20,
		"type": "mul",
		"icon_color": Color(0.6, 0.2, 1.0)
	},
	{
		"id": "multishot",
		"name": "Split Shot",
		"description": "Fire +1 additional bullet",
		"stat_key": "bullet_count",
		"value": 1.0,
		"type": "add",
		"icon_color": Color(1.0, 0.5, 0.0)
	},
	{
		"id": "explosive",
		"name": "Explosive Rounds",
		"description": "Bullets explode on impact (+AoE)",
		"stat_key": "explosive",
		"value": 1.0,
		"type": "add",
		"icon_color": Color(1.0, 0.2, 0.0)
	},
	{
		"id": "bullet_speed_up",
		"name": "Velocity Rounds",
		"description": "Bullet speed +30%",
		"stat_key": "bullet_speed",
		"value": 0.30,
		"type": "mul",
		"icon_color": Color(0.0, 0.9, 0.9)
	},
	{
		"id": "crit_chance_up",
		"name": "Eagle Eye",
		"description": "Critical hit chance +15%",
		"stat_key": "crit_chance",
		"value": 0.15,
		"type": "add",
		"icon_color": Color(1.0, 1.0, 0.0)
	},
	{
		"id": "ricochet",
		"name": "Ricochet",
		"description": "Bullets bounce once",
		"stat_key": "ricochet",
		"value": 1.0,
		"type": "add",
		"icon_color": Color(0.8, 0.8, 0.8)
	},
]

const CHOICES_PER_WAVE := 3  # how many upgrade cards to show

# ---------------------------------------------------------------------------
# Runtime
# ---------------------------------------------------------------------------
var _applied: Array[String] = []

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------
func present_upgrades() -> void:
	var options := _pick_random_upgrades(CHOICES_PER_WAVE)
	upgrades_ready.emit(options)

## Called by UI when player selects an upgrade card.
func apply_upgrade(upgrade_id: String, player: Node) -> void:
	var upg := _get_upgrade_by_id(upgrade_id)
	if upg.is_empty():
		return
	_apply_stat(upg, player)
	_applied.append(upgrade_id)
	upgrade_applied.emit(upg)
	GameManager.finish_upgrade_phase()

func get_applied_upgrade_ids() -> Array[String]:
	return _applied.duplicate()

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------
func _pick_random_upgrades(count: int) -> Array[Dictionary]:
	var pool := ALL_UPGRADES.duplicate()
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))

func _get_upgrade_by_id(id: String) -> Dictionary:
	for upg in ALL_UPGRADES:
		if upg["id"] == id:
			return upg
	return {}

func _apply_stat(upg: Dictionary, player: Node) -> void:
	if not player.has_method("apply_upgrade"):
		return
	player.apply_upgrade(upg)
