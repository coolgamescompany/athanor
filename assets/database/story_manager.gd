extends Node

var played_phrases: Array[String] = []

# Вспомогательная функция, которая останавливает таймер, если игрок падает или респавнится
func _wait_for_safe_player(seconds: float) -> void:
	var elapsed = 0.0
	while elapsed < seconds:
		# Проверяем, существует ли вообще текущая сцена
		var current_scene = get_tree().current_scene
		if current_scene:
			# Ищем игрока на сцене мира безопасным методом
			var player = current_scene.find_child("Player", true, false)
			
			# Если игрок нашелся, уверенно стоит на земле И не находится в процессе респауна
			if player and player.is_on_floor() and player.global_position.y > -20.0:
				elapsed += get_process_delta_time() # Только в этом безопасном случае таймер тикает вперед!
		
		await get_tree().process_frame # Пропускаем кадр видеокарты


# УЛЬТИМАТИВНАЯ НЕУБИВАЕМАЯ ЦЕПОЧКА ИНТРО С АВТО-ТАЙМИНГОМ
func start_intro_sequence() -> void:
	# --- 1. ПЕРВАЯ МЫСЛЬ ---
	# Ждем 3 секунды безопасного нахождения на земле после пробуждения
	await _wait_for_safe_player(3.0)
	play_phrase("intro_thought_1") # Горит 5.0 сек
	
	# --- 2. ОБУЧЕНИЕ ХОДЬБЕ (WASD) ---
	# Ждем, пока мысль погорит (5.0 сек) + даем 1.5 секунды тишины, чтобы игрок выдохнул
	await _wait_for_safe_player(5.0 + 1.5)
	play_phrase("intro_tutorial_1") # Горит 6.0 сек
	
	# --- 3. ВТОРАЯ МЫСЛЬ (ЗАМЕТИЛ ЧТО-ТО) ---
	# Ждем, пока обучение погорит (6.0 сек) + даем 2.0 секунды побегать на WASD
	await _wait_for_safe_player(6.0 + 2.0)
	play_phrase("intro_thought_2") # Горит 5.0 сек
	
	# --- 4. ТРЕТЬЯ МЫСЛЬ (МОЖНО ДОПРЫГНУТЬ) ---
	# Даем алхимику договорить мысль (5.0 сек) + 1.5 секунды тишины перед финальным выводом
	await _wait_for_safe_player(5.0 + 1.5)
	play_phrase("intro_thought_3") # Горит 5.0 net
	
	# --- 5. ОБУЧЕНИЕ ПРЫЖКУ (SPACE) ---
	# Как только герой подумал, что допрыгнуть МОЖНО (через 5.0 сек) -> выдаем подсказку прыжка!
	await _wait_for_safe_player(5.0 + 0.5)
	play_phrase("intro_tutorial_2") # Горит 6.0 сек



func play_phrase(phrase_id: String) -> void:
	if phrase_id in played_phrases:
		return
		
	played_phrases.append(phrase_id)
	
	var player = get_tree().current_scene.find_child("Player", true, false) as CharacterBody3D
	var floating_text = get_tree().current_scene.find_child("FloatingText", true, false)
	
	if not player or not floating_text: 
		return
		
	var phrase_data = StoryDB.get_phrase(phrase_id)
	if phrase_data.is_empty(): 
		return
		
	# === АВТОМАТИЧЕСКАЯ ГЕНЕРАЦИЯ КЛЮЧА ЛОКАЛИЗАЦИИ ===
	# Берём phrase_id (например, "intro_thought_1"), делаем капслоком и добавляем "KEY_"
	# На выходе железобетонно получится: "KEY_INTRO_THOUGHT_1"
	var generated_key = "KEY_" + phrase_id.to_upper()
	
	# Передаем этот сгенерированный ключ в функции отрисовки текста!
	if phrase_data["type"] == "thought":
		floating_text.show_thought(player, generated_key, phrase_data["time"])
	elif phrase_data["type"] == "system":
		floating_text.show_system_message(player, generated_key, phrase_data["time"])
