# Guerra — desempenho: histórico 1.6.0 e atualização 1.6.1

Atualizado em 24/10/2026. A versão corrente é 1.6.1, build 27, ativada no Ubuntu. A primeira parte deste documento preserva as medições da 1.6.0/build 26, coletadas em 23/10/2026. A seção final registra a revisão da 1.6.1 e a primeira medição offline, com limites explícitos de carga e evidência.

## Condições e limites

Godot 4.7.2, renderer Compatibility/OpenGL, NVIDIA GeForce GTX 1650, cliente principal em 1920×1080, limite de 60 FPS. Um servidor autoritativo e 1, 6 ou 12 clientes ENet reais no mesmo computador; somente o cliente principal renderiza. Portanto, o PC também executa o servidor e os demais clientes: estes resultados não equivalem a 12 PCs separados.

Fonte: `tests/run_war_benchmark.py`, `tests/war_benchmark.gd`, `tests/war_benchmark_fixture.gd`. O fixture usa imortalidade exclusivamente no teste para manter disparos durante a amostragem. Não modifica o dano no jogo distribuído. O cenário inclui FAL com munição/recarga reais. Nas execuções atuais de seis e 12 clientes há quatro veículos em movimento, dois drones e uma desconexão forçada aos 21 segundos; a execução de um cliente não possui essa mesma carga de ocupantes e desconexão. Quatro explosões simultâneas são produzidas a cada dois segundos na parte de combate do roteiro. Há três segundos de aquecimento e cerca de 25 segundos medidos por execução. As poses e a entrada dos ocupantes são preparadas pelo fixture; isso não valida a interface de ocupação.

Nas execuções atuais, a medição só começa depois da barreira de prontidão de todos os clientes: mapa carregado, jogador implantado e membros conhecidos. Isso reduz a contaminação por clientes que ainda inicializam, mas também altera o procedimento em relação ao histórico. Geração inicial do mapa, importação e primeiro carregamento continuam fora da janela e não são declarados otimizados por esses números.

O Godot Script Profiler foi ativado com `--debug --profiling` nas rodadas identificadas como profiler: seções `FRAME` e custos por função estão nos respectivos arquivos `stdout.log`. O profiler nativo também formata e escreve relatórios periódicos em stdout, introduzindo sobrecarga. `Performance.TIME_PROCESS` mede o processamento global, não somente scripts; o campo legado `script_frame_ms_mean` do JSON deve ser lido como tempo global de processamento. Tempos de quadro usam relógio monotônico. 1% low é o inverso da média do pior 1% dos intervalos.

## Resultados da 1.6.0 — cliente que renderiza, sem profiler

Rodada `final-play`, após revisão de modelos, áudio compartilhado, HUD e projéteis. Dados completos: `work/war-bench-final-play-{1,6,12}-0.json`. Cada configuração abaixo é uma execução de laboratório, não uma série estatística de repetições.

| Jogadores | FPS médio | 1% low | Quadro médio (ms) | P95 (ms) | Pior quadro (ms) | Draw calls máximos | RAM estática (MiB) | Física média (ms) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 60,01 | 54,50 | 16,66 | 17,37 | 18,92 | 1.125 | 172,94 | 1,88 |
| 6 | 60,01 | 52,17 | 16,66 | 17,67 | 22,33 | 1.627 | 176,10 | 2,78 |
| 12 | 59,47 | 38,82 | 16,82 | 19,81 | 28,94 | 1.845 | 179,16 | 5,17 |

Não houve intervalo acima de 50 ms registrado no campo `spikes` dessas três execuções. Isso não elimina as quedas abaixo de 60 FPS: o 1% low de 12 clientes foi 38,82 FPS e o pior intervalo de 28,94 ms excede o orçamento de 16,67 ms para 60 FPS.

### Janela de desconexão nas rodadas atuais

