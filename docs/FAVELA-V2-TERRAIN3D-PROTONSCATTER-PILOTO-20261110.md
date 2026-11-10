# Favela V2 — teste comparativo Terrain3D e ProtonScatter

**Data:** 10/11/2026
**Godot:** 4.7.2, Forward+, Windows 11, GTX 1650, 1920×1080
**Branch:** `ia/favela-v2-terrain3d-scatter-bench-20261110` (derivada de `9e6302b`)
**Status:** pesquisa experimental. Não incluir no jogo, `main`, servidor ou release.

## Decisão

**Não substituir o terreno atual pelo Terrain3D nem o MultiMesh existente pelo ProtonScatter nesta etapa.** Ambas as bibliotecas funcionaram em uma worktree isolada, mas nenhuma demonstrou melhoria repetível da fluidez do mapa completo. A importação do Terrain3D acrescentou latência de construção e, em duas posições da câmera, piorou o tempo médio por quadro.

Se futuramente for útil ao *editor* para esculpir mapas, o Terrain3D precisa de um segundo piloto com heightmap permanente e colisão/navmesh de cliente/autoridade verificados. O ProtonScatter pode continuar útil para **autoria procedural** de vegetação, mas seu renderizador MultiMesh não é inerentemente superior ao MultiMesh que já existe no jogo.

## Dependências reais instaladas e ensaiadas

- **Terrain3D 1.1.0-stable** oficial `https://github.com/TokisanGames/Terrain3D/releases/tag/v1.1.0-stable`; SHA256 do ZIP `51B78BC758F5759CBC8EAAAB14E5CF4E8661717E265FDD760F5ABF945F15B243`.
- **ProtonScatter** `https://github.com/HungryProton/scatter` commit `7198cc00078ebde61307578137c3f35223c6e438`.
- Instalação local em `addons/terrain_3d/` e `addons/proton_scatter/` **não versionada**. `tools/favela_v2_plugin_pilot_setup.ps1` automatiza download, valida a versão e suprime a varredura do ZIP extraído pela extensão `work/.gdignore`. **Não vendorizar binários na Git do jogo**.
- Houve uma falha inicial de classes duplicadas, porque o zip extraído estava dentro de `work/`. Corrigido com `work/.gdignore` e remoção do caminho duplicado do cache de extensões local. Após isso os dois plugins foram carregados e executados.

## Ensaio de heightmap: terreno verdadeiro da V2

`tests/favela_v2_terrain3d_pilot.gd` amostra `FavelaV2Terrain.height_at(x,z)` em imagem 256×256 pixels com espaçamento de **4 m**, importe via `Terrain3DData.import_images` e valida quatro pontos conhecidos.

**PASS:** quatro regiões importadas no Terrain3D; altitude da Polícia 10 m e dos traficantes 98 m preservadas; desvio máximo **0,4517 m** em quatro nós, pelo reamostramento de 4 m. Preparação/importação na execução headless: aproximadamente **666 ms**. Esse desvio é **grande demais para trocar o visual por Terrain3D mantendo a colisão antiga sem nova homologação de física e movimento**.

Na A/B gráfica, a geometria original de colisão continua construída e idêntica, seus 49 meshes de solo ficam invisíveis; o Terrain3D adiciona apenas a superfície visual com `collision_mode=Disabled`. Assim, o piloto não arrisca mudar `GameStepMotion`, tiros, navegação ou a autoridade multiplayer. Os outros elementos (197 casas, vias, escadarias, contornos rochosos) são os mesmos.

## Ensaio ProtonScatter

`tests/favela_v2_scatter_pilot.gd` reutiliza **`favela_arbusto_encosta.tscn`** e produz 480 posições determinísticas (seed 20261110), afastadas das 29 vias, bases e campinho. Alimenta o backend **real de MultiMesh do ProtonScatter** com as posições validadas, sem gerar colisão de arbustos. Resultado: **480/480 desenhados, zero objetos físicos novos, zero arbustos nos corredores**. Comparação separada usa a mesma malha/posições/alcance no MultiMesh nativo.

