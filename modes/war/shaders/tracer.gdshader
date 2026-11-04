shader_type spatial;
render_mode unshaded,blend_add,depth_draw_never,cull_disabled;
uniform float brightness = 1.09;
varying vec4 shade;
void vertex(){shade=COLOR;}
void fragment(){
 float edge=1.0-smoothstep(0.12,0.5,abs(UV.x-0.5));
 float tip=smoothstep(0.0,0.12,UV.y)*(1.0-smoothstep(0.82,1.0,UV.y));
 ALBEDO=shade.rgb;
 EMISSION=shade.rgb*2.0*brightness;
 ALPHA=edge*tip*shade.a;
}
