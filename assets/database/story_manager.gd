extends Node

# Список ID фраз, которые игрок уже прочитал за текущую сессию

# Список ID фраз, которые игрок уже прочитал за текущую сессию
var played_phrases: Array[String] = []

# Стадии сюжета: 0 - интро, 1 - проснулся (монолог головы), 2 - обучение ходьбе, 3 - пошёл (монолог острова), 4 - финал
var current_story_stage: int = 0

# Флаг, горит ли прямо сейчас КАКОЙ-ЛИБО текст на экране
var is_phrase_playing: bool = false

# Флаг, зафиксировали ли мы первое движение игрока
var has_player_moved_at_least_once: bool = false

# === СОБЫТИЙНЫЙ ТРИГГЕР 1: КОНЕЦ ИНТРО (Досмотрели или пропустили) ===
func on_intro_finished() -> void:
	if current_story_stage > 0: return
	current_story_stage = 1 # СТАДИЯ 1: Монолог о голове
	
	# Неспешное появление первой мысли после открытия глаз
	await _wait_for_safe_player(1.5)
	await play_phrase_cinematic("intro_thought_1") # Длится 5.0 сек + 0.8 сек анимация
	
	# Пауза тишины после угасания первой мысли
	await _wait_for_safe_player(1.5)
	
	# СТАДИЯ 2: В любом случае выводим туториал WASD, чтобы зафиксировать механику ходьбы
	current_story_stage = 2
	await play_phrase_cinematic("intro_tutorial_1") # Длится 6.0 сек + 0.8 сек анимация
	
	# Проверяем: если игрок к этому моменту уже вовсю бегает (нажал WASD ранее)
	if has_player_moved_at_least_once:
		# Сразу запускаем следующую стадию без ожидания!
		_run_island_monologue_chain()


		
# === СОБЫТИЙНЫЙ ТРИГГЕР 2: ИГРОК ВПЕРВЫЕ НАЖАЛ WASD ===
# === СОБЫТИЙНЫЙ ТРИГГЕР 2: ИГРОК НАЖАЛ WASD ===
func on_player_moved() -> void:
	# Запоминаем, что игрок в принципе умеет ходить
	has_player_moved_at_least_once = true
	
	# Если мы находимся на стадии 2 (горит или только что догорел туториал WASD) 
	# и игрок пошел — переключаем сюжет на монолог острова
	if current_story_stage == 2:
		_run_island_monologue_chain()


# === УМНАЯ ФУНКЦИЯ КИНЕМАТОГРАФИЧНОГО ВЫВОДА (С КОНТРОЛЕМ ОЧЕРЕДИ) ===
# Мы добавили await перед вызовом, чтобы менеджер точно знал, сколько секунд горит текст
func play_phrase_cinematic(phrase_id: String) -> void:
	if phrase_id in played_phrases: return
	played_phrases.append(phrase_id)
	
	var player = get_tree().current_scene.find_child("Player", true, false) as CharacterBody3D
	var floating_text = get_tree().current_scene.find_child("FloatingText", true, false)
	
	if not player or not floating_text: return
	var phrase_data = StoryDB.get_phrase(phrase_id)
	if phrase_data.is_empty(): return
	
	var generated_key = "KEY_" + phrase_id.to_upper()
	
	# Захватываем экран!
	is_phrase_playing = true
	
	if phrase_data["type"] == "thought":
		floating_text.show_thought(player, generated_key, phrase_data["time"])
	elif phrase_data["type"] == "system":
		floating_text.show_system_message(player, generated_key, phrase_data["time"])
		
	# Ждём время горения текста (из базы данных) + 0.8 секунды на анимацию Твина (появление + растворение)
	await _wait_for_safe_player(phrase_data["time"] + 0.8)
	
	# Освобождаем экран для следующей реплики
	is_phrase_playing = false


# === ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ ЗАМОРОЗКИ ТАЙМЕРОВ (БЕЗ ИЗМЕНЕНИЙ) ===
func _wait_for_safe_player(seconds: float) -> void:
	var elapsed = 0.0
	while elapsed < seconds:
		var current_scene = get_tree().current_scene
		if current_scene:
			var player = current_scene.find_child("Player", true, false)
			if not get_tree().paused and player and player.is_on_floor() and player.global_position.y > -20.0:
				elapsed += get_process_delta_time()
		await get_tree().process_frame

# --- ВНУТРЕННЯЯ ПОСЛЕДОВАТЕЛЬНАЯ ЦЕПОЧКА МОНОЛОГА ОСТРОВА ---
func _run_island_monologue_chain() -> void:
	current_story_stage = 3 # СТАДИЯ 3: Монолог об острове
	
	# Если на экране всё еще догорает туториал ходьбы — вежливо ждем полной чистоты
	while is_phrase_playing:
		await get_tree().process_frame
		
	# Идеальная неспешная ААА-пауза: даем игроку побегать 3.5 секунды в полной тишине, наслаждаясь покачиванием камеры
	await _wait_for_safe_player(3.5)
	await play_phrase_cinematic("intro_thought_2") # "Кажется, на том острове что-то есть..."
	
	# 2.5 секунды тишины между мыслями
	await _wait_for_safe_player(2.5)
	await play_phrase_cinematic("intro_thought_3") # "До него можно допрыгнуть."
	
	# Спустя 1.5 секунды после мысли "можно допрыгнуть" — сочно подталкиваем туториалом прыжка
	await _wait_for_safe_player(1.5)
	await play_phrase_cinematic("intro_tutorial_2") # Подсказка прыжка на Space
	
	current_story_stage = 4 # Интро-цепочка полностью завершена
