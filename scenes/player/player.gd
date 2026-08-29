extends CharacterBody3D

# Управление мышью
@export var mouse_sensitivity: float = 0.002
@onready var camera: Camera3D = %Camera3D
@onready var respawn_anim: AnimationPlayer = %AnimationPlayer

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

var spawn_position: Vector3


# РЕСПАВН ПОСЛЕ ПАДЕНИЯц
func respawn() -> void:
	# Чтобы функция не вызывалась повторно, пока идет телепорт
	if get_node("RespawnEffect/ColorRect").material.get_shader_parameter("white_fade") > 0.0:
		return
		
	set_physics_process(false)
	
	# 1. Мгновенно включаем белый экран (перематываем анимацию на старт)
	respawn_anim.play("wakeup")
	respawn_anim.seek(0.0, true)
	
	# Ждем крошечную долю секунды, чтобы экран успел побелеть перед переносом
	await get_tree().create_timer(0.05).timeout
	
	# 2. СБРОС УГЛА ВЗГЛЯДА
	# Обнуляем вращение тела игрока (направляем вдоль оси Z мира)
	global_rotation.y = 0.0
	# Обнуляем наклон головы камеры (смотрит строго горизонтально)
	camera.rotation.x = 0.0
	
	# 3. ТЕЛЕПОРТАЦИЯ
	global_position = spawn_position
	velocity = Vector3.ZERO
	
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if global_position.y < -30.0:
		respawn()
		
	# Добавление гравитации
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Прыжок
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Направление движения
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()


func _ready() -> void:
	# Игрок на старте просто захватывает курсор для игры
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Запоминаем стартовую позицию
	spawn_position = global_position
	# Стандартный режим: игрок автоматически засыпает, когда игра на паузе
	process_mode = PROCESS_MODE_PAUSABLE


func _input(event: InputEvent) -> void:
	# Так как игрок застывает на паузе, этот код не будет вращать камеру во время меню
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	# Возврат курсора по клику (если игрок переключился на другое окно и вернулся)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
