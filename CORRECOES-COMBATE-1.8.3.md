# Correções de combate — 1.8.3

## Causas reproduzidas

1. Cada confirmação de munição executava a limpeza de recarga mesmo quando não havia recarga. Essa limpeza definia o gatilho como solto: a FAL disparava uma vez por clique apesar de estar configurada como automática.
2. Selecionar uma granada ativava a previsão de lançamento. Voltar à arma, inclusive à mesma FAL, não desativava sempre essa flag. O método de disparo recusava a arma devido à preparação que já havia terminado. Isso afeta Glock e outras armas também no Offline.
3. A replicação do lançamento e os dois caminhos de respawn não limpavam todos os estados de preparação/animação da granada.

## Alterações

- `scripts/player.gd`: uma confirmação de inventário ocioso preserva o gatilho; uma recarga real continua interrompendo o disparo. Voltar à arma limpa a previsão de granada imediatamente, com uma verificação adicional na atualização dos controles.
- `scripts/grenades.gd`: a passagem de granada na mão para granada lançada limpa a preparação pendente e a previsão. A animação de lançamento continua bloqueando tiros até terminar.
- `scripts/main.gd`: seleção remota desativada limpa a previsão quando não há granada armada, e o respawn limpa os estados restantes nos dois lados.

Não foram alterados dano, cadência, limite de munição ou validação de disparos no servidor.

## Testes

- Antes da correção, a regressão reproduziu sete falhas nos estados do gatilho/granada.
- Depois da correção: 15 verificações de estado passaram, incluindo Glock numa vida nova Offline, Glock após cancelar granada, FAL após cancelamento/lançamento, bloqueio durante granada armada, recarga e limpeza de respawn.
- Servidor DTLS local com dois clientes nativos, um gráfico: 21 verificações passaram. FAL disparou 8 tiros na primeira pressão mantida, 6 depois da granada, 5 enquanto o adversário estava morto e rajadas de 6 tiros nos dois clientes após o respawn. Soltar o botão interrompeu todas as rajadas. A morte foi aplicada pelo caminho autoritativo de dano da FAL para exercitar o ciclo completo; não dependeu de mirar manualmente um projétil.
- Duas contas reais no servidor central: 8 tiros numa pressão mantida, Glock após cancelar granada e 5 tiros mantidos depois da explosão. Os dois clientes receberam 13 disparos da FAL, sem falhas no relatório.
- O pacote Windows exportado continuou abrindo com o runtime protegido; proteção de diretório e recusa de substituição externa permaneceram válidas.
- Som adicional solicitado durante a atualização: `sound_005.wav` substitui o som da FAL como `audio/fal-005.wav` no catálogo compartilhado. A gravação original mono, de 0,4522 segundos, foi preservada. O teste gráfico capturou a mixagem real de 30 disparos com 8 verificações aprovadas, 30 eventos iniciados, nenhum som em loop e pico de 0,735 (abaixo de 1,0). O relatório está em `tests/fal183-audio-results.json`.

Os testes locais de rede registraram dois descartes DTLS de datagramas de sessões já fechadas durante a saída. Foram contabilizados separadamente e preservados nos logs; não houve falha nas verificações do jogo.

## Evidências

- `work/combat183-before.log`
- `work/combat183-after.log`
- `work/combat183-network.log`
- `tests/combat183-network-server.json`
- `tests/combat183-network-alpha.json`
- `tests/combat183-network-bravo.json`
- `work/combat183-central-pvp.log`
- `work/combat183-package.log`

Publicação original das correções: build 52. A revisão final com o novo áudio foi publicada como **1.8.3, build 53**. O exportador confirmou a inclusão do sample e do remapeamento de `fal-005.wav` no pacote. Publicação e conferência final de download: `work/combat183-deploy-audio.log` e `work/combat183-distribution-audio.log`.
