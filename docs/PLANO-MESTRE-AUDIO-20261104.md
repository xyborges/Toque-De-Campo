# PLANO MESTRE DE ÁUDIO — JOGO DE NAVEGADOR / GODOT
Data: 04/11/2026 | Engine de validação: Godot 4.7.2 | Foco: todos os modos

## Estado real desta revisão
- [x] Instalar diretamente o kit V3 do tanque: tanque_municao_V3_PERTO.wav -> audio/explosions/tank_near.wav e tanque_municao_V3_DISTANTE.wav -> audio/explosions/tank_far.wav.
- [x] Confirmar SHA-256 com ZIP enviado; reimportar no Godot. Sem preservar as WAVs V2 antigas no projeto.
- [x] Preservar granada e drone e seus próprios kits.
- [x] Preservar os 5 estalos já presentes no arquivo final: 1,45; 2,72; 3,08; 4,25; 6,10 segundos. Os STEMs NÃO devem tocar junto com o WAV final.
- [x] Sincronizar os flashes da destruição de tanques e outros blindados com os cinco tempos do arquivo V3 (os outros blindados usam o mesmo áudio pesado).
- [ ] Implementar o NOVO mixer com prioridade/ducking, compressor e limiter de master — AINDA NÃO EXECUTADO.
- [ ] Validar acusticamente a mixagem da partida real e benchmark de FPS.
- [ ] Exportar/publicar a próxima atualização — NÃO EXECUTADO.

## Princípios inegociáveis
1. Audio cinematográfico, posicional e inteligível. A explosão de um blindado a 50–100 m deve dominar perceptivamente um G3 disparado junto, mas não apagar informações de gameplay nem a conversa de voz.
2. A intensidade vem do ataque, dinâmica, corpo, propagação, reflexões e balanço relativo, não de volume máximo indiscriminado.
3. O som mantém posição e tempo corretos. O brilho visual aparece na detonação; o estrondo chega ao ouvinte depois do tempo físico de propagação; estalos secundários seguem a mesma linha do tempo.
4. Configurações de volume do jogador continuam válidas. Nenhum reajuste pode ignorar Master, Efeitos, Armas ou Voz.
5. O servidor só retransmite eventos/dados; DSP de áudio, decodificação e espacialização permanecem no cliente. Voz Opus mantém seu transporte/codec existente.
6. Vozes, efeitos, partículas e raycasts com orçamento fixo. Não abrir alocação infinita em combate com 28 bots e preparar crescimento futuro para 57.
7. Não alterar IA, mapa, spawn, loot, física ou dano para resolver áudio. Trabalhar em código próprio e testar cruzamentos.

## Diagnóstico observado
- GameWeaponAudio tem 96 AudioStreamPlayer3D, perfis por arma e buses WeaponShots/Mid/Far/Blocked/Rear. G3 possui sample próprio perto/longe.
- GameExplosionAudio tem 24 players principais + 8 de pressão; kits separados para granada, tanque e drone; crossfade perto/distante; evento localizado em 3D.
- WarSoundscape atualiza acústica/oclusão usando orçamento de 8 fontes por atualização de 100ms.
- WarEffects usa MultiMesh de 256 cards e sequências secundárias visuais, sem física extra.
- Configuração atual encaminha disparos e explosões pela categoria Armas; não há prioridade acústica de explosão sobre disparo local nem ducking inteligente.
- Medição anterior de G3 local + explosão de tanque a 100m, com kit V3: o G3 isolado RMS -30,3 dBFS, tanque isolado -13,8 dBFS, ambos -13,7 dBFS; pico conjunto medido +2,13 dBFS NO PONTO DE CAPTURA. Isso pede revisão de headroom/final limiter, sem afirmar clipping físico sem medição no dispositivo.
- Voz por proximidade já existe com codec Opus, PTT e limite de até 6 falantes próximos. Não substituir nem quebrar: documentação em docs/VOZ-PROXIMIDADE-CLIENTE.md.

## FASE 1 — inventário, medição e regressão (primeira etapa geral)
Entregáveis:
- Tabela completa de eventos por modo, com origem, arquivo, comprimento, taxa de amostragem, volume, categoria, distância, prioridade, loop e owner.
- Cenas de QA que disparam G3 e explosão a 50/100/300m, tiro/impacto à esquerda/direita, blindado FPP/TPP, drone, granada, 28 bots, voice PTT e ambientes fechados.
- Captura do bus Master e de cada bus relevante: picos, RMS de ataque e cauda, quedas por distância e número de vozes ativas. Salvar resultados reproduzíveis.
- Critérios perceptivos: orientação de origem sem olhar; distinguir granada, BMP, tanque e drone; corpo do impacto; fala inteligível; nenhum clique/corte ao lotar pool.

