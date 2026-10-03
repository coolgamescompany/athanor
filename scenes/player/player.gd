extends CharacterBody3D

@onready var interaction_ray: RayCast3D = %InteractionRay
@onready var crosshair: ColorRect = $HUD/CanvasLayer/Crosshair
@onready var camera: Camera3D = $Camera3D
@onready var respawn_anim: AnimationPlayer = %AnimationPlayer
@onready var shader_rect: ColorRect = %ShaderRect
@onready var black_rect: ColorRect = %BlackRect

var step_sounds: Array[AudioStream] = [
	preload("res://assets/sfx/walk/sfx_step_rock_l.wav"),
	preload("res://assets/sfx/walk/sfx_step_rock_r.wav")
]
@onready var step_sound: AudioStreamPlayer = %StepSound
@onready var jump_sound: AudioStreamPlayer = %JumpSound
@onready var respawn_sound: AudioStreamPlayer = %RespawnSound
@onready var spawn_particles: GPUParticles3D = %SpawnParticles
@onready var tinnitus_sound: AudioStreamPlayer = %TinnitusSound

@export var WALK_SPEED: float = 3.2
@export var RUN_SPEED: float = 5.2
@export var CROUCH_SPEED: float = 1.8
@export var JUMP_VELOCITY: float = 4.2
@export var CROUCH_HEIGHT: float = 1.0
@export var mouse_sensitivity: float = 0.002

var spawn_position: Vector3
var default_height: float = 2.0
var camera_default_y: float = 0.5
var is_crouching: bool = false
var step_timer: float = 0.0
var collision_shape: CollisionShape3D

var cam_tween: Tween
var is_intro_playing: bool = true
var is_respawning: bool = false
var crosshair_tween: Tween


func _ready() -> void:
	if camera:
		camera.make_current()

	for child in get_children():
		if child is CollisionShape3D:
			collision_shape = child
			if collision_shape.shape is CapsuleShape3D:
				# Уникальная копия формы, чтобы присед не ломал ресурс сцены
				collision_shape.shape = collision_shape.shape.duplicate()
				default_height = (collision_shape.shape as CapsuleShape3D).height
			break
	camera_default_y = camera.position.y
	floor_snap_length = 0.25

	SettingsManager.apply_saved_graphics()
	MusicManager.play_game()

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	process_mode = Node.PROCESS_MODE_PAUSABLE

	if not SettingsManager.fov_changed.is_connected(_on_fov_updated):
		SettingsManager.fov_changed.connect(_on_fov_updated)

	var has_save_file: bool = SaveManager.load_game()
	if has_save_file and SaveManager.save_data["player"]["has_saved_position"]:
		global_position = Vector3(
			SaveManager.save_data["player"]["spawn_x"],
			SaveManager.save_data["player"]["spawn_y"],
			SaveManager.save_data["player"]["spawn_z"]
		)
		spawn_position = global_position
		black_rect.visible = false
		shader_rect.visible = false
		is_intro_playing = false
		camera.position.y = camera_default_y
		camera.rotation.x = 0.0
		camera.fov = SettingsManager.current_fov
		_set_crosshair_visible(true)
	else:
		spawn_position = global_position
		is_intro_playing = true
		_set_crosshair_visible(false)
		camera.position.y = -1.0
		camera.rotation.x = deg_to_rad(60)
		respawn_anim.play("intro_wakeup")

	if is_intro_playing:
		await get_tree().create_timer(1.5).timeout
		if not _is_alive() or not is_intro_playing:
			return
		if tinnitus_sound:
			tinnitus_sound.volume_db = -12.0
			tinnitus_sound.play()
			var audio_tween: Tween = create_tween()
			audio_tween.tween_property(tinnitus_sound, "volume_db", -40.0, 8.5)
			audio_tween.tween_callback(tinnitus_sound.stop)

		await get_tree().create_timer(6.5).timeout
		if not _is_alive() or not is_intro_playing:
			return

		cam_tween = create_tween().set_parallel(true)
		cam_tween.tween_property(camera, "position:y", camera_default_y, 4.0)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		cam_tween.tween_property(camera, "rotation:x", 0.0, 4.0)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		cam_tween.tween_property(camera, "fov", SettingsManager.current_fov, 4.0)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

		await get_tree().create_timer(4.0).timeout
		if not _is_alive() or not is_intro_playing:
			return

		_set_crosshair_visible(true)
		is_intro_playing = false
		StoryManager.on_intro_finished()

	if respawn_anim and not respawn_anim.animation_finished.is_connected(_on_portal_animation_finished):
		respawn_anim.animation_finished.connect(_on_portal_animation_finished)


func _is_alive() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


func _set_crosshair_visible(show_it: bool) -> void:
	if crosshair:
		crosshair.visible = show_it


func _on_fov_updated(new_fov: float) -> void:
	if is_intro_playing:
		return
	camera.fov = new_fov


