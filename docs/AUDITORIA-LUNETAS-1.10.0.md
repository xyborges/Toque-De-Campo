# Auditoria visual das lunetas — 1.10.0

O caminho de seleção funciona: o acessório escolhido chega ao modelo da arma e à cópia de primeira pessoa. A auditoria gráfica `tests/optic_model_audit.gd`, em Compatibility na GTX 1650, passou por 26 verificações e gerou capturas dos quatro pares FAL/AK × Prismática/PSO, em primeira pessoa, montagem lateral e ADS.

Resultado em `work/optic-model-audit.json`. A preparação da cópia FPP preserva a mesma geometria do módulo físico, existe uma única instância selecionada por representação e os dois módulos têm geometrias distintas nas duas armas. O apelido antigo `scope4x` continua resolvendo para Prismática na FAL e PSO na AK. Uma seleção canônica explícita de mira de ferro também prevalece sobre metadados antigos.

A semelhança visual apontada pelo jogador tem fundamento. As duas cenas herdam `scenes/weapons/scope4x.tscn` e compartilham o tubo, ocular, parte das torres e o mesmo shader/retículo de cruz. Ambas usam ampliação 4×. A Prismática acrescenta um corpo prismático e base; a PSO acrescenta tubo mais longo, objetiva, bateria e montagem lateral. Vistas de lado são diferentes, mas em ADS a ocular circular e o retículo compartilhados dominam a imagem. A Prismática atual ainda se parece com um tubo compacto sobre uma base, distante da silhueta SUIT da referência do usuário.

O gerenciador não substitui incorretamente toda seleção pelo mesmo recurso. O problema identificado é caracterização visual insuficiente dos dois modelos. Uma revisão visual pode manter os contratos `MountReference`, `Eye` e `Lens`, a montagem por interface, a câmera ao vivo e a origem do projétil. Deve diferenciar a carcaça e o desenho do retículo, sem alterar o sistema de seleção para esconder a diferença.

No BR há dois itens reais separados (`prism4x` e `pso4x`) que podem ser equipados nas duas armas. O loadout dos demais modos ainda apresenta uma escolha antiga “Mira 4×”, que usa o apelido por arma; ele não é um seletor entre os dois módulos. Isso também pode contribuir para a impressão de que a troca não existe fora do BR.

Capturas em `work/optic-model-<arma>-<acessório>-fpp.png`, `-mounted.png` e `-ads.png`. Nenhuma alteração de produção, exportação ou publicação foi feita nesta auditoria. O teste valida seleção e geometria efetivas, sem aprovar subjetivamente a qualidade dos modelos e sem substituir o teste de duelo multiplayer.

## Revisão visual posterior, ainda sem publicação

A Prismática foi remodelada em `scenes/weapons/scope4x_fal.tscn` e `scope4x_fal_housing.res`: carcaça curta facetada, objetiva dianteira mais baixa que o topo do corpo, tambor dianteiro, duas sapatas e ocular curta octogonal. As partes cilíndricas herdadas ficam ocultas, preservando os nós e transformações `MountReference`, `Eye` e `Lens`. A PSO continua com corpo longo, borracha sanfonada, bateria e suporte lateral. Ampliação, retículo e câmera não foram alterados.

A carcaça é agrupada em três superfícies de material, mais a lente existente. Na FAL são 942 triângulos e quatro superfícies visíveis; na AK, 954 triângulos e cinco superfícies com o adaptador. Antes eram aproximadamente 2.302 triângulos e 14 malhas visíveis na FAL. Isso é orçamento geométrico, não resultado de benchmark de FPS.

As capturas foram refeitas e inspecionadas. A auditoria do modelo passou novamente (26 verificações), o catálogo gráfico passou (54 verificações, câmera ao vivo e troca) e a regressão da origem do projétil passou (490 verificações, maior diferença de aproximadamente 0,000000359 m). O script de autoria offline é `tests/bake_prismatic_housing.gd`. Nenhuma publicação foi realizada nesta revisão.
