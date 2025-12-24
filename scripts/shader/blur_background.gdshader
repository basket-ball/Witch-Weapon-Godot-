shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 10.0) = 4.5;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec4 color = vec4(0.0);

	// 方框模糊 - 简单平均采样
	float blur_size = blur_amount * 0.002;
	int samples = 0;

	// 5x5方框采样
	for(int x = -2; x <= 2; x++) {
		for(int y = -2; y <= 2; y++) {
			vec2 offset = vec2(float(x), float(y)) * blur_size;
			color += texture(screen_texture, uv + offset);
			samples++;
		}
	}

	// 取平均值
	color /= float(samples);

	// 添加轻微的半透明深色遮罩，增加对比度
	vec3 tint = vec3(0.0, 0.0, 0.0);
	color.rgb = mix(color.rgb, tint, 0.25);

	COLOR = vec4(color.rgb, 1.0);
}
