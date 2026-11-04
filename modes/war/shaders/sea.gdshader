shader_type spatial;
render_mode cull_disabled;
uniform float ocean_time=0.;
uniform float storm=0.;
uniform float daylight=1.;
varying vec3 world_point;
void vertex(){
 vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
 float a=p.x*.025+ocean_time*.85;float b=p.z*.037-ocean_time*.65;
 float amplitude=1.+storm*2.2;
 VERTEX.y=(sin(a)*.22+sin(b)*.11)*amplitude;
 NORMAL=normalize(vec3(-cos(a)*.0055*amplitude,1.,-cos(b)*.00407*amplitude));world_point=p;
}
void fragment(){
 float ripple=sin(world_point.x*.34+world_point.z*.16+ocean_time*1.1);
 float ripple2=cos(world_point.z*.39-world_point.x*.12-ocean_time*.9);
 NORMAL_MAP=vec3(.5+ripple*.025,.5+ripple2*.025,1.);NORMAL_MAP_DEPTH=.4+storm*.25;
 float fresnel=pow(1.-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.,1.),3.);
 vec3 base=mix(vec3(.025,.14,.19),vec3(.17,.29,.32),fresnel*.65);
 float crest=smoothstep(.87,1.,ripple*ripple2)*storm*.33;
 ALBEDO=mix(base,vec3(.56,.63,.64),crest)*(.42+.58*daylight);
 ROUGHNESS=.29+storm*.16;METALLIC=.08;SPECULAR=.8;
}
