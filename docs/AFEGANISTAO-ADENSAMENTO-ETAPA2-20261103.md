# Mapa Afegão — adensamento v12 / etapa 2 — 03/11/2026

**Estado:** implementado localmente, testado no Godot 4.7.2, NÃO PUBLICADO.
**Escopo:** somente mapa afegão e biblioteca equivalente. Sem alteração do heightmap, da semente 712907, das estradas, casas existentes, spawns, armas, bots, outros mapas ou cenas autorais.

## Mudanças efetivamente aplicadas

A etapa v11 permanece ativa: 154 peças físicas (100 taludes, 46 muros, 8 anexos). A v12 acrescenta:
- **82 coberturas físicas:** 49 bermas de erosão, 20 ombros de leito seco e 13 anexos rurais adicionais, com 12 em um raio de 190 m do setor central (-260, 70).
- **1.135 plantas/arbustos visuais** distribuídos ao redor das bermas, propriedades e corredores rurais; sem colisores individuais e sem sombra por instância.
- **770 microdetalhes visuais**, incluindo vegetação seca, manchas de cascalho e capim de margem. Distância visual curta, sem colisão.
- Modelos reutilizáveis `erosion_berm_v12.tscn` e `wadi_bank_v12.tscn`; colisão convexa, mesmo posicionamento no servidor headless, materiais compartilhados, LOD, encaixes, superfície dirt e metadados de resistência.
- Banco físico inclui as 236 novas peças de v11+v12. O conjunto anterior de 184 coberturas de campo continua separado e preservado.

O terreno físico principal não foi editado: bermas baixas são módulos aditivos acompanhando a inclinação; não criamos depressões de altura reais nem mudamos estradas/parcelas. Em contrapartida, a proteção física é visível até 2.300 m e a vegetação com LOD distante alcança 1.800 m.

## Desempenho da implementação

- Cobertura física sem lógica por instância; agrupamento visual por tipo em células de 640 m, mantendo colisões individuais.
- Arbustos: 35 lotes próximos (até ~150 m) e 15 lotes de silhueta distante (150 a 1.800 m).
- Microdetalhes: 332 grupos de origem reunidos em 184 lotes gráficos, com alcance de ~75 m.
- Sem efeitos volumétricos, folhas com física ou GI adicional.
- Câmeras fixas, 1280 x 720, Compatibility, GTX 1650 (amostras pontuais sem bots):
  - Vista central: 581 draw calls antes; 610 depois (+29, ~5%).
  - Vista do wadi: 307 antes; 334 depois (+27, ~8,8%).
  - Vista distante: 951 antes; 1005 depois (+54, ~5,7%).
- Capturas idênticas antes/depois: `work/afghan-stage2-before-view{0,1,2}.png` e `work/afghan-stage2-after-view{0,1,2}.png`.
- Esses valores NÃO são FPS nem benchmark aprovado. A compilação de frames, GPU, física e 28 bots precisam de comparação A/B estável após a otimização paralela.

## Testes e pendência crítica

- `tests/afghan_stage2_qa.gd`: 82/82 peças bloqueiam raios físicos; 82/82 acessíveis no terreno seco; 82/82 respeitam afastamento de vias; layout determinístico.
- `tests/afghan_tactical_density_qa.gd`: 154/154 peças v11 validadas anteriormente.
- `tests/afghan_stage2_visual.gd`: três capturas em janela real e Compatibility, sem erros fatais.
- `python tools/maps.py audit --map afghan --output work/afghan-stage2-map-audit`: **1.521/1.521 amostras com superfície**, 161/162 spawns válidos, mas `Afghan prepared navigation does not match sources`; auditoria exit 1.
- O problema de navegação preparada já existia ANTES da v12, e as peças novas requerem rebake. `modes/battle_royale/navigation/navigation.gd` agora inclui as fontes v11/v12 no hash de integridade, evitando aceitar malha antiga.
- Regenerar o BR, depois o pipeline oficial de mapas e a navegação do Guerra, com backup completo dos diretórios preparados, antes de release. Não adulterar hashes e não regenerar no meio dos benchmarks de outros chats.
- Alguns scripts QA produzem avisos de Jolt no encerramento da SceneTree; não afirmar ausência de vazamentos até investigação própria.

## Controles e arquivos

- `--afghan-density-before`: desliga as duas etapas v11/v12.
- `--afghan-density-stage2-before`: preserva a v11 e desliga apenas a v12.
- `modes/battle_royale/map/afghan_density_stage2.gd`: distribuição física e lotes visuais.
- `modes/battle_royale/map/afghan_tactical_density.gd`: integração aditiva.
- `modes/battle_royale/library/build_earthworks_v12.gd`: gerador autoral, nunca sobrescreve cenas existentes.
- `modes/battle_royale/library/erosion_berm_v12.tscn`, `wadi_bank_v12.tscn`, `catalog_v2.json`, `catalog_v2.tscn`: biblioteca regional.
- `modes/battle_royale/navigation/navigation.gd`: hash das novas fontes.
- `tests/afghan_stage2_qa.gd` e `tests/afghan_stage2_visual.gd`: validações.

**Liberação condicionada:** validado visualmente e balisticamente, mas **sem aprovação de navegação preparada e de 60 FPS com 28 bots**. Manter local, não publicar.