## FASE 2 — arquitetura única de buses
Preservar controles de usuário existentes, mas reorganizar buses internos assim:
Master
  - Efeitos
    - Armas (controle herdado do usuário)
      - CombatWeaponsLocal       (sua arma)
      - CombatWeaponsWorld       (armas de outros jogadores/bots)
      - CombatBallistics         (whiz/crack de balas)
      - CombatImpacts            (material e penetração)
      - CombatExplosionsHeavy    (tanques/APCs/munição)
      - CombatExplosionsLight    (granadas/drones/mísseis)
      - CombatExplosionPressure  (pulso grave e estalo complementar)
    - Veiculos (motor, esteiras, servos, colisões)
    - Ambiente (vento, chuva, água, aves, ruínas)
    - Passos (passos, roupa, equipamento)
  - Voice (PTT; manter volume individual e prioridade de comunicação)
  - Interface (HUD, seleção, feedback)
  - Music (menus e transições)

Migrar encaminhamentos com cuidado: Voice, explosões e armas não devem usar double send ou limiter em cascata que achate o ataque. Manter compatibilidade com os nomes/canais anteriores até finalizar a migração.

## FASE 3 — prioridade/ducking contextual e proteção do pico (prioridade máxima)
- O event bus de uma explosão pesada, quando AUDÍVEL ao usuário e a menos de 150m, solicita uma janela de prioridade ao mixer CLIENTE. O pedido nasce na hora de chegada do áudio, não no recebimento do RPC.
- Reduzir CombatWeaponsLocal em 2 a 4 dB somente durante o impacto inicial; armas remotas em até 1–2 dB conforme densidade. Não suprimir completamente nenhum disparo; manter posicionamento direcional.
- Envelope inicial: attack 10–25ms, hold 150–250ms, release 500–900ms; calibrar ouvindo. Não prolongar o duck durante os 13,4s inteiros da explosão.
- Repetidas explosões não somam redução sem limite: prioridade mais forte vence, envelope é renovado com teto absoluto. Não produzir estalos ao trocar ganho.
- Considerar compressor com sidechain no Godot (suportado em AudioEffectCompressor) para controle por sinal, mas preferir envelope de evento se for necessário considerar distância, oclusão e tipo de arma. Confirmar ambas as alternativas com A/B gravado.
- Finalizar chain de Master com limitador de pico calibrado (alvo inicial ceiling -1 dBFS) e headroom suficiente, evitando o mix +2 dBFS medido. NÃO usar compressor extremo no master como substituto de balanceamento.
- Preservar Voice/PTT, avisos críticos, direcionalidade e a opção de volume do usuário; evitar ducking agressivo em tudo.

## FASE 4 — disparos, balística, impacto e propagação 3D
- Por arma: entrada (click/estalo), explosão do cano, corpo, cauda ao ar livre e amostras perto/médio/longe com transições sem degraus.
- Calibrar G3, AK/FAL, pistolas, sniper, metralhadoras, 30mm e canhões pesados com referências distintas; não reutilizar explosão de tanque para som de cano.
- Trajetória: disparo da posição da arma, whiz/crack no segmento real da bala e impacto do projétil sobre material. Frente/trás/altura com pistas espaciais; avaliar HRTF opcional por plataforma.
- Propagação: manter 343 m/s e tratamento por distância; evitar reproduzir a mesma reverberação de sala em campos abertos. Reflexão forte só onde há geometria adequada (edifícios, vales, porto).
- Oclusão: ignorar casco que origina o estrondo; distinguir parede real, terreno, blindagem e cabine. Reservar raycasts por orçamento (batch e cache).
- Testar lado esquerdo/direito, trás, alto, sobreposição e som a 50/100/500/1500m.

