"""Original pixel camouflage inspired by equipment references, not copied art."""
from pathlib import Path
import random
from PIL import Image, ImageDraw

target=Path(__file__).resolve().parents[1]/'assets/war'
target.mkdir(exist_ok=True)
for team,palette in [('ukraine',['#8b8862','#aaa182','#626746','#464a37']),('russia',['#4f6242','#73815a','#354833','#29362d'])]:
    rng=random.Random(1979 if team=='ukraine' else 2015)
    image=Image.new('RGB',(256,256),palette[0]);draw=ImageDraw.Draw(image)
    for i in range(940):
        x=rng.randrange(64)*4;y=rng.randrange(64)*4
        w=rng.randrange(1,5)*4;h=rng.randrange(1,4)*4
        color=rng.choice(palette)
        for sx in [0,-256,256]:
            for sy in [0,-256,256]:draw.rectangle((x+sx,y+sy,x+w+sx,y+h+sy),fill=color)
    image.save(target/(team+'-camo.png'),optimize=True)
print('WAR_CAMOUFLAGE_ORIGINAL_READY')
