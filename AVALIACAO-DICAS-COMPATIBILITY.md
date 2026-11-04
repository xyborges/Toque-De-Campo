# Avaliação das dicas visuais — Godot 4.7.2

Esta é uma avaliação para orientar experimentos, não uma lista de alterações aprovadas. Os experimentos de Nova Grama e destruição continuam locais e desativados no jogo. Não publicar sem autorização.

## Compatibilidade

- Névoa de profundidade e altura, tonemapping, glow, ajustes de cor, acesso à textura da tela e à profundidade são suportados no Compatibility. O glow usa uma implementação diferente e menos configurável que a do Forward+. Cada efeito deve ser medido, sobretudo em uma GTX 1650.
- Uma correção à sugestão: desde a versão 4.6, o Compatibility dispõe de SSAO simplificado. Na 4.7, esse SSAO expõe apenas raio e intensidade; sua existência não justifica ativá-lo sem medir custo, aparência e estabilidade de quadros.
- Decal, TAA, FSR2, névoa volumétrica, projetores de luz e CompositorEffects não são suportados no Compatibility. Um plano com transparência pode substituir visualmente alguns decals, mas precisa ser testado contra sobreposição, cintilação no terreno e excesso de pixels transparentes.
- A documentação distingue o aquecimento de materiais no Compatibility da pré-compilação de pipelines e do Shader Baker, que se aplicam aos outros renderizadores. Ver um recurso por um quadro durante o carregamento pode reduzir a primeira travada, mas deve ser verificado em todas as variantes importantes e não garante a ausência de travadas de outra origem.
- O filtro anisotrópico já está solicitado nas três texturas do shader de chão existente. Isso não comprova o nível efetivo em cada máquina nem significa que todos os materiais do mapa o usem.
- A escala 3D no Compatibility usa filtragem bilinear; FSR1 e FSR2, na documentação 4.7, são exclusivos do Forward+. Diminuir a escala pode ajudar quando o limite for a GPU, mas não resolve automaticamente gargalo de CPU.

Fontes: [tabela de renderizadores do Godot 4.7](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html), [ambiente e pós-processamento](https://docs.godotengine.org/en/4.7/tutorials/3d/environment_and_post_processing.html), [escala de resolução](https://docs.godotengine.org/en/4.7/tutorials/3d/resolution_scaling.html), [travadas de compilação](https://docs.godotengine.org/en/4.7/tutorials/performance/pipeline_compilations.html).

## Estado do projeto e interpretação

O Guerra já configura névoa, ambiente, tonemapping Filmic e luz direcional com sombra. Já existem faixas de visibilidade/LOD na vegetação e presets gráficos em `scripts/options.gd`: Baixo, Médio, Alto e Ultra. O preset Médio atual seleciona MSAA 2×, escala 3D 0,85 e sombras a 150 m; não há evidência de que seja o melhor padrão para a GTX 1650. A configuração padrão sem escolha usa antisserrilhamento desligado. Alterar presets requer medição e cuidado para que vegetação e distância de desenho não exponham adversários indevidamente no PvP.

Mais detalhe no material pode evitar novos nós e draw calls, mas não é gratuito: amostras de textura, mistura de camadas, transparência e efeitos de tela ainda consomem GPU e memória. O gargalo de CPU medido anteriormente envolve movimentação dos bots e física; isso não prova que o GPU não possa limitar determinada cena ou efeito. A VRAM efetivamente usada deve ser medida, sem presumir sua capacidade apenas pelo nome da placa.

Ao ligar a térmica, `modes/war/scripts/thermal.gd` também varre as malhas de personagens e veículos e repete a inspeção a cada 0,3 s enquanto está ativa. Esse trabalho na CPU é uma hipótese adicional para investigar: aquecer o shader não elimina o custo dessa varredura. Ainda não há medição isolada que atribua uma travada a ela.

A distribuição concentrada em pontos de interesse e o uso de MultiMesh por célula são boas direções, respeitando o catálogo de objetos reutilizáveis e mantendo colisões onde a jogabilidade precisa delas. Névoa e alcance não devem criar diferenças injustas de avistamento entre configurações.

## Próximas medições

1. Separar em ensaios o custo do material do chão e o custo dos detalhes da Nova Grama, com a mesma cena e referências intercaladas. O ensaio combinado anterior não passou no orçamento: as três comparações registraram quedas de FPS de aproximadamente 3,9%, 7,9% e 3,2%, e piora do 1% low em todas; permanece apenas no laboratório. O teste posterior apenas do chão, em 1920 × 1080, manteve 1.430 draw calls e registrou variações de +0,2%, -0,2% e -1,5% de FPS; o 1% low variou +34,1%, -3,3% e -4,4%. Portanto ainda não atende ao critério de não piorar o 1% low, e os valores não comprovam causa devido à variação entre referências. A VRAM total em uso foi cerca de 762 MiB nas amostras, incluindo outros processos; a temperatura da CPU não pôde ser lida. Resultados: `work/nova-ground-20261028-084845-summary.md`.
2. Medir travadas da primeira ativação de térmica e efeitos antes de criar um aquecimento; comparar carregamento, primeiro uso e usos posteriores.
3. Avaliar detalhes localizados e, isoladamente, SSAO simplificado, sombras e filtragem conforme a necessidade visual, registrando frame time, 1% low, memória de vídeo e draw calls. Não ativar recursos por suposição.
4. Comparar presets em condições controladas, mantendo consistência competitiva e registrando o custo de cada configuração.

Os benchmarks de destruição são separados dos de grama. Qualquer resultado de laboratório é provisório até reproduzir controles reais, multiplayer e cenários completos. Nada foi publicado.
