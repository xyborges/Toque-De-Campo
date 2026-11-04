# Guerra online — investigação de gargalos

**Continuação:** a correção foi implementada, validada e publicada na 1.10.3/build 77. Veja [CORRECAO-LAG-GUERRA-2026-10-29.md](CORRECAO-LAG-GUERRA-2026-10-29.md) para as mudanças e resultados. As medições abaixo preservam o diagnóstico anterior à correção.

Coleta em 29/10/2026, aproximadamente 16h53–17h03, horário de São Paulo. Servidor Ubuntu em produção na **1.10.2/build 74**. Esta investigação não publica uma versão nem reinicia os serviços.

## Resultado

**Há saturação da thread principal do Guerra com 28 bots e um humano.** A VM reconhece os oito processadores lógicos, mas o trabalho predominante da partida continua sequencial. Nas duas coletas estáveis, a thread principal consumiu aproximadamente **98,8–98,9% de um núcleo**, enquanto a VM inteira usou **15,3–15,6%**. O processo usou cerca de 111–112% de um núcleo, incluindo suas threads auxiliares. A soma de CPU do processo não significa que todos os oito núcleos estejam saturados.

O relógio autoritativo avançou **42,8 segundos em aproximadamente 44,75 segundos reais**, tanto com cliente headless quanto com cliente renderizado. Isso corresponde a aproximadamente **95,6% da velocidade real**, por inferência a partir dos snapshots recebidos. Não é uma medição direta de todos os ticks do servidor. A concordância das duas rodadas e a saturação da thread principal sustentam a identificação do gargalo; não reproduzem necessariamente a pior pausa sentida pelo jogador.

A câmera responde localmente aos comandos. Portanto, sua resposta não demonstra que a autoridade esteja acompanhando o mesmo ritmo. O relato de câmera respondendo enquanto o mundo atrasa é compatível com esse resultado. O histórico da sessão original do jogador não possui telemetria suficiente para atribuir cada travamento a uma causa individual.

## Por que oito núcleos não dividem a partida automaticamente

Os scripts atuais de Guerra processam bots, personagens, combate, veículos e sincronização predominantemente nos callbacks normais da árvore de cenas. A inspeção não encontrou grupos de processamento em threads auxiliares nem uso de `WorkerThreadPool` nessas rotinas. A escrita dos diagnósticos usa uma thread própria; o motor também tem trabalho auxiliar, observado no consumo adicional do processo.

O Godot oferece paralelismo explícito, mas a árvore de cenas e o objeto AStar compartilhado impõem restrições de acesso. Distribuir somente os núcleos na configuração da VM não transforma loops sequenciais em tarefas paralelas. Referências: [process_thread_group](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-property-process-thread-group) e [APIs e acesso entre threads](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html).

## Produção: duas janelas de partida

Um cliente autenticado, mapa completo, 28 bots além do humano, observação parada na base. Cada janela mede aproximadamente 45 segundos depois de 12 segundos de aquecimento. A CPU da VM foi coletada por SSH durante 20 segundos dentro da mesma janela.

| Métrica | Cliente headless | Cliente renderizado |
|---|---:|---:|
| Thread principal do servidor, % de um núcleo | 98,88% | 98,83% |
| Processo Guerra, % de um núcleo | 111,07% | 112,03% |
| CPU total da VM, oito processadores | 15,28% | 15,62% |
| CPU steal da VM | 0,0063% | 0,0063% |
| Relógio do servidor / tempo real observado | 42,80 / 44,750 s | 42,80 / 44,761 s |
| Intervalo médio dos snapshots de partida | 209,11 ms | 209,16 ms |
| P95 / máximo desses intervalos | 238,75 / 292,69 ms | 250,28 / 300,00 ms |
| RTT ENet médio / P95 / máximo | 65,16 / 88 / 93 ms | 67,01 / 90 / 101 ms |
| Intervalo de quadro do cliente, média / P95 | 16,85 / 24,16 ms | 25,41 / 39,56 ms |
| Pior intervalo de quadro do cliente | 156,64 ms | 84,23 ms |

O snapshot geral tem período nominal de **200 ms**; 209 ms não significa sozinho uma latência adicional de 209 ms. As posições dos bots são transmitidas por outro fluxo, nominalmente a cada 100 ms. Os intervalos medidos incluem os atrasos de processamento do receptor. RTT inclui transporte e atendimento do peer; não separa propagação de rede de espera no servidor ou cliente. Não há medição de latência em um sentido.

As duas janelas estáveis terminaram sem falhas de asserção, erros de script ou avisos de buffer UDP cheio. Uma rodada exploratória anterior registrou descarte de pacotes durante e após a entrada de outro cliente, mas concorria com um benchmark local. Ela foi excluída da comparação: não é evidência suficiente de perda persistente na rede física. O campo ENet de perda confiável também não mede diretamente perda de todos os datagramas de posição.

O Guerra manteve cerca de **396 MiB de RSS**. Havia aproximadamente **13,55 GiB de memória disponível**, swap sem uso e nenhum reinício do serviço. Não apareceu evidência de falta de RAM ou contenção relevante da VM pelo hipervisor nessas janelas. Isso não exclui problemas em outros horários.

**Atenção ao status antigo:** o campo `connections` do build 74 apareceu como 29 para esta população de 28 bots e um humano. Não foi interpretado como 29 conexões humanas. A população foi confirmada pelo cliente.

## Renderização no cliente

GTX 1650, Compatibility/OpenGL, janela solicitada de 1280 × 800, viewport lógico informado de 1440 × 900. A dimensão da textura efetivamente renderizada não foi coletada; este teste não deve ser chamado de benchmark em 1080p.

