# Toque de Campo — atualização 1.7.1

Publicada em 25/10/2026 no Ubuntu `192.168.101.24`, **build 40**. Site, instalador, atualizador e serviços Guerra, Deserto e Naval utilizam o mesmo pacote. Todos os participantes precisam atualizar. As versões de referência Three.js/Babylon permanecem preservadas.

## Sniper, trajetória e traçantes

- Velocidade inicial da sniper: **620 → 607,6 m/s**, redução exata de 2%. Alcance de 2.200 m, gravidade 12 e arrasto 0,008 preservados.
- Núcleo violeta mais luminoso, contorno e largura ajustada à projeção para continuar perceptível de dia, sem crescer exageradamente com a luneta.
- O rastro usa o segmento percorrido pelo próprio projétil. O blur acompanha sua direção e termina no impacto; não existe uma segunda bala visual com física independente.
- Resistência contínua aplicada também aos caminhos que ainda não a utilizavam: RPG, Stinger, TV e armas navais. Mantidas as velocidades iniciais das outras armas.
- No Naval, solução de mira, guia, colisão, posição visual e simulação do servidor utilizam a mesma integração, incluindo velocidade herdada do navio em **X e Z**. O tempo de alcance considera o arrasto.

O modelo adotado é **arrasto linear com integração analítica**, já existente na física compartilhada de infantaria. A desaceleração depende da velocidade atual, sem cortes artificiais por distância. Não foi implementado arrasto quadrático nem uma simulação aerodinâmica científica. Essa escolha mantém a previsão determinística e evita diferenças causadas pelo tamanho do passo de atualização. Gravidade atua durante todo o voo; a perda de velocidade e a queda são efeitos distintos.

## Áudio espacial e distância

- Disparos e explosões têm atraso por distância, usando **343 m/s**. Eventos remotos consideram a idade disponível do evento; isso continua sendo uma aproximação, não propagação acústica completa em um ouvinte móvel.
- Crack supersônico separado do disparo quando a velocidade real supera 343 m/s. Munição mais lenta usa passagem/assobio. Apenas projéteis próximos ao ouvinte acionam esses sons.
- Tratamento próximo, médio, distante, obstruído e interno: filtros e reverberação compartilhados; paredes abafam sem silenciar totalmente. Preservado o abafamento na cabine dos blindados.
- Impactos de terra, lama, concreto, metal, madeira, veículo e água partem do contato real. O servidor resolve a superfície; transmite um evento, nunca áudio bruto. Novos contatos sintéticos estão em `audio/ballistics`, com documentação de origem.
- Alcance sonoro por arma: Glock 600 m, FAL 1.200 m, sniper 2.400 m, metralhadoras 1.800 m e armas pesadas até 3.000 m; explosões até 2.400 m. A intensidade cai progressivamente, inclusive perto do limite.
- No Naval, o ouvinte fica na ponte do próprio navio: afastar a câmera ou ampliar a mira não altera artificialmente a distância de audição.
- Pools pré-aquecidos: 96 vozes de armas, 24 de explosões e 12 de feedback. Fila limitada a 256 eventos por agendador, com prioridade por proximidade/importância. Eventos antigos após travamentos/pausa são descartados, e a saída da partida cancela sons pendentes.
- Verificação de obstáculos usa orçamento e cache; efeitos de áudio não são alocados por disparo.

## Fumaça e ciclo de iluminação

- Fumaça de impactos pesados começa transparente, cresce gradualmente e possui uma saída mais longa. O clarão inicial permanece rápido.
- Oito puffs pesados no lugar de doze, com pequena defasagem entre emissões, duração entre 4 e 5,5 s e pool MultiMesh limitado. Sem novas luzes ou corpos físicos por puff.
- Fumaça de explosões navais e granadas também utiliza envelope gradual. O pavio das granadas permanece em 5 s.
- O ciclo completo de 24 horas dura **840 s / 14 minutos** em Offline, Deserto, Guerra e Naval. O tempo regulamentar das partidas não foi alterado.

## Principais arquivos

| Área | Arquivos |
|---|---|
| Física e armas | `scripts/weapons.gd`, `combat_rules.gd`, `bullet_physics.gd`; `modes/war/scripts/projectiles.gd`; `modes/naval/scripts/ballistics.gd`, `match.gd`, `projectile_visual.gd` |
| Visual dos disparos | `scripts/tracer_style.gd`, `combat_visuals.gd`; `shaders/projectile_trail.gdshader`; renderização de projéteis de Guerra |
| Áudio | `scripts/sound_propagation.gd`, `weapon_audio.gd`, `explosion_audio.gd`, `combat_feedback.gd`, `impact_surface.gd`; `audio/ballistics/*` |
| Integração e contatos | `scripts/main.gd`, `environment/environment_kit.gd`; `modes/war/scripts/game.gd`, `vehicles.gd`; `modes/naval/scripts/world.gd`, `mode.gd` |
| Fumaça e relógio | `scripts/effect_envelope.gd`, `day_night.gd`, efeitos de granada; efeitos de Guerra e Naval |
| Compatibilidade e publicação | Protocolos Guerra 12, Naval 6, implantação Deserto 2; `distribution/release-notes.json` |

