# Comparação de renderizadores — 06/11/2026

## Resumo executivo
**Para Windows, preferir Forward+ em testes controlados.** Nas duas amostras realizadas, ele teve P99 inferior e mais previsível que Mobile e Compatibility. Mobile foi o mais rápido em FPS mediano no segundo teste e deve continuar como alternativa. **Para exportação Web, manter Compatibility, pois Godot 4 Web requer WebGL 2.0.** Não alterar o renderer global na main antes de QA visual e testes prolongados. Nenhum teste passou na meta de 60 FPS estáveis.

## Fonte e isolamento
- Branch: `ia/renderers-compare`; base `35f8b1b` (`main`) sem mudanças.
- Worktree: `C:/Users/Joao Borges/Documents/campo-worktrees/renderers-compare`.
- Godot 4.7.2 stable; Windows; Intel i5-11400H; NVIDIA GeForce GTX 1650. O driver reportou NVIDIA nos três métodos.
- `project.godot`: `renderer/rendering_method="gl_compatibility"` e `renderer/rendering_method.mobile="gl_compatibility"`.
- Benchmark `tests/renderers_compare_20261106.gd`: cópia idêntica do fixture local de 03/11, SHA256 inicial `DFB33FB0CE5EA9D5291171F482B3D38A109FD316044DC4D05F75FC27AF90493D`.
- Cada execução: WarGame real offline, operação Afeganistão, 28 bots implantados + jogador, câmera fixa no povoado, 1920×1080, Médio/100%, V-Sync desligado, FPS sem cap, aquecimento 4 s e coleta 12 s.
- Godot `--rendering-method` foi passado só na linha de comando; não houve mudança de configuração do projeto. Importação isolada na worktree.
- Ordem rodada 1: Compatibility, Mobile, Forward+. Rodada 2: Forward+, Mobile, Compatibility.

## Medições
| Rodada | Método | FPS mediano | FPS pela média do quadro | P95 (ms) | P99 (ms) | GPU média (ms) | Física média (ms) | Processamento médio (ms) | Amostras |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | Compatibility | 13,37 | 13,32 | 95,48 | 120,05 | 23,04 | 19,47 | 36,93 | 160 |
| 1 | Mobile | 34,34 | 24,31 | 146,61 | 161,58 | 11,04 | 21,78 | 28,25 | 292 |
| 1 | Forward+ | 37,01 | 34,61 | 49,38 | 58,30 | 8,66 | 17,42 | 28,45 | 416 |
| 2 | Forward+ | 37,64 | 36,38 | 44,00 | 53,40 | 8,58 | 15,52 | 28,21 | 437 |
| 2 | Mobile | 40,66 | 38,04 | 46,98 | 60,53 | 8,07 | 18,03 | 27,88 | 457 |
| 2 | Compatibility | 15,70 | 15,15 | 96,46 | 125,27 | 18,05 | 16,57 | 37,76 | 182 |

Todos os 6 arquivos JSON registraram `valid=true`, 28 bots e 1920×1080 reais, escala 1.0; o processo de cada execução retornou exit code 0. Resultados brutos e logs estão na pasta ignorada `work/performance-pilot-20261103/` **desta worktree**, com rótulos `renderer-*` e `r2-*`. Não são arquivos versionados nem evidência de build publicada.

## Interpretação e limitações
- **Forward+**: melhor consistência de P99 nas duas execuções (53–58 ms) e custo médio de GPU ~8,6 ms. Recomendação provisória para Windows. Ainda falha 16,67 ms de orçamento por frame.
- **Mobile**: custo de GPU comparável ou menor na repetição (8,1 ms), FPS mediano maior na segunda execução, mas primeiro P99 161,6 ms. Avaliar caches/pipelines e estabilidade em primeira execução antes de aprová-lo como padrão.
- **Compatibility**: desempenho substancialmente inferior nesse cenário nativo; necessário no Web. Precisa de perfil dedicado de LOD, agrupamento, sombras, resolução e validação visual para navegador.
- O processamento médio (~28 ms nos métodos Vulkan) e a física (15–22 ms) indicam que **trocar renderizador não corrige a simulação**. A CPU / submits / catch-up físico merecem perfis próprios. Estes tempos de monitor não devem ser somados como parcelas independentes do frame.
- Piloto de 03/11 teve Forward+ com P99 >160 ms; os resultados atuais diferem. Importância de não extrapolar um único cenário para todos os mapas.
- Esta avaliação não cobre captura visual lado a lado, rede/servidor dedicado, múltiplos jogadores, combate prolongado, veículos ocupados, BR, Ucrânia, Favela ou Naval; nem 5 pares de 120 s e soak de 30 min. Não declarar 60 FPS alcançados.
- Os testes usam a versão do código da `main` na criação da worktree e não incluem alterações novas de outras IAs após esse snapshot.

## Repetir
No PowerShell na worktree, após importar o projeto no Godot e criar `work/performance-pilot-20261103` se necessário:

```powershell
$godot = 'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
New-Item -ItemType Directory -Force 'work/performance-pilot-20261103' | Out-Null
& $godot --path . --rendering-method forward_plus --windowed --resolution 1920x1080 --script res://tests/renderers_compare_20261106.gd -- '--operation=afghan' '--duration=12' '--warmup=4' '--label=repeat-forward'
```

Trocar `forward_plus` por `mobile` e `gl_compatibility` em rodadas alternadas; comparar JSON, capturas e a partida completa. Não publicar nem trocar a main automaticamente.

## Próximos gates
1. A/B pareado em cinco execuções de 120 s por método, com controle A/A e compilação de shaders já estabilizada, seguido de teste de primeiro lançamento a frio.
2. Favela e Ucrânia com 28 bots, veículos e eventos de explosão/fumaça; P50/P95/P99, física, processamento e GPU, além de revisão de iluminação/ópticas e VFX.
3. Isolar gargalos de simulação, física, rig e navegação. Só aprovar novo padrão Windows após meta de estabilidade e nenhum desvio de aparência ou gameplay.
4. Manter export Web em Compatibility com orçamento gráfico próprio; revisar shaders e funcionalidades não suportadas.
