# Battle Royale — conclusão local

Atualização da mochila e da arquitetura de acessórios: [Inventário modular e corpos saqueáveis](INVENTARIO-MODULAR-E-CORPOS.md). Essa revisão substitui a antiga organização por seções e o seletor de luneta descritos abaixo.

29/10/2026. Implementação do BR concluída localmente e revisada no Godot 4.7.2, Compatibility/GTX 1650. Revisão posterior de pareamento, mochila, combate com ópticas e personagem em `BR-PAREAMENTO-E-REVISAO.md`. Não houve publicação, instalação de atualização nem alteração do servidor em uso. Nova Grama e pedras adicionais nas encostas continuam fora desta entrega. A modalidade Guerra tradicional no Afeganistão continua um trabalho separado; esta conclusão cobre o Battle Royale solicitado agora.

## Partida e mapa

- Individual, sem veículos, avião, escolha manual de spawn ou respawn. Início desarmado e com vida cheia. Offline com jogador e sete bots; online com capacidade de 12 e bots preenchendo vagas. Pareamento fixo de 30 s; um humano basta. Partidas iniciadas fecham a admissão; novas buscas recebem outra sala.
- Servidor decide dano, eliminações, vencedor, loot e zona. Múltiplas mortes no mesmo evento/tick são resolvidas antes do vencedor; desconexão e empate na zona final são tratados.
- Resultado, intervalo de 60 s, nova espera de 30 s e nova rodada com limpeza de projéteis, loot, cura, postura, proteções, lunetas, estado de tiro e espectador. Sem mistura das estatísticas BR com ranking de outros modos.
- Mapa afegão utiliza suas construções exploráveis, propriedades e objetos contextuais existentes. Navegação preparada fora da partida: 661 candidatos secos, livres e conectados para spawn/zonas; 135 âncoras acessíveis de loot, incluindo 90 internas e 43 em telhados. Os outros dois pontos são agrícolas contextualizados. 74 marcadores sem acesso comprovado não recebem loot.
- Corrigidas buscas de caminho longas interrompidas pelo limite padrão e conexões das escadarias. Dados de navegação: 73.876 polígonos, 88 regiões e aproximadamente 2,96 MB. Sem reconstruir a navegação durante a partida. Bots reutilizam rotas, procuram arma/munição compatível, recarregam, combatem e seguem a zona.

## Personagem e combate

- Corpo humano articulado compartilhado com o Guerra como padrão dos modos de infantaria. BR começa com roupas simples, sem equipamentos militares permanentes.
- Socos alternados com braços FPP/TPP, contato na janela da animação, alcance/cadência e validação no servidor. Compensação geométrica limitada a 120 ms, sem retroceder a física do mundo.
- Agachar e deitar mantidos, com colisão, câmera e limite de mira para baixo. Javelin raro e sem trava somente no BR, com munição e recarga próprias.
- Mochilas, coletes e capacetes 1/2/3 são loot equipável. Bolsos/mochilas: 60/100/140/180 unidades. Proteções absorvem 30/40/55% e têm resistência 60/100/150; capacete na cabeça, colete no tronco/pelve. Dano absorvido desgasta o item. Zona e queda não recebem essa redução.
- Granada compartilhada aumentada de 120 para 160 de dano-base, em todos os modos que a utilizam. Preservados raio, queda por distância e bloqueio por cobertura. Tiros e explosões mantêm o aumento de volume e a reprodução espacial.

## Mochila e lunetas

- Tab/I: proximidades, inventário e equipamento. Dois slots de armas; 1/2 selecionam e 3 retorna aos punhos. Backspace larga a arma atual. Munição por calibre, curativos, capacidade e resistência ficam visíveis.
- Coleta parcial, troca, descarte, recarga interrompida por descarte, disputa do mesmo item e loot do corpo preservam quantidades. Um contêiner por corpo; objetos visuais próximos usam pool e limite de criação por quadro.
- Prismática 4× e PSO 4× são acessórios separados encontrados no mapa. Ambas podem equipar FAL e AK; os modelos existentes recebem suporte apropriado sem reconstruir a arma. Catálogo central define modelo, nome, ampliação e compatibilidade.
- Luneta solta ocupa quatro unidades. A lista na arma oferece mira de ferro e ópticas disponíveis; instalar consome uma unidade, trocar devolve a anterior. Remover exige espaço na mochila. Descarte/morte preserva a luneta instalada na arma e os acessórios soltos restantes.
- Visão da lente é renderizada ao vivo ao mover a mira, com ampliação 4× calibrada e somente um viewport local de 384 × 384 ativo durante a mira. Modelo/óptica equipada aparece aos demais e na entrada tardia; conteúdo da mochila e munição permanecem privados.

