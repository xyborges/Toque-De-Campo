# Estudo independente — custo de bots e escalabilidade (28 atuais, 50+ futuros)

**Data:** 06/11/2026 · **Responsável pela análise:** ChatGPT, DESKTOP-R0I0NQG · **Base de código:** `origin/main@4bff4ae` · **Status:** investigação, não alteração de gameplay · **Meta:** manter os 28 bots e sua qualidade perceptiva; estudar 50+ futuramente, sem aumentar o custo cegamente.

## 1. Evidências observadas versus hipóteses

A branch local **não publicada** `ia/benchbots-0611@0280a2c` da DESKTOP-JJ7U3G3 tem quatro ensaios de Guerra offline no Afeganistão, Godot 4.7.2, Forward+, GTX 1650, 1920×1080, Médio/100%, FPS e VSync destravados, 8 s de aquecimento e 30 s por coleta. O autor usou um jogador real local, câmera estacionária, seed 712907 e verificou 12 bots distribuídos 6×6 e implantados. Consultei os quatro JSONs originais na outra máquina, sem editar arquivos. **Os JSONs/CSVs/logs desse ensaio permanecem somente no diretório local** `C:\Users\Joao Borges\Documents\campo-worktrees\benchbots-0611\work\bot-comparison-jj-20261106`; a outra IA deverá versioná-los em sua branch e abrir PR, sem substituir resultados anteriores.

| Indicador | 0 bots, rodada 1 / 2 | 12 bots, rodada 1 / 2 |
| --- | --- | --- |
| FPS médio | 89,82 / 95,85 | 56,12 / 62,05 |
| P99 de frame | 25,75 / 24,16 ms | 39,23 / 40,77 ms |
| Física média | 4,850 / 4,631 ms | 9,846 / 10,729 ms |
| Renderização GPU média | 4,608 / 4,713 ms | 5,280 / 4,535 ms |
| Quadros acima de 33 ms | 6 / 3 | 93 / 69 |

Média simples das duas rodadas: FPS 92,83 → 59,09 (queda de **36,4%**), física 4,74 → 10,29 ms (**+5,55 ms**) e GPU 4,66 → 4,91 ms (**+0,25 ms**). O salto na física coincide com a presença de bots, **mas NÃO equivale a medir o custo exclusivo do solver**, porque o experimento modifica simultaneamente personagens, IA, física, armas, veículos, representação e eventos do jogo. Os monitores nativos são amostras de subsistemas, não parcelas somáveis do tempo de quadro. O valor `collision_pairs_max: 0` reportado não é prova de ausência de contatos físicos. O outlier `cpu_process_ms.max: 335,913` da primeira rodada com bots exige investigação específica e não deve ser atribuído à IA sem profiler.

**Extrapolação de 5,55/12 ≈ 0,46 ms por bot é somente uma hipótese linear**, não previsão para 28/50+ bots. Antes de escalar, repetir 0/6/12/28 e observar a curvatura, colisões, NPC em veículo, estados de combate e foco.

Os resultados de 28 bots na Favela com ~25 FPS, medidos na **DESKTOP-R0I0NQG** e em outro mapa, **não** devem ser comparados numericamente com o Afeganistão da JJ7 como se fossem um ensaio A/B; devem formar baseline separados por mapa, hardware e commit. A nova Favela v25 (`7717aa5`, branch separada) também precisa de baseline próprio.

## 2. Leitura real do projeto: onde o trabalho cresce

