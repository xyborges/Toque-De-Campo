# Revisão global de presença de áudio de combate — 08/11/2026

## Motivo

Ao jogar na Favela, o usuário percebeu que armas e explosões já ficavam pouco perceptíveis a algumas centenas de metros. **400 m foi uma observação, não uma meta de alcance.** A alteração atende todos os modos que utilizam `GameWeaponAudio` e `GameExplosionAudio`, incluindo Guerra/Favela, Afeganistão, Ucrânia e disparos e explosões compartilhados em BR/Deserto/Naval.

## O que foi ajustado

- `scripts/sound_propagation.gd`: curva única de **presença de combate**, somada ao ganho antigo e pequeno de 5% a 600 m. A curva de distância do `AudioStreamPlayer3D`, a posição do som, o cálculo do atraso de 343 m/s e o alcance máximo dos perfis permanecem intactos. O ganho é derivado da perda acústica inversa para evitar uma amplificação excessiva no intervalo intermediário.
- Calibração de origem: +3,5 dB na proximidade imediata; compensação parcial de 78% da atenuação inversa de referência de 240 m; chega a aproximadamente **+10,1 dB a 400 m**, a **+12 dB a 600 m** e ao teto de **+12,5 dB a partir de cerca de 700 m**. Essa curva garante que mesmo os canhões de maior unidade de distância continuem perdendo intensidade quando se afastam. Isso é amplitude na fonte, não nível percebido no mundo real. O ganho antigo de 5% a 600 m acrescenta cerca de 0,42 dB e foi preservado.
- `scripts/weapon_audio.gd`: aplica a curva a todos os disparos (pistola, G3, AK, FAL, snipers, MGs, 30 mm e armas pesadas); não aplica aos movimentos corpo a corpo e ferramentas. O teto do emissor individual foi aumentado de -3 para +2 dB (armas pesadas +3 dB), com o Master protegendo a soma final. Oclusão das armas foi suavizada de -8 para -4,5 dB e o filtro bloqueado atualizado, mantendo a percepção de parede.
- `scripts/explosion_audio.gd`: curva aplicada a todos os tipos (granadas, tanque, destruição, drone, míssil, 30 mm no solo/metal), incluindo o crossfade de WAV próximo e distante. O filtro de explosão atrás da parede deixa mais corpo.
- `scripts/audio_settings.gd`: um único `AudioEffectLimiter` na saída final, com teto de -1 dBFS, evitando somar fontes acima do pico máximo. Não substitui controles do usuário; Master/Efeitos/Armas mantêm seus ajustes e funções.

## Verificação

- Teste dedicado: `tests/combat_presence_audio_20261108.gd`. Mede perfis de armas e explosões, distância, corpo a corpo sem aumento, oclusão e o Master, além de verificar relação de amplitude PCM a 400 m num sinal contínuo passando pelo mixer real e estresse de armas + detonações.
- Teste legado: `tests/audio_far_gain_20261104.gd` atualizado para preservar a verificação do ganho original de 5% **em acréscimo** à curva nova, sem fazer o teste declarar que 50 m segue idêntico.
- Teste multiplayer `tests/war_audio_remote.gd`: expectativa de parede recalibrada para a atenuação proposta.
- Regressão de G3, explosões V3, APC 30 mm, 3D frente/trás, tiros e impactos deve continuar sem mudanças funcionais.
- Resultados Godot 4.7.2 (GTX 1650/Compatibility): teste global **103/103 PASS**, 3,20–3,24× de amplitude observada no mixer a 400 m (referência PCM constante), 13 pontos de distância monotônicos e pico no estresse de seis armas + duas explosões limitado a 0,891 (≈−1 dBFS). Regressões: ganho de 5% **17/17**, controles/voz **57/57**, direção **19/19**, explosões **18/18**, APC 30 mm **36/36**, passagem de balas **4/4**, blindado **14/14**.
- ENet nativo revisado em 09/11/2026 com servidor headless e cliente Godot/GTX 1650 independentes: **82/82 tiros recebidos, 289/289 verificações de áudio aprovadas no cliente e 3/3 validações aprovadas no servidor**, entre 50 e 600 m (50, 100, 200, 300, 400 e 600), Guerra/Deserto, Glock/FAL/sniper, FPP/TPP, direção e obstrução. O primeiro bloqueio estava no teste: faltava `GameNetworkPeers.watch(transport)` antes da conexão. A janela RMS foi normalizada para evitar a captura de silêncio extra quando o Windows apresenta travada de quadro. Capturas PCM e logs em `work/combat-presence-enet-20261109/` (ignorados pelo Git).
- **Dados PCM no cliente, Guerra/FPP (RMS normalizado)**: Glock 400m = 0,0368 e 600m = 0,0176; FAL 400m = 0,0579 e 600m = 0,0427; sniper 400m = 0,1372 e 600m = 0,1098. Na matriz principal, **60/60 pares de distâncias adjacentes** diminuíram estritamente em RMS. Esses números são relativos ao mixer, não a nível de pressão sonora física.
- **Ressalva de estabilidade:** uma das execuções longas terminou com acesso inválido do Godot Windows (`0xC0000005`) **depois** de registrar os 82 eventos e os testes como aprovados. Em execuções anteriores o servidor saiu normalmente, e 3 testes isolados de inicialização/encerramento também passaram. A causa do encerramento intermitente **não foi isolada nem homologada**. O teste ENet mediu tiros remotos, não detonações replicadas nem uma partida completa com 28 bots; esses testes ainda precisam de execução específica.
- A validação humana ainda é fundamental: conferir fones a volumes confortáveis, FPS e sobreposição com 28 bots. Não anunciar a sensação sonora como aprovada só por passar no teste automático.

**Limites:** não há mudança de dano, balística, IA, rede, mapa, arquivos WAV/MP3, cadência ou publicação do jogo. A dinâmica de prioridade/ducking entre sons fortes ainda é tarefa distinta do plano mestre.

## Segurança e reversão

A curva é centralizada em `GameSoundPropagation.combat_presence_db` e pode ser retocada por valores constantes numa única função. A presença mais alta exige o limitador final, evitando distorção de pico na soma de dezenas de fontes; antes de jogar, conferir os controles pessoais de volume e começar num nível confortável.
