# Congelamentos de estado online

## O que foi reproduzido

Na sala oficial Favela, build 92, um cliente gráfico conectado ao servidor remoto reproduziu uma lacuna de 242 ms nas atualizações da moto em movimento, enquanto os quadros continuaram com máximo de 36,5 ms e a câmera girou. O relógio ficou sem atualização por 656 ms na mesma ocorrência. Outra sessão a pé teve lacuna de 726 ms somente no relógio, enquanto poses continuavam chegando.

Em outra janela de 460 ms sem lotes de bots, a captura de saída UDP do servidor contou nove datagramas contra mediana de 69 em janelas próximas. A simulação não mostrou sobrecarga contínua. A captura é criptografada, observa horários/tamanhos e não identifica RPCs nem a causa exata da redução de envios. Não foi demonstrado que a renderização de múltiplos objetos seja a causa desse congelamento.

## Correções implementadas

- Retentar pedidos de recuperação sem resposta após 1 s, mantendo apenas um pedido atual pendente e rejeitando respostas de séries antigas.
- Verificar falta de estado a cada 50 ms. Personagens vivos e implantados ficam elegíveis a recuperação após 250 ms sem pose; relógio após 450 ms.
- Incluir o veículo ocupado ou drone controlado na recuperação confiável. Movimento fica elegível após 150 ms; veículos parados respeitam o heartbeat normal de 500 ms e só pedem reparo após 650 ms.
- Preservar token de admissão, exclusão da carga inicial, sequência do pedido, vida, geração da operação, geração do veículo e revisão dos assentos.
- Acrescentar sequência por drone. Respostas confiáveis e atualizações normais não podem rebobinar estado nem ressuscitar drones removidos.
- Preservar o cache de broadcast ao responder individualmente, para não suprimir o estado final ou adiar o heartbeat dos demais observadores.
- Pedidos limitados a 2/s a pé e 4/s ocupado, com capacidade de dois tokens para tolerar chegadas comprimidas por jitter. O cliente mantém intervalos mínimos de 500/250 ms. O limite anterior de um token rejeita chegadas legítimas ligeiramente abaixo desses intervalos.
- Guerra protocolo 37 exige a atualização conjunta de cliente e servidor. Clientes antigos não possuem o descarte de respostas atrasadas de drones.

## Validação

`tests/war_state_recovery_validation.gd` passou 41 verificações de admissão, ordenação, vida, ocupação, passageiro, morte, remoção, heartbeat, observadores e quota.

As regressões existentes passaram com relatórios temporários, sem regravar resultados versionados. Ordenação do mundo 12, entrada de drones 4, diagnóstico/ordenação de poses 19, cadência 36 e métricas de quadros 11 verificações.

O runner `tests/run_war_state_recovery_network.py` inicia servidor e cliente separados com ENet/DTLS, Favela completa e 28 bots de produção. O deslocamento usa uma pista elevada de QA com colisão. A falha controlada suprime o envio de snapshots selecionados; não injeta perda em UDP nem simula toda a Internet. A renderização, os controles e os pacotes confiáveis continuam ativos.

Controle sem recuperação veicular registrou 665–701 ms sem estado durante seis interrupções de 650 ms, sem qualquer resposta de reparo. A câmera continuou girando. Com a correção final, a repetição gráfica passou 52 verificações em dez cenários. Primeira recuperação em 137–211 ms para moto/drone; maior silêncio nessas seis janelas em 217–297 ms. Suprimindo também a primeira resposta legítima, a recuperação voltou em 1.248 ms.

A pé, três interrupções de 1,2 s separaram mundo inteiro (poses e relógio), somente relógio e somente poses. A primeira recuperação ocorreu em 293, 480 e 251 ms, respectivamente. O maior intervalo subsequente foi 557 ms, compatível com a cadência limitada de fallback. Não se trata de movimento contínuo durante perda prolongada. Todos os cenários mantiveram quadros e câmera em andamento.

A rodada gráfica anterior encontrou um caso com apenas uma resposta e 454 ms de silêncio no drone. O teste não foi relaxado. Após acrescentar a margem de dois tokens, a repetição passou e registrou 37 pedidos aceitos, sem recusa de quota. Um par chegou ao servidor com 244,7 ms de intervalo; o limite anterior de um token recusaria esse segundo pedido.

## Evidências locais

- Partida oficial de moto `C:/Users/Joao Borges/AppData/Local/Temp/campo-favela-moto-inlj7b9c/client.json`.
- Partida oficial a pé e captura da autoridade `C:/Users/Joao Borges/AppData/Local/Temp/campo-favela-online-5nvj1zw8/`.
- Controle sem reparo veicular `C:/Users/Joao Borges/AppData/Local/Temp/campo-recovery-network-_c1_o1fi/`.
- Rodada gráfica final com cenários a pé `C:/Users/Joao Borges/AppData/Local/Temp/campo-recovery-network-ndz5lsob/`.
- Regressões `C:/Users/Joao Borges/AppData/Local/Temp/campo-recovery-regression-gs8l_a59/`.
- Repetição final na versão 1.13.6/protocolo 37, 52 verificações PASS `C:/Users/Joao Borges/AppData/Local/Temp/campo-recovery-network-on3o5vi9/`.

Esses caminhos são evidência local temporária. O runner e os testes versionados permitem repetir a validação.

## Limites e entrega

O problema não é exclusivo da moto e do drone. Falta de atualizações da autoridade pode parar o estado remoto em qualquer atividade. As correções abrangem personagens e relógio em toda a partida Guerra, além do veículo ocupado. Veículos remotos não ocupados pelo observador continuam dependendo de seus snapshots e heartbeat normais.

Esta mudança corrige lacunas da recuperação e reduz a duração do estado parado. Não identifica nem elimina a causa das interrupções espontâneas de envio, não prevê movimento durante uma interrupção completa da rede e não corrige quedas de FPS. O controle de congestionamento permanece ativo. Não foi validada capacidade com 12 humanos.

O teste final da correção usa conexão real cliente/servidor no mesmo PC. As ocorrências naturais foram medidas antes na sala oficial remota. Publicação e validação posterior no servidor oficial são etapas distintas; não apresentar a validação local como correção já instalada em produção.
