shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
uniform vec3 viewer_position=vec3(0.0);
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	float distance_to=distance(world_position.xz,viewer_position.xz);
	float near_fade=1.0-smoothstep(30.0,105.0,distance_to);
	float vertical=(1.0-smoothstep(0.45,1.0,UV.y))*smoothstep(0.0,0.07,UV.y);
	float bands=0.5+0.5*sin(world_position.y*2.1+TIME*1.7);
	ALBEDO=vec3(0.34,0.64,0.92);
	ALPHA=(0.12+bands*0.17)*vertical*near_fade;
}