## Zona, morte e interface

- O servidor replica parâmetros da zona; clientes interpolam visualmente. Círculos contidos no anterior, centros acessíveis, dano progressivo e oito fases da tabela original, total de 15 min 25 s até o fechamento completo.
- HUD de vida em destaque, equipamento, munição, cura/recarga, vivos/abates, minimapa, próxima zona, direção correta para segurança e avisos temporários. A borda no mundo desenha apenas um arco próximo, sem colisão ou cilindro gigante.
- Aviso de responsável/arma/distância ou causa ambiental. Espectador FPP/TPP, troca entre sobreviventes e resultados próprios acessíveis após morrer. Minimapa acompanha apenas o observado; não recebe o inventário dele.
- Resultado contém colocação, tempo, distância, abates, dano causado/recebido, tiros/acertos/precisão, arma mais usada, itens e causa. Vitória tem apresentação própria. Menus usam o tema compartilhado; trilhos e valores dos controles de áudio ficaram legíveis.

## Voz por proximidade

- X para falar, somente vivos. Opus mono, 24 kHz, 20 kbps, quadros de 20 ms, DTX/FEC e buffer de jitter limitado. Canal não confiável dedicado dentro do ENet/DTLS.
- Servidor apenas retransmite bytes, fixa a identidade do falante e verifica vida/rodada, distância, mute, tamanho, sequência e taxa. Servidor headless não cria codec nem captura áudio.
- Reprodução 3D na cabeça do personagem, até seis falantes próximos, padrão claro até 10 m e inaudível após 40 m. Volume, alcance, silenciar, desligar chat e seleção de dispositivo na página Áudio.
- Preferências de voz acompanham a conta; dispositivo de microfone é local à máquina.
- Sair encerra microfone, encoder/decoders nativos, filas PCM/jitter, falantes, presença, bloqueios e barramento temporário. Pacotes atrasados não reativam a sala anterior; reentrada começa limpa. Saída também encerra sons e música do cenário.

## Validação concluída

| Verificação | Resultado | Relatório em work/ |
|---|---:|---|
| Estado BR/inventário/zona | 1.083 aprovadas | br-state-validation.json |
| Personagem, equipamento e combate | 60 aprovadas | br-completion-validation.json |
| Ciclo, morte, espectador, vencedor e reinício | 28 aprovadas | br-round-flow-validation.json |
| Bots em combate/coleta/recarga | 6 aprovadas | br-bot-flow-validation.json |
| Navegação e acessibilidade | 339 aprovadas | br-navigation-validation.json |
| Inventário de lunetas e troca atômica | 33 aprovadas | br-optic-inventory-validation.json |
| Servidor + três clientes ENet/DTLS, inventário, baseline de observador forçado em QA e reinício | 54 aprovadas | br-loot-network.json |
| Codec Opus e perda/atraso/reordenação | 423 aprovadas | br-voice-codec-validation.json |
| Servidor + quatro clientes, filtros de voz | 15 aprovadas | br-voice-network.json |
| Encerramento e reentrada da voz | 13 aprovadas | br-voice-lifecycle-validation.json |
| Ópticas, quatro combinações e atualização visual | 54 aprovadas | optic-catalog-validation.json |
| Origem do projétil com luneta | 490 aprovadas | scoped-muzzle-regression.json |
| HUD/mochila/controles/pool visual | 52 aprovadas | br-ui-validation.json |
| Granada: dano, distância e paredes reais | 5 aprovadas | grenade-damage-validation.json |
| Conteúdo do pacote de servidor | 96 aprovadas | br-server-pack-probe.json |

O mapa completo iniciou uma partida offline com oito participantes e 151 loots; a rodada seguinte também foi validada no teste multiplayer com a nova tabela de loot. Importação final sem erros. Capturas reais de 1280 × 800 em Compatibility: `br-final-map-hud.png`, `br-final-inventory.png`, `br-final-optic.png`, `br-final-zone.png`, `br-final-voice-settings.png`. A revisão visual pausou atores para inspeção; não é benchmark.

O pacote de QA foi criado somente em `work/`. Confirmados manifesto e 88 recursos de navegação, sem intermediários, testes, chaves privadas ou bibliotecas de voz. Foi carregado no Godot Windows com configuração de servidor Linux; não equivale a executar o binário num Linux real. O teste release Windows do codec foi um executável mínimo isolado, não publicação do jogo.

Áudio sintético percorreu Opus, jitter e WASAPI; conversa humana e latência acústica pela VPN não foram avaliadas subjetivamente. Não houve nova série de benchmarks nem afirmação de ganho de FPS nesta conclusão, conforme a orientação de priorizar a gameplay.
