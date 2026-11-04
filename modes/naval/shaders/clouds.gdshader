shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform sampler2D cloud_noise : repeat_enable, filter_linear_mipmap;
uniform float ocean_time = 0.0;
uniform float daylight = 1.0;
void fragment() {
 float value=texture(cloud_noise,UV*3.0+vec2(ocean_time*.000012,0.0)).r;
 float shape=smoothstep(.42,.68,value);
 ALBEDO=mix(vec3(.18,.24,.31),vec3(.83,.85,.82),daylight);
 ALPHA=shape*.62;
}
