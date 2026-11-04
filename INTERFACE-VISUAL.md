# Interface compartilhada — Toque de Campo 1.4.0

Atualização de 23/10/2026. Projeto Godot existente; referência Three.js preservada.

## 1. Referências reais consultadas

- **Andreas Lanjerud, designer de UI do BF2042:** https://helloandy.se/post/battlefield-2042/ — capturas reais de PlayStation. Conferidos no navegador o menu principal, a coleção, a personalização, o painel social e a preparação de partida.
  - Menu: https://helloandy.se/post/battlefield-2042/bf2024-main-s0.jpg
  - Coleção: https://helloandy.se/post/battlefield-2042/bf2042-collection-s0.jpg
  - Personalização: https://helloandy.se/post/battlefield-2042/bf2042-customize-s0.jpg
  - Social: https://helloandy.se/post/battlefield-2042/bf2042-playercards-social.jpg
  - Preparação: https://helloandy.se/post/battlefield-2042/bf2042-playercard-matchmaking-s0.jpg
- **Xbox Wire, captura de combate do BF2042:** https://news.xbox.com/en-us/2021/10/06/battlefield-2042-open-beta-starts-today/ — HUD real: munição e equipamento na direita, informações da partida na esquerda, centro livre para mirar.
  - Imagem inspecionada: https://xboxwire.thesourcemediaassets.com/sites/2/2021/10/Battlefield-2042-Xbox-One-V1_JPG.jpg
- **Vídeo AJ4Games, Start Up Screen + Menu Walkthrough (PS5):** https://www.youtube.com/watch?v=eDs0cvStZw8 — reproduzido sem áudio; observados o menu principal e a navegação de opções, aproximadamente em 0:41 e 1:10. Não foram extraídos assets desse vídeo.
- **EA/DICE, revisão do HUD e fluxo de coleção:** https://www.frostbite.com/en-gb/games/battlefield/battlefield-2042/news/battlefield-briefing-what-we-learned-from-open-beta
- **EA, configurações e legibilidade do HUD:** https://www.frostbite.com/able/resources/battlefield-2042/pc/display
- **Gavin Marshall, Technical UI Designer:** https://gavmakesgames.com/project/battlefield — contexto de desenvolvimento e telas reais de menu/coleção.

O trailer oficial da Temporada 5 foi localizado, mas exigia confirmação de idade no YouTube. Ele não foi considerado um vídeo assistido; a demonstração de menus acima estava disponível sem login.

### O que foi aproveitado

Abas superiores persistentes; seleção de modo separada do botão que inicia; cartões com imagem e estado selecionado; coleção com lista e prévia; identidade do jogador no cabeçalho; telas de salas com hierarquia clara; HUD organizado por função nos cantos; contagem de munição com peso tipográfico maior; retorno de recarga perto da mira e pouco conteúdo permanente no centro. Transições curtas preservam o foco. São adaptações ao jogo atual, sem copiar o turquesa do BF2042, seus assets, mapas, classes ou sistemas inexistentes.

## 2. Paleta extraída do login existente

O arquivo original foi examinado antes das alterações e está preservado em `work/ui-before-2026-10-23/login_screen.gd`.

| Papel | Cor original | Reutilização |
|---|---|---|
| Fundo | `#071013` | fundos das telas, carregamento e apresentação |
| Texto principal | `#E7EDE8` | títulos, dados, botões e HUD |
| Texto secundário | `#97AAA9` | descrições, categorias e telemetria secundária |
| Destaque | `#B7CCA1` | ação principal, aba/arma selecionada, foco, vida e progresso |
| Texto sobre destaque | `#14231B` | contraste nos botões preenchidos |
| Borda | `#364746` | painéis, campos e cartões |
| Hover | `#1E302F` / borda `#70867B` | interação dos controles |
| Pressionado | `#2E443D` | estado pressionado e equipamentos selecionados |
| Destaque em hover | `#CBDCBA` | realce da ação principal |
| Erro/atenção | `#ECAA98` | feedback de falha |
| Desabilitado | `#667976` | ações indisponíveis |
| Campo translúcido | `RGBA(0.06, 0.10, 0.11, 0.88)` | campos e botões secundários |
| Painel | mesma base escura, alfa `0.96` | contraste do menu e HUD |

