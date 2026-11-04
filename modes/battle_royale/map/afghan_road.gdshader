shader_type spatial;
render_mode cull_disabled;
uniform sampler2D soil : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_color : source_color, filter_linear_mipmap, repeat_disable;
uniform bool ground_ready=false;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 vec3 detail=texture(soil,world.xz*.21).rgb;
 float broad=.87+.09*sin(world.x*.037+world.z*.049)+.04*cos(world.z*.19-world.x*.11);
 float across=abs(UV.x-.5);
 float left=1.-smoothstep(.025,.065,abs(UV.x-.28));
 float right=1.-smoothstep(.025,.065,abs(UV.x-.72));
 float worn=(left+right)*(.55+.45*sin(UV.y*.12+sin(UV.y*.035)));
 float tread=.5+.5*sin(UV.y*9.+UV.x*4.);
 vec3 ground=ground_ready?texture(ground_color,(world.xz+vec2(1000.))/2000.).rgb:detail*vec3(.62,.59,.49);
 vec3 dry=mix(ground,detail*vec3(.56,.52,.43)*broad,.32);
 vec3 verge=ground;
 ALBEDO=mix(dry*(1.-worn*(.11+.055*tread)),verge,smoothstep(.30,.5,across));
 ROUGHNESS=1.;SPECULAR=.10;
 float near_detail=1.-smoothstep(15.,65.,length(VERTEX));
 NORMAL=normalize(NORMAL+vec3(worn*.035*sin(UV.y*9.),tread*.018,0.)*near_detail);
}
