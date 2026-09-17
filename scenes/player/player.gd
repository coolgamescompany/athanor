extends CharacterBody3D

# --- ССЫЛКИ НА ВНУТРЕННИЕ УЗЛЫ UI И РЕНДЕРИНГА ---
@onready var interaction_ray: RayCast3D = %InteractionRay
@onready var crosshair: ColorRect = get_node("HUD/CanvasLayer/Crosshair")
@onready var camera: Camera3D = $Camera3D
@onready var respawn_anim: AnimationPlayer = %AnimationPlayer

# --- АУДИОКОМПОНЕНТЫ И ЭФФЕКТЫ ОКРУЖЕНИЯ ---
var step_sounds: Array = [
	preload("res://assets/sfx/walk/sfx_step_rock_l.wav"),
	preload("res://assets/sfx/walk/sfx_step_rock_r.wav")
]
@onready var step_sound: AudioStreamPlayer3D = %StepSound
@onready var jump_sound: AudioStreamPlayer3D = %JumpSound
@onready var respawn_sound: AudioStreamPlayer3D = %RespawnSound
@onready var spawn_particles: GPUParticles3D = %SpawnParticles
@onready var tinnitus_sound: AudioStreamPlayer = $TinnitusSound

# --- НАСТРОЙКИ ФИЗИКИ ПЕРЕМЕЩЕНИЯ ---
@export var WALK_SPEED: float = 5.0
@export var RUN_SPEED: float = 8.5
@export var CROUCH_SPEED: float = 2.5
@export var JUMP_VELOCITY: float = 4.5
@export var CROUCH_HEIGHT: float = 1.0
@export var mouse_sensitivity: float = 0.002

# --- СИСТЕМНЫЕ ПЕРЕМЕННЫЕ СОСТОЯНИЯ ---
var spawn_position: Vector3
var default_height: float
var camera_default_y: float
var is_crouching: bool = false
var step_timer: float = 0.0
var collision_shape: CollisionShape3D

# Флаг блокировки пользовательского ввода на время стартовой заставки
var cam_tween: Tween
var is_intro_playing: bool = true

# Накапливаемые целевые углы поворота для реализации плавного сглаживания (LERP)
var target_rotation_y: float = 0.0
var target_rotation_x: float = 0.0


func _ready() -> void:
	# === ФИКС СИНХРОНИЗАЦИИ ДЛЯ SUBVIEWPORT ===
	# Находим SubViewport, в котором живет игрок, и насильно привязываем к нему глаза нашей камеры
	var my_viewport = get_viewport()
	if my_viewport:
		# Говорим вьюпорту обновлять рендеринг и слушаться именно эту камеру
		camera.make_current()
	# Инициализация графических параметров из конфигурационного файла
	SettingsManager.apply_saved_graphics()
	
	# Запуск фонового аудиопотока игрового процесса
	if has_node("/root/MusicManager"):
		get_node("/root/MusicManager").play_menu()
		get_node("/root/MusicManager").play_game()
		
	# Захват курсора мыши и фиксация начальной точки спавна
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	spawn_position = global_position
	process_mode = PROCESS_MODE_PAUSABLE
	
	# Кэширование параметров коллизии для механики приседания
	for child in get_children():
		if child is CollisionShape3D:
			collision_shape = child
			if collision_shape.shape is CapsuleShape3D:
				default_height = collision_shape.shape.height
			break
	camera_default_y = camera.position.y
	
	# === ИНИЦИАЛИЗАЦИЯ СТАРТОВОЙ КАТСЦЕНЫ ПРОБУЖДЕНИЯ ===
	is_intro_playing = true
	
	# Загрузка пользовательских настроек угла обзора (FOV)
	var user_fov = 75.0
	if has_node("/root/SettingsManager"):
		user_fov = get_node("/root/SettingsManager").current_fov
	
	# Деактивация элементов интерфейса на время затемнения экрана
	if has_node("HUD/CanvasLayer/Crosshair"):
		crosshair.visible = false
	
	# Настройка исходного напольного ракурса камеры (взгляд направлен вниз)
	camera.position.y = -1.0
	camera.rotation.x = deg_to_rad(60)
	
	# Воспроизведение анимации раскрытия век
	respawn_anim.play("intro_wakeup")
	
	# Инициализация и плавное затухание эффекта тиннитуса (звона в ушах)
	await get_tree().create_timer(1.5).timeout
	if tinnitus_sound: 
		tinnitus_sound.volume_db = -12.0
		tinnitus_sound.play()
		var audio_tween = create_tween()
		audio_tween.tween_property(tinnitus_sound, "volume_db", -40.0, 8.5)
		audio_tween.tween_callback(tinnitus_sound.stop)
	

	# Задержка до фазы полного открытия глаз
	await get_tree().create_timer(6.5).timeout
	
	# === СТРОГАЯ ЗАЩИТА ТВИНА КАМЕРЫ ОТ ПРОПУСКА ===
	# Если разработчик уже пропустил интро кнопкой F/Enter — полностью блокируем создание Твина!
	if is_intro_playing:
		cam_tween = create_tween().set_parallel(true)
		cam_tween.tween_property(camera, "position:y", camera_default_y, 4.0)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		cam_tween.tween_property(camera, "rotation:x", 0.0, 4.0)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		cam_tween.tween_property(camera, "fov", user_fov, 4.0)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		# Завершение фазы интро, восстановление элементов интерфейса и активация ввода
		await get_tree().create_timer(4.0).timeout
		
		# Делаем финальную проверку, не нажали ли скип за эти 4 секунды
		if is_intro_playing:
			if has_node("HUD/CanvasLayer/Crosshair"):
				crosshair.visible = true
				
			if not SettingsManager.fov_changed.is_connected(_on_fov_updated):
				SettingsManager.fov_changed.connect(_on_fov_updated)
				
			is_intro_playing = false

			if has_node("/root/StoryManager"):
				get_node("/root/StoryManager").start_intro_sequence()
				
	# Кэшируем стартовые углы поворота персонажа и камеры для сглаживания
	target_rotation_y = rotation.y
	target_rotation_x = camera.rotation.x



