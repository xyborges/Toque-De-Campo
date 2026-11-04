shader_type spatial;
render_mode cull_back;

uniform sampler2D biome : filter_linear, repeat_disable;
uniform sampler2D soil : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D variation : filter_linear_mipmap, repeat_enable;
uniform float storm = 0.0;
varying vec3 world_point;
varying vec3 world_normal;

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec2 p = world_point.xz;
	vec3 map = texture(biome, clamp((p+vec2(1750.0))/3500.0,vec2(0.0),vec2(1.0))).rgb;
	vec4 d = vec4(distance(map,vec3(48.0,150.0,54.0)/255.0),distance(map,vec3(108.0,65.0,50.0)/255.0),distance(map,vec3(178.0,151.0,80.0)/255.0),distance(map,vec3(174.0,165.0,145.0)/255.0));
	vec4 w = exp(-d*d*40.0); w /= max(dot(w,vec4(1.0)),0.001);
	float large = texture(variation,p*0.003).r;
	float small = texture(variation,p*0.38).r;
	vec3 dirt = texture(soil,p*0.45).rgb;
	vec3 rock = texture(stone,p*0.24).rgb;
	vec3 road = texture(gravel,p*0.34).rgb;
	vec3 field = mix(dirt*vec3(0.25,0.40,0.17),vec3(0.095,0.14,0.055),0.35);
	field *= mix(0.78,1.2,small);
	vec3 ash = mix(dirt*vec3(0.22,0.18,0.15),rock*vec3(0.32,0.29,0.26),smoothstep(0.35,0.7,small));
	vec3 transition = mix(field,ash,0.57);
	vec3 trail = road*vec3(0.48,0.42,0.32);
	vec3 base = field*w.x + ash*w.y + transition*w.z + trail*w.w;
	float slope = 1.0 - clamp(world_normal.y,0.0,1.0);
	base = mix(base,rock*vec3(0.33,0.32,0.27),smoothstep(0.18,0.58,slope)*0.6);
	ALBEDO = base * mix(0.84,1.15,large) * (1.0-storm*0.12);
	float detail = 1.0-smoothstep(45.0,100.0,length(VERTEX));
	vec3 n = texture(soil_normal,p*0.72).rgb*2.0-1.0;
	NORMAL = normalize(NORMAL+(VIEW_MATRIX*vec4(n.x*0.24,0.0,n.y*0.24,0.0)).xyz*detail);
	ROUGHNESS = mix(0.98,0.74,storm);
	SPECULAR = 0.12;
}
