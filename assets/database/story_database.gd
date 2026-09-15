extends Node

# Вся текстовая база данных нашей игры! 
# Каждая фраза имеет свой уникальный текстовый ID (ключ), тип и время показа.
const TEXTS = {
	# --- НАЧАЛО ИГРЫ (ИНТРО) ---
	"intro_thought_1": {
		"type": "thought",
		"text": "Где я?.. Моя голова... Как я здесь оказался?",
		"time": 5.0
	},
	"intro_thought_2": {
		"type": "thought",
		"text": "Кажется, на том острове есть что-то",
		"time": 5.0
	},
	"intro_thought_3": {
		"type": "thought",
		"text": "До него можно допрыгнуть",
		"time": 5.0
	},
	
	# ОБУЧЕНИЕ
	"intro_tutorial_1": {
		"type": "system",
		"text": "Нажмите на клавиши WASD для передвижения по острову",
		"time": 6.0
	},
	"intro_tutorial_2": {
		"type": "system",
		"text": "Нажмите на Space, чтобы прыгать",
		"time": 6.0
	},
	
	# --- ПЕРВЫЙ КРИСТАЛЛ (ЗАДЕЛ НА БУДУЩЕЕ) ---
	"find_crystal_thought": {
		"type": "thought",
		"text": "Ого, это же алхимический кристалл! Из него выйдет отличный эфир...",
		"time": 6.0
	},
	"find_crystal_tutorial": {
		"type": "system",
		"text": "Нажмите [E], чтобы собрать ингредиент",
		"time": 4.0
	},
	
	# --- БЕЗДНА / ПАДЕНИЕ ---
	"fall_abyss_thought": {
		"type": "thought",
		"text": "Эта бездна бесконечна... Магия острова вернула меня обратно.",
		"time": 4.0
	}
}

# Удобная функция, которая безопасно вытаскивает фразу по её ID
func get_phrase(phrase_id: String) -> Dictionary:
	if TEXTS.has(phrase_id):
		return TEXTS[phrase_id]
	print("КРИТИЧЕСКАЯ ОШИБКА: ID фразы '" + phrase_id + "' не найден в StoryDB!")
	return {}
	
