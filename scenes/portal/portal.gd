extends Node3D

@export var target_portal: Node3D

var is_ready_to_teleport: bool = true
var is_player_inside: bool = false
var portal_area: Area3D = null


func _ready() -> void:
	for child in get_children():
		if child is Area3D:
			portal_area = child
			break
			
	if portal_area:
		if not portal_area.body_entered.is_connected(_on_body_entered):
			portal_area.body_entered.connect(_on_body_entered)
		if not portal_area.body_exited.is_connected(_on_body_exited):
			portal_area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.is_in_group("player"):
		is_player_inside = true
		
		if not is_ready_to_teleport:
			return
			
		print("--- ПОРТАЛ: Вход игрока. Включение оверлея и запуск portal_entered ---")
		
		# ЖЕСТКИЙ ФИКС: Делаем ShaderRect видимым, иначе шейдер работает "вслепую"
		var shader_rect = body.find_child("ShaderRect", true, false)
		if shader_rect:
			shader_rect.visible = true
		
		# Запускаем анимацию накала эффекта через встроенный AnimationPlayer игрока
		if body.respawn_anim:
			if body.respawn_anim.has_animation("portal_entered"):
				body.respawn_anim.speed_scale = 1.0
				body.respawn_anim.play("portal_entered")
		
		await get_tree().create_timer(3.0).timeout
		
		if is_player_inside and is_ready_to_teleport:
			teleport_player(body)


func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D and body.is_in_group("player"):
		is_player_inside = false
		is_ready_to_teleport = true
		
		print("--- ПОРТАЛ: Отмена. Анимация плавно откатывается назад ---")
		
		if body.respawn_anim:
			if body.respawn_anim.has_animation("portal_entered"):
				body.respawn_anim.play_backwards("portal_entered")
				body.respawn_anim.speed_scale = 0.7
				
				# Автоматически тушим видимость ShaderRect ПОСЛЕ того, как анимация полностью отыграет назад
				if not body.respawn_anim.animation_finished.is_connected(_on_fade_back_finished.bind(body)):
					body.respawn_anim.animation_finished.connect(_on_fade_back_finished.bind(body))


# Калбэк для скрытия подложки после отмены телепортации
func _on_fade_back_finished(anim_name: StringName, player: CharacterBody3D) -> void:
	if anim_name == &"portal_entered" and not is_player_inside:
		var shader_rect = player.find_child("ShaderRect", true, false)
		if shader_rect:
			shader_rect.visible = false
		if player.respawn_anim.animation_finished.is_connected(_on_fade_back_finished.bind(player)):
			player.respawn_anim.animation_finished.disconnect(_on_fade_back_finished.bind(player))


func teleport_player(player: CharacterBody3D) -> void:
	if not target_portal:
		return
		
	var target_area: Area3D = null
	for child in target_portal.get_children():
		if child is Area3D:
			target_area = child
			break
			
	if not target_area:
		return
		
	print("--- ПОРТАЛ: Телепортация тела! ---")
	target_portal.is_ready_to_teleport = false
	player.set_physics_process(false)
	
	# === НОВЫЙ РАСЧЕТ ТОЧКИ ТЕЛЕПОРТАЦИИ ===
	# Берем глобальную позицию центра целевой зоны
	var target_position: Vector3 = target_area.global_position
	
	# Ищем CollisionShape3D внутри целевой зоны, чтобы узнать ее точные размеры
	for child in target_area.get_children():
		if child is CollisionShape3D and child.shape:
			# Вычисляем локальный габаритный контейнер (AABB) формы коллизии
			var shape_aabb: AABB = child.shape.get_debug_mesh().get_aabb()
			
			# Находим самую верхнюю точку зоны:
			# К центру зоны по Y прибавляем половину высоты коллизии (размер по Y умноженный на глобальный масштаб)
			var half_height = (shape_aabb.size.y * child.global_transform.basis.get_scale().y) / 2.0
			target_position.y += half_height
			break
	
	# Небольшой запас безопасности (зазор), чтобы ноги игрока гарантированно встали чуть НАД верхней гранью
	target_position.y += 0.1 
	
	# Переносим игрока на вычисленную верхнюю точку
	player.global_position = target_position
	# =======================================
	
	# Убеждаемся, что ShaderRect горит перед анимацией вспышки появления
	var shader_rect = player.find_child("ShaderRect", true, false)
	if shader_rect:
		shader_rect.visible = true
	
	# Включаем готовую анимацию пробуждения
	if player.respawn_anim:
		player.respawn_anim.speed_scale = 1.0
		if player.respawn_anim.has_animation("wakeup"):
			player.respawn_anim.play("wakeup")
			player.respawn_anim.seek(0.0, true)
	
	if player.respawn_sound:
		player.respawn_sound.play()
		
	if player.spawn_particles:
		player.spawn_particles.restart()
		
	await get_tree().create_timer(2.0).timeout
	player.set_physics_process(true)
