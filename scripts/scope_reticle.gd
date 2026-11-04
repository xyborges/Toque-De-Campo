extends RefCounted
class_name GameScopeReticle

const MRAD:=.001

static func pixels_per_mrad(height: float,vertical_fov: float) -> float:
	return maxf(1,height)*tan(MRAD)/(2.0*tan(deg_to_rad(clampf(vertical_fov,1,150))*.5))

static func configure(material: ShaderMaterial,size: Vector2,vertical_fov: float) -> void:
	material.set_shader_parameter("aspect",size.x/maxf(1,size.y))
	material.set_shader_parameter("pixel_size",1.0/maxf(1,size.y))
	material.set_shader_parameter("mrad_spacing",pixels_per_mrad(size.y,vertical_fov)/maxf(1,size.y))
