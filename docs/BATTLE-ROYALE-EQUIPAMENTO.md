# Battle Royale — personagem, mochila e combate

Revisão inicial de 28/10/2026; conclusão ampliada em 29/10/2026 em `BATTLE-ROYALE-CONCLUSAO.md`, incluindo voz, navegação e lunetas como loot. Sem instalar ou publicar uma versão no servidor. A organização do inventário usa PUBG como referência; modelos e interface próprios, mantendo o tema do jogo.

## Comportamento entregue

- Tab abre/fecha a mochila; I permanece como alternativa. Três áreas: proximidades, inventário, equipamento. Não abre sobre outras telas de configuração.
- Dois slots de armas; 1 e 2 selecionam as armas e 3 os punhos. A primeira arma recolhida é equipada automaticamente. Backspace larga a arma atual; a mochila também oferece descarte. Munição fica no carregador da arma descartada, enquanto a reserva permanece no inventário.
- Descarte durante recarga cancela a recarga. Arma descartada pode ser recolhida por outro jogador. Mortos e mensagens antigas de outra vida/rodada não podem alterar o inventário ou recriar loot do corpo.
- Munição e curativos têm peso; armas, mochila e proteções equipadas usam slots próprios. Coleta parcial preserva no chão o que não cabe. Caixas de corpo permitem escolher itens individualmente; F mantém a coleta prática. Identificadores internos de munição não aparecem no inventário.

| Mochila | Capacidade total |
|---|---:|
| Sem mochila | 60 |
| 1 | 100 |
| 2 | 140 |
| 3 | 180 |

Valores em unidades de inventário. Coletar uma mochila melhor substitui a anterior, deixando-a disponível. O botão de largar a mochila fica desativado enquanto seu conteúdo não cabe nos bolsos, sem destruir o excesso.

| Proteção | Resistência | Absorção |
|---|---:|---:|
| 1 | 60 | 30% |
| 2 | 100 | 40% |
| 3 | 150 | 55% |

Capacete protege a cabeça; colete protege peito/abdômen/pelve. Membros e zona não recebem essa redução. O dano absorvido consome resistência; equipamento esgotado sai do personagem. Upgrades deixam o item anterior no chão, com a resistência restante. Nível e resistência são preservados no loot do corpo.

- BR começa com roupa simples, sem capacete, colete ou mochila militar permanentes. Equipamento coletado aparece nos outros clientes e na entrada tardia. Nove cenas reutilizáveis em `modes/battle_royale/ui/equipment/`: `vest_1..3`, `helmet_1..3`, `pack_1..3`. Geometria estática agrupada por material, sem física por item de loot.
- O personagem humano articulado e o uniforme do Guerra são o padrão nos demais modos de infantaria. O BR compartilha o corpo, com vestuário próprio. Agachar e deitar reutilizam as articulações, colisão, altura de câmera e limite de mira deitado. Som dos passos reutiliza o banco por superfície, sem trazer a ambientação de veículos do Guerra para o BR.
- Punhos têm luvas e antebraços na visão FPP e braços articulados na visão externa. Golpes alternam e o servidor verifica acerto na janela ativa da animação.
- Tiros e explosões recebem +3 dB nas fontes compartilhadas; continuam com atenuação 3D, canais de volume existentes e limitadores.
- HUD dá mais espaço à vida, barra larga e cor de estado crítico. Mostra proteção, recarga e uso de curativo. Minimapa mantém círculos dentro do seu quadro.
- Javelin raro usa o modelo existente, um projétil carregado e recarga de 4,5 s com munição própria. Dispara sem trava apenas no BR, pelo mesmo caminho validado de cadência/munição das armas. Explosão bloqueada por cenário, inclusive dano ao próprio atirador; várias eliminações são concluídas antes da escolha do vencedor.
- Morte sem respawn; aviso com responsável, arma e distância ou causa ambiental. Transição para espectador e alternância FPP/TPP. Resultado com estatísticas e intervalo de 60 s, seguido de limpeza dos projéteis, loot, postura e equipamentos para a nova rodada.

## Verificação

`tests/br_completion_validation.gd` verifica inventário, níveis de mochila, coleta parcial, proteção por região, braços, posturas, descarte durante recarga, Javelin, morte e reinício. `tests/br_ui_validation.gd` cobre os estados da interface e o pool visual. Os relatórios ficam em `work/br-completion-validation.json` e `work/br-ui-validation.json`.

`tests/run_br_loot_network.ps1` usa servidor headless e três clientes locais ENet/DTLS, incluindo um cliente que entra depois: disputa de loot dentro de casa, validação de distância/parede/vida/rodada, transferência de arma descartada e réplica de mochila/proteções. Usa colisões reais do mapa afegão; a preparação de QA substitui login e movimentação. Relatório: `work/br-loot-network.json`.

`tests/br_play_smoke.gd` inicia o BR offline completo no mapa afegão com sete bots e três segundos de física normal. Não é benchmark. A revisão das posturas/armas do Guerra continua em `tests/pose189_validation.gd`.

Capturas em Compatibility/GTX 1650: `work/br-fists-hud.png`, `work/br-backpack.png`, `work/br-protection-human.png`. A cena das capturas é uma área simples para inspecionar equipamento, não uma representação do mapa final. Não há afirmação de ganho de FPS ou medição de latência real da VPN nesta revisão.

## Conclusão posterior

Voz por proximidade e navegação preparada foram integradas ao BR; as lunetas agora são itens independentes de loot, compatíveis com FAL e AK. Sistemas, validações e limites estão em `BATTLE-ROYALE-CONCLUSAO.md`. A modalidade Guerra tradicional no Afeganistão permanece separada desta conclusão. Publicação continua dependendo da aprovação do usuário.
