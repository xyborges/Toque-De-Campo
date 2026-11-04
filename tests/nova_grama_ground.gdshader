shader_type spatial;
render_mode cull_back;
uniform sampler2D biome : filter_linear, repeat_disable;
uniform sampler2D soil : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D stone : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D gravel : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D soil_normal : hint_normal, filter_linear_mipmap, repeat_enable;
varying vec3 world_point;
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 vec2 p=world_point.xz;
 vec3 map=texture(biome,clamp((p+vec2(1750.))/3500.,vec2(0.),vec2(1.))).rgb;
 vec4 d=vec4(distance(map,vec3(48.,150.,54.)/255.),distance(map,vec3(108.,65.,50.)/255.),distance(map,vec3(178.,151.,80.)/255.),distance(map,vec3(174.,165.,145.)/255.));
 vec4 w=exp(-d*d*40.);w/=max(dot(w,vec4(1.)),.001);
 vec3 dirt=texture(soil,p*.30).rgb;
 vec3 rock=texture(stone,p*.21).rgb;
 vec3 gravel_col=texture(gravel,p*.33).rgb;
 vec3 field=dirt*vec3(.39,.66,.33)+vec3(.025,.045,.018);
 vec3 burnt=mix(dirt*vec3(.29,.24,.20),rock*vec3(.34,.31,.28),.35);
 vec3 transition=mix(field,burnt,.46);
 vec3 trail=gravel_col*vec3(.56,.52,.43);
 vec3 base=field*w.x+burnt*w.y+transition*w.z+trail*w.w;
 float variation=0.91+.09*sin(p.x*.014+sin(p.y*.008)*2.)*cos(p.y*.012);
 ALBEDO=base*variation;
 float detail=1.-smoothstep(55.,130.,length(VERTEX));
 vec3 normal_sample=texture(soil_normal,p*.65).rgb*2.-1.;
 NORMAL=normalize(NORMAL+(VIEW_MATRIX*vec4(normal_sample.x*.20,0.,normal_sample.y*.20,0.)).xyz*detail);
 ROUGHNESS=.96;SPECULAR=.12;
}
