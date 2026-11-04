"""Original synthesized feedback; no sampled voices or external recordings."""
from pathlib import Path
import math, random, struct, wave
root=Path(__file__).resolve().parents[1]/'audio'
rng=random.Random(9107); rate=22050
def save(name, seconds, sample):
    data=[]
    for i in range(int(rate*seconds)):
        t=i/rate; data.append(max(-.9,min(.9,sample(t,t/seconds))))
    with wave.open(str(root/name),'wb') as f:
        f.setparams((1,2,rate,0,'NONE','not compressed'))
        f.writeframes(b''.join(struct.pack('<h',round(v*32767)) for v in data))
save('hurt_generated.wav',.29,lambda t,u: (math.sin(2*math.pi*(119*t-18*t*t))*.33+math.sin(2*math.pi*244*t)*.1+rng.uniform(-1,1)*.06)*math.sin(math.pi*u)**.65)
save('near_miss_generated.wav',.20,lambda t,u: (rng.uniform(-1,1)*.30+math.sin(2*math.pi*(1800*t-2500*t*t))*.11)*math.sin(math.pi*u)**2)
save('empty_generated.wav',.095,lambda t,u: (rng.uniform(-1,1)*.45+math.sin(2*math.pi*1800*t)*.25)*math.exp(-u*15)+math.sin(2*math.pi*740*t)*math.exp(-abs(u-.38)*65)*.19)
save('earth_impact_generated.wav',.28,lambda t,u: (rng.uniform(-1,1)*.66+math.sin(2*math.pi*83*t)*.3)*math.exp(-u*11)+rng.uniform(-1,1)*.09*math.exp(-abs(u-.25)*12))
print('4 original combat feedback WAV files generated')
