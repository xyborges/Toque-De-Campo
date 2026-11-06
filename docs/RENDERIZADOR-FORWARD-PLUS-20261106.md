# Forward+ como renderizador nativo padrão — 06/11/2026

## Escopo e decisão

A configuração do jogo foi promovida **somente nesta worktree** para `forward_plus` no Windows/desktop. A versão Web permanece explicitamente em `gl_compatibility` (WebGL 2.0). O override mobile que já existia (`gl_compatibility`) foi preservado. `project.godot` alterado cirurgicamente, sem mexer em cenas, gameplay, servidores, release ou `main`.

Alterações exatas:
- `application/config/features`: `"GL Compatibility"` → `"Forward Plus"`.
- `rendering/renderer/rendering_method`: `"gl_compatibility"` → `"forward_plus"`.
- `rendering/renderer/rendering_method.web`: `"gl_compatibility"` (novo override explícito).
- `rendering/renderer/rendering_method.mobile`: continua `"gl_compatibility"`.

## Testes de 06/11/2026

Godot 4.7.2 stable, Windows 11, i5-11400H, GTX 1650, Vulkan 1.4.341 no Forward+, Godot iniciado **sem** `--rendering-method` nos testes nativos. Jogo real offline, 28 bots implantados, 1920×1080, Médio em escala de 100%, V-Sync e limite de FPS desligados. Fixture `tests/renderers_compare_20261106.gd`, 4 s de aquecimento e 12 s de amostragem por operação. Os JSON/logs estão em `work/performance-pilot-20261103/` e `work/forwardplus-default-20261106/` desta worktree (ignorados pelo Git).

| Operação | Método efetivo | Bots | FPS mediano | P95 (ms) | P99 (ms) | GPU média (ms) | Resultado |
|---|---|---:|---:|---:|---:|---:|---|
| Afeganistão | forward_plus | 28 | 39,92 | 43,00 | 61,26 | 8,28 | PASS, exit 0 |
| Ucrânia | forward_plus | 28 | 20,23 | 87,63 | 113,78 | 14,67 | PASS, exit 0 |
| Favela | forward_plus | 28 | 29,49 | 53,34 | 64,03 | 7,96 | PASS, exit 0 |
| Afeganistão, fallback CLI | gl_compatibility | 28 | 13,38 | 123,39 | 151,44 | 20,31 | PASS, exit 0 |

O fallback foi executado com `--rendering-method gl_compatibility`, validando a rota de compatibilidade na instalação Windows. **Não substitui** QA e exportação real Web (não há preset Web nesta cópia).

Outras verificações:
- `--headless --script res://tests/favela_runtime_qa.gd -- --favela-bots`: **39/39 PASS**, 28 bots implantados, oito veículos, 0 falhas, exit 0.
- Menu real: `godot --path . --windowed --quit-after 90`, iniciado por padrão em **Vulkan Forward+**, exit 0.
- `git diff --check`: PASS, diff restrito a configurações esperadas.
- Nenhum perfil gráfico, shader, veículo, áudio ou arquivo da `main` foi alterado por esta mudança.

## Limitações e próximos gates

**Forward+ ativo e funcional, mas a meta de 60 FPS estáveis não foi atingida.** O P99 segue acima de 16,67 ms nos três mapas. As amostras têm apenas 12 s de coleta, câmera fixa e mundo offline: não são ensaio de 20 minutos com combate intenso, óticas, fumaça, rede e jogadores reais. Não inferir degradação/melhoria contra relatórios anteriores feitos em cenas/câmeras/presets diferentes.

Antes de publicação, testar Web exportado de verdade, verificar aparência/sombras/materiais, e ensaiar combate, blindados, alcance de visão e miras em Forward+. Depois investigar caudas de frame (CPU, processos de física Jolt, IA/bots, render submission, instancing, compilação de pipelines e 8 ticks de catch-up já documentados), preferindo perfis por operação e amostras pareadas. Não ocultar travamentos apenas reduzindo física/hitboxes.

Para teste manual na worktree: abrir normalmente no Godot para usar Forward+; forçar Compatibility só para comparação com `--rendering-method gl_compatibility`.

Integração na `main` exige revisão/merge separado conforme `docs/GIT-LOCAL-E-IA.md`. **Não foi publicada build nem enviado push.**