**Limite:** este ensaio testa a etapa de instanciamento/renderização da biblioteca com transformações pré-calculadas, **não** a geração por regras e modificadores do editor. Renderizações foram feitas sem atualização procedural durante o jogo.

## Benchmark GPU A/B — duas passagens, ordem invertida

`tests/favela_v2_terrain3d_scatter_benchmark.gd`: três câmeras a nível da rua (baixa, miolo, alta), 120 frames cronometrados após 75 de aquecimento, 197 casas e zero bots. Comparação base vs Terrain3D e MultiMesh nativo vs ProtonScatter em ordens invertidas. Também executado um teste combinado Terrain3D + ProtonScatter. **Valores abaixo são a média de duas execuções de cada variante.**

| Comparação terreno | Atual | Terrain3D | Leitura |
|---|---:|---:|---|
| Construção total | **993 ms** | 1.436,5 ms | +443,5 ms Terrain3D |
| P99 baixa | 6,09 ms | **5,57 ms** | pequena melhora com variação |
| P99 miolo | **4,60 ms** | 5,77 ms | **regressão** |
| P99 alta | 4,45 ms | 4,43 ms | equivalente |
| Quadro médio miolo | **2,24 ms** | 3,31 ms | **regressão acentuada** |
| Quadro médio alta | **2,21 ms** | 3,28 ms | **regressão acentuada** |
| Draw calls baixa | 163 | **137** | menos chamadas, mas não garante melhor frametime |

| Comparação de 480 arbustos | MultiMesh nativo | ProtonScatter |
|---|---:|---:|
| Construção total | 1.093,5 ms | **1.084,5 ms** |
| Draw calls baixa | 163 | 163 |
| Draw calls miolo | 111 | 111 |
| P99 baixa | **4,91 ms** | 5,43 ms |
| P99 miolo | 4,97 ms | **4,26 ms** |
| P99 alta | 4,59 ms | **4,27 ms** |

A variação do P99 entre duas execuções é expressiva; os valores não justificam adoção generalizada. O combinado Terrain3D + ProtonScatter apresentou P99 de 8,38 ms no miolo da execução única, pior que a cena base da mesma primeira rodada. Dados de todas as **9 execuções**, inclusive build_ms, draw calls, média, P50/P95/P99, estão em `docs/benchmark-results/favela-v2-terrain3d-protonscatter-20261110/metrics.json`.

**Limitações:** foco da janela e carga concorrente da GTX 1650 não controlados; não há bots, multiplayer ENet, combate, partículas ou spawn sob carga. A V2 ainda é um blockout que não representa as ~104 mil instâncias visuais da Favela original. Altas médias de FPS de uma cena vazia não comprovam ausência de travadas em combate.

## Recomendação operacional

1. **Manter o gerador atual**, pois a V2 já produz altura idêntica no cliente/servidor e o Terrain3D não reduziu consistentemente o P99; uma troca agora arriscaria discrepância física de dezenas de centímetros.
2. **Continuar com MultiMesh/LOD nativos**, preservando seu perfil de renderização e sem criar colisores decorativos; ProtonScatter pode servir ao editor para criar dados estáticos, não como nova camada obrigatória de runtime.
3. **Priorizar investigar as travadas reais:** picos de criação do mapa, custo de física e navegação com 22/28 bots, criação de cadáveres, disparos/efeitos e regiões de alta densidade. A/B com **0/12/22/28 bots**, foco de janela garantido, P95/P99 e tempo de spawn isolado; só depois otimizar o gargalo medido.
4. Não adicionar plugins ao `main` ou servidores. Os testes são opcionais e não devem gerar erro de parser na ausência de `addons` (scripts do piloto carregam ProtonScatter por `load()` dinâmico).

**A versão pública do Toque de Campo não foi alterada.**
