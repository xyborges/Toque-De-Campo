# IA 2 — Fase 2: consultas baratas, 28 bots e decisão por evidência

**Data:** 06/11/2026. **Máquina:** DESKTOP-R0I0NQG (NVIDIA GTX 1650). **Estado:** experimentos implementados em flags **desligadas por padrão**, sem integração na main, **nenhum ganho aprovado**. Sem alteração de física, degraus, colisões bot-bot, hitboxes, animações, rede ou replicação.

## Rastreabilidade e isolamento

- Base deste trabalho: `b4192f1` (Fase 1 IA 2; ancestral comum do jogo `origin/main@4bff4ae`).
- Branch: `ia2/ganhos-baratos-fase2-20261106`. Cada experimento de gameplay teve commit isolado e reversível:
  - `9d6acfe` — reutilizar a confirmação de linha de tiro calculada por `_visible_enemy()` durante `_think()`, somente com `TDC_IA2_REUSE_LOS=1`. Há validação dos dois endpoints; se mudarem, consulta normal.
  - `d09acb1` — reutilizar `BoxShape3D` e `PhysicsShapeQueryParameters3D` em `_traffic_clear()`, somente com `TDC_IA2_REUSE_TRAFFIC_QUERY=1`; todas as propriedades dinâmicas (tamanho, máscara, RID excluído, transformação, margem, movimento zerado) são redefinidas a cada chamada.
  - `7ef99f3` — scripts QA e runner, monitorando a flag realmente executada e os contadores de consultas poupadas.
- Favela v25 reproduzida em `ia2/ganhos-baratos-favela-v25-20261106` a partir de `5fceacc`, conteúdo do mapa `7717aa5`, com cherry-picks dos três commits acima; não foi incluída na main.
- Tudo desligado por padrão. Ao ativar uma flag, a outra permanece desligada nas medições.

## Testes de equivalência direta (sem medir FPS)

| Mapa | Bots | Veículos | Varreduras de tráfego, baseline vs cache | LOS cache vs consulta real | Veredito |
|---|---:|---:|---:|---|---|
| Afeganistão | 28 | 14 | 70/70 idênticas | 2 alvos visíveis + 2 invalidações do cache: sem divergência | PASS |
| Favela v25 | 28 | 8 | 40/40 idênticas | Nenhum alvo selecionado na fixture estática; **LOS não exercitado** | PASS de tráfego; LOS inconclusivo |

As varreduras incluem orientações e alcances diferentes em vários veículos no mesmo mundo físico, alternando o uso do cache e o método antigo sem esperar um novo tick. Não substituem cobertura de todo cenário multiplayer, projéteis ou ataque real. Os logs estão em `guards-afghan.log` e `guards-favela-v25.log`.

## Benchmark A/B LOS (Afeganistão)

Godot 4.7.2 estável, Jolt, Forward+, Médio 1080p/100%, VSync desligado, 28 bots reais, seed fixa, câmera fixa, 5 s de aquecimento + 10 s de janela, nenhuma instância Godot concorrente no início e foco integral. Cinco pares intercalados A/B (desligado/ligado), na ordem **AB–BA–AB–BA–AB**. JSON bruto, CSV Nvidia e logs individuais preservados. **Não misturar com FPS da JJ7 ou da Favela v25, nem declarar ganho apenas pelo FPS médio.**

| Par | FPS A | FPS B | Diferença FPS | Mudança no P99 (ms) | Mudança nos frames com ≥4 ticks |
|---|---:|---:|---:|---:|---:|
| 1 | 6,70 | 7,35 | +9,70% | −22,35 | +7 |
| 2 | 12,68 | 8,29 | −34,62% | +85,63 | −36 |
| 3 | 10,08 | 7,97 | −20,96% | −56,60 | −19 |
| 4 | 5,49 | 5,66 | +3,16% | −47,55 | +2 |
| 5 | 10,07 | 13,22 | +31,23% | −52,66 | +28 |

- **Ganho mediano de FPS B vs A:** +3,16%. **Ruído interno da própria R0I**, calculado como (máx−mín)/média dos cinco controles A: **79,86%**.
- **Mudança mediana no P99:** −47,55 ms (isoladamente favorável), mas **mudança mediana nos frames ≥4 ticks:** **+2**, desfavorável.
- Na condição B, `los_reused` foi 54, 51, 55, 46 e 55 consultas poupadas por **10 s**, total 261. Comparativamente, o total de movimentações e poses é muito maior.
- GPU: 36–37 °C em todos os 10 runs, **0 amostras de throttling térmico SW/HW**, porém clocks e tempos de render variaram. Não há evidência de problema térmico; não afirmar causa única da variação. A primeira dupla coincidiu com trabalho auxiliar de checkout/branch: **potencial contaminação adicional**, embora os gates formais de bots/foco tenham passado.
- **Decisão: REPROVAR/descartar como ganho de produção.** A variação de controle é enorme, ganho de FPS bem inferior ao ruído, ticks acumulados não melhoraram e ainda não há teste multiplayer autoritativo do recurso. Seis ou mais pares limpos e controle A/A estabilizado podem ser úteis futuramente, mas **não ativar agora**.

