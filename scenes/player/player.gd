extends CharacterBody3D

@onready var interaction_ray: RayCast3D = %InteractionRay
@onready var crosshair: ColorRect = get_node("HUD/CanvasLayer/Crosshair")

# Настройки скоростей
@export var WALK_SPEED: float = 5.0
@export var RUN_SPEED: float = 8.5
@export var CROUCH_SPEED: float = 2.5
@export var JUMP_VELOCITY: float = 4.5

# Размеры приседания
@export var CROUCH_HEIGHT: float = 1.0

# Управление мышью
@export var mouse_sensitivity: float = 0.002
@onready var camera: Camera3D = $Camera3D
@onready var respawn_anim: AnimationPlayer = %AnimationPlayer

# Звуковые ноды игрока
var step_sounds: Array = [
	preload("res://assets/sfx/walk/sfx_step_rock_l.wav"),
	preload("res://assets/sfx/walk/sfx_step_rock_r.wav")
]
@onready var step_sound: AudioStreamPlayer = %StepSound
@onready var jump_sound: AudioStreamPlayer = %JumpSound
@onready var respawn_sound: AudioStreamPlayer = %RespawnSound
@onready var spawn_particles: GPUParticles3D = %SpawnParticles
@onready var tinnitus_sound: AudioStreamPlayer = $TinnitusSound

var spawn_position: Vector3
var default_height: float
var camera_default_y: float
var is_crouching: bool = false
var step_timer: float = 0.0
var collision_shape: CollisionShape3D

# --- ГЛАВНАЯ ПЕРЕМЕННАЯ БЛОКИРОВКИ УПРАВЛЕНИЯ ---
var is_intro_playing: bool = true

# РЕСПАВН ПОСЛЕ ПАДЕНИЯ
func respawn() -> void:
	if get_node("RespawnEffect/ShaderRect").material.get_shader_parameter("white_fade") > 0.0:

		return
		
	set_physics_process(false)
	
	# 1. Мгновенно включаем белый экран и звук вспышки
	respawn_anim.play("wakeup")
	respawn_anim.seek(0.0, true)
	respawn_sound.play() # Звук респауна играет прямо в момент беления!
	
	await get_tree().create_timer(0.05).timeout
	
	# 2. СБРОС УГЛА ВЗГЛЯДА
	global_rotation.y = 0.0
	camera.rotation.x = 0.0
	
	# 3. ТЕЛЕПОРТАЦИЯ
	global_position = spawn_position
	velocity = Vector3.ZERO
	is_crouching = false
	
	set_physics_process(true)
	spawn_particles.restart()

func _ready() -> void:
	SettingsManager.apply_saved_graphics()
	if has_node("/root/MusicManager"):
		get_node("/root/MusicManager").play_menu()
		
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	spawn_position = global_position
	process_mode = PROCESS_MODE_PAUSABLE
	
	if has_node("/root/MusicManager"):
		get_node("/root/MusicManager").play_game()
	
	# Ищем коллизию капсулы для приседания
	for child in get_children():
		if child is CollisionShape3D:
			collision_shape = child
			if collision_shape.shape is CapsuleShape3D:
				default_height = collision_shape.shape.height
			break
	camera_default_y = camera.position.y
	
	# --- КИНЕМАТОГРАФИЧНОЕ ИНТРО (10 СЕКУНД) ---
	is_intro_playing = true
	
	# Сначала берем честный FOV из файла настроек, чтобы знать к какому значению идти
	var user_fov = 75.0
	if has_node("/root/SettingsManager"):
		user_fov = get_node("/root/SettingsManager").current_fov
	
	# Прячем прицел в темноте
	if has_node("HUD/CanvasLayer/Crosshair"):
		crosshair.visible = false
	
	# Алхимик жестко лежит лицом в полу
	camera.position.y = -1.0
	camera.rotation.x = deg_to_rad(60) # Поставил минус, чтобы взгляд был в землю, а не в небо
	
	respawn_anim.play("intro_wakeup")
	
	# 1. Звук тиннитуса с задержкой 1.5 сек
	await get_tree().create_timer(1.5).timeout
	if tinnitus_sound: 
		tinnitus_sound.volume_db = -12.0
		tinnitus_sound.play()
		var audio_tween = create_tween()
		audio_tween.tween_property(tinnitus_sound, "volume_db", -40.0, 8.5)
		audio_tween.tween_callback(tinnitus_sound.stop)
	
	# 2. Ждем еще 6.5 секунды до полного открытия глаз (суммарно 6 секунд тишины и темноты)
	await get_tree().create_timer(6.5).timeout
	
	# Начинаем плавный подъем из пола
	var cam_tween = create_tween().set_parallel(true)
	
	# Камера плавно встает на ноги
	cam_tween.tween_property(camera, "position:y", camera_default_y, 4.0)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
	# Глаза плавно поднимаются к горизонту скал
	cam_tween.tween_property(camera, "rotation:x", 0.0, 4.0)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
	# Во время самого подъема плавно подгоняем FOV камеры под настройки пользователя!
	cam_tween.tween_property(camera, "fov", user_fov, 4.0)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# 3. ФИНАЛ ИНТРО (Прошло ровно 10 секунд от старта игры)
	await get_tree().create_timer(4.0).timeout
	
	# Включаем прицел обратно
	if has_node("HUD/CanvasLayer/Crosshair"):
		crosshair.visible = true
		
	# Включаем сигналы динамического изменения FOV из меню
	SettingsManager.fov_changed.connect(_on_fov_updated)
	
	# Открываем управление!
	is_intro_playing = false


		
		

