from pathlib import Path
import json,struct
p=Path(r"C:\\Users\\Joao Borges\\Documents\\campo-cartunesco-godot\\campo-cartunesco-godot\\assets\\weapons\\sniper.glb")
out=p.with_name('sniper_iron.glb')
b=p.read_bytes()
jlen,_=struct.unpack_from('<II',b,12)
doc=json.loads(b[20:20+jlen].decode())
bin_offset=20+jlen
blen,_=struct.unpack_from('<II',b,bin_offset)
body=bytearray(b[bin_offset+8:bin_offset+8+blen])
primitive=doc['meshes'][0]['primitives'][0]
def accessor(a):
 a=doc['accessors'][a];v=doc['bufferViews'][a['bufferView']]
 step=v.get('byteStride',{'VEC3':12,'SCALAR':4}[a['type']])
 comp={5126:'f',5125:'I'}[a['componentType']]
 count={'VEC3':3,'SCALAR':1}[a['type']]
 return [struct.unpack_from('<'+comp*count,body,v['byteOffset']+a.get('byteOffset',0)+i*step) for i in range(a['count'])]
positions=accessor(primitive['attributes']['POSITION'])
indices=[n[0] for n in accessor(primitive['indices'])]
keep=[]
rejected=0
for n in range(0,len(indices),3):
 tri=indices[n:n+3]
 xyz=[positions[i] for i in tri]
 cx=sum(q[0] for q in xyz)/3
 cy=sum(q[1] for q in xyz)/3
 # The old non-modular scope assembly is above the receiver and mid-barrel.
 # Do not alter any of the gun barrel, stock, bipod or lower receiver faces.
 scope=(-.315<=cx<=.205 and cy>.075)
 if scope:rejected+=1
 else:keep.extend(tri)
v=doc['bufferViews'][primitive['indices'] and doc['accessors'][primitive['indices']]['bufferView']]
off=v['byteOffset']
for i,val in enumerate(keep):struct.pack_into('<I',body,off+i*4,val)
# zero dead indices for deterministic output
for i in range(off+4*len(keep),off+4*len(indices)):body[i]=0
doc['accessors'][primitive['indices']]['count']=len(keep)
doc['accessors'][primitive['indices']]['min']=[min(keep)]
doc['accessors'][primitive['indices']]['max']=[max(keep)]
v['byteLength']=len(keep)*4
txt=json.dumps(doc,separators=(',',':'),ensure_ascii=False).encode('utf8')
txt+=b' '*((-len(txt))%4)
total=12+8+len(txt)+8+len(body)
out.write_bytes(struct.pack('<4sII',b'glTF',2,total)+struct.pack('<II',len(txt),0x4e4f534a)+txt+struct.pack('<II',len(body),0x004e4942)+body)
print('sniper scope-only variant',len(indices)//3,'original faces',rejected,'deleted',len(keep)//3,'remaining',out.stat().st_size,'bytes')
