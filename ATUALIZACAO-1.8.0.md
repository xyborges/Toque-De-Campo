# Toque de Campo — Guerra costeira 1.8.0

Validação final em andamento. A publicação e o número da build serão registrados após a conferência do pacote exportado e do servidor.

## Mapa e cidade

- Área jogável de **3.500 × 3.500 m**, com ilha, mar ao redor, uma baía a oeste e um porto aberto a leste. Essa medida inclui terra e mar; não são 3,5 km de terra mais um oceano adicional.
- Bases terrestres e objetivos A/B/C preservados. Portos **D e E** são capturáveis e oferecem implantação conforme o controle da equipe.
- Dez setores urbanos, 60 edifícios modulares de dois/três pavimentos e quatro vilarejos periféricos. Ruas principais, secundárias e acessos de terra conectam bairros, bases e logística; o traçado evita lotes de edifícios.
- Quintais, cercas, anexos, fachadas comerciais, ponto de ônibus, postes, fiação e caixas de telecomunicações. Galpões, tanques industriais, caminhões, tubulações e pátios próximos aos portos.
- Cais, píeres apoiados, guindastes, contêineres, armazéns e quebra-mares. Prédios apresentam estados diferentes de destruição, com paredes, lajes e entulho.
- 3.141 árvores na distribuição principal, além dos conjuntos de pinheiros; 31.955 instâncias de vegetação rasteira e dois campos de trigo. A vegetação respeita acessos e áreas de implantação.

