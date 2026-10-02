shader_type canvas_item;

// Заменяем hint_screen_texture на обычную текстуру, куда мы закинем фото экрана
uniform sampler2D screen_texture : filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 5.0) = 0.0; 

void fragment() {
	// Идеально ровно размываем каждый пиксель фотографии
	COLOR = textureLod(screen_texture, SCREEN_UV, blur_amount);
}
