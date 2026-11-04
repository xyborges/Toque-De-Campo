# Toque de Campo 1.6.0 — Guerra chegou

**Publicada em 24/10/2026 · build 26 · Ubuntu.**

Download e atualização: **[http://192.168.101.24/](http://192.168.101.24/)**. Abra o launcher para instalar a versão nova. A instalação real e a segunda abertura sem baixar novamente foram verificadas. O endereço é privado e exige acesso à rede da VM ou VPN.

## O que foi entregue

### Guerra no mesmo jogo

Novo modo integrado, preservando Offline, Naval e PvP Deserto. Terreno de 2 × 2 km com relevo físico, trincheiras, crateras, lama, estradas, aldeia, ruínas e vegetação. A/B/C são objetivos ativos, com 300 tickets e vinte minutos.

Online há duas equipes de até seis integrantes. Escolha equipe, classe, equipamento e implantação; o servidor valida equilíbrio, recursos, posição, disparos e dano. As quatro classes são Médico, Soldado, Antitanque e Atirador. Alterações durante a vida ficam para o próximo respawn.

### Treino offline com bots

**Jogar → Guerra → Treino offline · Bots.** Você e cinco aliados enfrentam seis adversários controlados localmente. É o mesmo mapa e os mesmos personagens, hitboxes, armas, projéteis, munição, recarga, dano, respawn e conquista.

Não precisa de amigos, sala ou servidor; não abre ENet nem envia moedas/estatísticas ao ranking. Para entrada direta no executável há `--war-offline`; no projeto, `JOGAR-GUERRA-OFFLINE.bat`.

Os bots movimentam-se por rotas/obstáculos, verificam linha de visão, atiram, recarregam, reaparecem e disputam objetivos. Há suporte de cura e munição. **Nesta versão não pilotam blindados/drones nem usam autonomamente RPG, Stinger ou granadas.** O humano pode utilizar esses equipamentos. Sair encerra a IA e limpa a operação antes de começar outra.

### Quatro blindados e armas próprias

| Equipe | Veículo | Aparência/armamento representado |
| --- | --- | --- |
| 1 | Guarani 6×6 | Casco anfíbio, seis pneus, rampa traseira e estação inspirada na REMAX/M2 .50. |
| 2 | BMP-2 | Perfil baixo, esteiras, compartimento traseiro e canhão visual 2A42 de 30 mm. |
| 1 | Abrams | Torre angular com compartimento traseiro, sete rodas por lado e M256 de 120 mm. |
| 2 | T-90 | Perfil compacto, módulos externos de proteção, seis rodas por lado e 2A46 de 125 mm. |

São geometrias próprias inspiradas em referências reais; os valores de mobilidade, blindagem e dano são balanceamento do jogo. Um operador dirige e atira. Entrada/saída, reserva, morte e desconexão são validadas pela autoridade. Torres compensam o casco, com limites de elevação e disparos a partir dos canos visíveis. Há óptica, térmica, munição finita e drones com bateria/alcance/integridade.

**O casco que parecia transparente foi corrigido.** A combinação de malhas indexadas e superfícies autorais sem índices podia descartar faces durante o agrupamento. A geometria agora é indexada corretamente; os materiais continuam opacos. Vistas nativas de frente, lateral, traseira, armas e LOD foram conferidas. Detalhes são simplificados a partir de 160 m; não foram adicionados centenas de colisores para pequenos acessórios.

### Placar e ranking separados

Segure TAB para ver modo, mapa, tempo, tickets/objetivos e tabela alinhada: pontos, abates, mortes, assistências, K/D, dano efetivo, objetivos e ping medido. Guerra separa equipes; os modos individuais mantêm classificação única. A linha local e as primeiras posições têm destaque discreto.

O placar reutiliza linhas, ajusta a altura aos participantes e não pausa combate nem libera o mouse. Ping desconhecido aparece como `—`; offline oculta a coluna. A abertura por código também inicializa o contexto imediatamente.

**Ranking Global** fica em um painel suspenso à direita, com setas para quatro top 10: abates, K/D, mortes e moedas. Os dados vêm das contas centrais, com cache de uma hora. O K/D exige vinte eliminações + mortes; divisão por zero é tratada.

O ranking de mortes usa abates válidos registrados pelo servidor; suicídios, ambiente e treino offline não alimentam esse total. O placar da partida continua registrando as próprias mortes. Pontos da partida não são saldo de moedas.

### Áudio, equipamento e granada

- Tiros com origem fixa no mundo, listener no personagem em FPP/TPP, alcance por categoria, filtragem, oclusão e limite de vozes. Recursos e efeitos são reutilizados.
- Slots comuns: 1 pistola, 2 principal, 3 granada e 4 arma branca. Extras aparecem em 5/6/9; RPG/Stinger mantêm 7/8. O HUD mostra munição real, reserva, recarga, vazio e equipamento indisponível.
- G/3 equipa a granada desarmada. Segurar clique inicia cinco segundos; soltar lança. O tempo continua após lançar, com barra na mão e indicador próximo respeitando paredes. A classe Soldado de Guerra usa o mesmo sistema.
- Dano contabiliza HP efetivamente retirado; suporte distingue destinatário/tipo, deduplica antes de acumular frações e limita recompensas. Recompensas online exigem a credencial do servidor; uma conta comum não pode enviá-las.

A identidade do login foi mantida: destaque `#b7cca1`, texto `#e7ede8`, secundário `#97aaa9`, fundo `#071013` e borda `#364746`, por meio do tema compartilhado.

## Controles rápidos de Guerra

| Ação | Controle |
| --- | --- |
| Mover / agachar / trocar câmera | WASD / CTRL / V |
| Disparar / mirar ou ampliar | Botão esquerdo / botão direito |
| Recarregar | R |
| Pistola / principal / granada / arma branca | 1 / 2 / 3 ou G / 4 |
| Armar e lançar granada | Segurar clique esquerdo; soltar para lançar |
| Implantação/equipe/classe | M |
| Entrar ou sair do blindado | F próximo ao veículo |
| RPG / Stinger, classe Antitanque | 7 / 8 |
| Lançar drone / detonar sob controle | B / botão esquerdo |
| Subir / descer com drone | Espaço / CTRL |
| Térmica de veículo | X |
| Placar / menu e foco do mouse | Segurar TAB / ESC |

A operação online fica em **Jogar → Guerra → Conectar online**. Selecionar o cartão ou abrir Jogar apenas mostra escolhas; não inicia uma partida ao fundo.

## O que foi testado

| Bateria | Resultado final | Evidência |
| --- | ---: | --- |
| Operação offline: IA real, tiros, recarga, parede, headshot, respawn, conquista e reset | 42/42 | `tests/war-offline-results.json` |
| Equipamentos offline: veículo, câmeras, zoom, drone, granada e lançadores | 34/34, duas execuções finais aprovadas | `tests/war-offline-equipment-results.json`, `work/war-offline-equipment-diagnostic.log`, `work/war-offline-equipment-repeat.log` |
| Entrada normal pelo pacote exportado, sem login/ENet e com onze bots | 4/4 | `work/war-offline-pack-engine.log` |
| Menu, ações offline/online e três resoluções | 17/17 | `tests/war-menu-results.json` |
| Placar/ranking: 1/3/6/12 linhas, três resoluções e TAB real | 54/54 | `tests/scoreboard-visual-results.json` |
| HUD de equipamentos/granada | 25/25 | `tests/equipment-hud-results.json` |
| Estatísticas, dano efetivo e suporte | 34/34 | `tests/match-stats-results.json` |
| Quatro modelos, canos, materiais, geometria e LOD | 109/109 + revisão visual nativa | `tests/war-vehicle-models-after.json` |
| Regras/terreno/torretas/recursos de Guerra | 79/79 | `tests/war-systems-results.json` |
| Guerra ENet: servidor e três clientes, saída do motorista e FAL/recarga completa | 18/18 | `tests/war-multiplayer-{server,alpha,bravo,medic}.json` |
| Guerra central no Ubuntu, dois clientes | 17/17 | `work/release160-ubuntu-war.log` |
| Ranking central real e recusas HTTP 403 a ações de servidor | 10/10 | `tests/ubuntu-ranking-results.json` |
| Naval/PvP Deserto contra a VM | Aprovados | `work/release160-ubuntu-naval.log`, `work/release160-ubuntu-pvp.log` |
| Download, instalação real, pacote e segunda abertura sem download | Aprovados | `tests/ubuntu-distribution-results.json`, `work/release160-distribution.log` |

Essas baterias usam automação e fixtures de posição/cenário; não representam doze pessoas jogando pela interface. A rede local havia falhado porque o Stinger matava o médico do teste antes da verificação pós-desconexão. A fixture foi separada fisicamente e a execução final confirmou munição e recarga completas, sem alterar as regras de combate. O log histórico da falha foi preservado.

Áudio espacial compartilhou 28 verificações de mixer e os sons fornecidos passaram em 43. A API isolada passou em 67 verificações de autoridade e doze de ranking/cache. A instalação publicada também confirmou que credenciais comuns recebem HTTP 403 em `match_register`, `reward` e `match_wallet`.

## Desempenho: resultado e limite

GTX 1650, 1920×1080, limite de 60 FPS, servidor e clientes no mesmo PC; somente um cliente renderiza. A rodada sem profiler com doze clientes registrou **59,47 FPS médios**, **1% low de 38,82 FPS** e **pior quadro de 28,94 ms**.

**Isso não comprova 60 FPS estáveis. O FPS do treino offline com bots ainda não foi medido.** Há uma rodada separada com Profiler e histórico antes/depois, com diferenças de instrumentação/carga explicitadas em [GUERRA-DESEMPENHO.md](GUERRA-DESEMPENHO.md). Pools, LOD e agrupamento reduzem trabalho, mas não substituem novas medições em outros PCs e sessões mais longas.

## Referências consultadas

Organização do HUD/implantação: [gameplay oficial BF2042 no Xbox Wire](https://news.xbox.com/en-us/2021/10/06/battlefield-2042-open-beta-starts-today/), [EA — classes](https://www.ea.com/games/battlefield/battlefield-2042/news/dev-notes-classes-in-battlefield-2042) e [EA — Update 3.2.0](https://www.ea.com/en-au/games/battlefield/battlefield-2042/news/battlefield-2042-update-notes-3-2-0). Hierarquia de munição/equipamento, objetivos separados, equipes e espaçamento foram adaptados às cores existentes.

Modelos: [IDV — Guarani](https://www.idvgroup.com/products/amphibious-armoured-vehicles/guarani/), [ARES — REMAX](https://ares.ind.br/torres-e-sistemas/), [Ukrspecexport — BMP-2](https://www.ukrspecexport.com/uploads/files/Categories/pdf_5/be2e23.pdf), [GDLS — Abrams](https://www.gdls.com/abrams/), [folheto M1A2](https://international.gdls.com/english/products/ABRAMS/M1A2.pdf) e [Parque Patriot — T-90A](https://parkpatriot.ru/o-parke/tekhnika-parka/t-90a/). Geometria própria e simplificada; não é uma reprodução industrial.

## Próxima atualização — 1.6.1 em desenvolvimento

Pedidos recebidos depois da publicação: **reaparecer veículos na base da própria equipe após exatamente 60 segundos**, melhorar animações de corrida e adicionar/revisar passos. Esses trabalhos estão em andamento e **não são declarados implementados nem incluídos no build 26**.


Também em integração para a **1.6.1**: Guarani/BMP-2 com um operador e até cinco passageiros; Abrams/T-90 com um operador e um passageiro. Ocupação e papéis dos assentos, promoção de passageiro a operador, saída em posição livre e morte de todos os ocupantes quando o blindado for destruído deverão ser controlados pela autoridade. São alterações posteriores ao build 26 e ainda não são declaradas entregues nesta documentação.