- Aproximadamente **39,35 FPS** pela média dos intervalos; P95 de quadro de 39,56 ms.
- GPU: tempo medido médio **8,38 ms**, P95 **11,69 ms**, máximo **21,25 ms**.
- Até **3.586 draw calls** no quadro.
- Monitor global de física: média **14,25 ms**, P95 **18,41 ms**.

Há custo relevante no cliente, além do gargalo do servidor. O tempo médio da GPU inferior ao intervalo completo do quadro e a quantidade de draw calls são compatíveis com pressão de CPU/atualização/submissão de cena. Isso é uma inferência, não um perfil completo do driver. Tempos de GPU, processo global e física não devem ser somados como parcelas independentes. A observação foi parada na base; não cobre a pior vista, giros rápidos de câmera ou combate intenso.

## Carga local de bots, sem renderização

Uma autoridade local no mapa completo, um humano parado, mesmos sistemas de personagem e colisão, diretor com distribuição online pelos cinco objetivos. Não há clientes de rede neste ensaio. A cena usa autoridade offline para isolar o custo de população, portanto não mede diretamente a capacidade da VM. Cada configuração teve uma rodada, semente fixa e 24 segundos medidos após preenchimento e aquecimento.

| Bots realmente implantados | Física global média / P95 | Quadro médio / P95 | Pior quadro |
|---|---:|---:|---:|
| 0 | 5,60 / 8,47 ms | 16,67 / 18,53 ms | 24,11 ms |
| 14 | 12,47 / 22,15 ms | 16,67 / 19,77 ms | 33,31 ms |
| 28 | 17,05 / 25,78 ms | 16,94 / 21,99 ms | 98,38 ms |

Todos os bots pedidos estavam implantados; zero falhas de implantação. A rodada de 28 registrou dois tiros, as demais zero. As trajetórias, ocupação de veículos e estado da partida variam com a população. São comparações exploratórias, não um experimento de uma única variável com combate idêntico nem uma certificação de que 14 bots sejam o limite adequado.

Na rodada de 28, o timer inclusivo do diretor mediu aproximadamente **3,43 ms por tick**, com máximo de **10,10 ms**. O movimento teve 38.907 chamadas com média de 0,106 ms por chamada; as decisões tiveram 480 chamadas com média de 0,199 ms por chamada. O timer dos atores inclui poses, e o timer do diretor inclui movimento/decisões: esses escopos não são aditivos. O resultado mostra que distribuir apenas decisões de IA não remove todo o custo de movimento, atores e física.

Uma tentativa anterior, `28a`, continha 28 registros, mas apenas 17 bots implantados por causa do limite offline do fixture. Ela foi descartada. O fixture passou a exigir a implantação real de toda a população antes de medir.

## Prioridade técnica

1. Aliviar o ciclo principal de simulação e personagens, preservando colisões, tiros, navegação e autoridade. Usar a carga de 14 bots como controle de investigação; os dados não justificam escolher um novo limite permanente automaticamente.
2. Medir e separar tarefas de dados que possam executar em workers, como decisões e rotas sobre dados apropriados. Aplicar os resultados na autoridade; não mover toda a árvore de cenas ou compartilhar o mesmo AStar entre workers indiscriminadamente. Paralelizar apenas a decisão não garante ganho suficiente, dado o perfil local.
3. Reduzir custo de atualização e submissão dos modelos remotos no cliente, mantendo hitboxes e comportamento. Conferir especialmente a apresentação dos personagens na autoridade dedicada, que não possui observador local e não recebe o mesmo critério de LOD por distância do cliente.
4. Repetir com mais humanos, combate sustentado, entrada/saída de jogadores e sessões longas. Registrar tick e duração do frame autoritativo junto do RTT e dos fluxos de posição para identificar as pausas intermitentes individualmente.

Aumentar RAM ou simplesmente passar de oito para mais vCPUs não trata o trecho sequencial identificado. A investigação não aplicou uma mudança de gameplay nem uma arquitetura de threads ao servidor.

## Evidências e reprodução

- `work/war-lag-summary.json`: resultados consolidados, inclusive CPU da thread principal, GPU, RTT e relógio autoritativo.
- `work/war-lag-production-stable74-{headless,visual}.json`: amostras da VM, metadados e resumos sanitizados dos logs.
- `work/war-lag-live74-stable74-{headless,visual}.json`: observação dos clientes e fluxos de rede.
- `work/war-lag-load-{0b,14b,28b}.json`: dados completos e timers locais.
- `tests/war_lag_load.gd` e `tests/run_war_lag_load.py`: ensaio de população. Executar `python tests/run_war_lag_load.py` na raiz do projeto.
- Scripts `work/war_lag_remote_audit.py`, `work/war_lag_live_probe.gd`, `work/war_lag_live_game.gd`, `work/run_war_lag_live_probe.py`, `work/prepare_war_lag_source74.py` e `work/summarize_war_lag.py` documentam a coleta.

Os clientes de diagnóstico usaram um projeto isolado com fontes restauradas de antes da 1.10.3 e protocolo 31, contra a produção real. **Não eram o executável assinado exato do build 74.** Os assets vieram da cópia local; essa limitação se aplica especialmente à comparação de renderização. Não houve alteração do protocolo aceito pela produção, da autenticação ou da autoridade para admitir a coleta.

O projeto local recebeu alterações de diagnóstico durante a investigação; os ensaios locais representam esse estado de desenvolvimento, não o pacote publicado. Os timers são tempos inclusivos de relógio e os monitores do motor incluem trabalho nativo. As cinco rodadas válidas completaram sem erros de script; os cinco scripts Python de coleta, reprodução e consolidação também passaram por compilação sintática.
