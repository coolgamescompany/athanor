extends Node3D

@onready var thoughts_template: Label3D = $ThoughtsText
@onready var system_template: Label3D = $SystemText
@onready var thought_sound: AudioStreamPlayer3D = $ThoughtSound
@onready var system_sound: AudioStreamPlayer3D = $SystemSound


func _ready() -> void:
	if thoughts_template:
		thoughts_template.visible = false
	if system_template:
		system_template.visible = false


func show_thought(player_node: CharacterBody3D, message: String, duration: float = 5.0) -> void:
	if not thoughts_template or not player_node:
		return
	await _spawn_label(thoughts_template, player_node, message, duration, thought_sound, 2.0, Vector3.ZERO)


func show_system_message(player_node: CharacterBody3D, message: String, duration: float = 6.0) -> void:
	if not system_template or not player_node:
		return
	if not SettingsManager.show_tutorial:
		return
	await _spawn_label(system_template, player_node, message, duration, system_sound, 2.2, Vector3(0, 0.3, 0))


func _spawn_label(
	template: Label3D,
	player_node: CharacterBody3D,
	message: String,
	duration: float,
	sfx: AudioStreamPlayer3D,
	forward_dist: float,
	extra_offset: Vector3
) -> void:
	var text_instance: Label3D = template.duplicate() as Label3D
	text_instance.text = tr(message)
	var forward_dir: Vector3 = -player_node.global_transform.basis.z.normalized()
	var cam_pos: Vector3 = player_node.get_node("Camera3D").global_position
	var target_pos: Vector3 = cam_pos + (forward_dir * forward_dist) + extra_offset

	get_tree().current_scene.add_child(text_instance)
	text_instance.global_position = target_pos
	text_instance.global_position.y -= 0.3
	text_instance.scale = Vector3(0.3, 0.3, 0.3)

	var base_color: Color = text_instance.modulate
	text_instance.modulate = Color(base_color.r, base_color.g, base_color.b, 0.0)
	text_instance.visible = true
	if sfx:
		sfx.play()

	var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(text_instance, "modulate", Color(base_color.r, base_color.g, base_color.b, 1.0), 0.4)
	tween.tween_property(text_instance, "global_position:y", target_pos.y, 0.4)
	tween.tween_property(text_instance, "scale", Vector3.ONE, 0.4)

	await get_tree().create_timer(duration, false).timeout
	if not is_instance_valid(text_instance):
		return
	var fade_tween: Tween = create_tween()
	fade_tween.tween_property(text_instance, "modulate", Color(base_color.r, base_color.g, base_color.b, 0.0), 0.4)
	await fade_tween.finished
	if is_instance_valid(text_instance):
		text_instance.queue_free()
