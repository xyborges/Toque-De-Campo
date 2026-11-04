# 1.10.6 — Estabilidade do Guerra (build 81)

30/10/2026. Base 1.10.5/build 79. Guerra protocolo 33 preservado. **Publicado e verificado na VM Ubuntu**: `VERIFIED_READY build=81` e `DEPLOYED build=81 version=1.10.6`, com os quatro serviços ativos e o download real instalado pelo launcher.

## Entregas

- **Escrita do status periódico fora da thread de física.** O JSON de status do servidor de Guerra era gravado a cada 2 s dentro do passo de física. Passou a usar uma thread de escrita com uma única atualização pendente, cópia imutável dos dados e troca atômica do arquivo; o encerramento aguarda a última gravação. Com 28 bots, a média do callback nos passos que publicam status caiu de **3.706 ms para 0.484 ms** e o pior passo de **6.345 ms para 0.809 ms** — medidas do callback, não promessa de FPS.
- **Diagnóstico `war_frame_pacing`.** Janelas de 10 s com tempos reais entre quadros, passos de física por quadro, correções de posição, intervalos de estado do veículo, população, RTT, repetição de câmera e dados de vegetação. Memória fixa, sem posições, credenciais ou voz.
- Todas as correções de entrada, terreno, câmera, bots, placar, áudio (volume/VOIP 55 m), ópticas, transportes, motos e otimizações da 1.10.4/1.10.5 permanecem como estavam.

## Testes na fonte congelada

Baterias executadas antes do export, no mesmo commit empacotado: ópticas e transportes 55 verificações, ordenação de estado do War 12, escritor de status 8 (cópia imutável, armazenamento lento simulado, fila limitada, último estado salvo, escrita atômica, reinício), frame pacing 10 (pausas sintéticas periódicas, memória limitada, persistência no diagnóstico real).

## Publicação

- Pacote `releases/game-81-07c778021c4d.zip`, 221.555.784 bytes, SHA-256 `07c778021c4d7d74f14df09d6c437c4de6f30eee472378a654cace9a70a5ba98`; três arquivos no manifesto (`ToqueDeCampo.exe` 81.506.816, `ToqueDeCampo.pck` 189.995.052, `libgodotopus...dll` 786.432).
- Servidor Linux: PCK 189.841.132 bytes e `ToqueDeCampo.x86_64` 73.519.416, com `server_status_writer` e `frame_pacing` presentes e sem testes, chaves privadas ou cenas de QA no pacote.
- `current` → `/opt/toque-de-campo/releases/build-81`; `toque-naval` (3012), `toque-pvp` (3010), `toque-war` (3014) e `toque-br` (3016) ativos desde 30/10 13:11 UTC, com 0 reinícios e as quatro portas UDP abertas. Manifesto público publicado por último, como o helper exige.
- Launcher real: primeira execução instalou 1.10.6 ("Atualização instalada"), a segunda não baixou nada ("Nenhum download necessário") e `installed.json` é idêntico ao manifesto assinado. Download do EXE idêntico ao preparado; HTTP recusado na API de contas (426) e caminhos privados bloqueados (403/404).
- Página de download anuncia 1.10.6, "Estabilidade do Guerra" e as notas sem erro de codificação.

## Por que build 81 e não 80

O build 80 foi preparado e assinado, e o helper aprovou tudo (`VERIFIED_READY build=80`). A ativação parou em `Existing build directory differs from the authenticated release`: já existia em `/opt/toque-de-campo/releases/build-80` o resultado de uma tentativa anterior — PCK de 189.839.676 bytes, de um export das 09:23 — que não chegou a trocar o `current` nem o manifesto. O helper só aceita um diretório existente se ele for byte a byte igual ao release autenticado. A saída foi repetir o prepare pela via oficial, que renumera automaticamente para 81, sem alterar uma linha de código. Saltos de build já ocorreram antes (28, 35, 41, 43, 64, 69, 73, 76). **O diretório residual do build 80 foi removido depois da publicação, com root, liberando 252 MB; `current` permaneceu em build 81 e os quatro serviços ativos.**

## Limites

- A pausa periódica de ~1 s relatada **não** é declarada eliminada; o que se comprova é a retirada da escrita síncrona do callback periódico. A comparação de quadros da investigação é observacional.
- Benchmark térmico e partida longa com 28 bots não foram refeitos nesta publicação; não há número de FPS a anunciar.
- O trabalho de mapas (identidade/admissão de conteúdo, escolha de spawn por exposição, grass e navegação preparados) **não** entra neste build; ele está no checkout principal e já valida nos cinco mapas. Detalhes em [MANUTENCAO-1.10.6.md](MANUTENCAO-1.10.6.md).
- O contador local foi alinhado ao build 81, então o próximo prepare gera 82 e não repete o resíduo do build 80; o publicador agora recusa isso antes de enviar qualquer byte.

## Evidências

Em `work/release1106-microstutter/project/work/`: `release1106-prepare81.log`, `release1106-deploy81.log`, `release1106-verify.log` (13 verificações aprovadas), `release81-launcher-check.json`, `installed81-boot.json`, `release1106-deploy.log` (falha do build 80, preservada). Medições e reprodutibilidade da investigação em `work/microstutter1105/investigacao.md` e `comparison.json`. Fonte congelada do release em `work/release1106-microstutter/project`.
