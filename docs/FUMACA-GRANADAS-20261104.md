# Fumaça tática — granada M18 e blindados (04/11/2026)

## Escopo e compatibilidade

- Implementação em worktree isolada `ia/fumaca-granadas`, sem merge, publicação ou alterações na `main`.
- A granada explosiva existente continua padrão e mantém sua física, dano, áudio e pavio de 5 segundos.
- No arsenal/loadout de Guerra (soldado), Deserto e treinos offline, escolher `Granada explosiva` ou `Granada de fumaça (M18)`. Ambos usam o slot 3/G e o estoque de duas unidades; só um tipo equipado por vez.
- Battle Royale usa mochila/saque em vez de loadout; quando possuir granadas, pressionar `Y` alterna o tipo explosivo/M18, com escolha validada pelo servidor e indicação no HUD. A quantidade obtida por saque não é alterada.
- Blindados terrestres `abrams`, `t90`, `bmp2` e `guarani` recebem fumaça na tecla `Q` para o operador humano. Motos e navios não recebem o recurso de *blindado* terrestre.
- Não modificar políticas de uso dos bots, direção de blindados, algoritmos de visão dos bots nem scripts de áudio. Os áudios específicos serão adicionados em outra tarefa.

## Efeito da M18 de mão

- Modelo low-poly de corpo cilíndrico em aço pintado verde, 64 mm de diâmetro, corpo de 118 mm e conjunto superior com anel/tampa e alavanca. Referência dimensional: M18 militar (~64 mm x ~146 mm incluindo espoleta).
- Pavio **4,0 s** = 1 segundo a menos que a granada explosiva existente, contado a partir de armar e mantido pelo servidor, inclusive na mão e no lançamento.
- Mantém lançamento, arco de trajetória, ricochete, resting contact, contagem de munição e sincronização de granadas compartilhados. Não inflige dano/impulso de explosão.
- **64 s** de nuvem persistente, com crescimento progressivo até cerca de 5,5 s, cobertura local densa e dissipação progressiva nos últimos 14 s.
- Escala visual: 14 elementos de fumaça em um raio de ~3 m, com deriva leve; cor verde/cinza. Sem efeito sonoro temporário ou uso inadequado do som de explosão.

## Contramedida de blindados

- Sistema anterior: apenas Abrams/T-90, centro único, duração de 12 s e recarga de 45 s.
- Sistema novo: todos os quatro blindados; disparo de **12 cartuchos em tanques** ou **6 em APC/BMP** em leque circular de 360° com orientação relativa à torre; expansão maior ao longo da direção apontada pela torre; arco visual breve antes de as nuvens se formarem.
- Área da cortina: cartuchos espalhados a **~8–12 m** do centro (escalonados para Guarani/BMP-2), com 36 regiões nos tanques ou 18 nas variantes menores. Não são emissores físicos independentes.
- Duração **70 s**, recarga de **90 s** por veículo, validada pela autoridade. A fumaça acompanha o ponto de impacto inicial; depois de disparada, **não teleporta com o blindado**.
- Ângulo, tipo de veículo, origem, ID, expiração e estado são comunicados ao cliente; jogador entrando depois recebe cortinas ainda ativas.
- Visão em câmera do TV-míssil, inclusive térmica, continua recebendo overlay ao penetrar na fumaça. A câmera de um jogador também tem overlay dentro da nuvem. HUD não é coberto.
- Modelo dos blindados mostra grupos de tubos e suportes posicionados na torre; modelo do casco, munição, arma e blindagem permanecem funcionais.

## Desempenho e rede

- Usa `GameSmokeClouds` com um **único MultiMesh** por jogo, máximo de **192 cards** visuais e **40 eventos de nuvem** simultâneos (nenhum rigidbody adicional, sem luz, sombra ou áudio).
- Culling a ~340 m, redução de detalhes em distância intermediária e atualização visual limitada a 12,5 Hz, mantendo efeitos estáveis sem alocar uma árvore de Nodes por cartucho. A autoridade envia somente eventos; clientes constroem nuvens determinísticas localmente a partir de IDs.
- Conteúdo visual é dependente da distância e pode deixar de desenhar algumas nuvens se 192 cards estiverem simultaneamente em uso. Não é uma colisão sólida e não deve ser usada como bloqueio de balas.
- O sistema **não altera** a linha de visão/inteligência de NPCs. A coordenação do comportamento dos bots ficará para outro chat.
- A ocultação visual pode ser refinada após avaliação com usuários em cliente gráfico; teste headless não mede overdraw, contraste, FPS nem legibilidade em diferentes GPUs.

## Testes e condições de integração

- `tests/smoke_grenades_20261104.gd`: escolhas e validação por modo, preservação da explosiva, modelo M18, tempo de pavio, vida da nuvem, orçamento de GPU, os quatro blindados, cooldown, reset, prime autoritativo e ativação não letal.
- Exigir compilação e regressões existentes, teste multiplayer real e captura visual com GPU antes de liberar produção.
- Não misturar sons de explosão aos eventos de fumaça; novo catálogo de áudio deverá ser feito pelo chat responsável por sons.

## Referências de comportamento

- Squad — granadas de fumaça com fase de enchimento e permanência prolongada (~80 segundos em perfis de jogo): https://squad.fandom.com/wiki/M18_Smoke
- US Army, lançadores de granadas de fumaça de blindados e cortina orientada: https://jpeoaa.army.mil/Portals/94/Documents/JPEOAAPortfolioBook_2025.pdf
- M18 militar: corpo cilíndrico, dimensões e emissões de 50–90 segundos: https://jpeoaa.army.mil/Portals/94/Documents/CPE%20AE%202026%20Portfolio%20Book.pdf

A implementação adapta a cortina militar frontal para uma proteção circular em jogo, conforme pedido. Não simula automaticamente penetração de miras térmicas, contramedidas eletrônicas ou visão de IA.