func _on_fov_updated(new_fov: float) -> void:
	camera.fov = new_fov


func _physics_process(delta: float) -> void:
	# Проверка критического падения в бездну
	if global_position.y < -30.0:
		respawn()
		return
		
	# Блокировка перемещения и обработки ввода в режиме воспроизведения интро
	if is_intro_playing:
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
		return

	# Обработка стандартного гравитационного импульса
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Расчёт состояния изменения роста персонажа (Приседание)
	if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_C):
		is_crouching = true
	else:
		is_crouching = false

	# Интерполяция коллизии капсулы и положения высоты глаз
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var target_height = CROUCH_HEIGHT if is_crouching else default_height
		collision_shape.shape.height = lerp(collision_shape.shape.height, target_height, delta * 10.0)
	
	var target_camera_y = (CROUCH_HEIGHT * 0.5) if is_crouching else camera_default_y
	camera.position.y = target_camera_y # Скрипт камеры сам плавно подхватит это значение!


	# Обработка триггера прыжка (Добавлена жесткая защита от Enter при пропуске)
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_intro_playing:
		# Если игрок прыгает через Enter, СТРОГО запрещаем прыгать в микросекунду скипа!
		if not Input.is_key_pressed(KEY_ENTER):
			velocity.y = JUMP_VELOCITY
			jump_sound.play()

	# Определение модификатора линейной скорости (Шаг / Бег / Присед)
	var current_speed = WALK_SPEED
	if is_crouching:
		current_speed = CROUCH_SPEED
	elif Input.is_key_pressed(KEY_SHIFT):
		current_speed = RUN_SPEED

	# Расчёт направления вектора движения на основе плоскостных осей координат
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		
		# Обработка циклического воспроизведения звуков шагов на твердых поверхностях
		if is_on_floor() or is_on_wall():
			step_timer += delta
			var step_delay = 0.55
			if is_crouching: step_delay = 0.75
			elif current_speed == RUN_SPEED: step_delay = 0.35
			
			if step_timer >= step_delay:
				var random_index = randi() % step_sounds.size()
				step_sound.stream = step_sounds[random_index]
				step_sound.pitch_scale = randf_range(0.9, 1.1)
				step_sound.play()
				step_timer = 0.0
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
		step_timer = 0.0

	move_and_slide()
	
	# === ОБРАБОТКА ИНТЕРАКТИВНОГО СКАНИРОВАНИЯ ПРИЦЕЛА (RAYCAST3D) ===
	if interaction_ray.is_colliding():
		var hit_object = interaction_ray.get_collider()
		
		# Проверка принадлежности объекта коллизии к группе активного взаимодействия
		if hit_object.is_in_group("interactable"):
			if crosshair.modulate != Color("9c27b0"):
				create_tween().tween_property(crosshair, "modulate", Color("9c27b0"), 0.1)
		else:
			if crosshair.modulate != Color.WHITE:
				create_tween().tween_property(crosshair, "modulate", Color.WHITE, 0.1)
	else:
		if crosshair.modulate != Color.WHITE:
			create_tween().tween_property(crosshair, "modulate", Color.WHITE, 0.1)


