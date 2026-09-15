extends Node3D

@onready var thoughts_template: Label3D = $ThoughtsText
@onready var system_template: Label3D = $SystemText

@onready var thought_sound: AudioStreamPlayer3D = $ThoughtSound
@onready var system_sound: AudioStreamPlayer3D = $SystemSound

func _ready() -> void:
	if thoughts_template: thoughts_template.visible = false
	if system_template: system_template.visible = false

# === 1. ВЫВОД МЫСЛЕЙ АЛХИМИКА (Фиолетовый текст) ===
func show_thought(player_node: CharacterBody3D, message: String, duration: float = 5.0) -> void:
	if not thoughts_template or not player_node: return
		
	var text_instance = thoughts_template.duplicate() as Label3D
	text_instance.text = message
	
	var forward_dir = -player_node.global_transform.basis.z.normalized()
	var cam_pos = player_node.get_node("Camera3D").global_position
	var target_pos = cam_pos + (forward_dir * 2.0)
	
	get_tree().current_scene.add_child(text_instance)
	text_instance.global_position = target_pos
	
	text_instance.global_position.y -= 0.3
	text_instance.scale = Vector3(0.3, 0.3, 0.3)
	
	var base_color = text_instance.modulate
	text_instance.modulate = Color(base_color.r, base_color.g, base_color.b, 0.0)
	text_instance.visible = true
	
	if thought_sound: thought_sound.play()
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(text_instance, "modulate", Color(base_color.r, base_color.g, base_color.b, 1.0), 0.4)
	tween.tween_property(text_instance, "global_position:y", target_pos.y, 0.4)
	tween.tween_property(text_instance, "scale", Vector3.ONE, 0.4)
	
	await get_tree().create_timer(duration, false).timeout
	
	var fade_tween = create_tween()
	fade_tween.tween_property(text_instance, "modulate", Color(base_color.r, base_color.g, base_color.b, 0.0), 0.4)
	await fade_tween.finished
	text_instance.queue_free()

# === 2. ВЫВОД ИНСТРУКЦИЙ ОБУЧЕНИЯ (Белый текст) ===
func show_system_message(player_node: CharacterBody3D, message: String, duration: float = 6.0) -> void:
	if not system_template or not player_node: return
	
	if has_node("/root/SettingsManager"):
		if not get_node("/root/SettingsManager").show_tutorial:
			return 

	var text_instance = system_template.duplicate() as Label3D
	text_instance.text = message
	
	var forward_dir = -player_node.global_transform.basis.z.normalized()
	var cam_pos = player_node.get_node("Camera3D").global_position
	var target_pos = cam_pos + (forward_dir * 2.2) + Vector3(0, 0.3, 0)
	
	get_tree().current_scene.add_child(text_instance)
	text_instance.global_position = target_pos
	
	text_instance.global_position.y -= 0.3
	text_instance.scale = Vector3(0.3, 0.3, 0.3)
	
	var base_color = text_instance.modulate
	text_instance.modulate = Color(base_color.r, base_color.g, base_color.b, 0.0)
	text_instance.visible = true
	
	if system_sound: system_sound.play()
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(text_instance, "modulate", Color(base_color.r, base_color.g, base_color.b, 1.0), 0.4)
	tween.tween_property(text_instance, "global_position:y", target_pos.y, 0.4)
	tween.tween_property(text_instance, "scale", Vector3.ONE, 0.4)
	
	await get_tree().create_timer(duration, false).timeout
	
	var fade_tween = create_tween()
	fade_tween.tween_property(text_instance, "modulate", Color(base_color.r, base_color.g, base_color.b, 0.0), 0.4)
	await fade_tween.finished
	text_instance.queue_free()
