# Auditoria consolidada de otimização — IA 1 + IA 2
**Toque de Campo | 07/11/2026 | candidato experimental, sem lançamento público**

## Estado e origem
- Fonte oficial: `xyborges/Toque-De-Campo`, `origin/main@ee969af`. Atualização publicada: **1.13.8 / build 95**.
- Worktree isolada `ia/auditoria-otimizacoes-20261107` no desktop JJ7, Godot 4.7.2/Jolt.
- Esta auditoria compara os trabalhos das duas IAs sem mesclar branches experimentais inteiras. Nenhum binário, launcher, manifesto, assinatura ou servidor de produção foi alterado.
- O benchmark **não** comprova 60 FPS nem ganho em P95/P99 do cliente. Carregamento e execução contínua são métricas diferentes.

## Matriz de decisão
| Intervenção | Evidência | Decisão |
|---|---|---|
| Cache do planejamento de lotes da Favela (IA 2, `64ad9dc`) | No JJ7, cinco pares: rotina 992,56→302,69 ms (−69,50%); construção 4.562,04→3.934,72 ms (−13,75%); hashes/colliders idênticos | **Aceita para branch experimental, opt-in OFF** |
| Omitir planejamento puramente visual da encosta em servidor headless (IA 2, `d56cce2`) | Smoke JJ7: 1.031,95→77,85 ms na rotina isolada; árvore/posições físicas idênticas. Relatório original R0I: cinco pares, −19,38% na construção no protótipo v25 | **Aceita para branch experimental, opt-in OFF**; medir no servidor dedicado oficial |
| Reutilizar arma remota no respawn | Custo isolado -53,63%; em partida Afeganistão cinco pares, 28,09→25,90 FPS (pior) | Já está na main com flag OFF; **não ativar** |
| Enfileirar ragdolls remotos | Diminui pico concentrado de callbacks, mas não o custo total e introduz atraso visual; P99 cliente inconclusivo | Já na main com flag OFF; **não ativar** |
| Limite estrito de 10 cadáveres | Correção funcional: 11→10 corpos; cinco pares Favela 23,30→23,23 FPS | Bugfix experimental na main; **não afirmar ganho FPS, não ativar globalmente** |
| Reuso de LOS e query de tráfego | LOS muito abaixo do ruído; tráfego piorou FPS/P99 em teste exploratório | **Reprovado**, não integrar |
| Raios de projéteis visuais 30 Hz | Rotina −4,89%, ruído controle 14,85%, sem prova de gameplay real | **Reprovado**, não ativar |
| Construção staged da Favela | +6,01% no tempo até `join_ready` do protótipo | **Reprovado** |
| Cache de `BoxShape3D` e anexação diferida de setores | +2,36% e ~−2,16% no tempo de entrada, respectivamente; abaixo do ruído ou regressão | **Descartados** |
| Skip de arquitetura headless, exceções internas de ragdoll | Regrediu ou não ultrapassou ruído; patches descartados pela IA 2 | **Descartados** |
| IA 1: movimento, degraus, `move_and_slide`, `test_move`, colisões bot×bot, poses | Branches `ia/ia1-fisica-bots-0611`, `ia/fisica-bots-revisao-0611` e `ia/ia1-pose-scopes-20261107`: instrumentação/testes, ainda sem ganho final de FPS/P99 homologado | **Pendente; não mesclar mudança de física/corpo** |

## Proveniência e isolamento das alterações selecionadas
- `origin/ia2/housing-plan-cache-20261107@64ad9dc` → cherry-pick `d859def`. `TDC_IA2_HOUSING_CACHE=1` ativa recurso de ~2,3 MB assinado por hash de dependências; em falta/corrupção, retorna ao gerador original. Por padrão OFF.
- `origin/ia2/perf-world-build-phases-20261107@d56cce2` → cherry-pick `c79e58f`. `TDC_IA2_HEADLESS_SKIP_VISUAL_HILLSIDE=1` só tem efeito quando `kit.visuals == false`; conserva árvores e troncos físicos e não reduz a vegetação no cliente visual. Por padrão OFF.
- **Compatibilidade do mapa**: a IA 2 também mediu a Favela experimental v25 (4.313 casas/11.624 colisores). A `main` oficial possui **4.188 casas/11.146 colisores** e as seis músicas do baile. O primeiro fixture de vegetação falhou apenas por expectativa antiga (4.313 casas e 13.334 pontos de grama); o fixture foi ajustado para **4.188 e 13.301**, sem tocar no mapa, e passou com os mesmos hashes de árvores.
- Nenhum ajuste da IA 1, protótipo v25 ou cache rejeitado foi misturado; nenhum arquivo de mapa foi sobrescrito.

