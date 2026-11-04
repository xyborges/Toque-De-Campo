# Afeganistão e Battle Royale — especificação recebida

Estado em 29/10/2026: BR concluído localmente, incluindo voz, navegação, equipamento, lunetas e validação multiplayer; ver `BATTLE-ROYALE-CONCLUSAO.md`. Esta nota preserva o pedido original, que também contém a integração do Guerra tradicional ao cenário afegão, um trabalho separado do BR agora finalizado. Sem publicação. Nova Grama fica fora da atualização atual.

Fonte completa: anexo `b2ac4fc9-c1a1-4c5f-9e41-9d29f269daaf/Texto colado.txt`, recebido em 28/10/2026. Reconsultar o anexo ao iniciar cada etapa; esta nota não substitui seus requisitos.

## Integração e cenário

- Novo cenário do Guerra existente, sem recriar o jogo ou alterar desnecessariamente a Ucrânia. Seleção inicial: Guerra na Ucrânia / Guerra no Deserto; no cenário desértico, Guerra tradicional ou Battle Royale.
- Área jogável de 2.000 × 2.000 m. Hindu Kush, planícies áridas, colinas, montanhas, vales, desfiladeiros, riachos e irrigação; regiões orgânicas e rotas acessíveis. Horizonte desértico simplificado além do limite, sem oceano artificial nem quilômetros adicionais de colisão.
- Vilarejos de adobe/pedra com telhados planos, pátios, vielas, mercados, depósitos, estábulos, ruínas, muros e escadas. Parcela significativa explorável, com interiores e telhados onde se espera loot. Densidade sugerida: um povoado de 20–30 casas, três de 8–15 e 5–8 grupos de 2–6; ajustar ao orçamento medido.
- Arbustos e capim secos, árvores esparsas e choupos/salgueiros nos vales irrigados. Distribuição e materiais próprios; reutilizar técnicas de MultiMesh/LOD/células, sem presumir aprovação da Nova Grama. Servidor sem vegetação visual, materiais compartilhados, ausência de scripts por detalhe e paridade de cobertura entre presets.

## Modalidades

Guerra tradicional reutiliza equipes, bases, objetivos, tickets, respawn, classes, armas, blindados e bots. Bases/rotas/veículos respeitam o relevo. Spawns e pontuação separados do Battle Royale.

Battle Royale inicial individual, sem veículos, sem respawn, sem avião/paraquedas e sem escolha manual de spawn. Início desarmado, vida cheia, posições aleatórias seguras e separadas. Servidor determina eliminações e último sobrevivente. Começar com capacidade já suportada, ajustando loot e zona a testes; não inventar capacidade maior.

## Sistemas a reutilizar/ampliar

- Socos alternados com animação, contato real, alcance curto, cadência/dano moderados, áudio e validação no servidor. Continuam disponíveis quando desarmado.
- Loot físico de armas e munições separadas, em posições coerentes. Interação existente para pegar, descartar ou substituir; validar concorrência e calibre contra o modelo efetivo. Mochila limitada, cura, carregador/reserva e munição por calibre. Lançador existente pode atirar sem trava apenas no BR, como regra ficcional balanceada; preservar a trava nos modos atuais. O jogo chama o item atual de Javelin, embora o anexo use Stinger: confirmar o identificador/modelo antes de associar munição.
- Zona circular autoritativa com próximo círculo contido no anterior e centros acessíveis. Dano progressivo fora, círculo atual/próximo, direção segura e contadores no minimapa/HUD. Valores de balanceamento iniciais abaixo, sujeitos a teste.
- Morte mostra responsável, arma/distância ou causa ambiental; transição e espectador FPP/TPP sem controle ou informação indevida. Estatísticas: colocação, sobrevivência, distância, eliminações, danos causado/recebido, tiros/acertos/precisão, arma mais usada, itens e causa da morte; vitória própria e ranking sem contaminar outros modos.
- Ragdoll existente e mochila/contêiner de loot com quantidades preservadas; evitar dezenas de corpos físicos por morte.
- Voz local somente de vivos, apertar/segurar X sugerido (hoje pode conflitar com controles: resolver no desenho). Áudio 3D: claro até 10 m, caindo até 40 m; configurar volume, desativação, silenciar e indicador. Atenuação por obstáculos é opcional na primeira etapa. Avaliar transporte adequado à rede Godot atual; exigência de permissão no navegador só se houver cliente web.

| Zona | Diâmetro | Espera | Fechamento |
|---|---:|---:|---:|
| 1 | 1.500 m | 150 s | 90 s |
| 2 | 1.050 m | 100 s | 75 s |
| 3 | 700 m | 80 s | 65 s |
| 4 | 420 m | 60 s | 55 s |
| 5 | 220 m | 45 s | 45 s |
| 6 | 100 m | 35 s | 35 s |
| 7 | 35 m | 20 s | 30 s |
| Final | 0 m | 10 s | 30 s |

As fases acima somam 925 s (15 min 25 s), embora o anexo estime aproximadamente 17 min. Não tratar a estimativa textual como soma exata; validar ritmo antes de fixar tempos.

## Ordem posterior às correções atuais

1. Auditar seleção de modos/mapas, rede, spawn, inventário, projéteis, ragdoll, minimapa, HUD, resultados, presets e servidor dedicado; reutilizar os sistemas.
2. Estrutura/relevo e horizonte do mapa, depois vilarejos, materiais e vegetação.
3. Navegação e Guerra tradicional no novo cenário.
4. Regras BR, spawn e vencedor; loot, inventário e socos.
5. Zona segura/minimapa; morte, espectador e estatísticas.
6. Voz local, otimização e validação multiplayer.

Validar separadamente mapa, Guerra e BR, incluindo spawn simultâneo, disputa do mesmo loot, calibre incompatível, dano da zona, socos, espectador, entrada tardia, desconexão, vencedor, acessibilidade das zonas e ausência de veículos no BR. Medir nas condições e no hardware já registrados, preservar a versão estável e não publicar sem aprovação.