func _on_fov_updated(new_fov: float):
	camera.fov = new_fov

func _physics_process(delta: float) -> void:
	if global_position.y < -30.0:
		respawn()
		return
		
	# Если идет интро — гравитация работает, но WASD, бег и прыжки полностью отключены!
	if is_intro_playing:
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
		return

	# Добавление гравитации
	if not is_on_floor():
		velocity += get_gravity() * delta

	# ЛОГИКА ПРИСЕДАНИЯ (Работает везде: и на земле, и в воздухе)
	if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_C):
		is_crouching = true
	else:
		is_crouching = false

	# Плавное изменение роста капсулы и положения глаз камеры (lerp)
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var target_height = CROUCH_HEIGHT if is_crouching else default_height
		collision_shape.shape.height = lerp(collision_shape.shape.height, target_height, delta * 10.0)
	
	var target_camera_y = (CROUCH_HEIGHT * 0.5) if is_crouching else camera_default_y
	camera.position.y = lerp(camera.position.y, target_camera_y, delta * 10.0)

	# Прыжок
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		jump_sound.play() # Звук прыжка

	# Выбираем скорость перемещения (Бег на Shift, Присед на Ctrl/C)
	var current_speed = WALK_SPEED
	if is_crouching:
		current_speed = CROUCH_SPEED
	elif Input.is_key_pressed(KEY_SHIFT):
		current_speed = RUN_SPEED

	# Направление движения
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		
		# ТАЙМЕР ШАГОВ (звук воспроизводится только когда мы на земле)
		if is_on_floor() or is_on_wall():
			step_timer += delta
			var step_delay = 0.55 # Обычный шаг
			if is_crouching: step_delay = 0.75 # Медленный присед
			elif current_speed == RUN_SPEED: step_delay = 0.35 # Быстрый бег
			
			if step_timer >= step_delay:
				# Выбираем случайный звук из нашего массива (0 или 1)
				var random_index = randi() % step_sounds.size()
				step_sound.stream = step_sounds[random_index]
				
				# Немного меняем высоту тона (pitch), чтобы шаги были уникальными
				step_sound.pitch_scale = randf_range(0.9, 1.1)
				
				# Воспроизводим!
				step_sound.play()
				step_timer = 0.0
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
		step_timer = 0.0

	move_and_slide()
	
	# ЛОГИКА ИНТЕРАКТИВНОГО ПРИЦЕЛА
	if interaction_ray.is_colliding():
		# Получаем объект, на который наткнулся лазер
		var hit_object = interaction_ray.get_collider()
		
		# Проверяем, есть ли у этого объекта маркер или группа "interactable"
		# (Мы будем добавлять эту группу всем кристаллам, травам и алтарям)
		if hit_object.is_in_group("interactable"):
			# Плавно красим прицел в фиолетовый, если еще не покрашен
			if crosshair.modulate != Color("9c27b0"):
				create_tween().tween_property(crosshair, "modulate", Color("9c27b0"), 0.1)
		else:
			# Если объект твердый (остров), но не интерактивный — возвращаем белый
			if crosshair.modulate != Color.WHITE:
				create_tween().tween_property(crosshair, "modulate", Color.WHITE, 0.1)
	else:
		# Если лазер смотрит в пустоту космоса — возвращаем белый
		if crosshair.modulate != Color.WHITE:
			create_tween().tween_property(crosshair, "modulate", Color.WHITE, 0.1)

func _input(event: InputEvent) -> void:
	# Если идет катсцена — мышка намертво блокируется и не крутит голову!
	if is_intro_playing: 
		return
		
	if event is InputEventMouseMotion:
		# Получаем значение от 1 до 100 из настроек. 
		# Если файл пустой или сбоит, принудительно берём 5 (как среднюю скорость)
		var raw_sens: float = SettingsManager.mouse_sensitivity
		if raw_sens <= 0: 
			raw_sens = 5.0
		
		# ЖЕСТКАЯ ПРЯМАЯ ФОРМУЛА:
		# Берем вашу изначальную идеальную скорость (0.002) и умножаем на ползунок.
		# Ползунок на 1 = ваша старая скорость. Ползунок на 10 = в 10 раз быстрее!
		var sens: float = 0.002 * raw_sens
		
		var invert_multiplier = -1.0 if SettingsManager.mouse_inverted else 1.0
		
		# Поворачиваем камеру космического алхимика
		rotate_y(-event.relative.x * sens)
		camera.rotate_x(-event.relative.y * sens * invert_multiplier)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
