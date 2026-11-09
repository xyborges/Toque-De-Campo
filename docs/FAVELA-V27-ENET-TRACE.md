# Favela V27 - Telemetria de movimento, colisao e camera

Data: 09/11/2026. Branch: `ia/favela-v27-roof-diagnostic-20261109`. A `main` e a build 97 permanecem inalteradas.

## Implementacao
- Gravador em `modes/war/scripts/roof_motion_trace.gd`.
- Instrumentacao de `WarPlayer._physics_process` apos o movimento real do `GamePlayer`, opt-in somente com `--v27-roof-trace`, `is_local` e modo Favela. Sem efeito na jogabilidade quando a flag esta ausente.
- JSONL em `user://favela-v27-roof-<timestamp>.jsonl`; caminho absoluto e mostrado no console com `V27_ROOF_TRACE_FILE`. Limite de 7200 quadros (120s a 60Hz).
- Campos por quadro: tick e tempo, posicao e delta do personagem, velocidade, suporte e normal do chao, contatos (normal, ponto, nome do colisor, deslocamento), ultimo tick de step assistido, direcao de entrada, posicao e delta da camera, parent da camera, comprimento de SpringArm, camera_close.
- Arquivo criado somente em cliente executando a branch/test build com a flag; nao esta disponivel na build publica anterior.

## Testes
- Importacao Godot 4.7.2: exit 0.
- `tests/favela_roof_v27_warplayer.gd`: PASS com o novo codigo integrado; 8 rotas fisicas, sem recuos e bloqueios.
- `tests/favela_roof_v27_trace_writer_qa.gd`: 30 amostras gravadas em JSONL, validacao dos campos PASS, exit 0 e nenhum erro na segunda rodada. Primeira execucao encontrou falta de InputMap na fixture de teste; corrigido com guarda para acao inexistente.
- `tests/favela_roof_v27_network_trace.gd`: instrumento de teste que tenta usar host + 2 clientes Godot/ENet, WarPlayer real, pressionar movimento por Input e coletar colisao e camera de 4 telhados.
- Duas tentativas usando `tests/run_favela_network.py`: NAO CONCLUIDAS. Na primeira, servidor terminou com 0 jogadores e os clientes aguardaram ingresso (90s). Na segunda, mesmo apos 220s, servidor com 0 jogadores, clientes sem `join_ready`, erro DTLS mbedTLS -30464 / -0x7700. A porta UDP QA 39569 abriu; certificado de teste localhost valido de 25/10 a 25/11/2026. Nao houve dados de percurso multiplayer: nao classificar este teste como PASS de gameplay nem como reproduzido.
- Evidencia de console ignorada pelo Git: `work/v27-enet-console.log`, `work/v27-enet-second.log`, `work/v27-trace-writer-r2.log`, `work/v27-post-trace-warplayer.log`.

## Proximo gate
1. Investigar o ingresso da fixture no ENet/DTLS sem usar a rede de producao; verificar prebuild `join_game`, autenticação de teste, handshake e criterios de pronto.
2. Rodar o fixture completo com clientes conectados; obter JSONL por local FPP/TPP e normal de colisao em lajes com e sem modulos. Comparar tremor de personagem com correcao/spring arm de camera e erro de reconciliacao.
3. Somente entao propor uma alteracao fisica real e submeter novamente a QA + multiplayer. Nenhuma alteracao em colisao ou camera foi aplicada nesta fase.
