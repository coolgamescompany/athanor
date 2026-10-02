extends CanvasLayer

@onready var v_box_container: VBoxContainer = %VBoxContainer

var blur_tween: Tween
var camera_attrs: CameraAttributesPractical

func _ready() -> void:
	visible = false
	if v_box_container:
		v_box_container.modulate.a = 1.0
	
	# === ИНИЦИАЛИЗАЦИЯ ТОТАЛЬНОГО 3D БЛЮРА ===
	# Создаем один постоянный профиль размытия 3D-мира при старте
	camera_attrs = CameraAttributesPractical.new()
	camera_attrs.dof_blur_far_enabled = true
	camera_attrs.dof_blur_far_distance = 0.01   # Начинаем размывать прямо от глаз игрока
	
	# ЖЕСТКИЙ ФИКС ДЛЯ РАВНОМЕРНОСТИ: Сжимаем переход в абсолютный минимум,
	# чтобы размытие шло на 100% площади экрана равномерно, включая траву под ногами!
	camera_attrs.dof_blur_far_transition = 0.01 
	
	camera_attrs.dof_blur_amount = 0.0          # На старте игры картинка идеально четкая
	
	# Меню обязано работать, когда игра полностью заморожена на паузу
	process_mode = PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		
		if not get_tree().paused:
			open_pause_menu()
		else:
			close_pause_menu()


func open_pause_menu() -> void:
	# СТРАХОВКА РЕСПАУНА: Если идет вспышка падения, запрещаем ломать игру!
	var player = get_tree().current_scene.find_child("Player", true, false)
	if player and player.global_position.y < -20.0:
		return
		
	visible = true
	get_tree().paused = true # Намертво и безопасно включаем глобальную паузу движка
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Подключаем наши максимальные ААА-атрибуты размытия к глазам 3D-камеры игрока
	if player and player.has_node("Camera3D"):
		var camera = player.get_node("Camera3D") as Camera3D
		camera.attributes = camera_attrs
	
	# === ПЛАВНАЯ КИНЕМАТОГРАФИЧНАЯ АНИМАЦИЯ ===
	if blur_tween: blur_tween.kill()
	blur_tween = create_tween().set_parallel(true)
	blur_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# Плавное появление кнопок интерфейса
	if v_box_container:
		v_box_container.modulate.a = 0.0
		blur_tween.tween_property(v_box_container, "modulate:a", 1.0, 0.15)
	
	# ВЫКРУЧИВАЕМ РАЗМЫТИЕ В ХЛАМ: Сила блюра плавно растет до максимальных 3.0 за 0.25 секунды!
	blur_tween.tween_property(camera_attrs, "dof_blur_amount", 0.25, 0.25)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func close_pause_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if blur_tween: blur_tween.kill()
	blur_tween = create_tween().set_parallel(true)
	blur_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# Плавное исчезновение текста
	if v_box_container:
		blur_tween.tween_property(v_box_container, "modulate:a", 0.0, 0.1)
		
	# Плавный возврат 3D-камеры в кристальную четкость
	blur_tween.tween_property(camera_attrs, "dof_blur_amount", 0.0, 0.2)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	# Когда мир полностью стал четким — снимаем паузу и прячем меню
	blur_tween.finished.connect(func():
		get_tree().paused = false
		visible = false
		if v_box_container:
			v_box_container.modulate.a = 1.0
			
		# Отвязываем атрибуты в обычном геймплее для идеальной оптимизации FPS на ходу
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
