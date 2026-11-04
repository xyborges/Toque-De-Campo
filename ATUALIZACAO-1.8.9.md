# 1.8.9 — postura e inclinação lateral

## Correções do personagem

- Cabeça, tórax e ombros acompanham a mira vertical, com limites distintos para coluna e pescoço. As hitboxes continuam presas às partes correspondentes.
- O posicionamento da arma parte do ombro. O deslocamento antigo era rotacionado a partir da câmera e recuava a empunhadura para dentro do tórax ao olhar para baixo. Os punhos agora permanecem à frente do colete e os cotovelos dobram para fora, mantendo contato com as empunhaduras.
- Inclinação revisada após a primeira captura: removido o deslocamento lateral excessivo do tórax. A cintura permanece sobre a pelve, o quadril desloca apenas 4 cm e as pernas compensam lateralmente para conservar o apoio dos pés. A rotação máxima é de aproximadamente 10 graus, com transição suave.
- A rotação lateral é aplicada ao redor do eixo da mira depois da elevação. Isso evita desviar o cano lateralmente ao inclinar e mirar para cima/baixo.

## Controles e multiplayer

- Segure Q/E para inclinar à esquerda/direita; soltar retorna ao centro. As teclas podem ser alteradas nas configurações.
- A câmera verifica o volume da cabeça contra obstáculos; a postura recua quando encontra uma parede. Não fica ativa enquanto morto, nadando, em veículo ou com controles bloqueados.
- O estado lateral segue nos pacotes de movimento existentes. O servidor verifica valor finito, limites, vida, situação do personagem e colisão antes de aplicá-lo. Não há RPC adicional por articulação.
- O Guerra e o Deserto utilizam o mesmo sistema de infantaria. O reabastecimento na caixa do Deserto passa de E para F.
- Protocolos Guerra 21 e infantaria 8. Cliente e servidor devem ser atualizados juntos.

## Continuidade visual e biblioteca

A biblioteca de nove objetos da 1.8.8 foi preservada: árvore, árvore queimada, trincheira, estrada, contêiner, cais, barreira, escada e ruína, com materiais/colisões e agrupamento de detalhes existentes. Nenhuma cena de montagem do usuário foi sobrescrita.

As duas figuras de referência agora incluem animações nativas de mira, inclinação e recarga, amostradas a partir do rig jogável. Abra VER-BIBLIOTECA.bat e pressione P para alternar. FAL, Glock, Guarani e os objetos continuam na mesma galeria. Isso é uma continuação do acabamento; não converte o restante do mapa procedural nem declara todos os modelos concluídos.

## Testes

- `tests/pose189_validation.gd`: 2.214 verificações, incluindo quatro armas, cinco elevações, três inclinações, contato das mãos, amostragem dos dois segmentos de cada braço contra o núcleo do tronco, conexão cintura/pelve, apoio dos pés, alinhamento do cano, miras de ferro, região física da cabeça, bloqueio por parede e estados incompatíveis.
- `tests/pose189_network.gd`: servidor e dois clientes com DTLS, 62 verificações. Ambos os sentidos de inclinação observados e aplicados pela autoridade; mira vertical, recargas, drone, APC, míssil TV, morte e respawn.
- `tests/pose189_desert.gd`: servidor e dois clientes com DTLS, 35 verificações. Rajadas da FAL durante a inclinação, Glock, granada, recarga normal, morte, respawn e postura do jogador remoto. Dois registros DTLS tardios de sessões já encerradas permaneceram nos logs do servidor, sem falha de gameplay.
- `tests/pose189_gallery.gd`: 14 verificações dos clipes salvos, conexão da cintura e troca de animação com P, além de capturas nativas.
- Regressões anteriores: 188 verificações da biblioteca/rig, 56 de recarga, 15 de estado de combate e 15 de infantaria. O teste antigo de infantaria emitiu aviso de dois ObjectDB no encerramento; o aviso não foi tratado como medição de desempenho nem como crash do jogo.

## Desempenho

Comparação isolada na GTX 1650, SubViewport 1920×1080, 12 soldados, duas armas/recargas e nove objetos; limite 120 FPS. O teste posterior acrescenta a inclinação animada:

| Medida | Antes | Depois |
|---|---:|---:|
| FPS médio | 120,07 | 120,07 |
| 1% low | 103,63 | 111,38 |
| Frame p95 | 8,62 ms | 8,58 ms |
| Pico | 10,50 ms | 9,46 ms |
| Draw calls | 619 | 619 |

Resultados brutos em `tests/pose189-benchmark-before.json` e `tests/pose189-benchmark-after-results.json`. O limite de quadros e a variação entre execuções impedem atribuir o aumento do 1% low a uma otimização. Não é um benchmark de partida completa com 12 jogadores no mapa Guerra.

## Publicação

Publicado no Ubuntu como 1.8.9 build 60, com cliente, serviços e novidades atualizados juntos. Pacote cifrado e cinco verificações de proteção passaram. O atualizador foi baixado pelo HTTPS real, instalado e executado novamente sem baixar de novo. Após a publicação, duas contas reais concluíram 25 verificações no servidor central (DTLS): Q/E nos dois sentidos, postura remota, FAL/AK/Glock, recargas, drone, morte por granada, respawn e disparo/saída do APC.

Na sessão de dois clientes, RTT mediano de 28 ms (cliente visual) e 35 ms (headless); frame mediano do cliente visual de 16,67 ms, p95 de 17,19 ms e pico de 81,62 ms. Há picos durante a sequência; esta validação não demonstra ausência de travadas no mapa completo.

