extends Node3D

@export var target_portal: Node3D
@export var teleport_delay: float = 3.5
@export var portal_area: Area3D
@export var spawn_marker: Marker3D
## Если задан путь к сцене (например "res://world.tscn"), портал работает как
## переход на новый уровень: сцена грузится асинхронно через SceneLoader без зависаний.
@export var target_scene_path: String = ""

var is_ready_to_teleport: bool = true
var is_player_inside: bool = false
var tracked_player: CharacterBody3D = null
var _teleport_generation: int = 0


func _ready() -> void:
	if portal_area == null:
		portal_area = find_child("*Area*", true, false) as Area3D
	if spawn_marker == null:
		spawn_marker = find_child("*Marker*", true, false) as Marker3D

	if portal_area:
		if not portal_area.body_entered.is_connected(_on_body_entered):
			portal_area.body_entered.connect(_on_body_entered)
		if not portal_area.body_exited.is_connected(_on_body_exited):
			portal_area.body_exited.connect(_on_body_exited)
	else:
		push_error("В портале не найдена зона Area3D: %s" % name)


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("start_portal_fading") and is_ready_to_teleport:
		is_player_inside = true
		tracked_player = body as CharacterBody3D
		body.start_portal_fading()
		_teleport_generation += 1
		var gen: int = _teleport_generation
		get_tree().create_timer(teleport_delay).timeout.connect(
			func() -> void: _on_timer_timeout(gen)
		)


func _on_body_exited(body: Node3D) -> void:
	if body == tracked_player:
		_teleport_generation += 1
		is_player_inside = false
		is_ready_to_teleport = true
		if body.has_method("cancel_portal_fading"):
			body.cancel_portal_fading()
		tracked_player = null


func _on_timer_timeout(gen: int) -> void:
	if gen != _teleport_generation:
		return
	if is_player_inside and is_ready_to_teleport and is_instance_valid(tracked_player):
		teleport_player(tracked_player)


func teleport_player(player: CharacterBody3D) -> void:
	if not is_instance_valid(player):
		return

	# Блокируем оба портала от повторного срабатывания во время телепорта.
	if target_portal:
		target_portal.is_ready_to_teleport = false

	player.set_physics_process(false)
	if player.has_method("complete_teleport"):
		player.complete_teleport()

	SaveManager.save_game()

	# Если портал ведёт на другой уровень — грузим его асинхронно, без фриза.
	if not target_scene_path.is_empty():
		SceneLoader.change_scene_async(target_scene_path)
		return

	# Обычный телепорт в пределах одной сцены.
	var has_spawn: bool = target_portal != null and target_portal.spawn_marker != null
	if has_spawn:
		player.global_position = target_portal.spawn_marker.global_position

	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if is_instance_valid(player):
			player.set_physics_process(true)
		if is_instance_valid(target_portal):
			target_portal.is_ready_to_teleport = true
	)
