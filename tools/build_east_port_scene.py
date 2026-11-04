"""Author an ordinary editable Godot scene; not executed by the game."""
from pathlib import Path
import math

ROOT=Path(__file__).resolve().parents[1]
resources=[]
externals=[]
textures={}
for family in ['concrete','plaster','steel','wood']:
 key='Texture_'+family;textures[family]=key
 externals.append(f'[ext_resource type="Texture2D" path="res://assets/environment/materials/{family}-albedo.png" id="{key}"]')
nodes=['[node name="PortoLeste" type="Node3D"]']
counter=0
def vec(p):return 'Vector3('+', '.join(f'{v:.6g}' for v in p)+')'
def resource(kind,properties):
 global counter
 counter+=1;key=f'{kind}_{counter}'
 resources.append(f'[sub_resource type="{kind}" id="{key}"]\n'+properties)
 return key
def group(name,parent='.',position=(0,0,0)):
 path=name if parent=='.' else parent+'/'+name
 nodes.append(f'[node name="{name}" type="Node3D" parent="{parent}"]\nposition = {vec(position)}')
 return path
materials={}
for name,color in {'concrete':(.65,.68,.65),'wall':(.72,.71,.63),'steel':(.38,.45,.43),'roof':(.49,.54,.53),'blue':(.29,.41,.46),'red':(.46,.33,.29),'green':(.41,.46,.35),'mark':(.75,.70,.49),'dark':(.08,.12,.13),'glass':(.20,.34,.39),'wood':(.49,.41,.30),'rubber':(.06,.075,.07)}.items():
 family={'concrete':'concrete','wall':'plaster','steel':'steel','roof':'steel','blue':'steel','red':'steel','green':'steel','wood':'wood'}.get(name)
 textured=f'\nalbedo_texture = ExtResource("{textures[family]}")\nuv1_triplanar = true\nuv1_world_triplanar = true\nuv1_scale = Vector3(0.5,0.5,0.5)' if family else ''
 materials[name]=resource('StandardMaterial3D','albedo_color = Color('+','.join(map(str,color))+',1)\nroughness = 0.87'+textured)
def box(name,parent,pos,size,mat='steel',solid=False,rotation=(0,0,0)):
 mesh=resource('BoxMesh',f'size = {vec(size)}')
 prefix=f'[node name="{name}" type="MeshInstance3D" parent="{parent}"]\nposition = {vec(pos)}\nrotation = {vec(rotation)}\nmesh = SubResource("{mesh}")\nmaterial_override = SubResource("{materials[mat]}")\nvisibility_range_end = 950.0'
 nodes.append(prefix)
 if solid:
  body=name+'Collision'
  nodes.append(f'[node name="{body}" type="StaticBody3D" parent="{parent}"]\nposition = {vec(pos)}\nrotation = {vec(rotation)}\ncollision_layer = 1\ncollision_mask = 0\nmetadata/surface = "metal"')
  shape=resource('BoxShape3D',f'size = {vec(size)}')
  nodes.append(f'[node name="Shape" type="CollisionShape3D" parent="{parent+"/"+body}"]\nshape = SubResource("{shape}")')
def beam(name,parent,a,b,width=.15,mat='steel',solid=False):
 d=[b[i]-a[i] for i in range(3)];length=math.sqrt(sum(v*v for v in d))
 yaw=math.atan2(-d[0],-d[2]);pitch=math.asin(d[1]/length)
 box(name,parent,[(a[i]+b[i])*.5 for i in range(3)],(width,width,length),mat,solid,(pitch,yaw,0))
def label(name,parent,text,pos,width=3,rotation=0):
 nodes.append(f'[node name="{name}" type="Label3D" parent="{parent}"]\nposition = {vec(pos)}\nrotation = Vector3(0,{rotation},0)\ntext = "{text}"\nfont_size = 56\npixel_size = 0.018\nmodulate = Color(0.79,0.78,0.65,1)\noutline_size = 2')

yard=group('PatioDeCarga')
box('FaixaDeCirculacao',yard,(-14,.065,0),(13,.12,205),'concrete')
for i in range(22):box(f'FaixaViaria{i:02}',yard,(-14,.135,-100+i*9),(0.22,.025,4),'mark')
for j,z in enumerate([-23,-43]):
 for i,x in enumerate([6,10,14,18,22,26]):
  c=group(f'Container{j*6+i+1:02}',yard,(x,0,z))
  color=['blue','red','green'][(i+j)%3]
  box('Caixa',c,(0,1.4,0),(2.44,2.8,12.2),color,True)
  for side in [-1,1]:
   for rib in range(13):box(f'Nervura{side}_{rib}',c,(side*1.25,1.4,-5.7+rib*.95),(.06,2.65,.06),'steel')
   box(f'Longarina{side}',c,(0,side*1.35+1.4,0),(2.55,.1,12.3),'steel')
  for xdoor in [-.6,.6]:
   box(f'Porta{xdoor}',c,(xdoor,1.4,6.14),(1.15,2.65,.1),color)
   for latch in [-.25,.25]:box(f'Trava{xdoor}_{latch}',c,(xdoor+latch,1.4,6.22),(.04,2.4,.06),'steel')
  label('Numero',c,str(120+j*6+i),(0,1.7,6.24))
  if i in [0,2,4]:
   box('CargaSuperior',c,(0,4.2,0),(2.44,2.8,12.2),['red','blue','green'][(i+j)%3],True)
   for side in [-1,1]:
    for rib in range(13):box(f'NervuraAlta{side}_{rib}',c,(side*1.25,4.2,-5.7+rib*.95),(.06,2.65,.06),'steel')
