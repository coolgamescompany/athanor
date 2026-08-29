extends CharacterBody3D

# Управление мышью
@export var mouse_sensitivity: float = 0.002
@onready var camera: Camera3D = %Camera3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5


func _physics_process(delta: float) -> void:
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
