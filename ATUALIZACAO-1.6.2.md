# Atualização 1.6.2 — histórico de integração

**Integrada à 1.6.3/build29, publicada em24/10/2026.** A 1.6.2 foi preparada localmente e não foi distribuída separadamente. O estado atual e os resultados finais estão em [ATUALIZACAO-1.6.3.md](ATUALIZACAO-1.6.3.md). O restante desta página preserva o rascunho escrito durante a integração; suas pendências não representam a versão publicada.

## HUD dos equipamentos de Guerra

- Ao segurar RPG-7 ou Stinger, o cabeçalho mostra o lançador e suas cargas. A munição da arma guardada permanece no respectivo slot.
- Os atalhos **7 · RPG-7** e **8 · Stinger** dividem um único estoque. O HUD identifica explicitamente as cargas compartilhadas, sem sugerir duas reservas independentes.
- **Médico:** G usa o kit médico; quatro cargas iniciais e intervalo real de um segundo após uso válido.
- **Soldado:** G/3 mantém a granada existente; H reabastece aliados próximos, com três cargas próprias e intervalo de seis segundos. Granadas e reabastecimentos têm estoques diferentes.
- **Atirador:** G mantém a observação existente, com quatro cargas iniciais e intervalo de um segundo após uso válido.
- **Antitanque:** mostra os intervalos reais de 5,5 s do RPG e 6,5 s do Stinger. A indicação do Stinger distingue ausência de alvo, aquisição e trava completa.
- Morte, ausência de implantação ou ocupação de veículo retiram o indicador de equipamento de infantaria. Espera por equipes e recursos esgotados têm estados distintos. Dados ainda desconhecidos aparecem como sincronização, sem inventar munição.

Os quatro slots principais permanecem. O painel usa a paleta do login e reutiliza os mesmos controles, com atualização de texto/seleção somente quando o estado muda. Não foram acrescentados atalhos nem regras de combate.

### Evidências do HUD

`tests/war_class_hud.gd` aprovou **49 verificações nativas** usando WarPlayer e WarVehicles reais em um piso de teste pequeno, com ações válidas de cura, observação, reabastecimento e disparo de RPG. Exercita consumo, cooldown, estoque compartilhado, retorno ao fuzil, morte, implantação e veículo. Capturas próprias em 1024 × 768 e 1920 × 1080, em FPP e TPP, foram inspecionadas. Relatório em `tests/war-class-hud-results.json`; log em `work/war-class-hud.log`.

A regressão nativa `tests/equipment_hud.gd` também aprovou seus **25 casos** depois da alteração, incluindo slots, munição, pavio e oclusão do contador de granada. Log em `work/equipment-hud-162.log`.

O teste isolado não substitui a prova de replicação online. A regressão `tests/war_multiplayer.gd` foi ampliada para exigir no cliente os recursos e contadores confirmados pelo servidor; o resultado final deverá ser incluído após essa integração. A replicação de `charges`/`last_gadget` após consumo ainda é uma dependência da implementação de autoridade, não resolvida por uma contagem presumida no cliente. Não há medição nova de FPS nesta revisão de HUD.

## Demais frentes desta integração

O som distante de Guerra, a persistência de mortes online e a pausa/retomada de recarga por arma estão em tarefas separadas. Este rascunho não as declara publicadas nem concluídas. O histórico e as limitações anteriores permanecem em `REVISAO-AUDIO-RANKING-HUD.md` e `GUERRA-DESEMPENHO.md`.
