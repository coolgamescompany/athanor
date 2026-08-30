extends Node3D

@export var default_color: Color = Color.WHITE
@export var hover_color: Color = Color("ca55dfff") # Неоново-фиолетовый
@export var animate_time: float = 0.2

# Ссылки на звуковые ноды, которые мы создали в корне Главного Меню
@onready var hover_sound: AudioStreamPlayer = %MenuHoverSound
@onready var click_sound: AudioStreamPlayer = %MenuClickSound

func _ready() -> void:
	# Железобетонно снимаем паузу со всей вселенной игры при заходе в меню!
	get_tree().paused = false 
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Ждем один кадр, чтобы Autoload (MusicManager) успел создаться в памяти
	await get_tree().process_frame
	
	if has_node("/root/MusicManager"):
		get_node("/root/MusicManager").play_menu()
		
	# Автоматически настраиваем все кнопки и подключаем их сигналы из кода!
	# Чтобы не пришлось вручную кликать и привязывать 6 новых сигналов через интерфейс.
	var buttons = [%PlayButton, 
				   %SettingsButton, 
				   %ExitButton]
				   
	for btn in buttons:
		if btn is Button:
			btn.focus_mode = Control.FOCUS_NONE
			btn.modulate = default_color
			# Привязываем наведение мыши к нашим универсальным функциям пониже:
			btn.mouse_entered.connect(_on_btn_hover_start.bind(btn))
			btn.mouse_exited.connect(_on_btn_hover_end.bind(btn))
			
	

# Универсальная функция плавного зажигания фиолетового цвета + звук
func _on_btn_hover_start(btn: Button) -> void:
	if hover_sound:
		hover_sound.pitch_scale = randf_range(0.95, 1.05)
		hover_sound.play()
		
	var tween = create_tween().set_parallel(true) # Заставляем цвет и позицию анимироваться одновременно!
	
	# Плавно красим в фиолетовый
	tween.tween_property(btn, "modulate", hover_color, animate_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
	# Плавно сдвигаем кнопку вправо на 15 пикселей (можешь поменять число на своё)
	tween.tween_property(btn, "position:x", 15.0, animate_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# Универсальная функция плавного возвращения обратно
func _on_btn_hover_end(btn: Button) -> void:
	var tween = create_tween().set_parallel(true)
	
	# Возвращаем белый цвет
	tween.tween_property(btn, "modulate", default_color, animate_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
	# Возвращаем кнопку на исходное место (0 пикселей смещения)
	tween.tween_property(btn, "position:x", 0.0, animate_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# ИГРОВЫЕ КНОПКИ
func _on_play_button_pressed() -> void:
	if click_sound: click_sound.play()
	get_tree().change_scene_to_file("res://world.tscn")

func _on_settings_button_pressed() -> void:
	if click_sound: click_sound.play()
	
	var settings_scene = preload("res://scenes/ui/settings_menu.tscn")
	var settings_instance = settings_scene.instantiate()
	
	# Стучимся ко второй ноде в дереве сцены (твоему переименованному CanvasLayer)
	# и закидываем настройки внутрь него, принудительно поверх кнопок
	$MainMenu.add_child(settings_instance)



func _on_exit_button_pressed() -> void:
	if click_sound: click_sound.play()
	# Даем звуку клика 0.1 секунды честно дозвучать перед тем, как мгновенно убить процесс
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()
