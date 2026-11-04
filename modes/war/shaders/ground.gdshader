shader_type spatial;
render_mode cull_back;
uniform sampler2D soil : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D variation : filter_linear_mipmap, repeat_enable;
uniform vec2 port_west;
uniform vec2 port_east;
uniform vec4 towns_a;
uniform vec4 towns_b;
varying vec3 ground_position;
varying vec3 ground_normal;
varying float impact_wear;
void vertex(){
 ground_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 ground_normal=normalize((MODEL_NORMAL_MATRIX*NORMAL));
 vec2 p=ground_position.xz;
 float port=max(1.0-smoothstep(80.,260.,length((p-port_west)/vec2(1.,1.2))),1.0-smoothstep(80.,260.,length((p-port_east)/vec2(1.,1.2))));
 float city=max(max(1.0-smoothstep(55.,170.,distance(p,towns_a.xy)),1.0-smoothstep(55.,170.,distance(p,towns_a.zw))),max(1.0-smoothstep(55.,170.,distance(p,towns_b.xy)),1.0-smoothstep(55.,170.,distance(p,towns_b.zw))));
 impact_wear=max(port,city*.72);
}
void fragment(){
 vec2 uv=ground_position.xz;
 float large=texture(variation,uv*.0029).r;
 float medium=texture(variation,uv*.027).r;
 float small=texture(variation,uv*.31).r;
 vec3 dirt=texture(soil,uv*.44).rgb;
 vec3 stones=texture(gravel,uv*.22).rgb;
 float slope=1.0-clamp(ground_normal.y,0.,1.);
 float road=1.0-smoothstep(4.,9.,abs(uv.y-25.*sin(uv.x*.009)));
 float rut=1.0-smoothstep(.16,.5,abs(abs(uv.y-25.*sin(uv.x*.009))-2.2));
 float wet=smoothstep(.48,.72,medium)*(1.-slope)*mix(.22,.9,road);
 vec3 base=mix(dirt*vec3(.48,.38,.28),stones*vec3(.48,.46,.42),clamp(road*.65+slope*1.4,0.,1.));
 base*=mix(.63,1.35,large)*mix(.83,1.13,small);
 base=mix(base,base*vec3(.30,.28,.25),wet*.62+rut*road*.35);
 float luminance=dot(base,vec3(.2126,.7152,.0722));
 base=mix(base,vec3(luminance),.62)*vec3(.86,.89,.88);
 float vegetation=smoothstep(290.,500.,abs(uv.y));
 float patches=smoothstep(.49,.69,medium)*(1.-road);
 float industrial=impact_wear;
 vegetation*=1.0-industrial*.94;
 patches*=1.0-industrial*.8;
 base=mix(base,base*vec3(.74,1.25,.63)+vec3(.012,.023,.004),clamp(vegetation*.72+patches*.18,0.,.85));
 base=mix(base,mix(dirt*vec3(.24,.23,.20),stones*vec3(.30,.29,.26),medium),industrial*(.42+.25*small));
 ALBEDO=base;
 float close_detail=1.0-smoothstep(90.,260.,length(VERTEX));
 if(close_detail>0.001){
  vec3 grain=texture(soil_normal,uv*.65).rgb*2.0-1.0;
  NORMAL=normalize(NORMAL+(VIEW_MATRIX*vec4(grain.x*.28,0.,grain.y*.28,0.)).xyz*close_detail);
 }
 ROUGHNESS=mix(.99,.58,wet);
 SPECULAR=mix(.12,.25,wet);
}