## Repetição independente na JJ7 — 5 pares
- Godot 4.7.2, processos headless independentes, ordem A-B-B-A-A-B-B-A-A-B; A cache OFF / B ON; vegetação OFF para isolar a variável. Dez processos: todos exit 0, erros 0.
- **Planejamento:** A 992,56 ms vs B 302,69 ms, **−69,50%**, B venceu 5/5. Amplitude/média dos controles A: 14,45%.
- **Construção total (`world_ms`):** A 4.562,04 ms vs B 3.934,72 ms, **−13,75%**, B venceu 5/5. Amplitude/média dos controles A: 12,86%.
- **Até `join_ready`:** A 8.137,72 ms vs B 7.621,94 ms, **−6,34%**, B venceu 4/5, **abaixo do ruído A de 11,24%**. Não homologar como ganho geral de tempo até partida.
- Dados com cada amostra, diagnósticos, resultados e checksums: `docs/benchmark-results/auditoria-otimizacoes-20261107.json`.
- Plano, geometria canônica e oito raycasts foram iguais nas dez execuções, respectivamente SHA256: `9264a7d132a78bf2b9fc4966dab849dd92e66bb622321f547133febc60d3a479`, `ed382d5d98cbb2bb1471ac926b1cf890ee755213163ac8f2ddee32c33a48ca80` e `574841c454eb1f4ffe3703bfa0d5796c51cdb6676e428177b2468651a159f7b5`.
- `--editor --import --quit` passou exit 0 e ambos scripts `--check-only` passaram. São testes de importação e sintaxe, não de jogo gráfico.

## Flags combinadas: regressão curta
- Cache + encosta headless ON: mundo `world_ms=2948,565`, `join_ready=6317,008`; uma única medição, **não** calcular ganho estatístico conjunto.
- `tests/favela_runtime_qa.gd --favela-bots`: **39 checks, zero falhas**, 28 bots implantados, 8 veículos sem sobreposição, 1.466 movimentos registrados, **zero tiros**. Conclui apenas QA offline de construção, navegação inicial e spawn.
- Foliage QA no mapa oficial: árvore idêntica SHA256 `530d711514d60b6efb5397ab43352ecf5c3057f1be0b403af8accdb9a7e3bd94`, 1.850 árvores, 4.700 arbustos, 13.301 pontos de grama, 480 rochas.

## Gate para merge/atualização pública
1. Preservar **Forward+** como padrão desktop; testar **1920×1080, Médio, escala 100%, 28 bots**, foco de janela e concorrência controlados. Não reduzir número de bots nem geometria.
2. Rodar cinco pares A/B com cliente gráfico GTX 1650 e servidor dedicado **em processos/máquinas separados**, medir FPS, P95, P99, quadros acima de 33/50/100 ms, ticks físicos, CPU, GPU/temperaturas e frio/quente do cache.
3. ENet com entrada do segundo cliente, tiros/hitreg, mortes, ragdolls, ópticas, FPP/TPP, granadas, veículos e reconexão; testar fallback do cache também em export final e assinaturas de assets.
4. Confirmar impacto no servidor Ubuntu **headless** (tempo de entrada/carga), hash de colisão, travamento de ticks e ausência de discrepâncias visuais nos clientes.
5. Só promover flags e lançar build depois dos gates; `main` permanece sem essas duas flags, nenhuma versão/build de distribuição foi alterada por esta auditoria.

**Veredito:** os dois ganhos locais de *carregamento* justificam preparar uma atualização experimental opt-in, não habilitar automaticamente nem anunciar ganho de FPS. A investigação do gargalo contínuo dos 28 bots/poses deve prosseguir com a IA 1 em outra branch.
