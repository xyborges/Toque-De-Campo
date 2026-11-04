shader_type spatial;
render_mode unshaded, fog_disabled;
uniform float heat = 0.85;
uniform float reach = 2300.0;
uniform bool active = false;
void fragment(){
 if(!active) discard;
 float distance_fade=1.0-smoothstep(reach*0.75,reach,length(VERTEX));
 ALBEDO=vec3(mix(0.2,0.98,heat)*distance_fade);
 EMISSION=ALBEDO*0.2;
 ROUGHNESS=1.0;
}
