# Biblioteca de montagem do Guerra

Abra o projeto com `ABRIR-EDITOR.bat`. O painel **Guerra** aparece à direita.

- **Mapa:** abre `modes/war/scenes/map_additions.tscn`, com o mundo existente como referência visual. Escolha um grupo na árvore, selecione um objeto no catálogo e clique em **Inserir**, ou dê dois cliques no item. Também é possível arrastar as cenas de `modes/war/library/` para a vista 3D.
- **Encaixar:** alinha a peça selecionada a um conector compatível próximo. A inserção pelo catálogo também procura um encaixe. Desfazer/refazer mantém o histórico normal do editor. A escala da peça selecionada é preservada.
- **Referências:** abre `editor/war/biblioteca.tscn`, com os dois soldados, a FAL, a Glock, o Guarani e os módulos. F6 executa a galeria: 1–0 mudam o objeto, P alterna animações, botão direito gira a câmera e roda aproxima/afasta.
- **Testar Guerra Offline:** executa o modo existente com as alterações salvas.

Mover: W. Girar: E. Escalar: R. Duplicar: Ctrl+D. Enquadrar seleção: F. Salvar: Ctrl+S. O catálogo usa o histórico normal de desfazer/refazer do Godot.

## Objetos prontos

| Cena | Origem e dimensão | Colisão |
|---|---|---|
| `pinheiro.tscn` | chão; aproximadamente 8,5 m de altura | tronco; LOD visual a 110 m |
| `arvore_queimada.tscn` | chão; tronco e galhos quebrados | tronco; LOD visual a 110 m |
| `trincheira_6m.tscn` | piso da passagem; comprimento de 6 m | cinco formas para piso, paredes e sacos |
| `estrada_12m.tscn` | superfície do asfalto; comprimento de 12 m | pista e acostamentos |
| `container_20ft.tscn` | base; 2,44 × 6,06 m | paredes, portas, piso e teto |
| `cais_8m.tscn` | superfície do cais; módulo de 8 × 8 m | plataforma, estacas e cabeços |
| `barreira_concreto.tscn` | chão; 3 m de comprimento | um volume convexo inclinado |
| `escada_4m.tscn` | pé da escada; 4 m de comprimento | degraus de 18 cm e corrimãos |
| `casa_ruina.tscn` | fundação; 9 × 7 m | paredes com aberturas, estrutura e escombros |
| `estrada_curva_90.tscn` | entrada da curva; raio central de 12 m, pista de 7 m | 16 volumes convexos seguindo a curva |
| `estrada_cruzamento.tscn` | centro; 12 × 12 m | dois volumes sob as faixas transitáveis |
| `estrada_entroncamento.tscn` | centro; T de 12 × 12 m | dois volumes sob as faixas transitáveis |
| `estrada_rampa_12m.tscn` | centro em X/Z; Y no nível da ponta inferior; comprimento de 12 m, subida de 1,5 m | volume convexo inclinado |
| `cais_curva_90.tscn` | entrada da curva; raio central de 12 m, largura de 8 m | curva e estacas |
| `cais_rampa_8m.tscn` | centro em X/Z; Y no nível da ponta inferior; comprimento de 8 m, subida de 1,2 m | rampa, montantes e corrimãos |
| `trincheira_escavavel_6m.tscn` | terreno original; comprimento de 6 m | terreno escavado, revestimento, piso e parapeito |
| `fachada_atingida.tscn` | fundação; três pavimentos e fachada aberta | lajes, paredes e sacadas, com aberturas reais |
| `laje_desabada.tscn` | chão; placas quebradas e vergalhões | placas inclinadas |
| `carro_carbonizado.tscn` | chão; carroceria aberta e interior queimado | carroceria e rodas |
| `entulho_tijolos.tscn` | chão; monte de tijolos e concreto | volume convexo acompanhando o monte |
| `carga_portuaria.tscn` | chão; palete, tambores e carga | palete e volumes da carga |
| `defensa_portuaria.tscn` | piso do cais; cabeços, chapa e corda | cabeços e chapa |
| `canaleta_danificada.tscn` | chão; meio-fio quebrado e grelha | laterais de 30 cm |
| `cratera_impacto.tscn` | terreno original; depressão circular e detritos na borda | escavação na malha física do terreno |

