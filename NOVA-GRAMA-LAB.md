# Nova Grama — laboratório local

Este é um protótipo de teste. Ele não é carregado no jogo normal, não altera a colisão do terreno e não foi publicado. O material do terreno só é substituído temporariamente enquanto o laboratório está ativo.

## Mapa pintável

O arquivo `assets/war/biomes/nova_grama.png` cobre os 3.500 × 3.500 metros do mapa. A esquerda corresponde a X = -1750 m e a direita a X = +1750 m; o topo corresponde a Z = -1750 m e a base a Z = +1750 m. É possível editar o PNG num editor de imagens usando estas cores:

| Região | RGB | Hexadecimal |
|---|---|---|
| Campo | 48, 150, 54 | `#309636` |
| Queimada | 108, 65, 50 | `#6c4132` |
| Transição | 178, 151, 80 | `#b29750` |
| Trilha | 174, 165, 145 | `#aea591` |

O terreno mistura os materiais suavemente; os detalhes são classificados pela cor mais próxima. Para preservar bordas naturais sem criar cores ambíguas, prefira blocos com essas cores e deixe a suavização para o shader. O gerador `tools/create_nova_grama_map.py` não sobrescreve um PNG existente.

## Limites atuais

O protótipo muda o material de todos os setores visuais e filtra a vegetação antiga nas regiões queimadas, mas os detalhes novos são gerados apenas em uma área experimental de 200 × 200 m. Há uma opção adicional de laboratório que reclassifica os grupos que usam o modelo padrão de árvore; peças de vegetação e árvores com outras malhas ficam fora desse filtro. Os exemplos de árvore gerados no laboratório são somente visuais. O sistema não deve ser confundido com uma implementação completa para o mapa ou com uma atualização pronta para publicar.

Os capins e fragmentos experimentais são agrupados por células de 20 m, sem sombras, colisões ou scripts individuais. O teto é de 200 candidatos por célula, em 100 células; a seleção real depende do bioma, relevo, ruas e trincheiras. Há sete triângulos por tufo novo. O custo total de geometria e chamadas de desenho é medido pelo renderizador, porque parte das células é descartada fora da tela ou da distância configurada.

## Compatibility e aparência escura