| Jogadores | Desconexão real nesta configuração? | FPS médio da janela | 1% low | P95 (ms) | Pior quadro (ms) |
| --- | --- | ---: | ---: | ---: | ---: |
| 1 | Não; apenas janela temporal de controle | 60,04 | 54,32 | 17,58 | 18,92 |
| 6 | Sim, aos 21 s | 60,04 | 47,70 | 17,85 | 22,33 |
| 12 | Sim, aos 21 s | 60,03 | 39,58 | 21,05 | 25,81 |

As médias dessa janela não demonstram ausência de travamento em qualquer rede: são aproximadamente dois segundos do roteiro local, com cliente e servidor no mesmo PC. O teste funcional separado valida liberação da reserva do veículo e continuidade de disparo/recarga dos clientes restantes.

## Rodada da 1.6.0 com profiler nativo — 12 clientes

Fonte: `work/war-bench-synchronized-ready-12-0.json` e `work/war-bench-synchronized-ready-12-0.stdout.log`, com a mesma barreira de prontidão. O log preserva `BEGIN PROFILING`, seções `FRAME` e custos das funções.

| FPS médio | 1% low | Quadro médio (ms) | P95 (ms) | Pior quadro (ms) | Draw calls máximos | RAM estática (MiB) | Física média (ms) |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 52,70 | 7,54 | 18,98 | 24,21 | 250,04 | 1.844 | 182,03 | 5,24 |

Na janela de desconexão dessa rodada: 53,87 FPS médios, 1% low 8,18 e pior quadro 139,53 ms. Os picos recorrentes estão registrados no JSON, inclusive quando havia poucos ou nenhum projétil ativo. A emissão periódica de relatórios do profiler acrescenta trabalho de coleta, formatação e escrita durante a execução; a rodada sem profiler mede o comportamento jogável sem essa instrumentação. Não subtrair arbitrariamente os picos nem apresentar as duas rodadas como medição controlada do custo exato do profiler.

## Histórico preservado — comparação exploratória anterior

Resultados anteriores à rodada `final-play`, mantidos para rastreabilidade. Foram coletados com instrumentação e versões anteriores do fixture/modelos; não comparar diretamente como um experimento com todas as variáveis controladas.

| Jogadores | Etapa | FPS médio | 1% low | Quadro médio (ms) | P95 (ms) | Pior quadro (ms) | Draw calls máximos | RAM estática (MiB) |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| 1 | Antes | 58.98 | 18.50 | 16.96 | 17.33 | 62.92 | 1363 | 161.49 |
| 1 | Depois | 59.00 | 18.49 | 16.95 | 17.39 | 66.00 | 1170 | 158.98 |
| 6 | Antes | 55.47 | 6.60 | 18.03 | 17.89 | 990.02 | 2453 | 167.45 |
| 6 | Depois | 58.41 | 15.54 | 17.12 | 17.62 | 86.86 | 1597 | 161.94 |
| 12 | Antes | 53.87 | 11.16 | 18.56 | 27.68 | 106.67 | 2827 | 172.71 |
| 12 | Depois | 56.44 | 12.82 | 17.72 | 21.18 | 99.65 | 1793 | 165.87 |

## Alterações da comparação histórica

- Geometria rígida do equipamento é agrupada por material e parte animada, compartilhando malhas entre avatares da mesma equipe/classe. Mantidos pivôs, hitboxes e acessórios ligados às partes do ragdoll.
- Blindados agrupam casco, torreta e elevação separadamente; rodas animadas, marcadores dos canos e grupos térmicos de motor/canhão permanecem independentes.
- Atualizações de ocupação não reconstroem todo o uniforme se a equipe e classe continuarem iguais.
- Ao perder a conexão, controles e processamento da cena são encerrados antes de substituir o peer por OfflineMultiplayerPeer. O cliente desconectado deixou de registrar erros ENet a cada frame.

A execução antes de seis jogadores teve um pico de 990 ms e erros genéricos de peer inativo no cliente desconectado; ambos estão registrados, embora o runner original só reprovasse SCRIPT ERROR. As execuções depois não registraram esses erros. A inicialização do mapa e geração de malhas continuam caras, mas estão fora da janela medida.

