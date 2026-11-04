shader_type spatial;
render_mode cull_back;
varying vec3 world;
uniform vec3 soil : source_color=vec3(.22,.24,.12);
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 float detail=1.-smoothstep(30.,140.,length(VERTEX));
 float row=.5+.5*sin(world.x*4.4+sin(world.z*.013));
 float patch=.5+.5*sin(world.z*.32+sin(world.x*.21));
 ALBEDO=soil*mix(1.,mix(.88,1.08,row),detail)*mix(.94,1.06,patch);
 ROUGHNESS=1.;SPECULAR=.06;
}
