extends CanvasLayer

@onready var blur_rect: ColorRect = %ColorRect
@onready var v_box_container: VBoxContainer = %VBoxContainer

var blur_tween: Tween

func _ready() -> void:
	# Скрываем меню на старте игры
	visible = false
	(blur_rect.material as ShaderMaterial).set_shader_parameter("blur_amount", 0.0)
	v_box_container.modulate.a = 1.0
	
	# САМОЕ ВАЖНОЕ: Это меню обязано работать, когда игра заморожена!
	process_mode = PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	# Ловим нажатие Escape в любом состоянии игры
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled() # Говорим движку, что кнопка обработана
		
		if not get_tree().paused:
			open_pause_menu()
		else:
			close_pause_menu()


func open_pause_menu() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if blur_tween: blur_tween.kill()
	blur_tween = create_tween().set_parallel(true)
	blur_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# Плавно включаем размытие и появление кнопок
	blur_tween.tween_property(blur_rect.material, "shader_parameter/blur_amount", 2.5, 0.25)
	v_box_container.modulate.a = 0.0
	blur_tween.tween_property(v_box_container, "modulate:a", 1.0, 0.15)


func close_pause_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if blur_tween: blur_tween.kill()
	blur_tween = create_tween() # НЕ parallel, чтобы сначала убрать текст
	blur_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# 1. Мгновенно тушим текст, чтобы он не исчезал позже шейдера
	blur_tween.tween_property(v_box_container, "modulate:a", 0.0, 0.05)
	
	# 2. Плавно убираем размытие заднего фона
	blur_tween.tween_property(blur_rect.material, "shader_parameter/blur_amount", 0.0, 0.25)
	
	# 3. Когда всё скрылось — снимаем паузу
	blur_tween.finished.connect(func():
		get_tree().paused = false
		visible = false
		v_box_container.modulate.a = 1.0
	)


# --- ОБРАБОТКА СИГНАЛОВ КНОПОК ---
# Переподключите сигналы pressed() от кнопок к этим функциям внутри сцены PauseMenu

func _on_return_button_pressed() -> void:
	close_pause_menu()


func _on_settings_button_pressed() -> void:
	pass # Настройки

func _on_to_main_menu_button_pressed() -> void:
	get_tree().paused = false
	
	# Принудительно включаем музыку меню перед выходом!
	if has_node("/root/MusicManager"):
		get_node("/root/MusicManager").play_menu()
		
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
