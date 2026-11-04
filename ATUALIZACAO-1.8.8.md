# 1.8.8 — primeiro conjunto visual e biblioteca Guerra

## Personagem e armas

- Braços articulados em ombro, cotovelo e pulso. A mão de apoio acompanha o ponto real da arma em vez de apenas esticar um único braço reto. Geometria própria de luvas: palma, polegar e dedos curvados ao redor do guarda-mão e da empunhadura.
- Corrigida a mão de apoio da FAL apontando para baixo. Antebraços e pulsos acompanham a pegada, a inclinação da mira e a recarga. O cálculo é local e usa o mesmo estado de arma replicado; não envia dados adicionais de cada osso.
- Hitbox de antebraço ligado ao segmento móvel. Ragdoll mantém dois antebraços adicionais, com articulações e materiais do uniforme. Personalização, equipes e classes permanecem nos sistemas existentes.
- Cabeça com contorno e detalhes faciais mais discretos. Acabamentos comuns para tecido, polímero, metal, pintura, madeira e concreto.
- FAL com carregador e alavanca de manejo separados. Glock reconstruída com receptor, ferrolho, carregador, guarda-mato, boca do cano e miras tridimensionais. Mantidos atributos, munição, cadência e balística.
- Novas recargas de FAL e Glock: inclinação controlada, retirada do carregador, busca do novo, inserção e manejo final. O progresso usa o temporizador de recarga existente, com 6 s na FAL e 4 s na Glock. As partes móveis e a mão acompanham o mesmo progresso em FPP, TPP e no personagem remoto. Interromper/retomar mantém a regra anterior; a animação não concede munição.

## Guarani e cenário

- Guarani: painéis, fixadores, degraus, conjuntos de faróis protegidos, detalhes de rampa e áreas antiderrapantes. Acabamento diferencia vidro, borracha e metal. Hierarquia da torre, cano, seis rodas, assentos e colisões preservada.
- Nove módulos editáveis com materiais e colisões prontos: pinheiro, árvore queimada, trincheira de 6 m, estrada de 12 m, contêiner, cais, barreira, escada e casa em ruínas. Os pinheiros têm geometria de galhos/folhagem e uma representação distante simplificada.
- Detalhes agrupados por material; a trincheira usa cinco formas de colisão em vez de colidir individualmente com cada tábua e saco.
- As duas bases recebem módulos da biblioteca e o contêiner novo substitui o antigo. O porto leste editado anteriormente não foi sobrescrito.
- Cena de adições `modes/war/scenes/map_additions.tscn`, carregada tanto pelo cliente quanto pelo servidor. A versão sem renderização mantém as mesmas formas e transformações de colisão.

## Edição

Painel Guerra no editor, catálogo com miniaturas, inserção com desfazer/refazer, referência do mapa existente e teste Offline. Galeria em `editor/war/biblioteca.tscn`. A referência estática do mundo é exclusiva do editor e está excluída dos exports. O terreno e as antigas construções geradas por código continuam nesse sistema; esta primeira etapa disponibiliza uma camada de montagem visual sem recriar o jogo.

Guia: `BIBLIOTECA-GUERRA.md`.

## Validação

- `tests/art188_validation.gd`: 188 verificações de pegada em diferentes inclinações, duas equipes, miras de ferro centradas, muzzle real, antebraço/hitbox/ragdoll, paridade de colisão dos prefabs entre visual e servidor e subida dos degraus de 18 cm pela cápsula do personagem, sem pular.
- `tests/art188_reload.gd`: 56 verificações das etapas de recarga, carregador móvel, contato da mão, correspondência FPP/TPP, interrupção/retomada e transferência correta de munição.
- `tests/art188_network.gd`: servidor DTLS e dois clientes, incluindo recarga, drone, morte, APC e míssil TV. O observador mede o movimento real dos carregadores de FAL e Glock a partir da recarga replicada. 43 verificações passaram.
- Teste no editor: catálogo, abertura do mapa, contexto sem proprietário, inserção, serialização sem duplicar o mundo e desfazer passaram nas seis verificações.
- Capturas nativas de frente/costas, pegadas, FPP, miras, objetos e etapas de recarga em `work/art188-*.png`.

## Desempenho medido

Teste isolado de 12 soldados animados, recargas das duas armas e nove módulos, renderizado em um SubViewport de **1920 × 1080**, na **GTX 1650**, com limite de 120 FPS: média **120,06 FPS**, 1% low **112,92 FPS**, p95 de frame **8,51 ms**, pico **9,39 ms**, 619 chamadas de desenho e aproximadamente 197 mil primitivas.

Esse teste mede o conjunto visual em uma arena, não uma partida completa de 12 jogadores com todo o mapa, veículos, rede e explosões. Não implica que o modo Guerra inteiro mantenha esses números. Os JSONs registram o escopo e os resultados brutos.

## Referências

Modelagem original, usando referências dos fabricantes: [Guarani — IDV](https://www.idvgroup.com/products/amphibious-armoured-vehicles/guarani/), [G17 — Glock](https://gen5.glock.us/g17/). Organização da biblioteca e histórico de edição seguem os recursos nativos de [cenas do Godot](https://docs.godotengine.org/en/stable/getting_started/step_by_step/nodes_and_scenes.html) e [EditorUndoRedoManager](https://docs.godotengine.org/en/stable/classes/class_editorundoredomanager.html).

Compatibilidade: protocolo Guerra 20 e implantação de infantaria 7, para impedir uma partida misturando versões com modelos/hitboxes diferentes.

## Publicação

Publicado no Ubuntu como **1.8.8 build 59**, promovendo cliente, servidores e página de novidades no mesmo processo. Pacote cifrado validado, com bloqueio de execução de scripts/pacotes externos. As cenas e ferramentas exclusivas do editor ficam fora dos exports.
