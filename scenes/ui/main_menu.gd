extends Node3D

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Ждем один кадр, чтобы Autoload (MusicManager) успел создаться в памяти
	await get_tree().process_frame
	
	# Теперь музыка запустится со 100% гарантией при первом включении игры!
	if has_node("/root/MusicManager"):
		get_node("/root/MusicManager").play_menu()


func _on_play_button_pressed() -> void:
	# Бесшовно переключаем движок на сцену нашего игрового мира
	get_tree().change_scene_to_file("res://world.tscn")

func _on_settings_button_pressed() -> void:
	pass # Replace with function body.

func _on_exit_button_pressed() -> void:
	get_tree().quit()
