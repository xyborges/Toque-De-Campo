shader_type spatial;
render_mode unshaded,depth_draw_never,cull_back;
varying vec4 tone;
void vertex(){
 tone=COLOR;
 vec3 scale=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
 mat4 billboard=mat4(vec4(INV_VIEW_MATRIX[0].xyz*scale.x,0.0),vec4(INV_VIEW_MATRIX[1].xyz*scale.y,0.0),vec4(INV_VIEW_MATRIX[2].xyz*scale.z,0.0),MODEL_MATRIX[3]);
 MODELVIEW_MATRIX=VIEW_MATRIX*billboard;
}
void fragment(){
 vec2 p=UV*2.0-1.0;float radius2=dot(p,p);
 if(radius2>=1.0) discard;
 ALBEDO=tone.rgb;ALPHA=tone.a*pow(1.0-radius2,1.6);
}
