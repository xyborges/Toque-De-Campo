extends RefCounted
class_name WarArtStyle

# Shared physical finishes. No emission on opaque equipment; highlights come
# from broad bevels, roughness and lighting instead of painted bright edges.
const FINISHES:={
	"paint":["steel","8a977c",.12,.79],
	"dark_paint":["steel","4c5c4b",.10,.80],
	"bare_metal":["steel","70776d",.75,.52],
	"gunmetal":["steel","353d3a",.72,.51],
	"polymer":["fabric","252e29",.0,.84],
	"rubber":["fabric","202622",.0,.96],
	"webbing":["fabric","6a7051",.0,.94],
	"wood":["wood","776951",.0,.92],
	"concrete":["concrete","92978c",.0,.96],
	"plaster":["plaster","a5a69a",.0,.96],
	"brick":["brick","95816b",.0,.96],
	"asphalt":["asphalt","535a54",.0,.97],
	"earth":["sand","6b6250",.0,.99],
	"bark":["wood","666553",.0,.99],
	"charcoal":["wood","343932",.0,.99],
	"leaf":["fabric","566343",.0,.95],
	"marking":["plaster","c2bd9e",.0,.96],
	"rust":["steel","796147",.18,.94],
	"recess":["steel","131b18",.18,.80]
}
static var cache: Dictionary={}
static func material(id: String) -> StandardMaterial3D:
	if cache.has(id): return cache[id]
	var entry: Array=FINISHES[id]
	var mat:=EnvironmentKit.material(str(entry[0])+":"+str(entry[1])).duplicate() as StandardMaterial3D
	mat.resource_name=id
	mat.metallic=float(entry[2]);mat.roughness=float(entry[3]);mat.metallic_specular=.35
	mat.normal_scale=.20 if id in ["gunmetal","bare_metal","paint","dark_paint"] else .45
	mat.uv1_world_triplanar=false
	mat.uv1_scale=Vector3.ONE*(8. if id in ["gunmetal","polymer"] else .65)
	cache[id]=mat
	return mat

static func mesh(parent: Node3D,label: String,shape: Mesh,finish: String,position:=Vector3.ZERO,basis:=Basis.IDENTITY) -> MeshInstance3D:
	var node:=MeshInstance3D.new();node.name=label;node.mesh=shape;node.material_override=material(finish)
	node.transform=Transform3D(basis,position);parent.add_child(node)
	return node
