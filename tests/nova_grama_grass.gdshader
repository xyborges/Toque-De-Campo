shader_type spatial;
render_mode cull_disabled,diffuse_lambert_wrap;
varying vec3 tint;
void vertex(){
 vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
 float height=max(VERTEX.y,0.);
 VERTEX.x+=sin(TIME*1.15+world.x*.16+world.z*.11)*height*.10;
 VERTEX.z+=cos(TIME*.83+world.z*.12)*height*.05;
 NORMAL=normalize(vec3(NORMAL.x*.15,1.,NORMAL.z*.15));
 tint=COLOR.rgb;
}
void fragment(){ALBEDO=tint;ROUGHNESS=.98;SPECULAR=.08;}
