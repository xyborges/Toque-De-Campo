# Revisão do plano — histórico e fechamento na 1.6.3

**Estado atual em24/10/2026: 1.6.3/build29 publicada.** As quatro lacunas listadas ao final desta auditoria foram implementadas: áudio distante compartilhado, HUD de classes confirmado pela autoridade, persistência idempotente de mortes online e pausa/retomada de recarga. Resultados finais em [ATUALIZACAO-1.6.3.md](ATUALIZACAO-1.6.3.md). O ranking passa a contar também mortes online por ambiente/suicídio, sem gerar abates/moedas; treino offline/NPCs continuam excluídos. As tabelas abaixo preservam o diagnóstico anterior, não uma lista atual de funcionalidades ausentes.

Atualizado em 24/10/2026. O plano recebido está preservado em `work/plano-audio-score-ranking-hud.txt`. A base abaixo foi integrada à 1.6.0/build 26. A versão corrente é **1.6.1/build 27**, publicada e validada no Ubuntu; os pedidos de tripulação, respawn e locomoção foram encerrados antes da retomada das lacunas auditadas deste plano. Confirmações em `work/release160-publication.log` e `work/release161-publication.log`.

## Estado entregue e limites

| Etapa | Implementado e validado | Limites preservados |
| --- | --- | --- |
| Áudio 3D | `GameWeaponAudio` compartilhado por infantaria/Guerra, recursos pré-carregados, até 96 vozes e origem fixa por disparo. Listener na cabeça, independente da distância FPP/TPP. Atenuação, filtros e oclusão com orçamento de consultas; Guerra reutiliza WarSoundscape sem oclusão duplicada. | Alcances configurados de 500 m para pistola, 700 m para FAL, 1.000 m para sniper/metralhadoras e 1.500 m para canhões/lançadores são parâmetros do jogo. Captura do mixer não substitui escuta humana entre PCs. |
| Scoreboard | Pontos, abates, mortes, assistências, K/D, dano efetivo, objetivos e ping autoritativo. Equipes em Guerra, classificação individual nos modos próprios, linha local/líder e fontes legíveis. Linhas reutilizadas por revisão; TAB mantém movimento/câmera. Abertura por código também inicializa o contexto imediatamente. | Ping sem medição aparece como `—`; offline não mostra a coluna. Pontuação da partida não é saldo de moedas. |
| Estatísticas | Dano usa HP realmente retirado, incluindo blindados/drones; sem transformar dano em eliminações fictícias. Suporte contabiliza cada destinatário/tipo, deduplica antes das frações, limita a recompensa e libera registros ao sair. | O placar da partida conta suas mortes reais. O ranking persistente conta mortes decorrentes de abates válidos registrados pelo servidor; suicídios, ambiente e treino offline não alimentam esse ranking. |
| Ranking Global | Menu suspenso independente, à direita, com setas para abates, K/D, mortes e moedas. Top 10 calculado pela API, cache horário, mínimo de 20 eliminações + mortes no K/D e cache local válido preservado se a conexão falhar. | Não mostra pontos/tickets da partida como dinheiro. Atualização é horária, portanto não reflete cada abate imediatamente. |
| Granada | G/3 equipa desarmada; segurar clique inicia pavio de 5 s e soltar lança. Barra na mão e indicador próximo usam o mesmo tempo da simulação. Pós-lançamento: até oito indicadores, distância máxima de 24 m e oclusão por paredes. Classe Soldado de Guerra utiliza o mesmo sistema. | Latência/perda fora do laboratório e outros dispositivos exigem validação continuada. |
| Slots/HUD | 1 pistola, 2 principal, 3 granada e 4 arma branca resolvidos pelo equipamento real. Extras em 5/6/9; 7/8 preservados para RPG/Stinger. Munição, reserva, quantidade de granadas, recarga, vazio e indisponibilidade visíveis; ícone próprio de granada e contraste da seleção. | O HUD naval e o painel dos veículos mantêm informações próprias. Não foram copiados gráficos do BF2042. |
| Guerra | Mesmo jogo, conquista A/B/C, classes, terreno de 2 × 2 km, quatro blindados, drones e autoridade central. Treino offline: um humano, cinco aliados e seis adversários com sistemas compartilhados, sem sala/ENet ou recompensa global. | Bots não pilotam blindados/drones nem usam autonomamente lançadores/granadas. A medição offline posterior da 1.6.1 cobriu navegação com zero tiros, não combate intenso. |
| Otimização | Pools, projéteis ativos, consultas reutilizadas, geometria agrupada, LOD e cache de UI/ranking. Medições 1/6/12 clientes da 1.6.0 e revisão posterior de locomoção na 1.6.1. | Doze clientes na 1.6.1: 59,19 FPS médios/1% low 40,12; não comprova 60 FPS estáveis. Offline: 60,00/54,11 em navegação, zero tiros. Detalhes em `GUERRA-DESEMPENHO.md`. |

