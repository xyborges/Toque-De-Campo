# R01 — ensaio de física de ragdoll (08/11/2026)

## Fonte e isolamento
- Projeto: `xyborges/Toque-De-Campo`; base `origin/main` `4e41854` (1.13.9, build 97).
- Máquina: DESKTOP-R0I0NQG, Intel Core i5-3470, GeForce GTX 1650.
- Godot: 4.7.2 oficial, teste headless, 60 ticks/s.
- Branch: `ia/r01-ragdoll-fisica-20261108`; worktree: `C:/Users/Microgate/Documents/tdc-r01-ragdoll-20261108`.
- Nenhum arquivo da `main` foi alterado.

## Implementação experimental
Flag `TDC_R01_RAGDOLL_OPT=1`, **desligada por padrão**:
1. Apenas cadáveres remotos e não persistentes: CCD nos membros secundários desativado; torso, cabeça e pelve permanecem com CCD.
2. As exceções quadráticas membro-membro são omitidas, pois os corpos de ragdoll usam layer 8 / mask 1 e não colidem uns com os outros.
3. Uma checagem de repouso a cada 0,25 s congela corpos e remove juntas somente após dois intervalos estáveis, a partir de 1 s, mantendo os modelos visuais presentes.
4. Cadáveres locais (câmera de morte) e persistentes (Battle Royale/loot) mantêm o caminho físico completo.
5. Nenhuma alteração foi feita em hitboxes de jogadores vivos, física autoritativa, tiros, armas ou veículos.

## Benchmarks A/B
Fixture `tests/r01_ragdoll_perf.gd`: 10 cadáveres, 150 corpos rígidos, 140 juntas; 240 ticks; monitor `Performance.TIME_PHYSICS_PROCESS` (não é custo total da física nem FPS renderizado). Ordem das dez execuções: 0,1,1,0,0,1,1,0,0,1.

| Métrica, média de cinco execuções | Original (0) | Experimental (1) |
| --- | ---: | ---: |
| Criação dos 10 cadáveres (ms) | 77,80 | 76,98 |
| TIME_PHYSICS_PROCESS (ms) | 1,196 | 1,206 |
| P95 do mesmo monitor (ms) | 1,408 | 1,449 |
| Corpos ativos ao tick 240 | 150 | 15 |
| Corpos congelados ao tick 240 | 0 | 135 |
| Juntas restantes ao tick 240 | 140 | 14 |
| Cadáveres visíveis | 10 | 10 |

Os tempos oscilaram fortemente entre execuções; **não há melhora reproduzível de CPU/P95/FPS**. A redução de objetos físicos ativos é consistente e verificável. Não ativar essa flag em produção sem benchmark de cliente real e teste visual.

O benchmark original `tests/ia2_respawn_ragdoll_benchmark.gd` (28 atores, 4 rajadas de 8 mortes) apresentou aproximadamente 62,19 ms de callback por rajada, antes da alteração. Esse teste enfatiza custo inicial, não física sustentada, e a fila de ragdoll existente (`TDC_IA2_DEFER_REMOTE_RAGDOLL`) já reduz esse pico de callback sob flag, atrasando sua apresentação em quadros.

## Regressões
- `tests/ragdoll_contact_stress.gd -- --ticks40` com flag=1: 12 cadáveres, 0 falhas.
- `tests/ragdoll_stability.gd -- --ticks40` com flag=1: 0 falhas.
- `tests/r01_ragdoll_perf.gd` em ambas as condições: 0 falhas nas dez rodadas iniciais; verificação de preservação de cadáver local e persistente adicionada após essa bateria.

## Verificação adicional na máquina principal (08/11/2026)

- Máquina: DESKTOP-JJ7U3G3, i5-11400H, GTX 1650, Godot 4.7.2, commit de teste `a922f37` em worktree isolada. `main` intocada.
- Teste existente `tests/run_war_frame_pacing.py`: duas comparações invertidas (A-B e B-A) com servidor ENet real, 28 bots e cliente Vulkan Forward+, `1280×800`, fases parado/correndo/tanque. Todos os processos terminaram com exit 0 e zero falhas. A variante ligada teve pequenas vantagens de FPS nas três fases (1,2% a 3,5%), porém esse teste **não força a criação de ragdolls**; não é prova causal de otimização dos cadáveres. Houve também avisos de cache de shaders.
- Teste gráfico isolado criado apenas no `work/` ignorado da máquina principal: `work/ragdoll_qa_graphic.gd`, 10 ragdolls reais renderizados, alternância A/B, cinco execuções por modo, GPU GTX 1650. Resultados:

| Métrica (média das cinco execuções) | Original | Experimental |
| --- | ---: | ---: |
| FPS médio | **112,52** | 111,67 |
| P95 do intervalo entre quadros | 14,039 ms | 14,027 ms |
| P99 do intervalo entre quadros | 15,322 ms | 15,418 ms |
| Monitor de processamento físico | 1,928 ms | 1,912 ms |

- Todos os testes isolados terminaram sem falhas, os dez cadáveres permaneceram visíveis. O experimento confirmou menos corpos simulados após o repouso, **mas não reproduziu um ganho de FPS**; a média otimizada foi 0,8% menor, sem significância demonstrada. O teste gráfico isolado não substitui o cenário real de 28 bots, 1080p Médio e mortes sucessivas.

## Decisão
**NÃO HOMOLOGAR para produção nem ativar a flag por padrão.** A alteração permanece disponível para experimentos `TDC_R01_RAGDOLL_OPT=1` em branch separada. Preservar a câmera de morte local, loot persistente e integridade dos tiros; só reconsiderar com ganho sustentado de P95/P99 em cenário real de mortes e teste visual de câmera, terreno acidentado, equipamento e loot. A R01 havia apresentado cerca de 13 FPS em benchmark histórico (outro commit/cenário), não como resultado deste experimento.

Não fazer merge na `main` ou publicar atualização apenas com esta evidência.