## Benchmark de cache de consultas de tráfego (Afeganistão)

Um **par exploratório** A/B, 28 bots, mesmo pipeline. A: **10,58 FPS**, **P99 178,85 ms**, ≥4 ticks **100**. B com flag: **4,54 FPS**, **P99 307,46 ms**, ≥4 ticks **46**; **14 consultas com objeto reutilizado** em 10 s.

**Decisão: NÃO APROVAR**. Um par é insuficiente para atribuir causalidade ou demonstrar ganho acima do ruído. A amostra piorou FPS e P99, embora os ticks >=4 tenham caído; a consulta de tráfego é pouco frequente e depende principalmente de veículos, não de cada bot a 60 Hz. Não vale ativar ou continuar micro-otimizando esse trecho antes de estabilizar a carga e provar uma economia.

Em ambos os conjuntos há **zero clientes reais conectados**: a Phase 1 previa payload offline, não substitui servidor/cliente real. A autoridade de tiros, hitboxes, dano e posição foi preservada por não modificar esses caminhos.

## Consultas adicionais e escopo da IA 1

- `_avoid()` já cria uma query de raio por chamada e **reutiliza o objeto alterando o destino** ao experimentar até oito ângulos. Não duplicar esse trabalho.
- `_cover_goal()` testa altura corporal e altura dos olhos com destinos/origens diferentes, logo **não reutilizar o resultado**; são perguntas físicas distintas e a alternativa poderia reduzir precisão de cobertura.
- A análise é exclusiva da IA 2. `GameStepMotion.move`, `test_move`, contato bot-bot, LOD físico e correções de degraus ficam para a IA 1.
- **Poses/IK/hitbox:** a Phase 1 indicou custo importante na Favela v25, mas mudar a relação entre animação e hitbox autoritativo requer autorização específica. Nenhuma alteração nesse domínio foi feita.
- **Rede:** replicação espacial/adaptativa não foi implementada; um piloto exige servidor dedicado real, peers reais, medição de bytes/CPU e testes de hitreg.

## Testes e pendências de aceitação

- Godot `--headless --check-only`: PASS nos scripts QA e de benchmark da branch principal. Python `py_compile`: PASS.
- Teste estático de tráfego: 110/110 varreduras idênticas somando os dois mapas.
- O cache de LOS foi testado no Afeganistão; no teste estático da Favela v25 nenhum candidato visível foi encontrado. Executei ainda `favela_bot_pressure_qa.gd` na **Favela v25** com `TDC_IA2_REUSE_LOS=1` e com `0`. **Ambos terminaram exit 1 com os mesmos dados**: atacante manteve alvo visível por 300 ticks, avançou 16,3 m; os cinco squads de defesa foram atribuídos ao objetivo C, violando o critério de cobrir os cinco objetivos. É uma falha de teste presente também no baseline (sem otimização); não foi causada de forma demonstrável pelo cache, mas impede considerar o gate funcional aprovado. Logs `pressure-favela-v25-los-on.log` e `pressure-favela-v25-baseline.log` preservados.
- Faltam **cinco pares limpos de tráfego**, controle A/A estável, avaliação multiplayer real, equivalência balística e condições de aprovação de P99 e ticks. Portanto nenhuma flag pode ser incorporada ou ligada em produção.
- A base JJ7 com quatro JSONs 0/12 e CSVs foi verificada na máquina da IA 1 na Fase 1 e continua fora do versionamento sob controle dela; não copiar sem coordenação.

## Arquivos tocados para comunicação com IA 1

**Gameplay (único arquivo compartilhado):** `modes/war/scripts/bot_director.gd`: campos de flag/cache perto do cabeçalho; trecho de `_think()` que consome linha de tiro; trecho de `_visible_enemy()` que registra raycast confirmado; helper `_ia2_think_line_clear()` antes de `_has_clear_shot()`; criação de `BoxShape3D` e `PhysicsShapeQueryParameters3D` dentro de `_traffic_clear()`. Commits separados facilitam rebase com alterações de movimento da IA 1.

**QA somente:** `tests/ia2_cost_benchmark.gd`, `tests/ia2_phase2_guard_qa.gd`, `tools/ia2_cost_runner.py`, `tools/ia2_phase2_pairs.py`, além de `work/ia2-ganhos-baratos-fase2-20261106/` (relatório e evidência). A fixture de profiler da Fase 1 não foi alterada.

**Veredito:** código experimental disponível, flags independentes e desativadas; sem alteração na main e **sem ganho validado**. Nenhuma previsão de FPS para 50+ bots é justificada por esses dois microexperimentos. Priorizar estabilização dos benchmarks e investigações mais relevantes de corpo/pose com autorização e testes próprios.
