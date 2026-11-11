# LOD visual dos personagens remotos no cliente — 10/11/2026

## Objetivo e limites

Reduzir CPU por personagem distante sem alterar a frequência dos tiros, física do Jolt, replicação de rede, processamento de input ou hitboxes autoritativas. O `WarPlayer._animate_walk()` já possuía LOD de 30/15/8 Hz por distância para personagens remotos (faixas 80 m/250 m). O custo de braços/arma/torso e aplicação de pivôs continua significativo em cenas densas; converter isoladamente setters do tronco para C++ havia piorado o P99 gráfico em outro piloto. O problema real inclui frequência de chamadas e custo total de cena, não só a linguagem dos cálculos.

Branch `ia/gde-client-visual-lod-20261110`, derivada do piloto C++ anterior `91ac148`, separada da `main`. O piloto anterior de tronco nativo continua desligado por padrão; o C++ já aprovado para IK/separação mantém sua política anterior.

## Implementação

`modes/war/scripts/client_visual_lod.gd` (`WarClientVisualLOD`): pequena política compartilhada de câmera por physics tick. `_update_camera()` captura posição e direção do viewport uma vez a cada tick, mesmo com 28+ personagens consultando, evitando a mesma chamada de busca da câmera por NPC. O cache é indexado por `Engine.get_physics_frames()` e ID do viewport; quando a câmera é inválida, usa a posição do jogador local e **não ativa** classificação traseira.

`WarPlayer._animate_walk()`: ativa o novo scheduler **somente** no cliente multiplayer não autoritativo, em personagens não locais, por padrão na branch de desenvolvimento, desde que `--war-client-visual-lod-legacy` não esteja presente; a flag antiga `--experimental-client-visual-lod` permanece inofensiva. Nos outros casos, usa rigorosamente a lógica de LOD de distância anterior. Não modifica intervalo dos personagens próximos (distância inferior a 25 m), nem dos que estão à frente da câmera. Classifica atrás com histerese angular e só a partir de 25 m, reduzindo trabalho de pose que o jogador não vê. O máximo entre atualizações continua **250 ms**, sem congelamento permanente. Ao voltar para frente, a pose é calculada no primeiro physics tick mesmo que o intervalo traseiro ainda não tenha vencido. Trocar arma, postura ou gadget força pose imediatamente.

| Distância | Cadência anterior | Nova cadência atrás da câmera |
|---|---|---|
| Menos de 25 m | 30 Hz | 30 Hz, inalterada |
| 25–80 m | 30 Hz | 10 Hz |
| 80–250 m | 15 Hz | 5 Hz |
| A partir de 250 m | 8 Hz | 4 Hz |

`WarPlayer._swim_physics()` também elimina repetição de `exp(-delta*18)` para interpolar posição/yaw/pitch de personagens remotos nadando: calcula uma única vez por tick por personagem e reutiliza nas três componentes. Não altera resultado numérico; não há qualquer mudança no servidor de física.

## Gatilhos de segurança e fallback

- Local player (FPP/TPP) sem decimação.
- Servidor dedicado e servidor host: preservados; hitboxes autoritativas e Jolt continuam no ritmo atual.
- NPCs e players de outros modos que não usam `WarPlayer` preservados.
- Distância próxima (menos de 25m): ritmo anterior.
- Retorno à câmera, troca de arma, troca de postura e troca de gadget: atualização antecipada para evitar armas/poses visualmente atrasadas.
- LOD cliente não reduz frequência de network RPC, físicas de `_physics_process`, som, movimentação interpolada ou damage registration.

`tests/client_visual_lod_qa.gd` instancia um `WarGame` de fixture e valida tiers, classificação traseira com histerese, câmera real, volta ao campo de visão, troca de arma e a desativação do LOD no servidor offline. **80/80 checks PASS**, incluindo 1 retorno ao campo de visão e amostras de atualização traseira dispensadas.

## Multiplayer real ENet/28 bots (teste inicial)

`tests/client_visual_lod_network.gd` reaproveita por herança `war_frame_pacing_network.gd` e imprime métricas do novo escalonador após as três fases existentes (idle/movimento a pé/tanque). O runner auxiliar externo usa contas de testes locais, certificados TLS autoassinados temporários em `work/security182` (não versionados), porta UDP loopback livre e APPDATA isolado. Não altera nenhuma máquina de produção.

Primeira execução `candidate-r1` com servidor local headless, cliente gráfico real Forward+ GTX 1650, **28 bots no servidor e 29 jogadores no cliente**. Todos os asserts de servidor/cliente passaram; client final registrou **39.059 ticks de pose traseira dispensados, 9 retomadas imediatas ao campo de visão**, 9.364 atualizações dianteiras e 4.764 traseiras. As fases idle, foot e tank concluíram sem falhas e com movimento replicado (cliente teve 6→11 correções acumuladas, dentro da mesma lógica de rede já existente). Este teste confirma execução real do novo caminho; **ainda não comprova ganho de FPS**, que requer comparar com `--war-client-visual-lod-legacy` em condições equivalentes.

## Critérios de promoção

1. Executar pares de cliente gráfico ENet AB/BA com mesmos 28 bots, verificar P50/P95/P99 por fase, foco da janela, número de poses reais e estabilidade do servidor.
2. Concluir QA de transições de arma, postura, morte, respawn, áudio e veículo em 2 clientes reais; não afetar hitboxes autoritativas.
3. Somente habilitar por padrão se o FPS/P95/P99 realmente melhorarem, sem popping perceptível ao virar câmera. Caso contrário manter piloto experimental ou rejeitar sem merge na `main`.
4. Respeitar branches de outras IAs (R2C/P1K, física dos bots e nova Favela) e evitar modificar o rig físico em paralelo.


