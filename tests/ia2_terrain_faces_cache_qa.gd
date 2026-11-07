extends SceneTree

# Bake original terrain collision faces into a typed Godot Resource.
# The runtime flag remains OFF by default. No visual geometry is omitted.
func _initialize() -> void:
	_generate.call_deferred()

func _generate() -> void:
	var records: Array=[]
	var begin:=Time.get_ticks_usec()
	for iz in 15:
		for ix in 15:
			var corner:=Vector3(ix*WarFavelaMap.TILE-WarFavelaMap.HALF,0,iz*WarFavelaMap.TILE-WarFavelaMap.HALF)
			var vertices:=PackedVector3Array()
			for z in WarFavelaMap.GRID:
				for x in WarFavelaMap.GRID:
					var wx:=corner.x+x*WarFavelaMap.STEP
					var wz:=corner.z+z*WarFavelaMap.STEP
					vertices.append(Vector3(x*WarFavelaMap.STEP,WarFavelaMap.height_at(wx,wz),z*WarFavelaMap.STEP))
			var faces:=PackedVector3Array()
			for z in WarFavelaMap.GRID-1:
				for x in WarFavelaMap.GRID-1:
					var a:=z*WarFavelaMap.GRID+x
					var b:=a+1
					var c:=a+WarFavelaMap.GRID
					var e:=c+1
					for vertex in [a,c,b,b,c,e]:
						faces.append(vertices[vertex])
			records.append(faces)
	var signature: String=WarFavelaMap.ia2_housing_source_signature()
	var digest:=WarFavelaMap.ia2_terrain_digest(records)
	var pack:=Resource.new()
	pack.set_meta("version",1)
	pack.set_meta("signature",signature)
	pack.set_meta("digest",digest)
	pack.set_meta("faces",records)
	var status:=ResourceSaver.save(pack,WarFavelaMap.IA2_TERRAIN_FACES_RESOURCE)
	var restored: Resource=ResourceLoader.load(WarFavelaMap.IA2_TERRAIN_FACES_RESOURCE,"",ResourceLoader.CACHE_MODE_IGNORE)
	var content: Variant=restored.get_meta("faces",[]) if restored!=null else []
	var valid: bool=status==OK and not signature.is_empty() and restored!=null and content is Array and content.size()==225
	if valid:valid=WarFavelaMap.ia2_terrain_digest(content)==digest
	print("IA2_TERRAIN_FACES_BAKE ",JSON.stringify({
		"valid":valid,"resource":WarFavelaMap.IA2_TERRAIN_FACES_RESOURCE,
		"face_arrays":records.size(),"vertices_per_tile":2400,"signature":signature,
		"digest":digest,"save_status":status,
		"elapsed_ms":(Time.get_ticks_usec()-begin)*.001}))
	quit(0 if valid else 2)
