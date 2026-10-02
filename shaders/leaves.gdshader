shader_type canvas_item;

// hint_screen_texture сама делает идеальный снимок 3D-экрана со всем сглаживанием!
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 5.0) = 0.0; 

void fragment() {
	// Идеально гладкое ААА-размытие на уровне видеокарты
	COLOR = textureLod(screen_texture, SCREEN_UV, blur_amount);
}
