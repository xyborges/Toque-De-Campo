# Corre??o de identifica??o e dano nas 16 regi?es (09/11/2026)

## Escopo

- Base `origin/main e8891ae` (R2C incorporada como piloto **OFF por padr?o**).
- Branch isolada `ia/r2c-damage-fix-20261109`. Sem altera??o de protocolo ENet, RPC, f?sica 60 Hz, geometria, layers ou ativa??o de poses em bots/remotos.
- Corrige a identidade f?sica das canelas no `WarStance.build_legs()`, as regras de dano e agrupamento de membros, e os testes de raycast direcionados ?s regi?es reais.

## Causa e altera??es

A ?rea `ShinHitL/ShinHitR` existia, mas recebia `hit_region=legL/legR`: os tiros na canela n?o eram diferenciados dos tiros na coxa. O dicion?rio `CombatRules.DAMAGE` n?o inclu?a `shinL/shinR`, enquanto `region_group()` devolvia indevidamente `head` quando recebia tais nomes.

1. `modes/war/scripts/stance.gd`: marcar a regi?o f?sica como `shinL/shinR` sem modificar seus volumes, m?scaras, hierarquias ou movimenta??o.
2. `scripts/combat_rules.gd`: registrar multiplicador `0.75` para `shinL/shinR`, equivalente ao que era aplicado quando essas ?reas eram identificadas como `legL/legR`; agrupar as canelas nas respectivas pernas para contabiliza??o de dano localizado.
3. `tests/combat_integration.gd`: a fixture passa a tentar at? 18 dire??es exteriores reais de raycast, sem desabilitar nenhuma hitbox. Um tiro frontal ?nico pode atingir a perna antes do p? e n?o comprova erro no p?.
4. `tests/r2c_damage_16_regions_qa.gd`: regress?o pr?pria das 16 ?reas ? exist?ncia, collision layer, metadados, coeficiente expl?cito, grupo de membro, chegada do raio e aplica??o real da regra de dano no jogo.

## Resultados reproduzidos na JJ7 ? Godot 4.7.2

| Gate | Resultado |
|---|---|
| QA de 16 regi?es e dano real | **129/129 PASS**, exit 0 |
| R2C PoseFrame | 129/129 PASS |
| R2C estados | 172/172 PASS |
| R2C World | 105/105 PASS |
| **R2C subtotal** | **406/406 PASS** |
| P1a autoridade | PASS com flag `--true-fpp-p1a-authority`, 5 dist?ncias (10, 70, 150, 300, 1700 m), 0 m de diverg?ncia do skip visual |
| P1b CollisionRig proxy | PASS, 16 regi?es independentes, 3 posturas |
| ENet/DTLS, 3 processos reais | **18/18 PASS**: servidor 5, jogador m?vel 1, observador 12; exit 0 todos, zero erros |
| Granada | 5/5 PASS |
| Agachamento/rastejamento, ADS, quatro armas | 1126/1126 PASS |
| Ragdoll | 4/4 PASS |

O antigo `tests/combat_integration.gd` passou **todos os 48 testes iniciais de regi?o, identifica??o e multiplicador** ap?s o reparo. A su?te completa ainda reporta 8 falhas posteriores: 6 compara??es de orienta??o visual Glock/FAL, 1 restaura??o de menu e 1 alcance de proj?til com grande passo temporal.

**Controle A/A na main antiga:** um comparador criado a partir do arquivo de teste original da `main e8891ae`, pulando somente o bloco legado de regi?es que abortava em `DAMAGE["shinL"]`, reproduziu **exatamente as mesmas 8 falhas**. Portanto, elas n?o foram criadas pela corre??o de canelas e p?s. A su?te completa continua vermelha e deve ser corrigida no fluxo apropriado de armas/UI/proj?teis.

## Limites para release

- P1k autoritativo de 16 regi?es com as poses remotas ainda n?o est? homologado; testes P1a/P1b s?o anteriores/experimentais.
- A R2C permanece **OFF por padr?o**, limitada ao jogador local offline TPP G3 com flags expl?citas; **n?o habilitar bots e multiplayer com este commit**.
- FPS/P95/P99 com 28 bots seguem pendentes de medi??o GPU exclusiva. Um teste anterior foi invalidado por concorr?ncia de outra IA com a GTX 1650.
- Ucr?nia e Favela ainda precisam de manifestos preparados coerentes no ciclo de release. N?o desabilitar hashes.
- Nenhuma build p?blica est? sendo lan?ada por esta corre??o.

## Logs locais

`work/r2c-combat-qa/final.log` (129/129), `regression_summary.json` (R2C + P1a + P1b), `enet.log` (18/18), `auxiliary.json` (granada, postura, ragdoll), `combat-integration.log` (8 casos legados ap?s 16 regi?es aprovadas).

O comparador da base antiga est? em `work/r2c-full-qa-20261109/combat_legacy_later_cases.log` na worktree da auditoria anterior.
