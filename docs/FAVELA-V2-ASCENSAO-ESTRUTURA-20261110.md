# Favela V2 — estrutura 3D do mapa subindo morro (10/11/2026)

## Interpretação atualizada do esboço do usuário
A favela é uma **subida contínua** de baixo para cima, com a **Polícia (Equipe 1)** no vale (sul) e **Traficantes (Equipe 2)** no cume (norte). A rua principal serpenteia em S, passando por núcleos de casas e áreas de combate. O setor de casas do morro esquerdo só se liga ao **miolo central** pelo link `l00`: **não existe saída daquele bairro para a base superior**.

Este trabalho é uma **estrutura real em Godot 4.7.2**, com terreno físico, vias e modelos originais reutilizados. Não é uma ilustração gerada por IA.

## O que foi executado

**Branch:** `ia/favela-v2-ascensao-3d-20261110` baseada no commit V2 já versionado `4bdf6ae`. As alterações de outra worktree ainda não commitadas foram preservadas no lugar, sem sobrescrita, e não entraram no build.

1. **Mapa e circulação:** `modes/war/scripts/favela_v2_topology.gd` comprime a área para **640 × 670 m**, reorienta 25 nós / 29 links, preserva os identificadores e categorias do mapa original V2 e mantém uma rota principal de **725,42 m** entre as duas bases (versus 552,12 m em linha reta). O bairro oeste tem **um único portão** para o centro. A geometria de todos os traços foi transformada de forma coerente, não só os locais das bases. As marcações A/B/C/D/E são setores visuais propostos, não objetivos de captura já registrados na autoridade.
2. **Terreno em aclive:** `modes/war/scripts/favela_v2_terrain.gd` usa uma elevação **contínua** ao longo do eixo sul–norte, uma crista lateral oeste alongada, sulcos de drenagem discretos e pads locais integrados para bases/campinho. Removido o relevo em formato de bacia, sem contornos circulares artificiais e sem elevação das bordas para simular um cercado. Desnível planejado das bases: **88 m** (10 m a 98 m). Na seção natural de controle, o solo sobe progressivamente entre os 7 pontos amostrados.
3. **Desempenho físico:** grade de 5 m, **49 células de terreno**, **34.304 triângulos do solo**, mesma `ArrayMesh` para física no cliente e no servidor. Apenas **cinco afloramentos rochosos**, em dois conjuntos descontínuos, substituem o anel de 16 blocos altos. As rochas usam geometria irregular e colisão baseada na própria malha. **Esses cinco pontos não provam que jogadores não possam flanquear por toda a encosta** — o fechamento completo da circulação física será homologado em etapa posterior.
4. **Texturas e prefabs antigos:** reutilizados os materiais `sand-albedo/normal/roughness`, `concrete-albedo/normal` e `rock-albedo/normal`; os módulos `favela_casa_laje.tscn`, os oito acessórios originais das fachadas e a cena original `favela_campo_baile.tscn` para representar o campinho. Não substituímos nenhuma cena original da Favela. A estrutura contém **160 casas ao longo das vias** e **37 no bairro oeste**, somando **197 residências**; além de **390 degraus** do oeste, com colisor agrupado por lance. O cliente recebeu 608 detalhes visuais de fachadas na via principal e 140 no oeste; o servidor não gera esses detalhes decorativos.
5. **Prévia real para feedback:** `tests/favela_v2_ascension_visual_qa.gd` inicia o gerador `favela_v2_ascension_blockout.gd` no renderer Forward+ da **GTX 1650**, acrescenta etiquetas temporárias para as duas bases e setores A–E e tira quatro capturas. Essas etiquetas são **apenas da prévia de QA**.

## Validações

- `tests/favela_v2_topology_qa.gd`: **238/238 PASS**, incluindo zero cruzamentos geométricos sem entroncamento e uma única ligação do bairro oeste.
- `tests/favela_v2_ascension_qa.gd`: **31/31 PASS**, 49 células, 34.304 triângulos, 25 pontos do grafo com piso físico, rota curva funcional e recursos reutilizados.
- `tests/favela_v2_ascension_visual_qa.gd`: **PASS 4/4**, capturas PNG reais no Forward+ / NVIDIA GTX 1650 em `docs/images/favela-v2-ascensao-*.png`.
- `tests/favela_v2_ascension_walk_qa.gd`: **PASS 18/18** caminhadas com `CharacterBody3D` e `GameStepMotion` (nove trechos, subida/descida), **zero bloqueios e zero ticks de recuo**, pico de variação vertical por quadro de **0,039 m** no segmento amostrado. Não testa bots nem a travessia contínua do mapa inteiro.
- Construção física básica no modo headless: aproximadamente **0,75 segundo** durante o QA de estrutura (não é FPS nem benchmark de jogo).

A nova worktree recebeu exclusivamente um **cache local de importação Godot** (gerado na worktree V2 anterior) porque a primeira importação do editor falhou. Esse cache fica em `.godot/imported` e **não é versionado no Git**; nenhuma alteração de código foi copiada de outras worktrees.

## Limites e próximos trabalhos

A estrutura é **um blockout 3D**, sem iluminação final, integração no modo Guerra publicado, navmesh de bots, spawns ao vivo, sessão multiplayer ou FPS P95/P99 medidos em combate. A geometria ainda mostra a borda técnica do terreno de certos ângulos; as casas ainda devem ganhar densidade e melhor composição por platôs. Não incorporar na `main` ou publicar build com este protótipo.

O propósito desta revisão é **o responsável pelo jogo dar feedback da forma real do morro e das ruas**; depois aperfeiçoaremos a direção do S, escadões completos, densidade e áreas de combate. A estrutura original da Favela pública permanece intacta.

## Imagens reais

- `docs/images/favela-v2-ascensao-geral.png` — visão aérea inclinada do percurso inteiro
- `docs/images/favela-v2-ascensao-vale.png` — aproximação a partir da base da Polícia
- `docs/images/favela-v2-ascensao-meio.png` — visão do miolo e da subida
- `docs/images/favela-v2-ascensao-topo.png` — visão da base dos traficantes para o vale