## FASE 5 — explosões e destruição audiovisual
- Manter o kit V3 do tanque como master para near/far com seus cinco estalos já misturados. NÃO tocar STEMs em paralelo. É preciso aguardar aprovação sonora em partida para substituir/alterar novamente.
- Usar tipo coerente: tanque e destruição de blindado -> V3; granada -> kit de granada; drone/TV/míssil -> kit dedicado. Evitar variantes aleatórias de categoria errada.
- Sincronizar flashes e secondary cook-offs com os tempos da WAV V3, respeitando atraso físico da onda sonora. Ação visual é client-side e não cria dano extra.
- Qualidade visual por distância: flash curto, bola de fogo, choque, detritos/poeira, coluna de fumaça, incêndio persistente — com LOD e limites de overdraw.
- Diferenciar detonação de munição pesada versus impactos pequenos; não tocar o mesmo som gigante quando o efeito é leve.
- Comparar antes/depois com capturas PCM e gravação de gameplay a 25/50/100/250m.

## FASE 6 — veículos, ambiente e superfície
- Veículos: motor e esforço do RPM, esteiras, pneu, servo da torre, interior/exterior, cabine de blindado, visão térmica/óptica, dano, colapso e incêndio; cada fonte com posição consistente.
- Mapas: Afeganistão/BR (vento seco, distância e obstáculos), Guerra Ucrânia (artilharia distante, fumaça, ruínas), Deserto clássico, Escritório e Naval/porto onde presentes. Reverb interior real somente nas áreas adequadas; evitar som de quarto em campo aberto.
- Água/navio/submarino: ambiente e ar vs submerso, motores, disparo naval/torpedo e rádio conforme mecânicas reais existentes. Não criar áudio de gameplay que o modo não tem.
- Passos: diferentes superfícies, postura, corrida, andar, equipamento e distância, audíveis para jogabilidade sem competir com explosões.
- HUD/UI: clique, equipar, recarga, eliminação, alerta, trocas de estado e menus/transições, em bus independente.

## FASE 7 — voz por proximidade e acessibilidade
- Preservar Godotopus/Opus, PTT e relay autoritativo existente. Não enviar áudio de combate pelo servidor, nem misturar microfone com ambiente/efeitos.
- Manter voz inteligível durante explosões sem reduzir todo o combate de modo irreal; priorização suave e configurável apenas na reprodução (não no codec).
- Mute individual, faixa de volume de voz, indicador de PTT e entrada do dispositivo permanecem operacionais.
- Preferências: controles por categoria, perfil "Dinâmico" e perfil "Noturno", limites de pico, teste de canal esquerdo/direito, cuidado com jogadores de fone.

## FASE 8 — desempenho, QA completo e entrega
- Orçamentos de referência atuais: 96 fontes de armas, 24 explosões principais, 8 camadas de pressão, 256 cards FX, 8 raycasts de acústica por ciclo de 100ms; até 6 falantes por proximidade. Não multiplicar indiscriminadamente.
- Teste com 28 bots / 1080p / GTX 1650 e mapa do Afeganistão, Ucrânia e BR; depois prova de escalabilidade para 57 bots. Registrar median FPS, 1% low, custo de CPU em audio, estalos e cortes.
- Testar evento simultâneo G3+tanque a 100m com áudio isolado, somado e pós-mixer; meta: sem clipping perceptível, explosão dominante e G3 ainda localizável.
- Teste de 40 explosões, desconexões, respawn e troca FPP/TPP sem vazamento de fonte, crash ou reinício de voice.
- Publicar apenas após suíte automática, teste auditivo humano em fones e aprovação multiplayer. Nunca confundir "Godot importou" com "áudio aprovado".

## Ordem sugerida
P0: kit tanque V3 instalado/validado e efeito visual sincronizado (esta revisão).
P1: Fases 1, 2 e 3 — mixer/buses + ducking e limiter, por serem a causa sistêmica de conflitos.
P2: Fases 4 e 5 — acústica/armas, explosões e choque visual.
P3: Fases 6 e 7 — veículos, mapas, voz, interface e acessibilidade.
P4: Fase 8 — estresse, escuta, build e publicação.

## Arquivos mais relevantes
scripts/weapon_audio.gd; scripts/explosion_audio.gd; scripts/combat_feedback.gd; scripts/sound_propagation.gd; scripts/audio_settings.gd; scripts/combat_audio_catalog.gd; scripts/grenades.gd; scripts/voice/client.gd; modes/war/scripts/audio.gd; modes/war/scripts/soundscape.gd; modes/war/scripts/effects.gd; modes/war/scripts/vehicles.gd; modes/battle_royale/voice/relay.gd.
