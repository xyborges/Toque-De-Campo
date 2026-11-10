# Piloto A/B: occlusion culling na Favela (10/11/2026)

## Estado
Branch `ia/map-occlusion-pilot-20261110`; base local `85cc9d1`. **Desligado por padrão. Não integrar na main nem publicar antes da validação gráfica/multiplayer.**

## Descobertas na base
- `WarFavelaMap` gera 225 tiles de terreno e utiliza a mesma função `height_at` para autoridade e cliente.
- `EnvironmentKit` já agrupa geometrias em `MultiMesh` por setores e utiliza `visibility_range_end` / LOD próximo-distante. Não duplicar essas estruturas.
- `EnvironmentKit` já sabia gerar `OccluderInstance3D`, mas a Favela desligava isso deliberadamente. Ligar indiscriminadamente produziria occluders de muros, segmentos e casas abertas.
- `GamePerformanceProbe` e testes de benchmark já existem. Priorizar P95/P99, custo de geração e gargalos de spawn sobre médias de FPS isoladas.

## Implementação isolada
- `project.godot`: habilita infraestrutura global de occlusion culling. O viewport da Favela permanece **desligado** sem a flag.
- `WarWorld._build_favela`: liga o viewport somente com `--favela-occlusion-pilot` e renderização visual.
- `WarFavelaMap.build`: autoriza somente `CasaFavela` (bloco fechado) e `Puxadinho` (bloco sólido). Não cria occluders de escadas, portas, paredes finas, lajes acessíveis ou casas abertas.
- `EnvironmentKit._collider`: filtro por rótulos opt-in e volume oclusor com margem interna de 12 cm de cada lado. Preserva comportamento sem filtro para escritório e demais cenas.
- A colisão física, cálculo determinístico de altura, navegação, tiros e rede **não foram alterados**.

## QA
Na worktree, com Godot 4.7.2 e acesso de leitura ao projeto:
```powershell
$g='C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $g --headless --path . --script res://tests/favela_occlusion_pilot_qa.gd
& $g --path . --script res://tests/favela_occlusion_benchmark.gd
& $g --path . --script res://tests/favela_occlusion_benchmark.gd -- --favela-occlusion-pilot
```
O segundo e terceiro comandos exigem **GPU física, janela em primeiro plano, resolução 1920x1080 e mesmo perfil térmico**. Fazer pelo menos três pares A/B intercalados, registrando build_ms, occluder_count, FPS, P95/P99 e draw calls. Não comparar headless com gráfico.

## Próximas tecnologias (não instaladas nesta etapa)
- **Terrain3D 1.1**: piloto em novo mapa/heightmap isolado, sem substituir colisão/height_at autoritativos ou os mapas existentes. Avaliar impacto em export Windows e Ubuntu.
- **ProtonScatter**: é editor de distribuição de objetos, não substitui a renderização eficiente em MultiMesh já existente. Útil para adensamento visual apenas se gerar dados determinísticos ou prefabs estáticos exportáveis e preservar corredores/jogabilidade.
- **GridMap**: usar em protótipos modulares; atual `EnvironmentKit` já consolida lotes/colliders e é mais adequado à Favela procedural.
- **Object pooling**: auditar sistemas de armas/efeitos que já tenham reuso antes de criar outro pool; spawn inicial de mapa precisa ser perfilado separadamente.
- **LOD**: já está ativo em muitos objetos. Inspecionar flags de import de GLB e aplicar LOD em assets complexos, não em toda malha procedural indistintamente.

## Critérios de promoção
1. Teste estrutural passa e o mapa com occluders conserva line-of-sight nas casas abertas, escadas, portas, lajes e sobre morro.
2. Multiplayers cliente-servidor recebem as mesmas colisões, jogabilidade, seleção de pontos e tiros.
3. Medições repetidas demonstram melhora material de P95/P99 ou redução de draw calls sem regressão de build_ms, memória e stutter.
4. Testar Favela padrão, Favela V2 (em branch independente) e cenários de longa distância onde occluders podem ser custo inútil.

## Evidências locais de benchmark (GTX 1650, Godot 4.7.2 Forward+, 1080p)
Um passe por configuração, três posições de câmera, 180 frames por posição depois de 60 de aquecimento, sem bots. **Há testes de outras IAs executando na máquina; a coleta é exploratória, não gate de release.**

| Configuração | Occluders | Build ms | Draw calls P1/P2/P3 | P99 ms P1/P2/P3 |
|---|---:|---:|---|---|
| OFF padrão | 0 | 10104 | 1529 / 1208 / 631 | 11.695 / 9.879 / 7.584 |
| ON sem limite por célula | 7526 | 10384 | 1093 / 198 / 174 | 9.186 / 6.985 / **11.08** |
| ON limite 32 m | 1256 | 10234 | 1522 / 1193 / 585 | 9.554 / 7.831 / 5.970 |
| ON limite 16 m | 3619 | 10399 | 1517 / 1155 / 570 | **14.518** / 9.639 / 5.156 |

**Escolha provisória: 32 m**. Limite de 16 m piorou o P99 da primeira posição; sem limite piorou o P99 da terceira, apesar de derrubar draw calls. A versão 32 m reduz o número de occluders e apresentou P99 melhor em todas as três posições nesta única coleta. É uma tendência, **não evidência estatística**; a redução de draw calls de 32 m é modesta. Benchmark concorrente ou disputa de foco podem alterar o resultado. Não há autorização técnica para habilitar em produção.

### Situação dos testes e limites
- Import Godot 4.7.2 via editor/headless: sucesso.
- `tests/favela_occlusion_pilot_qa.gd`: **11/11 PASS**, incluindo default-off, compatibilidade com escritório, whitelist, colisão do servidor e teto por célula.
- `git diff --check`: sem problemas.
- Teste de câmera/pixel visual com lajes e interiores, campanha de pares A/B sem concorrência, 22/28 bots reais, combate multiplayer e P99 no spawn: **pendentes**.
- Nenhuma dependência externa (Terrain3D/ProtonScatter) foi instalada nem mapa substituído nesta fase.
- Não há ganho prometido de FPS; objetivo do piloto é provar se o culling vale o custo extra de CPU, RAM e construção do mapa.

### Candidato mantido
`set_meta("occluder_cell_size",32.0)` nos mapas Favela; flag `--favela-occlusion-pilot`. Nem `origin/main`, nem release recebem esta feature por padrão.
