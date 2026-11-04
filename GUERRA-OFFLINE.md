# Guerra offline

## Integração

A operação offline utiliza o mesmo `WarGame`, terreno, personagens, classes, veículos, hitboxes, projéteis, objetivos, tickets e HUD da operação online. Não abre um servidor ENet nem conecta a uma sala. `OfflineMultiplayerPeer` mantém a autoridade no processo local; `online` permanece `false`.

O jogador escolhe equipe, classe, armamento e ponto de implantação normalmente. Após a primeira implantação, a operação adiciona cinco aliados e seis oponentes, mantendo seis integrantes de cada lado. A seleção da outra equipe também é atendida. O placar offline mostra estatísticas de combate e objetivos, sem apresentar ping como se existisse uma conexão.

As operações locais não enviam eliminações, recompensas ou moedas aos serviços de conta e ranking global.

## Bots

`WarBotDirector` só habilita processamento quando `offline_operation` é explicitamente verdadeiro, a simulação é local e o processo tem autoridade. O modo online não cria nem executa esses bots.

Os bots usam `WarPlayer` com armas e hitboxes de jogador. O indicador `is_npc` permanece falso porque os NPCs do treino original representam atacantes desarmados com outra lógica. O metadado `war_bot` identifica os integrantes controlados localmente.

Comportamentos implementados:

- Distribuição entre os objetivos A, B e C, com movimento, gravidade, colisão e separação entre personagens.
- Caminhos regionais em `AStarGrid2D`, seguindo a altura real de `WarTerrain`. Obstáculos estáticos e destroços são considerados, incluindo paredes finas entre os centros das células.
- Desvio próximo por consultas à física, rotas em cache e decisões escalonadas entre os integrantes.
- Aquisição de adversários com limite de distância e verificação de linha de visão.
- Disparo pelo mesmo método autoritativo usado pelos jogadores: cano real, projétil, dano por região, munição, cadência e recarga com reserva finita.
- Pequeno erro de mira e rajadas com intervalos, evitando tiro permanentemente perfeito.
- Reaparecimento pelo fluxo existente de implantação, preservando a classe e restaurando os recursos previstos pelo jogo.
- Médicos podem utilizar a cura existente em aliados próximos; soldados podem fornecer munição pelos recursos de suporte existentes.

Os veículos ficam disponíveis para o jogador humano. Nesta implementação os bots não pilotam blindados nem drones e não recebem rotinas autônomas de RPG, Stinger ou granadas. Essas armas e ações continuam disponíveis ao jogador pelas classes e equipamentos existentes.

## Navegação e orçamento

A grade regional tem células de 4 m e 88.101 pontos, cobrindo as duas bases e o setor dos objetivos ativos. Ela adapta a abordagem do `OfflineDirector` do treino existente, com amostragem do terreno de Guerra e colisores reais do mapa.

Somente um bot recebe uma decisão de caminho e alvo por quadro de física. Movimento e gravidade continuam atualizados em todos os quadros. A grade é construída na entrada da operação; não é reconstruída continuamente.

O teste isolado de navegação aprovou 13 verificações: cobertura, obstáculos, paredes finas, passagem sob um teto elevado, caminho contornando bloqueios, altura dos objetivos e bloqueio de execução fora do modo offline. O tempo de construção da grade isolada foi de aproximadamente 734 ms nesta máquina. Esse valor mede inicialização, não FPS de partida.

## Testes nativos

`tests/war_offline.gd` abre uma operação Godot nativa e verifica:

- Autoridade local, ausência de ENet e de chamadas aos serviços de conta.
- Formação de 12 integrantes, equilíbrio das equipes e quatro classes.
- Movimento espontâneo dos bots.
- Tiros reais do FAL controlados pela IA, dano, consumo de munição e recarga com reserva finita.
- Bloqueio por parede, headshot pelo sistema compartilhado e reaparecimento do bot.
- Captura de objetivo, tickets e pontos de participação.
- Saída, destruição do mundo e início de outra operação com equipe e classe diferentes.

As posições das verificações de combate e os participantes da fase curta de captura são organizados pela fixture para tornar o resultado repetível. O teste não injeta dano para provar o combate: o dano verificado é produzido pelos projéteis do sistema real.

`tests/war_offline_equipment.gd` cobre os comandos locais de blindado, câmera, zoom, drone, granada e seleção de equipamento antitanque. Os resultados JSON e as capturas ficam nas pastas `tests` e `work`.
