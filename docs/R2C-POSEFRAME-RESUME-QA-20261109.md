# Continuação R2C PoseFrame — recuperação e QA JJ7 (09/11/2026)

Branch ia/realismo-r2c-poseframe-resume-20261109, criada do R2C publicado f893572. Worktree dedicada, sem modificar o trabalho anterior do Terra e sem merge em main.

## Trabalho preservado
- Importados seletivamente os sete arquivos preparados em ia/realismo-r2c-poseframe-20261109, preservando o diff staged e seu relatório de auditoria.
- O novo tactical_pose_frame.gd compõe transformações absolutas de quadril e tronco a partir de bases recentes, com identidade de tick físico e vida. O objeto é reutilizado. O corpo continua local/offline/TPP e OFF por padrão.
- O commit do PoseFrame foi concluído com o pre-commit normal habilitado e tools/git_guard.py aprovado; o bloqueio de sh.exe da outra IA não foi reproduzido no Desktop Commander.

## Testes reexecutados nesta worktree
- tests/realismo_r2c_pose_frame.gd: 129/129 PASS, exit 0.
- tests/realismo_r2c_states.gd: 172/172 PASS, exit 0, física a 60 Hz, 16 áreas presentes nos estados auditados.
- tests/realismo_r2c_world_pilot.gd: 105/105 PASS, exit 0.
- Total reexecutado nesta retomada: 406/406 PASS.
- Suítes adicionais R1/R2/ópticas: a IA anterior registrou 520/520 PASS; não confundir o histórico com reexecução completa nesta worktree.
- Driver gráfico tests/realismo_r2c_benchmark.gd corrigido em duas tipagens GDScript: Vector2 versus Vector2i, e variável valid: bool explícita. Godot --headless --check-only passou com exit 0. Benchmarks A/B só devem ser aceitos após R2C_BENCH_RESULT válido, sem perda de foco.

## Gates ainda abertos
- Benchmark 0/12/22/28 bots, Forward+ 1920x1080 Médio 100%, com P95/P99, controles A/A e A/B de 60 s. Não atribuir ganhos de FPS sem pares.
- Integração seletiva ao P1k e paridade autoritativa das 16 regiões, sem regredir o custo de pose.
- Partida real ENet/DTLS e tiros/danos em distâncias variadas.
- Falha na importação fria do editor, previamente registrada, ainda não homologada.
- Piloto continua OFF por padrão, restrito a treino offline local TPP. Nenhuma publicação de build ou alteração em main.

A branch original ia/realismo-r2c-poseframe-20261109 continua fisicamente preservada, inclusive as reservas antigas. Esta retomada usa reservas próprias, worktree independente e não cancela sessões alheias.