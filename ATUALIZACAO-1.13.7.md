# Atualização 1.13.7

Integração do commit `eb61911` à base 1.13.6: campo de baile, ruas e terreno da Favela. A colisão do palco é criada também no servidor dedicado; áudio e iluminação ficam apenas no cliente.

Os registros de diagnóstico agora incluem `war_recovery_request`, `war_recovery_timeout` e `war_recovery_reply` no cliente e `war_recovery_server` no servidor. A sequência do pedido e os horários UTC permitem correlacionar os dois arquivos. `war_simulation.authority_pacing` informa o maior intervalo entre ticks e snapshots e a contagem de tentativas de envio em cada janela de dez segundos. O registro ENet informa RTT, variação, perda de pacotes confiáveis e limitação de pacotes não confiáveis.

`war_simulation.network_peers` amostra esses indicadores separadamente para cada ID de jogador conectado. O cliente grava `war_connection` a cada dez segundos com o número de snapshots aceitos, intervalo médio e máximo entre chegadas, tempo sem snapshot e contagem de recuperações. Isso permite comparar jogadores da mesma partida. A perda confiável e a limitação de pacotes não confiáveis são indicadores distintos; nenhum deles mede sozinho a velocidade de download.

Para investigar uma pausa, exporte o diagnóstico no cliente e compare a sequência do evento com o arquivo `/var/lib/toque-de-campo/game/diagnostics/*.jsonl` do servidor. Se o tick ou as tentativas de snapshot também pararam, a causa está na simulação ou no envio do servidor. Se o servidor continuou tentando enviar e o cliente ficou sem estado, examine o transporte e a recepção no cliente. A tentativa de envio não comprova entrega UDP; a perda ENet se refere a pacotes confiáveis.

A causa original das interrupções espontâneas ainda depende de um episódio capturado simultaneamente nos dois lados. A partida de QA anterior e a amostra do servidor sem jogadores não reproduziram a falha.

## Publicação e verificação em 06/11/2026

Build 94 / versão 1.13.7 publicada no servidor oficial. A instalação assinada passou 13/13 verificações; o manifesto HTTPS corresponde ao assinado, os seis serviços estão ativos e os hashes do executável e do PCK Linux coincidem. Evidências: `work/release1137-prepare.log`, `work/release1137-signed-install.log`, `work/release1137-preflight.log`, `work/release1137-deploy.log` e verificação pós-publicação `LIVE_1137_VERIFICATION`.

A partida online de QA terminou sem falha: 4.281 quadros, 28 bots, 396 snapshots de operação, 185,6 m de moto e drone acionado. O cliente produziu sete amostras `war_connection`. Os 19 pedidos de recuperação foram respondidos e suas sequências 1–19 apareceram também no servidor. Evidências locais: `C:/Users/Joao Borges/AppData/Local/Temp/campo-1137-official-match/client.json` e `work/war-lag-production-1137-qa.json`.

Os 16 primeiros pedidos ocorreram nos 7,2 segundos posteriores à entrada, enquanto os bots recebiam estado inicial. Os três posteriores ocorreram aos 23, 39 e 54 segundos. Nesses últimos, o servidor continuou com cerca de 50 tentativas de snapshot por 10 segundos, o maior intervalo de tick observado foi 93,9 ms e a idade do último snapshot no recebimento dos pedidos ficou perto de 176–177 ms. O ENet do servidor reduziu temporariamente a transmissão não confiável daquele jogador para 81,25%, 62,5% e 68,75%. Isso fornece um indício de limitação no transporte nesses episódios; não identifica ainda por que o ENet a aplicou nem demonstra que sejam os congelamentos mais longos relatados pelo usuário.
