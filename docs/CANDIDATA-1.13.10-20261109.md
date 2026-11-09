# Candidata 1.13.10 — coleta e seleção de branches (09/11/2026)

**Estado:** integração isolada de pré-release. **NÃO PUBLICADA, NÃO INTEGRADA À MAIN.**
Build de referência no Ubuntu: **1.13.9/build 97**, validada por HTTPS. `main`/`origin/main` de referência: `ce2653e` (RPG-7 calibrado, marcações por 100 m, QA ENet).

## Objetivo e escopo

Preparar a possível **1.13.10 / build 98** sem interferir no único prompt ainda em desenvolvimento (Caveirão 3D) nem em worktrees experimentais. Após `git fetch origin --prune`, inventário: 38 branches locais e 53 refs remotas não incorporadas. Muitas são variantes e relatórios de experiências reprovadas; não contar como 91 novidades.

Worktree: `campo-worktrees/release-11310-candidate-20261109`
Branch: `ia/release-11310-candidate-20261109`
Base: `ce2653e`. **Não executar push, build assinado nem deploy nesta fase de coleta.**

## Integradas SOMENTE à candidata, não à main

1. **Corrigir UTF-8 das atualizações** — origem `ia/release-notes-utf8-20261109`/`3696b53`; merge `179394b`. Corrige textos e geração de página, com teste para caracteres substitutos/mojibake. Teste Python: **3/3 PASS**.
2. **Bots: recuperação de obstáculos e ameaça de blindados** — `ia/bots-escape-armor-20261108`, commits `23a3daa` e `32efdc4`; merge `62e5371`. Adiciona waypoint temporário para fuga de bloqueio e busca cobertura contra APC/tanque ocupado. Padrões de defesa de objetivos continuam intocados; QA físico dedicado deve passar na base atual.
3. **Presença de tiros e dinâmica das explosões** — `origin/ia/r01-explosion-dynamics-20261109`, que já contém `0abd0c4`, `bb462d4`, `6bea316` e `25303d4`; merge `d1a40ce`. Inclui presença distante, limitador Master, compressor somente de explosões e testes. **Não** integrar `ia/audio-presenca-global-1108` novamente, pois está contida nesta branch. Na R01: testes áudio 326/326; multiplayer de explosões 144/144 (Ucrânia + Favela, 28 bots cada); nenhum WAV/MP3 foi regravado. Falta validar os merges da candidata nesta máquina e conferir desempenho/escuta humana.
4. **Manifesto Favela v29** — `21ea7db`, gerado da fonte real `tools/prepare_favela_manifest.py --write`. Corrige v28 obsoleto com **68 fontes**, hashes de conteúdo e de origem conferidos. O status permanece `testing` até homologação da candidata.

## Fora desta candidata (não interpretar como autorizado para produção)

- **Caveirão:** `ia/caveirao-cinza-3d-20261109` inclui cena isolada `5d09c4d`, mas existe sessão ativa `gpt6-caveirao-trucknose` e alterações não commitadas em `caveirao_cinza.tscn` e no novo `.glb`. Não tocar, mesclar ou substituir. Reavaliar APÓS conclusão, commit e QA de composição/colisão/LOD/servidor.
- **Favela V27, lajes:** `origin/ia/favela-v27-roof-diagnostic-20261109` inclui apenas testes e relatório. Testou 142 lajes e 706 amostras sem reproduzir tremor, recuo ou travamento. A queixa do jogador permanece **não resolvida**; não anunciar correção.
- **R2B/G3 FPP e realismo R1A–R1C/R2A:** o benchmark `ia/bench-realismo-r2b-jj7-20261109` terminou 5 pares/10 janelas, 28 bots reais e equivalência sem falhas, porém ~38 FPS com e sem R2B; **não homologado para publicação**. Mantê-lo opt-in OFF, sem mesclar nesta versão. P1k/CollisionRig também não passou gate de produção.
- **Bot pose dirty-guard / IK cache:** CPU isolada mostrou economia, mas o A/B gráfico não foi homologado; `ia/qa-bot-pose-main-20261108` reprova entrada em produção. `ia/ik-28bots-qa-20261108` rejeita ganho FPS/P99. Não incluir.
- **Caches de entrada da Favela (`ia2/entrada-mapas-integral-20261107`):** ganho headless isolado, porém P99 gráfico piorou; rejeitados para produção.
- **Branches históricas ou diagnósticas antigas:** revisar uma a uma antes de qualquer cherry-pick; não fazer merge em massa por nome ou por data.

