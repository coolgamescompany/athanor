extends Node

# Вся текстовая база данных нашей игры! 
# Каждая фраза имеет свой уникальный текстовый ID (ключ), тип и время показа.
const TEXTS = {
	# --- НАЧАЛО ИГРЫ (ИНТРО) ---
	"intro_thought_1": {
		"type": "thought",
		"time": 5.0
	},
	"intro_thought_2": {
		"type": "thought",
		"time": 5.0
	},
	"intro_thought_3": {
		"type": "thought",
		"time": 5.0
	},
	
	# ОБУЧЕНИЕ
	"intro_tutorial_1": {
		"type": "system",
		"time": 6.0
	},
	"intro_tutorial_2": {
		"type": "system",
		"time": 6.0
	},
	
	# ПЕРВЫЙ КРИСТАЛЛ (ЗАДЕЛ НА БУДУЩЕЕ) ---
	"find_crystal_thought": {
		"type": "thought",
		"time": 6.0
	},
	"find_crystal_tutorial": {
		"type": "system",
		"time": 4.0
	},
	
	# --- БЕЗДНА / ПАДЕНИЕ ---
	"fall_abyss_thought": {
		"type": "thought",
		"time": 4.0
	}
}


# Удобная функция, которая безопасно вытаскивает фразу по её ID
func get_phrase(phrase_id: String) -> Dictionary:
	if TEXTS.has(phrase_id):
		return TEXTS[phrase_id]
	print("КРИТИЧЕСКАЯ ОШИБКА: ID фразы '" + phrase_id + "' не найден в StoryDB!")
	return {}
	
