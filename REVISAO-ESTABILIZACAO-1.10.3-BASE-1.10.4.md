# Revisão e estabilização da 1.10.3 — compatibilizada com a 1.10.4

29/10/2026. Referência atual: **1.10.4/build 78, Guerra protocolo 33**. Este documento fecha o checklist solicitado para a revisão da 1.10.3 e registra o que permanece limitado. Não substitui nem altera [ATUALIZACAO-1.10.4.md](ATUALIZACAO-1.10.4.md).

As nove fontes principais conferidas correspondem aos hashes registrados para o build 78. Os nove artefatos locais preparados correspondem ao manifesto assinado. O build 76 local da etapa anterior foi superado. Nesta retomada não houve alteração de código de jogo, novo pacote, publicação ou reinicialização de serviço.

## Checklist do plano

| Item solicitado | Estado e evidência |
|---|---|
| Lotes de até dois personagens, confirmação individual | Implementado. Servidor e dois clientes reais validaram o limite e a continuação dos quadros durante espera deliberada. |
| Estado explícito de sincronização e implantação bloqueada | Implementado. Identidade não libera o jogador durante a carga; a conclusão exige o identificador da transferência atual. Implantação antecipada e durante falha foi rejeitada. |
| Confirmações antigas, inválidas ou duplicadas | Rejeitadas. 27 verificações do estado de transferência passaram; não são contadas como 27 partidas de rede. |
| Entrada, saída e alterações durante carregamento | Alterações agrupadas por personagem; apenas o estado atual é enviado ao drenar a fila. Segundo humano entrou durante a criação dos bots. 15 verificações de autoridade e dois clientes passaram na validação da 1.10.4. |
| Prazos de 30 s sem progresso e 120 s totais | Implementados. 17 verificações com dois clientes cobrem saída na carga, expiração dos dois prazos, preservação do outro cliente e reconexão. O fixture antecipa o relógio para exercitar o caminho real de expiração. |
| Drones na entrada tardia | Recepção incremental separada da atualização completa dos veículos. 15 verificações de rede com dois clientes cobrem múltiplos lotes, remoção e criação durante a carga e conjunto final idêntico. Quatro verificações adicionais conferem que os lotes não apagam drones anteriores. |
| Rotas preparadas antes da primeira implantação | Implementado. O acesso à preparação no nascimento passou de 350,359 ms na referência antiga para 0,012 ms após preparar durante a carga. Esse custo foi deslocado, não eliminado. |
| 28 bots online, preenchimento gradual e equilíbrio | Implementado. 28 bots implantados, 14 por equipe, movimento e disparos reais; nenhuma falha de implantação. Autoridade permanece no servidor. |
| Bots offline locais | Confirmado no mapa completo: 18 participantes, 9 contra 9, movimento local, nenhuma chamada a serviços de conta ou transporte de rede. Sete verificações passaram. |
| Placar completo | Limite anterior de 12 corrigido. Dez verificações de capacidade/validade; placar de 30 participantes recebido nos dois clientes. |
| Tempos e população nos registros | Construção do mundo, rotas, criação de bots, preparação/espera dos lotes, população por equipe, RTT e monitores de processamento disponíveis. Tempos inclusivos não devem ser somados como parcelas independentes. |
| Microfone: diagnóstico por tentativa e por canal | Implementado. Dispositivo, taxa, amostras, níveis esquerdo/direito/mono e contadores; nenhuma gravação. 14 verificações de captura passaram. |
| Exclusão entre teste/PTT e troca/perda do dispositivo | Implementado. Dono único da captura e reinicialização limitada; 13 verificações de ciclo do codec e 17 de rede, com servidor e quatro clientes, passaram. |
| Fala real no microfone | Teste físico abriu a entrada, mas recebeu silêncio. O usuário esclareceu que o microfone estava desativado e considerou a origem resolvida. Não há teste de inteligibilidade com fala, nem se atribui esse silêncio ao software. |
| BR: terreno, limites, nascimento e moto | Passaram 14 verificações de terreno/câmera, nove com autoridade e dois clientes no mapa completo, 30 de física da moto e 17 de rede da moto. Os clientes nasceram apoiados e atravessaram o antigo limite central. |
| Comparação gráfica da entrada | A/B/A/B registrado na etapa da 1.10.3, mesma semente/câmera e renderização real 1920×1080. Piores quadros de 218–262 ms para 79–112 ms; 1% low melhor nas duas comparações, média variável e conclusão da sincronização cerca de meio segundo mais demorada. Esses resultados se referem à entrada e àquela base; não são uma promessa de FPS atual em combate. |
| Pacote concreto e validado | O pacote atual é o build 78. 13 verificações de instalação assinada, boot normal do EXE protegido e DLL de voz carregada. 111 verificações do pacote Linux. A publicação anterior foi confirmada em log e manifesto HTTPS; nenhuma nova publicação foi feita nesta retomada. |

