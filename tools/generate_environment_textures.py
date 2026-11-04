"""Original seamless PBR surfaces. No downloaded art or external asset licenses."""
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / 'assets/environment/materials'
ROOT.mkdir(parents=True, exist_ok=True)
N = 256
y, x = np.mgrid[:N, :N] / N
rng = np.random.default_rng(84167)

def noise(scale):
    field = rng.normal(size=(N, N))
    fy, fx = np.meshgrid(np.fft.fftfreq(N), np.fft.fftfreq(N), indexing='ij')
    field = np.fft.ifft2(np.fft.fft2(field) * np.exp(-(fx*fx+fy*fy)*scale**2)).real
    return field / max(field.std(), .0001)

specs = {
    'concrete': ((.56,.54,.48), .85),
    'plaster': ((.76,.75,.67), .9),
    'steel': ((.32,.38,.36), .51),
    'wood': ((.40,.29,.17), .72),
    'cardboard': ((.59,.43,.26), .92),
    'sand': ((.66,.51,.31), .95),
    'rock': ((.40,.43,.38), .91),
    'fabric': ((.40,.44,.30), .94),
    'floor': ((.53,.47,.36), .79),
    'asphalt': ((.25,.26,.24), .94),
    'brick': ((.59,.53,.42), .88),
}
for name, (color, rough) in specs.items():
    coarse = noise(38)
    fine = noise(4)
    relief = coarse*.035 + fine*.009
    value = coarse*.045 + fine*.018
    if name in ['plaster','concrete']:
        value = coarse*(.014 if name=='plaster' else .022)+fine*.006
        relief = coarse*.012+fine*.004
    if name == 'sand':
        ripple = np.sin(y*2*np.pi*14 + np.sin(x*2*np.pi)*1.6)
        relief += ripple*.035
        value += ripple*.018
    if name in ['wood','cardboard']:
        grain = np.sin(x*2*np.pi*(27 if name=='wood' else 76)+np.sin(y*2*np.pi*2)*.5)
        relief += grain*.012
        value += grain*.023
    if name == 'steel':
        pits = np.maximum(0, coarse-1.1)
        value -= pits*.05
        relief -= pits*.025
    if name == 'rock':
        seam = np.exp(-np.abs(np.sin(x*2*np.pi*3 + np.sin(y*2*np.pi*2)))*65)
        relief -= seam*.11
        value -= seam*.12
    if name == 'fabric':
        weave = np.sin(x*2*np.pi*64)*np.sin(y*2*np.pi*64)
        relief += weave*.026
        value += weave*.025
    if name == 'floor':
        joint = (np.minimum(x%0.5, 0.5-x%0.5)<.004) | (np.minimum(y%0.5, 0.5-y%0.5)<.004)
        relief -= joint*.04
        value -= joint*.13
    if name == 'brick':
        row = np.floor(y*8)
        bx = (x+(row%2)*.125)%.25
        mortar = (y*8%1<.07) | (bx<.012)
        relief -= mortar*.065
        value += mortar*.11
    rgb = np.clip(np.asarray(color)[None,None,:] + value[:,:,None],0,1)
    if name == 'steel':
        rust = np.clip((coarse-1.5)*.18,0,.2)
        rgb += rust[:,:,None]*np.array([.45,-.16,-.35])
    normal = np.stack([-(np.roll(relief,-1,1)-np.roll(relief,1,1))*5,
                       -(np.roll(relief,-1,0)-np.roll(relief,1,0))*5,
                       np.ones((N,N))],axis=-1)
    normal /= np.linalg.norm(normal,axis=-1,keepdims=True)
    Image.fromarray((np.clip(rgb,0,1)*255).astype('uint8')).save(ROOT/f'{name}-albedo.png')
    Image.fromarray(((normal*.5+.5)*255).astype('uint8')).save(ROOT/f'{name}-normal.png')
    Image.fromarray((np.clip(rough+fine*.035+coarse*.025,.15,1)*255).astype('uint8')).save(ROOT/f'{name}-roughness.png')
print('ENVIRONMENT_MATERIALS',len(specs),'surfaces',len(specs)*3,'textures',sum(p.stat().st_size for p in ROOT.glob('*.png')),'bytes')
