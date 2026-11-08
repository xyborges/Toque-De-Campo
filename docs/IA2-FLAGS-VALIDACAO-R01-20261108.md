# Validação experimental IA2 — armas, criação de cadáveres e limite de corpos (R01, 08/11/2026)

## Base e isolamento

- Repositório: `xyborges/Toque-De-Campo`; base testada: `origin/main` em `4e41854`.
- Máquina: `DESKTOP-R0I0NQG` (R01), GPU NVIDIA GTX 1650, monitor 1920×1080.
- Godot 4.7.2, Vulkan/Forward+ nos testes gráficos; 60 ticks físicos por segundo nas fixtures.
- Worktree isolada: `tdc-r01-ia2-flags-20261108`; branch `ia/r01-ia2-flags-20261108`.
- Nenhum script de produção modificado. Todas as três flags continuam **OFF por padrão** na `main`.
- Logs brutos/CSV locais (ignorados pelo Git): `work/r01-ia2-20261108/`.

## Testes A/B de CPU — cinco pares alternados por recurso

Fixture existente: `tests/ia2_respawn_ragdoll_benchmark.gd`, headless, 28 personagens remotos, mesma cena e Godot. Ordem invertida nos pares pares para reduzir efeito de aquecimento. Cada execução retornou exit code 0 e zero falhas.

| Cenário | Original (média) | Otimizado (média) | Redução no trecho medido | Amostra por execução |
| --- | ---: | ---: | ---: | --- |
| Refresh/reuso de arma remota | 5,7657 ms/lote | 2,6104 ms/lote | **54,73%** | 20 lotes de 28 atores, 560 eventos |
| Callback de rajada de cadáveres | 62,3417 ms/rajada | 0,8972 ms/rajada | **98,56%** | 4 rajadas de 8 mortes, 32 eventos |

**Interpretação:** reusar geometria evita reconstruções completas. A fila de ragdoll muda a distribuição temporal da criação; **98,56% não é redução de custo físico total**, tampouco FPS.

## Ensaios com GPU e janela — dois pares alternados por recurso

Mesma fixture com janela de 1920×1080 e renderer Vulkan/Forward+ na GTX 1650. **Não é um cliente multiplayer, não há 28 bots com IA, nem combate real.** O indicador de armas é `approx_frame_ms` (intervalo aproximado da operação de refresh); para ragdolls é `intervals_ms` (amostras da janela de apresentação, incluindo callback). O P99 é restrito às amostras dessas fixtures, não o P99 de uma partida.

| Indicador sintético | Original | Otimizado | Variação |
| --- | ---: | ---: | ---: |
| Armas — média aproximada por lote | 18,4055 ms | 16,8133 ms | **−8,65%** |
| Armas — P99 aproximado por lote | 32,5775 ms | 29,1590 ms | **−10,49%** |
| Ragdolls — média das amostras da rajada | 19,1608 ms | 16,3698 ms | **−14,57%** |
| Ragdolls — P99 das amostras da rajada | 75,0355 ms | 31,4540 ms | **−58,08%** |

Todas as oito execuções gráficas retornaram exit code 0 e zero falhas. Melhoras na cena controlada são promissoras, **não** prova de FPS/P99 melhores em 28 bots online.

## Regressões e compatibilidade

- `tests/ia2_ragdoll_cap_qa.gd`: exit 0, quatro checks; 12 mortes no mesmo quadro resultavam em 11 corpos no modo antigo e **10** com limite estrito; limpeza passou.
- **Novo** `tests/ia2_flags_combo_qa.gd`: exit 0, sem falhas. Reuso de arma remota sem reconstruir cano; troca de arma reconstrói; 12 mortes enfileiradas, teto de 10 corpos, 12 apresentações, morte local imediata (corpo criado sem entrar na fila), descarte de vida antiga e limpeza total.
- `tests/weapon_presentation_validation.gd`: 1.091 checks e zero falhas **tanto com flags OFF quanto ON**; teste headless.
- `tests/optics_universal_validation_20261103.gd`: 242 checks e zero falhas por configuração (AK, FAL, G3, sniper; quatro ópticas); teste headless.
- `tests/br_corpse_stack_validation.gd`: 24 checks e zero falhas por configuração; inventário e loot de cadáveres em BR, headless.

## Decisão

| Flag | Veredito | Estado |
| --- | --- | --- |
| `TDC_IA2_REUSE_RESPAWN_WEAPON` | Ganho de CPU consistente; não comprovado no cliente online com troca de armas/ópticas/FPP/TPP | **Manter OFF por padrão** |
| `TDC_IA2_DEFER_REMOTE_RAGDOLL` | Queda dos picos nas fixtures; adia a apresentação e não elimina a física | **Manter OFF por padrão** |
| `TDC_IA2_RAGDOLL_STRICT_CAP` | Corrige bug determinístico de teto; passou testes isolados e combinado | **Manter OFF por padrão até regressão de cliente real** |

**Status: aprovados para piloto controlado na R01, não homologados para ativação global.** O critério do documento `docs/INTEGRACAO-IA2-PERFORMANCE-20261106.md` exige cinco pares alternados em cliente ENet real, servidor dedicado, 28 bots, 1080p/Médio Forward+, mortes em rajada, trocas e ópticas, FPP/TPP, hitreg e integridade física, com FPS/P99 favoráveis acima do ruído. Essa etapa **não foi executada**. Não ativar no servidor nem integrar mudanças de defaults à main ainda.

Obs.: o experimento diferente de física/contatos de ragdoll na branch `ia/r01-ragdoll-fisica-20261108` foi reprovado em análise própria; **não confundir** com os três toggles IA2 validados aqui.

## Execução e rastreabilidade

As séries auditáveis dos 20 ensaios headless e 8 gráficos estão versionadas em `docs/benchmark-results/ia2-r01-20261108/all-runs.csv` e `docs/benchmark-results/ia2-r01-20261108/graphical-runs.csv` (decimais normalizados com ponto). Logs individuais completos permanecem somente em `work/r01-ia2-20261108/` na R01 (`weapons-*`, `ragdolls-*`, `graphical-*`, `reg-*`, `combined-qa-final.log`), fora do Git. Nenhum build ou log bruto foi incorporado.

**Próxima etapa para homologar:** cliente real da R01 conectado ao servidor dedicado de testes, 28 bots com combate, 5 pares A/B alternados por flag e métricas validadas de FPS médio, 1% low, P95/P99 e falhas de combate. Ativar somente o recurso que passar; publicar/mesclar após revisão do responsável pela integração.
