extends Node

var played_phrases: Array[String] = []
var current_story_stage: int = 0
var is_phrase_playing: bool = false
var has_player_moved_at_least_once: bool = false

var _island_chain_started: bool = false
var _cached_player: CharacterBody3D = null
var _cached_floating_text: Node = null


func reset_story() -> void:
	played_phrases.clear()
	current_story_stage = 0
	is_phrase_playing = false
	has_player_moved_at_least_once = false
	_island_chain_started = false
	_cached_player = null
	_cached_floating_text = null


func on_intro_finished() -> void:
	if current_story_stage > 0:
		return
	current_story_stage = 1

	await _wait_for_safe_player(1.5)
	await play_phrase_cinematic("intro_thought_1")
	await _wait_for_safe_player(1.5)

	current_story_stage = 2
	await play_phrase_cinematic("intro_tutorial_1")

	if has_player_moved_at_least_once:
		_run_island_monologue_chain()


func on_player_moved() -> void:
	has_player_moved_at_least_once = true
	if current_story_stage == 2:
		_run_island_monologue_chain()


func play_phrase_cinematic(phrase_id: String) -> void:
	if phrase_id in played_phrases:
		return

	var player: CharacterBody3D = _get_player()
	var floating_text: Node = _get_floating_text()
	if player == null or floating_text == null:
		return

	var phrase_data: Dictionary = StoryDB.get_phrase(phrase_id)
	if phrase_data.is_empty():
		return

	# Помечаем фразу только после успешного старта показа
	played_phrases.append(phrase_id)
	is_phrase_playing = true
	var generated_key: String = "KEY_" + phrase_id.to_upper()

	if phrase_data["type"] == "thought":
		floating_text.show_thought(player, generated_key, phrase_data["time"])
	elif phrase_data["type"] == "system":
		floating_text.show_system_message(player, generated_key, phrase_data["time"])

	await _wait_for_safe_player(float(phrase_data["time"]) + 0.8)
	is_phrase_playing = false


func _wait_for_safe_player(seconds: float) -> void:
	var elapsed: float = 0.0
	while elapsed < seconds:
		if get_tree() == null:
			return
		var player: CharacterBody3D = _get_player()
		if not get_tree().paused and player and player.is_inside_tree() and player.is_on_floor() and player.global_position.y > -20.0:
			elapsed += get_process_delta_time()
		await get_tree().process_frame


func _run_island_monologue_chain() -> void:
	if _island_chain_started:
		return
	_island_chain_started = true
	current_story_stage = 3

	while is_phrase_playing:
		await get_tree().process_frame

	await _wait_for_safe_player(3.5)
	await play_phrase_cinematic("intro_thought_2")
	await _wait_for_safe_player(2.5)
	await play_phrase_cinematic("intro_thought_3")
	await _wait_for_safe_player(1.5)
	await play_phrase_cinematic("intro_tutorial_2")

	current_story_stage = 4


func _get_player() -> CharacterBody3D:
	if is_instance_valid(_cached_player):
		return _cached_player
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var players: Array[Node] = tree.get_nodes_in_group("player")
	if players.size() > 0:
		_cached_player = players[0] as CharacterBody3D
		return _cached_player
	return null


func _get_floating_text() -> Node:
	if is_instance_valid(_cached_floating_text):
		return _cached_floating_text
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return null
	_cached_floating_text = tree.current_scene.find_child("FloatingText", true, false)
	return _cached_floating_text
