# Afegão — adensamento tático v11 (03/11/2026)

**Situação:** aplicado localmente; sem publicação. Não equivale a aprovação de FPS com 28 bots.

## Escopo implementado

- Camada aditiva determinística para os 2 x 2 km, sem mover construções, relevo base, casas, estradas, campos ou adições do usuário.
- 154 coberturas novas aprovadas no QA: 100 taludes, 46 muros e 8 anexos rurais; 10 peças no entorno piloto (-260,70).
- Peças só ocupam terreno jogável seco, respeitando declividade, estradas, casas, plantações, rio e separação entre coberturas.
- Biblioteca nova: `rural_annex_v11.tscn` (muralhas de adobe, área interior parcialmente coberta, encaixes, colisões, material compartilhado, metadados).
- Muros e taludes reaproveitam `field_bank_v10` e `field_wall_v10`; renderização de cobertura física continua visível até 3 km.
- Anexos têm alcance visual de 2300 m e colisão presente também no servidor headless. Nenhum detalhe decorativo pequeno ganhou colisão.
- Agrupamento por lote/célula existente; sem script por objeto nem desabilitação de física para ganhos artificiais.
- Desligamento de comparação: executar o jogo com `--afghan-density-before` como argumento do usuário do Godot.

## Arquivos

- `modes/battle_royale/map/afghan_map.gd` (integração na etapa de composição).
- `modes/battle_royale/map/afghan_tactical_density.gd` (geração nova).
- `modes/battle_royale/library/build_tactical_density_v11.gd` (gerador explícito sem sobrescrever existentes).
- `modes/battle_royale/library/rural_annex_v11.tscn` (cena reutilizável).
- `modes/battle_royale/library/catalog_v2.json` (catálogo).
- `tests/afghan_tactical_density_qa.gd` (teste determinismo, autoridade e cobertura balística).

## Evidências

- Teste headless: 154 peças; contagem por família 100/46/8; 10 peças no piloto; **154/154 bloqueiam raycast físico**; posições determinísticas repetidas. Exit 0.
- Teste pré-existente `tests/afghan_field_cover_validation.gd` headless: **184/184** coberturas originais bloqueiam tiros. Exit 0.
- Mesmo teste gráfico em 1280×800 / Compatibility / GTX 1650: exit 0, 184/184; três capturas em `work/afghan-cover-after-*.png`.
- Testes geram avisos conhecidos de alocações Jolt ainda vivas ao encerrar a SceneTree; não representam reprovação no teste funcional, mas merecem investigação separada.

## Pendências de liberação

1. A navegação preparada do Afegão estava **desatualizada antes** desta alteração. Recriar pelo pipeline oficial, na ordem BR -> mapas -> Guerra, sem adulterar hashes e sem conflitar com a otimização em andamento.
2. Executar benchmark A/B com `--afghan-density-before` contra composição nova, na mesma GTX 1650, em gameplay 1080p Médio 100%, 28 bots, mediana/P95/P99 e movimento/veículos.
3. Avaliar acessos e rotas dos veículos/bots, casas, loot, altitudes e pontos elevados na partida real. Só expandir a densidade depois disso.
4. Não publicar ou mesclar com trabalhos paralelos sem revisar os diffs.

**Observação:** esta é uma primeira ampliação física por todo o vale, não uma reforma total da arte e não uma reconfiguração do heightmap. Foram preservadas as decisões prévias de remover rochedos das encostas.
