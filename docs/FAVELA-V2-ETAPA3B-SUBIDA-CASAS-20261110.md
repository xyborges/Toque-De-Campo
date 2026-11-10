# Favela V2 — Correção de direção da subida e reuso das casas originais

Data: 10/11/2026.
Branch: `ia/favela-v2-uphill-reuse-houses-20261110`, derivada de `abdcb85`.
**Não é uma atualização da main ou do servidor público.**

## Decisão do responsável pelo mapa

O esboço é uma favela sendo conquistada **de baixo para cima**, e não um bairro plano: a Equipe 1 **Polícia** parte do vale e a Equipe 2 **Traficantes** controla a base no alto do morro. O setor de casas à esquerda segue acessível **somente pelo miolo central** — não é um atalho entre as bases.

## Reprojeto da topografia

O arquivo `modes/war/scripts/favela_v2_terrain.gd` agora define altitude dos 25 pontos de circulação com uma progressão explícita: Polícia em **10 m**, entrada em 14–21 m, praça em **30 m**, miolo em **40 m**, comércio e escada central em **49–58 m**, ruas altas em **66–87 m**, base dos traficantes em **98 m**. A diferença vertical entre bases é **88 m**; o percurso dos bots no grafo ainda tem ~836 m, com curvas, não uma reta.

O solo natural recebeu inclinação norte–sul correspondente, mantendo a grade determinística de 54 células e a malha física compartilhada no servidor/cliente. O morro esquerdo sobe de portal 43 m até mirante 83 m, mas **o topo dos traficantes continua mais alto** e sem acesso por esse bairro.

`modes/war/scripts/favela_v2_topology.gd` declara `TEAM_BASES={1:"base_sul",2:"base_norte"}` e nomes das equipes. São âncoras para a integração de spawn futura; **não alteram os spawns atualmente publicados**.

## Reaproveitamento real da biblioteca de modelos antiga

O gerador `modes/war/scripts/favela_v2_west_hillside.gd` continua instanciando diretamente `favela_casa_laje.tscn` para **58 casas físicas**. A nova composição usa **oito cenas existentes** adicionais: `favela_porta_entrada`, `favela_janela_grade`, `favela_janela_madeira`, `favela_toldo`, `favela_comercio_fachada`, `favela_varal`, `favela_laje_domestica` e `favela_puxadinho_chapa`.

São **cinco tratamentos visuais** de casas, com cores de parede compartilhadas, janelas e coberturas diferentes e **220 detalhes reutilizados**. Não foi sobrescrita nenhuma cena original. Para evitar o problema anterior de vibração nas lajes, detalhes são decoração sem colisão própria; a casa mantém **um único colisor estrutural** no cliente e na autoridade. O servidor não carrega esses detalhes visuais. Propriedades de navegação/contato específicas de lajes serão trabalhadas separadamente quando houver acesso aos telhados.

Os escadões permanecem com **437 degraus agrupados em cinco corpos de colisão**, e os corrimãos permanecem sem colisão decorativa.

## QA executado em Godot 4.7.2

- `tests/favela_v2_uphill_qa.gd`: **49/49 PASS**; equipes/bases coerentes, +88 m, topo mais alto que todos os outros pontos, piso físico nos nós, desvio máximo ~0,177 m, 58 casas, 5 variantes, 437 degraus, zero módulos de decoração no servidor.
- `tests/favela_v2_terrain_qa.gd`: **24/24 PASS**; 54 chunks, 20.691 vértices amostrados, 40.800 triângulos físicos, piso presente em 25 pontos, gradiente máximo de vias comuns ~26,86%, escadas ~26,43%.
- `tests/favela_v2_west_qa.gd`: **2.727/2.727 PASS**; 58 casas, 33 raycasts de escadas sem falhas, 264 amostras de cápsula ao longo das vielas sem colisões com casas.
- `tests/favela_v2_barrier_walk_qa.gd`: **4/4 cenários PASS**; entrada pelo miolo permitida, barreiras norte, sul e leste impedem passagem via `GameStepMotion`.
- `tests/favela_v2_west_walk_qa.gd`: **6/6 trajetos PASS**; três lances testados nas duas direções, zero recuos, avanço contínuo, variação vertical máxima de ~0,066 m/quadro.
- `tests/favela_v2_topology_qa.gd`: **238/238 PASS**; apenas um portal oeste, nenhum entroncamento indevido.
- `tests/favela_v2_uphill_visual_qa.gd`: **4/4 PNGs PASS** em Forward+ com GTX 1650; confirmou 220 detalhes reutilizados, cinco variantes e **zero colisores extras ativos** nos detalhes. Imagens em `docs/images/favela-v2-uphill-*.png`.

## Limites do protótipo

A topologia ainda é candidata, a base superior tem **altitude e associação de equipe corretas**, mas **não tem assentamento final, spawns de equipe nem objetivo de captura integrado ao modo Guerra**. Ainda faltam o bairro do topo, praça e campinho, terraços/fundações de casas, transições completas de todas as escadarias, bots navegando em multiplayer e FPS/frametime P95/P99 a 1080p no hardware-alvo. Os paredões rochosos da Etapa 2 ainda são blockout visível, não arte orgânica final.

### Próximo módulo recomendado
Montar as residências defensivas no alto da encosta e base dos traficantes, reutilizando o mesmo `favela_casa_laje` e as composições do morro, mantendo área livre para spawn, cobertura e retorno por ruas curvas. Depois testar bots ascendendo desde a Polícia até os objetivos. Não publicar a V2 antes disso.
