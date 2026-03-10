## SaveManager.gd
## Handles saving and loading player progress via JSON.
extends Node

const SAVE_PATH := "user://save_data.json"

# ---------------------------------------------------------------------------
# Save
# ---------------------------------------------------------------------------
func save_game(high_score: int, waves_survived: int) -> void:
	var data := {
		"high_score": high_score,
		"waves_survived": waves_survived,
		"unlocked_upgrades": UpgradeManager.get_applied_upgrade_ids(),
		"timestamp": Time.get_datetime_string_from_system()
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("[SaveManager] Game saved.")
	else:
		push_error("[SaveManager] Failed to open save file for writing.")

# ---------------------------------------------------------------------------
# Load
# ---------------------------------------------------------------------------
func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}

func get_high_score() -> int:
	var data := load_game()
	return int(data.get("high_score", 0))

func get_waves_survived() -> int:
	var data := load_game()
	return int(data.get("waves_survived", 0))

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
