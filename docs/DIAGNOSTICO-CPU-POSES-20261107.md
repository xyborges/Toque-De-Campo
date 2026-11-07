# Toque de Campo — diagnóstico CPU / physics process / poses (7 nov. 2026)

## Decisão

**A investigação comprovou um custo importante no processamento individual dos 28 bots, mas NÃO produziu uma otimização jogável.** Não lançar build, não alterar `main`, não ligar uma flag experimental de produção. A variante B interrompe `WarPlayer._physics_process()` de todos os 28 bots no teste (mantém o `WarBotDirector` e `GameStepMotion.move()` ativos). Isso congela estados, animações e poses das hitboxes: é somente um limite superior de economia, **não uma solução segura**.

- Máquina: **DESKTOP-JJ7U3G3**, GTX 1650, Godot 4.7.2, Jolt, Forward+, 1920 × 1080, escala interna 100%, Médio, VSync off.
- Código-base: `a86c21b573cfca23bcbc6f168bca4689e44fc421` (QA anterior), descendente de `ee969af` (GitHub main antes desta tarefa).
- Branch de diagnóstico: `ia/diagnostico-cpu-poses-20261107`, reutilizando sequencialmente a worktree QA existente para evitar duplicar dezenas de GB. Nenhuma IA concorrente utilizou essa worktree durante o teste.
- Cinco pares alternados A/B, B/A, A/B, B/A, A/B. Uma alteração por execução; 6 s de warmup e 14 s de coleta gráfica, câmera fixa na Favela.
- 28 bots (14 por equipe), com a lógica de IA, navegação, tiros e movimento do diretor preservadas no fixture. A posição é monitorada; o movimento continua ocorrendo no modo B, mas temporizadores e poses estão incompletos. **Não é uma partida funcional de teste de tiros.**
- Scripts de teste: `tests/ia1_physics_pose_ab.gd` e `tests/run_ia1_physics_pose.py`; JSON/CSV NVIDIA e logs brutos sob `work/diag-physics-poses-20261107/` (ignorados pelo Git).
- `GameStepMotion.qa_enabled=true` em ambas as variantes gera contagem do solver e provoca o mesmo pequeno overhead nas duas.

## Resultados — cinco pares na mesma máquina

| Par | FPS A | FPS B | Física média A/B (ms) | P99 A | P99 B | Movimento A/B (chamadas) |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 23,98 | 41,95 | 18,35 / 13,68 | 75,42 | 38,82 | 13.083 / 13.113 |
| 2 | 24,48 | 45,77 | 19,98 / 12,25 | 82,71 | 34,57 | 13.119 / 13.113 |
| 3 | 24,41 | 39,67 | 17,74 / 13,99 | 74,92 | 45,88 | 13.074 / 13.107 |
| 4 | 20,89 | 46,10 | 19,28 / 12,93 | 112,50 | 33,66 | 13.128 / 13.134 |
| 5 | 26,28 | 36,95 | 18,59 / 16,12 | 63,23 | 63,23 | 13.062 / 13.113 |
| **Média** | **24,01** | **42,09** | **18,79 / 13,79** | **81,76** | **43,23** | **~13 mil em ambos** |

- Alteração diagnóstica: **+75,3% FPS**, **−26,6% do tempo físico por quadro**, **−47,1% no P99**. Os 5 pares venceram em FPS e média física. O P99 foi melhor em quatro, praticamente empatado no último.
- Quadros com mais de um tick físico: **99,83% A**, **41,79% B**, mas a sincronização/tempo de quadros do jogo mudou muito entre variantes.
- Em ambos os modos, a soma de movimento amostrada ficou aproximadamente entre 1.305 e 1.325 metros por 28 bots/14 s de coleta, confirmando o diretor e o solver **não foram desligados**.
- Variação amplitude/média dos controles em FPS: aproximadamente 22,5%. A separação entre A/B é maior que essa amplitude, **mas não supera os bloqueios de segurança e telemetria abaixo**.
- Jogo offline: renderização e autoridade na mesma máquina; não afirmar FPS equivalente para cliente ENet separado. Cada janela mediu **14 s**, não a coleta oficial de 60 s.

## Confiabilidade da GPU e limites

O CSV NVIDIA incluiu todo o processo (carregamento, warmup e medição); registrou temperaturas máximas de **57 a 61 °C** e amostras de **`sw_thermal_slowdown=Active` em ambas as variantes**. Não sabemos quais dessas amostras coincidem com os 14 s medidos, então NÃO afirmar throttling durante a janela oficial nem dizer que o ambiente foi livre de thermal slowdown. Corrigir o runner para recortar a janela de medição com timestamps emitidos pelo Godot antes de aceitar qualquer melhoria para publicação.

A coleta reproduziu bots/população/cenário/resolução/foco e manteve o solver ativo, mas **não isolou** qual subrotina de `WarPlayer._physics_process()` domina o custo. O delta abrange, entre outros: `stance.advance`, `locomotion.advance`, `weapon_optics.advance`, `GameInfantryPose.advance`, `_animate_walk`, timers, grenadas, estado e interações do `super`. Alguns efeitos são indiretos (redução de backlog de ticks / dirty transforms), não apenas tempo linear de GDScript.

## Leitura arquitetural

- Profiling IA1 anterior na Favela já tinha identificado `move_and_slide` ~3,36 ms/frame, poses ~2,12 ms/frame e percepção/navegação bem menores, em base e coleta distintas (não somar esses valores aos atuais).
- O protótipo anterior de LOD de movimento em 18 atores apresentou melhoria da média **mas pico de ~434 ms**, portanto não reintroduzir.
- Cache de degraus, retirar colisão entre bots, micro-otimizações de alocação e P1k/CollisionRig já foram avaliados com regressões ou resultados insuficientes. Nenhum foi reativado.
- O caminho promissor é **desagregar com medição por escopo** o trabalho de `WarPlayer._physics_process()`, primeiro `_animate_walk` e `_update_weapon_pose`, depois `GameInfantryPose.advance`, `stance.advance` e `locomotion.advance`. Uma alteração opt-in de cada vez, mantendo colisão, temporizadores e rig de hitbox em todos os frames necessários.

## Próxima validação antes de otimizar de verdade

1. Criar instrumentação **somente de benchmark**, preferivelmente subclassando `WarPlayer` e `WarGame._new_player`, para medir tempos dos escopos sem modificar os arquivos de produção.
2. Medir A/B de cada componente com 28 bots na Favela e posteriormente em Afeganistão, cinco pares, métricas FPS/P99/multi-ticks, GPU no intervalo correto e CPU clock/temperatura quando disponíveis.
3. Qualquer LOD futuro precisa preservar hitboxes e colisões autoritativas, tiros, mira, escadas/telhados, combate bot-bot, veículos, granadas, bandeiras e multiplayer dedicado.
4. Só ativar otimização demonstrada com cinco pares válidos, vantagem acima do ruído, P99/multi-ticks melhores e matriz funcional de regressão PASS. **Nenhum passo desta investigação foi liberado para a main/build pública.**

## Arquivos modificados

Novos apenas: `tests/ia1_physics_pose_ab.gd` (+UID de importação), `tests/run_ia1_physics_pose.py`, e este relatório. Nenhum arquivo de produção, mapa, física Jolt, bots, GitHub `main`, launcher ou servidor foi alterado.
