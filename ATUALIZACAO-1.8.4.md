# Toque de Campo 1.8.4 — portos, navios e movimento

## Correções e causas

- **Escadas e calçadas:** `CharacterBody3D.move_and_slide()` não sobe uma face vertical de degrau sozinho. O movimento compartilhado agora verifica espaço acima, à frente e abaixo da cápsula e transpõe degraus de até 42 cm. Jogadores, NPCs comuns e bots do Guerra utilizam a mesma rotina. Paredes altas e tetos baixos continuam bloqueando a passagem; o avanço horizontal não é duplicado.
- **Tiros em TPP:** o limite antigo de 3,8 m entre câmera e personagem rejeitava a câmera de ombro do Guerra na distância máxima. A validação agora considera o enquadramento permitido nesse modo, verifica posição e direção e mantém a checagem contra paredes. O disparo continua sendo validado pelo servidor.
- **Chão do porto:** o terreno e o piso do cais ocupavam a mesma altura. O terreno foi rebaixado sob o cais, eliminando a disputa entre superfícies. A malha do terreno recebe maior resolução junto aos portos.
- **Blindados nas ladeiras:** a orientação anterior considerava principalmente a inclinação longitudinal, com uma caixa inferior maior que a área de apoio. Quatro consultas ao chão agora consideram frente, traseira e laterais, incluindo pontes e rotação parada. A colisão inferior acompanha rodas/esteiras; a parte superior conserva o volume da blindagem.
- **Saída dos navios:** a busca de desembarque exigia solo seco. Agora prioriza píer livre e, na ausência dele, permite desembarque em água profunda livre para nadar. São verificados espaço para o corpo e trajeto de saída. O servidor libera o assento e promove passageiro quando necessário.

## Navios e portos

Os navios do Guerra utilizam a câmera de terceira pessoa do Naval, com zoom por clique. A visão e a moldura de óptica em primeira pessoa foram retiradas **somente dos navios**. Vida, velocidade, armas, munição e térmica permanecem. O ponto de mira desconsidera o próprio navio e seus ocupantes.

A baía fica no **oeste**, com duas extremidades ligadas à terra, entrada navegável, cais curvo, silos e transporte de granéis. O leste mantém costa aberta e recebe pátio de contêineres, armazém, administração, ferrovia e carga. Os guindastes receberam estrutura, cabine, contrapesos e cabos.

O terminal leste possui uma cena editável no Godot: `modes/war/scenes/east_port.tscn`. Consulte [Editar o porto leste](EDITAR-PORTO-LESTE.md). As peças permanecem editáveis na cena e são agrupadas por material durante o jogo. Referências reais e decisões de ambientação estão em [Referências dos portos](REFERENCIAS-PORTOS-1.8.4.md).

## Iluminação, destruição e passos

A noite ganhou iluminação ambiente mais legível, mantendo o ciclo completo de 14 minutos. Postes junto às ruas e aos portos ligam à noite quando há energia. Tiros e explosões podem quebrá-los no meio; a parte superior cai, os fios acompanham e a interrupção afeta o circuito. Restos permanecem no cenário, com estado enviado também a quem entra depois.

As luzes não projetam sombras individuais e têm limite de distância e quantidade ativa. As atualizações elétricas não alternam todas as luzes a cada consulta.

Passos usam o material de contato: grama, barro, asfalto e pedra possuem variações próprias. Permanecem o áudio espacial e a reprodução dos passos dos outros jogadores. A origem dos arquivos está registrada em `audio/ORIGEM-DOS-SONS.md`.

## Verificação local

- **45 verificações de movimento:** escadas com três degraus de 20 cm, descida, parede alta, teto baixo, materiais de contato e apoio de Abrams, T-90, Guarani e BMP-2 em quatro orientações sobre uma inclinação.
- **33 verificações na instância renderizada do Guerra:** tiros TPP em três distâncias e quatro direções, rejeição de origem inválida, portos/baía, câmera naval, zoom, térmica, HUD, desembarque, natação, iluminação e destruição dos postes.
- **22 verificações em quatro processos usando DTLS:** servidor, operador, passageiro e adversário. Incluem tiro em TPP, subida da escada com validação normal de movimento, disparos reais do navio alinhados ao cano, saída do operador, promoção de passageiro e transmissão do estado dos postes.
- **15 verificações de regressão do combate:** preservação dos estados de gatilho, granada e disparo da Glock/FAL da atualização anterior.

Resultados e logs: `tests/movement184-results.json`, `tests/war184-results.json` e `work/war184-network.log`. Capturas ficam em `work/war184-*.png`.

### Medição gráfica e limites

Godot nativo, GTX 1650, resolução **1536 × 864**, VSync desligado. Câmera noturna fixa no porto, seis segundos por caso, física dos bots suspensa durante a medição:

| Caso | FPS médio | 1% low | Frame médio | Pico |
|---|---:|---:|---:|---:|
| Luzes locais desligadas | 157,07 | 118,35 | 6,37 ms | 9,11 ms |
| Luzes locais ligadas | 150,83 | 119,23 | 6,63 ms | 8,86 ms |

Essa medição avalia o custo local da iluminação nessa cena. **Não é um benchmark de combate com 12 jogadores nem comprovação de 60 FPS em 1080p.** Os testes multiplayer verificam comportamento e sincronização, não representam essa carga gráfica completa.

## Arquivos principais

- Movimento: `scripts/step_motion.gd`, `scripts/player.gd`, `scripts/main.gd`, `modes/war/scripts/bot_director.gd`, `modes/war/scripts/player.gd`.
- Navios/câmera/HUD: `modes/naval/scripts/camera.gd`, `modes/war/scripts/vehicles.gd`, `vehicle_reticle.gd`, `ui.gd`.
- Terreno e portos: `modes/war/scripts/coast.gd`, `terrain.gd`, `harbors.gd`, `modes/war/scenes/east_port.tscn`.
- Apoio dos blindados: `modes/war/scripts/vehicle_ground.gd`, `vehicle.gd`.
- Postes e noite: `modes/war/scripts/power_pole.gd`, `power_grid.gd`, `game.gd`, `scripts/day_night.gd`, `scripts/grenades.gd`.
- Passos: `modes/war/scripts/soundscape.gd`, `roads.gd`, arquivos em `audio/`.

O protocolo do Guerra passa para **16**; os participantes precisam atualizar para esta versão para usar os novos eventos de destruição.

## Publicação confirmada

Publicada no Ubuntu em 26/10/2026 como **1.8.4, build 54**, incluindo site de download, notas da atualização, launcher e servidores. Os serviços Guerra, Deserto e Naval estão ativos em `/opt/toque-de-campo/releases/build-54`.

Verificados no servidor: download HTTPS com a autoridade esperada, igualdade do manifesto e dos arquivos, instalação real pelo launcher e segunda verificação sem baixar novamente. O runtime exportado abre seu pacote criptografado; o Godot convencional não lê o diretório protegido, e substituições externas de script/pacote são bloqueadas. Isso dificulta inspeção e substituição simples dos arquivos, sem constituir garantia de proteção absoluta contra engenharia reversa.

Evidências de publicação: `work/war184-deploy.log`, `work/war184-download-verification.log`, `work/war184-server-status.log`, `tests/ubuntu-distribution-results.json`.