## Preservação da 1.10.4

Continuam presentes as sequências monotônicas por personagem/vida, lotes de bots não ordenados com descarte de estados antigos no receptor e estados da operação validados por geração/relógio. As otimizações de CPU de corpo, braços, recarga, apoio dos pés, terreno e hitboxes foram preservadas.

Repeti após a conciliação 12 verificações de ordenação e 27 da transferência de entrada: todas passaram. O documento da 1.10.4 registra também 17 verificações de transição de operação e 15 de rede sobre essa versão. Não houve retorno ao protocolo 32 ou ao envio ordenado global de bots.

## Investigação complementar dos picos restantes

Uma sessão autenticada de 60 segundos, cliente headless, mapa completo, um humano e 28 bots, reproduziu **1.800,826 ms** entre estados aceitos da operação. O maior intervalo entre quadros do cliente foi **49,488 ms**, com média de 16,717 ms. Portanto, nessa amostra a pausa de recepção não se explica apenas por um quadro gráfico longo.

Durante a mesma sessão, a coleta no servidor observou somente horários, direção e tamanho dos datagramas UDP da porta do Guerra; nenhum conteúdo ou endereço IP foi salvo. Nas janelas próximas aos segundos 37–38, a saída observada caiu de cerca de 216–223 datagramas por segundo para 21–39, enquanto a entrada permaneceu em 22–26. A amostragem da thread principal continuou a cada aproximadamente 50 ms, com cerca de 76–83% de um núcleo nessas duas janelas. A captura informou 106 pacotes perdidos pelo próprio coletor em 17.036 capturados; isso não é medição de descarte no socket do jogo. Datagrama criptografado também não identifica qual RPC foi enviado.

A observação localiza melhor o sintoma, mas não demonstra a causa exata. O ENet pode descartar atualizações não confiáveis pelo controle adaptativo de envio. Esse mecanismo consta da [documentação oficial](https://docs.godotengine.org/en/stable/classes/class_enetpacketpeer.html#class-enetpacketpeer-method-throttle-configure) e do [código usado pela 4.7.2](https://github.com/godotengine/godot/blob/4.7.2-stable/thirdparty/enet/peer.c). O valor observado no peer do cliente refere-se ao envio daquele peer; não deve ser apresentado como o estado interno do envio da autoridade.

Testei a hipótese em ENet/DTLS isolado, com um proxy local que muda temporariamente o atraso sem descartar pacotes deliberadamente. Diminuir a janela de adaptação de 5.000 para 1.000 ms não melhorou consistentemente os maiores intervalos. Na comparação com conexão aquecida, o intervalo máximo ficou em 500,005 ms e 508,342 ms, apesar de maior entrega total na variante curta. O ajuste foi **descartado**. Nenhum controle de congestionamento foi desativado e nenhuma configuração da produção foi mudada.

**Limite de conclusão:** os itens funcionais do plano foram implementados e verificados, com pacote validado. Permanecem picos ocasionais de recepção e variação de FPS já explicitados na 1.10.4. Não foi comprovada a eliminação de todo congelamento online, capacidade para 12 humanos em combate intenso ou um ganho gráfico estável. A próxima correção de transporte exige medir a tentativa de envio e o throttle da autoridade durante o pico; não será presumida a partir do RTT do cliente.

## Evidências

- `work/stabilization1104-review.json`: estado do checklist e preservação das fontes.
- `work/reconcile1104.json`: correspondência de fontes e artefatos; nenhuma alteração de runtime.
- `work/war-state-network.log`, `work/join-transfer1103-validation.json`, `work/join1103-faults-network.json`, `work/join1103-drone-network-network.json`.
- `work/offline-authority1103.json`, `work/voice-capture1103-final-review.json`, `work/hotfix1103-validation.json`.
- `work/war-state-signed-install78.json`, `work/war-state-pack78.json`, `work/war-state-public-download78.json`.
- `work/war-gap-investigation1104.json`: nova observação ao vivo, limites da captura e experimento não adotado.
