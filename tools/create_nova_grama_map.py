"""Create a starter biome PNG only if the user has not already painted one."""
from pathlib import Path
import math, struct, zlib
target=Path(__file__).resolve().parents[1]/'assets/war/biomes/nova_grama.png'
if target.exists():
 print('PRESERVED',target)
 raise SystemExit(0)
size=256
palette={'field':(48,150,54),'burnt':(108,65,50),'transition':(178,151,80),'trail':(174,165,145)}
rows=[]
for py in range(size):
 row=bytearray([0])
 for px in range(size):
  x=(px+.5)*3500/size-1750; z=(py+.5)*3500/size-1750
  boundary=250+30*math.sin(x*.004)
  zone='field' if abs(z)>boundary+75 else ('burnt' if abs(z)<boundary-75 else 'transition')
  if abs(z-(25*math.sin(x*.009)))<11: zone='trail'
  row.extend(palette[zone])
 rows.append(row)
def chunk(kind,data):
 return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',size,size,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(b''.join(rows),9))+chunk(b'IEND',b'')
target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(png)
print('CREATED',target)
