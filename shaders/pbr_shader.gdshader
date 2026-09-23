shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Группа настроек для тайлинга (масштабирования)
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform vec2 uv_offset = vec2(0.0, 0.0);

// Группа Альбедо
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color, hint_default_white, filter_linear_mipmap;

// Группа Металличности
uniform float metallic_intensity : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D texture_metallic : hint_default_white, filter_linear_mipmap;

// Группа Шероховатости
uniform float roughness_intensity : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D texture_roughness : hint_default_white, filter_linear_mipmap;

// Группа Нормалей
uniform float normal_intensity : hint_range(-16.0, 16.0) = 1.0;
uniform sampler2D texture_normal : hint_normal, filter_linear_mipmap;

// Группа Затенения (AO)
uniform sampler2D texture_ambient_occlusion : hint_default_white, filter_linear_mipmap;

void fragment() {
	// Применяем тайлинг и смещение UV-координат
	vec2 base_uv = UV * uv_scale + uv_offset;
	
	// 1. Альбедо
	vec4 albedo_tex = texture(texture_albedo, base_uv);
	ALBEDO = albedo_color.rgb * albedo_tex.rgb;
	
	// 2. Металличность (данные берем из Red канала)
	float metallic_tex = texture(texture_metallic, base_uv).r;
	METALLIC = metallic_tex * metallic_intensity;
	
	// 3. Шероховатость (данные берем из Red канала)
	float roughness_tex = texture(texture_roughness, base_uv).r;
	ROUGHNESS = roughness_tex * roughness_intensity;
	
	// 4. Карта нормалей
	NORMAL_MAP = texture(texture_normal, base_uv).rgb;
	NORMAL_MAP_DEPTH = normal_intensity;
	
	// 5. Ambient Occlusion (данные берем из Red канала)
	AO = texture(texture_ambient_occlusion, base_uv).r;
	AO_LIGHT_AFFECT = 1.0; // Насколько сильно AO влияет на динамический свет
}