Na comparação histórica, o teste com 12 jogadores passou de 53,87 para 56,44 FPS médios, com queda no pico de draw calls de 2.827 para 1.793. O 1% low continuou insuficiente. Esta é uma comparação exploratória de uma execução por configuração, com concorrência de processos e variação de eventos/rede; não isola a contribuição de cada alteração.

## Alterações presentes nas rodadas atuais

- Projéteis visuais processam apenas os slots ativos e reutilizam consultas físicas. Colisão varrida continua sendo validada; não foi substituída por apenas uma posição final do projétil.
- O filtro de colisão recebe efetivamente os RIDs do proprietário e do veículo ocupado, evitando a alteração de uma cópia temporária da lista de exclusão.
- Balística comum considera arrasto e gravidade; mísseis guiados preservam integração própria. As verificações de origem/direção dos canos continuam independentes dos efeitos renderizados.
- Geometria rígida dos blindados permanece agrupada por casco, torreta e elevação, com LOD distante. A revisão visual acrescentou detalhes e alterou a carga de geometria; por isso o pico de draw calls atual não deve ser comparado ao histórico como se os modelos fossem idênticos.
- Placar reaproveita linhas e atualiza por revisão, slots usam cache e o ranking não consulta a API a cada frame.
- Áudio compartilha recursos pré-carregados, limite global de vozes e origens fixas por disparo. Desconexão remove estado de controle antes da limpeza diferida dos objetos.

**A meta de 60 FPS estáveis ainda não foi comprovada.** A rodada atual de 12 clientes ficou em 59,47 FPS médios sem profiler, com 1% low de 38,82. São necessários testes repetidos, medições mais longas e clientes em outras máquinas, incluindo o hardware-alvo e a conexão real com o servidor central. A comparação antes/depois permanece exploratória, pois fixture, geometria, eventos, instrumentação e concorrência de processos variaram.

## Validações complementares

- `tests/war_systems.gd`: 79 verificações aprovadas, incluindo equilíbrio das equipes, captura/neutralização, relevo físico, alinhamento dos quatro canos em cinco rotações do casco, limites de elevação, munição/recarga, alcance/bateria do drone e recursos por vida. Evidência: `tests/war-systems-results.json`.
- Modelos de Guarani, BMP-2, Abrams e T-90: 109 verificações aprovadas, com materiais, armamento, canos, silhuetas e LOD distante. Evidência: `tests/war-vehicle-models-after.json`. O casco que desaparecia foi corrigido indexando as superfícies antes do agrupamento; materiais continuam opacos. Vistas nativas de frente, lateral, traseira, armas e LOD foram conferidas. Isso não certifica fidelidade integral a um veículo real.
- `tests/run_war_multiplayer.py`: 18 verificações aprovadas em sessão real ENet com servidor e três clientes. Valida implantação, exclusividade/controle do APC, disparos e saída acima do terreno, granada compartilhada, cura efetiva, RPG, travamento Stinger, destruição de drone, desconexão do motorista e disparo/recarga completa do FAL pelo jogador restante, no servidor e cliente. Poses e alvos são preparados pelo fixture; não são três pessoas jogando pela interface. Os resultados finais estão em `tests/war-multiplayer-{server,alpha,bravo,medic}.json`; o log histórico `work/release160-war-network.log` conserva uma falha anterior da fixture, na qual o Stinger matava o médico antes de ele testar a arma.
- Scoreboard: 54 verificações; equipamentos/HUD: 25; estatísticas: 34. Evidências: `tests/scoreboard-visual-results.json`, `tests/equipment-hud-results.json` e `tests/match-stats-results.json`. Incluem abertura imediata do placar offline sem ping, suporte por destinatário e dano efetivo sem inventar eliminações de infantaria.
- Áudio espacial compartilhado: 28 verificações, com captura real do mixer, distâncias, FPP/TPP, canais e oclusão. Evidência: `tests/spatial-weapon-audio-results.json`. Não equivale a teste de escuta humana.
- `tests/supplied_audio.gd`: 43 verificações aprovadas dos quatro sons recebidos, posições espaciais independentes, evento idêntico em dois clientes, deduplicação e carga de 80 explosões com limite de 24 vozes.
- `tests/ragdoll_contact_stress.gd`: 12 corpos perto de paredes; pico 5,86 m/s, altura 2,00 m e separação máxima 1,34 m. Incluída correção da posição do centro da caixa de colisão em malhas assimétricas.

