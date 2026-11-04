# 1.10.4 — sincronização do Guerra

29/10/2026. **1.10.4/build 78 publicado na VM Ubuntu.** Mantém a otimização de personagens publicada no build 77 e acrescenta a correção do fluxo de estados. O publicador confirmou `VERIFIED_READY build=78` e `DEPLOYED build=78 version=1.10.4`, usando a verificação de salas vazias, backup e rollback existentes.

## Problema encontrado na verificação final

O build 77 reduziu a carga da thread principal da autoridade, de cerca de 99% para 82% de um núcleo, e o relógio autoritativo voltou a acompanhar o tempo real na amostra online. O cliente gráfico passou de aproximadamente 39 para 56 FPS. Entretanto, nessa sessão ainda foi observado um intervalo de 3,78 segundos entre estados da operação e pausas em grupos de posições de bots, sem parada equivalente dos frames do cliente nem da simulação.

Esse dado não demonstra isoladamente a causa da pausa. A revisão encontrou um problema concreto de transporte: os lotes de bots e o estado geral da operação usavam o mesmo fluxo `unreliable_ordered`, com tamanhos e frequências diferentes. Essa ordenação descarta um datagrama que chega depois de outro enviado posteriormente, mesmo quando os conteúdos pertencem a atores diferentes. A [documentação do Godot](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html#channels) descreve esse risco ao misturar tamanhos de pacote.

## Correção

- Os lotes de bots usam transporte não ordenado e uma sequência monotônica por personagem e por vida. A autoridade gera essa sequência; o receptor compartilhado rejeita duplicatas, posições antigas e vidas anteriores.
- O estado da operação também usa transporte não ordenado e rejeita atualizações antigas pelo identificador da operação e pelo relógio da autoridade. Um estado de uma operação anterior não restaura relógio, tickets ou fim de partida.
- As mensagens confiáveis de entrada, equipamento, dano e transição de rodada preservam seu caminho existente. Os 28 bots, colisões e otimizações de CPU continuam ativos.
- O Guerra passa ao **protocolo 33**. Cliente e servidor precisam atualizar juntos.

Não se afirma que a alteração elimina qualquer pausa de rede. As medições após a publicação abaixo registram os intervalos observados com a conexão real.

## Validação anterior à publicação

- **12 verificações** de sequência por ator/vida, rejeição de duplicatas, pacotes antigos, timestamp inválido, formato antigo e tamanho conservador do lote.
- **17 verificações** de transições de operação e descarte de estados da rodada anterior. A verificação do painel aguarda a animação compartilhada de fechamento e também exige a liberação imediata dos controles.
- **15 verificações** com autoridade e dois clientes ENet/DTLS: 28 bots implantados, balanceamento, entrada gradual, dois humanos, placar, movimento e disparos reais. Zero falhas de implantação.
- **111 verificações** do pacote Linux: navegação declarada pelo manifesto, ausência de fontes de teste, chaves privadas e extensão de voz no servidor.
- **13 verificações** da instalação assinada do build 78, seguidas de inicialização normal do EXE protegido, carregamento da biblioteca de voz e confirmação de que os arquivos instalados permaneceram intactos.

Após a publicação, o manifesto HTTPS correspondeu byte a byte ao manifesto assinado validado localmente; o download anunciado tem os 221.504.112 bytes previstos. Foi feita uma consulta HEAD do arquivo, sem repetir seu download completo. Evidências: `work/war-state-release-deploy.log`, `work/war-state-signed-install78.json` e `work/war-state-public-download78.json`.

Evidências: `work/war-state-ordering.json`, `work/war-round-transition-regression.json`, `work/war-state-network.log`, `work/1103-war-bots-network.json` e `work/war-state-pack78.json`. Os resultados de CPU e da comparação Linux A/B/A da etapa anterior estão em [CORRECAO-LAG-GUERRA-2026-10-29.md](CORRECAO-LAG-GUERRA-2026-10-29.md).

## Verificação online após a publicação

Sessões autenticadas na autoridade real, com mapa completo, 28 bots (14 por equipe), um humano parado na base e nenhum carregamento pendente. A VM confirmou os oito vCPUs e o caminho `/opt/toque-de-campo/releases/build-78`. Guerra, PvP, Naval e encaminhador BR ativos; as salas BR estavam ociosas. Zero reinícios por falha.

| Medida | Antes, build 74 headless, 45 s | Build 78 headless, 45 s | Build 78 gráfico, 120 s |
|---|---:|---:|---:|
| Thread principal, % de um núcleo | 98,88% | **82,05%** | **83,74%** |
| Processo Guerra, % de um núcleo | 111,07% | **86,99%** | **88,74%** |
| Relógio autoritativo / tempo real recebido | 42,80 / 44,750 s | **44,60 / 44,648 s** | **119,80 / 119,808 s** |
| Ritmo do relógio autoritativo | 95,64% | **99,89%** | **99,99%** |
| RTT médio / P95 | 65,16 / 88 ms | **26,84 / 29 ms** | **33,69 / 39 ms** |
| Maior intervalo de estado geral | 292,69 ms | 601,09 ms | 814,00 ms |
| Maior silêncio de posição viva/implantada observado | 129,78 ms | 291,93 ms | 681,89 ms |

O intervalo de estado geral da versão intermediária 77 chegou a 3.780 ms na amostra gráfica de 45 segundos; não houve intervalo de vários segundos nas novas sessões. Isso não prova a causa de todo pacote perdido, nem permite afirmar que o transporte nunca voltará a pausar. O build 78 headless também teve intervalos de estado geral maiores que os da referência 74: a melhora do relógio e do custo de CPU não deve ser apresentada como uma redução uniforme de todos os intervalos de rede. Saltos de sequência podem incluir perda ou reordenação; não são uma medição direta de perda de pacotes.

Na amostra gráfica de 120 segundos, o usuário redimensionou a janela e confirmou isso durante a verificação. O viewport terminou em 1743×900, contra 1440×900 nas amostras anteriores, e houve um quadro de 649 ms. Os intervalos de recebimento incluem pausas do cliente; não se atribui o pico integralmente à rede. Os 36,15 FPS médios dessa amostra ficam registrados, mas não são usados como comparação controlada de renderização.

### Repetição gráfica e limites restantes

A repetição de 45 segundos bloqueou o redimensionamento. Foi solicitado 1280×800; após a mudança do estilo da janela, o Godot reportou **1292×812** e viewport **1440×905**, iguais no início e no fim. Portanto, é uma resolução próxima da referência, e não uma igualdade exata de viewport. O resultado foi **36,80 FPS**, quadro médio de **27,17 ms**, P95 de **37,09 ms** e pior quadro de **115,72 ms**. O tempo de GPU médio foi **9,20 ms**. A amostra intermediária do build 77 chegou a 55,53 FPS, mas **não houve ganho gráfico estável confirmado na repetição final**. O redimensionamento anterior não explica toda a variação; não se apresenta a otimização de CPU da autoridade como garantia de maior FPS no cliente.

Nessa repetição, o relógio da autoridade avançou aproximadamente em tempo real (100,05%, com variação de recepção), o RTT médio foi **32,41 ms**, e foram observados até **1.203 ms** entre estados da operação e **1.598 ms** entre posições recebidas de um bot. O maior silêncio vivo/implantado amostrado foi 1.336 ms. Houve quadros do cliente menores que esses intervalos, então não se atribui todo o pico ao redimensionamento ou à renderização. **Persistem picos ocasionais de recepção**, embora o gargalo sustentado de CPU e a desaceleração do relógio tenham melhorado. A correção de ordenação é válida e testada; estas medições não comprovam o desaparecimento de todo congelamento online.

A revisão somente de leitura da VM encontrou `RcvbufErrors=0`, `SndbufErrors=0`, `InErrors=0` e `MemErrors=0` nos contadores UDP acumulados do kernel. Os 17 registros recentes de simulação com 28 bots mostraram monitor de física entre 14,891 e 23,422 ms, sem erros de engine no log ativo. O monitor é pontual a cada registro; não é um perfil de todos os ticks. Isso não identifica a origem dos picos nos demais saltos de rede ou no PC cliente e não justifica alterar buffers ou a configuração dos oito vCPUs sem evidência adicional.

Evidências adicionais: `work/war-lag-live74-build78-visual-fixed.json`, `work/war-lag-production-build78-visual-fixed.json` e `work/war-lag-production-build78-final-review.json`. A repetição também terminou sem erro de script ou aviso de buffer cheio.

A CPU foi amostrada por 20 segundos dentro de cada sessão; não representa a média de todos os 120 segundos. O RTT inclui transporte e atendimento dos dois processos, com sessões em horários diferentes. Os clientes de diagnóstico usam o Godot de desenvolvimento e as fontes da versão publicada, com autenticação normal; o EXE assinado foi instalado e inicializado em teste separado. São amostras com um humano e pouco combate, sem comprovação de lotação de 12 humanos ou ausência de pausas em toda sessão longa.

Evidências: `work/war-lag-live74-build78-headless.json`, `work/war-lag-live74-build78-visual.json`, `work/war-lag-production-build78-headless.json`, `work/war-lag-production-build78-visual.json` e `work/war-lag-summary.json`. O prefixo legado `live74` pertence ao coletor; o campo `version` dos resultados confirma 1.10.4. Nenhum erro de script ou aviso de buffer cheio apareceu nas duas sessões.

Para receber a correção, feche e abra novamente o launcher. A autoridade usa o protocolo 33; o cliente anterior precisa atualizar para reconectar.
