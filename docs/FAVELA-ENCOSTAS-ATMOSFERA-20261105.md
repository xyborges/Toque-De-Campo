# Favela — encostas, mata e atmosfera (05/11/2026)

## Contexto / controle de versões

- Origem: `ia/favela-final-candidate`, commit-base `10a497d`.
- Desenvolvimento isolado: `ia/favela-encostas-mata`.
- As worktrees `favela-guerra` e `favela-detail-max` continuam reservadas
  por outras IAs. Não foram alteradas, canceladas ou descartadas.
- A `main` possui uma alteração alheia em `distribution/release-history.json`
  e não foi tocada. Nenhuma atualização foi publicada.

## Problema visual resolvido nesta etapa

A versão-base já havia substituído o pavimento cinza fora das vias por
terra/saibro, mas as encostas e o limite mata-favela ainda apareciam nus,
lisos e com árvores muito espaçadas. Também faltava atmosfera: o céu tinha
apenas uma graduação de cor, sem nuvens, e a bruma era uniforme.

### Intervenção sem alteração da física do terreno

O módulo `favela_hillside.gd` complementa a vegetação original, que foi
preservada. Distribui por seed reprodutível quatro tipos:
- 1.850 árvores de copa/cartunesco (mesmos meshes compartilhados e LOD
  das árvores já existentes);
- 4.700 arbustos/massas de sub-bosque;
- 13.214 tufos de capim baixo/alto, sem colisão;
- 480 afloramentos rochosos visuais, sem colisão.

A distribuição privilegia três faixas: mata de fundo, flancos do mapa
e transição urbana. Arbusto/capim também entram em recortes não edificados,
sem invadir as casas. A seleção usa células espaciais de 32 m, respeita
footprints residenciais, limites do mapa e reservas próximas a
ruas, bases e pontos domináveis. Pequenos detalhes não geram corpos
físicos; somente 78 troncos estruturais adicionais recebem uma cápsula
cilíndrica simples.

O solo nas encostas recebeu *veios de erosão e sedimento* calculados no
shader sobre a inclinação da malha. O efeito atua fora da máscara da rua.
Não desloca vértices, fundações, muros ou rotas e, portanto, mantém
o mesmo terreno físico que os jogadores/bots percorrem.

### Nuvens e condensação

`favela_atmosphere.gd` substitui a antiga atmosfera por:
- céu procedural com manchas de nuvens brancas e sombra suave,
  intercaladas com azul; shader *estático*, sem TIME/POSITION,
  evitando recálculo contínuo do cubemap;
- 14 faixas translúcidas de névoa estática na mata traseira;
- névoa de distância sutil (densidade 0,00037),
  sem prejudicar combate a curta e média distância;
- luz do sol e preenchimento ambiente levemente quentes;
- sem volumes pesados, partículas por folha nem colisão das névoas.

Há três cenas reutilizáveis `favela_arbusto_encosta.tscn`,
`favela_rocha_encosta.tscn` e `favela_nevoa_encosta.tscn`, todas
registradas em `prefab_factory.gd`. O catálogo do editor continua
capaz de instanciar/mover cada modelo independentemente.

## Evidências e orçamento de execução

`favela_hillside_atmosphere_qa.gd` passou 40.513 verificações sem falhas.
Conferiu limites, determinismo do gerador, distâncias de segurança,
biblioteca e céu/bruma estáticos.

Smoke visual completo Godot 4.7.2 passou, preservando:
- 4.199 casas, 49 rotas, 225 tiles, oito veículos;
- 1.005 módulos urbanos de borda, 264 posições descartadas;
- ~99.430 instâncias visuais na variante final.

Teste offline com 28 bots: 39/39 e oito veículos sem sobreposição
de nascimento (execução anterior na mesma branch, antes do retoque
visual que não afeta física).

### Perfil GPU de referência

GTX 1650, 1920×1080, preset Alto e escala 100%, 28 bots, 18 s:
- **57,2 FPS médios**, p50 **15,93 ms**;
- p99 **58,40 ms**; pior quadro **178,66 ms**;
- física p99 **31,12 ms**;
- mediana **1.357 draw calls**, pico **2.089**.

Nota: testes Godot de outras IAs executavam simultaneamente no notebook.
Esse resultado **não comprova 60 FPS estáveis** nem prova uma diferença
precisa contra outras branches medidas em duração/carga diferente.
Não encerrar os processos de terceiros para forçar resultado artificial.
Testar novamente sem concorrência antes de liberar build final.

## Gates / próximos passos

- **Regressão concluída:** `favela_architecture_qa.gd` PASS com 120 escadas,
  12 passarelas e 8.747 amostras físicas. `favela_spatial_review.gd` PASS,
  4.199 lotes, 83,7% das bordas a menos de 5 m, 0 casas invadindo ruas,
  0 lotes sobrepostos.
- **Multiplayer concluído:** um servidor Godot + dois clientes Godot reais
  em ENet/DTLS, 28 bots + 2 humanos, **18/18 checagens**, todos os
  processos com código de saída 0 e sem falhas reportadas.
- Capturas comparativas de avenida, encosta e mata inspecionadas em
  `1920x1080`. O céu passou de cinza homogêneo a nuvens com azul aparente;
  a mata ganhou sub-bosque e rochas.
- Revalidar performance em uma janela sem testes concorrentes antes
  da integração final no jogo publicado.
- O mapa deixa de apresentar uma mata traseira quase despida, mas
  a aprovação final ainda requer avaliação em jogo das distâncias
  táticas e benchmark sem concorrência.
- Fazer merge revisado **somente** quando as IAs concorrentes finalizarem.
- Não lançar atualização nesta branch automaticamente.

## Referências visuais e de renderização

- Imagens aéreas da Rocinha mostrando edifícios até o encontro com
  cobertura arbórea e nuvens baixas:
  https://conteudo.imguol.com.br/c/noticias/36/2023/11/01/vista-aerea-da-favela-da-rocinha-no-rio-1698853145969_v2_4x3.jpg
- Shader de céu no Godot e custo de regeneração do cubemap ao usar TIME:
  https://docs.godotengine.org/en/4.4/tutorials/shaders/shader_reference/sky_shader.html
