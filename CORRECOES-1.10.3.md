# 1.10.3 — Estabilização do BR, Guerra e captura de voz

**29/10/2026 — publicada como 1.10.3/build 77.** A ativação na VM foi confirmada pelo publicador com verificação de serviços e rollback disponível. Esta entrega também inclui a [correção de desempenho do Guerra](CORRECAO-LAG-GUERRA-2026-10-29.md).

## Causa reproduzida

O BR prepara seu mundo antes de abrir a conexão. Em seguida, a rotina herdada de entrada atribuía `map_kind="desert"`. Ao conectar, o BR reconhecia que o Afegão já estava construído e retornava antes de restaurar `map_kind="afghan"`.

O visual e as colisões eram do Afegão, mas o personagem usava o limite de ±149 m e a recuperação de terreno do pequeno mapa do Deserto. No teste anterior à correção, um nascimento válido em **(-307,037; 45,435; 85,560)** terminou em **(-149; 34,521; 85,560)**, sem apoio no chão. Isso reproduz a barreira central e a mudança indevida de altura. O caminho offline não passava por essa sequência de conexão.

## Correções

- A rotina de rede consulta a identidade do mapa definida pelo modo. O BR conserva `afghan` tanto na hospedagem como na conexão.
- A reentrada no mundo restaura a identidade antes de reaproveitar o mapa preparado.
- A câmera da moto passa a controlar também os quadros de mouse e as atualizações da apresentação, impedindo a câmera a pé de reaparecer entre ticks. O veículo e o próprio personagem ficam excluídos da consulta de obstrução existente. Desembarcar restaura FPP/TPP conforme a seleção anterior.
- Registros de nascimento no cliente e na autoridade incluem mapa, posição e altura de terreno para investigar novas ocorrências.
- BR, roteador e pool usam protocolo 9; o pacote anterior não deve entrar numa sala corrigida.

## Verificação

- Regressão antes/depois no mapa completo e na câmera: **14 verificações passaram após a correção**. O teste anterior falhava em oito verificações. No ponto reproduzido, o personagem terminou em **(-307,037; 45,142; 85,560)**, apoiado no solo de altura 45,135.
- **144 movimentos de mouse**, entre quadros de física, com ambas as perspectivas a pé selecionadas: zero aparições da cópia FPP, zero saltos para a distância da câmera a pé e orientação do piloto preservada.
- Autoridade e **dois clientes independentes**, todos no Afegão completo, com 28 bots e ENet/DTLS: **nove verificações passaram**. Nascimentos diferentes, incluindo um a 129,5 m de altitude, ficaram apoiados na colisão real. Um cliente caminhou de X=145 até X=154,383; a autoridade aceitou a posição e o personagem permaneceu no chão. Não é um teste contra a produção e não mede capacidade/FPS da VM.
- Moto em Compatibility/GTX 1650: **30 verificações** de condução, colisões, saída, restauração da câmera e rejeição de comandos antigos.
- Moto com autoridade e dois clientes DTLS: **17 verificações**, incluindo condução, mudança de moto, morte e desconexão.

O cenário completo emite o aviso nativo mbedTLS -30464/-0x7700 ao encerrar conexões, já observado antes da correção. Não houve falha nas asserções funcionais ou erro de script nessa execução. A investigação não afirma que toda colisão do mapa foi varrida; ela reproduz e remove a aplicação indevida dos limites e do terreno de outro modo.

Evidências: `work/hotfix1103-validation.json`, `work/br-terrain-camera-regression.json`, `work/br-fullmap-online.json`, `work/br-motorbikes-validation.json` e `work/br-motorbikes-network.json`.


## Guerra e sincronização

O placar limitava a recepção a 12 linhas. A correção preserva até 128 participantes e foi verificada com 30, 40 e 128 registros, duplicatas e entradas inválidas. Isso explica uma possível impressão de apenas uma equipe preenchida; não prova que essa era toda a causa da sessão relatada.

A autoridade prepara as rotas enquanto carrega o mundo. A execução antiga media 350,359 ms na primeira implantação; após preparar antes, o acesso na primeira implantação mediu 0,012 ms. O custo foi deslocado, não eliminado: o mundo levou 31,284 s nessa execução. Criações individuais de bots mediram 11,9–42,1 ms no pequeno probe, e continuam graduais e alternadas entre equipes.