## Publicação, offline e limites restantes

A 1.6.0/build 26 foi publicada em `http://192.168.101.24/`. Guerra central passou em 17 verificações com dois clientes e autenticação real; Naval e PvP Deserto também passaram pela regressão contra a VM. O download real, instalação pelo launcher e segunda abertura sem baixar novamente foram aprovados. Evidências: `work/release160-ubuntu-war.log`, `work/release160-ubuntu-naval.log`, `work/release160-ubuntu-pvp.log` e `tests/ubuntu-distribution-results.json`.

Guerra Offline passou em 42 verificações de operação real, mais 34 de equipamentos repetidas com sucesso em duas execuções e quatro de entrada pelo pacote exportado. Um humano e onze bots usam as regras e sistemas compartilhados; bots não dirigem blindados nem drones. **No fechamento da 1.6.0, FPS/frame time offline ainda não haviam sido medidos.** A medição posterior da 1.6.1 está na seção final; os JSONs ENet acima continuam sem medir o custo da IA local.

Continuam necessários testes mais longos e repetidos, outros computadores/hardware e avaliação auditiva humana entre PCs. O desempenho publicado não comprova 60 FPS estáveis.

No fechamento histórico da 1.6.0, respawn de 60 segundos, corrida/passos e tripulações ainda estavam na fila seguinte. Foram entregues no build 27; resultados específicos na seção abaixo. O histórico do build 26 permanece em `ATUALIZACAO-1.6.0.md`.

As capacidades publicadas na **1.6.1** são um operador + cinco passageiros nos APCs e um operador + um passageiro nos tanques. A autoridade gerencia assentos, promoção, saída e destruição; os testes funcionais abaixo validam esses comportamentos, sem atribuir a eles um custo isolado de FPS.

## Atualização 1.6.1 — build 27

**Publicada e validada em 24/10/2026.** A ativação está confirmada em `work/release161-publication.log`; a tripulação central passou em 33 verificações com três contas reais e a instalação real do launcher seguida de abertura sem download repetido foi aprovada. Evidências: `work/release161-central-passengers.log` e `work/release161-distribution.log`. As mudanças e verificações funcionais estão em [ATUALIZACAO-1.6.1.md](ATUALIZACAO-1.6.1.md).

### Regressão encontrada e revisão de locomoção

O primeiro teste da 1.6.1 com doze clientes caiu para 36,32 FPS médios. Para investigar, houve uma execução de controle desativando **somente no fixture** o módulo de locomoção, seguida de revisão que mantém a locomoção ativa, reduz consultas de chão e evita escrever continuamente poses/transformações de atores parados. O controle sem animação não é a versão distribuída.

Mesmas condições gerais: GTX 1650, 1920×1080, limite de 60 FPS, doze clientes ENet e servidor no mesmo PC, apenas um renderizando; veículos, drones, tiros, explosões e desconexão preparados pelo roteiro. Cada linha representa uma execução exploratória; não isola todas as variações de rede, carga e processos.

| Execução 1.6.1 | FPS médio | 1% low | Quadro médio (ms) | P95 (ms) | Pior quadro (ms) | Física média (ms) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Inicial, antes da revisão de trabalho ocioso | 36,32 | 17,37 | 27,53 | 43,47 | 84,72 | 8,71 |
| Controle do fixture, locomoção desativada | 60,02 | 47,69 | 16,66 | 18,39 | 23,60 | 4,62 |
| Locomoção ativa após revisão | 59,19 | 40,12 | 16,89 | 19,98 | 29,25 | 4,96 |

Fontes: `work/war-bench-release161-12-0.json`, `work/war-bench-isolate-no-locomotion-12-0.json` e `work/war-bench-optimized161-12-0.json`. A última execução registrou 1.845 draw calls máximos, 182,70 MiB de memória estática e nenhum intervalo acima de 50 ms no campo `spikes`. Na janela de desconexão: 58,01 FPS médios, 1% low de 41,12 FPS e pior quadro de 24,44 ms.