## Validação

Os relatórios detalhados e caminhos das evidências estão em `tests/release171-final-status.json`. Testes locais usam instâncias próprias; as verificações centrais usam contas QA reais e não substituem partidas de usuários.

| Cenário | Resultado |
|---|---|
| Física, som, filas, fumaça, superfícies e limpeza | 39 verificações sem falhas. Tiro físico a 1.000 m: impacto em 1,666 s; disparo ouvido em 2,949 s, com captura PCM real. |
| Visibilidade da sniper | Renderização nativa diurna a 100/600/1.000 m, FOV 70° e 7°; pixels visíveis nos seis casos e erro zero da ponta em relação à posição física. |
| Áudio remoto | Dois processos ENet independentes; 3 verificações na origem e 195 no observador. 58 eventos com as gravações reais, captura estéreo, filtros, oclusão, distância e coerência FPP/TPP. |
| Sniper de Guerra | 18 verificações, com alvos físicos a 300/800/1.200/1.800/2.000 m. |
| Naval | Física: 15; arsenal: 100. Rede com 5% de perda e atraso de 20–65 ms; disparos, dano, destruição, respawn e entrada tardia sem falhas na rodada final. |
| Implantação/UI | Offline: 30; Guerra com 11 bots: 15; Naval: 14, incluindo posição do ouvinte no navio. |
| Equipamentos e câmera TV | 80 e 53 verificações, respectivamente. |
| Combate/térmica/áudio no código final | 25 verificações; inclui tanque a aproximadamente 850 m com crédito de abate e dano, proteção por parede e térmica a 1.200 m. |
| Abafamento da cabine | Voz real de explosão encaminhada para `WarCabinWeapons`; teste nativo, sem falhas. |
| Movimento TPP | 420 quadros, mais de 435° de giro e aproximadamente 43 m; sem apresentação FPP sobreposta. |
| Pacote exportado | Inspeção executada a partir do PCK, fora da árvore de fontes: recursos de física, áudio, temas, músicas, mapas e novas versões de protocolo presentes. |

No servidor publicado foram repetidas as conexões de Guerra (operador/oponente/passageiro), Deserto (dois jogadores com granadas e implantação) e Naval (duas contas, prontidão, disparos replicados e liberação do gatilho). A verificação de distribuição baixa o executável real, confere o hash, instala o pacote assinado, executa novamente sem baixar e inicia o executável de produção. Resultado final registrado no JSON de fechamento.

## Desempenho medido

Comparação entre **PCK 1.7.0/build 38 e PCK 1.7.1/build 40**. GTX 1650, 1920×1080, limite de 60 FPS, iluminação diurna fixa para comparação. Doze clientes ENet e servidor no mesmo PC; somente o operador renderiza, com térmica, veículos, drones, disparos, explosões e desconexão de um cliente. Fixture de invulnerabilidade, cerca de 25 s úteis de combate por execução. Não representa doze PCs humanos nem uma sessão longa pela internet.

| Medida do cliente renderizado | Antes | Depois |
|---|---:|---:|
| FPS médio | 57,95 | 57,22 |
| 1% low | 21,16 | 27,78 |
| Frame time médio | 17,26 ms | 17,48 ms |
| Frame time p95 | 21,00 ms | 23,28 ms |
| Maior frame time | 254,70 ms | 52,51 ms |
| FPS médio com térmica | 57,58 | 56,66 |
| 1% low com térmica | 19,25 | 26,73 |
| Memória do processo | 225,13 MiB | 230,06 MiB |
| Maior frame na janela de desconexão | 23,07 ms | 19,54 ms |

Os picos mais severos diminuíram nesta amostra, mas a média e o p95 não melhoraram; **não há comprovação de 60 FPS estáveis**. A sequência de combate não é um replay quadro a quadro: até 63 projéteis simultâneos no baseline e 127 na execução final. Não é possível atribuir toda diferença a uma alteração isolada. Repetições e hardware adicional são necessários para uma conclusão estatística.

Evidências: `tests/benchmark171-before171-thermal-noprof.json` e `tests/benchmark171-pack171-final-thermal-noprof.json`. Medidas são dos monitores nativos e tempos de quadro do Godot; não são uma captura interativa da aba Profiler do editor. Execuções intermediárias foram preservadas, sem substituir o resultado final pelos melhores números.

## Referências técnicas

- [Godot — AudioStreamPlayer3D](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer3d.html): reprodução espacial e atenuação.
- [Godot — AudioEffectCapture](https://docs.godotengine.org/en/stable/classes/class_audioeffectcapture.html): captura PCM usada nas verificações de áudio.

Download e atualização: [Toque de Campo](http://192.168.101.24/).
