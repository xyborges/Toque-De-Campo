# Sons desta instância Godot

- `ak_fire.wav`, `sound_026.wav`, `sound_032.wav` e sons navais: arquivos que já estavam no projeto.
- `fal-005.wav`: som da FAL fornecido pelo usuário como `sound_005.wav` em 26/10/2026 (Sound Pack for RSL MOD by Matihuano). Usado pelo sistema compartilhado de áudio 3D em todos os modos.
- `death_0.wav` até `death_5.wav`: os seis sons incorporados no `deathSounds` da versão Three.js de consulta. Foram decodificados de Opus para WAV, sem substituir os originais.
- `glock_fire_generated.wav`, `glock_reload_generated.wav`, `fal_reload_generated.wav`, `melee_swing_generated.wav`: efeitos procedurais de apoio criados para os recursos que estavam sem áudio. Podem ser substituídos por gravações fornecidas pelo usuário.
- `audio/war/step-grass-*.wav`, `step-asphalt-*.wav` e `step-stone-*.wav`: nove amostras originais de apoio, geradas por `tools/generate_surface_steps.py`. O barro usa as amostras próprias `step-mud-*.wav` já existentes. A escolha usa o material da colisão sob o pé e o tipo de via/solo.

O índice de morte é escolhido pela autoridade e transmitido no mesmo evento da morte. Cada cliente reproduz o mesmo arquivo uma vez. Os emissores usam AudioStreamPlayer3D e limite de distância. Um limiter no barramento Master limita a soma dos sons; cada arma reutiliza até quatro vozes. Recargas são canceladas também no áudio quando a arma é trocada ou o personagem morre.

## 1.8.5 — AK e FAL

- `ak-005.wav`: arquivo anteriormente chamado `fal-005.wav`; gravação e ganho preservados para a AK.
- `rifle_reload_generated.wav`: nome comum para a recarga gerada, antes `fal_reload_generated.wav`.
- `fal-098.wav`: cópia integral de `sound_098.wav`, enviado pelo usuário em 26/10/2026, Sound Pack for RSL MOD by Matihuano, GENRL/Bank_137. Mono PCM 16 bits, 44.100 Hz, sem loop. SHA-256: 6898dc5d7b6c66cbb451c5d0b18b61f10fcff851b2dd6a6e6ca163b383298878.
