# Voz — captura e reprodução do cliente

Implementação local de 29/10/2026, Godot 4.7.2/Windows x86-64. Sem publicar o jogo. Integração de transporte e interface fica em `modes/battle_royale/voice/relay.gd` e nas configurações do jogo.

## Codec fixado

Godotopus v0.0.2 sem DNN, classes nativas criadas por `ClassDB` em tempo de execução. Mono 24 kHz, 480 amostras por pacote de 20 ms, alvo CBR 20 kbps, DTX para silêncio, FEC habilitado e PLC para perdas restantes. O binário sem DNN não usa DRED. Limite de 256 bytes por pacote; o receptor verifica duração e canais pelo cabeçalho Opus antes de decodificar.

`native/voice` contém DLLs Windows debug/release, configuração da extensão e avisos MIT/BSD do addon, Opus, SpeexDSP e godot-cpp. ZIP fixado por SHA-256 `069d54a3d128fcf3b2d4b647545866cbdc298f14ea846b6eb87799c22b4cb7db`; DLL debug `e70e045962fbc5ef67b0c98bf398f0917899070f7d5a3f8c6ae7b5a15c23902a`; release `c2fb27d317fd0f386641c0cefba4d716fdf88bd9b611986c734aaafd301976f5`.

O servidor não instancia codec nem captura áudio. Seu preset deve excluir `native/voice/*`. Ausência da DLL no cliente gera estado de voz indisponível, sem impedir a partida ou o parser da autoridade.

## Captura

Usa a API direta do AudioServer da 4.7. Não usa AudioEffectCapture, barramento de monitoração ou arquivos de gravação. `set_input_device_active(true)` apenas durante push-to-talk; ao soltar, morrer, perder permissão de fala ou sair, descarta buffers e desativa entrada. O microfone continua fechado durante a construção/configuração do codec.

Entrada estéreo do dispositivo vira mono; SpeexDSP converte a taxa real de entrada para24kHz. Falha ao criar o conversor impede transmissão em uma taxa errada. Uma travada descarta áudio antigo, com acumulação máxima de 100 ms antes de reduzir para os 40 ms recentes; no máximo 3 pacotes são codificados num quadro do jogo. Falha de abertura do dispositivo aguarda soltar/apertar novamente, evitando tentativas e mensagens a cada quadro. Dispositivo sem mudança não reabre captura nas atualizações de configuração.

WASAPI neste computador precisou de aquecimento na primeira abertura: em 120 ms ainda não havia amostras, mas em 350 ms retornou 9600 quadros a 48 kHz, convertidos em 4800 amostras a 24 kHz. Nenhuma fala foi transmitida, ouvida ou gravada nesse teste. O tempo de abertura inicial é separado de rede/DTLS.

## Recepção espacial

No máximo 6 falantes mais próximos recebem decodificador; um mais próximo substitui o mais distante. Áudio acompanha a âncora da cabeça do personagem, inclusive agachado/deitado. Ganho permanece claro na distância definida (padrão 10 m) e cai até o limite configurado (máximo 40 m), com estéreo 3D e volume próprio.

Jitter inicial de 60 ms; fila de pacotes limitada a 12 quadros, com descarte para 3 recentes após travada. Decodificação ocorre por tempo, sem descarregar dezenas de pacotes num único quadro. Usa FEC do pacote seguinte para a lacuna e no máximo 3 PLC consecutivos. O gerador recebe 3 quadros antes de começar, para evitar underrun na primeira mistura do driver; a fila de saída é medida separadamente da fila de rede. Mute, morte, outra vida, saída, fim de fala e distância removem voz/buffers. Jogador morto/espectador não captura nem reproduz vozes de vivos.

Ao sair da partida, `shutdown()` bloqueia transmissão e recepção, para a captura, descarta PCM/jitter, libera imediatamente codificador e decodificadores nativos e limpa os dados de presença, roster, sequências e falantes da sala. A última instância libera também o barramento Voice se o jogo o criou; um barramento preexistente é preservado. Chamadas repetidas e pacotes atrasados não reativam a sala. Preferências da conta continuam salvas; IDs temporários da sala não passam para a próxima. `reset()` continua sendo usado apenas na mudança de rodada dentro da mesma sala.

## API

`scripts/voice/client.gd`: `configure(context)`, `available()`, `status()`, `set_enabled`, `set_volume`, `set_audible_range(clear,radius)`, `set_input_device`, `set_transmitting`, `receive_frame(id,life,seq,packet)`, `remove_speaker`, `reset`, `shutdown`, `stats`. Sinais `encoded_frame`, `transmitting_changed`, `availability_changed`. O contexto fornece `voice_local_allowed()`, `voice_speaker(id)`, `voice_muted(id)` e opcionalmente `voice_listener_position()`; caso contrário usa o personagem local do jogo.

## Verificação realizada

- `tests/br_voice_codec_validation.gd`:423 verificações, 400 quadros nativos, 20 kbps com DTX desligado apenas na medição de bitrate (tom contínuo não é fala). DTX testado separadamente com silêncio. Conversor48k→24k testado. Perda determinística de 1/9 dos pacotes, atraso e reordenação:402 quadros de saída, 51 FEC, 8 PLC, pico de 4 pacotes na fila; duplicatas/atrasados/duração inválida rejeitados. PTT, mutes, vida, morte,6 vozes e despejo de backlog verificados. Relatório `work/br-voice-codec-validation.json`.
- `tests/br_voice_audio_probe.gd`: reprodução sintética silenciada no WASAPI real, AudioStreamPlayer3D ligado ao falante e gerador a 24 kHz. 80 pacotes, 35584 amostras consumidas, 37,3 ms na fila de saída ao observar, zero skips ou resets. Checagem de 350 ms de entrada conservou somente contagens/taxas, nunca áudio. Relatório `work/br-voice-audio-probe.json`.
- Executável mínimo de QA exportado com template release 4.7.2 e DLL release: 100 quadros codificados/decodificados, 5000 bytes, `editor=false`, `release=true`, sem microfone. Projeto isolado `work/voice-client-export`, relatório `work/br-voice-release-smoke.json`. Não é exportação/publicação do jogo.
- `tests/run_br_voice_network.ps1`: 15 verificações com servidor e quatro clientes ENet/DTLS reais, canal não confiável3. Proximidade, mute, alcance, morte, vida/rodada antiga, tamanho, rajadas, repetição, fim e limpeza de desconexão.14 quadros encaminhados,36 recusas esperadas. Usa pacotes sintéticos no transporte, sem decodificação ou captura nesse cenário; relatório `work/br-voice-network.json`.
- `tests/br_voice_lifecycle_validation.gd`:13 verificações de encerramento/reentrada com Opus nativo sintético, referências nativas liberadas, microfone físico nunca ativado, buffers/PCM/roster/presença vazios, barramento temporário liberado e pacotes tardios rejeitados. Relatório `work/br-voice-lifecycle-validation.json`.

As verificações não avaliam subjetivamente conversas humanas ou latência acústica ponta a ponta pela VPN. A análise do protocolo real e do filtro de destinatários pertence ao teste de rede do relay, separado da compatibilidade do codec e do driver.

Referências primárias: [API AudioServer 4.7](https://docs.godotengine.org/en/4.7/classes/class_audioserver.html), [Godotopus v0.0.2](https://github.com/Mako-Mako-Games/godotopus/releases/tag/v0.0.2), [licença MIT do projeto](https://github.com/Mako-Mako-Games/godotopus/blob/main/LICENSE.md), [Opus RFC 6716](https://www.rfc-editor.org/rfc/rfc6716).
