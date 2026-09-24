extends Node3D

@export var target_portal: Node3D
@export var teleport_delay: float = 3.5

var spawn_marker: Marker3D = null
var portal_area: Area3D = null

var is_ready_to_teleport: bool = true
var is_player_inside: bool = false
var tracked_player: CharacterBody3D = null # Запоминаем игрока надёжно

# Переменная для хранения ссылки на таймер
var p_timer: SceneTreeTimer = null


func _ready() -> void:
	# Наш универсальный поиск узлов по дереву
	if not portal_area:
		portal_area = find_child("*Area*", true, false)
	if not spawn_marker:
		spawn_marker = find_child("*Marker*", true, false)

	if portal_area:
		portal_area.body_entered.connect(_on_body_entered)
		portal_area.body_exited.connect(_on_body_exited)
	else:
		push_error("КРИТИЧЕСКАЯ ОШИБКА: В портале не найдена зона Area3D!")


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("start_portal_fading") and is_ready_to_teleport:
		is_player_inside = true
		tracked_player = body
		
		# Запускаем плавное потемнение у игрока
		body.start_portal_fading()
		
		# Создаем таймер и запоминаем ссылку на него
		p_timer = get_tree().create_timer(teleport_delay)
		p_timer.timeout.connect(_on_timer_timeout)


func _on_body_exited(body: Node3D) -> void:
	if body == tracked_player:
		is_player_inside = false
		is_ready_to_teleport = true
		p_timer = null # Сбрасываем таймер, если он шёл, чтобы деактивировать телепортацию
		
		if body.has_method("cancel_portal_fading"):
			body.cancel_portal_fading()
		
		tracked_player = null


func _on_timer_timeout() -> void:
	# Проверяем, что игрок всё еще внутри и объект существует
	if is_player_inside and is_ready_to_teleport and is_instance_valid(tracked_player):
		teleport_player(tracked_player)


func teleport_player(player: CharacterBody3D) -> void:
	if not target_portal or not target_portal.spawn_marker:
		return
		
	print("--- ПОРТАЛ: Телепортация тела! ---")
	target_portal.is_ready_to_teleport = false
	
	player.set_physics_process(false)
	
	# Переносим игрока строго в позицию маркера целевого портала
	player.global_position = target_portal.spawn_marker.global_position
	
	# Вызываем у игрока чистый метод завершения (белая вспышка/пробуждение)
	if player.has_method("complete_teleport"):
		player.complete_teleport()
		
	# Через 2 секунды возвращаем управление физикой игроку и включаем целевой портал
	get_tree().create_timer(2.0).timeout.connect(func():
		if is_instance_valid(player):
			player.set_physics_process(true)
		if is_instance_valid(target_portal):
			target_portal.is_ready_to_teleport = true
	)