Foram mantidos Bahnschrift → Segoe UI → DejaVu Sans, bordas finas e cantos de 2 px. A grade usa espaçamentos de 8 px e seus múltiplos, com ajustes responsivos. Os ícones próprios seguem traço simples e a cor de destaque. O login continua com sua apresentação e iluminação militar existentes.

## 3. Componentes compartilhados

- `themes/field_theme.tres`: recurso **Theme único**, carregado por login, menus e HUD.
- `scripts/ui/field_theme.gd`: constantes e estilos de Button, LineEdit, OptionButton, painéis, barras, sliders, tooltip e popup.
- `scripts/ui/ui_kit.gd`: criação reutilizável de rótulos, botões, painéis, ícones e transições.
- `scripts/ui/ui_feedback.gd`: os mesmos tons discretos de hover/clique do login, com limite de repetição.
- `scripts/ui/menu_page.gd`: estrutura naval de cabeçalho, conteúdo rolável, prévia e rodapé.
- `scripts/ui/item_preview.gd`: modelos reais do jogo em World3D isolado. Prévia desliga a renderização quando oculta; não participa da física da partida.
- `scripts/ui/loading_screen.gd`: estado real de conexão, sem porcentagem de carregamento inventada.
- `scripts/ui/main_menu.gd`: abas, modos, arsenal, personagem, loja, opções e créditos.
- `scripts/ui/infantry_hud.gd` e `naval_hud.gd`: composições específicas para cada modo.
- Integração em `scripts/main.gd`, `modes/naval/scripts/mode.gd`, `scripts/ui_focus.gd` e `scripts/ui/login_screen.gd`.

A autenticação, contas, preços, compras navais e autoridade da simulação continuam nos serviços existentes. A preferência de arma inicial usa o pedido de equipamento já validado pelo servidor, após a autenticação. O cancelamento da conexão invalida a tentativa pendente.

## 4. Telas implementadas

| Tela | O que foi entregue |
|---|---|
| Login e registro | recurso Theme compartilhado; paleta/layout/playlist preservados |
| Menu principal | Jogar, Arsenal, Personagem, Loja, Opções; conta e saldo no cabeçalho |
| Modos | Offline, PVP Naval e PVP Deserto; fotografia e seleção, implantação por botão separado |
| Arsenal | lista com ícones, prévia do modelo real, dados e preferência de arma inicial |
| Personagem | prévia do avatar real, cor e proporções; alterações salvas pelo mecanismo existente |
| Loja principal | acesso ao estaleiro e à coleção; compras de infantaria permanecem no arsenal da partida |
| Navegador naval | salas reais, ocupação/estado, criar, entrar por código e atualizar |
| Criar/entrar naval | campos e controles padronizados; privacidade e entrada tardia preservadas |
| Lobby naval | participantes em cartões, navio, dono/você, convite e estado de espera; mínimo de dois preservado |
| Frota e estaleiro | propriedade/seleção/saldo reais, cartões, prévia e confirmação |
| Configurações e pausa | tema, foco, feedback e rolagem compartilhados; partida online continua |
| Carregamento | sobreposição de conexão/join com texto real; cancelamento no PVP de infantaria |
| HUD Offline/PVP Deserto | vida, arma, carregador/reserva, seleção, recarga com tempo/barra, retículo, placar e estado da sessão |
| HUD naval | integridade, velocidade, arma/munição/recarga, retículo, guia balística, alcance/limite/bloqueio das torretas e placar |

