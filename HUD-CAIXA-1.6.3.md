# HUD e caixa de munição — integração 1.6.3

## Objetivos e implantação de Guerra

O marcador dos objetivos guardava uma posição de tela calculada apenas a cada 100 ms. Ao mover a câmera entre essas atualizações, o ponto permanecia temporariamente no lugar anterior. Agora a projeção usa a câmera atual no momento do desenho; nome, distância e cor são atualizados separadamente, a quatro vezes por segundo. Os três registros e os controles são reutilizados.

A implantação usa `deployment_ready()` e `deployment_wait_left()` da autoridade. O botão apresenta o tempo de espera e fica indisponível até o prazo terminar. A linha **SALVO NO SERVIDOR** mostra equipe, classe e ponto recebidos em `pending`; mudar o formulário sem enviar não é apresentado como confirmação.

O teste nativo `tests/war163_hud_projection.gd` aprovou **19 verificações** em 1024 × 768 e 1920 × 1080. Movimentos ocorreram abaixo do intervalo de atualização do restante do HUD; o erro máximo da projeção foi **0 px**. Também confirmou o esconderijo dos marcadores em morte/menu, ausência de criação de nós e os estados de implantação. Evidências: `tests/war163-hud-projection-results.json`, `work/war163-hud-projection.log`, `work/war163-objective-projection.png`.

## Caixa do Deserto

O caminho anterior enviava o inventário privado a todos os participantes e reenviava o loadout ao dono, embora uma reposição não alterasse armas equipadas. A caixa usa agora um único snapshot autoritativo dirigido ao dono, reaproveitando a aplicação normal de inventário. Vida e revisão são verificadas antes de alterar qualquer estoque. Não há reconstrução de arma, personagem ou geometria.

As capacidades das três armas de fogo ficam em cache. Entradas desconhecidas não recebem munição de um FAL por fallback. Alcance, visibilidade, quantidades e intervalo de vinte segundos permanecem. Solicitações repetidas durante o cooldown têm um orçamento curto de feedback, evitando criar uma mensagem/timer por pedido duplicado. Desconexão remove esses registros.

`tests/supply_validation.gd` aprovou **19 verificações headless**: capacidades exatas, sem reconstrução/parada de movimento, duplicações, cooldown, vida inválida, morte, granada, distância, destinatário incorreto, pacotes antigos e limpeza ao desconectar. A regressão anterior `tests/combat_155.gd` aprovou **64 verificações**, incluindo linha de visão bloqueada e regras de dominação. As duas capturas desse teste são simplesmente ignoradas em headless; a lógica é a mesma.

## Medição antes e depois

Servidor e três clientes ENet locais no mapa real do Deserto, um cliente renderizado e dois observadores headless, limite de 60 FPS. Cada janela de navegação possui 120 frames; os intervalos foram medidos por relógio real, sem usar o delta suavizado do Godot.

| Medida | Antes | Depois |
| --- | ---: | ---: |
| Inventário da reposição entregue aos dois observadores | 1 para cada | 0 |
| Pacote redundante de loadout entregue ao dono | 1 | 0 |
| Aplicação de inventário no dono | 1 | 1 |
| Tempo de processamento da solicitação no servidor | 309 µs | 215 µs |
| Resposta observada pelo dono | 17 ms | 18 ms |
| FPS médio após a solicitação | 60,07 | 60,09 |
| Frame time P95 após a solicitação | 17,06 ms | 17,06 ms |
| Maior frame após a solicitação | 17,37 ms | 17,51 ms |
| Troca do mesh da arma / novos nós pela reposição | Nenhuma | Nenhuma |

**A travada relatada não foi reproduzida nesta bancada.** A alteração remove trabalho redundante comprovado, mas os números não demonstram um aumento material de FPS nem provam que todo travamento possível foi eliminado. São janelas curtas em um computador, sem combate simultâneo ou perda de rede simulada.

Evidências reproduzíveis: `tests/run_supply_profile.py before|after`, `tests/supply-profile-before-server.json`, `tests/supply-profile-after-server.json` e relatórios por cliente. Cada rodada aprovou três verificações de servidor e uma do cliente renderizado, com os três participantes conectados. A guia física da granada não foi alterada nesta revisão de HUD.
