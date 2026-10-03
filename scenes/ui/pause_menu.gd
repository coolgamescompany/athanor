extends CanvasLayer

@onready var v_box_container: VBoxContainer = %VBoxContainer

var blur_tween: Tween
var camera_attrs: CameraAttributesPractical

func _ready() -> void:
	visible = false
	if v_box_container:
		v_box_container.modulate.a = 1.0
	
	# === КРИТИЧЕСКИЙ ФИКС СЛОЕВ ===
	# Поднимаем слой паузы выше HUD игрока
	layer = 2
	
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
	# Страховка респауна
	var player = get_tree().current_scene.find_child("Player", true, false) as CharacterBody3D
	if player and player.global_position.y < -20.0:
		return
		
	# === ОТКЛЮЧЕНИЕ ПРИЦЕЛА ПО ТОЧНОМУ ПУТИ ===
	# Стучимся в плеер, открываем HUD, заходим в CanvasLayer и тушим Crosshair!
	if player and player.has_node("HUD/CanvasLayer/Crosshair"):
		player.get_node("HUD/CanvasLayer/Crosshair").visible = false
		
	visible = true
	get_tree().paused = true # Безопасно замораживаем глобальную физику движка
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Подключаем наши ААА-атрибуты размытия к 3D-камере игрока
	if player and player.has_node("Camera3D"):
		var camera = player.get_node("Camera3D") as Camera3D
		camera.attributes = camera_attrs
	
	# Анимация плавного появления кнопок
	if blur_tween: blur_tween.kill()
	blur_tween = create_tween().set_parallel(true)
	blur_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	if v_box_container:
		v_box_container.modulate.a = 0.0
		blur_tween.tween_property(v_box_container, "modulate:a", 1.0, 0.15)
	
	# Плавно выводим сочное размытие на твое идеальное значение 0.25
	blur_tween.tween_property(camera_attrs, "dof_blur_amount", 0.25, 0.25)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func close_pause_menu() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if blur_tween: blur_tween.kill()
	blur_tween = create_tween().set_parallel(true)
	blur_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	if v_box_container:
		blur_tween.tween_property(v_box_container, "modulate:a", 0.0, 0.1)
		
	# Плавно возвращаем 3D-мир в идеальную четкость
	blur_tween.tween_property(camera_attrs, "dof_blur_amount", 0.0, 0.2)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	blur_tween.finished.connect(func():
		get_tree().paused = false
		visible = false
		if v_box_container:
			v_box_container.modulate.a = 1.0
			
		# === ВОЗВРАЩАЕМ ПРИЦЕЛ ПРИ ВЫХОДЕ ИЗ ПАУЗЫ ===
		var player = get_tree().current_scene.find_child("Player", true, false) as CharacterBody3D
		if player and player.has_node("HUD/CanvasLayer/Crosshair"):
			player.get_node("HUD/CanvasLayer/Crosshair").visible = true
			
		# Отвязываем атрибуты в геймплее
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
