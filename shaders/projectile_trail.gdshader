shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled,depth_draw_never;
uniform vec4 tint:source_color=vec4(1.0);
uniform float energy=0.25;
void fragment(){
 float edge=1.0-smoothstep(0.04,0.5,abs(UV.x-0.5));
 float tail=smoothstep(0.0,0.18,UV.y)*(1.0-smoothstep(0.88,1.0,UV.y));
 ALBEDO=tint.rgb; EMISSION=tint.rgb*energy; ALPHA=tint.a*edge*tail;
}
