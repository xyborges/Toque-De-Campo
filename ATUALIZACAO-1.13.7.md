# Atualização 1.13.7

Integração do commit `eb61911` à base 1.13.6: campo de baile, ruas e terreno da Favela. A colisão do palco é criada também no servidor dedicado; áudio e iluminação ficam apenas no cliente.

Os registros de diagnóstico agora incluem `war_recovery_request`, `war_recovery_timeout` e `war_recovery_reply` no cliente e `war_recovery_server` no servidor. A sequência do pedido e os horários UTC permitem correlacionar os dois arquivos. `war_simulation.authority_pacing` informa o maior intervalo entre ticks e snapshots e a contagem de tentativas de envio em cada janela de dez segundos. O registro ENet informa RTT, variação, perda de pacotes confiáveis e limitação de pacotes não confiáveis.

`war_simulation.network_peers` amostra esses indicadores separadamente para cada ID de jogador conectado. O cliente grava `war_connection` a cada dez segundos com o número de snapshots aceitos, intervalo médio e máximo entre chegadas, tempo sem snapshot e contagem de recuperações. Isso permite comparar jogadores da mesma partida. A perda confiável e a limitação de pacotes não confiáveis são indicadores distintos; nenhum deles mede sozinho a velocidade de download.

Para investigar uma pausa, exporte o diagnóstico no cliente e compare a sequência do evento com o arquivo `/var/lib/toque-de-campo/game/diagnostics/*.jsonl` do servidor. Se o tick ou as tentativas de snapshot também pararam, a causa está na simulação ou no envio do servidor. Se o servidor continuou tentando enviar e o cliente ficou sem estado, examine o transporte e a recepção no cliente. A tentativa de envio não comprova entrega UDP; a perda ENet se refere a pacotes confiáveis.

A causa original das interrupções espontâneas ainda depende de um episódio capturado simultaneamente nos dois lados. A partida de QA anterior e a amostra do servidor sem jogadores não reproduziram a falha.
