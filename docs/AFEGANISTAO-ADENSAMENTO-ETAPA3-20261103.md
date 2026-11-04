# Deserto Afegão — etapa 3 / v13 — 03/11/2026

**Próxima direção visual (04/11/2026):** referência de encosta/trilha do Sinai enviada pelo usuário, adaptada ao Afegão com proteção para loot/spawn. Ver [AFEGANISTAO-REFERENCIA-SINAI-TRILHAS-20261104.md](AFEGANISTAO-REFERENCIA-SINAI-TRILHAS-20261104.md). Registro de plano apenas; v13 não alterada por esta referência.

**Status: aplicado localmente no código e nas cenas; não publicado.**
A otimização de outro chat não foi sobrescrita e nenhum arquivo preparado de navegação foi regenerado nesta etapa.

## Objetivo e referência
Adensar de modo coerente as propriedades e as periferias dos 15 assentamentos afegãos, preservando os caminhos, casas, quintais, rios, lavouras, loot e spawn. Referências visuais: propriedades muradas conectadas por caminhos rurais, como fotografias aéreas de Ghazni / construções rurais afegãs. A arquitetura segue o visual cartunesco atual: sem reconstrução de mapa, nova topografia ou fotorealismo.

## Mudanças em campo

- 12 conjuntos de abrigo rural aberto (12 cenas `rural_shade_shed_v13` instanciadas), 32 trechos laterais/traseiros de muro `courtyard_wall_v2` e 84 microdetalhes em renderização.
- Frente totalmente aberta; reservadas entrada e saída, sem barreiras atravessando o acesso do pátio. Posições determinísticas da mesma autoridade Godot no cliente e no servidor.
- Colisões físicas persistentes e silhuetas visíveis até 2.300 m, com composição estática em lotes e pouca decoração próxima sem colisão.
- A biblioteca recebeu `rural_shade_shed_v13.tscn`, com marcação de entrada, área interior, encaixes e **LootStorage**, material compartilhado e metadados de superfície, resistência, LOD e durabilidade. Catálogos `catalog_v2.json` / `catalog_v2.tscn` atualizados.
- Na v13 existem **12 novos pontos de loot** (um por abrigo), posicionados no armazenamento interno e enviados exclusivamente pela autoridade do modo BR. Os **375 pontos de loot antigos permanecem** e não tiveram localização alterada.
- Não foram criados novos spawns físicos, nem movidos os spawns anteriores. O algoritmo de admissão do BR agora evita a repetição sistemática de posições entre salas, sem mexer nos locais autorais.

## BR: correção da repetição de spawn

A semente de spawn dependia de `seed_value=712907` e `br_generation`, de forma que salas novas podiam repetir o mesmo sorteio. Além disso, `navigation.choose_spawns` usava amostragem com reposição (alguns candidatos examinados repetidamente e outros omitidos), dando vantagem às posições mais distantes.

- `game.gd` gera uma nova semente **no servidor** por rodada, combinando ID de sala, relógio monotônico e semente do mapa. O mapa continua determinístico e não muda de lugar.
- `navigation.gd` analisa todos os candidatos elegíveis, mantém distância mínima de 90 m, favorece áreas com loot e limita a recompensa de separações excessivas para não favorecer sempre cantos remotos. A escolha usa variação pseudoaleatória reprodutível com a mesma semente.
- Até quatro alternativas determinísticas se a seleção não conseguir acomodar a sala cheia; um ponto com colisão inesperada é rejeitado individualmente em vez de bloquear imediatamente a rodada inteira.
- A geração normal do loot também usa a semente variável da rodada. O círculo de jogo, regras de combate, spawn candidates originais e lógica de loot garantido perto de participantes não foram modificados.

## Testes concluídos

- `tests/afghan_stage3_qa.gd`: 12/12 abrigos com bloqueio físico; **32/32 paredes do pátio** bloqueiam raycast; 12/12 entradas livres; zero spawns invadidos; layout determinístico.
- Regressão no estado final: v11 **154/154**, v12 **82/82** e coberturas originais **184/184** passaram novamente; execução encadeada terminou com exit 0.
- `tests/afghan_stage3_br_spawn_qa.gd`: `BRNavigation.install(map, true)` com navegação atual permitiu 40/40 participantes em oito simulações; distância mínima entre participantes em todas as simulações ficou acima de 141 m; o spawn do primeiro participante caiu em oito células distintas. Isto comprova a seleção e as colisões **na navegação antiga carregada para teste**, não certifica a navegação preparada de produção.
- `tests/afghan_stage3_loot_qa.gd`: 12/12 anchors novos acessíveis e 12/12 com loot gerado; simulação produziu 742 drops, respeitando max_items=900.
- `tests/afghan_stage3_visual.gd`: três câmeras antes/depois a 1280x720, Compatibility na GTX 1650, seis imagens locais em `work/afghan-stage3-{before,after}-view{0,1,2}.png`; draw calls 722→754, 946→993, 159→159 nas amostras iniciais.
- `python tools/maps.py audit --map afghan --output work/afghan-stage3-map-audit`: 1.521/1.521 amostras de superfície presentes; 161/162 candidatos a spawn válidos (um rejeitado já conhecido); **falha esperada** no teste de navegação: fontes diferem da navegação preparada.

## Limites e riscos

1. **Bloqueio de publicação:** `modes/battle_royale/navigation/prepared` tem hash/conteúdo antigo em relação às geometrias v11+v12+v13. É obrigatório **regerar as malhas BR**, validar rotas/bots/veículos e depois preparar o pipeline de mapas antes de lançar. Nada foi mascarado por hashes alterados manualmente.
2. Não foi executado benchmark completo 1080p/28 bots, pois existe um esforço paralelo dedicado à otimização. As medições atuais são somente comparativos pontuais de draw calls e carregamento.
3. O layout ainda depende do filtro de declividade e da malha de 5 m; não foi reconstruída a topografia. Conjuntos futuros devem herdar as mesmas reservas de estrada, lavoura, imóvel e acesso.
4. Os testes headless podem registrar no encerramento avisos conhecidos de RIDs Jolt não liberados; não equivalem a falha de colisão, mas devem ser investigados antes do release.

## Controles

- `--afghan-density-stage3-before`: desliga apenas v13 para A/B.
- `--afghan-density-stage2-before`: desliga v12 e, pela cadeia de integração, v13.
- `--afghan-density-before`: desliga v11, v12 e v13.

## Arquivos específicos desta etapa

- `modes/battle_royale/map/afghan_density_stage3.gd`
- `modes/battle_royale/map/afghan_density_stage2.gd` (chamada de integração)
- `modes/battle_royale/map/afghan_map.gd` (métricas)
- `modes/battle_royale/library/build_rural_shed_v13.gd`
- `modes/battle_royale/library/rural_shade_shed_v13.tscn`
- `modes/battle_royale/library/catalog_v2.json`, `catalog_v2.tscn`
- `modes/battle_royale/scripts/game.gd` (spawn seed, loot)
- `modes/battle_royale/navigation/navigation.gd` (hash + seleção de spawn)
- `tests/afghan_stage3_qa.gd`, `tests/afghan_stage3_br_spawn_qa.gd`, `tests/afghan_stage3_loot_qa.gd`, `tests/afghan_stage3_visual.gd`

**Observação:** esta etapa está implementada, mas não há autorização técnica para publicar até que a navegação seja regenerada e os testes de 28 bots sejam repetidos. A simulação das sementes confirma variação; partidas reais com jogadores ainda não foram validadas.
