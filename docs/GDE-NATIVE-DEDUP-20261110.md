# Integração nativa por padrão e redução de trabalho duplicado — 10/11/2026

## Princípio
Acelerar o trabalho realmente repetido, não substituir indiscriminadamente GDScript por C++. O Godot e Jolt Physics já executam colisões, consultas físicas e `move_and_slide` em código nativo. Reescrever o controlador de degraus em C++ foi **rejeitado** em piloto anterior por piorar o P95 gráfico.

Branch: `ia/gde-native-dedup-20261110`, baseada na branch de separação em lote `cf7c2a9`. Nenhuma alteração na `main`.

## Alterações implementadas

**1. Política central de execução nativa.** `scripts/native_runtime.gd` (`GameNativeRuntime`) verifica se `WarNativePoseMath` está registrada no Godot. Quando estiver, o caminho C++ torna-se preferido por padrão para `GameInfantryPose` (torso/arma/ombro/cotovelo/mão) e `WarBotDirector` (separação de bots em lote). Sem biblioteca nativa, o caminho GDScript segue funcionando. Compatibilidade com flags antigas de ativação preservada por serem redundantes; novos opt-outs: `--war-native-legacy` para tudo, `--pose-gde-legacy` para apenas poses, `--war-bot-separation-legacy` para apenas separação. Isto é a política **da branch de desenvolvimento**, não da build publicada.

**2. Reaproveitamento de cálculos no par de braços.** `WarHumanRig.pose_pair` utiliza um pequeno contexto **local à mesma atualização síncrona**, compartilhado entre ambos os braços. São calculados no máximo uma vez por par: `GameWeapons.canonical(weapon_id)`, tipo de arma/estado de granada, inversão da basis do `body_root`, orientação da arma importada e `GameInfantryPose.upper_transform(actor).basis`. Todos são carregados de forma *lazy*, apenas se o braço ainda exige atualização. Elimina também a construção de uma lista temporária de `[arm,target,grupo]` por frame. Cache não é persistente entre frames: mudanças de mira, recarga e animação continuam imediatas. Chamadas para arma/objeto segurado por uma mão mantêm o caminho individual original.

**3. Reuso de identificação da arma na finalização da mão.** `WarHumanRig._finish_arm` recebe `canonical` já calculado e não refaz `GameWeapons.canonical` a cada mão.

## Auditoria de outros hotpaths e decisões

| Área | Diagnóstico | Decisão |
|---|---|---|
| `WarHumanRig._prepare_arm` | Orientação do tronco, grip importado, código da arma e basis invertida calculados duas vezes por pose | **Implementado** reaproveitamento por par; medir custo real |
| `WarBotDirector._prepare_native_separations` | Coleta os jogadores elegíveis a cada tick e reconstitui IDs/posições; o cálculo em C++ em lote já evita várias buscas por bot | **Manter**, avaliar snapshot contíguo mais compacto com profiling antes de mexer na replicação/autoridade |
| `WarBotDirector._index_actors` | Grade espacial atualizada a cada 0,2 s, enquanto separação de contato usa posições atuais | **Não reutilizar diretamente** o índice antigo nos 60 ticks; isso introduziria atraso no desvio entre bots |
| `GameInfantryPose.apply` | Atualização do torso/leg/head/arms gera arrays de tamanho 2 e várias alterações de `Node3D` | Próxima oportunidade para cache visual/visibilidade com evidência de profiler; hitboxes e câmera exigem cautela |
| `WarCollisionPoseSolver` + visual poses | Pode existir trabalho redundante entre pose visual e rig físico, mas outra IA mantém P1k em desenvolvimento | **Não alterar em paralelo**; aguardar homologação P1k para evitar sobrescrever correções |
| `move_and_slide`, Jolt e consulta a degraus | Trabalho físico já nativo; migração anterior piorou P95 de FPS | **Não portar** |
| Objetos/mapas Favela e criação de ragdolls | Travadas de inicialização e objetos podem envolver criação de cena, colisões, memória e renderização; port C++ puro não garante solução | Medir com profiler/capture gráfica antes de otimizar |
| Renderização de personagens distantes | Atualizações repetidas de nós/poses e armas mesmo fora do campo de visão podem consumir CPU do cliente | Candidato de alto valor para estudo de LOD visual com exceções para sombras, mira e hitboxes |

## Resultados disponíveis

