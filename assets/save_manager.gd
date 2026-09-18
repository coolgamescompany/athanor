extends Node

# Путь, по которому файл сохранения будет бережно лежать в пользовательской папке OS
const SAVE_PATH = "user://save_game.cfg"

# --- ГЛОБАЛЬНЫЙ СЛОВАРЬ СТРУКТУРЫ ДАННЫХ СОХРАНЕНИЯ ---
# Все дефолтные значения на случай самого первого, чистого запуска игры
var save_data: Dictionary = {
	"player": {
		"spawn_x": 0.0,
		"spawn_y": 0.0,
		"spawn_z": 0.0,
		"has_saved_position": false # Флаг, перезаписывали ли мы спавн хоть раз
	},
	"story": {
		"current_stage": 0,
		"played_phrases_list": []
	}
}


# === 1. ФУНКЦИЯ КИНЕМАТОГРАФИЧНОЙ ЗАПИСИ НА ДИСК ===
func save_game() -> void:
	# Ищем игрока по системной группе (добавь ноду игрока в группу "player" в редакторе, если ещё не добавил)
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0] as CharacterBody3D
		if player:
			# Берем именно ТЕКУЩУЮ позицию игрока в мире, а не начальную!
			save_data["player"]["spawn_x"] = player.global_position.x
			save_data["player"]["spawn_y"] = player.global_position.y
			save_data["player"]["spawn_z"] = player.global_position.z
			save_data["player"]["has_saved_position"] = true
			


	if has_node("/root/StoryManager"):
		save_data["story"]["current_stage"] = get_node("/root/StoryManager").current_story_stage
		save_data["story"]["played_phrases_list"] = get_node("/root/StoryManager").played_phrases

	# Упаковываем наш словарь в системный файл Godot ConfigFile
	var config = ConfigFile.new()
	
	# Записываем блок игрока
	config.set_value("player", "position_x", save_data["player"]["spawn_x"])
	config.set_value("player", "position_y", save_data["player"]["spawn_y"])
	config.set_value("player", "position_z", save_data["player"]["spawn_z"])
	config.set_value("player", "has_saved", save_data["player"]["has_saved_position"])
	
	# Записываем блок сюжета
	config.set_value("story", "stage", save_data["story"]["current_stage"])
	config.set_value("story", "played_phrases", save_data["story"]["played_phrases_list"])
	
	# Сохраняем физический файл в систему
	var error = config.save(SAVE_PATH)
	if error == OK:
		print("--- СИСТЕМА СОХРАНЕНИЙ: Данные Атанора успешно записаны на диск! ---")
	else:
		print("--- СИСТЕМА СОХРАНЕНИЙ: КРИТИЧЕСКАЯ ОШИБКА ЗАПИСИ ФАЙЛА! ---")


# === 2. ФУНКЦИЯ ПОСЛЕДОВАТЕЛЬНОЙ ЗАГРУЗКИ ДАННЫХ ===
func load_game() -> bool:
	var config = ConfigFile.new()
	var error = config.load(SAVE_PATH)
	
	# Если файла на диске нет (первый запуск) — возвращаем false
	if error != OK:
		print("--- СИСТЕМА СОХРАНЕНИЙ: Файл сохранения не найден. Начинаем чистую игру. ---")
		return false
		
	# Распаковываем данные обратно в наш рабочий словарь памяти
	save_data["player"]["spawn_x"] = config.get_value("player", "position_x", 0.0)
	save_data["player"]["spawn_y"] = config.get_value("player", "position_y", 0.0)
	save_data["player"]["spawn_z"] = config.get_value("player", "position_z", 0.0)
	save_data["player"]["has_saved_position"] = config.get_value("player", "has_saved", false)
	
	save_data["story"]["current_stage"] = config.get_value("story", "stage", 0)
	
	# Безопасное чтение массива строк (Played Phrases)
	var loaded_phrases = config.get_value("story", "played_phrases", [])
	var safe_phrases: Array[String] = []
	for phrase in loaded_phrases:
		safe_phrases.append(str(phrase))
	save_data["story"]["played_phrases_list"] = safe_phrases
	
	# Насильно синхронизируем скачанные данные со StoryManager
	if has_node("/root/StoryManager"):
		get_node("/root/StoryManager").current_story_stage = save_data["story"]["current_stage"]
		get_node("/root/StoryManager").played_phrases = save_data["story"]["played_phrases_list"]
		
	print("--- СИСТЕМА СОХРАНЕНИЙ: Данные успешно считаны! Текущая стадия сюжета: ", save_data["story"]["current_stage"])
	return true


# === 3. МЕХАНИКА СБРОСА ПРОГРЕССА (ДЛЯ КНОПКИ В НАСТРОЙКАХ) ===
func clear_save() -> void:
	var dir = DirAccess.open("user://")
	if dir and dir.file_exists("save_game.cfg"):
		dir.remove("save_game.cfg")
		print("--- СИСТЕМА СОХРАНЕНИЙ: Файл save_game.cfg полностью удален из системы! ---")
	else:
		print("--- СИСТЕМА СОХРАНЕНИЙ: Попытка удаления, но файла на диске не было. ---")
		
	# Полностью обнуляем оперативную память менеджера до дефолтных настроек
	save_data["player"]["has_saved_position"] = false
	
	# Безопасная проверка: сбрасываем сюжет, только если StoryManager реально запущен в памяти
	if has_node("/root/StoryManager"):
		var sm = get_node("/root/StoryManager")
		if sm:
			sm.current_story_stage = 0
			sm.played_phrases.clear() # ИСПРАВЛЕНО: Очищаем массив без краша типов данных!
			sm.has_player_moved_at_least_once = false
