"""Original restrained motorcycle loop. Does not overwrite existing vehicle audio."""
from pathlib import Path
import array
import math
import random
import wave

rate = 22050
duration = 6
rng = random.Random(193)
pcm = array.array("h")
filtered = 0.0
for i in range(rate * duration):
    t = i / rate
    filtered += 0.13 * (rng.uniform(-1, 1) - filtered)
    # A round exhaust pulse with restrained upper harmonics; no hard clicks.
    pulse = sum(math.sin(2 * math.pi * 38 * harmonic * t) / harmonic**1.7
                for harmonic in range(1, 7))
    value = 0.24 * pulse + 0.055 * filtered
    envelope = min(1.0, i / 441, (rate * duration - 1 - i) / 441)
    pcm.append(round(max(-0.8, min(0.8, value * envelope)) * 32767))
output = Path(__file__).resolve().parents[1] / "audio/war/engine-bike.wav"
with wave.open(str(output), "wb") as sound:
    sound.setparams((1, 2, rate, 0, "NONE", "not compressed"))
    sound.writeframes(pcm.tobytes())
print(f"Created {output.name}: {duration}s, peak {max(abs(x) for x in pcm)/32767:.3f}")
