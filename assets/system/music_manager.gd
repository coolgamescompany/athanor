extends AudioStreamPlayer

# Ссылки на твои музыкальные файлы (поменяй пути на свои)
var menu_music = preload("res://assets/soundtrack/A_Walk_Through_the_City.mp3")
var game_music = preload("res://assets/soundtrack/Patience.ogg")

func play_menu() -> void:
	if stream != menu_music:
		stream = menu_music
		play()

func play_game() -> void:
	if stream != game_music:
		stream = game_music
		play()
