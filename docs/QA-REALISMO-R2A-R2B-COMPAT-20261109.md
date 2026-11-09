# Auditoria independente — Realismo R2A/R2B e compatibilidade P1k

- **Data:** 09/11/2026
- **Jogo:** Toque de Campo, Godot 4.7.2, Windows, Forward+ na GTX 1650
- **Base do ramo de realismo:** `origin/main a7b9010`
- **Candidato exato:** `origin/ia/realismo-r2b-g3-fpp-20261109 @ 52079b0`
- **QA isolada:** `ia/qa-realismo-r2b-20261109` (worktree independente, sem editar `main`)
**Flags do piloto:** `TDC_TACTICAL_MOTION_PILOT=1` **e** `TDC_TACTICAL_BODY_PILOT=1`. Ambas OFF por padrão.

## Escopo dos commits, verificado no Git
- `2e505de` R2A: contrato matemático puro `modes/war/scripts/tactical_body_pose.gd`; **não grava** `Pelvis`, `Torso` nem físicas.
- `56fc735` R2B: pequeno acréscimo à `WarLocomotion.pose_weapon()` para girar **somente** `view_root.rotation` do jogador **local, G3, FPP, em pé**, sem recarga/ADS/tiro/granada/veículo.
- `52079b0`: documenta o gate físico, sem mudanças de runtime. A cadeia inclui os trabalhos prévios R1A/R1B/R1C.
- Nenhum desses commits modifica `scripts/player.gd`, `modes/war/scripts/player.gd`, `modes/war/scripts/human_rig.gd`, `collision_pose_solver.gd`, `collision_rig_proxy.gd`, `bot_director.gd` nem os pacotes ENet.
- Os outros ramos experimentais de IK e dirty guard de pose também não têm sobreposição de arquivos com as novas alterações R2A/R2B. **Ausência de conflito textual não é homologação de FPS em multiplayer.**

## Verificação executada novamente na máquina principal (Godot 4.7.2, flags ON)

| Fixture | Resultado | Comentário |
| --- | --- | --- |
| `realismo_r2a_body_pose_contract.gd` | **33/33 PASS**, exit 0 | Saídas matemáticas determinísticas, quadril/tronco físicos intocados |
| `realismo_r2b_g3_body_pose.gd` | **93/93 PASS**, exit 0 | 18 situações FPP/TPP, ADS, tiro, reload, granada, morte, veículo, arma não G3 e remoto; arma real e corpo inalterados |
| `realismo_r1a_motion_weight.gd` | **8/8 PASS**, exit 0 | Peso longitudinal |
| `realismo_r1b_lateral_weight.gd` | **13/13 PASS**, exit 0 | Peso lateral |
| `realismo_r1c_landing_weight.gd` | **16/16 PASS**, exit 0 | Contato visual |
| `realismo_r1c_physics_landing.gd` | **10/10 PASS**, exit 0 | Primeiro chão no frame 28; apresentação de impacto no 29 (em solo) |
| `optics_universal_validation_20261103.gd` | **242/242 PASS**, exit 0 | AK, FAL, G3, sniper, quatro ópticas; bandeiras R1/R2 ON |
| `realismo_r2b_g3_calibration.gd` | **25/25 PASS**, exit 0 | GTX 1650, Forward+, 1280×720; quatro capturas neutral/acceleration/strafe/landing; câmera e arma real invariantes |

**Total:** 440 verificações aprovadas, nas oito suítes. Os cenários visuais são pesos controlados; não substituem combate real com bots e rede.

### Microbenchmark independente
`realismo_r2b_pose_benchmark.gd`: 5 pares A/A e A/B, 28 atores sintéticos × 720 quadros (20.160 actor-frames), mas só 1 personagem local FPP invoca R2B:
- A/A mediana diferença: **−0,074 ms / lote** (ruído);
- A/B mediana diferença: **+1,279 ms / 720 ticks**;
- custo estimado: **1,776 µs / tick local FPP**, sem GPU, rede ou física;
- não há medição concluída de impacto em FPS/P95/P99 com 28 bots no multiplayer; **não converter custo de pose em FPS projetado**.

