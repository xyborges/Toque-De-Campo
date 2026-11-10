# Favela V2 — casas, becos e crista montanhosa oeste
**10/11/2026 · Branch experimental:** `ia/favela-v2-densidade-becos-morro-20261110`

## Escopo aplicado no Godot 4.7.2
A Favela V2 segue em *blockout* 3D, construída na branch de protótipo `ia/favela-v2-occlusion-lod-pilot-20261110`, sem tocar a Favela pública, `main` ou a versão distribuída.

- **385 casas** no terreno real: **348** ao longo das curvas da via central/leste e **37** no morro esquerdo; o protótipo anterior tinha 197 no total. Os imóveis agora ocupam **três linhas escalonadas** próximas às ruas e conservam os identificadores da topologia.
- **Nove variantes** de escala/altura/largura e combinações de portas, grades, janelas de madeira, toldos, comércio, puxadinhos, lavanderias, obras e varais da biblioteca anterior. As paredes usam **tijolo, reboco e concreto**, com materiais/texturas compartilhados (`brick`, `plaster`, `concrete`). Lajes com concreto texturizado. Não foram sobrescritas cenas da biblioteca.
- **27 novos becos** de concreto, aproximadamente 21 m de profundidade e 2,65 m de largura, distribuídos perpendicularmente a ruas principais e secundárias. A posição é reservada **antes** das casas; nenhum prédio pode ocupar a faixa. Um filtro por amostras de altura remove acessos com transições de inclinação que a física do personagem não consegue vencer. Os becos são *ramais sem saída*: não acrescentam atalhos de bot para a base alta. São visuais, sobre a **mesma colisão física do terreno**.
- **190 arbustos** do `favela_arbusto_encosta.tscn` em **36 lotes MultiMesh de ~92 m**; sem script/colisão por arbusto, sem sombras individuais, alcance visual de 180 m. Reservados às encostas e às bordas, não às ruas, bases ou casas.
- **Barreira natural norte-oeste:** elevação integrada ao heightmap com flanco íngreme (gradiente máximo amostrado **2,44 m/m**), mais **quatro faces de rocha irregulares com colisão** compartilhada no cliente/servidor. Isso bloqueou a tentativa física de travessia teste do morro, sem transformar o bairro em uma bacia circular e sem bloquear o acesso central `l00`. As cinco outras faces existentes e as 49 células do terreno foram mantidas.
- **Correção de Jolt Physics:** detalhes de telhado e fachada que não exigem colisão agora têm suas formas desativadas **antes** de entrar na árvore 3D. Antes, alguns corpos decorativos geravam erros por escala não uniforme, mesmo com collision_layer=0.
- **Tempo de construção:** casas do oeste e corredores são planejados apenas uma vez por construção, evitando recomputações de listas e alturas. Ainda resta custo de spawn a otimizar em etapa própria.

## Validações executadas
- `tests/favela_v2_density_qa.gd`: **22/22 PASS**, 385 imóveis, 27 becos, nove variantes, distância mínima entre casas de 11,42 m, afastamento mínimo centro da casa → eixo do beco de 5,70 m, quatro corpos de crista autoritativos e zero colisores de decoração.
- `tests/favela_v2_density_walk_qa.gd`: **10/10 becos amostrados PASS** usando `GameStepMotion` real. Tentativa direta de transpor a crista pela esquerda a partir de (x = -205 m, z = -203 m), 550 frames, interrompida aproximadamente em **z = -228,28 m**, sem chegar à vertente norte. Isto **não** prova impossibilidade de contorno por todas as coordenadas do mapa.
- `tests/favela_v2_ascension_walk_qa.gd`: **18/18 PASS** em nove segmentos oficiais (subida e descida), sem recuos.
- `tests/favela_v2_ascension_qa.gd`: **31/31 PASS** nos 25 pontos do grafo, 49 células e acessos.
- `tests/favela_v2_visual_optimization_qa.gd`: **787/787 OFF** e **787/787 ON**: 385 colisores de edifícios preservados, 6.182 detalhes com LOD; oclusão experimental opcional com 154 occluders, desligada por padrão.
- `tests/favela_v2_density_visual_qa.gd`: **3/3 capturas PASS** no Forward+ / NVIDIA GTX 1650, **zero erros no log** após correção das colisões dos kits decorativos.

## Benchmark exploratório GTX 1650 (1080p, Forward+)
Dois pares A/B (197 casas antigas versus 385 casas), com 150 frames em três posições após aquecimento de 75 frames; zero bots, sem combate. Dados brutos e médias em `docs/benchmark-results/favela-v2-density-20261110/ab.json`.

| Métrica | Anterior (197 casas) | Nova (385 casas) |
| --- | ---: | ---: |
| Construção média completa | **1.065 ms** | 1.637 ms |
| Draw calls, baixa | 153 | 231 |
| Draw calls, miolo | 108 | 151 |
| Draw calls, alta | 82 | 106 |
| P99 média baixa | 10,48 ms | 6,09 ms |
| P99 média miolo | 9,50 ms | 5,27 ms |
| P99 média alta | **5,13 ms** | 6,83 ms |

O terceiro ensaio, **depois da eliminação das recomputações de planejamento**, registrou **1.557 ms** de montagem da versão densa. Foi apenas uma execução, não há base para declarar ganho estatístico sobre os 1.637 ms anteriores.

**Interpretação:** a densidade nova aumenta draw calls e custo de construção, mas a medição do P99 variou muito entre sessões. O ambiente não tinha controle de foco de janela nem exclusividade da GPU; portanto, não afirmar que a nova V2 é mais rápida em combate. Este protótipo não tem os 28 bots da build jogável. A construção visual ainda pode causar pico no spawn, e precisa ser amortizada antes do lançamento.

## Capturas diretas do jogo
- `docs/images/favela-v2-densidade-geral.png` — mapa inteiro e curvas da subida
- `docs/images/favela-v2-densidade-becos.png` — camadas de casas, becos e campinho
- `docs/images/favela-v2-densidade-morro-oeste.png` — crista esquerda e casas no declive

## Próxima etapa recomendada
**Não integrar na `main` ainda.** Primeiro, resolver o pico de construção visual (instanciamento de centenas de casas e milhares de módulos), limitar draw calls de fachadas sem retirar colisões/cobertura, verificar os 27 becos por todo o comprimento e validar as rotas de pedestres com bot/servidor autoritativo. Depois, repetir teste 0/12/22/28 bots com janela em foco (100%), spawn, FPS P95/P99 e áudio/efeitos sob combate.

A base e a versão pública permanecem intactas.