## QA de integração executado na candidata — JJ7, 09/11/2026

- Godot 4.7.2: import/editor **exit 0**.
- UTF-8: **3/3 testes Python PASS**.
- Bots: `war_bot_escape_armor_qa.gd` **10/10 PASS**. Fuga do muro em 1 replanejamento, aproximação a 0,15 m do objetivo; APC ocupado detectado, desvio para cobertura real e recuo validado.
- Favela: `favela_operation_smoke.gd` **PASS**, 4.313 casas, 142 lajes transitáveis, 11.624 colisores, rotas 49. Manifesto **v29 / 68 fontes MATCH**.
- Mixer nativo: `combat_presence_audio_20261108.gd` **103/103 PASS**, ganho PCM medido a 400 m de **3,195×**, pico durante mistura estressada **0,89125**, sem overflow digital.
- Dinâmica de explosões: `r01_explosion_dynamics_20261109.gd` **25/25 PASS** no mixer real, 4 detonações simultâneas limitadas, audição a 400–600 m preservada.
- ENet/DTLS Favela: servidor e **2 clientes**, exit 0, **12 + 6 + 6 verificações PASS**. Este smoke NÃO simula 28 bots ou valida o cenário de explosões com os 28 bots simultâneos.
- Teste de origem R01 anterior ao merge: **144/144 verificações de explosões** em Ucrânia e Favela, com 28 bots em cada mapa; permanece **pendente repetir sobre este commit candidato**.
- O runner R01 de explosões tem paths específicos de `C:/Users/Microgate/Documents/Codex/2026-11-06/fa-a`; não executá-lo diretamente no JJ7 sem adaptar engine e certificados QA. A tentativa de `--help` só diagnosticou a ausência do executável nesse caminho, não contou como teste.

Os resultados originais estão nos arquivos ignorados `work/release-11310-qa/`. Não houve teste A/B de FPS nem deploy.

## Gates para anunciar build 98

- [x] Godot 4.7.2 import completo na worktree, exit 0, sem cópia indiscriminada de caches da main.
- [x] UTF-8 da página e notas preservados, 3/3 testes.
- [x] Favela manifesto v29 e circulação no smoke offline consistentes; ENet de 2 clientes aprovado. **Resta** validar 28 bots juntos.
- [x] `war_bot_escape_armor_qa.gd` PASS 10/10; bot recupera rota e evita APC. **Resta** regressão de captura/defesa em partida longa.
- [x] Mixagem nativa `combat_presence_audio_20261108.gd` 103/103 + `r01_explosion_dynamics_20261109.gd` 25/25 PASS com limitador sem clipping.
- [ ] Multiplayer local ENet/DTLS com 28 bots: partidas Ucrânia/Favela, explosões reais e colisões; validar eventuais `0xC0000005` de encerramento.
- [ ] Bench gráfico pareado GTX 1650, 1080p, escala 100%, Médio, foco de janela 100%: FPS, P95/P99, GPU, CPU, 28 bots; não piorar a cauda.
- [ ] Reavaliar mudanças do único prompt ativo (Caveirão) somente após `finish` do coordenador e commit completo.
- [ ] Revisar `git diff main...candidata`, emitir veredito e somente então integrar à main mediante autorização de lançamento.
- [ ] Se aprovada: incrementar versão, preparar build 98, assinatura, QA de instalação, preflight e deploy com proteção de jogadores ativa, conferindo manifesto e seis serviços.

**Regra operacional:** nenhum push, alteração na `main`, reset de worktree, limpeza destrutiva ou publicação faz parte desta rodada de coleta.
