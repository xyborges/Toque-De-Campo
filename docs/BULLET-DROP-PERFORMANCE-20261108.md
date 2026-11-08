# Auditoria: custo do bullet drop — 08/11/2026

**Base:** `origin/main` em `4e41854`; Godot 4.7.2; branch de análise `ia/r01-bullet-drop-profile-20261108`.

## Veredito

**Não remover o bullet drop para ganhar FPS.** A fórmula de gravidade é barata. A maior oportunidade estimada está no ciclo completo de projéteis (raycast de colisão, lógica de impacto/near miss, histórico, rastros e efeitos). Esta branch **não altera o código de produção nem as características do tiro**.

## Onde está o trabalho por projétil

- `scripts/bullet_physics.gd`: integração analítica de gravidade e arrasto; cache de até 1.024 pares `(drag, dt)`. O custo por acerto no cache é menor que por cálculo novo.
- `modes/war/scripts/projectiles.gd`: no modo Guerra, `_physics_process` visita projéteis ativos, `_step` calcula queda/arrasto e executa `direct_space_state.intersect_ray` por subpasso. Balas comuns: até 60 Hz; projéteis guiados ou com alvo: até 120 Hz; também trata água, explosão, impacto, near miss, trilha e efeitos.
- `modes/war/scripts/projectiles.gd`: visuais são pools `MultiMesh`, não um nó físico novo por bala; atualizações de rastro e flash ainda têm custo. O loop de 48 flashes atualiza transform e cor a cada tick mesmo quando não há bala ativa (hipótese adicional para perfil, não comprovada neste benchmark).
- `scripts/main.gd`: BR/legado possui outro loop de projéteis, com o mesmo solucionador de coeficientes e raycast.
- `modes/naval/scripts/ballistics.gd`: solução de trajetória de torre faz uma busca temporal; não foi avaliada como uso contínuo de infantaria.

## Teste realizado, ambiente e limitações

**R01 DESKTOP-R0I0NQG, Intel i5-3470 (4c/4t), Windows, Godot 4.7.2 oficial, headless, sem GPU/FPS.** Cena sintética com **48 caixas estáticas** para raycast. Foram **11 passes alternados de ordem normal/inversa**, aquecimento da VM e do cache, **25.000 operações de cada tipo por pass**. Cada valor é mediana de ms a cada **1.000 chamadas**; a coluna P95 é percentil de *lotes*, NÃO P95 de quadros. Código: `tests/bullet_drop_profile_20261108.gd`. Amostras brutas e checksum: `docs/benchmark-results/bullet-drop-20261108.json`.

| Operação | Mediana (ms/1.000) | P95 de lotes (ms/1.000) |
| --- | ---: | ---: |
| Movimento linear simples | 0,145 | 0,187 |
| Coeficientes, acerto no cache | 1,110 | 1,397 |
| Coeficientes, tempos variáveis | 2,364 | 3,031 |
| Integração com arrasto e **sem** gravidade | 1,425 | 1,655 |
| Integração com arrasto e **com** gravidade | 1,427 | 1,863 |
| `GameBulletPhysics.advance` (inclui Dictionary) | 4,138 | 6,260 |
| `intersect_ray` isolado | 3,641 | 4,313 |
| Loop sintético (arrasto + raycast; sem queda) | 5,988 | 6,706 |
| Loop sintético (arrasto + raycast; com queda) | 6,750 | 8,394 |

**Cuidado estatístico:** a diferença entre as duas medianas de integração é 0,0028 ms / 1.000 chamadas, enquanto a **mediana das 11 diferenças pareadas** é ~0,0745 ms / 1.000 = **0,0745 µs por projétil/tick**. A variabilidade entre passes é da mesma ordem; a medição não prova ganho real de FPS ao remover gravidade. A diferença dos dois caminhos com raycast não isola gravidade: o movimento altera os pontos consultados e possivelmente o padrão de colisões.

**Extrapolação, não telemetria do jogo:** 28 projéteis *em voo simultaneamente*, atualizados uma vez em 1/60 s, custariam ~**0,0021 ms/tick** adicionais para o cálculo matemático da gravidade pelo par central, enquanto 28 raycasts sintéticos custariam ~**0,102 ms/tick** e o percurso sintético completo com queda ~**0,189 ms/tick**. 28 bots **não significam** 28 projéteis voando, e esses valores não incluem custo real dos bots, mapa, rede, draw calls nem efeitos de Guerra.

## Positivos

- O código atual preserva bullet drop e arrasto sem rigid body por bala.
- O cache reduz custos de cálculos repetidos; nas 11 amostras, o caso de cache hit foi mais rápido que o caso de intervalo variável.
- **Teste determinístico PASS:** `GameBulletPhysics.advance` produziu **7,90747 metros de queda após 1 segundo** no cenário de teste, comparado à mesma trajetória com gravidade 0.
- **Execução do microbenchmark PASS:** Godot headless finalizou com **exit code 0**, sem `ERROR` no log da execução pós-import, gerando relatório JSON.

## Negativos / riscos / limites

- Não existe medição válida de FPS, P95/P99 de quadros, 28 bots reais, cenário Favela, multiplayer ou placa gráfica nesta branch. A R01 compartilhava recursos com outros trabalhos; medições podem sofrer ruído por concorrência.
- A consulta física custa mais que a integração matemática no microbenchmark, mas isso **não demonstra** que raycasts dominem o custo do *jogo inteiro*.
- O cache de coeficientes pode perder eficiência com `delta` e arrasto continuamente variáveis; nenhum cache novo foi proposto sem provar ganho no jogo.
- Desativar a queda altera impacto, compensação de mira, zeroing e sincronização. **Não é otimização aceitável.**
- A rotina integrada WarProjectiles não foi perfilada em partida real; não é correto homologar uma alteração de produção só com este teste.

## Próximos ensaios sugeridos (sem alteração aqui)

1. Telemetria por fase em `WarProjectiles`: gravidade/coeficientes, `intersect_ray`, impacto/near miss e `_draw_round`, com número real de projéteis ativos e quantidade de rays/tick.
2. Cenário A/B no cliente GTX 1650, **28 bots reais**, mesmo commit, mapa, câmera, renderizador, resolução, foco e duração. Reportar frame-time e P95/P99 com resultado positivo **e** negativo.
3. Só se houver gargalo reproduzível, considerar: cache mais estável de coeficientes por passo, culling visual de trilhas distantes, amortização de efeitos, e reduzir trabalho de flashes ociosos. **Nunca** reduzir frequência de raycast sem preservar impactos/autoridade e colisão varrida.

## Como reproduzir (somente benchmark CPU)

```powershell
& 'C:\Users\Microgate\Documents\Codex\2026-11-06\fa-a\work\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/bullet_drop_profile_20261108.gd --quit-after 12000
```

Não inclui assets de áudio ou build; `main` e as branches de outras IAs ficam intactas.