| Componente / código | Situação atual | Hipótese / impacto a aferir |
| --- | --- | --- |
| `modes/war/scripts/bot_director.gd::_physics_process` | 40 decisões de IA **compartilhadas por segundo**, índice de atores a cada 0,2 s, objetivo de esquadrão a cada 1,5 s; ainda chama `_move` para cada bot ativo em cada tick de 60 Hz | O pensamento já é escalonado; prioridade é o custo repetido da movimentação e simulação, e não apenas implementar `id % N`. Com 28 bots são até 1.680 chamadas de movimento/s; 50 bots seriam 3.000/s se todos em terra |
| `scripts/step_motion.gd::move` | Usa `CharacterBody3D.move_and_slide()` por passo e, quando bloqueado, vários `test_move()` para subir obstáculos, eventualmente um segundo `move_and_slide()` | Provável multiplicador de consultas em escadas/portas/muros. Medir tentativas, falhas, tempo e custo por região antes de substituir o controlador |
| `modes/war/scripts/player.gd::_physics_process` e `scripts/player.gd::_physics_process` | Postura, estado de arma, rig/pose e rotinas de ator remotas; atualização de hitboxes incorporada à hierarquia de apresentação | Custo por ator não desaparece quando a IA não decide. Deve ser isolado por diagnóstico em corpo vivo com decisões desligadas |
| `scripts/infantry_pose.gd`, `modes/war/scripts/human_rig.gd` | Computam transformações e IK de braços, armas, membros e hit regions. Há LOD de pose visual; servidor dedicado pode atualizar full-rate onde há hitboxes físicos | Principal candidato a **separação de rig de colisão e rig visual**, mas exigir testes de dano e equivalência |
| `bot_director.gd::_visible_enemy/_has_clear_shot/_avoid` | Busca em `game.players.values()`, gera consultas de raio e cria parâmetros em vários caminhos. Uma grade espacial **já existe para separação**, mas não elimina busca ampla em visão | Instrumentar contagens; aplicar distância²/FOV antes de raycast; cache curto só quando geometria/alvo não mudou; impor orçamento sem tornar o bot cego |
| `bot_director.gd::_near_actors` | Faz `append_array` de até nove células de grade por bot por tick | Alocações evitáveis; protótipo isolado já foi feito em `perf/bot-neighbors-r0i-20261106`, mas **ganho ainda não validado** por ensaio pareado com foco. Não anunciar vitória |
| `modes/war/scripts/game.gd::_physics_process` | Conta todos os participantes por objetivo a cada tick. Há distâncias euclidianas e loops por membro | Micro-otimização possível (distâncias ao quadrado/particionamento), mas medir antes: provavelmente secundário |
| Replicação em `bot_director.gd` | Somente host online simula a IA; serializa estado dos bots a cada 0,1 s em lotes de até quatro | Com 28 bots implantados: até sete lotes a cada 100 ms. Projetar interesse por cliente e compressão de deltas após medir banda, CPU e stutter; não reduzir cegamente frequência que afete visada |
| `scripts/player.gd` para ator `not is_local` | Em cliente remoto, não executa a mesma movimentação autoritativa; interpola/atualiza pose, mas ainda é ator completo com corpo e hit regions | **Não** afirmar que cliente simula cérebro de bot: a autoridade já está no servidor. Pilotar render proxy e máscaras de colisão **apenas no cliente**, guardando identificação/seleção; conferir hitreg e multiplayer |

### Jolt, Rapier e 50+ bots

O projeto **já utiliza `3d/physics_engine="Jolt Physics"`** em `project.godot`. Não há 'troca para Jolt' a fazer; substituir por Rapier exigiria nova integração, testes de diferenças de colisão e ganho real ainda não demonstrado. Rapier não substitui transporte de rede e seu determinismo entre plataformas exige condições/configurações específicas. O Godot 4.6 passou a oferecer Jolt por padrão para projetos novos, mas projetos existentes preservam configuração.

O modo Guerra tem `WarRules.CAPACITY=40`, `HUMAN_CAPACITY=12` e o online fill visa **14 bots de cada lado**. Logo, a meta **futura de 50 e poucos bots** não depende apenas de FPS: exigirá uma revisão explícita de capacidade, distribuição em times, protocolo/replicação, regras de entrada, servidor e testes com clientes. Não alterar esses limites nesta fase.

## 3. Priorização diferente: ganho plausível × risco × prova

**P0 — Medir antes de mexer (risco baixo).** Criar fixture parametrizada 0, 6, 12 e 28 bots na DESKTOP-R0I0NQG, mesmo Afeganistão, seed, câmera, Godot e GPU; intercalar A/B/A/B ou usar duas repetições invertidas. Cada coleta deve incluir 60 s válidos, warm-up, FPS médio, 1% low, P95/P99, `physics_ticks_per_frame`, GPU, CPU, física, temperatura/power/clocks, total de bots e quadros com foco. Separar no log cronologia de tiros e veículos. A JJ7 pode ter outra matriz, mas **nunca misturar máquinas como pares A/B**.

