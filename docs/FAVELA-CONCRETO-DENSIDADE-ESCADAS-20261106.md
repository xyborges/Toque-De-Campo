# Favela: concreto, densidade de 1,5 m e escadarias — 06/11/2026

## Situação
- Branch de trabalho: `ia/favela-concreto-densidade-escadas`, baseada em `ia/favela-linha-frente-20261106` (`47fc6a8`).
- Somente worktree isolada. Não foi executado merge na `main`, nem push, export ou publicação.
- Mapa preservado: 1.500 × 1.500 metros. Novos morros externos, pontos sequenciais A/B/C/D/E e campo como E permanecem.
- Manifesto oficial da Favela: v25, 68 fontes, `FAVELA_MANIFEST MATCH`.

## Alterações

### Piso urbano de concreto
`favela_map.gd` e `favela_street_art.gd` neutralizam o tom amarronzado. A área urbanizada recebeu base acinzentada e shader que usa a luminância do concreto sem carregar a pigmentação quente da textura. O acabamento final foi ajustado após **três rodadas de screenshots reais no Forward+ 1920 × 1080 com GTX 1650**, evitando tanto o piso bege quanto o cinza branco estourado. A rua mantém asfalto; morros e faixa natural nas bordas preservam terra, grama, pedras e vegetação. Declives de corte deixam terra local e erosão.

### Casas próximas, sem invadir umas às outras
`favela_layout.gd` recalibra tamanhos para aproximadamente 11,3–11,7 m, passo urbano de 13,35 m e posicionamentos 78 × 97, respeitando a reserva de pelo menos **1,5 metro entre footprints**. O posicionamento final considera outras casas, proximidade das vias, objetivos, campo e bases, sem remover as funções existentes.

Resultado medido no teste próprio:
- **4.313 casas**; referencial na branch anterior: 4.197 (+116, cerca de 2,8%).
- **1,507299 m** de menor afastamento efetivo entre duas casas.
- **4.749 pares** de vizinhos entre 1,5 e 2,6 m.
- 81,8% das bordas amostradas das ruas têm uma casa em até 5 m; 1,0% têm vazios maiores de 15 m.
- Nenhuma sobreposição de lotes e nenhuma invasão de vias.
- 3.355 casas com partes empilhadas; 1.103 intervenções de laje; 191 frentes comerciais.

### Escadarias de beco
O novo gerador `favela_pedestrian_stairs.gd` identifica trechos íngremes somente nas rotas `MINI_STREETS`, reservando as ruas veiculares. Um módulo de degrau de cimento de 1,05 × 0,82 m, `favela_degrau_beco.tscn`, foi incorporado ao catálogo de arquitetura e prefabs. Os degraus são gerados **na lateral da viela**, com colisão física e corrimãos visuais, para deixar o eixo de circulação livre. O sistema não cria uma nova rede de navegação: mantém a mesma topografia e respeita objetivos/bases.

Resultado final: **31 lances, 217 degraus físicos**. Além desses, a rede preexistente mantém **142 acessos às lajes e 16 passarelas**. As plataformas de desembarque das lajes foram recuadas 0,15 m para recuperar folga na última pisada; a mudança foi testada em geometria real.

## Validação e testes

| Verificação | Resultado |
|---|---|
| `tests/favela_concrete_density_stairs_qa.gd` | PASS, 261 verificações, 4.313 casas, distância 1,507m, 31 lances |
| `tests/favela_frontline_qa.gd` | PASS 63/63, avanço e contra-ataque preservados |
| `tests/favela_architecture_qa.gd` | PASS, 9.491 amostras de física, 142 escadas e 16 passarelas |
| `tests/favela_spatial_review.gd` | PASS, 18 vias, 0 casas sobre vias, 0 lotes sobrepostos |
| `tests/favela_road_collision_1138_qa.gd` | PASS, 0 bloqueios |
| `tests/favela_operation_smoke.gd -- --favela-visuals` | PASS, 0 obstruções na avenida ou em mini-ruas, 104.789 instâncias visuais |
| `tests/favela_runtime_qa.gd -- --favela-bots` | PASS, 39 verificações com 28 bots e 8 veículos |
| `tests/favela_hillside_atmosphere_qa.gd` | PASS, 40.753 verificações, 1.850 árvores, 4.700 arbustos, 13.334 capins |
| ENet captura/contra-ataque de setores C→D→C | PASS, 1 servidor e 2 clientes, 16/16 |
| ENet 28 bots + 2 jogadores | PASS, 1 servidor e 2 clientes, 18/18 |

O primeiro protótipo falhava em 3 amostras de folga nas lajes e 3 amostras de passagem em mini-ruas. As colisões foram identificadas via `PhysicsDirectSpaceState` e corrigidas; **retestes de arquitetura e smoke passaram**.

**Ressalvas**: O teste unitário de densidade avisa sobre algumas instâncias Godot remanescentes no encerramento do processo, apesar de retornar código 0 e PASS. O teste ENet confirma a rede local, não substitui teste humano de latência real ou combate intenso. O perfil de GPU precisa considerar P99 e combates com tiros, e não só FPS médio.

## Capturas e evidências

Capturas reais do jogo em Forward+ na GTX 1650, 1920×1080:
- `alto-rua-da-favela.png` — comparação de piso da rua
- `alto-setor-central.png` — percepção de densidade e paleta
- Versão anterior e suas imagens de campo/morros preservadas em `%TEMP%\favela-concreto-cinzento-final-20261106`.
- Captura final cinza médio em `%TEMP%\favela-concreto-cinza-medio-20261106`.

Logs dos testes de geometria/servidor estão em `%TEMP%\favela-concreto-densidade-20261106`.

## Material final e desempenho (revisao de 06/11)

O concreto anterior ja tinha o especular desativado e roughness alta. A aparencia de piso polido vinha principalmente da falta de detalhes no albedo, nao de reflexos. A revisao em favela_street_art.gd preserva a luminancia da textura original e acrescenta ruido reproduzivel em tres escalas, granulos, manchas de drenagem e reparos. O ruido e gerado em uma textura seamless mipmapped de 256 x 256 pixels. Nenhuma casa, colisao ou regra de combate foi alterada nesta revisao visual.

Capturas reais: TEMP/favela-concreto-granulado-20261106/alto-rua-da-favela.png e alto-setor-central.png, Godot 4.7.2, Forward+, GTX 1650, 1920x1080, qualidade Alta. O piso agora apresenta manchas e granulacao, preservando morros com terra.

Depois da mudanca, o teste de densidade PASS 261/261 (4.313 casas; 1,507m minimo; 31 lances; 217 degraus). O smoke visual PASS (104.789 instancias visuais e 11.624 formas de colisao). Manifesto Favela v25/68 fontes MATCH.

Benchmark exploratorio, nao oficial: 18,0 segundos sem tiros, GTX 1650, 1080p, Forward+, Alta, 100% de escala, VSync off, 28 bots e nenhum Godot concorrente. Resultado: 53,61 FPS medios; p50 17,52ms; p99 37,40ms; pior quadro 55,22ms; fisica p99 23,48ms; mediana 1.369 draw calls; 965 quadros. Ainda NAO atinge a meta de 60 FPS estaveis. Necessarios testes de combate e uma rodada oficial de 60s com dados brutos para aprovar performance.

## Lançamento
O trabalho está pronto **para integração/revisão em branch**; não está autorizado como build publicada. Para o lançamento, primeiro medir o desempenho do mesmo commit, avaliar interação real em combate e decidir se integra a `main` com o restante das IAs.
