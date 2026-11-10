# Profundidade e localização dos disparos remotos — 10/11/2026

## Sintoma e causa investigada

Relato: os disparos de outros jogadores e NPCs parecem vir do próprio personagem, mesmo quando o atirador está distante.

A sequência de produção `GamePlayer.fire` → `GameMain._server_accept_shot` → `WarGame._present_shot` → `WarAudio` → `GameWeaponAudio._play_now` foi auditada. A autoridade envia `packet.origin`, a posição mundial do cano, e cada `AudioStreamPlayer3D` usa `voice.global_position=point`, sem acompanhar o jogador que escuta. O `AudioListener3D` permanece na cabeça do jogador local. **Não foi constatado um erro de coordenadas no caminho dos tiros; o defeito mensurável era perceptivo.**

A atualização de presença global adicionou +10,145 dB em 400 m, enquanto os perfis de rifle usavam referência inversa de 95 metros e filtragem de quase 17 kHz em longas distâncias. Assim, tiros remotos preservavam muita energia/agudos e podiam soar tão próximos quanto o próprio disparo. Aumentar atenuação de paredes como paliativo não foi adotado: preservamos a oclusão original de 4,5 dB.

## Correção — quatro problemas menores

1. **Referência 3D da arma:** Glock muda de `unit_size=46` para 42; AK/FAL/G3 de 95 para **70**; sniper de 155 para **110**; metralhadoras de 140 para **105**. As distâncias máximas, balística, dano e mecânica de rede não mudam. Armas pesadas/tanque, RPG, autocannon, explosões e ferramentas mantêm os perfis originais.
2. **Alívio de disparo remoto:** `GameWeaponAudio.distant_shot_relief_db` atinge até **−5 dB** entre 8 e 75 m para armas leves, permanecendo constante além de 75 m. A própria arma a 5 m mantém o ganho; a partir de 50 m a sensação de distância aumenta, enquanto o ganho global de presença continua parcialmente ativo aos 400–600 m. A distância também é atenuada naturalmente pelo `AudioStreamPlayer3D` depois dos 75 m.
3. **Assinatura espectral:** pequenas armas usam filtragem contínua de **18 kHz próximo** até **7,4 kHz a 375 m**. As armas pesadas mantêm os filtros anteriores; obstrução física ainda limita o agudo em 5,6 kHz.
4. **Primeiro transiente no lugar certo:** distância, oclusão, timbre e bus são configurados **antes** de `voice.play()`; não se espera pela próxima varredura acústica para evitar o estalo inicial com timbre de tiro próximo. Os sons continuam saindo da coordenada 3D real de cada cano, inclusive com reciclagem do pool fixo de 96 vozes.

`GameSoundPropagation` continua usando 343 m/s, sem mudanças no áudio de explosões, no Master, nos controles de volume, nos recursos WAV/MP3 nem no `remote_shot_packet`.

## QA nativa com áudio real

**Godot 4.7.2, GTX 1650, modo Compatibility, WAVs/MP3 reais, 24/24 verificações aprovadas**, em `tests/shot_distance_localization_20261110.gd`. Há uma câmera e um ouvinte reais do Godot, com `AudioEffectCapture` no bus `WeaponShots`.

| Verificação | Resultado |
|---|---:|
| FAL disparado a 5 m — RMS estéreo | 0,217 aprox. |
| FAL remoto a 50 m — RMS estéreo | 0,152 aprox. |
| FAL remoto a 400 m — RMS estéreo | 0,0208 no QA local; 0,02189 no ENet Guerra/FPP |
| Agudos do FAL a 400 m | 7400 Hz |
| Pan esquerdo/direito (tiros remotos) | Correto; a fonte mantém a lateralidade |
| Erro entre emissor e coordenada mundial pretendida | 0,0 metro |
| FAL a 50 m, parede física | Oclusão original −4,5 dB preservada; resultado ENet bloqueado/limpo ≈0,510 nos dois modos |
| G3, Glock, sniper, MGs, tanque, RPG | Uso de perfis por tipo preservado; G3 distante usa `g3_far.mp3` |
| Limite de vozes do pool | 96, sem alteração |

**269/269 regressões do mixer passaram após a calibração da distância:** `combat_presence_audio_20261108.gd` (103), `audio_far_gain_20261104.gd` (17), `audio_direction_20261103.gd` (19), `audio_settings_functional.gd` (57), `apc30mm_audio_20261105.gd` (36), `explosions_kit_v2_20261103.gd` (33), `near_miss195.gd` (4). A regressão curta da parede é medida com um obstáculo físico, uma amostra de disparo real e o ataque inicial, não só a reverberação de cauda.

## Multiplayer ENet e limites

O teste `tests/war_audio_remote.gd` exerce **duas instâncias reais** (autoridade headless e observador com GTX 1650), com validação ordinária de munição/vida/cadência e RPC confiável `remote_shot_packet`. A matriz inclui 50, 100, 200, 300, 400 e 600 m, Guerra e Deserto, FPP/TPP, Glock/FAL/sniper, pan esquerda/direita, obstáculos e deduplicação. A janela de comparação de parede foi corrigida: `skip=.05` em vez da janela tardia `skip=.25`, **sem afrouxar** o gate `0.45 < bloqueado/limpo < 0.86`. **Rodada final concluída com sucesso:** observador **289/289 checks PASS**; servidor **3/3 checks PASS**; **82/82 tiros** transmitidos via ENet e reproduzidos pelo cliente. Os dois processos encerraram com **exit code 0**. As medidas diretas de oclusão ficaram em 0,50986 no Deserto e 0,50995 na Guerra (gate original entre 0,45 e 0,86); lateralidade estéreo, referência FPP/TPP, atenuação monotônica até 600 m, fonte 3D e deduplicação passaram. As capturas e logs estão em `work/war-audio-remote-*.stdout.log` e nos JSONs da última execução preservados em `work/shot-localization-enet-20261110/`. Os arquivos JSON históricos de teste versionados foram restaurados ao conteúdo original para evitar diffs de dados gerados.

Os testes de voz/PCM permitem avaliar nível e posição mas não substituem a aprovação auditiva humana do timbre em uma partida longa e real. O cenário ENet é uma arena de QA, não uma sessão completa de Favela ou combate com 28 bots.

## Fonte, branch e segurança

A branch `ia/shot-distance-localization-20261110` partiu da `main` local `ed0e856`, que documenta a build 98, e tinha **29 commits locais não presentes no `origin/main`** no começo deste trabalho. É necessário coordenar a sincronização do GitHub antes de abrir ou integrar PRs, para não importar involuntariamente os commits de release. Não efetuar merge direto na `main` nem deploy sem revisão.

Arquivos alterados: `scripts/weapon_audio.gd`; testes `audio_far_gain_20261104.gd`, `combat_presence_audio_20261108.gd`, `war_audio_remote.gd`, nova `shot_distance_localization_20261110.gd` + UID e este relatório. **Nenhum WAV, mapa, asset de explosão, servidor, rede, balística ou rotina de bots modificado.**

Para reverter, reverter somente o commit da branch. Mantêm-se os volumes pessoais do usuário.
