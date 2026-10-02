extends CanvasLayer

@onready var v_box_container: VBoxContainer = %VBoxContainer

var blur_tween: Tween
var camera_attrs: CameraAttributesPractical

func _ready() -> void:
	visible = false
	if v_box_container:
		v_box_container.modulate.a = 1.0
	
	# Инициализация профиля тотального размытия 3D-мира при старте
	camera_attrs = CameraAttributesPractical.new()
	camera_attrs.dof_blur_far_enabled = true
	camera_attrs.dof_blur_far_distance = 0.01   # Начинаем размывать прямо от глаз игрока
	camera_attrs.dof_blur_far_transition = 0.01 # Равномерный блюр по всему экрану (включая траву)
	camera_attrs.dof_blur_amount = 0.0          # На старте игры картинка идеально четкая
	
	# Меню и его функции обязаны работать, когда игра заморожена на паузу
	process_mode = PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled() # Помечаем ввод как обработанный
		
		if not get_tree().paused:
			open_pause_menu()
		else:
			close_pause_menu()


func open_pause_menu() -> void:
	# Страховка респауна: если игрок летит в бездну, запрещаем открывать меню
	var player = get_tree().current_scene.find_child("Player", true, false)
	if player and player.global_position.y < -20.0:
		return
		
	visible = true
	get_tree().paused = true # Безопасно замораживаем глобальную физику движка
	
	# Включаем видимость мыши для интерфейса
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Подключаем наши ААА-атрибуты размытия к 3D-камере игрока
	if player and player.has_node("Camera3D"):
		var camera = player.get_node("Camera3D") as Camera3D
		camera.attributes = camera_attrs
	
	# Анимация плавного появления
	if blur_tween: blur_tween.kill()
	blur_tween = create_tween().set_parallel(true)
	blur_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	if v_box_container:
		v_box_container.modulate.a = 0.0
		blur_tween.tween_property(v_box_container, "modulate:a", 1.0, 0.15)
	
	# Плавно выводим сочное размытие на твое идеальное значение 0.25
	blur_tween.tween_property(camera_attrs, "dof_blur_amount", 0.25, 0.25)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
	# === ФИКС ФОКУСА КНОПОК ===
	# Автоматически передаем фокус ввода первой кнопке в контейнере (кнопке "Вернуться")
	# Это заставляет интерфейс мгновенно реагировать на клики и мышь, 
	# даже если анимация вставания или респауна в фоне пытается блокировать ввод!
	#if v_box_container and v_box_container.get_child_count() > 0:
	#	var first_button = v_box_container.get_child(0)
	#	if first_button is Control:
	#		first_button.grab_focus()


func close_pause_menu() -> void:
	# Возвращаем мышь обратно в скрытый режим для 3D-управления
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if blur_tween: blur_tween.kill()
	blur_tween = create_tween().set_parallel(true)
	blur_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	if v_box_container:
		blur_tween.tween_property(v_box_container, "modulate:a", 0.0, 0.1)
		
	# Плавно возвращаем 3D-мир в идеальную четкость
	blur_tween.tween_property(camera_attrs, "dof_blur_amount", 0.0, 0.2)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	# Когда мир полностью стал четким — снимаем паузу движка и прячем интерфейс
	blur_tween.finished.connect(func():
		get_tree().paused = false
		visible = false
		if v_box_container:
			v_box_container.modulate.a = 1.0
			
		# Отвязываем атрибуты в геймплее, чтобы не жрать ресурсы видеокарты при беге
		var player = get_tree().current_scene.find_child("Player", true, false)
		if player and player.has_node("Camera3D"):
			var camera = player.get_node("Camera3D") as Camera3D
			camera.attributes = null
	)


# --- ОБРАБОТКА СИГНАЛОВ КНОПОК ---
func _on_return_button_pressed() -> void:
	close_pause_menu()


func _on_settings_button_pressed() -> void:
	var settings_scene = preload("res://scenes/ui/settings_menu.tscn")
	var settings_instance = settings_scene.instantiate()
	add_child(settings_instance)


func _on_to_main_menu_button_pressed() -> void:
	get_tree().paused = false
	if has_node("/root/MusicManager"):
		get_node("/root/MusicManager").play_menu()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
