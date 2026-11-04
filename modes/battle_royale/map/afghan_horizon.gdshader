shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform float daylight=1.0;
varying vec3 world;
varying vec3 face_normal;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;face_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 float ring=clamp((max(abs(world.x),abs(world.z))-1000.0)/1750.0,0.0,1.0);
 // Atmospheric layers are applied to the existing horizon mesh, no extra
 // mountains, transparency layers or additional draw calls.
 vec3 near_tone=vec3(.45,.43,.38);
 vec3 far_tone=vec3(.57,.63,.69);
 vec3 rock=mix(near_tone,far_tone,smoothstep(0.,1.,ring));
 rock*=.91+.09*sin(world.x*.007+world.z*.005);
 rock*=.86+.14*clamp(dot(normalize(face_normal),normalize(vec3(.4,.8,.3))),0.,1.);
 float haze=smoothstep(650.,3300.,length(world.xz-INV_VIEW_MATRIX[3].xz));
 rock=mix(rock,vec3(.65,.67,.69),haze*.65);
 ALBEDO=rock*mix(vec3(.25,.32,.43),vec3(1.),daylight);
}
