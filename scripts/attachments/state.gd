extends RefCounted
class_name GameAttachmentState

const MAX_MODULES:=16
const MAX_DEPTH:=4
const MAX_STATE_BYTES:=256

static func valid_state(id: String,raw: Variant) -> bool:
	var definition:=GameAttachmentRegistry.definition(id)
	if not definition or not raw is Dictionary or raw.size()>16 or var_to_bytes(raw).size()>MAX_STATE_BYTES:return false
	for key: Variant in raw:
		if not key is String or not definition.state_schema.get(key) is Dictionary:return false
		var rule: Dictionary=definition.state_schema[key];var value: Variant=raw[key];var kind:=str(rule.get("type","bool"))
		if kind=="bool":
			if not value is bool:return false
		elif kind in ["int","float"]:
			if not (value is int or value is float) or not is_finite(float(value)):return false
			if kind=="int" and float(value)!=floorf(float(value)):return false
			if float(value)<float(rule.get("min",-1000000.)) or float(value)>float(rule.get("max",1000000.)):return false
		elif kind=="enum":
			if not value is String or value not in rule.get("values",[]):return false
		else:return false
	return true

static func stateclean(id: String,raw: Dictionary) -> Dictionary:
	var definition:=GameAttachmentRegistry.definition(id);var result: Dictionary={}
	if not definition:return result
	for key: String in definition.state_schema:
		var rule: Dictionary=definition.state_schema[key]
		var value: Variant=raw.get(key,rule.get("default",false if str(rule.get("type","bool"))=="bool" else 0))
		if str(rule.get("type",""))=="int":value=int(value)
		elif str(rule.get("type",""))=="float":value=float(value)
		result[key]=value
	return result

static func _base_path(path: String) -> String:
	var pieces:=path.rsplit("/",true,1);var leaf:=str(pieces[-1]).split("@",true,1)[0]
	return str(pieces[0])+"/"+leaf if pieces.size()>1 else leaf

static func sockets(weapon: String,configuration: Dictionary={}) -> Dictionary:
	var result: Dictionary={};var profile:=GameAttachmentRegistry.profile(weapon)
	if not profile:return result
	for value: Resource in profile.sockets:
		var socket:=value as GameAttachmentSocket
		if socket and not socket.id.is_empty():result[socket.id]=socket
	var keys:=configuration.keys();keys.sort_custom(func(a,b):return str(a).count("/")<str(b).count("/"))
	for path: Variant in keys:
		if not path is String or not configuration[path] is Dictionary or not result.has(_base_path(path)):continue
		var definition:=GameAttachmentRegistry.definition(str(configuration[path].get("id","")))
		if not definition:continue
		for value: Resource in definition.provided_sockets:
			var socket:=value as GameAttachmentSocket
			if socket and not socket.id.is_empty() and not "/" in socket.id and not "@" in socket.id:result[path+"/"+socket.id]=socket
	return result

static func from_legacy(weapon: String,id: String) -> Dictionary:
	var resolved:=GameAttachmentRegistry.resolve_legacy(id,weapon)
	if resolved.is_empty():return {}
	for path: String in sockets(weapon):
		if can_install(weapon,{},path,resolved).get("ok",false):return {path:{"id":resolved,"state":{},"position":0.}}
	return {}

static func normalize(weapon: String,raw: Variant) -> Dictionary:
	if raw is String:return from_legacy(weapon,raw)
	if not raw is Dictionary:return {}
	var result: Dictionary={}
	for path: Variant in raw:
		if not path is String or path.length()>192:return {}
		var value: Variant=raw[path]
		if value is String:value={"id":str(value),"state":{},"position":0.}
		if not value is Dictionary:return {}
		if not value.get("state",{}) is Dictionary or not (value.get("position",0.) is float or value.get("position",0.) is int):return {}
		result[path]={"id":str(value.get("id","")),"state":Dictionary(value.get("state",{})).duplicate(true),"position":float(value.get("position",0.))}
	return result

