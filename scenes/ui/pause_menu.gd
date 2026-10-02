extends CanvasLayer

@onready var blur_rect: ColorRect = $ColorRect
@onready var v_box_container: VBoxContainer = %VBoxContainer

var blur_tween: Tween

func _ready() -> void:
	visible = false
	if blur_rect and blur_rect.material:
		(blur_rect.material as ShaderMaterial).set_shader_parameter("blur_amount", 0.0)
	if v_box_container:
		v_box_container.modulate.a = 1.0
	
	# Меню обязано работать, когда игра на паузе
	process_mode = PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		
		if not get_tree().paused:
			open_pause_menu()
		else:
			close_pause_menu()


func open_pause_menu() -> void:
	# === ДЕЛАЕМ МГНОВЕННОЕ ФОТО ЭКРАНА ===
	# Хватаем текущую картинку из буфера видеокарты
	var screen_image = get_viewport().get_texture().get_image()
	
	# === ВОТ ЭТОТ КРИТИЧЕСКИЙ ФИКС ДЛЯ РАЗМЫТИЯ: ===
	# Насильно заставляем картинку сгенерировать мип-мапы (слои сглаживания) в памяти!
	screen_image.generate_mipmaps()
	
	# Превращаем её в обычную 2D текстуру
	var screen_texture = ImageTexture.create_from_image(screen_image)
	
	# Запихиваем эту фотку внутрь нашего шейдера
	if blur_rect and blur_rect.material:
		(blur_rect.material as ShaderMaterial).set_shader_parameter("screen_texture", screen_texture)
	
	# Теперь со спокойной душой включаем видимость и замораживаем 3D мир намертво
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# === ПЛАВНАЯ АНИМАЦИЯ ===
	if blur_tween: blur_tween.kill()
	blur_tween = create_tween().set_parallel(true)
	blur_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# Плавно зажигаем кнопки текста
	if v_box_container:
		v_box_container.modulate.a = 0.0
		blur_tween.tween_property(v_box_container, "modulate:a", 1.0, 0.15)
	
	# Плавно размываем нашу статичную фотку от 0.0 до 3.5 за 0.25 секунды
	if blur_rect and blur_rect.material:
		blur_tween.tween_property(blur_rect.material, "shader_parameter/blur_amount", 3.5, 0.25)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func close_pause_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if blur_tween: blur_tween.kill()
	blur_tween = create_tween().set_parallel(true)
	blur_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# Плавно тушим кнопки
	if v_box_container:
		blur_tween.tween_property(v_box_container, "modulate:a", 0.0, 0.1)
	
	# Плавно возвращаем фотку в кристальную четкость
	if blur_rect and blur_rect.material:
		blur_tween.tween_property(blur_rect.material, "shader_parameter/blur_amount", 0.0, 0.2)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	# Когда анимация затухания завершилась — окончательно скрываем меню и размораживаем игру
	blur_tween.finished.connect(func():
		get_tree().paused = false
		visible = false
		if v_box_container:
			v_box_container.modulate.a = 1.0
			
		# Очищаем текстуру из памяти, чтобы она не висела мертвым грузом во время бега
		if blur_rect and blur_rect.material:
			(blur_rect.material as ShaderMaterial).set_shader_parameter("screen_texture", null)
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
