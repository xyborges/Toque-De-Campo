# Atualização 1.13.3 — fumaça tática, veículos e miras

**Estado:** CANDIDATA em 04/11/2026.

## Conteúdo

- Granada M18 selecionável, com pavio de 4 segundos, nuvem persistente e comportamento autoritativo sem dano explosivo.
- Cortinas de fumaça para Abrams, T-90, BMP-2 e Guarani, com duração, recarga, LOD, agrupamento e áudio 3D limitados.
- Zeragem balística por arma em passos de 50 m, validada e recalculada pelo servidor.
- Moto revisada no Guerra e Battle Royale, com piloto, garupa, guidão, apoios e restauração da pose ao sair.
- Modelos dos blindados com torres, canhões, coaxiais e lançadores visualmente conectados.
- Bases, baias, estrada de descida, nascimento de bots e controle de veículos revisados no Afegão.
- Marcadores de objetivos projetados pela câmera das ópticas 4× e 8×.
- Tela de preparação imediata antes de abrir partidas e transições de retorno ao menu.

## Verificações concluídas antes do candidato

- Modelos de blindados: 34/34 verificações estruturais.
- Tomada do piloto bot e baias afegãs: 16/16 verificações.
- Moto e garupa: 47/47 verificações de pose e embarque no Guerra.
- Marcadores nas lunetas: 25/25 verificações renderizadas na GTX 1650.
- Zeragem balística: 58/58 verificações, incluindo validação autoritativa.
- Granada M18 e cortinas de blindados: 54/54 verificações.
- Áudio de fumaça: 30/30 verificações.
- Scan do projeto no Godot 4.7.2 sem erro de script.
- Recursos preparados: `tests/maps_prepared.gd` passou **11.992.060/11.992.060** verificações; guard de identidade/navegação passou sem erros.
- Navegação BR afegã: **115 regiões, 508 links, 640 spawns e 12/12 abrigos v13 acessíveis**.
- `python tools/maps.py validate --map all`: Ucrânia, Afeganistão, Deserto, Escritório e Naval sem erros; permanece o aviso conhecido de 1/162 anchors afegãos rejeitado e avisos Jolt de encerramento headless.
- Moto BR em ENet/DTLS: **24/24** verificações com servidor e dois clientes.
- Rede de granadas: 12 verificações funcionais somadas entre servidor, atirador e alvo, sem falhas de lógica; o teardown DTLS ainda registra avisos `-30464` após o teste terminar.
- `br_queue_screen_validation`: quatro falhas no fluxo SAIR/teardown foram reproduzidas sem diferença na 1.13.2 e na candidata, portanto permanecem dívida de QA preexistente.
- A suíte legada `war_multiplayer` também reproduziu na 1.13.2 as mesmas falhas de balanceamento/deploy/cura observadas na candidata; não foi tratada como regressão desta integração.

## Fora desta versão

- O CollisionRig/FPP-TPP experimental permanece fora da atualização por ainda ter trabalho ativo e regressão de desempenho registrada no ensaio de 28 atores.
- Mixer dinâmico global e ducking de combate continuam pendentes.

Os resultados finais de mapas, instalação assinada, publicação e serviços serão registrados após a validação do candidato.