## Evidências finais

| Área | Resultado | Evidência |
| --- | ---: | --- |
| Operação Guerra offline real | 42 verificações | `tests/war-offline-results.json` |
| Equipamentos offline e controles/câmeras | 34; duas execuções finais aprovadas | `tests/war-offline-equipment-results.json`, `work/war-offline-equipment-diagnostic.log`, `work/war-offline-equipment-repeat.log` |
| Entrada offline pelo pacote exportado | 4 verificações | `work/war-offline-pack-engine.log` |
| Menu Guerra offline/online | 17 verificações | `tests/war-menu-results.json` |
| Guerra: regras, terreno, torretas e recursos | 79 verificações | `tests/war-systems-results.json` |
| Modelos opacos e LOD dos quatro blindados | 109 verificações | `tests/war-vehicle-models-after.json` |
| Scoreboard/ranking suspenso, 1/3/6/12 linhas | 54 verificações | `tests/scoreboard-visual-results.json` |
| HUD de equipamento e granadas | 25 verificações | `tests/equipment-hud-results.json` |
| Estatísticas, suporte, limites/deduplicação | 34 verificações | `tests/match-stats-results.json` |
| Áudio espacial / sons fornecidos | 28 / 43 verificações | `tests/spatial-weapon-audio-results.json`, `tests/supplied-audio-results.json` |
| Autoridade da API / ranking isolado | 67 / 12 verificações | `tests/account-authority-results.json`, `tests/account-rankings-results.json` |
| Guerra ENet local, servidor + três clientes | 18 verificações | `tests/war-multiplayer-{server,alpha,bravo,medic}.json` |
| Guerra central Ubuntu, dois clientes | 17 verificações | `work/release160-ubuntu-war.log` |
| Ranking na API publicada e recusas HTTP 403 | 10 verificações | `tests/ubuntu-ranking-results.json`, `work/release160-live-ranking.log` |
| Download/launcher reais, instalar e não baixar novamente | Aprovados | `tests/ubuntu-distribution-results.json`, `work/release160-distribution.log` |

São contagens de baterias específicas, não cobertura total nem doze jogadores humanos em PCs separados. As regressões Naval e PvP Deserto contra a VM passaram em `work/release160-ubuntu-naval.log` e `work/release160-ubuntu-pvp.log`. A versão exportada entrou sem login/rede no treino offline, com onze bots, e sem sobreposição do menu.

A regressão de rede local inicialmente falhou porque o Stinger da fixture matava o médico antes de ele testar o FAL. O cenário foi separado fisicamente, sem alterar dano/combate, e a execução final confirmou disparo e recarga completa no servidor/cliente. Os relatórios por papel são a evidência final; o log histórico da falha foi preservado.

## Segurança publicada

`match_register`, `reward` e `match_wallet` exigem credencial Service nos três modos, inclusive para registros legados. A API publicada devolveu HTTP 403 às três operações tentadas com credencial comum. Compra, seleção, aparência, perfil, login, logout e ranking continuam sendo ações da conta.

O cliente não informa o valor da recompensa nem o saldo do ranking. Eventos persistentes são idempotentes; sessões, senhas e chaves privadas não são expostas pelo painel. Os testes isolados usam PHP/SQLite separados; as verificações contra a VM usam a API real.

## Referências visuais e identidade

