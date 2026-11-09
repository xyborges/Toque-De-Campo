# R01 — correção modular de dinâmica das explosões (09/11/2026)

## Base de testes e escopo

A worktree `ia/r01-explosion-dynamics-20261109` foi criada a partir da branch de ganho global `origin/ia/audio-presenca-global-1108` (base `bb462d4`), **não** da `main` da R01, que ainda não continha esse reforço. O teste foi executado no Godot 4.7.2, modo Compatibility / GTX 1650 da DESKTOP-R0I0NQG. As alterações são somente client-side no processamento de áudio.

### Problema 1 — fonte de áudio

Os nove WAVs de explosão/pressão (`grenade`, `tank`, `drone`, perto e longe, mais pressure) foram lidos em PCM mono de 48 kHz. Não havia nenhuma amostra em `+/-32767`: **não existe clipping PCM digital no material original**. O ataque é forte, mas tem headroom limitado nas variantes próximas, com picos entre −0,54 e −0,82 dBFS.

**Decisão:** conservar todos os WAVs V3 originais; não normalizar ou regravar os efeitos.

### Problema 2 — ganho e limitadores do Master

Alguns modos/versões anteriores inicializavam o Master com `AudioEffectLimiter.threshold_db=-6` e `ceiling_db=-0.7`. Com explosões sobrepostas, isso eleva a energia média e prende o pico no limite, achatando a dinâmica. A branch de ganho global já instala um limitador mais conservador em −1 dB, mas antes ela não corrigia um limitador antigo que já estivesse presente.

**Solução:** `GameAudioSettings._ensure_master_peak_ceiling()` reutiliza e calibra qualquer limitador já presente para limiar e teto `−1 dBFS`. Não adiciona duplicata, não altera sliders de usuário, nem interfere no bus de voz/menus.

### Problema 3 — explosões simultâneas

A R01 demonstrou que duas explosões de tanque a 50 m ocupavam vários quadros perto do teto do Master. Reduzir a intensidade de todas as explosões prejudicaria a audibilidade dos sons distantes.

**Solução:** aplicar **um `AudioEffectCompressor` somente no bus `CombatExplosions`**, *antes* do limitador já existente; limiar −3,5 dB, ratio 3,5:1, ataque 5 ms, release 180 ms, makeup 0 dB. Isso controla eventos simultâneos conforme a energia real, mantendo o som do tanque próximo com ataque e corpo e sem reprocessar o WAV. Os buses `CombatExplosionsFar` e `CombatExplosionsBlocked` continuam roteados para `CombatExplosions`, com filtros e posicionamento 3D originais. Os 24 players + 8 camadas de pressão são mantidos.

### Problema 4 — preservar presença a 400 m

A compressão é dependente do nível do sinal. Detonações distantes ficam normalmente abaixo do limiar e não são abafadas. A curva global de `GameSoundPropagation.combat_presence_db`, o crossfade de perto/longe, atraso acústico, oclusão, posições 3D e `max_distance` não foram modificados.

## Testes A/B do mixer real

`tests/r01_explosion_dynamics_20261109.gd`: medidas PCM na saída real do Master usando `AudioEffectCapture`, 1 s normalizado por cenário. O áudio é reproduzido por `GameExplosionAudio` (não uma simulação matemática dos níveis). No A/B, só o compressor do bus de explosões é desativado; o Master e o limitador de explosões permanecem ligados nos dois lados.

| Cenário | Sem compressor | Com compressor |
|---|---:|---:|
| Tanque 50 m, 1 detonação — RMS | −12,44 dBFS | −12,92 dBFS |
| Tanque 50 m, 1 detonação — quadros próximos ao teto | 0,215% | 0,077% |
| Tanque 50 m, 2 detonações — RMS | −7,04 dBFS | −10,89 dBFS |
| Tanque 50 m, 2 detonações — quadros próximos ao teto | **9,82%** | **0,46%** |
| Tanque 400 m, 1 detonação — RMS | −15,537 dBFS | −15,547 dBFS |
| Tanque 600 m, 1 detonação — RMS | — | −17,199 dBFS |
| Tanque 50 m, 4 detonações — quadros próximos ao teto | — | 0,563% |

Resultado inicial: **25/25 verificações aprovadas**. Os sete cenários com processamento habilitado não apresentaram clipping na saída. Granadas e drones próximos continuaram com picos seguros (respectivamente −3,14 e −2,09 dBFS).

O limiar de “próximo ao teto” corresponde a amostras cujo pico absoluto por frame ultrapassa 0,885 na escala digital. Isso não substitui avaliação auditiva humana: percepção de compressão, realismo e aspereza continuam dependendo de reprodução em fones/caixas e numa partida real.

## Arquivos e riscos

Modificados:
- `scripts/explosion_audio.gd` (compressor exclusivo do canal de explosões; inicialização idempotente)
- `scripts/audio_settings.gd` (restauração idempotente de limitador antigo sem makeup excessivo)
- `tests/r01_explosion_dynamics_20261109.gd` (+ UID)
- Este relatório

Não foram alterados os WAVs/MP3, a física, a IA, o multiplayer, a cadência, os bancos do usuário ou outros canais. Caso seja preciso desfazer, reverter somente os commits desta branch. **Nenhuma build foi publicada.** A correção depende de integrar também a branch de presença global se ela ainda não estiver na `main`.

## Validação adicional

**Resultado final na R01: 326/326 verificações PASS**, incluindo 25/25 da nova dinâmica e 301/301 de nove regressões existentes, todos os processos Godot com saída 0: `combat_presence_audio_20261108.gd` (103), `audio_far_gain_20261104.gd` (17), `explosions_kit_v2_20261103.gd` (33), `explosion_impact_20261104.gd` (18), `armor_wreck_presence_20261104.gd` (14), `apc30mm_audio_20261105.gd` (36), `audio_direction_20261103.gd` (19), `audio_settings_functional.gd` (57), `near_miss195.gd` (4). Godot 4.7.2 / Compatibility / GTX 1650.

A regressão de configurações foi medida pelo WASAPI real: os controles de Music, Efeitos, Armas, Ambiente, Veículos, Passos e Interface continuam com ganho proporcional e mute funcional, incluindo a voz. A regressão de áudio global confirmou ganho distante de 3,195× no PCM real a 400 m e limite de pico de 0,891 durante armas e explosões juntas.

O mixer com 28 bots numa partida completa, a replicação ENet específica das explosões e a aprovação auditiva subjetiva ainda precisam de execução específica antes de publicar uma build. Estes testes medem o processamento client-side, não a latência do evento de detonação pela rede.
