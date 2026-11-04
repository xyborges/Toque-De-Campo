# Inventario Git e fila de integracao entre IAs — 04/11/2026

> **Escopo:** leitura do Git local, dos documentos versionados e de evidencias preservadas em `work/`. Esta tarefa **nao** incorpora recursos ao jogo, nao substitui fontes, nao atualiza o servidor e nao publica builds. Manifesto estruturado: [INVENTARIO-INTEGRACAO-IA-20261104.json](INVENTARIO-INTEGRACAO-IA-20261104.json).

## Resultado executivo

- Base inspecionada: `main` em `7a5dc4f` (projeto `1.13.2`), limpa em `git status --short --branch`.
- Antes desta tarefa: **0 branches de desenvolvimento, 0 commits de codigo aguardando merge, 0 reservas ativas**. Ja existia um baseline do codigo principal com 4.926 arquivos. A nova branch `ia/inventario-pendencias-20261104` foi criada **somente para documentar este inventario**.
- **Ha funcionalidades incompletas, mas nenhum pacote de gameplay comprovadamente pronto para integrar.** O que ja estava no codigo foi incorporado ao baseline; testes/fixtures e laboratorios de `work/` nao sao automaticamente gameplay.
- Varias anotacoes antigas dizem “nao publicado” ou “build 87”; sao historicas. A versao de `project.godot` lida agora e `1.13.2`. A verificacao de publicacao da build 88 foi feita em outro turno; nao foi repetida nesta auditoria Git.
- Cuidado: `work/`, `distribution/build`, `distribution/published`, `distribution/private`, backups, copies de laboratorio e `.ai-coord/` sao **ignorados de proposito**. Nao use `git add -f` e nunca copie a pasta de um laboratorio inteiro para o main.

## Classificacao por sistema

| ID | Area | Estado real | Proxima acao, nao confundir com commit pronto |
|---|---|---|---|
| IA-001 | G3 e lunetas Hensoldt 4x/8x | **Ja versionado na main** | Regressao de cliente exportado; nao aplicar snapshots antigos |
| IA-002 | Afeganistao v11-v13, rotas BR, preparados Afeganistao/Ucrania | **Ja versionado; homologacao final pendente** | Verificar hashes e nav apos novas mudancas; online 2 clientes + 28 bots |
| IA-003 | Kit V3, destruicao de blindado e VFX | **Ja no codigo; homologacao auditiva/FPS pendente** | A/B em partida real e teto de pico |
| IA-004 | HUD BR/Guerra/Naval | **Alteracoes no codigo; QA total pendente** | Capturas e uso real em diferentes modos/resolucoes |
| IA-005 | IA militar, veiculos e bots | **Codigo no main; comportamento ainda nao homologado** | APC, ocupacao, objetivos, colisao, combate intenso, 28 bots |
| IA-006 | Unificacao FPP/TPP, CollisionRig | **Prototipo inativo** | Solver por arma/postura, hitboxes reais, paridade de tiro e custo antes de ativar |
| IA-007 | Mixer master, ducking e prioridade de explosao | **NAO implementado** | Implementar e testar, preservando voz/volumes |
| IA-008 | Trilhas do Afegao inspiradas no Sinai, etapa v14 | **Somente plano** | Construir trecho piloto, navmesh, colisao e medir FPS |
| IA-009 | 60 FPS estaveis em 1080p com 28 bots | **Meta NAO alcancada** | A/B termicamente controlado, p95/p99, host separado |
| IA-010 | QA online completo de War/BR com clientes exportados | **Homologacao pendente** | Recriar fluxo com ticket assinado sem enfraquecer autenticacao |
| IA-011 | Jolt threaded de laboratorio | **REJEITADO — nao integrar** | Preservar logs, nao copiar configuracao |
| IA-012 | CollisionPose Lite/event + grama alternativa | **Rejeitado/desligado — nao integrar** | Preservar evidencias, nao restaurar codigo antigo |

### Evidencias de conteudo ja versionado