## Atualização final do piloto — benchmark EXCLUSIVO Full HD com GTX 1650

Todos os testes ENet desta fase foram executados em **Godot 4.7.2 Vulkan Forward+ / NVIDIA GTX 1650**, **tela cheia exclusiva** (modo 4), monitor e viewport físico **1920 × 1080**, **Médio, qualidade LOD 1 e escala interna 1,00 (100%)**, VSync desabilitado, FPS desbloqueado. O teste falha se resolução, escala ou tela cheia não coincidirem. O servidor era dedicado headless na mesma máquina (loopback) com 28 bots; o cliente tinha 29 personagens replicados. **Este fixture é PVP Deserto, não Favela**; uma validação de mapa Favela permanece separada.

Ordem real **LOD novo → legado → legado → LOD novo**. As três fases mediram idle, deslocamento a pé e tanque, com cerca de 20 segundos de simulação por fase. A tabela agregada usa todos os `frame_ms` capturados; média FPS = 1000 × N / soma(ms), não apenas 1000/P50. Para reprodução, os relatórios **completos do cliente e servidor** e o sumário calculado estão em `docs/benchmark-results/client-visual-lod-fhd-20261110/`. R2 mediu explicitamente 2.967/2.967 frames com foco no legado e 3.112/3.112 no novo; em R1 foi verificada tela cheia, mas ainda não havia contador interno de foco por frame (um monitor externo reativava a janela).

| Teste | FPS médio | P50 ms | P95 ms | P99 ms | Frames ≥33,33 ms |
|---|---:|---:|---:|---:|---:|
| LOD novo — R1 | **43,74** | **22,034** | **30,140** | **33,894** | **39** |
| Legado — R1 | 41,95 | 23,128 | 31,581 | 35,132 | 66 |
| Legado — R2 | 41,60 | 23,459 | 31,750 | 36,098 | 82 |
| LOD novo — R2 | **43,68** | **22,161** | **29,881** | **33,186** | **29** |

O caminho novo aumentou FPS médio **4,27% e 5,00%** nos respectivos pares; reduziu P95 **4,56% e 5,89%**; reduziu P99 **3,52% e 8,07%**. Por fase, a melhora de FPS médio no movimento a pé foi **5,31% e 6,77%**. A fase de tanque foi aproximadamente neutra no R1 (P99 pior), mas melhor no R2; não extrapolar este ganho para veículos em geral.

**Profiling de CPU (só cliente):** tempo médio por `player.pose` caiu de 0,08536 → 0,06914 ms (R1) e 0,08608 → 0,06864 ms (R2); `player.remote.physics` caiu 0,15450 → 0,14249 ms e 0,15588 → 0,14193 ms. O servidor continuou executando 28 bots; fases completas sem falhas de entrada, deslocamento, replicação, tanque ou inventário. O LOD traseiro dispensou **33.484/33.824** atualizações candidatas nas duas execuções, com **9 retornos à câmera** em cada. Não se saltou a física, rede nem hitboxes autoritativas.

**Decisão:** promover o escalonador de pose remota para padrão **nesta branch de desenvolvimento**, pois os dois pares gráficos foram positivos. `--war-client-visual-lod-legacy` reverte imediatamente à regra de distância anterior. O C++ do tronco total continua **opt-in** porque piorou FPS nos testes anteriores. **Não integrar automaticamente a `main` / não publicar o jogo** sem rever compatibilidade com o estado atual do GitHub, P1k/R2C e multiplayer de produção; neste teste havia apenas um cliente humano e a rede era loopback. O objetivo é melhorar FPS sem tornar as atualizações físicas autoritativas menos frequentes.

## Regressões finais após ativar o LOD por padrão na branch

- `tests/client_visual_lod_qa.gd`: **81/81 PASS** no modo padrão e **81/81 PASS** com `--war-client-visual-lod-legacy`.
- `tests/prone_weapon_pose_validation.gd`: **1.126/1.126 PASS**.
- `tests/gde_arm_runtime_qa.gd`: **2.700/2.700 PASS** (150 cenas de braços/armas reais).
- `tests/gde_native_separation_qa.gd`: **20.600/20.600 PASS**.
- `tests/gde_native_separation_runtime_qa.gd -- --experimental-native-separation`: **720/720 PASS**, 90 forças não nulas, 60 ticks. Este teste requer explicitamente essa flag de QA, apesar de a política C++ já estar ligada por padrão; a primeira chamada sem a flag foi bloqueada intencionalmente pelo próprio teste, não por falha do jogo.
- Os **quatro testes gráficos ENet Full HD exclusivos** (cliente+servidor) finalizaram sem erros de gameplay, replicação e veículo, e todos registraram 28 bots autoritativos.
- Espaço no SSD `C:`: **91,9 GB livres**, então **não foi necessário apagar backups, worktrees ou arquivos antigos**.

O LOD visual é uma otimização **GDScript de quantidade de trabalho** combinada com os backends C++ anteriores, não uma substituição total do Godot por C++. Os sistemas de IA/veículos/projéteis ainda exigem avaliação própria e são potencialmente dominados pelo motor de física nativo; não prometer ganho só por mudar de linguagem.
