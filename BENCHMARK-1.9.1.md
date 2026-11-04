# Desempenho e latência — 1.9.1

Medições em 27/10/2026, Godot 4.7.2 Compatibility, Windows, i5-11400H (6 núcleos/12 threads), GTX 1650. Relatórios brutos ficam em `work/perf181/` e `work/latency191-*`; cenários de regressão em `tests/`.

## Diagnóstico confirmado

- Configurações: a consulta de diretório fazia uma prova de escrita repetida no caminho padrão do perfil. Essa resolução agora acontece uma vez por processo; preferências continuam persistidas pelo escritor normal.
- Água: a consulta era repetida dentro do mesmo tick. Em 10.000 chamadas quentes, a referência custou 43,48–52,41 ms e o cache 7,31–7,54 ms. O resultado é um microteste de CPU, não ganho de FPS da partida. Testes cobrem teleporte, morte, embarque, horário/onda, clima e edição do terreno.
- Térmica: reaplicação desnecessária de metadados por mesh. Com 1.000 meshes e 200 scans, o custo médio medido foi 2,290 → 1,461 ms; p95 3,146 → 2,350 ms. Não inclui desenho da GPU nem carregamento inicial. Os testes verificam troca de temperatura, mudança externa de material e restauração ao desativar.
- Blindados vazios: no fixture de apoio estável, 108 de 120 ticks dispensam movimento, alinhamento e rodas. Recargas permanecem ativas. Isso não equivale a reduzir em 90% o custo da partida inteira.

## Rede real

Antes da publicação, dois clientes de teste autenticados no Ubuntu de produção, em espera, sem interferir em partidas: RTT ENet/DTLS médio 23,31 e 33 ms, p95 24 e 33 ms; frame p95 dos clientes 16,91/16,92 ms. O servidor consumiu 10,55% de um núcleo durante a coleta, com filas UDP vazias. Esta amostra não representa combate com doze jogadores.

O snapshot nominal de 5 Hz chegou a cada 216,66 ms, em vez de 200 ms. A soma de doze ticks de 1/60 podia ficar abaixo de 0,2 e esperar um tick adicional; zerar o acumulador perpetuava a deriva. O helper compartilhado preserva o resto e a taxa nominal, emitindo no máximo uma atualização por chamada após uma travada. Há 36 verificações a 30/60/120 Hz, incluindo stutter.

Um teste ENet/DTLS real com proxy UDP descartou sete datagramas e atrasou dois. A última pose perdida foi recuperada pelo heartbeat em 565,98 ms. Os dois veículos rejeitaram os estados antigos sem desfazer respawn nem contaminar a revisão dos assentos. O ensaio verificou os receivers reais do jogo; não foi apenas uma comparação matemática de vetores.

## Ensaio de carga e limites

O stress mantém um servidor, um cliente com renderização 1920 × 1080 e onze clientes de carga leves neste mesmo PC. Todos conectam por ENet/DTLS. Há disparos, quatro blindados, drones, explosões e uma desconexão. A autoridade e o cliente visível mantêm o mapa completo.

A execução de diagnóstico registrou um stall de servidor de 1.735 ms, acompanhado por 1,61–1,66 s sem novas poses de oito atores. O cliente manteve seu próprio tick (máximo 85 ms nessa janela), sem gaps de sequência dessas poses. O RTT também cresceu porque a recepção e os ACKs dependem do polling do processo. Isso sustenta investigar o avanço do servidor, não atribuir o congelamento a DTLS.

O fixture reposiciona quatro veículos aos oito segundos; alguns entram em contato com o terreno e seguem trajetórias opostas. Esse trecho mede ativação/teleporte/colisão extrema, não condução livre. Um ensaio adicional com um único processo, mapa completo e saída normal da base separa esses efeitos da concorrência entre treze processos.

Os monitores `TIME_PROCESS`/`TIME_PHYSICS_PROCESS` são amostras do engine e não devem ser somados como tempos exclusivos. Os timers de movimento medem tempo de parede, incluindo trabalho nativo, sincronização e preempção. Scopes aninhados não são aditivos. Os relatórios de diagnóstico retêm 600 chamadas por scope e preservam contagem, média e máximo do período completo.

