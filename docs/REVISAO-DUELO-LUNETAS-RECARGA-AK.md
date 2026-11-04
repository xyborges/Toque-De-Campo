# Duelo com lunetas, recarga da AK e ombros

Revisão local de 29/10/2026, sem publicação.

## Duelo gráfico

`tests/run_br_optic_duel.ps1` abriu um servidor headless e dois clientes gráficos separados em Compatibility/GTX 1650, a 960 × 640. Conexões reais ENet/DTLS. A preparação de QA fornece posição, inventário e sala; os disparos, previsão de munição, RPCs, projéteis balísticos, colisões, dano, recarga e câmeras são os sistemas do BR.

Foram usadas FAL e AK com Prismática 4× e PSO 4×, invertendo as armas/ópticas entre os clientes. Incluídos em pé, agachado e deitado. Ambos disparam e recebem dano; o equipamento nível 3 permite inspecionar as câmeras antes da eliminação. A sequência final usa disparos reais até o vencedor.

**368 verificações funcionais aprovadas**: câmera principal própria, lente ao vivo respondendo ao movimento, câmera óptica alinhada, somente um viewport de luneta por cliente e nenhum no personagem remoto, troca de luneta/mira de ferro, recuo, recarga real de seis segundos, origem no cano, dano nos dois sentidos, morte, bloqueio de disparo morto e espectador FPP/TPP.

O duelo encontrou uma defasagem de aproximadamente 12,8 mm durante o recuo: a câmera/FPP girava imediatamente, mas a arma física só acompanhava no tick seguinte. `GamePlayer.present_fire()` agora sincroniza a pose no mesmo evento. A origem do tiro permaneceu correta nas 490 verificações de regressão de postura, mira e inclinação lateral.

Relatório: `work/br-optic-duel.json`. Capturas `work/br-optic-duel-scoped-*.png`. O teste não passa pelo login ou pareamento e não é benchmark. Os logs ainda registram dois avisos nativos de encerramento DTLS (-30464) ao desligar os processos; eles não ocorreram durante as trocas de tiro e não foram ocultados nem classificados como falha de câmera. A naturalidade da animação continua sujeita à avaliação visual do jogador.

## Recarga compartilhada da AK

- Mesmo modelo e texturas existentes. Uma preparação offline separa a malha do carregador na junção com o receptor, interpolando apenas os vértices da borda; não reconstrói a arma durante a partida. O arquivo usa as texturas originais, sem duplicá-las.
- A mão esquerda solta, inclina e retira o carregador, busca o novo, aproxima e o encaixa. A direita mantém a empunhadura e depois aciona o ferrolho; a esquerda retorna ao guarda-mão. O contato acompanha a transformação real do carregador.
- Mesma função do temporizador autoritativo para FPP/TPP, BR, Guerra e os demais modos de infantaria. Duração e regras de munição/recarga continuam em seis segundos.
- A cópia FPP usa a árvore já montada; reinstanciar a cena importada criava um carregador fixo extra, agora eliminado.
- Implementação: `scripts/ak_reload.gd`, `scripts/reload_pose.gd`, integração em `scripts/player.gd`. Preparação reproduzível em `tools/prepare_ak_reload.py`, saída `assets/weapons/ak_animated.glb` (aproximadamente 1,6 MB), reaproveitando `ak_0.png` e `ak_1.jpg`.

## Ombros

As superfícies de manga e antebraço eram lofts sem tampas quando a seção final tinha raio diferente de zero. Isso mostrava os ombros como tubos vazios. A própria malha agora fecha essas superfícies e arredonda/estende discretamente a região proximal para sobrepor a junção com o tronco. Não foram adicionadas bolas ou scripts de ombro; IK, colisões e comprimentos dos segmentos permanecem compartilhados.

**1.101 verificações aprovadas** de recarga/malha, abrangendo agachar, deitar, inclinação lateral e mira, contato das mãos, encaixe real do carregador, final/cancelamento, compatibilidade das lunetas e fechamento das superfícies no personagem BR sem equipamento. Erro máximo das mãos no alvo: aproximadamente 0,000000274 m. **2.196 verificações da regressão de poses compartilhadas aprovadas**, sem penetração nos testes de torso existentes. Capturas dos estágios de saída, inserção, encaixe e ferrolho em `work/ak-reload-*.png`.
