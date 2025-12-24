shader_type canvas_item;

uniform float transition_progress : hint_range(0.0, 1.0) = 0.0;
uniform float edge_sharpness : hint_range(0.1, 10.0) = 5.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    // 从下到上的过渡
    float y_from_bottom = 1.0 - UV.y;
    float transition_line = transition_progress;

    // 使用smoothstep创建平滑过渡
    float alpha_mask = smoothstep(
        transition_line - (0.1 / edge_sharpness),
        transition_line + (0.1 / edge_sharpness),
        y_from_bottom
    );

    // 直接应用透明度遮罩
    COLOR = tex;
    COLOR.a *= alpha_mask;  // 线以下部分透明，线以上部分保持原样
}