static func _fit(weapon: String,configuration: Dictionary,path: String,id: String,position: float) -> Dictionary:
	var profile:=GameAttachmentRegistry.profile(weapon);var definition:=GameAttachmentRegistry.definition(id)
	var known:=sockets(weapon,configuration);var socket:=known.get(_base_path(path)) as GameAttachmentSocket
	if not profile or not definition or not socket:return {"ok":false,"reason":"socket"}
	if path.count("/")+1>MAX_DEPTH or configuration.size()>MAX_MODULES:return {"ok":false,"reason":"depth"}
	if definition.category not in socket.categories:return {"ok":false,"reason":"category"}
	var interface_ok:=false
	for interface_id: String in definition.required_interfaces:
		if interface_id in socket.interfaces:interface_ok=true;break
	if not interface_ok:return {"ok":false,"reason":"interface"}
	for tag: String in definition.required_weapon_tags:
		if tag not in profile.tags:return {"ok":false,"reason":"weapon_tags"}
	for tag: String in socket.required_tags:
		if tag not in definition.tags:return {"ok":false,"reason":"module_tags"}
	for tag: String in socket.denied_tags:
		if tag in definition.tags:return {"ok":false,"reason":"module_tags"}
	if not definition.required_space.is_finite() or definition.required_space.x>socket.available_space.x+.0001 or definition.required_space.y>socket.available_space.y+.0001 or definition.required_space.z>socket.available_space.z+.0001:return {"ok":false,"reason":"space"}
	if not is_finite(position):return {"ok":false,"reason":"position"}
	if not socket.allow_multiple and absf(position)>.0001:return {"ok":false,"reason":"position"}
	if socket.allow_multiple and (socket.rail_length<=0 or absf(position)+definition.required_space.z*.5>socket.rail_length*.5+.0001):return {"ok":false,"reason":"space"}
	var ancestor:=path
	while "/" in ancestor:
		ancestor=ancestor.rsplit("/",true,1)[0]
		if str(configuration.get(ancestor,{}).get("id",""))==id:return {"ok":false,"reason":"cycle"}
	for other_path: String in configuration:
		if other_path==path:continue
		var other:=GameAttachmentRegistry.definition(str(configuration[other_path].get("id","")))
		if not other:continue
		for tag: String in definition.conflict_tags:
			if tag in other.tags:return {"ok":false,"reason":"conflict"}
		for tag: String in other.conflict_tags:
			if tag in definition.tags:return {"ok":false,"reason":"conflict"}
		if _base_path(other_path)==_base_path(path):
			if not socket.allow_multiple:return {"ok":false,"reason":"occupied"}
			if absf(float(configuration[other_path].get("position",0.))-position)<(definition.required_space.z+other.required_space.z)*.5-.0001:return {"ok":false,"reason":"occupied"}
	return {"ok":true,"socket":path}

static func validate(weapon: String,raw: Variant) -> Dictionary:
	if not raw is Dictionary or raw.size()>MAX_MODULES:return {"ok":false,"reason":"size","state":{}}
	for value: Variant in raw.values():
		if not value is Dictionary and not value is String:return {"ok":false,"reason":"format","state":{}}
		if value is Dictionary and (not valid_state(str(value.get("id","")),value.get("state",{}))):return {"ok":false,"reason":"state","state":{}}
	var configuration:=normalize(weapon,raw)
	if configuration.size()!=raw.size():return {"ok":false,"reason":"format","state":{}}
	for path: String in configuration:
		var leaf:=str(path.rsplit("/",true,1)[-1]);var base:=_base_path(path)
		if path.begins_with("/") or path.ends_with("/") or "//" in path or path.count("/")+1>MAX_DEPTH:return {"ok":false,"reason":"path","state":{}}
		if "@" in leaf:
			var available:=sockets(weapon,configuration);var target:=available.get(base) as GameAttachmentSocket
			if not target or not target.allow_multiple:return {"ok":false,"reason":"path","state":{}}
		var entry: Dictionary=configuration[path]
		if not valid_state(str(entry.id),entry.state):return {"ok":false,"reason":"state","state":{}}
		var fit:=_fit(weapon,configuration,path,str(entry.id),float(entry.position))
		if not fit.get("ok",false):return {"ok":false,"reason":fit.reason,"state":{}}
		entry.state=stateclean(str(entry.id),entry.state)
	return {"ok":true,"state":configuration}

