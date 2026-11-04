# Toque de Campo 1.6.1 — tripulações, corrida e retorno dos blindados

**Publicada e validada em 24/10/2026 · build 27 · Ubuntu.**

O log `work/release161-publication.log` confirma `DEPLOYED build=27 version=1.6.1`. O build assinado está disponível em **[http://192.168.101.24/](http://192.168.101.24/)**. A tripulação foi validada no servidor de produção com três contas reais, e o launcher instalou a 1.6.1; na segunda abertura não baixou novamente. Os resultados desta versão estão em `work/release161-central-passengers.log`, `work/release161-distribution.log` e `tests/ubuntu-distribution-results.json`.

## Tripulações no Modo Guerra

| Blindado | Operador | Passageiros | Capacidade total |
| --- | ---: | ---: | ---: |
| Guarani | 1 | 5 | 6 |
| BMP-2 | 1 | 5 | 6 |
| Abrams | 1 | 1 | 2 |
| T-90 | 1 | 1 | 2 |

**F** solicita entrada no primeiro assento livre ou saída do veículo. A autoridade valida equipe, distância, capacidade e reserva do assento. O primeiro ocupante é o operador; os demais recebem assentos de passageiro. A interface informa função e ocupação.

Somente o operador dirige, aponta a torre, dispara, recarrega o armamento montado e utiliza óptica/térmica. Passageiros observam por câmera externa independente: mover o mouse não muda o alvo da torre. Armas pessoais, granadas, recargas e equipamentos de classe ficam bloqueados enquanto embarcados; o servidor também recusa tentativas de comandar essas ações.

### Saída e troca de operador

A saída considera terreno, paredes, outros veículos, personagens e espaço físico para o corpo. Sem uma posição livre, o jogador permanece embarcado e recebe o aviso correspondente.

Quando o operador sai, morre ou desconecta e o blindado continua íntegro, o passageiro embarcado há mais tempo assume. Gatilhos e comandos da ocupação anterior são descartados. A troca não cria dois operadores nem reaproveita pacotes atrasados do motorista anterior.

### Destruição

A explosão mata o operador e os passageiros ainda embarcados, registrando cada morte e abate válido no placar. Não há saída antecipada para salvar ocupantes nem promoção de motorista durante a sequência de destruição. Assentos, comandos e recursos temporários são limpos pela autoridade.

## Reaparecimento após um minuto

Os quatro blindados de Guerra pertencem às bases das respectivas equipes. Depois da destruição, o servidor inicia uma contagem de **60 segundos** e replica o estado restante.

Ao completar o minuto, o mesmo veículo retorna à posição original na própria base, com integridade, carregador/reserva e armamento secundário restaurados. Volta sem ocupantes, movimento, gatilho, recarga ou estado anterior da torre. O cliente aplica o retorno diretamente na base, sem interpolar o blindado através do mapa desde o local da explosão.

A regra vale para Guerra online e treino offline. Não altera o tempo de reaparecimento dos navios no Naval.

## Corrida e passos

Melhorias da infantaria de Guerra em primeira e terceira pessoa:

- Segurar **Shift** durante o movimento amplia a passada e abaixa a arma suavemente.
- A animação não acrescenta balanço à câmera nem desloca sua transformação para simular corrida.
- Mira, disparo, recarga e granada preservam suas poses de combate.
- Personagens remotos e bots usam o movimento efetivo; interrupção dos snapshots não mantém uma passada indefinida.
- Passos dependem de deslocamento e contato com o chão. Não tocam parado, no ar, morto ou embarcado.
- Timbre e cadência variam conforme velocidade e regiões de superfície do mapa, como madeira, cascalho, concreto, terra e lama.
- O áudio reutiliza o pool espacial existente de **24 vozes**, com distância/volume e filtragem do sistema de Guerra. Não é criado um emissor permanente novo para cada passo.

## Controles rápidos

| Situação | Controle |
| --- | --- |
| Entrar ou solicitar saída | F |
| Correr na infantaria | Segurar Shift enquanto se move |
| FPP/TPP na infantaria | V |
| Operador: dirigir | WASD |
| Operador: apontar / disparar | Mouse / botão esquerdo |
| Operador: óptica / térmica | Botão direito / X |
| Operador: recarga / trocar arma montada | R / Q |
| Passageiro: observar | Mouse, somente câmera externa |
| Placar / menu e foco | Segurar TAB / ESC |

Guerra offline continua em **Jogar → Guerra → Treino offline · Bots**. Um humano e cinco aliados enfrentam seis adversários. Os bots ainda não pilotam blindados ou drones; as novas capacidades de tripulação não representam uma IA de transporte.

**Todos os clientes precisam atualizar:** o protocolo de assentos de Guerra mudou para a revisão 2. Cliente e servidor foram publicados juntos; não misturar versões anteriores nessa operação.

## Verificações confirmadas

| Bateria | Resultado confirmado | Evidência |
| --- | ---: | --- |
| Assentos dos quatro blindados, capacidade, autoridade, promoção, saída e destruição | 91/91 | `tests/war-vehicle-passengers-results.json` |
| Respawn de um minuto, base da equipe, munição e aplicação remota | 41/41 | `tests/war-vehicle-respawn-results.json` |
| Regressão dos sistemas de Guerra | 79/79 | `tests/war-systems-results.json` |
| Corrida FPP/TPP, poses, câmera, chão e áudio PCM | 34/34 | `tests/war-locomotion-results.json` |
| Locomoção por ENet real: servidor, emissor e observador | 18/18 | `tests/war-locomotion-network-{server,mover,observer}.json` |
| Passageiros em sessão ENet nativa | 24/24 | `tests/war-passengers-network-{server,operator,passenger,enemy}.json` |
| Regressão de rede de Guerra, três clientes e FAL após desconexão | 18/18 | `work/war-passenger-review-legacy-network-final.log` |
| Equipamentos da operação offline | 34/34 | `work/war-passenger-offline-equipment.log` |
| Entrada offline pelo pacote exportado da 1.6.1 | 4/4 | `work/war-offline-pack-161.log` |
| Ativação assinada da 1.6.1 no Ubuntu | Confirmada, build 27 | `work/release161-publication.log` |
| Tripulação contra o serviço central, três contas reais | 33/33 | `work/release161-central-passengers.log` |
| Download real, instalação 1.6.1, segunda abertura sem download, assets e inicialização normal | Aprovados, build 27 | `work/release161-distribution.log`, `tests/ubuntu-distribution-results.json` |

O teste de respawn usa os métodos reais de dano/autoridade, mas avança a contagem de forma determinística: verifica que 59,9 s não bastam e que o estado retorna após os 0,1 s restantes. Não representa espera de um minuto de relógio em cada cenário.

A bateria de locomoção nativa usa entrada normal em uma plataforma física reproduzível e captura PCM real do áudio. A bateria ENet transmite posições legais a cada 50 ms; depois suspende snapshots para verificar parada da animação e dos passos sem desconectar o transporte. São testes automatizados, não sessões com jogadores humanos.

O teste central utilizou três contas assinadas e a autoridade Ubuntu publicada, sem modo de contas de teste, token Service ou comandos privilegiados de teleporte no servidor. A aproximação usou posições legais a 5,8 m/s e comandos/RPCs existentes; arquivos locais só coordenaram as fases. Foram confirmados direção/disparo pelo operador, câmera independente do passageiro, recusa de comandos indevidos, promoção e saída segura.

## Desempenho e limites

Foi executado o mesmo roteiro de doze clientes ENet, um renderizando em 1080p numa GTX 1650 e todos os processos neste PC. Inclui blindados, drones, tiros, explosões e desconexão. Uma execução não representa doze máquinas independentes nem uma prova de 60 FPS estáveis.

| Configuração 1.6.1 | FPS médio | 1% low | Pior quadro (ms) | P95 (ms) |
| --- | ---: | ---: | ---: | ---: |
| Antes de reduzir trabalho de locomoção parado | 36,32 | 17,37 | 84,72 | 43,47 |
| Controle de diagnóstico: módulo desativado só no fixture | 60,02 | 47,69 | 23,60 | 18,39 |
| Locomoção ativa, consultas e poses ociosas reduzidas | 59,19 | 40,12 | 29,25 | 19,98 |

Fontes: `work/war-bench-release161-12-0.json`, `work/war-bench-isolate-no-locomotion-12-0.json`, `work/war-bench-optimized161-12-0.json`. A medição síncrona do módulo em doze atores imóveis caiu de 0,398 para 0,140 ms por quadro. Isso não mede isoladamente os custos posteriores das mudanças de transformações na física; o teste completo acima confirma a recuperação neste roteiro. Restam quedas no 1% low; não foi alcançada estabilidade de 60 FPS. O treino offline foi medido separadamente durante 30 segundos em 1080p com onze bots reais e o humano parado no ponto avançado: 60,00 FPS médios, 1% low 54,11, P95 17,24 ms e pior quadro 19,48 ms. Os bots realizaram navegação, mas não dispararam nessa janela (zero tiros no relatório); portanto estes números não medem combate intenso offline. Fonte: `work/war-offline-benchmark-161.json`.

Metodologia histórica em [GUERRA-DESEMPENHO.md](GUERRA-DESEMPENHO.md). A entrega anterior permanece documentada em [ATUALIZACAO-1.6.0.md](ATUALIZACAO-1.6.0.md).

## Fechamento e próxima etapa

A ativação assinada, a tripulação no servidor central e a distribuição pelo launcher da 1.6.1 estão confirmadas. O pacote inclui os assets esperados e inicializa pela cena normal, sem conteúdo de QA. `distribution/release-notes.json` alimenta o site e o launcher.

Depois desse fechamento, a fila do plano de áudio/scoreboard/ranking/granadas/HUD está em [REVISAO-AUDIO-RANKING-HUD.md](REVISAO-AUDIO-RANKING-HUD.md): som distante de Guerra, HUD dos gadgets, mortes persistentes elegíveis e estado de recarga por arma. Os sistemas já corretos serão reaproveitados.

