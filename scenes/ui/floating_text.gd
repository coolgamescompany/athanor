extends Node3D

@onready var thoughts_text: Label3D = $ThoughtsText
@onready var system_text: Label3D = $SystemText

# Наши новые звуковые плееры
@onready var thought_sound: AudioStreamPlayer3D = $ThoughtSound
@onready var system_sound: AudioStreamPlayer3D = $SystemSound

func _ready() -> void:
	if thoughts_text: thoughts_text.visible = false
	if system_text: system_text.visible = false

# === 1. ФУНКЦИЯ ДЛЯ ВЫВОДА МЫСЛЕЙ (Фиолетовый текст) ===
func show_thought(player_node: CharacterBody3D, message: String, duration: float = 5.0) -> void:
	if not thoughts_text: return
	if not player_node.is_on_floor() or player_node.velocity.y < -1.0:
		return
		
	thoughts_text.text = message
	
	# Берем направление взгляда и находим точку строго на уровне камеры игрока!
	var forward_dir = -player_node.global_transform.basis.z.normalized()
	# camera.global_position автоматически дает идеальную высоту глаз алхимика
	var cam_pos = player_node.get_node("Camera3D").global_position
	var target_spawn_pos = cam_pos + (forward_dir * 2.0)
	
	# Телепортируем весь корень в целевую точку
	self.global_position = target_spawn_pos
	
	# --- НАСТРОЙКА КИНЕМАТОГРАФИЧНОЙ АНИМАЦИИ (Всплытие + Рост) ---
	# Стартуем из прозрачности, уменьшенного размера и чуть опущенными вниз
	thoughts_text.position = Vector3(0, -0.3, 0)
	thoughts_text.scale = Vector3(0.3, 0.3, 0.3)
	
	var base_color = thoughts_text.modulate
	thoughts_text.modulate = Color(base_color.r, base_color.g, base_color.b, 0.0)
	thoughts_text.visible = true
	
	# Воспроизводим звук мысли!
	if thought_sound: thought_sound.play()
	
	# Запускаем параллельный сочный Твин
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(thoughts_text, "modulate", Color(base_color.r, base_color.g, base_color.b, 1.0), 0.4)
	tween.tween_property(thoughts_text, "position", Vector3.ZERO, 0.4) # Всплывает на дефолтное место
	tween.tween_property(thoughts_text, "scale", Vector3.ONE, 0.4) # Вырастает до 100% размера
	
	# Ждем увеличенное время показа
	await get_tree().create_timer(duration).timeout
	
	# Плавно растворяем в воздухе
	var fade_tween = create_tween()
	fade_tween.tween_property(thoughts_text, "modulate", Color(base_color.r, base_color.g, base_color.b, 0.0), 0.4)
	await fade_tween.finished
	thoughts_text.visible = false

# === 2. ФУНКЦИЯ ДЛЯ ОБУЧЕНИЯ (Белый текст) ===
func show_system_message(player_node: CharacterBody3D, message: String, duration: float = 6.0) -> void:
	if not system_text: return
	if not player_node.is_on_floor():
		return
	
	# Проверка галочки обучения из менеджера настроек
	if has_node("/root/SettingsManager"):
		var is_tutorial_enabled = get_node("/root/SettingsManager").show_tutorial
		if not is_tutorial_enabled:
			return 

	system_text.text = message
	
	var forward_dir = -player_node.global_transform.basis.z.normalized()
	var cam_pos = player_node.get_node("Camera3D").global_position
	# Обучение спавним чуть выше (на +0.3 метра над мыслями), чтобы они не перекрывали друг друга
	var target_spawn_pos = cam_pos + (forward_dir * 2.2) + Vector3(0, 0.3, 0)
	
	self.global_position = target_spawn_pos
	
	# Стартовые параметры для анимации системы
	system_text.position = Vector3(0, -0.3, 0)
	system_text.scale = Vector3(0.3, 0.3, 0.3)
	
	var base_color = system_text.modulate
	system_text.modulate = Color(base_color.r, base_color.g, base_color.b, 0.0)
	system_text.visible = true
	
	# Воспроизводим звук системы!
	if system_sound: system_sound.play()
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(system_text, "modulate", Color(base_color.r, base_color.g, base_color.b, 1.0), 0.4)
	tween.tween_property(system_text, "position", Vector3.ZERO, 0.4)
	tween.tween_property(system_text, "scale", Vector3.ONE, 0.4)
	
	await get_tree().create_timer(duration).timeout
	
	var fade_tween = create_tween()
	fade_tween.tween_property(system_text, "modulate", Color(base_color.r, base_color.g, base_color.b, 0.0), 0.4)
	await fade_tween.finished
	system_text.visible = false