PVP Deserto continua cada um por si; não foram inventados times ou um novo sistema de salas de infantaria. O submarino existente é apresentado como **SUPERFÍCIE**, sem um indicador falso de profundidade. A guia balística continua usando o lançamento real das torretas e a física existente.

## 5. Fotografias solicitadas

As ilustrações geométricas dos três cartões foram substituídas por fotografias em `assets/ui/modes/`:

- Galpão: Compagnons (@sigmund), https://unsplash.com/photos/a-large-warehouse-filled-with-lots-of-boxes-j8C0xOCuX0U
- Navio no mar: Abdullah Al Hasan (@aa_hasan), https://unsplash.com/photos/8dJM0LwzsfU
- Dunas: 光曦 刘 (@liuguangxi), https://unsplash.com/photos/OSfQ7JI1Ppc

Licença consultada: https://unsplash.com/license. Fontes, autores e SHA256 estão em `assets/ui/modes/credits.json`; o aviso está em `LICENSE.txt`. Créditos também acessíveis em Opções no jogo. São fotografias ilustrativas, não capturas dos mapas. Os três JPEG somam aproximadamente 405 KiB e são distribuídos no pacote; não há download/hotlink durante o jogo.

## 6. Testes e evidências

- **Interface:** 40 verificações, sem falhas — abas, seleção sem iniciar, clique nas fotografias, carregamento, prévias, HUD/recarga real e páginas navais. Capturas nativas, com solicitações de janela 800×600, 1280×800 e 1920×1080.
- **Login real:** 44 verificações, sem falhas — digitação, Tab/Shift+Tab, olho, registro, erros, timeout, sessão validada, conta real, logout e música compartilhada.
- **Regressões:** lobby 18, física naval 15, combate 86, NPCs/armas brancas 73, ragdoll 4; todas passaram.
- **Playlist:** 14 verificações, sem falhas; os cinco arquivos do usuário continuam disponíveis.
- **Naval multiplayer:** dois executáveis nativos conectados à VM; sala pública/convite, mínimo de dois, seleção persistente, início, movimento/disparo, recepção de áudio 3D e tiro, convidado continua após criador sair.
- **Deserto multiplayer:** dois clientes gráficos conectados à VM; contas reais carregadas, Glock selecionada aplicada inicialmente e disparo autorizado pelo servidor recebido nos dois.
- Confirmada igualdade textual das funções `_update_guide` e `_update_projectiles` com a cópia anterior a esta reformulação. Os testes físicos verificam cano real, rotação compensada e velocidade herdada em X **e Z**.

Relatórios: `tests/ui-standardization-results.json`, `login-ui-results.json`, `login-music-results.json`, `naval-physics-results.json`, `naval-autohost-{host,guest}.json` e `ubuntu-pvp-{host,guest}.json`.

Capturas em `tests/screens/ui/`: menu, arsenal, personagem, loja, opções, carregamento, login, lobby, frota, estaleiro, pausa, HUD offline e PVP Deserto. A sessão naval gráfica está em `tests/screens/autohost-host-combat.png`.

### Limites da validação

Não foi um teste de carga com seis PCs físicos. Os dois clientes de QA foram executados neste computador e conectados ao servidor Ubuntu real. O diagnóstico já conhecido do OpenGL ao encerrar a aplicação ainda pode registrar duas texturas de atlas de 349524 bytes como não liberadas; não houve erro de script nas rodadas finais aprovadas. Não se afirma ausência de vazamento em sessões prolongadas.

## Distribuição

**Publicado e validado: 1.4.0, build 17**, em http://192.168.101.24/. O atualizador baixado da VM instalou a atualização; a segunda execução confirmou que não era necessário baixar novamente. O PCK de produção contém o tema, fotografias, créditos e cinco músicas, sem a cena de QA. A inicialização do executável de produção passou. Evidência: `tests/ubuntu-distribution-results.json`.
