extends CanvasLayer

@onready var v_box_container: VBoxContainer = %VBoxContainer

var blur_tween: Tween
var camera_attrs: CameraAttributesPractical
var settings_instance: Node = null
var _cached_player: CharacterBody3D = null


func _ready() -> void:
	visible = false
	if v_box_container:
		v_box_container.modulate.a = 1.0
	layer = 2
	camera_attrs = CameraAttributesPractical.new()
	camera_attrs.dof_blur_far_enabled = true
	camera_attrs.dof_blur_far_distance = 0.01
	camera_attrs.dof_blur_far_transition = 0.01
	camera_attrs.dof_blur_amount = 0.0
	process_mode = Node.PROCESS_MODE_ALWAYS


func _get_player() -> CharacterBody3D:
	# Тот же игрок, что и в прошлый раз, и он всё ещё в дереве — отдаём без поиска.
	if is_instance_valid(_cached_player):
		return _cached_player
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	_cached_player = players[0] as CharacterBody3D if players.size() > 0 else null
	return _cached_player


func _get_player_camera() -> Camera3D:
	var player: CharacterBody3D = _get_player()
	if player == null:
		return null
	return player.get_node_or_null("Camera3D") as Camera3D


func _get_player_crosshair() -> Control:
	var player: CharacterBody3D = _get_player()
	if player == null:
		return null
	return player.get_node_or_null("HUD/CanvasLayer/Crosshair") as Control


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if settings_instance and is_instance_valid(settings_instance):
		settings_instance.queue_free()
		settings_instance = null
		return
	if not get_tree().paused:
		open_pause_menu()
	else:
		close_pause_menu()


func open_pause_menu() -> void:
	var player: CharacterBody3D = _get_player()
	if player and player.global_position.y < -20.0:
		return

	var crosshair: Control = _get_player_crosshair()
	if crosshair:
		crosshair.visible = false

	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	SaveManager.save_game()

	var camera: Camera3D = _get_player_camera()
	if camera:
		camera.attributes = camera_attrs

	if blur_tween:
		blur_tween.kill()
	blur_tween = create_tween().set_parallel(true)
	blur_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if v_box_container:
		v_box_container.modulate.a = 0.0
		blur_tween.tween_property(v_box_container, "modulate:a", 1.0, 0.15)
	blur_tween.tween_property(camera_attrs, "dof_blur_amount", 0.25, 0.25)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func close_pause_menu() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if blur_tween:
		blur_tween.kill()
	blur_tween = create_tween().set_parallel(true)
	blur_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if v_box_container:
		blur_tween.tween_property(v_box_container, "modulate:a", 0.0, 0.1)
	blur_tween.tween_property(camera_attrs, "dof_blur_amount", 0.0, 0.2)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if not blur_tween.finished.is_connected(_finish_close_pause):
		blur_tween.finished.connect(_finish_close_pause, CONNECT_ONE_SHOT)


func _finish_close_pause() -> void:
	get_tree().paused = false
	visible = false
	if v_box_container:
		v_box_container.modulate.a = 1.0
	var crosshair: Control = _get_player_crosshair()
	if crosshair:
		crosshair.visible = true
	var camera: Camera3D = _get_player_camera()
	if camera:
		camera.attributes = null


func _on_return_button_pressed() -> void:
	close_pause_menu()


func _on_settings_button_pressed() -> void:
	if settings_instance and is_instance_valid(settings_instance):
		return
	var settings_scene: PackedScene = preload("res://scenes/ui/settings_menu.tscn")
	settings_instance = settings_scene.instantiate()
	add_child(settings_instance)
	settings_instance.tree_exited.connect(func() -> void:
		settings_instance = null
	)


func _on_to_main_menu_button_pressed() -> void:
	SaveManager.save_game()
	get_tree().paused = false
	MusicManager.play_menu()
	SceneLoader.change_scene_async("res://scenes/ui/main_menu.tscn")
