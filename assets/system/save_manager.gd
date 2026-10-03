extends Node

const SAVE_PATH: String = "user://save_game.cfg"

var save_data: Dictionary = {
	"player": {
		"spawn_x": 0.0,
		"spawn_y": 0.0,
		"spawn_z": 0.0,
		"has_saved_position": false
	},
	"story": {
		"current_stage": 0,
		"played_phrases_list": []
	}
}


func save_game() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return

	var players: Array[Node] = tree.get_nodes_in_group("player")
	if players.size() > 0:
		var player: CharacterBody3D = players[0] as CharacterBody3D
		# Во время интро не пишем позицию — иначе Continue пропустит пробуждение
		if player and not bool(player.get("is_intro_playing")):
			save_data["player"]["spawn_x"] = player.global_position.x
			save_data["player"]["spawn_y"] = player.global_position.y
			save_data["player"]["spawn_z"] = player.global_position.z
			save_data["player"]["has_saved_position"] = true
		elif player and bool(player.get("is_intro_playing")):
			return

	save_data["story"]["current_stage"] = StoryManager.current_story_stage
	save_data["story"]["played_phrases_list"] = StoryManager.played_phrases.duplicate()

	var config := ConfigFile.new()
	config.set_value("player", "position_x", save_data["player"]["spawn_x"])
	config.set_value("player", "position_y", save_data["player"]["spawn_y"])
	config.set_value("player", "position_z", save_data["player"]["spawn_z"])
	config.set_value("player", "has_saved", save_data["player"]["has_saved_position"])
	config.set_value("story", "stage", save_data["story"]["current_stage"])
	config.set_value("story", "played_phrases", save_data["story"]["played_phrases_list"])

	var error: Error = config.save(SAVE_PATH)
	if error != OK:
		push_error("Не удалось записать файл сохранения: %s" % error)


func load_game() -> bool:
	var config := ConfigFile.new()
	var error: Error = config.load(SAVE_PATH)
	if error != OK:
		StoryManager.reset_story()
		return false

	save_data["player"]["spawn_x"] = config.get_value("player", "position_x", 0.0)
	save_data["player"]["spawn_y"] = config.get_value("player", "position_y", 0.0)
	save_data["player"]["spawn_z"] = config.get_value("player", "position_z", 0.0)
	save_data["player"]["has_saved_position"] = config.get_value("player", "has_saved", false)
	save_data["story"]["current_stage"] = config.get_value("story", "stage", 0)

	var loaded_phrases: Variant = config.get_value("story", "played_phrases", [])
	var safe_phrases: Array[String] = []
	if loaded_phrases is Array:
		for phrase in loaded_phrases:
			safe_phrases.append(str(phrase))
	save_data["story"]["played_phrases_list"] = safe_phrases

	StoryManager.current_story_stage = int(save_data["story"]["current_stage"])
	StoryManager.played_phrases = safe_phrases
	StoryManager.has_player_moved_at_least_once = StoryManager.current_story_stage >= 2
	StoryManager.is_phrase_playing = false
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func clear_save() -> void:
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("save_game.cfg"):
		dir.remove("save_game.cfg")

	save_data["player"]["spawn_x"] = 0.0
	save_data["player"]["spawn_y"] = 0.0
	save_data["player"]["spawn_z"] = 0.0
	save_data["player"]["has_saved_position"] = false
	save_data["story"]["current_stage"] = 0
	save_data["story"]["played_phrases_list"] = []
	StoryManager.reset_story()