As referências visuais foram as cinco imagens fornecidas pelo usuário: bairro portuário, cidade destruída, ruínas densas, trigo e floresta de pinheiros. Foram consultadas também as descrições históricas de costa/porto no [roteiro dos mares Negro e de Azov](https://ivms.mil.gov.ua/wp-content/uploads/2020/10/Black_and_Azov_seas_PilotNP-24_2003.pdf) e no [material do estaleiro de Azov](https://privatization.gov.ua/wp-content/uploads/2022/01/ENG_SOE_Azov_Shipyard.pdf). O cenário é uma adaptação ao estilo modular do jogo, não uma reconstrução fotorrealista ou geográfica exata de Mariupol.

## Navios e ocupantes

- **Um navio de assalto e uma fragata por porto**, quatro embarcações no total. Reutilizados os cascos, armamentos e física do modo Naval.
- Cada navio tem um operador e seis assentos de passageiros, com bancos no convés. O limite de seis jogadores por equipe continua valendo.
- Operador controla deslocamento, torretas, munição e recarga. Passageiros apenas observam e são transportados; comandos forjados de controle são rejeitados pelo servidor.
- Entrada/saída por F, seleção das armas por 1–4, posições seguras de desembarque e controle de ocupação mantidos na autoridade.
- As quatro torretas acompanham a mira. Cabine e tropas ocupando os assentos entram na proteção de tiro; o servidor bloqueia disparos ainda obstruídos.
- Munições saem dos canos reais. A previsão usa a mesma balística do disparo, incluindo velocidade herdada nos eixos X e Z, arrasto e gravidade.
- Capturar o porto transfere somente embarcações vazias. As ocupadas mantêm a equipe; após destruição, retornam vazias em **60 segundos**, para a equipe que controla o porto.
- Destruição mata todos os ocupantes e contabiliza os abates uma única vez. Explosões com mais de uma eliminação geram um aviso agrupado.

## Água, clima e efeitos

- Animação de natação em primeira e terceira pessoa, com o corpo horizontal e braços/pernas em movimento. Armas, granadas, recarga e equipamentos ficam indisponíveis enquanto o personagem nada, com validação também no servidor.
- Ao voltar à terra, a apresentação do equipamento é restaurada. Uma granada já armada cai ao entrar na água, conservando o pavio.
- Blindados terrestres que efetivamente entram no mar são destruídos, junto com operador e passageiros. Veículos sobre um píer seco não são destruídos apenas porque existe água abaixo dele.
- Chuva ocasional sincronizada, com entrada/saída gradativas e maior agitação do mar. Ciclo completo de dia/noite mantido em **14 minutos**.
- Faíscas em contatos metálicos, com pool limitado; projéteis visíveis também nas regiões externas do mapa.
- Movimento dos navios interpolado por histórico de posição, velocidade e tempo do servidor, tanto no Guerra quanto no Naval. O teste a 25 m/s produziu deslocamentos de aproximadamente 0,416667 m por quadro a 60 Hz, sem os saltos por pacote.

## Desempenho e correções

- Geração do mundo antes de abrir a conexão ENet: o carregamento do mapa não deixa uma conexão já iniciada sem responder.
- Colisores estáticos organizados em setores; terreno visual agrupado sem alterar suas superfícies físicas.
- Árvores distantes compartilham LODs por setor até 900 m; posição, escala, rotação e colisão são preservadas. Partes próximas e distantes usam os mesmos limites de troca para evitar buracos entre LODs.
- Navios vazios não resolvem a balística de 16 torretas a cada tick. A resposta dos cascos às ondas permanece ativa.
- Broadcasts idênticos são serializados uma vez, preservando a proteção para conexões que estão sendo encerradas. Referência técnica: [RPCs do Godot 4.7](https://docs.godotengine.org/en/4.7/tutorials/networking/high_level_multiplayer.html).
- Busca espacial das ruas: **13.150 amostras**, erro de altura zero; consulta de referência em 612,331 ms e consulta indexada em 53,254 ms. Isso mede a consulta das ruas, não o FPS do jogo.

## Validação

O teste nativo do mapa no pacote final passou **54 verificações**, incluindo píeres, cabine, assentos, natação FPP/TPP, equipamento ao sair da água, limites de renderização dos projéteis e morte de todos os ocupantes ao afundar. A sessão local com servidor e três clientes já tinha passado **21 verificações** numa execução anterior, incluindo bloqueio de ações na água, controle exclusivo do operador, disparos reais, liberação do gatilho, multikill e reposição do navio. O pacote Windows assinado foi inspecionado em isolamento: recursos de costa, Guerra, Naval, HUD/armas e launcher encontrados; cena de QA não incluída.

A publicação confirmou `VERIFIED_READY`, instalou a build **48**, e deixou os serviços Naval, PvP e Guerra ativos. O download público, a instalação pelo atualizador, a segunda execução sem novo download e o boot do executável passaram. Um smoke test posterior autenticou três contas reais no serviço de contas, mas os clientes não entraram na sala central; o teste não verificou combate online nesta publicação. O socket UDP **3014** está em escuta no servidor. Assim, a conexão multiplayer de produção ainda precisa ser verificada com jogadores reais/rede acessível; não considero esse smoke test online aprovado.

### Medição de desempenho

Teste com **12 clientes ENet reais** no mesmo computador: um cliente renderizado e 11 clientes headless, quatro veículos com operadores, drones, fogo simultâneo, granadas, desconexão e visão térmica. PC de renderização: **GTX 1650**. Servidor, outros clientes e jogo renderizado disputam CPU e memória no mesmo host; é uma carga local mais concentrada que 12 PCs distribuídos.

| Build/carga | Resolução renderizada | Média | 1% low | Frame médio / P95 / pico | Térmica | RAM do cliente |
|---|---:|---:|---:|---:|---:|---:|
| 1.7.1, cenário anterior | 1920×1080 | 59,70 FPS | 35,95 FPS | 16,75 / 18,60 / 52,53 ms | 59,67 FPS; 1% low 34,85 | 230 MiB |
| 1.8.0 build 47, carga de 12 clientes | 1536×864 | 29,43 FPS | 13,33 FPS | 33,98 / 54,43 / 77,31 ms | 30,81 FPS; 1% low 13,63 | 367 MiB |

O monitor ativo limitou a segunda medição a 1536×864, então as duas resoluções não são uma comparação controlada. Ainda assim, a build 1.8.0 **não atingiu a meta de 60 FPS** nessa carga. O ajuste de LOD reduziu os draw calls máximos de 2.336 (build 46) para 2.061 (build 47), mas não recuperou o FPS. No profiler, as funções de script mais custosas somaram poucos milissegundos por frame; a maior parte do custo restante aparece fora de uma única função GDScript, sobretudo no renderizador e na carga agregada dos 13 processos. O servidor teve média de 59,36 FPS, física média de 22,64 ms e 54 projéteis simultâneos no cenário medido. As desconexões não causaram travamento persistente no servidor, mas esse ensaio não demonstra 60 FPS estáveis para o cliente.

A busca espacial das ruas foi medida separadamente: **13.150 amostras**, erro de altura zero; consulta linear em 612,331 ms e indexada em 53,254 ms. Esse resultado é tempo de consulta, não FPS.

O pacote preparado é a **build 48**, versão **1.8.0**. A build 48 remove a seleção de cena de QA dos recursos de execução/exportação; o conteúdo jogável medido na build 47 é o mesmo. A checagem local da build assinada, do cliente instalado pelo atualizador e dos serviços de produção será registrada após a publicação.

## Arquivos principais

- `modes/war/scripts/terrain.gd`, `coast.gd`, `harbors.gd`, `outskirts.gd`, `districts.gd`, `urban_layout.gd`, `city_life.gd`, `roads.gd`, `vegetation.gd`, `weather.gd` e shaders costeiros.
- `modes/war/scripts/ship.gd`, `ship_guide.gd`, `vehicles.gd`, `vehicle.gd`, `player.gd`, `bot_director.gd`, `rules.gd`, `game.gd` e `projectiles.gd`.
- `scripts/snapshot_motion.gd`, `metal_sparks.gd`, `network_broadcast.gd`, `environment/environment_kit.gd`, `main.gd` e integração de movimento no Naval.
- `distribution/release-notes.json`: notas exibidas no site e no atualizador.

As versões de referência Three.js/Babylon permanecem intactas.