- **Armas e oticas:** `scripts/g3_model.gd`, `scripts/attachments/precision_detail.gd`, `scenes/weapons/precision8x.tscn`; `tests/optical_ads_live.gd` e `tests/br_optic_duel.gd`. O ciclo previo registrou 421 verificacoes de mira BR/Guerra e 552 no duelo BR, mas esta auditoria nao as reexecutou.
- **Afegao e preparacao:** `modes/battle_royale/map/afghan_density_stage3.gd`, `modes/battle_royale/navigation/prepare_routes.gd`, `maps/prepared/afghan/manifest.json`, `maps/prepared/ukraine/manifest.json` e `tools/verify_prepared_maps_v13.py`. `docs/PREPARACAO-MAPAS-V13-UCRANIA-20261103.md` registra 12/12 depositos v13 alcancaveis, 40 participantes em 8 seeds e 11/11 verificacoes do verificador naquela preparacao. Isso nao substitui dois clientes exportados nem 28 bots.
- **Audio:** `audio/explosions/tank_near.wav`, `audio/explosions/tank_far.wav`, `scripts/explosion_audio.gd`, `modes/war/scripts/effects.gd`; `docs/PLANO-MESTRE-AUDIO-20261104.md` marca mixer/ducking como ainda nao executado.
- **HUD e IA:** `scripts/ui/infantry_hud.gd`, `scripts/ui/naval_hud.gd`, `modes/battle_royale/ui/hud.gd`, `modes/war/scripts/ui.gd`, `modes/war/scripts/bot_director.gd` e `modes/war/scripts/bot_transit.gd`. Manifestos de `work/hud-*` sao checkpoints historicos de hash, nao trabalho separado pronto.
- **FPP/TPP:** `modes/war/scripts/collision_pose_state.gd`, `collision_rig_proxy.gd` e `collision_pose_solver.gd` ja estao versionados; o proxy cria `Area3D` com shapes desligados e espelha o rig atual. Um solver isolado de G3 em pe nao certifica o arsenal (AK/FAL/Glock/sniper/armas especiais), prone, multiplayer ou FPS. Nao habilitar automaticamente.
- **Performance:** `scripts/frame_pacing.gd` foi alterado para observabilidade; o relatorio `work/performance-final-20261103/RELATORIO.md` concluiu que 60 FPS/p99 ainda nao foram atingidos e proibiu integrar o experimento Jolt threaded pelos erros de consulta fisica.
- **Cenario futuro:** `docs/AFEGANISTAO-REFERENCIA-SINAI-TRILHAS-20261104.md` declara explicitamente que nenhuma trilha da fase v14 foi implementada.

## Fila pronta para proximas IAs (nao e fila de merge)

1. **Verificar gates de release:** rodar `python tools/verify_prepared_maps_v13.py` apos qualquer alteracao de fonte; repetir regressoes de armas/oticas, 2 clientes exportados BR/Guerra e benchmark completo. Os resultados antigos nao aprovam o codigo que vier depois.
2. **Audio:** implementar mixer dinamico em worktree exclusiva; confirmar picos, ducking por evento, PTT/voz e performance.
3. **FPP/TPP:** terminar `CollisionPose` independente e multi-arma, validar tiros/cobertura e so entao trocar exibicao FPP/TPP. Rejeitar Lite/event.
4. **IA/HUD:** ciclo proprio de homologacao/bugfix, sem misturar com audio e FPP.
5. **Mapa v14 e desempenho:** apenas apos validar navegacao, carga e orçamento da GTX 1650.
6. **Rever laboratorios separados (`campo-ui-lab`, `campo-perf-lab`, `campo-map-prep-v13`, `work/`) seletivamente:** comparar arquivos, hashes e testes; nunca promover snapshot de projeto inteiro.

## Politica de integracao

- Este inventario e uma **fila rastreavel no Git**. Nao ha branch de gameplay pronta para `merge` nesta data.
- Cada IA deve criar worktree/branch propria, reservar arquivos, verificar hashes, executar testes e commitar somente diferencas revisadas. Nao aplicar patches automaticamente por este documento.
- Um item sai de `nao implementado` ou `prototipo` apenas com **codigo integrado, teste de regressao e observacao de runtime** registrados. Um resultado `exit 0` isolado sem verificacoes nao e homologacao.
- `main` e a build publicada permanecem intactas por esta auditoria; nenhuma publicacao foi solicitada.
