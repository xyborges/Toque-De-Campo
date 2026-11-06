# Diagnóstico IA 2 — Entrada, personagens e autoridade de teste — 28 bots

**Data:** 6 de novembro de 2026. **Entrega:** diagnóstico antes das otimizações, parcialmente concluído. **Decisão:** parar aqui para revisão; nenhuma alteração de desempenho aprovada.

## Integridade, escopo e máquinas

- Repositório: `xyborges/Toque-De-Campo`; branch exclusivamente de diagnóstico `ia2/diagnostico-entrada-cliente-v25-20261106`.
- **Commit-base do jogo:** `5fceacc` (Favela v25; mapa introduzido em `7717aa5`; importação/protocolo de benchmark compatível com `e828888`). Este commit já está publicado no GitHub antes deste diagnóstico. Não usar os antigos ensaios da `main@4bff4ae` como referência de FPS para esta matriz.
- Flags experimentais da Fase 2 **desligadas/não presentes** nesta base: `TDC_IA2_REUSE_LOS=0`, `TDC_IA2_REUSE_TRAFFIC_QUERY=0`. Não usar protótipos de CollisionRig, LOD físico ou IA desligada.
- **R0I (única máquina medida):** `DESKTOP-R0I0NQG`, Intel Core i5-3470, 4 núcleos/4 threads, 3,20 GHz; GTX 1650 presente para telemetria. Godot `4.7.2.stable.official.ed1daf0bf`, script em `--headless --max-fps 60`; não há renderização 1080p nem GPU de cliente.
- **JJ7 (cliente GTX 1650):** a máquina apareceu cadastrada, mas não respondeu a comandos do Desktop Commander e depois ficou **offline**. Não se coletou FPS/frametime/render CPU-GPU, RTT, jitter ou idade de estados com cliente real.
- **R0I como servidor de teste:** esta coleta **NÃO** iniciou um servidor de rede ENet, e sim o `WarGame` offline/headless com instrumentação por subclasse QA. O nome 'authority' indica execução local de lógica autoritativa, não comprovação de servidor dedicado multiplayer. NENHUM valor deve ser apresentado como desempenho do servidor real em rede.
- **Ubuntu publicado, 192.168.101.24:** pelo código, os serviços `toque-war-favela.service` e `toque-war-afghan.service` chamam `ToqueDeCampo.x86_64 --headless --max-fps 60 -- --war-server --war-map=favela/afghan`; as portas ENet declaradas são UDP 3017 (Favela), 3015 (Afeganistão) e 3014 (Ucrânia). TCP 22 respondeu, mas a tentativa SSH de leitura foi recusada por autenticação; portanto **não** verificamos serviço, commit ativo, processos, presença de jogadores nem carga real. **Nenhum acesso, reinício, implantação ou alteração de produção.**
- O online só preenche os 28 bots após pelo menos um humano admitido (`bot_director.gd::_online_targets()`). Um servidor vazio não serviria como amostra. O teste offline cria os 28 bots explicitamente e valida a população.

## Protocolo e limites

Fixture adicionada: `tests/ia2_authority_entry_probe.gd`; execução/telemetria em `tools/ia2_entry_probe_runner.py`. **Não altera arquivos de produção.** Usa `Time.get_ticks_usec()` e subclasse QA `tests/ia2_cost_game.gd` com métricas `IA2CostMetrics`. Seed 712907, `--headless`, 60 FPS limitados, 0 ou 28 bots; checagem de processos Godot concorrentes antes de cada coleta; aquecimento de 4 ou 8 segundos. Os pares não têm mesma duração: 30 s controles, 10 s amostras de entrada e 120 s estabilizados. **São observações exploratórias, não cinco pares A/B, e NÃO aprovam modificações.**

Registros por quadro: intervalo real entre `process_frame`, monitor de física/processamento do Godot, contagem de ticks e concentração de ticks em um quadro, P95/P99/máximo, picos acima de 50 e 100 ms. O `Performance.TIME_PHYSICS_PROCESS` pode ser atualizado esporadicamente; seu P99 amostrado **não é P99 real de duração de cada tick**. Escopos de scripts são *inclusivos* e se sobrepõem. A média de 60 ticks/s sem atraso crescente não garante P99 de tick inferior a 16,67 ms. O campo `max_nominal_tick_deficit_proxy` não é uma fila de física comprovada.

Telemetria GPU via `nvidia-smi` apenas do computador de testes, arquivada em CSV por caso; temperatura típica 33–34 °C durante as janelas, flags de limitação térmica SW/HW não ativas. Não é medição do cliente. Os arquivos contêm os timestamps Unix de início/fim, contagens e intervalos, para auditoria. Não houve relógios entre máquinas sincronizados.

## Entrada — construção e preparo

