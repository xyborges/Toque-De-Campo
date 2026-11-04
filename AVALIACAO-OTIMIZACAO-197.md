# Avaliação de desempenho — Guerra, versão 1.9.7

Análise local; nenhuma atualização publicada. Motor Godot 4.7.2, Jolt e renderizador GL Compatibility, GTX 1650. O jogo continua configurado para 60 ciclos de física por segundo, sem interpolação global.

## Método e limites

O cenário usa o mapa real, um jogador local e 17 bots offline, semente 193, câmera fixa na frente central, mesma máquina e resolução interna registrada como 1965 × 1080. Cada execução dura 45 s, descartando os três primeiros segundos. As posições, decisões e ações variam conforme o tempo real, apesar da mesma semente. O pior quadro é expresso em milissegundos: quanto menor, melhor. Não representa 18 computadores conectados, nem o custo completo do servidor online.

O Profiler embutido do Godot, em execução adicional com instrumentação, identificou mais tempo acumulado nos métodos de movimento dos bots, movimento dos personagens e simulação dos veículos. Os tempos são inclusivos, podem conter chamadas aninhadas e esperas, e o próprio Profiler interfere no desempenho; não devem ser somados entre si nem com a GPU. Na captura, o solver interno Jolt não apareceu como custo isolado dominante. Métodos chamados durante o ciclo de física e consultas de colisão ainda são relevantes.

## Resultados — três execuções por condição

Os valores de cada execução são: FPS médio / FPS do 1% mais lento / pior quadro em ms.

| Condição | Execução 1 | Execução 2 | Execução 3 | Decisão |
| --- | --- | --- | --- | --- |
| Referência inicial: 60 Hz | 25,6 / 15,6 / 83,4 | 25,6 / 16,2 / 75,3 | 26,7 / 17,5 / 64,0 | Referência da primeira sessão |
| Interpolação global, 60 Hz | 22,7 / 10,3 / 119,8 | 17,4 / 11,1 / 95,5 | 25,1 / 16,9 / 63,9 | Descartada; média e 1% low piores e avisos de atualização fora da física |
| Física a 40 Hz sem interpolação, sessão inicial | 35,9 / 18,6 / 75,2 | 38,3 / 21,1 / 64,7 | 38,8 / 21,8 / 56,9 | Resultado não suficiente por si só |
| Interpolação seletiva em personagens e blindados, 40 Hz | 21,4 / 7,1 / 160,4 | 27,1 / 10,2 / 146,3 | 50,1 / 29,8 / 44,8 | Inconclusiva: execução 3 ocorreu após interrupção e mudança evidente nas condições do PC; protótipo exclusivo do benchmark |
| Referência repetida após retomada: 60 Hz | 42,0 / 24,1 / 49,7 | 42,0 / 27,0 / 56,0 | 41,0 / 26,5 / 46,4 | Referência da segunda sessão |
| Física a 40 Hz sem interpolação, repetida | 53,4 / 14,9 / 99,2 | 49,0 / 13,5 / 81,1 | 48,0 / 13,3 / 90,3 | Descartada: mediana do FPS sobe, mas 1% low e pior quadro pioram |
| Hitboxes sem monitoramento ativo, 60 Hz | 38,9 / 18,1 / 91,9 | 33,2 / 14,4 / 95,6 | 35,0 / 19,6 / 60,2 | Descartada: sem melhora demonstrada; alteração foi apenas na cena de benchmark |
| Atalho experimental na consulta de água, 60 Hz | 37,1 / 23,0 / 57,4 | 36,5 / 23,0 / 51,4 | 35,0 / 19,3 / 74,7 | Revertido: não superou a referência |
| Interpolação seletiva em personagens e blindados, 60 Hz | 38,9 / 23,2 / 61,4 | 37,5 / 24,2 / 53,2 | 36,7 / 22,5 / 57,6 | Não adotada: sem ganho medido; requer teste visual separado para avaliar tremedeira |

As diferenças entre sessões mostram variação de carga do computador. Mesmo as comparações sequenciais podem sofrer influência de frequência da GPU/CPU, temperatura, tarefas externas, sincronização e decisões diferentes da IA. A mediana de 40 Hz na segunda sessão foi 49,0 FPS versus 42,0 FPS, mas 13,5 versus 26,5 no 1% low. Não é correto atribuir toda a diferença exclusivamente à alteração. Para ganho pequeno seria preciso novo ensaio alternado A/B/A/B com captura de carga externa.

## Análise das sugestões