static func can_install(weapon: String,configuration: Dictionary,path: String,id: String,position:=0.) -> Dictionary:
	return install(weapon,configuration,path,id,{},position,true)

static func install(weapon: String,raw: Dictionary,path: String,id: String,individual_state: Dictionary={},position:=0.,dry_run:=false) -> Dictionary:
	var current:=validate(weapon,raw)
	if not current.get("ok",false):return current
	if not valid_state(id,individual_state):return {"ok":false,"reason":"state"}
	var configuration: Dictionary=current.state
	var known:=sockets(weapon,configuration);var socket:=known.get(_base_path(path)) as GameAttachmentSocket
	if not socket:return {"ok":false,"reason":"socket"}
	if path.begins_with("/") or path.ends_with("/") or "//" in path or ("@" in str(path.rsplit("/",true,1)[-1]) and not socket.allow_multiple):return {"ok":false,"reason":"path"}
	if socket.allow_multiple and not "@" in str(path.rsplit("/",true,1)[-1]):path+="@"+str(roundi(position*10000.))
	var removal:=remove(weapon,configuration,path)
	configuration=removal.state
	if configuration.size()>=MAX_MODULES:return {"ok":false,"reason":"size"}
	var fit:=_fit(weapon,configuration,path,id,position)
	if not fit.get("ok",false):return fit
	if not dry_run:configuration[path]={"id":id,"state":stateclean(id,individual_state),"position":position}
	return {"ok":true,"state":configuration,"removed":removal.removed,"socket":path}

static func remove(_weapon: String,raw: Dictionary,path: String) -> Dictionary:
	var configuration:=raw.duplicate(true);var removed: Array[Dictionary]=[]
	var keys:=configuration.keys();keys.sort_custom(func(a,b):return str(a).count("/")>str(b).count("/"))
	for key: String in keys:
		if key==path or key.begins_with(path+"/"):
			var item: Dictionary=configuration[key].duplicate(true);item.socket=key;removed.append(item);configuration.erase(key)
	return {"ok":true,"state":configuration,"removed":removed}

static func effective(base: Dictionary,weapon: String,raw: Dictionary) -> Dictionary:
	var result:=base.duplicate(true);var validated:=validate(weapon,raw)
	if not validated.get("ok",false):return result
	var flat: Dictionary={};var percent: Dictionary={};var overrides: Dictionary={}
	var paths: Array=validated.state.keys();paths.sort()
	for path: String in paths:
		var definition:=GameAttachmentRegistry.definition(str(validated.state[path].id))
		for key: String in definition.modifiers_flat:flat[key]=float(flat.get(key,0.))+float(definition.modifiers_flat[key])
		for key: String in definition.modifiers_percent:percent[key]=float(percent.get(key,0.))+float(definition.modifiers_percent[key])
		overrides.merge(definition.modifiers_override,true)
	for key: String in base:
		if base[key] is int or base[key] is float:
			var value:=(float(base[key])+float(flat.get(key,0.)))*(1.+float(percent.get(key,0.)))
			if is_finite(value):result[key]=value
	for key: String in overrides:
		if base.has(key):result[key]=overrides[key]
	return result

static func legacy_optic(weapon: String,raw: Dictionary) -> String:
	var validated:=validate(weapon,raw)
	if not validated.get("ok",false):return ""
	var keys: Array=validated.state.keys();keys.sort()
	for path: String in keys:
		var definition:=GameAttachmentRegistry.definition(str(validated.state[path].id))
		if definition.behavior_type=="optical":return definition.id
	return ""
static func legacy_optics(weapon: String,raw: Dictionary) -> String:return legacy_optic(weapon,raw)

static func socket_records(weapon: String,configuration: Dictionary={}) -> Dictionary:
	var result: Dictionary={}
	var available:=sockets(weapon,configuration)
	for path: String in available:
		var socket: GameAttachmentSocket=available[path]
		result[path]={"label":socket.ui_label,"category":str(socket.categories[0]) if not socket.categories.is_empty() else "","categories":Array(socket.categories),"interfaces":Array(socket.interfaces),"ui_position":socket.ui_position,"occupied":configuration.get(path,{}),"multiple":socket.allow_multiple}
	return result