| Cenário | Janela (s) | Mundo (`world_build_ms`) | Até `join_ready` | Até bots prontos | Depois de `join_ready` até bots |
|---|---:|---:|---:|---:|---:|
| Favela 28 bots, primeira amostra | 10 | 5.183,8 ms | 10.059,6 ms | 10.521,8 ms | 462,2 ms |
| Favela 28 bots, repetição | 120 | 5.076,0 ms | 9.911,5 ms | 10.365,0 ms | 453,5 ms |
| Favela 0 bots, controle | 30 | 5.072,8 ms | 9.904,3 ms | 10.014,9 ms | 110,6 ms* |
| Afeganistão 28 bots, primeira amostra | 120 | 5.413,8 ms | 7.820,0 ms | 8.368,2 ms | 548,2 ms |
| Afeganistão 28 bots, repetição | 10 | 5.337,6 ms | 7.693,1 ms | 8.240,4 ms | 547,3 ms |
| Afeganistão 0 bots, controle | 30 | 5.442,8 ms | 7.847,2 ms | 7.974,5 ms | 127,3 ms* |

*Com 0 bots, 'até bots prontos' é um marcador QA após curto aguardo, não tempo de spawn.*

**Achado:** a construção do mundo levou aproximadamente 5,1–5,4 segundos em ambos os mapas independentemente de haver zero ou 28 bots. O tempo `join_ready` foi ~10 s na Favela e ~7,7–7,8 s no Afeganistão; só ~0,45–0,55 s adicional depois de `join_ready` correspondeu a completar 28 bots. Portanto, perfilar decomposição da preparação do mapa/recursos tem prioridade na frente de entrada. As diferenças entre primeira e repetição foram ~1–2%, mas **não houve limpeza controlada de page cache, medição de disco ou custo de shaders**. Não afirmar teste de cache frio controlado, nem que o jogador ficou bloqueado após liberar os controles (sem cliente real).

O código de cliente em `modes/war/scripts/game.gd::join_game()` pré-constrói o mundo **antes** do ENet, justamente para não deixar a rede sem resposta durante a construção. O servidor já distribui baseline em lotes com `war_baseline_ready` e registra espera/tempo de atores. Isto separa as possíveis travadas de construção local, baseline de rede e primeira apresentação gráfica, ainda sem medidas diretas dessas últimas.

## Estabilizado — 120 s em headless e controle 0 bots

| Métrica | Favela 0 bots (30 s) | Favela 28 bots (120 s) | Afeganistão 0 bots (30 s) | Afeganistão 28 bots (120 s) |
|---|---:|---:|---:|---:|
| Ticks por segundo real | 60,03 | 60,00 | 60,05 | 60,01 |
| Intervalo entre quadros — P95 | 18,32 ms | 24,44 ms | 17,54 ms | 26,73 ms |
| Intervalo entre quadros — P99 | 20,42 ms | 27,51 ms | 24,24 ms | 38,30 ms |
| Intervalo máximo | 39,17 ms | 71,73 ms | 50,08 ms | 142,10 ms |
| Quadros acima de 50 ms | 0 | 12 | 1 | 40 |
| Quadros acima de 100 ms | 0 | 0 | 0 | 4 |
| Quadros com ≥2 ticks | 2 | 41 | 4 | 110 |
| Quadros com ≥4 ticks | 0 | 1 | 0 | 24 |
| Disparos | 0 | 32 | 0 | 968 |
| Bots vivos/implantados: mínimo | 0 | 17 | 0 | 26 |

Com 28 bots, a Favela produziu 7.201 ticks e o Afeganistão 7.202 ticks durante aproximadamente 120 s. Os 28 bots **permaneceram cadastrados** em toda a coleta, mas mortes/respawns variaram. Não houve roteiro de combate equivalente: Favela 32 tiros, Afeganistão 968 tiros, 50 recargas e 1 granada. É incorreto atribuir as diferenças de P99 a um mapa exclusivamente. Mesmo mantendo ~60 Hz médios, 24 quadros no Afeganistão acumularam ≥4 ticks, e houve quatro picos acima de 100 ms: **a meta de cauda de latência não está comprovada**.

### Tempos de script (28 bots, 120 s): milissegundos por quadro do processo headless

| Escopo inclusivo | Favela média | Favela P99 | Afeganistão média | Afeganistão P99 |
|---|---:|---:|---:|---:|
| Diretor IA e movimento, total | 3,903 | 8,184 | 3,432 | 8,377 |
| `bot_move` dentro do diretor | 3,058 | 4,494 | 2,172 | 5,140 |
| `WarPlayer._physics_process` | 3,197 | 10,892 | 2,826 | 9,050 |
| Poses visuais/regions associadas | 1,410 | 8,727 | 1,231 | 6,504 |
| IK braços | 0,401 | 2,807 | 0,343 | 2,042 |
| Decisão de IA (`_think`) | 0,248 | 0,756 | 0,146 | 0,761 |

