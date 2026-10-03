extends Control

@onready var label: Label = %FPSLabel
var _fps_accum: float = 0.0


func _process(delta: float) -> void:
	_fps_accum += delta
	if _fps_accum < 0.25:
		return
	_fps_accum = 0.0
	var show_fps: bool = SettingsManager.show_fps_counter
	label.visible = show_fps
	if show_fps:
		label.text = "FPS: %d" % Engine.get_frames_per_second()
