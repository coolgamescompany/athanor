extends Node3D

func _ready() -> void:
	# Снимаем паузу с движка (на всякий случай, если вышли из меню паузы)
	get_tree().paused = false
	# Делаем курсор мыши видимым и свободным для нажатия кнопок
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_play_button_pressed() -> void:
	# Бесшовно переключаем движок на сцену нашего игрового мира
	get_tree().change_scene_to_file("res://world.tscn")

func _on_settings_button_pressed() -> void:
	pass # Replace with function body.

func _on_exit_button_pressed() -> void:
	get_tree().quit()