**Não somar escopos aninhados.** Em 0 bots, o ator humano local no teste ainda executa `actor.physics_inclusive` (~0,54–0,55 ms/quadro) e pose (~0,34 ms/quadro). Assim, 'custo fixo' não significa zero trabalho de personagem. O corpo e as poses executam na autoridade headless porque a árvore de transformações participa também das regiões autoritativas de acerto. **Não removê-las sem contrato CollisionRig/hitbox.** O servidor dedicado real pode ter caminhos diferentes.

## Diagnóstico e prioridade confirmada

1. **Entrada/instanciação do mundo:** custo de construção fixo relevante (~5 s) antes de `join_ready` nos dois mapas. Próxima medição deve discriminar carregamento de arquivos, criação de instâncias, recursos/materiais, scripts de mundo e estado inicial de cliente; registrar instante em que controles são liberados e picos subsequentes.
2. **Movimento e lógica física de personagens:** domina os tempos instrumentados frente ao cérebro; área de investigação da **IA 1**. Não fazer cortes de movimento sem preservar gravidade, colisões, interação, tempo simulado e estados de risco.
3. **Poses/IK/hitbox:** também custam CPU em headless; área de **IA 2 / CollisionRig**. Não otimizar até provar independência física das transformações. Um LOD visual que afete hitboxes autoritativas é inaceitável.
4. **Combate e P99:** investigar eventos de armas/recarga/colisões e acumulação de ticks, particularmente o Afeganistão. Padronizar intensidade/roteiro antes de comparar variações.
5. **Custo fixo sem bots:** medir separadamente em pares com a mesma duração e dados de CPU/disco. No controle, os atrasos da construção ainda aparecem; não aceitar ganhos com ruído grande.

**Condição para passar à próxima fase:** R0I servidor ENet real com 28 bots e ≥1 humano, JJ7 cliente gráfico real GTX1650 1080p/Médio, dois mapas, três janelas (entrada realmente fria, entrada aquecida e 120 s normal), período de combate reproduzível e dois clientes incluindo late join. Medir por tick (média/P95/P99/atraso), por quadro do cliente (FPS/P95/P99/CPU/GPU), RTT/jitter/idade de estados, relógios sincronizados e temperatura/proc. Executar A/A e cinco pares alternados A/B **depois de escolher cada intervenção**, não antes de confirmar confiabilidade. Registrar sync clocks e IDs de sessão compartilhados.

**Metas ainda não validadas:** cliente médio ≥60 FPS, P95 ≤25 ms, P99 ≤33,3 ms; servidor ENet 60 ticks/s P99 do tick ≤16,67 ms (alvo 12 ms); nenhuma travada >100 ms atribuível a carregamento após liberar controles. Nesta entrega não há métricas de cliente nem P99 real de tick dedicado.

## Auditoria, flags, hashes e arquivos

- Seis execuções sem erros (todas 0 ou 28 bots conforme solicitado; arquivo JSON individual, `.gpu.csv` e `.log` para cada uma), `sessions.jsonl` e `import.log`. As quatro medições com 28 bots têm população registrada do início ao fim; o controle 0bots valida ausência de bots.
- Uma possível limitação no QA: seus buckets de script são por `Engine.get_process_frames()` e cada valor inclui eventuais múltiplos ticks; esse custo não é exclusivamente `ms/tick`. A instrumentação também custa CPU. O controle 0bot e as amostras de 10s/120s têm durações diferentes.
- Os dados só refletem **a R0I em modo offline/headless**, nunca a JJ7 nem Ubuntu; sem rollback, build publicada, scripts produtivos alterados ou reinício.
- Arquivos exclusivamente novos: `tests/ia2_authority_entry_probe.gd` (e UID local se gerada), `tools/ia2_entry_probe_runner.py`, e `work/ia2-diagnostico-entrada-v25-20261106/`. **Arquivos de produção compartilhados com IA 1: nenhum.** Nenhum conflito com `bot_director.gd`, `player.gd`, `step_motion.gd`, rig de colisão ou cenas do mapa.
- Run ID é o nome individual de arquivo, contém mapa/quantidade/condição e horário; os timestamps da medição dentro do JSON usam Unix ms do mesmo computador. Sem sincronização de relógios entre hosts, **não** correlacionar as séries por horário absoluto.

**Próxima entrega pendente** (não simulada): real servidor × cliente × entrada na JJ7, em ambiente de teste separado da produção, com timestamp comum e controle do roteiro. **Parar agora e revisar antes de qualquer otimização.**
