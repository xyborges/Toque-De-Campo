# Arquivos fornecidos pelo usuário em 23/10/2026

- `pistol-109.wav`: `sound_109.wav`, novo disparo da pistola.
- `explosion-115.wav`: `sound_115.wav`, variação de explosão.
- `explosion-114.wav`: `sound_114.wav`, variação de explosão.
- `explosion-112.wav`: `sound_112.wav`, variação de explosão.

Copiados dos anexos temporários para recursos permanentes do projeto. O caminho dos anexos menciona “Sound Pack for RSL MOD by Matihuano”. Os arquivos não foram produzidos por este projeto; nenhuma licença adicional é presumida.

As variações de explosão são escolhidas a partir do identificador compartilhado do evento: todos os clientes escolhem a mesma amostra, com posição, atenuação e oclusão calculadas localmente. Nenhum WAV é transmitido durante as partidas.

Os arquivos 114 e 115 recebidos são idênticos (SHA-256 `18bda25d5f2dd7e824e573c92c49429d304861463ae0f36f3e5e2da7502ee92f`); os dois nomes foram preservados. Há três entradas no catálogo e duas gravações distintas.

Cada explosão utiliza uma voz espacial própria, fixada na origem do evento. Até 24 caudas podem se sobrepor; ao atingir esse limite, a mais antiga é substituída. Ganho de −12 dB e limitadores no barramento evitam somas de várias amostras em volume máximo. Eventos repetidos são descartados. A pistola utiliza o mesmo catálogo no Offline, Deserto e Guerra.

Validação local: `tests/supplied_audio.gd`, 43 verificações aprovadas, incluindo carregamento dos quatro WAVs, disparo real de áudio da pistola, reprodução naval e Guerra, igualdade entre dois clientes, posições independentes, repetição de eventos e carga de 80 explosões.