- [Gameplay oficial do BF2042 no Xbox Wire](https://news.xbox.com/en-us/2021/10/06/battlefield-2042-open-beta-starts-today/) e [imagem do artigo](https://xboxwire.thesourcemediaassets.com/sites/2/2021/10/Battlefield-2042-Xbox-One-V1_JPG.jpg): hierarquia de munição/equipamentos no canto inferior direito e objetivos separados.
- [EA — classes no BF2042](https://www.ea.com/games/battlefield/battlefield-2042/news/dev-notes-classes-in-battlefield-2042) e [Update 3.2.0](https://www.ea.com/en-au/games/battlefield/battlefield-2042/news/battlefield-2042-update-notes-3-2-0): organização de implantação, equipamento e HUD.
- [Godot — AudioStreamPlayer3D](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer3d.html): listener, atenuação e filtros.
- Modelos: [IDV/Guarani](https://www.idvgroup.com/products/amphibious-armoured-vehicles/guarani/), [ARES/REMAX](https://ares.ind.br/torres-e-sistemas/), [Ukrspecexport/BMP-2](https://www.ukrspecexport.com/uploads/files/Categories/pdf_5/be2e23.pdf), [GDLS/Abrams](https://www.gdls.com/abrams/), [folheto M1A2](https://international.gdls.com/english/products/ABRAMS/M1A2.pdf) e [Parque Patriot/T-90A](https://parkpatriot.ru/o-parke/tekhnika-parka/t-90a/).

Paleta do login preservada: destaque `#b7cca1`, texto `#e7ede8`, secundário `#97aaa9`, fundo `#071013` e borda `#364746`. FieldTheme centraliza painéis, transparências, botões e estados. A organização foi adaptada ao estilo existente. Capturas próprias foram renderizadas e inspecionadas no Godot; a pesquisa não é apresentada como uma inspeção interativa completa do BF2042.

## Fechamento da 1.6.1

**1.6.1/build 27 publicada e validada:** reaparecimento na própria base após 60 segundos, corrida/passos e tripulações. Houve 33 verificações no serviço central com três contas reais, instalação real e segunda abertura do launcher sem download repetido. Evidências em `ATUALIZACAO-1.6.1.md`.


As capacidades publicadas são um operador + cinco passageiros nos APCs e um operador + um passageiro nos tanques. Ocupação, promoção do passageiro mais antigo, saída em posição livre e morte de todos os embarcados na destruição são autoritativas. Não fazem parte do histórico do build 26.

## Auditoria integral do pedido original — fila após a 1.6.1

Revisão em 24/10/2026, após releitura integral de `work/plano-audio-score-ranking-hud.txt`, incluindo as oito etapas e os testes A–F. A auditoria foi preparada enquanto a 1.6.1 fechava suas verificações. **Com o build 27 agora publicado e validado, os itens 1–4 abaixo são a próxima fila de implementação**, sem reescrever o que já funciona.

### Mapeamento das oito etapas

| Etapa original | Cobertura existente | Restante identificado |
| --- | --- | --- |
| 1. Áudio 3D | Listener local na cabeça; câmera FPP/TPP não altera a origem auditiva. Perfis por arma, atenuação, vozes limitadas, oclusão e reprodução de eventos remotos. `scripts/weapon_audio.gd`, `scripts/player.gd`, `modes/war/scripts/audio.gd`. | Em Guerra, o controlador acústico externo não aplica a rota específica de som distante usada no Deserto. Ver item 1 abaixo. A matriz de duas instâncias remotas com os WAV reais a 50/100/200/300 m não está coberta pelo teste atual de mixer. |
| 2. Scoreboard | Todas as colunas solicitadas; pontos autoritativos, ordenação por pontos/abates/assistências, assistências com contribuição efetiva, headshot/distância, captura/neutralização/defesa, blindado/drone e suporte limitado. `scripts/match_stats.gd`, `scripts/main.gd`, `scripts/desert_domination.gd`, `modes/war/scripts/game.gd`, `modes/war/scripts/vehicles.gd`. | Não há sistema de reanimação de aliado no jogo atual. Portanto o bônus proposto de +100 não foi ligado a uma ação inexistente. O pedido manda adaptar às funcionalidades existentes; não exige criar reanimação somente para produzir pontos. |
| 3. Ranking Global | Quatro top 10, dados persistentes, saldo do servidor, K/D com participação mínima e denominador seguro, setas, top 3, atualização assíncrona, hora e último cache válido. `account-service/api.php`, `scripts/ui/global_ranking.gd`, `scripts/ui/main_menu.gd`. | O total persistente de mortes cobre somente abates inimigos registrados. Suicídios/ambiente ficam no placar da partida, mas não no top de mortes/K/D global. O cache de uma hora é refeito sob demanda; esse desenho é explicado separadamente abaixo. |
| 4. Granada | HUD usa o pavio real de cinco segundos, cozimento, tempo em décimos, barra, perigo final, limite por distância/visibilidade, oclusão e remoção na explosão. Snapshots têm relógio/deadline do servidor. `scripts/grenades.gd`, `scripts/ui/grenade_timers.gd`, `scripts/ui/infantry_hud.gd`. Física, quique, guia, cobertura e dano anteriores foram preservados. | Nenhuma mecânica nova ausente identificada nesta auditoria. Ampliar a prova de sincronização do contador renderizado entre duas instâncias com atraso/perda; os testes de transporte/explosão e o teste visual isolado hoje são baterias separadas. |
| 5. Slots | Inventário real resolve 1 pistola, 2 principal, 3 granada e 4 arma branca, com prioridade do rodo e fallback vassoura/machado. Extras 5/6/9 e classe 7/8/contextual preservados. Troca imediata e sincronizada sem recriar inventário. `scripts/inventory_slots.gd`, `scripts/player.gd`. | Munição/reserva por arma são preservadas, mas trocar arma chama `cancel_reload()` e perde o progresso parcial. Não existe estado pausado de recarga por arma; ver item 4 abaixo. |
| 6. HUD | Painel inferior direito, quatro slots, valores reais, destaque ativo, ícones, pouca munição/vazio, recarga, disponibilidade e quantidade de granadas; HUD de veículo separado. Paleta do login preservada e referências reais BF2042 documentadas. | O HUD de Guerra ainda mostra o FAL quando um lançador está ativo e não exibe as cargas de RPG/Stinger ou de suporte médico/soldado. Ver item 2 abaixo. |
| 7. Integração/otimização | Placar por revisão, linhas e indicadores reutilizados, texto de munição atualizado ao mudar, ranking fora do loop de render, áudio/projéteis limitados e autoridade preservada. Medições da 1.6.0 e revisão medida da 1.6.1, com locomoção ativa e navegação offline. | Não atribuir os números antigos à versão nova nem navegação offline a combate intenso; a rodada offline registrou zero tiros. Não foi feita validação em um segundo computador de menor desempenho. |
| 8. Testes A–F | Baterias existentes cobrem áudio espacial, estatísticas e UI, PHP/SQLite real, granadas, slots/HUD, transporte, entrada/saída/reconexão e frame time. Contagens da versão 1.6.0 estão na tabela acima. | Completar a matriz de áudio remoto real e a leitura de cronômetros entre instâncias; acrescentar testes específicos dos itens 1–4 depois das respectivas mudanças. Não reapresentar testes sintéticos como escuta humana ou bancada em outro hardware. |

### Ordem de implementação recomendada depois do fechamento da 1.6.1

1. **Som distante de Guerra.** `modes/war/scripts/audio.gd` habilita `external_acoustics=true`, pulando `GameWeaponAudio._process()`. O Deserto usa `WeaponFar` além de 100 m, com filtro de 2.600 Hz e reverberação; `WarSoundscape._update_acoustics()` atualmente escolhe somente a categoria normal, bloqueada ou interior. Integrar a característica distante no controlador de Guerra, respeitando as categorias existentes e sem aplicar oclusão ou ganho duas vezes. Validar som aberto/bloqueado e FPP/TPP a 50/100/200/300 m com os recursos reais de armas e dois clientes.
2. **HUD dos equipamentos de classe.** `WarPlayer.set_gadget()` mantém `weapon_id` da arma primária enquanto `gadget_equipped` determina o lançador. `GameInfantryHUD.refresh()` e `_refresh_slots()` leem apenas arma/granada; `WarUI` não acrescenta um contador de `members[peer].charges`. Mostrar o gadget realmente ativo, suas cargas/disponibilidade e os atalhos 7/8 ou G/H correspondentes, sem sobrescrever os quatro slots nem esconder a munição da arma guardada. Testar consumo, recarga/cooldown aplicável, morte, respawn, veículo e reconexão para cada classe.
3. **Persistência de todas as mortes online elegíveis.** A ação `reward` da API soma a morte da vítima junto ao abate e exige autor e vítima diferentes; as rotinas de morte do jogo não enviam suicídio/ambiente como evento persistente. O plano pede top de mortes sem esse filtro. Acrescentar um evento de morte validado pela autoridade, idempotente por partida/vítima/vida, que não conceda abate/moedas a ninguém e não duplique a morte já registrada por `reward`. Preservar o isolamento do treino offline e os dados existentes. Testar suicídio, ambiente, abate normal, duplicação, ordenação e K/D. Até essa mudança, manter explícito que o ranking atual cobre mortes por abates válidos.
4. **Estado de recarga na troca de arma.** `GamePlayer.equip_slot()` chama `cancel_reload()`; existe apenas um conjunto `reload_weapon/reload_left/reload_total`, e `Main._equip_server()` e `remote_equipped()` também cancelam a recarga. Revisar o comportamento para atender à preservação pedida: guardar estado por arma e retomá-lo de forma autoritativa, sem criar munição, concluir duas recargas ou permitir disparos durante uma transição inválida. A pausa/retomada deverá continuar usando a animação e o áudio comuns; morte, respawn e entrada em veículo precisam ter política explícita de cancelamento. Esse comportamento ainda não está implementado.

**Cache de 60 minutos: desenho operacional, não uma implementação ausente de ranking.** A API registra `created`/`expires_at`, retorna a mesma fotografia por uma hora e recalcula na primeira consulta depois da expiração, dentro de transação. Não há cron que recalcule enquanto ninguém consulta. Isso evita trabalho sem consumidores e atende ao cache horário para quem abre o painel; não requer cron para corrigir o ranking visível. Somente acrescentar agendamento independente se for exigido que a fotografia seja renovada no relógio mesmo sem acessos.

### O que os testes realmente demonstram

- `tests/spatial_weapon_audio.gd` aprovou 28 verificações. Captura PCM real do mixer, mas substitui Glock/FAL/sniper por uma sonda determinística de três frequências para medir atenuação. Mede 50/100/200/300 m, FPP/TPP, esquerda/direita, parede e limites de vozes; **não dispara os três WAV reais entre dois processos de jogo nessas distâncias**.
- `tests/scoreboard_visual.gd` aprovou 54 verificações com estatísticas controladas e `tests/match_stats.gd` aprovou 34, incluindo o caminho real de hitbox/dano. A rede de Guerra e o servidor central validam eventos complementares; as 12 linhas do teste visual não equivalem a 12 humanos.
- `tests/account_rankings.py` aprovou 12 verificações contra PHP/SQLite isolados, incluindo mudanças persistentes, cache/expiração, ordenação, participação mínima e saldo. A expiração é avançada na fixture; não exige aguardar uma hora de relógio. `tests/ubuntu-ranking-results.json` aprovou dez verificações na API publicada.
- `tests/equipment_hud.gd` aprovou 25 verificações de slots, munição, granada/contador, oclusão e remoção. `tests/combat_155.gd` e os testes de rede existentes preservam pavio, física, cobertura, morte/reconexão. Nenhum desses testes afirma que a recarga retoma progresso após trocar de arma.
- O benchmark `final-play` de doze clientes, 59,47 FPS médios e 1% low 38,82, é do build 26. A 1.6.1 registrou 59,19/40,12 após revisão da locomoção e 60,00/54,11 em navegação offline sem tiros. Nenhuma dessas execuções comprova 60 FPS estáveis em todo combate. A meta de testar hardware mais modesto permanece uma validação adicional, não uma justificativa para reescrever os sistemas já corretos.


