# Revisão atual — paisagem e propriedades

> **Referência nova (04/11/2026):** imagem enviada pelo usuário de trilha montanhosa e povoado no vale, identificada no story como Santa Catarina / Sinai, Egito. Inspiração para transição de encosta e vale no Afegão, sem reintroduzir rochedos grandes nem afetar o BR. Plano v14 em [AFEGANISTAO-REFERENCIA-SINAI-TRILHAS-20261104.md](AFEGANISTAO-REFERENCIA-SINAI-TRILHAS-20261104.md). **Somente planejamento; não implementado no mapa.**

Atualização local de 28/10/2026. A pedido do usuário, as séries de benchmark foram interrompidas. Não há nova certificação de FPS. Nada foi publicado.

## Direção aplicada

- Foram removidos do mapa os rochedos, escarpas instanciadas e conjuntos de pedras nas encostas, incluindo o espalhamento antigo de rochas grandes. A etapa de detalhamento rochoso das encostas foi cancelada pelo usuário. Os arquivos reutilizáveis já criados permanecem na biblioteca; não são instanciados pelo gerador do mapa.
- A ocupação atual tem 83 construções, 22 campos maiores, 53 hortas/pomares ligados às casas, dez pequenos bosques e dez recintos rurais em ruínas. Os jardins seguem o terreno existente, têm divisas baixas e mantêm o lado de acesso aberto. O terreno só é nivelado onde a implantação da construção exige.
- O mapa tem 1.354 árvores e 908 arbustos, distribuídos principalmente nas propriedades, canais, margens, ruas e bosques. Os números representam o mapa completo, não objetos desenhados em cada quadro. O capim de margem é uma peça nova com lâminas em geometria, sem colisão ou script, usada em manchas de alcance curto. Não é a atualização de grama volumosa anteriormente cancelada.
- Madeira, caixas, barris, ferramentas, muros quebrados e sulcos compõem conjuntos rurais contextualizados. Permanecem peças reutilizáveis no catálogo regional, com materiais, colisão apropriada e LOD. Detalhes pequenos são agrupados em MultiMesh e não recebem sombra.
- O vale recebeu ondulações e depressões. Os cortes e aterros laterais das vias agora têm largura proporcional à diferença de altura, em vez de devolver o terreno abruptamente à cota natural a poucos metros da rua. A superfície visual das estradas acompanha os triângulos reais do terreno, com bordas irregulares e marcas de pneus.

## Conferência desta revisão

O projeto foi importado e o mapa completo foi aberto no renderizador Compatibility. Foram preparadas novamente as alturas compartilhadas e a cor distante do chão. A captura `work/afghan-no-hillside-rocks-view0.png` mostra o conjunto; `view1.png` mostra a rua; `view2.png` mostra um quintal com pomar. As câmeras e a composição estão em `work/afghan-no-hillside-rocks-cameras.json`.

Essa conferência é visual e de carregamento. As verificações e benchmarks descritos no histórico abaixo pertencem a versões anteriores da composição e não certificam a geometria atual. A prévia que usa o contexto de teste do personagem ainda registra pequenos recursos de física retidos ao encerrar o processo; não é apresentada como uma partida integral validada. O desempenho desta composição fica para avaliação na gameplay, conforme solicitado pelo usuário.

---

# Histórico anterior — não representa a composição atual
# Deserto Afegão — composição do mapa

Revisão local de 28/10/2026. Nada foi publicado. O mapa da Ucrânia e a cena de adições do usuário foram preservados.

## O que mudou

O planejamento reserva estradas, riacho, canais e parcelas agrícolas antes de aceitar os lotes. As propriedades recebem acessos, quintais, muros baixos, árvores e pequenos adereços. São 26 parcelas irrigadas e 83 construções de cinco tipos. Um lote foi rejeitado porque não permitia uma implantação segura; não se força uma casa na última posição tentada.

O vale ganhou ondulações, leito seco e transições mais largas para as encostas. As montanhas passaram de cones estreitos a cadeias com ombros mais largos. Duas trilhas graduadas sobem pelos lados oeste e leste. As casas são aceitas considerando a diferença de altura em relação à via próxima; plataformas e entradas têm uma transição própria, em vez de deixar uma porta acima de um corte vertical.

Os campos têm contornos com seis vértices, margens suaves, acessos, aberturas nos muros e valas de alimentação. O cultivo e o solo úmido fazem parte do material do terreno, sem planos verdes sobrepostos. A cor do cultivo conserva detalhe e variação. Há pomares nos campos em pousio e manchas verdes nas margens, canais e quintais.

A vegetação concentra-se em propriedades, ruas, divisas, pomares e pequenos bosques no corredor do riacho. A composição atual tem 1.115 árvores e 496 arbustos no mapa inteiro; esses números não são a quantidade desenhada por quadro. A vegetação usa MultiMesh por célula, com modelos próximos e silhuetas simplificadas distantes. Os cultivos e pequenos detalhes têm alcance curto. A grama volumosa cancelada pelo usuário continua fora desta atualização.

Os choupos, salgueiros e arbustos são modelos próprios, entregues também na biblioteca regional. A versão otimizada conserva todos os vértices e colisores da composição visual, reunindo a cor de troncos e folhas num material compartilhado por categoria. Os modelos anteriores permanecem como arquivos, preservando referências existentes.