**P1 — Isolar 'cérebro vs corpo' (risco baixo se estritamente QA).** No mesmo cenário com bots reais implantados e presentes: (A) normal; (B) diretor parado, personagens vivos/renderizados e física de atores preservada; (C) atualização de pose visual suprimida, mas colisores preservados (somente QA, não compartilhar como gameplay); (D) simulação dos corpos parada, apenas QA para construir um teto teórico do custo de movimentação. A diferença de FPS entre A e B identifica carga da lógica autoritativa; B e C indicam custo da pose; C e D estimam custo do movimento físico. **Nenhum desses modos é uma partida jogável**; não prometer ganhos aditivos, pois mudanças também alteram carga de IA e renderização.

**P2 — Perfil granular do movimento (baixo risco de instrumentação).** Instrumentar `GameStepMotion`: número/tempo de `move_and_slide`, `test_move` por direção, sucesso/falha de subida, tempo de recuperação de piso, distribuição por bot. O código já possui `--step-probe`, cache **experimental** de falha de degrau (`--experimental-bot-step-cache`) e `GamePerformanceProbe`; aproveitar em vez de criar outro coletor. Cache teve P99 inconsistente e não é default. Testar desativação de degrau **só como teto diagnóstico** e comparar com otimização real guardada por colisão/posição/heading. Validar escadas, atalhos, rampas e telhados da Favela.

**P3 — Simplificar contato entre bots (risco médio).** Testar, em branch/flag QA, máscaras que impedem somente contato corpo-corpo bot-bot; manter cenário, humanos, balística e hit regions. Continuar separação por steering e checar empilhamento/atravessamento. Se for benéfico, integrar com máscaras diferenciadas para mover corpos e atingir projéteis. Simular 28 bots juntos em uma passagem estreita e registrar colisões/framerate/dano.

**P4 — Reuso de percepção (risco médio).** Contagem de raycasts por funcionalidade; reaproveitar candidato por setor da grade existente; filtrar `distance_squared` e FOV antes de `intersect_ray`; invalidar cache de visibilidade quando alvo, cobertura, arma ou posição mudarem significativamente, expiração inicial 100–200 ms apenas como **hipótese a testar**. O bot sob ataque ou com inimigo próximo usa prioridade alta. Verificar tiros através de parede/cobertura e reacção aceitável.

**P5 — Separar autoritativamente hitboxes e pose visual (alto potencial, alto risco).** A branch `ia/fpp-p1k-retomada` já possui ensaios com 28 atores/16 regiões por ator que **pioraram** o custo do piloto: relatório `docs/FPP-TPP-P1K-CUSTO-20261106.md` observou aumento de cerca de 63% da mediana pareada no servidor Linux e 68% em Windows no ensaio específico, com controle A/A instável. **Não reutilizar piloto nem declarar economia sem reparar a regressão.** Desenhar pose mínima para hitbox: cápsula corporal e regiões essenciais independentes da malha cosmética, atualização sob demanda para tiros/ação; clientes interpolam aparência. Provar equivalência de dano em prone/crouch/lean/recarga/arma/veículo, network ENet/DTLS e hitbox history.

**P6 — LOD *seletivo* e reversível (alto risco de gameplay).** A proposta não é reduzir a física global de 60 Hz, e sim, depois de separar hitboxes, reduzir atualização de **decisão, animação e movimento não-crítico de bots suficientemente longe de qualquer humano**. Exigir reversão imediata ao entrar em combate, ser observado ou estar perto de projéteis; evitar reduzir ticks de `CharacterBody3D` sem uma prova de colisão e trajetória. O repositório possui `tests/perf200_bot_lod_prototype.gd` **de propósito fora da versão de produção**, com advertência explícita sobre hitbox history/authoridade. Não repetir esse protótipo como solução aprovada.

