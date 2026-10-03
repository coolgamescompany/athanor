shader_type canvas_item;

// hint_screen_texture берет идеальный живой 3D-кадр со всем сглаживанием
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	// Мы жестко выставляем силу размытия на твои идеальные 0.25. 
	// А колыхание и лесенки полностью растворятся в аппаратных мип-мапах!
	COLOR = textureLod(screen_texture, SCREEN_UV, 0.25);
}
