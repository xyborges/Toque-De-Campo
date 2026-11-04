shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform sampler2D cloud_noise : repeat_enable, filter_linear_mipmap;
uniform float ocean_time=0.;
uniform float daylight=1.;
void fragment(){
 float value=texture(cloud_noise,UV*3.+vec2(ocean_time*.000012,0.)).r;
 float shape=smoothstep(.53,.76,value);
 ALBEDO=mix(vec3(.12,.17,.24),vec3(.75,.72,.67),daylight);
 ALPHA=shape*.28;
}