| Sugestão | Situação e possível ganho | Risco / decisão |
| --- | --- | --- |
| Jolt | Já ativo no projeto e no servidor. A captura não indica o solver interno como principal item. | Manter. Ragdolls, colisões e blindados continuam dependentes do mesmo motor. |
| Interpolação da física | Não está ativada. Pode melhorar a apresentação, não é uma otimização garantida de FPS. A ativação global foi medida e piorou; o teste seletivo a 40 Hz foi inconclusivo e o seletivo a 60 Hz não trouxe ganho de desempenho. | Alta atenção: câmera FPP, `MultiMesh`, transições, teletransportes e interpolação existente na rede; requer adaptação por ramo e verificação visual em movimento. |
| Redução para 40/30 ciclos | O trabalho da simulação ocorre no ciclo de física, mas a medição de 40 Hz piorou muito o 1% low na repetição. 30 Hz não foi testado. | Descartar 40 Hz para esta versão; não extrapolar para 30 Hz. Riscos em veículos, tiros, hitboxes, ragdolls, cadência de rede e resposta de controles. |
| Mudanças de Jolt na 4.7 | O projeto já roda na 4.7.2; `ConeTwistJoint3D` é usado no ragdoll. Não encontrei usos de `WorldBoundaryShape3D` ou `SoftBody3D` no código do jogo. | Os testes de ragdoll a 40 Hz passaram, inclusive com 12 corpos em contato; não substituem inspeção visual de todas as articulações. |
| Shader Baker | Não beneficia o renderizador atual Compatibility, segundo a documentação oficial. | Não habilitar esperando ganho; mudar para Forward+ exigiria nova comparação de GPU e compatibilidade. |
| Stencil | Não é a solução de gargalo identificada; seria recurso visual de marcação, com custo e possível exposição de inimigos. | Não ativado. Visibilidade não pode depender apenas do cliente. |
| Áreas Jolt | Algumas áreas, como hitboxes genéricas, têm máscara zero mas monitoramento padrão; a perna e míssil já desligam o monitoramento. Experimento com as hitboxes não comprovou ganho. | Descartar por ora; manter camadas consultáveis para tiros e headshots. |
| AreaLight3D | Recurso visual, sem benefício direto para o gargalo; no Compatibility não projeta sombras de área. | Não adicionar luzes para otimização; novas luzes podem custar GPU. |
| Navegação em regiões | Bots usam grade AStar para parte central, grafo de trânsito e decisões escalonadas; não há NavigationRegion3D separada. O Profiler mostrou custo nos bots, mas não isola o roteamento como maior causa. | Protótipo localizado, posterior a medir movimento e consultas. Riscos: rotas de infantaria e blindados, cobertura, autoridade e sincronização. |
| Terrain3D / clipmap | Terreno já é dividido em setores visuais e colisões geradas, não Terrain3D. O fornecedor declara suporte à 4.7 e Compatibility, mas isso não confirma nosso mapa ou servidor. Ganho ainda não medido. | Migração grande e não prioritária: trincheiras editáveis, altura, colisão de blindados, construção de mapa e correspondência entre servidor e clientes. |
| Projéteis por raios e pool | Já há um laço de simulação, pool fixo e raios para colisão; traçantes usam MultiMesh. | Preservar; novo sistema sem medição poderia introduzir erros de colisão e sincronização. |
| Partículas e decals | Fumaça, faíscas e projéteis já usam pools MultiMesh; chuva usa partículas. Decals não foram identificados como gargalo. | Limitar overdraw quando houver explosões demonstradamente pesadas. Preservar informação de tiros, fumaça e visão térmica. |
| Interest management e headless | Servidor headless já existe; estados usam envios próprios, sequência, heartbeat e agrupamento, não `MultiplayerSynchronizer` com filtros gerais de interesse. | Potencial de rede e CPU no online, mas requer teste de entrada/saída da área, tiros de longa distância, bots, veículos, dano e placar; ganho desconhecido no offline medido. |
| WorkerThreadPool | Não identificado para visão e IA. | Último: acesso a mundo físico e árvore de cena exige cuidado; resultados antigos podem causar tiros através de parede ou decisões diferentes da autoridade. Ganho desconhecido. |

## Ordem recomendada

1. Medir novamente movimentos dos bots e `move_and_slide`, com benchmark alternado A/B e carga externa registrada. Priorizar menos consultas ou trabalho repetido, sem diminuir a frequência de colisões.
2. Investigar picos de quadro: criação/destruição de atores, eventos e renderização de vegetação, isolando GPU, CPU e compilação em Compatibility.
3. Avaliar interpolação seletiva a 60 Hz como melhoria de apresentação com teste visual de FPP/TPP, câmeras, entrada/saída de veículos, respawn e jogadores remotos. Manter separada da decisão de diminuir a física.
4. Medir interesse e cadência de rede em sessão real com vários clientes, antes de mudar replicação.
5. Só se o caminho de bots for dominante, prototipar regiões de navegação e comparar a IA e o custo; investigar Terrain3D como projeto próprio, não troca imediata.
6. Considerar WorkerThreadPool por último, para cálculos isolados e seguros; stencil, luz de área e novos efeitos são escolhas visuais, não otimizações prioritárias.

## Validação funcional

O teste de trincheira a 40 Hz percorreu a frente e a ré com Guarani, BMP-2, Abrams e T-90, offline e em simulação local da autoridade. A direção também foi exercitada nos quatro blindados nos dois caminhos; todos passaram. Os testes de ragdoll simples e de 12 corpos em contato passaram a 40 Hz. Um teste separado com servidor local e três clientes verificou o operador, passageiro, restrições de uso, movimento, tiro, troca de posto e saída; o servidor registrou 14 verificações e o passageiro 10, sem falhas. Não foi uma partida na internet nem uma avaliação visual completa de 144 Hz. Os 40 Hz não foram adotados.

Referências oficiais: [interpolação](https://docs.godotengine.org/en/4.7/tutorials/physics/interpolation/using_physics_interpolation.html), [uso avançado](https://docs.godotengine.org/en/4.7/tutorials/physics/interpolation/advanced_physics_interpolation.html), [Shader Baker e Compatibility](https://docs.godotengine.org/en/4.7/tutorials/performance/pipeline_compilations.html), [AreaLight3D](https://docs.godotengine.org/en/4.7/classes/class_arealight3d.html), [migração 4.7](https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.7.html), [lançamentos do Terrain3D](https://github.com/TokisanGames/Terrain3D/releases).