**A meta de 60 FPS estáveis com doze jogadores em PCs separados não é demonstrada por este stress local.** A correção não remove colisões, objetos do mapa ou hitboxes para fabricar um resultado.

## Suspensão: validação final

A varredura vertical usa `cast_motion` para cada forma do casco e o menor deslocamento seguro entre elas. Como essa consulta ignora sobreposições já existentes no início, um spawn/teleporte sobre uma rampa usa a recuperação completa do corpo somente quando uma sobreposição é detectada. A rotação testa as orientações intermediárias com `intersect_shape`. Transformações idênticas deixam de ser reaplicadas. Referências: [consultas físicas do Godot](https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate3d.html) e [implementação de Node3D](https://github.com/godotengine/godot/blob/master/scene/3d/node_3d.cpp).

No cenário extremo de quatro teletransportes, a primeira versão segura desta correção gastou 799,05 ms acumulados em alinhamento, com pico de 476,63 ms. A versão final gastou 222,15 ms, com pico de 0,684 ms. **Essa é uma comparação entre iterações da correção**, não com a versão publicada. A simulação completa dos quatro veículos ainda teve pico de 407,69 ms; a 1.9.0 teve 378,14 ms. O problema de ativação extrema não foi eliminado. Na média, a simulação foi de 1,650 para 2,261 ms, pois a correção acrescenta verificações de segurança e altera o caminho efetivamente percorrido sobre obstáculos.

O ensaio de quatro faixas no terreno natural também não deve ser apresentado como benchmark de estrada plana: o Guarani antigo ficou preso após 19,18 m e desviou 5,95 m lateralmente; a correção atravessou 64,73 m com desvio de 0,12 m. O T-90 corrigido desviou 2,44 m na encosta, excedendo a tolerância de 2 m inicialmente proposta pelo fixture. Os relatórios conservam essas falhas; não são convertidos em aprovação artificial.

Validação funcional final: 353 verificações de obstáculos (88 cenários), 32 de apoio em rampas em quatro orientações, 139 de repouso/alteração de apoio e estados, 32 de sequência de navios. Todas passaram. Os testes físicos determinísticos usam passo de 1/60 e `--fixed-fps 60` para dispensar espera de relógio; isso não é usado para medir FPS.

Sessão de regressão com servidor e dois clientes reais ENet/DTLS: **103/103** verificações, incluindo os dois times, armas/recarga, drone, APC, morte, respawn na base selecionada, impacto e observador remoto. Cliente visível: frame médio 16,74 ms, p95 17,20 ms, pico 128,22 ms. É uma sessão limitada a 60 FPS neste PC, não um benchmark de capacidade máxima.

## Renderização isolada em 1080p

Uma inspeção das capturas invalidou os primeiros ensaios da cópia de referência: o caminho longo da cópia no Windows impedia a criação do cache de shaders (erro `shader_gles3.cpp:802`), e parte do cenário aparecia sem materiais. Os números de `before191`, `baseline191-repeat` e do primeiro stress `before191-12` **não servem como comparação de FPS**. A referência foi executada por um caminho curto e os logs e as imagens foram novamente verificados. O código e os assets da referência não foram alterados.

Ensaios válidos sequenciais, cena congelada, cinco segundos por vista após aquecimento, sem limite de FPS:

| Vista | 1.9.0 FPS médio | 1.9.1 FPS médio | 1.9.1 1% low |
| --- | ---: | ---: | ---: |
| Combate | 161,1 | 159,4 | 122,1 |
| Combate térmico | 148,9 | 135,0 | 76,5 |
| Cidade | 137,9 | 141,0 | 96,1 |
| Porto | 119,0 | 115,8 | 74,9 |
| Floresta | 182,9 | 184,0 | 125,6 |

Fontes: `baseline191-valid.json` e `final191-repeat.json`. Mesma geometria, resolução e contagem de desenhos. Esta alteração não demonstra ganho geral de renderização; a simulação congelada também desativa os caminhos de CPU otimizados. A vista térmica variou para baixo e não é apresentada como ganho de FPS: o microteste de registro de materiais mede outra operação. O foco desta versão é remover trabalho repetido e corrigir mobilidade/sincronização.

## Carga com doze clientes: resultados finais

Uma última referência com diretório de perfil curto também eliminou os erros de shader no stress (`baseline191-clean`). A tentativa anterior chamada `baseline191-valid` **ainda continha erros de shader e foi descartada**: corrigir apenas o caminho do projeto não corrigia o caminho longo do perfil usado pelo renderizador. O executor agora reprova explicitamente esse erro.

| Processo/versão | FPS médio do loop | 1% low | Frame p95 | Maior frame |
| --- | ---: | ---: | ---: | ---: |
| Cliente visível 1.9.0 | 29,95 | 5,96 | 55,65 ms | 272,39 ms |
| Cliente visível 1.9.1 | 34,73 | 12,89 | 45,06 ms | 143,93 ms |
| Servidor local 1.9.0 | 13,06 | 1,60 | 223,30 ms | 1.296,17 ms |
| Servidor local 1.9.1 | 18,24 | 1,91 | 256,88 ms | 847,59 ms |

Fontes: referência `war-bench-baseline191-clean-12-{8,server}.json` e atual `war-bench-final191-valid-12-{8,server}.json`. Os treze processos disputam CPU neste mesmo notebook; FPS do loop do servidor não é taxa de simulação configurada. O p95 do servidor piorou nessa comparação, mesmo com média e máximo melhores. Uma execução atual com diagnóstico teve 42,24 FPS no cliente e 35,29 no servidor, demonstrando variabilidade importante entre rodadas. Não atribuir toda diferença às alterações nem extrapolar para doze computadores separados.

Todos os clientes completaram os cenários sem falhas funcionais. A correção final reduziu o tempo médio amostrado de alinhamento para 0,104 ms por chamada no stress com diagnóstico, mas o movimento físico ainda teve pico de 315 ms por chamada. **A investigação localiza um gargalo restante em movimentação/ativação física; esta versão não declara a latência ou os picos resolvidos por completo.**

## Integridade das cenas preservadas

`east_port.tscn` conserva o SHA-256 `69158EBE35AD7A932894EC978ED70663205EF1303BD95962E96F4777DB79B1CB`. Cena, terreno e geometria renderizada permanecem os mesmos; a otimização concentra-se em trabalho repetido, física e sincronização.

## Publicação e validação no Ubuntu

Versão **1.9.1, build 62**, publicada em 27/10/2026: cliente e servidor juntos, Guerra 23 / Infantaria 10. O publicador confirmou a instalação. O atualizador baixou os arquivos reais por HTTPS, verificou o pacote, instalou a versão e, na segunda execução, informou que não havia novo download necessário. Os cinco testes de proteção do pacote passaram, incluindo abertura no runtime próprio e rejeição de substituição por script/pacote externo. Isso dificulta alterações comuns; não torna o executável impossível de analisar.

Dois clientes autenticados conectaram ao servidor publicado por ENet/DTLS. As **25 verificações** passaram (16 do anfitrião, 9 do convidado), incluindo os dois times, poses, tiros e recargas. RTT médio: **22,86 / 21,10 ms**; p95 **30 / 22 ms**, máximos **34 / 22 ms**. O cliente visível, limitado a 60 FPS, teve frame médio **16,73 ms**, p95 **17,05 ms**, máximo **95,95 ms**. O segundo cliente era headless. Não é um teste de doze jogadores simultâneos no servidor publicado.

Uma coleta passiva posterior de 25 segundos, em espera, confirmou o intervalo corrigido de snapshots: **199,99 ms** em ambos os clientes, p95 **200,12 / 200,14 ms**, contra **216,66 ms** antes da correção. RTT médio dessa coleta: **16 / 17 ms**. A diferença de RTT entre sessões não pode ser atribuída exclusivamente ao código; não houve comparação isolada do custo da criptografia. DTLS permaneceu habilitado em todos esses testes.

Evidências: `work/perf191-deploy.log`, `work/perf191-download.log`, `work/perf191-live.log`, `tests/ubuntu-war187-perf191-{host,guest}.json`, `work/latency191-production23-{host,guest}.json`. Os executores encerraram seus clientes ao final; nenhum processo de teste desta rodada ficou aberto.
