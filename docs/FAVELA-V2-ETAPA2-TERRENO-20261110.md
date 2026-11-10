# Favela V2 — Etapa 2: terreno físico e fechamento do morro esquerdo

Data: 10/11/2026. Esta etapa parte da topologia aprovada em `ia/favela-reboot-v2-topology-phase1-20261110`, **não** altera a Favela pública atual.

## Escopo implementado

- `modes/war/scripts/favela_v2_terrain.gd`: gera um campo de altura determinístico de **850 × 600 m**, em grade de 5 m, separada em **54 células de até 100 × 100 m**. Nenhum objeto tem script de atualização por frame.
- `modes/war/library/favela_v2_terrain_chunk.tscn`: peça modular do terreno. A mesma ArrayMesh dá origem à colisão `ConcavePolygonShape3D` tanto no servidor dedicado quanto no cliente; o servidor omite apenas os visuais.
- O terreno usa a topologia explícita da V2: 29 vias e corredores têm o solo suavizado seguindo alturas acordadas entre os 25 nós. Não há `PRIMARY` nem "retona" reutilizada do mapa antigo.
- Morro esquerdo com curvas de nível, elevações progressivas, cristas irregulares e margem de relevo orgânica para esconder o limite retangular técnico.
- Duas sequências de cristas formam o contorno do setor oeste, com **uma única abertura** voltada ao `central_hub` (miolo). Um conjunto de 16 faces rochosas sólidas e reutilizáveis fecha os trechos em que somente o relevo poderia ser escalado pelo `GameStepMotion`.
- `modes/war/library/favela_v2_rock_barrier.tscn`: prefab da face rochosa com colisão BoxShape3D por segmento; a geometria visual usa as texturas de rocha existentes do jogo. **Sem paredes invisíveis**.
- `modes/war/scripts/prefab_factory.gd`: ambos os novos módulos registrados no catálogo do editor. A cena completa tem **70 corpos/colisões setorizados**: 54 terrenos + 16 rochas.
- Preview das ruas por uma única malha visual (`TracadoV2VisualSemColisao`), que **não cria piso falso nem colisão extra**. As bordas de morro laranjas da referência continuam sendo relevo, nunca caminhos.
- Esta versão NÃO cria moradias definitivas, objetivos do modo Guerra, navmesh de bots ou novos spawns. V2 ainda não está selecionável no menu.

## QA e desempenho inicial

Testes em Godot 4.7.2, desktop com GTX 1650:
- `tests/favela_v2_terrain_qa.gd`: altura e colisão sincronizadas nos 25 nós; 20.691 amostras de terreno, 40.800 triângulos físicos; piso reconhecido pelo motor; conferência de larguras, gradientes e módulos reutilizáveis. Teste também garante que a base superior continue acessível pelo traçado principal.
- Grade máxima amostrada no eixo das vias comuns: cerca de **0,258** (25,8%); nas áreas previstas para escadas: **0,221**. Estas são inclinações do solo do blockout, não prova de que a futura escadaria modular já funcione.
- O paredão norte tem diferença de altura local de aproximadamente **12,8 m**, mas apenas altura NÃO bastou para bloquear o jogador: o `GameStepMotion` superava o declive na primeira versão. As **16 faces físicas foram adicionadas** após esse achado.
- `tests/favela_v2_barrier_walk_qa.gd`: caminhadas usando `CharacterBody3D` e **o verdadeiro `GameStepMotion`**. Um teste atravessa a passagem pelo miolo; três tentativas nos limites norte, sul e leste do morro são detidas. Esses quatro cenários são amostras, não garantia de cobertura total de todos os trechos da borda.
- Construção física inicial em headless: aproximadamente **0,8–1,0 s** no equipamento testado. Não confundir este tempo de geração com FPS/frametime de combate.
- `tests/favela_v2_terrain_visual_qa.gd`: três capturas em **Forward+ GTX 1650**, contendo visão aérea, morro esquerdo e a passagem central. Prévia gráfica intencionalmente simples, **sem casas finais**.

## Arte e limitações

A cor de solo atual é terra com matizes cinza/ocre e prévia clara do traçado. Os paredões são rostos rochosos retos e perceptíveis: **geometria de bloqueio provisória**, NÃO estética final. Próxima fase deverá suavizar a transição, compor rochas e vegetação, preservar a face física e evitar uma "muralha" visual homogênea.

O mapa ainda usa uma área técnica retangular de 850 × 600 m; morros de borda e percurso sinuoso definem a área utilizável. Faltam fronteira orgânica final, casas, escadões, espaços sociais, navegação automatizada, multiplayer real e FPS P95/P99. Não publicar nem mesclar a V2 na `main` somente com este QA.

## Próxima etapa (Fase 3)

Construir **somente o morro esquerdo** como primeiro bairro jogável: casas em patamares, vielas estreitas, três grupos de escadões modulares com piso físico, pátio, mirante e cobertura. Testar duas direções das escadas com jogador e bot, evitar enroscos em lajes e confirmar em multiplayer que a passagem pelo miolo é única.

Comandos:
- `Godot --headless --path . --script res://tests/favela_v2_terrain_qa.gd`
- `Godot --headless --path . --script res://tests/favela_v2_barrier_walk_qa.gd`
- `Godot --path . --script res://tests/favela_v2_terrain_visual_qa.gd`

A branch contém as capturas em `docs/images/favela-v2-terreno-*.png`.
