# Integração IA 2 — Performance experimental (06/11/2026)

## Proveniência

- Repositório: xyborges/Toque-De-Campo.
- Commit-base: `4bff4ae9ed6a697ef1a61d2cba25425f03404a36` (origin/main, antes da integração).
- Integração isolada: `integracao/ia2-performance-20261106` na DESKTOP-R0I0NQG, sem alterar a main durante os testes.
- Commits originais selecionados da IA 2: `1d0aa87` (arma remota), `9787392` (fila de ragdoll), `c66699d` (limite de cadáveres), `c4d304d` (fixture de benchmark).
- NÃO foi feito merge da branch inteira `ia2/bench-ragdoll-armas-20261106`: ela carrega alterações de mapa, instrumentação e logs fora do escopo.

## Funcionalidades incorporadas — desligadas por padrão

| Variável de ambiente | O que muda quando =1 | Escopo |
|---|---|---|
| `TDC_IA2_REUSE_RESPAWN_WEAPON` | Reutiliza modelo de arma intacta e sem troca em ator remoto, atualizando ópticas | `modes/war/scripts/player.gd` |
| `TDC_IA2_DEFER_REMOTE_RAGDOLL` | Limita a criação visual de ragdolls remotos a um novo cadáver por quadro | `scripts/main.gd` |
| `TDC_IA2_RAGDOLL_STRICT_CAP` | Corrige o limite de 10 cadáveres considerando nós já agendados para remoção | `scripts/main.gd` |

Com variáveis ausentes ou diferentes de `1`, permanece o comportamento anterior. Não há alteração por padrão em bots, física, navegação, servidores dedicados, armas autoritativas, FPS alvo ou renderizador.

## Validação de integração na DESKTOP-R0I0NQG

Godot 4.7.2, testes headless na nova worktree criada diretamente de `origin/main`:

- Importação do projeto: exit 0, sem `SCRIPT ERROR`/erros de Godot na saída.
- `tests/ia2_ragdoll_cap_qa.gd`: exit 0, 4 checks, 0 falhas. Doze mortes simultâneas: modo antigo 11 corpos, modo estrito 10. Limpeza dos corpos PASS.
- `tests/ia2_respawn_ragdoll_benchmark.gd --mode=weapons --optimized=0`: exit 0, 28 atores remotos, 560 eventos, 20 lotes, sem falhas. Refresco médio 5,93965 ms/lote, 616 construções completas.
- Mesma fixture com `--optimized=1`: exit 0, mesmos 28 atores/560 eventos, sem falhas. Refresco médio 2,654 ms/lote (**55,32% menor**), 560 reusos e 56 construções completas. Amostra única adicional de integração; os cinco pares originais da IA 2 também constam em `work/ia2-ragdoll-armas-bench-20261106/` na branch de origem.
- `--mode=ragdolls --optimized=0`: exit 0, 28 atores, quatro rajadas de oito mortes. Média dos callbacks 63,02925 ms, 4 callbacks acima de 33 ms, zero falhas.
- `--mode=ragdolls --optimized=1`: exit 0, mesma fixture, média dos callbacks 0,979 ms, zero callbacks acima de 33 ms, 32 criações adiadas, zero falhas. **Isso espalha trabalho pelos quadros e atrasa apresentação visual; não elimina o custo total da física.**

Todos os dados desta validação estão em `work/ia2-main-integration-20261106/*.stdout.log` na worktree, fora do Git por política de arquivos temporários.

## Bloqueios e exclusões

- `5611fde` (reuso de distância de ruas/lotes na Favela v25): cherry-pick conflitou com a Favela da main atual; inteiramente excluído. Nenhuma mudança de mapa incorporada.
- `8eb3892` (raycast visual 30 Hz): não incorporado, pois ainda não comprovou FPS/P99 em cliente multiplayer.
- `9d6acfe`, `d09acb1` (LOS e tráfego de bots): não incorporados; benchmarks de cinco pares e relatório da própria IA 2 reprovaram ganhos.
- Não incorporar CollisionRig/P1k ou mudanças experimentais de movimento da IA 1 sem validação independente.
- **Não há evidência de FPS/P99 melhorados em cliente online GTX 1650.** A integração disponibiliza experimentos opt-in, não uma atualização de otimização ativada em produção.

## Aceitação futura para ativar as flags

Medir com servidor dedicado e cliente real, 28 bots, 1080p/Médio Forward+, tiros, trocas de armas, respawns, diferentes ópticas, FPP/TPP, mortes em rajada, network hitreg e integridade de ragdolls, com no mínimo cinco pares alternados; exigir ganho de FPS e P99 acima do ruído, sem regressões. Ativar uma flag por vez, documentando aprovação antes de torná-la padrão.

Arquivos de produção tocados na integração: apenas `modes/war/scripts/player.gd` e `scripts/main.gd`. Testes: `tests/ia2_respawn_ragdoll_benchmark.gd`, `tests/ia2_ragdoll_cap_qa.gd` e UIDs. Nenhum build publicado.
