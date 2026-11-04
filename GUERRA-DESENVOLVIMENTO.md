# Modo Guerra — 1.6.1 publicada, build 27

Atualizado em 24/10/2026. Guerra está disponível no mesmo Toque de Campo, ao lado de Offline, Naval e PvP Deserto. O build 27/1.6.1 foi publicado no Ubuntu e validado com três contas reais, download e launcher. Resumo atual e controles em [ATUALIZACAO-1.6.1.md](ATUALIZACAO-1.6.1.md); a estreia do modo permanece em [ATUALIZACAO-1.6.0.md](ATUALIZACAO-1.6.0.md).

A especificação original está preservada em `work/guerra-especificacao.txt` e a base anterior em `work/before-war-1.5.0/`.

## Integração entregue

- Mesmo projeto e mecanismos compartilhados de personagem, combate, hitboxes, inventário, tema, autenticação e efeitos. Cena e autoridade próprias de Guerra preservam os outros modos.
- Terreno físico de 2 × 2 km com trincheiras, crateras, estradas, povoado, obstáculos e materiais variados. Visual, colisão e spawn usam a mesma triangulação.
- Conquista A/B/C, 300 tickets e vinte minutos. Neutralização antes da captura, disputa, retenção/regressão de progresso e implantação validada. D/E permanecem definidos e inativos; bases não são conquistáveis.
- Online: até doze jogadores, seis por equipe. Escolha de equipe respeita capacidade e diferença máxima de um integrante; combate pontuado depende de participantes nas duas equipes.
- Médico, Soldado, Antitanque e Atirador possuem uniforme/equipamento e recursos próprios. Mudanças durante a vida são aplicadas no próximo respawn. RPG e Stinger usam validação autoritativa, munição/cargas, alcance e linha de visão.
- Guarani/Abrams para a Equipe 1; BMP-2/T-90 para a Equipe 2. Um operador dirige e atira; APCs transportam até cinco passageiros e tanques um. Passageiro usa câmera independente, sem controlar armas. Reserva, entrada, saída segura, promoção do mais antigo, morte e desconexão são autoritativas. Destruição mata todos os embarcados; após 60 segundos o veículo retorna íntegro e vazio à própria base.
- Torres compensam a rotação do casco; elevação, geometria visível e marcadores dos canos determinam os disparos. Há óptica, térmica, munição e recarga. Drones possuem limite por equipe, integridade, bateria e alcance.
- Uniformes acompanham os pivôs animados e o ragdoll. Câmera sobre o ombro usa SpringArm e prevenção de colisão. Limpeza de desconexão revoga controles antes da destruição diferida dos objetos.

## Modelos e armamentos

Geometria própria inspirada em referências reais: Guarani 6×6/REMAX-M2, BMP-2/2A42, Abrams/M256 e T-90/2A46. Foram revistos casco, rodas/esteiras, torre, canhão, ópticas e acessórios. Valores de blindagem, mobilidade, dano e cadência são balanceamento do jogo, não capacidades reais.

As partes que pareciam transparentes eram superfícies sem referência no índice do agrupamento de malhas. A indexação foi corrigida e os materiais continuam opacos. Vistas nativas de frente, lateral, traseira, armas e LOD foram conferidas. Os detalhes dão lugar à silhueta distante a partir de 160 m. Ver [GUERRA-MODELOS.md](GUERRA-MODELOS.md).

## Guerra offline

**Jogar → Guerra → Treino offline · Bots**. Uma pessoa e cinco aliados enfrentam seis adversários. É a mesma operação, com autoridade local por `OfflineMultiplayerPeer`, sem abrir ENet, autenticar em servidor ou conceder moedas/ranking global.

Os bots usam `WarPlayer`, quatro classes, terreno/obstáculos, linha de visão, cano real, projéteis, dano por região, munição finita, recarga, respawn e conquista. Médicos podem curar aliados e soldados fornecer munição. Nesta versão os bots não dirigem blindados/drones nem usam autonomamente RPG, Stinger ou granadas; esses equipamentos continuam disponíveis ao humano.

O parâmetro `--war-offline` abre diretamente a implantação. Na cópia de desenvolvimento, `JOGAR-GUERRA-OFFLINE.bat` faz essa entrada. Sair encerra IA e operação; começar novamente limpa objetivos, tickets, equipe e classe anteriores. Detalhes em [GUERRA-OFFLINE.md](GUERRA-OFFLINE.md).

## Validação da estreia — 1.6.0

