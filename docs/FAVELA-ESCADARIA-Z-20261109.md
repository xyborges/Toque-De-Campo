# Favela — escadaria contínua no caminho em Z (09/11/2026)

## Escopo e seleção
O trecho escolhido é a primeira mini-rua em zigue-zague no oeste da Favela, que passa aproximadamente por (-300, 111). Segue os seis vértices originais do `MINI_STREETS[0]`, de (-320, 165) até (-256, -15), total de 212,01 m. É uma hipótese explícita da identificação visual do caminho em Z; não foram alteradas as demais cinco mini-ruas, cruzamentos, avenida principal ou posições das casas.

## Arte e geometria
- A faixa deste corredor deixa de ser pintada como asfalto na máscara da `WarFavelaMap.road_envelopes()` e ganha o acabamento do beco de concreto.
- Escadaria no eixo da via, com 276 degraus físicos de 2,30 x 0,24 x 0,68 m, espaçamento longitudinal de cerca de 0,72 m.
- Seis patamares em concreto nos vértices, inclusive nas curvas do Z, rebaixados para evitar criar uma borda que bloqueie a mini-rua.
- Corrimãos com 132 postes visuais, fora da faixa útil de caminhada, sem colisores; degraus contêm friso de borda e pequenos reparos irregulares no concreto.
- Materiais dos degraus reutilizam as texturas existentes de concreto: albedo, normal e rugosidade. Um único prefab reutilizável `modes/war/library/favela_z_stair_tread.tscn` registrado em `favela_architecture.gd` e no catálogo de prefabs. A arquitetura achata suas instâncias em lotes/sectores como os demais módulos.
- Terreno físico original mantido; escadas no servidor e no cliente seguem a mesma fonte. Não altera `GameStepMotion`, a IA nem a forma como o servidor gera rotas. Lances laterais genéricos não duplicam a nova escadaria.
- Manifesto preparado do mapa atualizado como candidato, versão 30, `status: testing`, com os novos módulos e texturas incluídos no hash.

## Homologação técnica
Godot 4.7.2, DESKTOP-JJ7U3G3:
- `tests/favela_z_stairway_qa.gd`: PASS, 565 verificações; 276 degraus, 6 patamares, desnível máximo entre peças sucessivas de 0,14462 m, 212,01 m.
- `tests/favela_z_stair_walk_qa.gd`: PASS depois dos ajustes; 56 pontos de contato, zero amostras sem piso, zero sobreposição de cápsula, seis caminhadas de CharacterBody3D usando `GameStepMotion` (subida e descida), zero recuos ou bloqueios.
- `tests/favela_operation_smoke.gd -- --favela-visuals`: PASS após ajustar patamar e regenerar o manifesto. Testa mapa completo, setor de circulação e ausência de obstruções nas mini-ruas; `visual_instances=105601`, `collision_shapes=11885`, `build_ms=8575` em headless (não são FPS).
- Captura real em Forward+ usando GTX 1650 e `tests/favela_z_stair_visual_qa.gd`. Imagens em `work/favela-z-stair-view-{0,1,2}.png`, não versionadas.
- `python tools/prepare_favela_manifest.py`: MATCH.

## Limites
Sem homologação de multiplayer humano, navegação de bots por todo o percurso, comparação FPS/P99 com a versão anterior ou publicação de build. Não foi alterada a `main`; este commit é candidato. Se o caminho em Z mencionado no jogo for outro, identificar por screenshot ou coordenada para reposicionar sem alterar outras vias.
