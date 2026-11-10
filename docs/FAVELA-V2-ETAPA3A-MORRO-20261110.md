# Favela V2 — Etapa 3A: morro esquerdo, primeiro bloco funcional

**Data:** 10/11/2026
**Branch:** `ia/favela-v2-phase3-west-stairs-20261110`
**Base:** `e3ff20e` (Etapa 2 física da V2).

## Regra do usuário preservada
O morro da esquerda é um setor *lateral* de casas e escadões. Existe exatamente uma ligação física/topológica para o miolo, pelo portal `l00`. Não existe corredor atravessando o morro até a base norte. Os paredões são terrenos rochosos sólidos, NÃO caminhos.

## Implementado

- `modes/war/library/favela_v2_stair_tread.tscn`: módulo reutilizável de degrau de concreto 2,24 × 0,14 × 0,79 m, com colisão física, textura albedo/normal, metadados de superfície e limite de visualização. Registrado no catálogo de prefabs do editor Godot.
- `modes/war/scripts/favela_v2_west_hillside.gd`: gerador determinístico de **5 lances de escadão**, links `l02`, `l03`, `l04`, `l07`, `l09`. Total inicial **437 degraus**, colocados seguindo as alturas do terreno.
- **Otimização importante:** as faces de cada lance são agrupadas em **uma única colisão estática por lance** (5 no total) e, no cliente, uma `MultiMeshInstance3D` por lance representa os degraus visíveis. O servidor não gera MultiMesh decorativo. O protótipo anterior de uma instância física por degrau NÃO foi adotado.
- Corrimão metálico simples, **356 elementos visuais** agrupados em MultiMesh, **sem colisão** e sombras individuais, para não invadir o corredor.
- **55 casas no morro** posicionadas de forma determinística, utilizando o prefab existente `favela_casa_laje.tscn`. São mais de uma altura, adaptadas ao relevo, afastadas de cruzamentos, vielas e paredes rochosas. São volumes reais com `StaticBody3D`, iguais no cliente e na autoridade, não só desenhos da prévia.
- `plan_houses()` mede inclinação local, proximidade com ruas/vielas e cristas, e separação entre casas antes de criar instâncias. Portas/ruas não ganham os caminhos de terra rejeitados pelo usuário.
- O novo bairro é gerado **isoladamente**, sem modificar `WarFavelaMap`, as bases ou o menu publicado. `build(parent,visuals,with_houses)` permite separar teste de percurso de teste de ocupação.

## Testes feitos

**Godot 4.7.2 no JJ7U3 com GTX 1650:**

1. `tests/favela_v2_west_qa.gd` — **PASS**: 2.550 checks, 5 lances/437 degraus, 55 casas, 33 raycasts sobre degraus sem falhas, 264 consultas de cápsula ao longo do eixo das vielas com **zero colisão com casas**. Todos os degraus mantêm contato com terreno físico e há 1 único portal para o miolo.
2. `tests/favela_v2_west_walk_qa.gd` — **PASS**: seis percursos com `CharacterBody3D` e **`GameStepMotion` real** (3 lances, ambas as direções); todos avançam, zero ticks de recuo, desvio vertical máximo por frame de ~0,055 m, sem bloqueios. O teste usa `with_houses=false` só para isolar escadas; o QA estrutural separado testa as casas em todos os eixos dos becos.
3. `tests/favela_v2_west_visual_qa.gd` — **PASS**, quatro capturas reais em Forward+ / NVIDIA GTX 1650: visão geral do bairro, escadão, única entrada e platô/mirante. Imagens em `docs/images/favela-v2-*.png`.
4. A mesma base do terreno da Etapa 2 é reutilizada com 54 células, 16 barreiras rochosas e 29 links; não se alterou a geometria desses recursos.

## Limites e próximas partes

A **Etapa 3A é um blockout jogável em física**, ainda não a favela final. A arte das casas ainda tem pouca variedade; falta o acabamento orgânico dos paredões, textura detalhada do solo, bases de sustentação de casas em inclinações fortes, platôs projetados com piso físico, pátios habitados, escadarias secundárias e mirantes com cobertura.

**Atenção:** os seis percursos validam lances selecionados e trechos parciais, não o percurso integral sob ação de multiplayer/IA. Antes de liberar V2, precisamos ensaiar os cinco lances e os cotovelos, navmesh dos bots, FPS/frametime P95/P99 com 0/12/22 bots e sessão ENet real.

### Etapa 3B sugerida
Construir pátio e platôs do morro, bases de casas e variantes de fachada/janelas, escadas de ligação em curva. Incluir QA de **100% das transições** entre as rotas, teste de bots chegando ao mirante e medição de custo gráfico. Preservar apenas uma entrada pelo miolo.

**Nenhuma alteração foi mesclada à main ou à build do servidor.**