Mova a raiz de cada objeto: aparência, colisão e metadados de superfície acompanham juntos. As subdivisões nomeadas, como portas do contêiner, permanecem editáveis. Os detalhes rígidos estão agrupados por material para reduzir chamadas de desenho.

Use **Trincheira escavável · 6 m** para abrir o chão. Posicione sua raiz na altura do terreno original e ajuste **Depth** no Inspetor, entre 0,8 e 2,8 m. O revestimento acompanha a profundidade; as extremidades fazem a transição de entrada e saída. Desative **Excavate** para usar somente o revestimento. O antigo `trincheira_6m.tscn` continua sendo apenas revestimento, com origem no piso.

No painel Guerra, mover, girar, alterar a profundidade ou remover uma trincheira atualiza a prévia do terreno. Salve e execute **Testar Guerra Offline** para validar o resultado jogável. O chão é construído com a mesma geometria e colisão no cliente e no servidor; os setores afetados recebem subdivisões de 0,5 m, preservando as malhas menos densas no restante do mapa. Isso é edição de mapa, não escavação durante a partida.

Estradas e fundações ajustam o terreno sob a peça; cais rebaixam o terreno que atravessaria a plataforma. Curvas, cruzamentos e rampas possuem conectores nomeados em `Encaixes`. Use peças da mesma largura/perfil; superfícies de rampas de cais também aceitam ligação com estradas de largura compatível. Os módulos são rígidos: confira as junções em encostas e evite escalar somente um eixo em curvas que precisam manter um raio regular.

## O que cada arquivo controla

- `modes/war/scenes/map_additions.tscn`: objetos acrescentados ao mapa; é carregado no Offline e no servidor.
- `modes/war/scenes/east_port.tscn`: terminal leste existente; preservado nesta atualização.
- `modes/war/scenes/infraestrutura_190.tscn`: camada com 86 instâncias nas duas bases, nos dois cais e no vilarejo oeste; está dentro de `map_additions.tscn`.
- `modes/war/scenes/detalhamento_190.tscn`: 200 objetos de destruição e infraestrutura nos arredores dos dois portos e em quatro núcleos urbanos. As cenas permanecem editáveis; o agrupamento de renderização acontece somente ao carregar uma partida.
- `modes/war/library/`: objetos reutilizáveis, cenas normais do Godot.
- `editor/war/referencia_mundo.scn`: referência estática do cenário gerado. Não entra no jogo exportado e não é salva junto das adições.
- `modes/war/scripts/world.gd` e `terrain.gd`: continuam responsáveis pelo terreno e pelas estruturas geradas anteriormente. Esta etapa não converteu toda a cidade em objetos individuais editáveis.

Os arquivos `soldado_equipe_1.tscn`, `soldado_equipe_2.tscn`, `fal_referencia.tscn`, `glock_referencia.tscn` e `guarani_referencia.tscn` são modelos de inspeção na galeria. Personagens e veículos jogáveis continuam sendo criados pelos sistemas de gameplay, com seus assentos, animações e autoridade. O novo trecho substitui oito casas e trechos de ruas geradas anteriormente, sem duplicá-los. Árvores geradas respeitam as novas fundações e passagens.

Não execute o gerador com `--replace-library`, `--replace-new`, `--replace-details` ou `--replace-generated` sobre cenas que você editou: são opções de manutenção. A execução normal preserva os 24 objetos e as camadas existentes. Depois de editar mapas, uma nova exportação/publicação é necessária para os outros jogadores receberem a mesma geometria.

As peças de destruição têm representação simplificada à distância; pequenos detritos e vergalhões só aparecem perto do jogador. Colisões permanecem iguais. Na partida, objetos repetidos usam MultiMesh e as peças únicas são agrupadas por setor/material, preservando o mapa editável no Godot.

Novos objetos de cenário seguem essa organização por diretriz permanente em `AGENTS.md`: cena reutilizável, materiais, origem/escala, colisões, metadados e configuração de desempenho quando aplicável, acrescentando também a instância no mapa quando solicitada.

## Animações de referência (1.8.9)

Na galeria em execução, P alterna mira vertical, inclinação lateral e recarga. As figuras usam movimentos amostrados do personagem jogável. A animação da galeria serve para inspeção; os personagens da partida continuam no sistema de poses e sincronização do jogo.