| Área | Resultado final |
| --- | --- |
| Operação offline real | 42 verificações, sem falhas |
| Equipamentos offline, controles e câmeras | 34 verificações; duas execuções finais aprovadas |
| Entrada offline pelo pacote exportado | 4 verificações, sem login/servidor |
| Escolha de modo e ações offline/online | 17 verificações |
| Regras, terreno, canos e recursos | 79 verificações |
| Modelos e LOD | 109 verificações e revisão visual nativa |
| Rede local, servidor e três clientes | 18 verificações, incluindo FAL/recarga completa após desconexão |
| Serviço Guerra no Ubuntu, dois clientes | 17 verificações |
| Ranking na API publicada | 10 verificações, incluindo HTTP 403 para recompensa por credencial de jogador |

Naval e PvP Deserto passaram pelas regressões na VM. A instalação real pelo launcher e a abertura seguinte sem download repetido também passaram. Evidências detalhadas em [ATUALIZACAO-1.6.0.md](ATUALIZACAO-1.6.0.md).

## Validação e desempenho atuais — 1.6.1

Assentos: 91 verificações; respawn: 41; sistemas: 79; locomoção nativa: 34 e ENet: 18; passageiros por ENet: 24; regressão anterior de rede: 18; equipamento offline: 34. A sessão central de três contas reais passou em 33 verificações, sem comandos privilegiados nem token de serviço. Download, instalação real, abertura seguinte sem download repetido e inicialização normal do pacote também passaram.

Na GTX 1650, doze clientes ENet no mesmo PC e um renderizando em 1080p registraram **59,19 FPS médios, 1% low de 40,12 FPS e pior quadro de 29,25 ms**, após corrigir o trabalho ocioso da locomoção. O diagnóstico inicial havia caído para 36,32 FPS; o controle de 60,02 FPS sem módulo foi somente fixture e não é o jogo distribuído. O treino offline teve 60,00 FPS médios e 1% low de 54,11 em trinta segundos de navegação de onze bots, com **zero tiros**; não mede combate offline intenso. Não há comprovação de 60 FPS estáveis. Metodologia e histórico em [GUERRA-DESEMPENHO.md](GUERRA-DESEMPENHO.md).

Depois da 1.6.1, o plano de áudio/scoreboard/ranking/granadas/HUD volta à fila: som distante de Guerra, HUD de gadget/cargas, mortes persistentes elegíveis e estado de recarga por arma. Escopo preciso em [REVISAO-AUDIO-RANKING-HUD.md](REVISAO-AUDIO-RANKING-HUD.md).

## Referências primárias

- [IDV — Guarani](https://www.idvgroup.com/products/amphibious-armoured-vehicles/guarani/) e [ARES — REMAX](https://ares.ind.br/torres-e-sistemas/).
- [Ukrspecexport — catálogo com BMP-2](https://www.ukrspecexport.com/uploads/files/Categories/pdf_5/be2e23.pdf).
- [General Dynamics — Abrams](https://www.gdls.com/abrams/) e [folheto ilustrado M1A2](https://international.gdls.com/english/products/ABRAMS/M1A2.pdf).
- [Parque Patriot — T-90A](https://parkpatriot.ru/o-parke/tekhnika-parka/t-90a/).
- [Ministério da Defesa ucraniano — equipamento individual](https://mod.gov.ua/en/news/personal-protective-equipment-for-the-military-key-equipment-ensuring-the-safety-of-service-members-of-the-armed-forces-of-ukraine-and-the-state-special-transport-service), [especificação de colete/MM-14](https://www.mil.gov.ua/content/ddz/TY_2024/eng_bronya.pdf) e [Rostec — Ratnik](https://rostec.ru/media/pressrelease/rostekh-dosrochno-postavil-pochti-18-tysyach-komplektov-ekipirovki-ratnik-v-ramkakh-gosoboronazakaza/).
- [EA — classes e implantação do BF2042](https://www.ea.com/games/battlefield/battlefield-2042/news/dev-notes-classes-in-battlefield-2042) e [Update 3.2.0](https://www.ea.com/en-au/games/battlefield/battlefield-2042/news/battlefield-2042-update-notes-3-2-0). Organização adaptada à paleta existente; não foram copiados gráficos nem alteradas as cores do login.


As capacidades de tripulação acima e corrida/passos são itens entregues na 1.6.1. A animação preserva a câmera, o áudio reutiliza 24 vozes espaciais e passos cessam parado, no ar, morto, embarcado ou com snapshots interrompidos. Esses sistemas são reaproveitados no online e offline.