Na documentação oficial do Godot 4.7, [`Decal`](https://docs.godotengine.org/en/4.7/classes/class_decal.html) não funciona no Compatibility. [`GPUParticles3D`](https://docs.godotengine.org/en/4.7/classes/class_gpuparticles3d.html) funciona, mas há limitações nesse renderizador, incluindo trilhas e colisão SDF. O [idioma de shaders](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/shading_language.html) admite `sampler2DArray`; não se deve confundir isso com a restrição a arrays de cubemaps na [matriz de renderizadores](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html). Este experimento usa texturas 2D comuns, sem decals nem partículas.

O capim existente usa cor escura e normais laterais nas lâminas; dependendo do lado iluminado, isso diminui a luz recebida. A iluminação noturna também reduz a intensidade do sol e usa preenchimento azulado. Ambos contribuem para o escurecimento; a contribuição exata de cada um não foi isolada por medição. O capim experimental usa normais mais voltadas para cima e uma cor diferente. A visão térmica atual converte a luminosidade da cena em tons de cinza: a captura à noite ficou quase preta, uma limitação própria dessa apresentação térmica, não uma prova de que o shader de grama tenha falhado.

## Reprodução

`tests/nova_grama_lab.tscn` contém o componente opcional. O benchmark `tests/nova_grama_benchmark.gd` carrega o mapa de Guerra e o ativa com `--nova-grama`; `tests/run_nova_grama2_ab.ps1` executa o bloco intercalado em 1080p com 18 participantes. Os resultados ficam em `work/`, incluindo métricas e capturas em três distâncias, de dia, à noite e na visão térmica.

Não substituir um benchmark intercalado por uma medição isolada: os clocks e a carga do computador variam. A primeira série `nova-grama-` aplicou o material em somente um setor por causa de nomes duplicados; ela foi descartada para avaliar o material. A série corrigida usa o prefixo `nova-grama2-`.

## Resultados até agora

Todas as séries usaram a GTX 1650, Jolt, renderização Compatibility, textura renderizada em 1920 × 1080 e 18 participantes no Guerra offline. A câmera permaneceu parada; nesse trecho os bots não entraram em tiroteio. Cada execução mediu 20 segundos, excluindo os três primeiros, com a semente 193. Os valores representam este cenário, não uma partida inteira nem 18 clientes conectados.

- Na repetição `nova-grama3`, comparando a versão atual com o terreno e detalhes experimentais **sem** a troca global das árvores, os três pares ficaram em -1,0%, -5,4% e -5,0% de FPS; o 1% low variou +9,5%, +13,3% e **-24,2%** frente às referências vizinhas. A variação de clocks e de IA limita a interpretação, mas a última queda não atende ao critério de aceitação. A experiência continua desligada.
- `nova-grama4` comparou células de 20 m com agrupamento em 40 m, preservando as posições. Os grupos experimentais caíram de 157 para 72 e o pico de chamadas de desenho do quadro, de 1451 para 1439. Porém, não houve ganho consistente de FPS e o 1% low piorou em dois blocos. A mudança de agrupamento não foi adotada.
- `nova-grama5` e `nova-grama6` testaram duas versões da classificação de árvores, mas foram **descartadas como avaliação da implementação correta**: o filtro também identificava malhas usadas como pequenos galhos de pinheiros, que não são árvores independentes. A filtragem foi corrigida e precisa de nova medição. Os registros foram preservados apenas para investigação; nenhum desses resultados justifica integrar a funcionalidade.
- A série `nova-grama8` também foi descartada: duas execuções se sobrepuseram e gravaram nos mesmos arquivos após interrupções. Não é possível reconstruir uma comparação confiável a partir desses dados.
- A série exclusiva `nova-grama9-20261028-081931` repetiu a comparação completa após corrigir a identificação das árvores, sem outros processos Godot presentes. Cada execução mediu 25 segundos e usou arquivos exclusivos. Contra as referências adjacentes, os pares tiveram **-3,9%, -7,9% e -3,2% de FPS** e **-6,6%, -4,0% e -13,3% no 1% low**. O protótipo acrescentou aproximadamente 31 chamadas de desenho, 568 nós e 25,1 MiB de memória estática neste cenário; as primitivas totais caíram cerca de 20 mil devido à filtragem do capim antigo. Os clocks e temperaturas estão registrados no resumo da série. A proposta não atendeu ao limite de desempenho e continua desligada. A área adicional de detalhes cobre apenas 200 × 200 m, de modo que esse resultado não mede o custo de estendê-la para o mapa todo.
- Em `nova-ground-20261028-084845`, isolamos o material do chão sem adicionar os detalhes. As chamadas de desenho permaneceram em 1.430 e os três pares ficaram em +0,2%, -0,2% e -1,5% de FPS. O 1% low variou +34,1%, -3,3% e -4,4%; como houve piora em duas comparações e a referência também oscilou, o resultado não demonstra que o material tenha causado a queda, mas tampouco permite aceitá-lo pelo critério definido. Não substitui o teste completo de bioma, que precisa também modificar a vegetação.
- Em `nova-details-20261028-090359`, isolamos detalhes e filtragem de grama, com o material de chão original e perfil de teste separado. Os pares deram +4,9%, -9,9% e +3,6% de FPS; o 1% low variou +11,9%, -11,3% e +29,6%. A variante acrescentou 21 chamadas de desenho e aproximadamente 538 nós nesse enquadramento; a memória estática subiu cerca de 24,4 MiB. O bloco não atende ao limite de 5% nem ao de 1% low, e a variação elevada impede atribuir o custo com precisão. Trata-se de apenas 200 × 200 m de detalhes novos; segue experimental e não foi integrado.
- A série `nova-mask-20261028-091629` comparou diretamente, em sete execuções, a máscara original com uma que substituía os recursos nos próprios nós, sem duplicar lotes. Embora tenha reduzido cerca de 380 nós e 20,1 MiB de memória estática, as três diferenças de FPS foram -4,5%, -16,7% e +11,2%, e o 1% low variou -42,8%, -22,8% e +51,6%; um quadro da variante levou 121,8 ms. Há variação elevada entre execuções e os clocks também mudaram, de modo que não há prova de causa da travada, mas tampouco há ganho consistente. A variante foi revertida como pedido. O relatório e dados brutos permanecem em `work/`.
- Depois da reversão, `nova-post-revert` confirmou a execução do laboratório anterior com 18 participantes, nenhuma representação de capim nas áreas queimadas entre as 113.415 verificadas e restauração da visibilidade e dos materiais após desligá-lo. É um teste funcional rápido, não uma nova medição de desempenho.

Os relógios e temperaturas da GPU, o relógio estimado da CPU, tempos dos quadros e dados brutos ficam nos arquivos `work/nova-grama*-offline.json`, `work/nova-grama*-hardware.jsonl` e nos resumos Markdown correspondentes. A temperatura da CPU não pôde ser lida pelo Windows. Na auditoria gráfica foram examinadas 113.415 representações de capim, incluindo níveis próximo e distante, com zero classificadas na área queimada; tufos secos montados separadamente não estão nessa contagem. O teste de desligar o laboratório confirmou a restauração dos materiais dos 171 setores e dos 278 grupos de árvores modificados, inclusive da visibilidade prévia.
