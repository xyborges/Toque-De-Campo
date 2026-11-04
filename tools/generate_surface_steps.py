"""Original surface-specific boot foley; does not replace other War audio."""
from pathlib import Path
import random,math,wave,struct,json
out=Path(__file__).resolve().parents[1]/'audio/war'
rate=22050
for surface in ['grass','asphalt','stone']:
 for variation in range(3):
  rng=random.Random(184000+variation+sum(map(ord,surface))*7)
  samples=[];low=0.;mid=0.;seconds=.27
  for i in range(int(rate*seconds)):
   t=i/rate;n=rng.uniform(-1,1);low=low*.94+n*.06;mid=mid*.58+n*.42
   sole=math.sin(math.tau*(91+variation*6)*t)*math.exp(-t*65)*.22
   if surface=='grass':
    rustle=(n-mid)*.10*(math.exp(-t*14)+.65*math.exp(-abs(t-.085)*48))
    value=sole*.8+low*.42*math.exp(-t*27)+rustle
   elif surface=='asphalt':
    value=sole+mid*.25*math.exp(-t*45)+(n-mid)*.08*math.exp(-abs(t-.045)*65)
   else:
    crunch=(n-mid)*(.16 if rng.random()>.82 else .035)*math.exp(-t*13)
    value=sole*.85+mid*.24*math.exp(-t*30)+crunch+math.sin(math.tau*340*t)*.05*math.exp(-t*80)
   value*=min(1,t/.002)*min(1,(seconds-t)/.025)
   samples.append(int(max(-.85,min(.85,value))*32767))
  with wave.open(str(out/f'step-{surface}-{variation}.wav'),'wb') as f:
   f.setparams((1,2,rate,0,'NONE','not compressed'));f.writeframes(struct.pack('<'+'h'*len(samples),*samples))
print('Generated nine original surface-step samples')
