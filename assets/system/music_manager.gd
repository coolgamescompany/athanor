extends AudioStreamPlayer

var menu_music: AudioStream = preload("res://assets/soundtrack/A_Walk_Through_the_City.mp3")
var game_music: AudioStream = preload("res://assets/soundtrack/Patience.ogg")


func _ready() -> void:
	bus = "Music"


func play_menu() -> void:
	if stream != menu_music:
		stream = menu_music
		play()


func play_game() -> void:
	if stream != game_music:
		stream = game_music
		play()
