shader_type spatial;
render_mode unshaded;
varying vec4 tint;
void vertex(){tint=COLOR;}
void fragment(){ALBEDO=tint.rgb;EMISSION=tint.rgb*0.6;}
