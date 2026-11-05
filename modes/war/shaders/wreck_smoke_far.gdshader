shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Far-field tank smoke uses one MultiMesh, three quads per wreck and no textures.
// Fragment work stays tiny at 1–6.5 km; avoid expensive volumetric ray marching.
varying vec4 smoke_tone;
varying float noise_seed;

void vertex() {
    smoke_tone = COLOR;
    noise_seed = INSTANCE_CUSTOM.r;
    vec3 scale = vec3(length(MODEL_MATRIX[0].xyz),
        length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
    mat4 billboard = mat4(
        vec4(INV_VIEW_MATRIX[0].xyz * scale.x, 0.0),
        vec4(INV_VIEW_MATRIX[1].xyz * scale.y, 0.0),
        vec4(INV_VIEW_MATRIX[2].xyz * scale.z, 0.0),
        MODEL_MATRIX[3]);
    MODELVIEW_MATRIX = VIEW_MATRIX * billboard;
}

void fragment() {
    vec2 uv = UV;
    float height = uv.y;
    float side = abs(uv.x * 2.0 - 1.0);
    float drift = TIME * 0.055 + noise_seed * 6.28318;
    float eddy = sin(height * 17.0 + drift + noise_seed * 11.0) * 0.065;
    eddy += sin(height * 31.0 - drift * 1.6 + uv.x * 11.0) * 0.040;
    float width = mix(0.63, 0.96, smoothstep(0.12, 0.75, height));
    float silhouette = 1.0 - smoothstep(width - 0.25, width + 0.06, side + eddy);
    float cap = smoothstep(0.005, 0.17, height) * (1.0 - smoothstep(0.87, 1.0, height));
    float turbulence = 0.81 + 0.11 * sin(uv.x * 14.0 + height * 25.0 + drift);
    turbulence += 0.08 * sin(uv.x * 25.0 - height * 15.0 - drift * 1.8);
    float alpha = smoke_tone.a * silhouette * cap * turbulence;
    if (alpha < 0.016) discard;
    ALBEDO = smoke_tone.rgb * (0.9 + turbulence * 0.14);
    ALPHA = alpha;
}