func _input(event: InputEvent) -> void:
	# === ФИКС СИНХРОНИЗАЦИИ ДЛЯ SUBVIEWPORT ===
	# Находим SubViewport, в котором живет игрок, и насильно привязываем к нему глаза нашей камеры
	var my_viewport = get_viewport()
	if my_viewport:
		# Говорим вьюпорту обновлять рендеринг и слушаться именно эту камеру
		camera.make_current()
	# --- МЕХАНИКА ПРОПУСКА ИНТРО НА КНОПКУ [F] или [ENTER] ---
	if is_intro_playing and event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_F or event.physical_keycode == KEY_ENTER:
			print("Разработчик пропустил интро заставку.")
			
			# 1. Принудительно останавливаем текущую анимацию интро
			if respawn_anim.is_playing():
				respawn_anim.stop()
				respawn_anim.seek(0.0, true) # Возвращаем аниматор в исходную позицию
			
			# Намертво убиваем Твин подъёма головы, если он успел создаться
			if cam_tween and cam_tween.is_valid():
				cam_tween.kill()
			
			# ЖЕСТКИЙ ФИКС ЭФФЕКТОВ: Вместо сброса параметров шейдера в ноль, 
			# мы просто СВЕРТЫВАЕМ видимость самих оверлеев! Материал останется нетронутым для респауна!
			if %BlackRect: 
				%BlackRect.modulate.a = 0.0 # Сбрасываем прозрачность темноты в ноль на всякий случай
				%BlackRect.visible = false
			if %ShaderRect: 
				%ShaderRect.visible = false
				
			# 2. Мгновенно выравниваем камеру на стандартную высоту человеческого роста
			camera.position.y = camera_default_y
			camera.rotation.x = 0.0
			
			# 3. Восстанавливаем FOV из файла конфигурации и возвращаем прицел
			var user_fov = 75.0
			if has_node("/root/SettingsManager"):
				user_fov = get_node("/root/SettingsManager").current_fov
			camera.fov = user_fov
			
			if has_node("HUD/CanvasLayer/Crosshair"):
				crosshair.visible = true
				
			# 4. Безопасно восстанавливаем обработку сигналов изменения FOV из меню
			if not SettingsManager.fov_changed.is_connected(_on_fov_updated):
				SettingsManager.fov_changed.connect(_on_fov_updated)
				
			is_intro_playing = false
			
			# Запускаем нашу умную, последовательную цепочку мыслей и обучения
			if has_node("/root/StoryManager"):
				get_node("/root/StoryManager").start_intro_sequence()
				
			# Поглощаем ввод, чтобы Enter не вызывал автоматический прыжок персонажа
			get_viewport().set_input_as_handled()
			return

	# Игнорирование мыши во время блокировки управления катсценой
	if is_intro_playing: 
		return
		
	# Расчёт векторов вращения камеры и трансформации осей взгляда
	# Расчёт векторов вращения камеры и трансформации осей взгляда
	if event is InputEventMouseMotion:
		var raw_sens: float = SettingsManager.mouse_sensitivity
		if raw_sens <= 0: 
			raw_sens = 0.5
		
		# Возвращаем стандартный комфортный шаг чувствительности
		var sens: float = 0.003 * raw_sens
		var invert_multiplier = -1.0 if SettingsManager.mouse_inverted else 1.0
		
		# ВМЕСТО ПОВОРОТА: Просто копим целевые значения углов!
		target_rotation_y -= event.relative.x * sens
		target_rotation_x -= event.relative.y * sens * invert_multiplier
		target_rotation_x = clamp(target_rotation_x, deg_to_rad(-80), deg_to_rad(80))

		
		rotate_y(-event.relative.x * sens)
		camera.rotate_x(-event.relative.y * sens * invert_multiplier)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	# Автоматический захват фокуса мыши при клике по экрану
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- ЦИКЛ ОБРАБОТКИ ПЕРЕРОЖДЕНИЯ СУЩНОСТИ (RESPAWN) ---
func respawn() -> void:
	if get_node("RespawnEffect/ShaderRect").material.get_shader_parameter("white_fade") > 0.0:
		return
		
	# ЖЕСТКИЙ ФИКС: При падении включаем ТОЛЬКО шейдер вспышки! Чёрную шторку не трогаем!
	if %ShaderRect: %ShaderRect.visible = true
		
	set_physics_process(false)
	
	# Запуск анимации ослепления и звукового сопровожения респауна
	respawn_anim.play("wakeup")
	respawn_anim.seek(0.0, true)
	respawn_sound.play()
	
	await get_tree().create_timer(0.05).timeout
	
	# Сброс углов трансформации взгляда по осям координат
	global_rotation.y = 0.0
	camera.rotation.x = 0.0
	
	# Векторный перенос сущности в начальную точку и деактивация параметров скорости
	global_position = spawn_position
	velocity = Vector3.ZERO
	is_crouching = false
	
	set_physics_process(true)
	spawn_particles.restart()
	
	# Добавляем 1.5 секунды кинематографичной задержки, чтобы игрок успел прийти в себя после телепорта
	await get_tree().create_timer(1.5, false).timeout
	if has_node("/root/StoryManager"):
		get_node("/root/StoryManager").play_phrase("fall_abyss_thought")
