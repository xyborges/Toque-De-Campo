# Oito falhas antigas da su?te de combate ? corre??o verific?vel

Base: commit 6a88aac (corre??o de 16 regi?es). Branch ia/combat-eight-regressions-20261109.

## Falhas e interven??o

- Seis testes de orienta??o da Glock/FAL: modelos procedurais atuais t?m cano voltado ao eixo local -Z; a fixture antiga usava eixos laterais. A sniper importada mant?m eixo +X. Corrigido o teste, sem alterar armas.
- Menu: UIFocus.close_top() deixava vis?vel o overlay fechado durante o fade, mesmo ap?s mostrar o menu anterior. Quando houver outro modal abaixo, oculta o overlay imediatamente. O ?ltimo modal mant?m o fade.
- Alcance: a FAL atual tem 1.100 m, n?o 80 m. O teste passa a configurar explicitamente o proj?til de QA em 80 m antes de avan?ar um passo f?sico de 1 segundo, comprovando o clamp sem mudar o alcance de produ??o.

## Gates

- tests/combat_integration.gd: 92/92 PASS, exit 0, nenhum erro.
- tests/ui_navigation_phase2.gd: 11/11 PASS, exit 0.
- tests/war_menu_navigation_quick.gd: 9/9 PASS, exit 0.
- Dano 16 regi?es 129/129 PASS no pai 6a88aac; R2C 406/406 e ENet 18/18 precedentes.

Logs work/combat-eight/final.log, ui-navigation.log, war-menu-quick.log.

Sem ativa??o R2C remota, sem merge P1k, sem alterar bots/rede. Nenhuma build publicada. PR isolado da candidata 1.13.10.