Cada entrada possui transferência própria, com lotes de até dois personagens ou drones, confirmação após oportunidade de renderização, limite de 30 s sem progresso e 120 s totais. Identidades, inventário, morte, entrada e saída durante a carga agrupam alterações por personagem. A implantação permanece bloqueada até a conclusão ou desconexão; confirmações antigas, inválidas e duplicadas não liberam o jogador. A sequência dos movimentos dos clientes já em jogo é preservada. Drones usam recepção incremental própria para que um lote não apague o anterior.

Novos diagnósticos registram tempo de construção do mundo, preparação de rotas, criação de bots, preparação/espera dos lotes, população por equipe, RTT e duração dos passos do script Guerra/monitor da engine. O tempo do script não inclui automaticamente todo processamento dos filhos; não deve ser somado aos monitores como se fossem custos independentes. Não foi atribuída culpa ao DTLS.

- Servidor e dois clientes DTLS no mapa completo, com segundo cliente durante o preenchimento: 15 verificações aprovadas. 28 bots implantados, 14 por equipe, placar de 30 participantes nos dois clientes, movimento e combate reais, nenhum erro de implantação. O cliente retido recebeu somente dois personagens remotos, ignorou confirmações inválidas e não implantou antecipadamente.
- Estados de transferência: 27 verificações aprovadas.
- Saída durante entrada, prazos de 30/120 s e reconexão: 17 verificações aprovadas, com dois clientes DTLS. Os prazos foram antecipados pelo fixture para testar o caminho real de expiração; não é uma simulação de perda de rede.
- Recepção incremental de múltiplos drones e snapshot posterior: quatro verificações aprovadas.
- Guerra offline no mundo real: sete verificações aprovadas. 18 participantes locais, 9 contra 9, movimentação dos bots e nenhuma chamada aos serviços de conta/servidor.

## Medição gráfica A/B/A/B

Compatibility, GTX 1650, renderização real 1920 × 1080 em janela física 1280 × 720 para controlar o escalonamento do Windows; mesma câmera e semente 8377. Três processos locais, 28 bots já criados e parados. Janela de quatro segundos desde o início da sincronização. A referência do fixture envia dois personagens por quadro do servidor, sem esperar confirmação; B usa o comportamento atual. Mede a fluidez da entrada, não FPS de uma partida em combate.

| Execução | FPS médio | 1% low | Pior quadro | Sincronização |
|---|---:|---:|---:|---:|
| A1 | 49,05 | 4,47 | 261,60 ms | 520 ms |
| B1 | 45,32 | 11,29 | 111,71 ms | 1.150 ms |
| A2 | 53,31 | 6,27 | 217,57 ms | 414 ms |
| B2 | 56,16 | 15,76 | 78,63 ms | 866 ms |

B melhora os piores quadros e o 1% low nas duas comparações; a média oscila. A carga leva aproximadamente meio segundo adicional para repartir o trabalho. Ainda existem quadros perceptíveis de 79–112 ms: não afirmamos ausência completa de travadas. A construção procedural anterior à conexão mediu 24,6–34,8 s. GPU: 56–75 °C, clocks registrados antes/depois em `work/join1103-render-abab.json`; CPU informou 2.688 MHz, temperatura indisponível. Esses sensores pontuais não excluem toda variação térmica durante a execução.

## Microfone e ZIP do usuário

O ZIP tinha 65 eventos legíveis, com testes de microfone abertos mas sem sinal e um erro WASAPI de saída. Não continha tempos por quadro ou população suficientes para explicar o travamento do Guerra. Também inclui sessões de QA, que não são prova de que o executável instalado do usuário havia sido atualizado.

A captura agora tem proprietário exclusivo entre teste e transmissão, encerramento/reabertura ao trocar ou perder dispositivo, contadores por tentativa e níveis separados de entrada esquerda/direita/mono. A conversão evita cancelar canais em oposição de polaridade. Nenhuma gravação é armazenada.

Passaram 14 verificações de captura, 13 do ciclo do codec e 17 de rede com servidor e quatro clientes (todos terminaram com código zero). O teste físico recebeu silêncio nos dois canais. Depois o usuário informou que o microfone estava desativado e considerou a origem do problema resolvida. Não há validação de inteligibilidade com fala; a captura zerada anterior não comprova defeito de software.

A preparação local desta etapa terminou no build 76 e foi superada pelos builds 77 e 78. A publicação e a instalação assinada do build 78 foram realizadas na etapa documentada em `ATUALIZACAO-1.10.4.md`; esta retomada não publicou nem reiniciou serviços.