func _physics_process(delta: float) -> void:
	if global_position.y < -30.0:
		respawn()
		return

	if is_intro_playing:
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	var want_crouch: bool = Input.is_action_pressed("crouch")
	if want_crouch:
		is_crouching = true
	elif is_crouching and not _ceiling_blocks_standup():
		is_crouching = false

	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = collision_shape.shape
		var target_height: float = CROUCH_HEIGHT if is_crouching else default_height
		capsule.height = lerp(capsule.height, target_height, delta * 10.0)

	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_intro_playing:
		velocity.y = JUMP_VELOCITY
		jump_sound.play()

	var current_speed: float = WALK_SPEED
	if is_crouching:
		current_speed = CROUCH_SPEED
	elif Input.is_action_pressed("sprint"):
		current_speed = RUN_SPEED

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if input_dir.length() > 0.0:
		if not StoryManager.has_player_moved_at_least_once or StoryManager.current_story_stage == 2:
			StoryManager.on_player_moved()

	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		if is_on_floor():
			step_timer += delta
			var step_delay: float = 0.55
			if is_crouching:
				step_delay = 0.75
			elif current_speed == RUN_SPEED:
				step_delay = 0.35
			if step_timer >= step_delay:
				var random_index: int = randi() % step_sounds.size()
				step_sound.stream = step_sounds[random_index]
				step_sound.pitch_scale = randf_range(0.9, 1.1)
				step_sound.play()
				step_timer = 0.0
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
		step_timer = 0.0

	move_and_slide()
	_update_crosshair_state()
	_try_interact()


func _ceiling_blocks_standup() -> bool:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from: Vector3 = global_position
	var to: Vector3 = global_position + Vector3.UP * (default_height * 0.5 + 0.1)
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, [get_rid()])
	return not space.intersect_ray(query).is_empty()


func _update_crosshair_state() -> void:
	if crosshair == null:
		return
	if interaction_ray.is_colliding():
		var hit_object: Object = interaction_ray.get_collider()
		if hit_object and hit_object.is_in_group("interactable"):
			if crosshair.modulate != Color("9c27b0"):
				_animate_crosshair(Color("9c27b0"))
		elif crosshair.modulate != Color.WHITE:
			_animate_crosshair(Color.WHITE)
	elif crosshair.modulate != Color.WHITE:
		_animate_crosshair(Color.WHITE)


func _try_interact() -> void:
	if not Input.is_action_just_pressed("interact"):
		return
	if not interaction_ray.is_colliding():
		return
	var hit_object: Object = interaction_ray.get_collider()
	if hit_object and hit_object.has_method("interact"):
		hit_object.interact()


func _animate_crosshair(target_color: Color) -> void:
	if crosshair_tween and crosshair_tween.is_valid():
		crosshair_tween.kill()
	crosshair_tween = create_tween()
	crosshair_tween.tween_property(crosshair, "modulate", target_color, 0.1)


func _input(event: InputEvent) -> void:
	if is_intro_playing and event is InputEventKey and event.pressed:
		var key_event: InputEventKey = event
		if key_event.physical_keycode == KEY_F or key_event.physical_keycode == KEY_ENTER:
			_skip_intro()
			get_viewport().set_input_as_handled()
			return

	if is_intro_playing:
		return

	if event is InputEventMouseMotion:
		var raw_sens: float = SettingsManager.mouse_sensitivity
		if raw_sens <= 0.0:
			raw_sens = 0.5
		var sens: float = 0.003 * raw_sens
		var invert_multiplier: float = -1.0 if SettingsManager.mouse_inverted else 1.0
		rotate_y(-event.relative.x * sens)
		camera.rotate_x(-event.relative.y * sens * invert_multiplier)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _skip_intro() -> void:
	if respawn_anim.is_playing():
		respawn_anim.stop()
		respawn_anim.seek(0.0, true)
	if cam_tween and cam_tween.is_valid():
		cam_tween.kill()

	black_rect.modulate.a = 0.0
	black_rect.visible = false
	shader_rect.visible = false
	if shader_rect.material:
		shader_rect.material.set_shader_parameter("white_fade", 0.0)

	camera.position.y = camera_default_y
	camera.rotation.x = 0.0
	camera.fov = SettingsManager.current_fov
	_set_crosshair_visible(true)
	is_intro_playing = false
	StoryManager.on_intro_finished()


func respawn() -> void:
	if is_respawning:
		return
	is_respawning = true
	shader_rect.visible = true
	set_physics_process(false)

	respawn_anim.play("wakeup")
	respawn_anim.seek(0.0, true)
	respawn_sound.play()

	await get_tree().create_timer(0.05).timeout
	if not _is_alive():
		return

	global_rotation.y = 0.0
	camera.rotation.x = 0.0
	global_position = spawn_position
	velocity = Vector3.ZERO
	is_crouching = false
	set_physics_process(true)
	spawn_particles.restart()

	await get_tree().create_timer(1.5, false).timeout
	is_respawning = false
	if _is_alive():
		StoryManager.play_phrase_cinematic("fall_abyss_thought")


func start_portal_fading() -> void:
	shader_rect.visible = true
	if respawn_anim and respawn_anim.has_animation("portal_entered"):
		respawn_anim.speed_scale = 1.0
		respawn_anim.play("portal_entered")


func cancel_portal_fading() -> void:
	if respawn_anim and respawn_anim.has_animation("portal_entered"):
		respawn_anim.play_backwards("portal_entered")
		respawn_anim.speed_scale = 0.7


func complete_teleport() -> void:
	shader_rect.visible = true
	if respawn_anim and respawn_anim.has_animation("wakeup"):
		respawn_anim.speed_scale = 1.0
		respawn_anim.play("wakeup")
		respawn_anim.seek(0.0, true)
	if respawn_sound:
		respawn_sound.play()
	if spawn_particles:
		spawn_particles.restart()
	spawn_position = global_position


func _on_portal_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"portal_entered" and respawn_anim.speed_scale < 1.0:
		shader_rect.visible = false
