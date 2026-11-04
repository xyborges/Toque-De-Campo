shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D optical_view : source_color, filter_linear, repeat_disable;
uniform bool live_view = false;
void fragment() {
	vec2 p = UV-vec2(0.5);
	float r=length(p);
	if (r>0.5) discard;
	vec3 scene=live_view?texture(optical_view,UV).rgb:vec3(.028,.065,.060);
	scene*=1.0-smoothstep(.38,.5,r)*.93;
	float x=1.-smoothstep(.0012,.003,abs(p.x));
	float y=1.-smoothstep(.0012,.003,abs(p.y));
	float horizontal=y*step(.032,abs(p.x))*step(abs(p.x),.36);
	float vertical=x*step(.030,abs(p.y))*step(abs(p.y),.38);
	float subtension=0.;
	for(int i=1;i<=5;i++){
		float v=float(i)*.042;
		subtension=max(subtension,(1.-smoothstep(.0015,.003,abs(p.y-v)))*step(abs(p.x),.016));
	}
	float reticle=max(max(horizontal,vertical),subtension);
	ALBEDO=mix(scene,vec3(.012,.013,.012),reticle);
}
