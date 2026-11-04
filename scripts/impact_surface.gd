extends RefCounted
class_name GameImpactSurface
const SOUNDS:=["earth","mud","concrete","metal","wood","vehicle","water"]
static func detect(hit: Dictionary,mode: String) -> String:
	if bool(hit.get("water",false)): return "water"
	var body:=hit.get("collider") as Node
	if not is_instance_valid(body): return "earth"
	if body is WarVehicle or body is NavalShip: return "vehicle"
	var tag:=str(body.get_meta("surface",""))
	if body is CollisionObject3D and hit.has("shape"):
		var owner:=body.shape_owner_get_owner(body.shape_find_owner(int(hit.shape))) as Node
		if is_instance_valid(owner): tag=str(owner.get_meta("surface",tag))
	if tag in SOUNDS: return tag
	if tag in ["steel","screen"]: return "metal"
	if tag in ["cardboard","fabric"]: return "wood"
	if tag in ["rock","plaster","asphalt","brick","floor"]: return "concrete"
	if tag=="sand": return "earth"
	var label:=str(body.name).to_lower()
	if "terrain" in label or "ground" in label: return "mud" if mode=="war" else "earth"
	if "wood" in label or "crate" in label or "tree" in label: return "wood"
	if "steel" in label or "metal" in label: return "metal"
	return "concrete"