As faixas escuras do solo incluíam auto-sombreamento, não apenas repetição de textura. A superfície visível recebe sombras; os terrenos muito suaves deixam de projetar sombra sobre si mesmos. Encostas mais inclinadas e objetos continuam projetando sombras. Não se afirma que toda irregularidade visual distante tenha sido eliminada.

## Evidências de jogabilidade

- `work/afghan-interiors-validation.json`: 93 percursos físicos passaram, sendo dez testes de peças em duas escalas e os 83 interiores reais do mapa. Foram verificados entrada, alcance e linha de visão para o loot interno. Execução com `--all-houses`, cápsula e GameStepMotion reais, sem correção de posição.
- `work/afghan-mountain-walk.json`: duas trilhas completas passaram, com 146 e 144 pontos percorridos. O trajeto oeste ganhou 96,65 m de altitude; o leste, 98,03 m. Isso testa caminhada, não blindados.
- `work/afghan-revision-validation.json`: 5.615 verificações passaram. Rede viária com 102 pontos de spawn conectados; 4.080 amostras de inclinação, máximo medido de 34,59°. Das 500 consultas de terreno, 499 atingiram terreno em vez de estruturas; maior erro entre altura e colisão foi 0,000176 m. A conectividade grosseira de células é diagnóstico, não uma navmesh pronta.
- `work/afghan-territory-plan.json`: 137 verificações passaram. A autoridade e o cliente planejam as mesmas 2.754 peças. Esse total inclui elementos decorativos e não representa o número de corpos físicos nem de draw calls. Os muros são agrupados em corpos estáticos por célula.
- `work/afghan-prepared-validation.json`: 713 verificações passaram. As alturas preparadas coincidem com o gerador, com erro máximo de 0,000013 m; 40 muros mantêm seus recursos de colisão e transformações após o agrupamento.
- `work/afghan-foliage-validation.json`: 18.330 verificações passaram. Seis malhas conservam os vértices originais e as propriedades de colisão; maior diferença de cor por quantização foi 0,002615. Os níveis visuais de detalhe foram regenerados.
- `work/br-loot-network.json`: 12 verificações passaram com servidor e dois clientes reais por ENet/DTLS. Disputa de loot dentro da casa, um único proprietário, remoção nos dois clientes, preservação do carregador e rejeição de coleta através de parede, longe, morto ou com vida/rodada antiga. A preparação do teste substitui login e deslocamento; não é uma partida completa.

## Comparação visual e desempenho

As capturas `work/afghan-composition-20261028-204132-a-warm-view0.png` e `b-warm-view0.png`, assim como as vistas 1 e 2, usam transformações de câmera idênticas em 1920 × 1080. `work/afghan-chora-optimized-view0.png`, `view1.png` e `view2.png` mostram a conversão para um material por malha.

Referência A: composição anterior, 28 campos e 84 construções. Revisão B: composição atual, 26 campos e 83 construções, com mais contexto e vegetação. Mesma iluminação, câmera, resolução, semente 712907, Compatibility, GTX 1650 e 18 personagens animados. O ensaio isola a renderização: física dos personagens e IA desativadas, sem combate ou rede. Não representa o FPS de uma partida com 18 bots.

A primeira série, `work/afghan-composition-20261028-204300-*`, usou A1/B1/A2/B2/A3/B3/A4. A mediana passou de 122,29 para 113,52 FPS, aproximadamente -7,2%; o 1% low passou de 30,03 para 25,46 FPS. O desenho passou de 1.439 para aproximadamente 1.659 chamadas por quadro. Essa versão não atende à meta de até 5% de custo sem piora do 1% low.

Foi feita uma única alteração visual em seguida: reunir os materiais de cor da vegetação. A segunda série alternada está em avaliação. As temperaturas e clocks estão nos arquivos `*-hardware.jsonl`. A temperatura da CPU não está disponível neste computador; seu clock é uma estimativa do Windows. As leituras de memória não equivalem, sozinhas, ao consumo total da GPU por todos os programas.

## Edição e referências

As adições do usuário permanecem em `modes/battle_royale/scenes/map_additions.tscn`. Os objetos ficam na biblioteca regional, acessível por `modes/battle_royale/library/catalog_v2.tscn`. As cores de grandes regiões podem ser pintadas em `modes/battle_royale/map/afghan_biomes.png`. O gerador comum não sobrescreve essa imagem nem as cenas do usuário.

As imagens fornecidas pelo usuário e as capturas de Chora publicadas pelo próprio Squad orientaram a relação entre agricultura, propriedades e vegetação: [referência de 2015](https://media.joinsquad.com/2015/Dec/EAFollowUp/chora_1.jpg) e [referência de 2016](https://media.joinsquad.com/2016/Oct/SeptRecap/relight_3.jpg). A imagem específica do Fandom não abriu pelo acesso automático. Nenhum objeto, textura ou traçado de Squad foi incorporado ao jogo.

## Limites da entrega

O resultado é uma revisão local do cenário. A navegação completa em navmesh, percursos com todos os veículos e uma partida Battle Royale completa ainda não estão certificados. A integração como variante do Guerra e a voz por proximidade continuam tarefas separadas. Não há autorização de publicação.

