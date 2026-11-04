shader_type spatial;
render_mode cull_disabled;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 float ripple=sin(world.x*3.1+world.z*2.4+TIME*1.4)*sin(world.z*4.2-TIME*1.1);
 ALBEDO=vec3(.13,.24,.24)+ripple*.013;
 ROUGHNESS=.33;METALLIC=.05;SPECULAR=.5;
 NORMAL=normalize(NORMAL+vec3(ripple*.025,0.,cos(world.z*3.+TIME)*.025));
}
