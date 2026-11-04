# Atualização 1.5.2 — áudio de combate

Publicada em 23/10/2026, build 22, no servidor Ubuntu 192.168.101.24. Site, notas do instalador e manifesto assinado usam a mesma versão.

## Sons recebidos

- `sound_109.wav` → `audio/pistol-109.wav`: substitui o disparo da Glock no Offline e PVP Deserto. O catálogo também é utilizado no Guerra em desenvolvimento.
- `sound_115.wav` → `audio/explosion-115.wav`.
- `sound_114.wav` → `audio/explosion-114.wav`.
- `sound_112.wav` → `audio/explosion-112.wav`.

114 e 115 são gravações idênticas nos arquivos recebidos; os nomes foram mantidos. Os quatro anexos foram copiados de suas pastas temporárias para recursos permanentes antes da importação. Créditos e hash da duplicata estão em `audio/USER-SUPPLIED-SOUNDS.md`.

## Reprodução e multiplayer

O servidor já distribui identificadores e posições dos eventos. Um hash estável desse identificador escolhe o mesmo arquivo em cada cliente. A posição é processada por AudioStreamPlayer3D, com atenuação por distância. Arquivos WAV não são enviados durante as partidas.

`GameExplosionAudio` utiliza uma voz independente por explosão, preservando sua posição durante a cauda. Pool máximo de 24 vozes; a mais antiga é reciclada ao atingir o limite. Ganho −12 dB e limitadores controlam a soma das amostras. Até 256 identificadores recentes ficam registrados para não repetir o mesmo evento. Valores de posição não finitos são recusados. Aplicado às explosões de navios e aos impactos de míssil/torpedo; no Guerra, ao evento autoritativo de explosão.

Caixas de colisão de ragdolls também foram alinhadas ao centro real da malha, preservando a configuração de estabilidade da versão anterior.

## Arquivos principais

- `scripts/combat_audio_catalog.gd`: catálogo e escolha estável.
- `scripts/explosion_audio.gd`: vozes espaciais independentes, deduplicação e limite.
- `scripts/main.gd`: novo som da Glock no sistema compartilhado.
- `modes/naval/scripts/world.gd` e `mode.gd`: origem das explosões navais.
- `modes/war/scripts/audio.gd`: catálogo compartilhado com Guerra.
- `scripts/death_ragdoll.gd`: centro das caixas.
- `distribution/release-notes.json`: notas no site/atualizador.

## Validações realizadas

- `tests/supplied_audio.gd`: 43 verificações aprovadas, incluindo quatro WAVs mono importados, pistola, reprodução Naval/Guerra, igualdade de amostra em dois clientes, posições simultâneas independentes, deduplicação e carga de 80 explosões.
- Regressões: lobby naval 18, física naval 15, combate 86, armas brancas/NPCs 73, ragdoll quatro verificações aprovadas. Uma execução inicial falhou na verificação de contato do NPC; a repetição com diagnóstico passou. O fixture passou a inicializar explicitamente relógio/estado/velocidade do ataque e aguardar a atualização física para isolar essa verificação. A causa da falha intermitente não foi comprovada pela primeira execução; o código de dano dos NPCs não foi alterado nesta correção do teste. A falha original e o diagnóstico foram preservados em `work/audio-152-melee_offline_integration-verified.log` e `work/audio-152-melee-diagnostic.log`.
- Teste ENet com atraso 20–70 ms e 256 de 3.144 datagramas descartados: dano, morte, respawn, recarga, mira, movimento, reconexão e identidade do áudio de morte aprovados.
- Dois executáveis Windows QA recém-exportados, autenticados no servidor central: movimento e disparo do anfitrião, disparo/áudio remoto no outro cliente e continuidade após saída do criador aprovados.
- `work/audio-152-deploy.log`: assinatura verificada e ativação do build 22.

Download e atualizador aprovados: executável real baixado do Ubuntu instalou a versão 1.5.2; a segunda execução informou que nenhum download era necessário. Os quatro WAVs foram carregados de dentro do PCK publicado. Inicialização do executável de produção, TLS e bloqueio dos arquivos privados aprovados. Evidências em `work/audio-152-distribution.log` e `tests/ubuntu-distribution-results.json`.

## Guerra

O trabalho paralelo continua local e sua disponibilidade pública permanece condicionada à validação do modo. `GUERRA-DESEMPENHO.md` registra testes com 1, 6 e 12 clientes e custos reais do Godot Profiler. A meta de 60 FPS estáveis ainda não foi atingida; não é anunciada como concluída nesta atualização.
