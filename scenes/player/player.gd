extends CharacterBody3D

# Управление мышью
@export var mouse_sensitivity: float = 0.002
@onready var camera: Camera3D = %Camera3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
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
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# Вращаем всего персонажа влево-вправо (по оси Y)
		rotate_y(-event.relative.x * mouse_sensitivity)
		# Вращаем только камеру вверх-вниз (по оси X)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		# Ограничиваем наклон головы, чтобы шея не сломалась (в радианах)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))
	
	# Если нажали клавишу Escape
	if event.is_action_pressed("ui_cancel"):
		# ui_cancel — это встроенное в Godot действие для кнопки Escape
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			# Если мышка была заблокирована, просто освобождаем её
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			# Если мышка уже свободна, закрываем игру полностью
			get_tree().quit()
	# Если кликнули левой кнопкой мыши по экрану
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			# Снова прячем курсор и возвращаемся в игру
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
