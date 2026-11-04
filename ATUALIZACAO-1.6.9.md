# Toque de Campo — 1.6.9

Publicado em 24/10/2026, build 36, protocolo Guerra 8. Download e atualização em [192.168.101.24](http://192.168.101.24/). As notas também estão no site e no atualizador. Todos os participantes precisam atualizar, pois o cenário físico de Guerra mudou.

## Áudio dos veículos

O som anterior tinha osciladores muito perceptíveis, ruído de rodagem dominante e variação de pitch diretamente ligada à velocidade. Isso produzia um motor artificial e mudanças bruscas de timbre.

Os quatro veículos agora usam adaptações de gravações de motores, com equalização, remoção de subgrave, loops com transição contínua e variação suave de rotação e esforço. Rodagem e servo ficaram mais discretos; a rodagem silencia quando parado. Foram preservados áudio 3D, câmera de passageiro e abafamento da óptica interna. Continuam três vozes por veículo, sem criar uma nova voz a cada alteração de velocidade.

Fontes: [Engine-loop heavy vehicle/tank, Nayckron e qubodup, CC BY 3.0](https://opengameart.org/content/engine-loop-heavy-vehicletank) e [Tank Engine Loop.flac, qubodup](https://freesound.org/people/qubodup/sounds/200303/). A segunda página descreve a origem como domínio público, mas exibe CC BY 4.0; mantivemos essa atribuição conservadora. As gravações foram misturadas e adaptadas por veículo: não são apresentadas como registros autênticos de cada modelo de blindado. Autores, licenças e modificações estão em Configurações → Créditos e no pacote distribuído.

## Mapa de Guerra

- Relevo físico com colinas, vales e ondulações. O levantamento na área central mediu de −11,76 a 33,70 metros, mais de 45 metros de variação. A área jogável continua com 2 km de lado.
- Bases e quinze áreas de construção têm patamares nivelados e transições suaves. Estradas acompanham o terreno longitudinalmente; não são mais faixas rígidas suspensas ou cortes artificiais até a altura zero.
- A região central usa terreno com resolução de 2 metros, enquanto as áreas externas usam 10 metros. As bordas compartilham a mesma interpolação. Terreno externo prolonga o horizonte, com colisão igual no servidor e nos clientes.
- Mais de 2.200 árvores: bosques nos flancos e árvores queimadas na zona devastada. Foram adicionados 23.848 grupos de capim, com orientação ajustada à superfície.
- Casas e celeiro receberam fundações, empenas e estrutura de sustentação dos telhados. Chaminés começam no piso. Coberturas das trincheiras têm postes que chegam ao solo e ao telhado.
- Cercas, degraus, pranchas, destroços e pequenos abrigos de sacos de areia foram ajustados ao terreno. As colunas de sacos acompanham individualmente o solo, evitando flutuação em declives.

Árvores usam malhas agrupadas, versões simplificadas à distância e instanciamento. O capim tem distância de exibição limitada. Não foi aumentada a neblina para esconder a ausência de detalhes. As versões de referência Three.js e Babylon não foram alteradas.

## Validação

| Verificação | Resultado |
| --- | --- |
| Contatos físicos de fundações, apoios, estradas, terreno e sacos de areia | 525/525 |
| Caminhada, onze bots e condução dos quatro blindados no relevo | 16/16 |
| Motores, rodagem, servo, mixagem e rotas de câmera | 45/45 |
| Créditos visíveis e contidos na interface | 3/3 |
| Câmera TPP no pacote exportado, 420 frames e rotação horizontal de 435° | 8/8; nenhum frame com apresentação FPP |
| Míssil TV em três clientes ENet locais | 17/17 |
| Guerra no Ubuntu, três contas reais, operador/oponente/passageiro | 25/25 |
| Download real, instalação, assinatura, segunda execução sem novo download e início normal do pacote | Aprovado |

Também passaram as regressões de sensibilidade, equipamentos e térmica, ópticas, HUD, sniper, combate, Guerra multiplayer e passageiros. As galerias foram capturadas dentro do Godot, incluindo o pacote final exportado. A sessão no Ubuntu utilizou contas normais e a autoridade de produção, sem teleporte privilegiado ou modo de contas de teste.

## Desempenho medido

Comparação entre o pacote anterior 1.6.8 e o pacote final 1.6.9: GTX 1650, 1920 × 1080, limite de 60 FPS, doze clientes e um servidor no mesmo PC. Cenário com disparos, veículos, drones, explosões e desconexão coordenada. O personagem de carga era invulnerável para manter o ensaio ativo. Não equivale a doze computadores independentes nem garante 60 FPS constantes em todo hardware.

| Métrica | 1.6.8 | 1.6.9 final |
| --- | ---: | ---: |
| FPS médio | 59,64 | 59,82 |
| 1% low | 37,83 | 41,07 |
| Frame time médio | 16,77 ms | 16,72 ms |
| Frame time p95 | 19,87 ms | 18,86 ms |
| Maior frame | 31,92 ms | 29,86 ms |
| Maior frame na janela de desconexão | 31,92 ms | 25,19 ms |
| Draw calls máximas | 1.701 | 1.637 |
| Memória reportada pelo Godot | 190,67 MiB | 216,63 MiB |

O cenário ganhou detalhes mantendo FPS médio semelhante, com maior consumo de memória e de nós. Nenhum frame ultrapassou 50 ms nessas duas execuções. O 1% low permanece abaixo de 60 FPS; portanto não se declara estabilidade total.

Houve também execução separada com o profiler nativo (`--debug --profiling`): 55,00 FPS médios, 1% low 8,35 e pico de 139,79 ms. Ela imprime relatórios de funções e apresenta picos periódicos; seus resultados instrumentados ficam registrados separadamente, sem substituírem os números do ensaio normal. Dados brutos estão em `tests/performance169-comparison.json` e logs em `work/war-bench-*.log`.

## Arquivos principais

- `modes/war/scripts/terrain.gd`, `world.gd`, `structures.gd`, `vegetation.gd`: relevo, distribuição, construções e apoio no terreno.
- `modes/war/shaders/ground.gdshader`: variação visual de materiais do solo.
- `modes/war/scripts/soundscape.gd`, `audio/war/*.wav`, `audio/war/credits.json`: áudio revisado e licenças.
- `scripts/ui/main_menu.gd`, `export_presets.cfg`: créditos e inclusão no pacote.
- `modes/war/scripts/rules.gd`: protocolo 8, compatível com o novo mundo físico.
- `distribution/release-notes.json`: notas do site e atualizador.

Backup anterior em `work/source-before-169`. Capturas finais: `work/war-map-after169-pack-{approach,village,house,shelter,forest,overview}.png`. Resultados consolidados em `tests/release169-final-status.json`.
