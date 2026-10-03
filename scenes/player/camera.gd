extends Camera3D

@export var IDLE_BOB_SPEED: float = 3.0
@export var IDLE_BOB_AMOUNT: float = 0.02
@export var WALK_BOB_SPEED: float = 14.0
@export var WALK_BOB_AMOUNT: float = 0.1
@export var WALK_BOB_SIDE: float = 0.1

var time_passed: float = 0.0
var parent_player: CharacterBody3D
var base_y: float = 0.0


func _ready() -> void:
	parent_player = get_parent() as CharacterBody3D


func _process(delta: float) -> void:
	if parent_player == null or parent_player.is_intro_playing:
		return

	time_passed += delta
	var is_moving: bool = parent_player.velocity.length() > 0.1 and parent_player.is_on_floor()
	base_y = (parent_player.CROUCH_HEIGHT * 0.5) if parent_player.is_crouching else parent_player.camera_default_y

	var target_pos_y: float = base_y
	var target_pos_x: float = 0.0
	if is_moving:
		var speed_factor: float = parent_player.velocity.length() / parent_player.WALK_SPEED
		var current_bob_speed: float = WALK_BOB_SPEED * speed_factor
		var dynamic_amount: float = WALK_BOB_AMOUNT * speed_factor
		var dynamic_side: float = WALK_BOB_SIDE * speed_factor
		target_pos_y = base_y + sin(time_passed * current_bob_speed) * dynamic_amount
		target_pos_x = cos(time_passed * current_bob_speed * 0.5) * dynamic_side
	else:
		target_pos_y = base_y + sin(time_passed * IDLE_BOB_SPEED) * IDLE_BOB_AMOUNT
		target_pos_x = cos(time_passed * IDLE_BOB_SPEED * 0.5) * IDLE_BOB_AMOUNT

	position.y = lerp(position.y, target_pos_y, delta * 10.0)
	position.x = lerp(position.x, target_pos_x, delta * 10.0)