warehouse=group('Armazem',position=(8,0,64))
box('Piso',warehouse,(0,.22,0),(31,.44,35),'concrete',True)
for x in [-15,15]:box(f'Parede{x}',warehouse,(x,3.8,0),(.5,7.1,34),'wall',True)
for z in [-17,17]:
 for x in [-10,10]:box(f'ParedeFrente{x}_{z}',warehouse,(x,3.8,z),(10,7.1,.5),'wall',True)
 box(f'Verga{z}',warehouse,(0,6.65,z),(10,1.4,.5),'wall',True)
 for x in [-5.15,5.15]:box(f'Batente{x}_{z}',warehouse,(x,2.9,z),(.23,5.3,.65),'steel',True)
 label(f'Placa{z}',warehouse,'СКЛАД 02',(0,6.7,z+(-.31 if z<0 else .31)),rotation=math.pi if z<0 else 0)
for z in [-16,-8,0,8,16]:
 for side in [-1,1]:
  beam(f'Tesoura{side}_{z}',warehouse,(side*15,7.35,z),(0,10.35,z),.22,solid=True)
  box(f'Coluna{side}_{z}',warehouse,(side*14.65,3.8,z),(.25,7.1,.35),'steel',True)
for side in [-1,1]:
 for section in range(5):
  if side==1 and section==3:continue
  box(f'Telha{side}_{section}',warehouse,(side*7.5,8.85,-13.6+section*6.8),(15.4,.14,6.75),'roof',True,(0,0,-side*math.atan2(3,15)))
 for z in [-17,17]:
  for x in range(1,6):beam(f'Empena{side}_{z}_{x}',warehouse,(side*x*2.5,7.35,z),(side*x*2.5,10.35-x*.5,z),.12)
for i in range(5):
 box(f'Caixote{i}',warehouse,(-10+(i%2)*2.4,1,7+i*1.8),(2,1.5,1.5),'wood',True)
office=group('Administracao',position=(-28,0,68))
box('Base',office,(0,.2,0),(11,.4,19),'concrete',True)
box('Corpo',office,(0,2.15,0),(10,3.9,18),'wall',True)
box('Cobertura',office,(0,4.25,0),(11,.25,19),'roof',True)
for z in [-6,-2,2,6]:
 box(f'Vidro{z}',office,(5.06,2.5,z),(.08,1.4,1.6),'glass')
 for dz in [-.85,.85]:box(f'Moldura{z}_{dz}',office,(5.13,2.5,z+dz),(.1,1.65,.1),'steel')
box('Porta',office,(5.07,1.3,-8),(.1,2.2,1.4),'blue')
label('Controle',office,'КОНТРОЛЬ',(5.2,3.7,0),rotation=math.pi*.5)
quay=group('Cais')
for i in range(17):
 z=-103+i*12.5
 box(f'MarcacaoBorda{i}',quay,(39,.065,z),(1.5,.10,5),'mark')
 box(f'Defensa{i}',quay,(41.3,-.7,z),(.6,1.7,1.4),'rubber')
for i in range(6):
 z=-90+i*35
 box(f'BatenteAtracacao{i}',quay,(37,.25,z),(.5,.5,1),'steel',True)
access=group('Entrada')
for side in [-1,1]:
 box(f'BasePortao{side}',access,(-36,.5,side*8),(1,1,1),'concrete',True)
 box(f'PostePortao{side}',access,(-36,2.5,side*8),(.2,4,.2),'steel',True)
 for z in range(12,103,6):box(f'Cerca{side}_{z}',access,(-38,1.4,side*z),(.10,2.2,4.9),'steel')
label('PlacaEntrada',access,'ПОРТ СХІД / ТЕРМІНАЛ 02',(-35,5.5,0),rotation=-math.pi*.5)

folder=ROOT/'modes/war/scenes';folder.mkdir(exist_ok=True)
(folder/'east_port.tscn').write_text('[gd_scene load_steps='+str(len(resources)+len(externals)+1)+' format=3]\n\n'+'\n\n'.join(externals+resources+nodes)+'\n',encoding='utf-8')
print('AUTHORED_EAST_PORT',len(nodes),'nodes')
