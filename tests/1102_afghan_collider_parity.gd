extends SceneTree
const MAP=preload("res://modes/battle_royale/map/afghan_map.gd")
func _initialize()->void:run.call_deferred()
func index(map:Node)->Dictionary:
 var out:Dictionary={}
 for n:CollisionShape3D in map.find_children("*","CollisionShape3D",true,false):
  if n.disabled or not n.shape:continue
  var p:=n.global_position
  var key:="%s|%.3f|%.3f|%.3f|%s"%[n.shape.get_class(),p.x,p.y,p.z,str(n.get_parent().get_meta("library_id",""))]
  out[key]=int(out.get(key,0))+1
 return out
func run()->void:
 var a:Node3D=MAP.new();a.render_visuals=false;root.add_child(a);a.build();await physics_frame
 var ai:=index(a);print("AUTH colliders=",ai.size());a.free();await process_frame
 var b:Node3D=MAP.new();b.render_visuals=true;root.add_child(b);b.build();await physics_frame
 var bi:=index(b);print("CLIENT colliders=",bi.size())
 var only_a:Array=[];var only_b:Array=[]
 for key in ai:
  if not bi.has(key) or ai[key]!=bi[key]:only_a.append({"key":key,"authority":ai[key],"client":bi.get(key,0)})
 for key in bi:
  if not ai.has(key):only_b.append({"key":key,"client":bi[key]})
 var result:Dictionary={"authority":ai.size(),"client":bi.size(),"authority_only":only_a,"client_only":only_b}
 NavalStorage.write_json("res://work/1102-afghan-collider-parity.json",result)
 print("PARITY authority_only=",only_a.size()," client_only=",only_b.size()," first=",only_a.slice(0,8));b.free();await process_frame;quit(0)
