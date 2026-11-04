# Guerra: modelos dos blindados

## Referências e representação visual

Os modelos são geometrias próprias do jogo, inspiradas em fotografias e nas silhuetas dos veículos abaixo. Não são reproduções industriais nem alteram os valores de blindagem, dano, velocidade ou cadência definidos em `WarRules`.

| Modelo | Características incorporadas | Armamento representado |
| --- | --- | --- |
| Guarani | Casco anfíbio em V, seis pneus com sulcos, caixas de roda inclinadas, posição dianteira do motor, periscópios, rampa traseira, escotilhas e estação remota compacta. | REMAX com caixa de munição, módulo óptico e metralhadora visual do tipo M2 .50. |
| BMP-2 | Casco baixo com proa inclinada, seis rodas de apoio por lado, esteiras contínuas, saias laterais, portas e escotilhas do compartimento traseiro, motor na região dianteira e torre cônica facetada. | Canhão visual 2A42 de 30 mm, camisa e freio de boca, além da arma secundária já existente no jogo. |
| Abrams | Casco comprido, sete rodas de apoio por lado, saias segmentadas, torre angular com compartimento traseiro, painéis superiores, cesto, visores e grade de exaustão traseira. | Canhão visual M256 de 120 mm com mantlete, camisa térmica, extrator e arma coaxial do jogo. |
| T-90 | Perfil mais baixo, seis rodas de apoio por lado, torre compacta, blocos externos de proteção, módulos ópticos, saias, tambores traseiros e tronco de recuperação. | Canhão visual da família 2A46 de 125 mm, com camisa, extrator e arma coaxial do jogo. |

Referências consultadas:

- [IDV — Guarani](https://www.idvgroup.com/products/amphibious-armoured-vehicles/guarani/).
- [ARES — REMAX e sistemas de armas](https://ares.ind.br/torres-e-sistemas/).
- [Ukrspecexport — catálogo de blindados, BMP-2](https://www.ukrspecexport.com/uploads/files/Categories/pdf_5/be2e23.pdf).
- [General Dynamics Land Systems — Abrams](https://www.gdls.com/abrams/) e [folheto ilustrado M1A2](https://international.gdls.com/english/products/ABRAMS/M1A2.pdf).
- [Parque Patriot — T-90A](https://parkpatriot.ru/o-parke/tekhnika-parka/t-90a/).

## Correção do casco que desaparecia

O problema não era uma transparência escolhida para o modelo. A montagem juntava primitivas indexadas e faces autorais sem índices. As últimas podiam ficar sem referência no índice final, fazendo partes do casco e da torre desaparecerem.

Os cascos e torres autorais agora geram índices explícitos. `WarRenderBatch` também indexa uma superfície autoral que chegue sem índices antes de agrupá-la. Os materiais mantêm opacidade e descarte normal de faces traseiras; a correção não depende de tornar todas as superfícies visíveis pelos dois lados.

As antenas dos APCs têm apoio no teto do casco. As dos tanques acompanham a torre, com a base encostada no teto. Alças e suportes das armas também possuem pontos de apoio em vez de peças suspensas.

## Hierarquia e disparos

- O casco, a torre horizontal, a elevação da arma e as rodas continuam em nós separados.
- O módulo `vehicle_models.gd` constrói apenas a aparência. O servidor e os clientes mantêm os mesmos pivôs e marcadores definidos em `vehicle.gd`.
- As extremidades visíveis dos canos principal e secundário terminam nos seus respectivos `Marker3D`.
- A rotação visual e a elevação usam os mesmos nós que determinam a origem e a direção efetivas do disparo.
- A colisão e o balanceamento permanecem em seus sistemas existentes; detalhes pequenos não criam centenas de colisores.

## LOD e custo

Os detalhes rígidos são agrupados por material e região térmica. Rodas continuam independentes para a animação; torre e elevação preservam suas articulações.

A geometria detalhada termina a 160 m. A silhueta simplificada começa exatamente nessa distância e permanece até 950 m. O LOD distante mantém rodas ou esteiras, casco, torre e canhão orientados pelos mesmos pivôs. Isso afeta apenas a renderização.

O teste `tests/war_vehicle_models.gd` registra separadamente triângulos próximos e distantes, quantidade de malhas e chamadas de desenho. O orçamento por blindado é inferior a 65 malhas após agrupamento e a 90 mil triângulos somando os dois níveis. A geometria distante deve representar menos de um oitavo da geometria próxima.

## Verificação

O teste cobre os quatro veículos, doze combinações de orientação/elevação por modelo, marcadores de disparo, extremidades reais das malhas dos canos, faixas de LOD, materiais opacos e orçamento de geometria.

Há uma regressão específica para a mistura de malhas com e sem índices e testes de fechamento das superfícies autorais: cada aresta deve ser compartilhada por duas faces, os triângulos não podem ser degenerados e a orientação do volume deve corresponder às faces externas.

As capturas nativas do Godot incluem frente, lateral e traseira. Os resultados medidos são gravados em `tests/war-vehicle-models-after.json`; as capturas ficam em `work/vehicle-after-*.png`.

### Resultado da rodada de 23/10/2026

Foram aprovadas **109 verificações**, sem falhas. Também foram renderizadas vistas próximas das armas e uma vista a mais de 160 m, com enquadramento ampliado para conferir o LOD.

| Modelo | Malhas totais | Triângulos próximos | Triângulos distantes | Malhas distantes |
| --- | ---: | ---: | ---: | ---: |
| Guarani | 34 | 18.844 | 1.220 | 4 |
| BMP-2 | 44 | 47.792 | 392 | 4 |
| Abrams | 52 | 56.332 | 248 | 4 |
| T-90 | 47 | 50.532 | 264 | 4 |

Na cena isolada, a vista distante registrou seis chamadas de desenho por veículo, incluindo o cenário de teste. As vistas próximas registraram de 66 a 164, conforme o modelo e a direção, incluindo sombras. Esses valores não representam o custo de uma partida completa nem substituem os testes de desempenho com jogadores, veículos e efeitos simultâneos.
