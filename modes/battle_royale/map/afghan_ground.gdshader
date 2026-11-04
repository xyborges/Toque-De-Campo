shader_type spatial;
render_mode cull_back;
uniform sampler2D sand : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D biome_mask : filter_linear_mipmap, repeat_disable;
uniform sampler2D agriculture : source_color, filter_linear, repeat_disable;
uniform sampler2D baked_color : source_color, filter_linear_mipmap, repeat_disable;
uniform bool baked_enabled=false;
uniform bool rural_detail_enabled=true;
varying vec3 p;
varying vec3 n;
float hash2(vec2 x){return fract(sin(dot(x,vec2(127.1,311.7)))*43758.5453);}
vec3 untile(sampler2D tex,vec2 uv){
 vec2 cell=floor(uv*.10);vec2 local=fract(uv*.10);
 vec2 next=cell+vec2(1.);
 float a=hash2(cell),b=hash2(next);
 float blend=smoothstep(.2,.8,fract((local.x+local.y)*.5));
 return mix(texture(tex,uv+vec2(a,a*.73)*17.).rgb,texture(tex,uv+vec2(b,b*.73)*17.).rgb,blend);
}
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;n=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
	float far_mix=baked_enabled?smoothstep(90.,180.,length(VERTEX)):0.;
	vec3 prepared=vec3(0.);
	if(far_mix>0.){prepared=texture(baked_color,(p.xz+vec2(1000.))/2000.).rgb;}
	if(far_mix>=1.){ALBEDO=prepared;ROUGHNESS=.97;SPECULAR=.11;}else{
 // Irrational scale/rotation pairs break the old obvious tiled stripes.
 vec2 uv=p.xz;
 mat2 spin=mat2(vec2(.8,.6),vec2(-.6,.8));
 vec3 s=untile(sand,uv*.13)*.58+texture(sand,spin*uv*.031+vec2(.37,.71)).rgb*.42;
 vec3 r=untile(gravel,uv*.16)*.63+texture(gravel,spin*uv*.021).rgb*.37;
 vec3 stone=texture(rock,uv*.095).rgb;
 if(n.y<.88){vec2 weights=abs(n.xz);weights/=max(.01,weights.x+weights.y);stone=texture(rock,p.zy*.10).rgb*weights.x+texture(rock,p.xy*.10).rgb*weights.y;}
 float broad=.5+.19*sin(p.x*.005+p.z*.002)+.16*cos(p.z*.008-p.x*.003)+.08*sin(p.z*.029+p.x*.017);
 float slope=1.-clamp(n.y,0.,1.);
 vec4 biome=texture(biome_mask,(uv+vec2(1000.))/2000.);
 vec3 c=mix(s*vec3(.60,.59,.55),r*vec3(.70,.69,.64),.88);
 c=mix(c,stone*vec3(.57,.55,.50),smoothstep(.08,.32,slope));
 float luma=dot(c,vec3(.2126,.7152,.0722));c=mix(c,vec3(luma),.23);
 c*=mix(.77,1.13,clamp(broad,0.,1.));
 c=mix(c,c*vec3(.74,.84,.66),biome.g*.40);
 c=mix(c,c*vec3(.63,.60,.55),biome.r*.24);
 float crack=smoothstep(.79,.94,abs(sin(p.x*.76+sin(p.z*.63))*sin(p.z*.59)));
 c=mix(c,mix(r*vec3(.59,.57,.52),c*.47,crack*.36),biome.b*.34);
 c=mix(c,c*vec3(.91,.89,.83),biome.a*.3);
 float strata=.94+.06*sin(p.y*1.35+sin(p.x*.15+p.z*.12));c*=mix(1.,strata,smoothstep(.1,.35,slope));
 vec4 farm=texture(agriculture,(p.xz+vec2(1000.))/2000.);
 float crop_detail=.82+.36*texture(gravel,uv*.21).r;
 float rows=.94+.06*sin(p.x*2.1+sin(p.z*.05));
 c=mix(c,farm.rgb*crop_detail*rows*mix(.90,1.08,clamp(broad,0.,1.)),farm.a);
 ROUGHNESS=rural_detail_enabled?.99:.97;SPECULAR=rural_detail_enabled?.055:.11;
 float close=1.-smoothstep(22.,90.,length(VERTEX));
 vec3 detail=texture(soil_normal,p.xz*.17).rgb*2.-1.;
 if(rural_detail_enabled){c*=1.+(detail.x*.07+detail.y*.055)*close*(1.-farm.a*.4);}
 ALBEDO=mix(c,prepared,far_mix);
 float strength=rural_detail_enabled?.060:.035;
 NORMAL=normalize(NORMAL+(VIEW_MATRIX*vec4(detail.x*strength,0.,detail.y*strength,0.)).xyz*close);
 }
}

