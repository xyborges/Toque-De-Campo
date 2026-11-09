# Candidata de integra??o R2C ? piloto protegido (09/11/2026)

## Decis?o e escopo

- Branch: `ia/r2c-release-preview-20261109`, criada de `origin/main ce2653e`, com merge `661539d` da branch de QA `ia/r2c-enet-qa-20261109`.
- **Apta para revis?o e PR como piloto experimental opt-in. N?o ? um lan?amento p?blico pronto.**
- C?digo R1A/R1B/R1C/R2A/R2B/R2C e regress?o ENet foram integrados apenas nesta branch; nenhuma build publicada, nenhum push direto para `main`.
- `R2C` segue **OFF por padr?o** e, mesmo com flags habilitadas, afeta exclusivamente o jogador local **offline, TPP, G3**, vivo, em p? e em situa??o n?o concorrente. N?o ? ativada para bots, remotos ou servidores online; n?o modifica autoridade nem protocolo.
- N?o confundir com a candidata paralela 1.13.10, que tem dono e reservas pr?prias. Esta branch n?o a altera.

## Gates reexecutados

| Gate | Resultado |
| --- | --- |
| `tests/realismo_r2c_pose_frame.gd` | 129/129 PASS, exit 0 |
| `tests/realismo_r2c_states.gd` | 172/172 PASS, exit 0 |
| `tests/realismo_r2c_world_pilot.gd` | 105/105 PASS, exit 0 |
| **F?sica local total** | **406/406 PASS**, f?sica 60 Hz |
| `tests/run_war_locomotion_network.py` no Afeganist?o | **18/18 PASS** (5 servidor, 1 m?vel, 12 observador), ENet/DTLS real, 3 exit 0, sem erros |
| Integra??o Git sobre `origin/main` | `git merge-tree --write-tree` exit 0; merge real na candidata sem conflitos |
| Manifesto preparado `afghan` | READY v15 |

**Limite importante:** a regress?o ENet verifica a locomo??o existente e o transporte, n?o uma ativa??o de PoseFrame remoto; a su?te local verifica o gate que bloqueia o remoto.

## Performance ? GTX 1650, 22 bots, Favela, Forward+ 1080p, M?dio 100%, 60 segundos

Dois ensaios sequenciais v?lidos, 100% de foco, mesma fixture de movimento G3, mesmos par?metros e 60 Hz. Sa?das brutas versionadas em `docs/benchmark-results/r2c-release-20261109/`.

| M?trica | R2C OFF | R2C ON |
| --- | ---: | ---: |
| FPS m?dio | 41,1120 | 42,9402 |
| P95 (ms) | 37,440 | 35,372 |
| P99 (ms) | 47,903 | 47,627 |
| Frames com R2C ativa | 0 | 318 |
| C?digo de sa?da / valid | 0 / true | 0 / true |

**N?o h? regress?o percept?vel neste ?nico par, mas tamb?m n?o h? evid?ncia estat?stica de ganho.** Os dois perfis falham a meta de ~60 FPS/P99 inferior a 33,3 ms na Favela com 22 bots. Precisam ser repetidos em pares alternados A/A e A/B, ao menos cinco pares x 60 s, antes de uma decis?o de desempenho definitiva. O gargalo da popula??o n?o foi corrigido nesta branch.

## Como optar pelo piloto local em QA

Em um terminal PowerShell, configurar **apenas no processo de teste**:

```powershell
$env:TDC_TACTICAL_MOTION_PILOT = "1"
$env:TDC_TACTICAL_BODY_PILOT   = "1"
$env:TDC_TACTICAL_WORLD_PILOT  = "1"
```

Depois iniciar o cliente Godot da branch e entrar no Guerra **offline**, com G3, em terceira pessoa. Para voltar ao comportamento padr?o, remover as vari?veis ou defini-las como `0`. O c?digo faz gate de seguran?a adicional; habilitar flags n?o libera automaticamente bots, PvP, FPP, crouch, prone, ve?culos, ADS ou disparos.

## Bloqueios para ativa??o geral e publica??o de build

1. Integra??o f?sica com o CollisionRig/P1k e as 16 regi?es autoritativas em servidor, remotos, LOD, IK, arma e tiro/dano. O P1k tem hist?rico de regress?o CPU n?o homologada.
2. Homologa??o de desempenho A/A/A/B, FPS m?dio e P95/P99 com 22 bots, incluindo casos de 28 bots, e sem quedas relevantes de foco ou concurr?ncia.
3. Valida??o real PvP de dano/regi?es, morte/respawn, ve?culos, crouch/prone, LOD e tiros at? ~1.700 m. A prova ENet existente n?o cobre tudo isso.
4. Corre??o e revalida??o do pipeline de importa??o fria Godot, que j? apresentou crashes e assets sem cache em worktrees novas.
5. Consist?ncia dos manifestos preparados dos mapas Ucr?nia e Favela; n?o desativar a checagem de hash.
6. Integra??o com a candidata geral 1.13.10, preflight de release, vers?o/build e pipeline de publica??o separados.

**Veredito:** pode entrar como *c?digo de piloto opt-in* em PR para `main`, mantendo OFF por padr?o. **N?o liberar a R2C f?sica para todos os jogadores e bots**, nem anunciar o recurso como acabado ou publicar build automaticamente.
