# Favela — cimento urbano, veículos estacionados e infraestrutura aérea

**Data:** 05/11/2026  
**Branch de trabalho:** `ia/favela-cimento-urbanidade`  
**Base:** `main`, commit `10d83c8` (1.13.4/build 91 já publicada)  
**Estado:** mudanças de desenvolvimento, sem merge na `main` ou publicação.

## Objetivo visual
Corrigir o excesso de textura de terra entre as casas, substituindo a aparência rural por cimento cinza remendado onde há ocupação urbana, sem cimentar a mata, os barrancos nem as faixas periféricas. Aumentar a leitura lateral e aérea com carros estacionados, lixeiras, pedras soltas, postes, cabos e caixas de emenda de fibra.

## Implementação
- `favela_map.gd`: `_ground_color()` usa paleta de cimento claro na malha urbanizada. O limite foi ampliado até as construções e a avenida periférica após uma inspeção de captura detectar terra excessiva junto às frentes de casas. Solo natural preservado no morro, mata e bordas.
- `favela_street_art.gd`: mistura **real de duas texturas** (cimento e solo), controlada por distância à zona urbana, inclinação e remendos pseudoaleatórios. A máscara de asfalto/concreto viário continua com prioridade absoluta; apenas a aparência muda, não o relevo nem a colisão.
- `favela_map.gd`: distribuição determinística e com `STREET_SPACE.claim()` para objetos físicos: reutiliza `favela_carro_compacto`, acrescenta lixeiras e pequenos montes de pedra. As casas, vias, bases e pontos têm prioridade. Carros só são aceitos quando a inclinação ao longo de sua carroceria é compatível com estacionamento.
- Rede de distribuição: intervalos menores entre postes (avenida 36→28 m, transversais 39→31 m, eixos secundários 33→27 m, ruas menores 29→23 m). Cabos ópticos instalados no alto, sem atravessar o tráfego na altura do jogador; caixas a cerca de 5,35 m. Modelos aéreos reutilizam o batching do projeto.
- Novos prefabs `favela_lixeira_rua.tscn` (1 colisor físico), `favela_pedras_entulho.tscn` (0 colisores), `favela_caixa_fibra_optica.tscn` (0 colisores). Todos com LOD, metadados e registro na biblioteca/editor. Instanciamento pelo sistema setorizado `EnvironmentKit` com setores de até 160 m.

## Contagem real do Godot 4.7.2
- 4.199 casas, 3.255 casas com pavimentos sobrepostos.
- 44 carros estacionados no total, **36 novos** nesta etapa.
- 121 lixeiras, 156 conjuntos de pedras/entulho.
- 359 postes, 339 trechos de fibra e 182 caixas ópticas.
- 24 motos estacionadas já existentes, preservadas.
- 1.005 módulos urbanos anteriores, preservados.
- 101.998 instâncias visuais e 10.769 formas de colisão no smoke visual.
- 49 rotas, 120 escadarias e 12 passarelas preservadas.

## QA
- Import Godot 4.7.2 e parsing: PASS.
- `favela_urbanidade_qa.gd`: PASS; prefabs, LOD, colisores, concreto x solo e contagens aprovados.
- `favela_operation_smoke.gd -- --favela-visuals`: PASS.
- `favela_architecture_qa.gd`: PASS, 8.747 amostras físicas.
- `favela_spatial_review.gd`: PASS; **0 casas na pista**, 0 lotes sobrepostos e 1,5% das bordas a mais de 15 m das casas.
- `favela_runtime_qa.gd -- --favela-bots`: PASS 39/39; 28 bots implantados e 8 veículos sem spawn sobreposto.
- `prepare_favela_manifest.py`: MATCH. Manifesto atualizado para **versão 8, 53 fontes**.

### Pendências para liberação
- No ensaio em GTX 1650, 1080p, Alta, 28 bots, 30 s: **40,4 FPS médios**, p50 20,86 ms, p99 79,10 ms, física p99 27,04 ms e mediana 1.389 draw calls. Havia testes Godot concorrentes das branches de veículos e bots; **não é comprovação de 60 FPS estáveis**. É necessário A/B com baseline isolado.
- No QA multiplayer ENet local, ambos os clientes **passaram 5/5**, enxergando 28 bots + 2 humanos; o processo servidor completou suas 8 verificações, mas registrou erro de ciclo de vida em `bot_director.gd` (leitura de `get_global_transform()` em nó fora da árvore). O runner considerou a rodada **falha**. Esse script é responsabilidade de outra instância ativa; não editá-lo por cima.
- A inspeção visual final deve confirmar concreto nas margens próximas da avenida após a extensão da máscara urbana.

**Não lançar nova atualização a partir desta branch sem reconciliar o bot_director, medir FPS sem concorrência e efetuar merge revisado.**

### Verifica??o final adicional

- Manifesto de desenvolvimento vers?o 9, 53 fontes, MATCH ap?s ?ltima revis?o de m?scara.
- Godot headless: QA de urbanidade e smoke visual novamente PASS.
- Nova captura 1920x1080 da avenida conferida: concreto nas ?reas planas e terra clara ainda presente em um talude.
- Perfil curto p?s-m?scara: n?o usar como A/B conclusivo devido a outros Godots concorrentes.