A medição síncrona dos métodos de locomoção em doze atores imóveis passou de aproximadamente 0,398 para 0,140 ms por quadro. Ela não inclui necessariamente todo o custo posterior das mudanças de transformações na física. O teste completo registra a recuperação no cenário, mas não deve ser usado para atribuir causalidade exata de cada milissegundo.

**Não há comprovação de 60 FPS estáveis.** A execução distribuída mantém locomoção, corrida e passos ativos; o resultado de 60,02 FPS do controle sem módulo não pode ser anunciado como desempenho do jogo publicado.

### Primeira medição de Guerra offline — navegação

Em uma operação nativa a 1080p, um humano permaneceu parado no ponto avançado enquanto onze bots reais se movimentavam. Foram medidos 1.800 quadros em aproximadamente trinta segundos, sem imortalidade, teleporte ou disparos forçados no fixture.

| FPS médio | 1% low | Quadro médio (ms) | P95 (ms) | Pior quadro (ms) | Física média (ms) | RAM estática (MiB) |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 60,00 | 54,11 | 16,67 | 17,24 | 19,48 | 5,54 | 157,99 |

Fonte: `work/war-offline-benchmark-161.json`. O relatório registra 22.341 atualizações de movimento, 1.021 rotas, onze implantações e **zero tiros/recargas**. Portanto, esta medição cobre a operação e navegação da IA; **não valida o desempenho de combate intenso offline**, explosões simultâneas ou bot disparando perto do observador. É uma rodada exploratória, não uma garantia para outro computador.

### Verificações funcionais associadas

- Assentos/autoridade/promoção/saída/destruição: 91 verificações; sessão ENet de passageiros: 24.
- Respawn na base após um minuto: 41 verificações, com contagem avançada deterministicamente.
- Sistemas de Guerra: 79; locomoção nativa/PCM: 34; locomoção por ENet real: 18.
- Regressão anterior de Guerra após desconexão: 18; equipamentos offline: 34; entrada pelo pacote exportado: quatro.

Contagens de testes funcionais não medem FPS. O custo de doze pessoas em PCs separados, outras GPUs e sessões longas ainda exige validação própria.

## Medição da integração 1.6.3

Mesma bancada: GTX 1650, uma janela 1920 × 1080, onze clientes headless e servidor no mesmo PC. Doze participantes, quatro blindados, drones, disparos reais, explosões e uma desconexão; personagens invulneráveis apenas no fixture. Janela medida de aproximadamente 25 segundos, limite de 60 FPS.

| Medida do cliente renderizado | 1.6.1 após revisão | 1.6.3 |
| --- | ---: | ---: |
| FPS médio | 59,19 | 59,20 |
| 1% low | 40,12 | 33,61 |
| Quadro médio | 16,89 ms | 16,89 ms |
| P95 | 19,98 ms | 19,15 ms |
| Pior quadro | 29,25 ms | 36,39 ms |
| Física média | 4,96 ms | 4,64 ms |
| Draw calls máximos | 1.845 | 1.694 |
| RAM estática máxima | 182,70 MiB | 182,73 MiB |

Fonte: `work/war-bench-final163-12-0.json`. Foram observados os doze jogadores e até 41 projéteis ativos. A janela da desconexão mediu 60,02 FPS médios, 1% low 41,51 e pior quadro de 27,22 ms. O servidor, competindo pelos recursos dos outros doze processos, mediu 57,62 FPS e pico de 222,48 ms. A inicialização dos veículos e a primeira utilização de efeitos continuam aparecendo em seus picos.

Não houve melhora material no FPS médio; o 1% low desta rodada ficou pior. Não se conclui causalidade de uma única rodada com treze processos, nem estabilidade de 60 FPS. O resultado é mantido integralmente, incluindo os piores quadros. O custo em PCs separados e a reprodução do travamento de munição relatado ainda precisam de observação em uso real.

