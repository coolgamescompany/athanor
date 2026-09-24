shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx, depth_prepass_alpha;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;

// Настройки ветра
uniform float wind_speed : hint_range(0.0, 10.0) = 1.0;
uniform float wind_strength : hint_range(0.0, 2.0) = 0.2;
uniform float wind_frequency : hint_range(0.0, 5.0) = 2.0;

void vertex() {
    float time = TIME * wind_speed;
    float wave = sin(time + VERTEX.x * wind_frequency) * cos(time + VERTEX.z * wind_frequency);
    
    // Эффект сильнее на кончиках (чем выше вершина по Y локально, тем сильнее гнется)
    float wind_weight = max(0.0, VERTEX.y * 0.5); 
    
    VERTEX.x += wave * wind_strength * wind_weight;
    VERTEX.z += wave * wind_strength * wind_weight;
}

void fragment() {
    vec4 albedo_tex = texture(texture_albedo, UV);
    ALBEDO = albedo.rgb * albedo_tex.rgb;
    ALPHA = albedo_tex.a;
    ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
}