O primeiro import headless do worktree de realismo encerrou com o erro nativo Windows `-1073741819` durante o cache frio, mas as oito suítes acima conseguiram executar na cópia de QA (incluindo renderização real). **Não assumir import de editor homologado** com base nos testes de execução.

## Compatibilidade com P1k
- Merge textual seco entre `origin/ia/fpp-p1k-physical-replacement` e `origin/ia/realismo-r2b-g3-fpp-20261109`: **sem conflitos** (`git merge-tree --write-tree`, exit 0).
- O merge completo dessas branches traria também mudanças de release 1.13.4–1.13.9, portanto **não foi feito**: isso não seria um teste isolado do realismo.
- Em vez disso, uma worktree `ia/qa-r2b-p1k-hybrid-20261109` foi construída sobre a ponta P1k `2e0d5e2`, aplicando **somente** os sete commits R1A→R2B (com `cherry-pick`, todos sem conflitos, ponta `8e168ab`). Não é `main` nem branch de lançamento.
- A worktree híbrida não tinha inicialmente índice `.godot`, de modo que o primeiro ciclo de testes exibiu erros de compilação de `class_name`. As classes existiam no repositório. O editor realizou a descoberta das classes (embora o processo de importação fria tenha terminado com `-1073741819`), e os testes rodaram em seguida.
- **R2B no P1k:** `realismo_r2b_g3_body_pose.gd` **93/93 PASS**, exit 0, incluindo ausência de escrita na hierarquia corporal, câmera e arma real.
- **P1A, hitboxes e distância:** `true_fpp_p1a_authority_hitboxes.gd` **PASS em 5 distâncias (10, 70, 150, 300, 1700 m)**, 13 regiões físicas e **zero erro de pose em seis ticks**, quando executado corretamente com `-- --true-fpp-p1a-authority`. Uma primeira execução sem esse argumento deu erro de até 2,459 m, e foi descartada por **piloto não habilitado**, não por regressão R2B.
- **P1B:** `true_fpp_p1b_collision_stance_motion.gd` exit 0 com R1/R2 ON.
- **P1G:** `true_fpp_p1g_collision_authority.gd` **31/31 PASS**, 0 falhas, `visual_stale_m=0`.
- **P1I:** `true_fpp_p1i_damage_ragdoll.gd` **24/24 PASS**, 0 falhas; valida braço, mão, perna, abdome/pelve, morte por headshot e ragdoll.
- **R1C + ópticas:** `realismo_r1c_physics_landing.gd` **10/10 PASS**, `optics_universal_validation_20261103.gd` **242/242 PASS**, ambos com flags ON.
- **P1J, ENet/DTLS real:** `tests/run_true_fpp_p1j_network.py` com três processos Godot independentes e certificado localhost de QA válido (em `work/`, não versionado): **servidor 15/15, atirador 2/2, vítima 2/2**, 0 erros, todos exit 0. **19 verificações multiplayer**.
- **Resultado do gate híbrido:** compatibilidade funcional R2B + P1k **PASS nos cenários exercitados**. Não confundir com aprovação de R2C física, benchmark gráfico de 28 bots, ou release. A branch híbrida contém somente cherry-picks experimentais, permanece **local** e não é para publicação.

## Veredito de engenharia
R2A é um contrato matemático puro que pode continuar como referência para etapas futuras. R2B em G3 local FPP está **funcionalmente validado no escopo visual especificado**, desligado por padrão. Não aplicar o quadril/tronco R2C aos pivôs físicos antes da homologação de P1k, de 28 bots (incluindo colisões por região e servidor), de arma/cano e de performance em partida. Nenhuma alteração foi integrada à `main`, build ou servidor pela QA.
