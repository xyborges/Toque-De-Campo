shader_type spatial;
render_mode cull_disabled;
uniform float ocean_time = 0.0;
uniform float daylight = 1.0;
uniform vec4 islands[5];
varying vec3 ocean_position;
void vertex() {
 vec3 p = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
 float a=p.x*0.025+ocean_time*0.85;
 float b=p.z*0.037-ocean_time*0.65;
 // Exactly the existing authoritative wave; no extra vertical animation.
 VERTEX.y=sin(a)*0.22+sin(b)*0.11;
 NORMAL=normalize(vec3(-cos(a)*0.0055,1.0,-cos(b)*0.00407));
 ocean_position=p;
}
void fragment() {
 float shore=10000.0;
 for(int i=0;i<5;i++) {
   vec2 offset=ocean_position.xz-islands[i].xy;
   float angle=atan(offset.y,offset.x);
   float radius=islands[i].z*(0.91+sin(angle*5.0+float(i))*0.035+cos(angle*3.0-float(i))*0.035);
   shore=min(shore,abs(length(offset)-radius));
 }
 float near_shore=1.0-smoothstep(2.0,34.0,shore);
 float warp=sin(ocean_position.x*.021+ocean_position.z*.013)*1.6;
 float ripple_x=sin(ocean_position.x*.33+ocean_position.z*.17+ocean_time*1.1+warp)+.35*sin(ocean_position.z*.51-ocean_time);
 float ripple_y=cos(ocean_position.z*.39-ocean_position.x*.12-ocean_time*.8+warp)+.3*cos(ocean_position.x*.67+ocean_time*.6);
 NORMAL_MAP=vec3(0.5+ripple_x*0.018,0.5+ripple_y*0.018,1.0);
 NORMAL_MAP_DEPTH=0.45;
 float fresnel=pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),3.0);
 vec3 depth_color=mix(vec3(0.021,0.13,0.18),vec3(0.10,0.28,0.27),near_shore);
 vec3 color=mix(depth_color,vec3(0.22,0.36,0.42),fresnel*0.45);
 float wash=sin(shore*1.1-ocean_time*1.35+ripple_x*.6)*.5+.5;
 float foam=(1.0-smoothstep(0.4,5.5,shore))*smoothstep(.55,.95,wash);
 ALBEDO=mix(color,vec3(.63,.72,.69),foam*.7)*(0.65+0.35*daylight);
 ROUGHNESS=mix(.24,.72,foam);
 METALLIC=.12;
 SPECULAR=.85;
}