- `tests/native_runtime_defaults_qa.gd`: **14/14 PASS** com native default e com `--war-native-legacy`, comprovando fallback e política por recurso.
- `tests/gde_arm_runtime_qa.gd`: **2.700/2.700 PASS**, 150 pares reais de braços (cinco armas, 300 membros), diferenças máximas ~1,14e-5 nas transformações e regiões de acerto.
- `tests/gde_native_separation_qa.gd`: **20.600/20.600 PASS** em populações 0/1/2/12/28/57.
- `tests/native_pose_dedup_qa.gd`: **2.070/2.070 PASS**, 180 comparações de entrada entre caminho individual e compartilhado, erro 0 em todos os campos. Benchmark alternado de 7×1.600 iterações de preparação de dois braços: mediana original **58,556 ms**, com cache **54,680 ms**, aceleração local **1,071×** (~6,6% menos tempo desta rotina). Não equivale a 7% mais FPS.

## Bloqueios conhecidos
- O editor do Godot apresentou anteriormente crash intermitente na **primeira importação** de uma extensão C++. Isso não foi reproduzido nesta importação de worktree, mas a causa raiz ainda não está comprovada.
- A extensão Linux x86_64 foi compilada no Ubuntu 26.04/WSL e pode exigir glibc mais recente do que outras distribuições; testar em servidor de produção real, com mesma versão do Godot.
- A separação em lote é executada pelo diretor **autoritativo** de bots; o benefício pode ser do host/servidor, não necessariamente do cliente remoto. A otimização de pose nativa atua também no cliente.
- Nova política de default **não autoriza merge ou release** antes de medição de FPS cliente/28 bots, QA multiplayer e teste de estabilidade de importação. O fallback deve permanecer disponível.

## QA de carga headless real, 28 bots, versões padrão e fallback
Quatro execuções sequenciais, 28 bots, Jolt e render desativado (servidor headless); outros testes de IAs estavam presentes na mesma máquina. Ordem **C++ padrão, GDScript legado, GDScript legado, C++ padrão**. Todos terminaram sem falhas.

| Rodada | Caminho | Frame P50 ms | Frame P95 ms | Física P95 ms |
|---|---|---:|---:|---:|
| 1 | C++ automático | 14,534 | 30,866 | 22,573 |
| 1 | GDScript legado | 14,792 | 31,965 | 27,563 |
| 2 | GDScript legado | 14,371 | 30,799 | 24,691 |
| 2 | C++ automático | 16,143 | 41,266 | 37,448 |

**Veredito do servidor:** não houve ganho consistente. O C++ venceu o primeiro par e sofreu regressão no segundo; isto pode envolver concorrência, alterações de estado da carga ou ruído, mas **não há prova de aumento de FPS** e tampouco autorização para publicar como padrão. Estes dados são de simulação sem renderização, e não de cliente GTX 1650.

A comparação gráfica com foco e Forward+ ainda precisa confirmar o comportamento no cliente. O default nativo continua restrito à branch isolada até completar esses gates.

## Benchmark gráfico direto, GTX 1650 / 1080p / Forward+ / Médio a 100%
Fixture `tests/benchmark/war_1080p_benchmark.gd`; mapa Favela; 28 bots reais; 6 s aquecimento, 12 s medição, sem FPS cap, VSync desativado. Ordem **C++ padrão → GDScript legado → GDScript legado → C++ padrão**. Os quatro relatórios brutos (frame-time trace, GPU, physics, render, população e foco) estão em `docs/benchmark-results/gde-native-default-20261110/visual-*.json`.

| Rodada | Caminho | Mediana FPS | P50 frame ms | P95 frame ms | P99 frame ms | Foco |
|---|---|---:|---:|---:|---:|---:|
| R1 | C++ automático | 48,71 | 20,528 | 34,817 | 49,916 | 507/507 |
| R1 | GDScript legado | 36,26 | 27,579 | 39,457 | 71,189 | 431/431 |
| R2 | GDScript legado | 40,49 | 24,698 | 40,125 | 65,105 | 461/461 |
| R2 | C++ automático | 49,59 | 20,167 | 32,674 | 39,141 | 534/534 |

**Leitura:** o C++ venceu os dois pares gráficos com P95/P99 menores, ao contrário dos resultados headless inconsistentes. O ganho medido refere-se à **combinação das rotinas nativas já validadas (poses e separação) mais reutilização de dados entre os braços**; o microbenchmark isolado de preparação de braços explica apenas uma fração pequena dessa diferença. Ainda não é demonstração estatística de melhoria permanente: existem processos de teste de outras IAs na máquina, e só foi possível repetir dois pares curtos de 12 s. O cenário é offline/host local, **não o cliente remoto multiplayer**. A janela esteve em foco em 100% das amostras.

## Decisão atual
**C++ preferido por padrão somente na branch**, mantendo opt-outs por recurso e fallback automático se a classe ou métodos exportados estiverem ausentes. O gate cliente gráfico é promissor; o gate headless do servidor **não está aprovado por regressão em R2**. Portanto esta branch está pronta para PR/revisão e QA multiplayer, mas **não deve ser integrada automaticamente na main/publicação** sem comparar ambiente de produção e investigar o histórico de crash esporádico na primeira importação de GDExtension.
