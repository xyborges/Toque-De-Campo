# IA 2 — Custo dos módulos de arquitetura da Favela no servidor headless

**Data:** 7 de novembro de 2026. **Máquina:** DESKTOP-R0I0NQG. **Godot:** 4.7.2 stable. **Base:** commit `ee969af` da `origin/main`, em worktree e branch exclusivas `ia2/headless-architecture-20261107`. A `main` não foi modificada. Não houve deploy no servidor.

## Hipótese e patch experimental

No servidor sem renderização, `EnvironmentKit._instance()` retorna imediatamente, mas `favela_architecture.gd::place()` ainda percorria partes visuais de um prefab e calculava `pose*part.pose`, tamanho do setor e dicionário de opções. Foi introduzida temporariamente a flag `TDC_IA2_SKIP_HEADLESS_ARCH_VISUALS=1` para pular somente esse loop quando `kit.visuals==false`. O código dos colisores, máscaras, posições, materiais e partes físicas permaneceu idêntico. Em cliente gráfico, a flag não altera a renderização. No padrão OFF, a rotina não muda.

**Após medir, o patch foi REPROVADO e REVERTIDO.** Arquivo de produção `modes/war/scripts/favela_architecture.gd` está intacto frente ao commit-base. Diff da hipótese disponível apenas como `DESCARTADO-architecture-visuals.patch.gz` neste diretório.

## Matriz de 5 pares A/B

Ordem A-B-B-A-A-B-B-A-A-B, subprocessos Godot independentes e sem outros Godot ativos; sempre na mesma máquina. A variável única é a flag acima. Cada execução carrega o WarGame offline com Favela e valida `join_ready`; não se trata de um cliente ENet conectado, benchmark FPS da GTX 1650 ou 28 bots em combate.

| Indicador | Original (A) | Experimental (B) |
|---|---:|---:|
| Média da construção de mundo (`world_build_ms`) | 5.701,43 ms | 5.885,74 ms |
| Média até `join_ready` | 12.250,25 ms | 12.896,03 ms |
| Mudança na construção | — | **3,23% mais lento** |
| Mudança na entrada | — | **5,27% mais lento** |
| Ruído controle A na construção (amplitude/média) | **19,78%** | — |
| Ruído controle A até `join_ready` | **21,90%** | — |
| Pares favoráveis a B (construção) | — | **3/5** |
| Pares favoráveis a B (entrada) | — | **2/5** |

A execução 7 da variante B teve pico de 7.660,84 ms de construção, enquanto controles A oscilaram entre 5.151,21 e 6.279,17 ms. O resultado não é robusto e não supera o ruído. **Não ativar e não integrar.**

## Auditoria física e diferença de versões

Nesta base oficial `ee969af`, a Favela apresenta **4.188 casas, 225 tiles e 11.146 colisores contabilizados no EnvironmentKit**. A varredura completa das cenas encontrou **11.922 CollisionShape3D**, incluindo colisores fora do contador EnvironmentKit. Não misturar esses números com revisões anteriores do mapa, que tinham 4.313 casas/11.624 colisores.

Nas **dez execuções**, hash canônico da geometria física ordenada foi idêntico:
`ed382d5d98cbb2bb1471ac926b1cf890ee755213163ac8f2ddee32c33a48ca80`.

Hash das oito consultas físicas de controle também idêntico:
`574841c454eb1f4ffe3703bfa0d5796c51cdb6676e428177b2468651a159f7b5`.

Os hashes são válidos para esta fixture, commit e versão do Godot. Não atestam física ao longo de uma partida com jogadores, combate e veículos. O script `tests/ia2_headless_architecture_qa.gd` verifica o mesmo conjunto de condições.

## Decisão e próximos alvos

**DESCARTAR** a tentativa de pular os loops visuais em `favela_architecture.gd`. O custo real da montagem de bairros é dominado por outras operações, como geração da estrutura física, nós, posicionamento e consultas de altura, que precisam ser perfiladas isoladamente antes de intervir.

A IA 2 não tocou nos arquivos da outra frente, especialmente `favela_hillside.gd` e testes reservados para a otimização de vegetação sem renderização. O ganho relatado nessa frente é independente deste experimento.

Arquivos: `architecture-5pairs.csv`, dez JSONs e logs, `analysis.json`, `analyze.py`, `run-five-pairs.ps1`, diff compactado e `SHA256SUMS.txt`. A branch guarda dados e QA, **sem mudança de gameplay ou melhoria ativada**. A próxima pesquisa deve medir uma fase dominante específica, usando o cronômetro do próprio trecho e uma fixture reproduzível, e só depois implementar uma alteração única sob flag.
