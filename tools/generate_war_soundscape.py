"""Original synthesized loops and foley, generated locally with a fixed seed."""
from pathlib import Path
import wave
import numpy as np
out=Path(__file__).resolve().parents[1]/'audio/war';out.mkdir(exist_ok=True)
rate=22050;rng=np.random.default_rng(78114)
def save(name,seconds,fn,loop=False):
 t=np.arange(round(rate*seconds))/rate
 noise=rng.normal(0,1,len(t))
 low=np.convolve(noise,np.ones(31)/31,'same')
 data=fn(t,noise,low)
 peak=max(.001,float(np.max(np.abs(data))));data=data/max(1,peak/.8)
 if not loop:data*=np.minimum(1,t/.003)*np.minimum(1,(seconds-t)/.03)
 else:
  # Cross-fade endpoints to zero; short loops are phase-continuous.
  data*=np.minimum(1,t/.025)*np.minimum(1,(seconds-t)/.025)
 with wave.open(str(out/(name+'.wav')),'wb') as f:
  f.setparams((1,2,rate,0,'NONE','not compressed'));f.writeframes((np.clip(data,-.9,.9)*32767).astype('<i2').tobytes())
save('engine',3,lambda t,n,l:(np.sin(2*np.pi*44*t)*.28+np.sin(2*np.pi*88*t)*.13+np.sin(2*np.pi*132*t)*.08+l*.3)*(1+.12*np.sin(2*np.pi*11*t)),True)
save('tracks',3,lambda t,n,l:n*.13*(.35+.65*np.maximum(0,np.sin(2*np.pi*17*t))**8)+l*.20,True)
save('tyres',3,lambda t,n,l:l*.25+n*.035,True)
save('drone',3,lambda t,n,l:(np.sin(2*np.pi*176*t)*.17+np.sin(2*np.pi*352*t)*.09+np.sin(2*np.pi*528*t)*.055)*(1+.12*np.sin(2*np.pi*23*t))+n*.025,True)
save('servo',2,lambda t,n,l:np.sin(2*np.pi*310*t)*.055+np.sin(2*np.pi*622*t)*.025+l*.09,True)
save('wind',8,lambda t,n,l:l*.9*(.65+.22*np.sin(2*np.pi*.25*t))+n*.018,True)
save('fire',4,lambda t,n,l:l*.25+n*.045+n*.22*(rng.random(len(t))>.996),True)
save('electric',3,lambda t,n,l:np.sin(2*np.pi*100*t)*.10+n*.09*(rng.random(len(t))>.997),True)
save('creak',1.3,lambda t,n,l:(np.sin(2*np.pi*(190*t+45*t*t))*.13+np.sin(2*np.pi*384*t)*.04+l*.2)*np.sin(np.pi*t/1.3)**2)
save('bird',.8,lambda t,n,l:np.sin(2*np.pi*(1700*t+430*np.sin(t*6)))*.10*(np.sin(t*19)**12)*np.sin(np.pi*t/.8)**2)
for material,roughness,pitch in [('mud',.7,85),('dirt',.42,120),('gravel',.85,180),('concrete',.22,210),('wood',.18,310),('metal',.09,690),('water',.9,65)]:
 for variation in range(3):
  save(f'step-{material}-{variation}',.22,lambda t,n,l,r=roughness,p=pitch:(n*r*.16*np.exp(-t*30)+l*.24*np.exp(-t*16)+np.sin(2*np.pi*p*t)*(.22-r*.10)*np.exp(-t*48))*(1+variation*.06))
save('gear',.18,lambda t,n,l:(n*.10+np.sin(2*np.pi*1800*t)*.025)*np.exp(-t*30))
save('reload',.65,lambda t,n,l:n*.15*(np.exp(-abs(t-.06)*120)+np.exp(-abs(t-.3)*140)+np.exp(-abs(t-.54)*170)))
save('collision',.4,lambda t,n,l:(l*.5+np.sin(2*np.pi*74*t)*.3)*np.exp(-t*15))
print('Generated',len(list(out.glob('*.wav'))),'original War sounds')