**P7 — Mundo físico e renderização (risco médio).** Avaliar custo do cenário sem bots e com bots, formas estáticas de colisão repetidas, excesso de nós, sombras dinâmicas, draw calls, transparência e particionamento de `MultiMesh`. A GPU no Afeganistão mudou só ~0,25 ms de média nas quatro rodadas, então **não** começar pelo downgrade gráfico lá; a Favela v25 merece análise específica. `MultiMesh` não permite culling por instância, devendo ser particionado por setor se realmente necessário.

**P8 — Rede e escalonamento para 50+ (alto risco e etapa futura).** Medir o servidor autoritativo e um cliente remoto em máquinas diferentes; taxa de estados dos bots, atualizações ENet, banda/peer e custo do cliente. Usar proxies visuais sem IA/física **somente no cliente** quando a autoridade de dano permanecer no servidor. Testar reconexão, atrasos, entrada/saída e relevância por distância. Somente depois rever `CAPACITY=40`, `HUMAN_CAPACITY=12` e `14×2`.

**Baixa prioridade no momento:** trocar motor de física; enfileirar toda IA em `WorkerThreadPool` (SceneTree e consultas físicas não são chamadas seguras em workers sem separar os dados); reduzir indiscriminadamente `Engine.physics_ticks_per_second` (jitter, latência e servidores); transformar o mapa em heightmap exclusivamente (impreciso em tetos, prédios, escadas e interiores). `Engine.max_physics_steps_per_frame` normalmente é 8: aumentar o teto não elimina trabalho e pode piorar realimentação de travamentos.

## 4. Critérios de qualidade para promover qualquer otimização

- Pelo menos duas rodadas válidas por condição, ordem intercalada e mesmo computador/mesmo **commit de mapa**; ideal três ou mais para P99. Dados brutos e falhas de foco devem ser preservados e rotulados.
- Não degradar 1% low, P99 ou contador de quadros >33/>50 ms. Priorizar **cauda**, não apenas FPS médio.
- Preservar 28 bots implantados e sua capacidade de detectar, perseguir, atirar, recarregar, ocupar objetivos, entrar/sair de veículos e movimentar-se nas escadas (inclusive Favela v25).
- Jogadores reais continuam a ter física responsiva 60 Hz. Um bot distante não deve ganhar invulnerabilidade, mover-se por parede ou deixar de ser atingível.
- Confirmar no servidor e em cliente real: dano, hitboxes, poses, tempo de autoridade/ENet, estabilidade do frame, movimento e acessos. Uma câmera parada não substitui uma partida humana.
- Publicar commit exato, diferenças, configuração, métricas por hardware, JSON/CSV/logs, veredito **válido / inválido** e PR. Nunca integrar experimental sem passar os gates.

## 5. Referências técnicas externas consultadas

- [Godot — CPU optimization (nós, física, profiling)](https://docs.godotengine.org/en/stable/tutorials/performance/cpu_optimization.html)
- [Godot — CharacterBody3D e move_and_slide](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html)
- [Godot — APIs thread-safe](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html)
- [Godot — WorkerThreadPool](https://docs.godotengine.org/en/stable/classes/class_workerthreadpool.html)
- [Godot — Physics interpolation](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/physics_interpolation_introduction.html)
- [Godot — Engine physics step limit](https://docs.godotengine.org/en/4.6/classes/class_engine.html)
- [Godot — MultiMesh e culling](https://docs.godotengine.org/pt-br/4.x/tutorials/performance/using_multimesh.html)
- [Godot 4.6 — Jolt padrão em **novos** projetos](https://godotengine.org/article/godot-4-6-all-about-your-flow/)
- [Rapier — determinismo e condições](https://rapier.rs/docs/user_guides/rust/determinism/)

## Veredito e decisão

**O gargalo associado aos bots é consistente**, mas ainda não está corretamente decomposto. O código mostra que a IA já é rate-limited, enquanto corpos, rig e movimento são atualizados frequentemente. Ordem recomendada: **A/B cérebro versus corpo → perfil de `GameStepMotion` → contato bot-bot → percepção → separação segura de hitboxes/visual → LOD físico cuidadosamente validado**. Manter 28 bots é o objetivo atual; arquitetar 50+ depois de estabilizar CPU, P99 e rede. Nenhuma estimativa de FPS pós-otimização foi reivindicada.
