# IA 2 — Entrada e combate: verificação e intervenções (06/11/2026)

**Estado:** laboratório, mudanças sob flags DESLIGADAS por padrão, NÃO integrado à main. Base 5fceacc (Favela v25); branch ia2/entrada-combate-custo-20261106. DESKTOP-R0I0NQG, Godot 4.7.2.stable.official.ed1daf0bf, Jolt e headless nas coletas de mapa. Nenhum cliente ENet GTX1650 real foi medido nesta rodada. Não confundir com o executável publicado no Ubuntu, build 95.

## 1. Auditoria dos quatro caminhos

**Entrada / mundo:** WarFavelaMap.build faz construção síncrona, inclusive planejamento de lotes, terreno, bairros e geometria, antes de liberar o jogo. Instrumentação opt-in identificou 5.359 ms de construção do mapa (5.494 ms da preparação geral), divididos principalmente em layout e reservas 1.377,4 ms, bairros 1.347,1 ms, encostas 1.015,4 ms, terreno de 225 tiles 626,7 ms, marcos/fiação/clutter 493,6 ms e bordas 242,8 ms. Contagem: 11.624 formas de colisão.

**Projéteis:** WarProjectiles já possui pool de até 512 slots e reaproveita uma PhysicsRayQueryParameters3D durante o voo. O cliente também calcula raycasts de projéteis meramente visuais. Não há indicação de que o custo principal seja alocação da query por quadro; eliminar collision query sem sweep seria arriscado. Nenhuma consulta de dano do servidor foi retirada.

**Armas no respawn:** _refresh_weapon refazia geometria, inclusive quando um observador continuava com a mesma arma válida. A posição autoritativa do muzzle, ópticas e visões em primeira pessoa precisam continuar coerentes.

**Ragdolls:** DeathRagdoll.create realiza vários testes físicos de desobstrução, instancia muitos RigidBody3D, materiais, formas e juntas em um callback de morte. O processo é síncrono; distribuir mortes remotas por quadro reduz o agrupamento de picos, mas NÃO o custo total de um cadáver nem o pico de um corpo isolado.

## 2. Patches independentes (flags OFF por padrão)

| Intervenção | Flag opt-in | Arquivo / proteção |
|---|---|---|
| Reuso do modelo intacto de arma remota | TDC_IA2_REUSE_RESPAWN_WEAPON=1 | modes/war/scripts/player.gd; apenas ator não local, mesmo ID e muzzle/rig válido, com óptica atualizada; launcher, arma alterada ou vista local seguem reconstrução original |
| Uma apresentação de ragdoll remoto por quadro | TDC_IA2_DEFER_REMOTE_RAGDOLL=1 | scripts/main.gd; preserva áudio/deduplicação imediatamente; fila com WeakRef e life ID; cadáver local da câmera de morte continua imediato; servidores headless não usam a fila |
| Raycast visual agrupado a 30 Hz | TDC_IA2_CLIENT_PROJECTILE_30HZ=1 | modes/war/scripts/projectiles.gd; apenas visual não autoritativo, não guiado, não explosivo, não aquático; o próximo ray percorre o trecho COMPLETO desde a última consulta; servidor continua consultando cada passo, guiados e explosivos sem mudança |
| Reuso de consulta de rua já calculada para lote idêntico | TDC_IA2_LAYOUT_REUSE_FRONTAGE=1 | modes/war/scripts/favela_layout.gd; só reutiliza gap quando posição e metade da dimensão não foram alteradas; lotes deslocados são recalculados |
| Cronometria por etapa da Favela | TDC_IA2_MAP_STAGES=1 | modes/war/scripts/favela_map.gd; apenas adiciona tempos a build_metrics, sem mudança de geometria |

A implementação do ragdoll preserva autoridade, hitbox e posições porque só altera apresentação remota. O raycast visual pode atrasar efeitos cosméticos aproximadamente um passo físico; requer equivalência visual em multiplayer antes de qualquer ativação.

## 3. Teste de equivalência do planejador

Execução isolada da rotina de 4.313 lotes, A-B-B-A-A-B (3 medições por variante):

| Modo | Tempo fase do planejamento, ms | Mediana |
|---|---|---:|
| Original A | 1.352,387; 1.332,939; 1.334,168 | 1.334,168 |
| Reuso B | 933,853; 884,881; 900,189 | 900,189 |

**Redução da mediana do planejador = ~434 ms ou 32,5%**, não da entrada total. Reutilizadas 5.592 consultas por execução otimizada. Os seis arrays de 4.313 lotes permaneceram IDÊNTICOS, com SHA256 da serialização JSON base cf02c42b719d067724e2913677870aaadadcd89ba463c577a33cf905e520ea55.

Antes, testei limites geométricos AABB para ignorar ruas distantes: o resultado do mapa também foi idêntico, porém a mediana SUBIU de ~1.321 para ~1.911 ms. Essa abordagem foi DESCARTADA e revertida. Logs layout-qa.log (descartada) e layout-qa-reuse.log (atual).

## 4. Cinco pares alternados de CONSTRUÇÃO COMPLETA do mundo

Godot headless, mesmo mapa, 10 subprocessos separados, ordem A-B-B-A-A-B-B-A-A-B, apenas TDC_IA2_LAYOUT_REUSE_FRONTAGE alternada. Em TODAS as rodadas: 225 tiles, 11.624 formas físicas. Os dados estão em map-world-abba-5pairs.csv e logs map-world-01-0.log até map-world-10-1.log.

| Par | Mundo original A (ms) | Mundo com reuso B (ms) | Diferença (ms) | Redução |
|---|---:|---:|---:|---:|
| 1 | 5.298,309 | 4.889,615 | +408,694 | +7,714% |
| 2 | 5.429,658 | 4.897,617 | +532,041 | +9,799% |
| 3 | 5.815,410 | 4.978,405 | +837,005 | +14,393% |
| 4 | 5.516,610 | 4.975,487 | +541,123 | +9,809% |
| 5 | 5.511,467 | 5.671,475 | **-160,008** | **-2,903%** |

Média A: 5.514,291 ms. Média B: 5.082,520 ms. Economia média: **431,771 ms (7,83%)**. Mediana das cinco economias pareadas: **532,041 ms (9,80%)**. Ruído nos cinco controles originais A (amplitude dividida pela média): **9,38%**. Quatro dos cinco pares favoreceram B, um piorou. A economia média ficou ABAIXO do ruído dos controles e não se mediu P99 pós-controle, cache frio real ou FPS do cliente. **Candidato de baixo risco, NÃO aprovado para ativar em produção.**

## 5. QA e regressões funcionais

- tests/ia2_entry_combat_qa.gd com flags de combate: **23 verificações, 0 falhas, exit 0**. Reuso da mesma arma preserva o mesmo muzzle; troca de arma reconstrói modelo e muzzle; launcher continua rebuild. Três mortes remotas enfileiradas, no máximo um ragdoll criado por quadro, life IDs preservados. Com raycast original/agrupado, uma bala visual atingiu a MESMA parede em (0,1.975497,-24.5) e (0,1.975184,-24.5), delta abaixo de 1 mm. Três consultas visuais foram puladas. Um tiro marcado authoritative=true continuou realizando 5 raycasts mesmo com flag visual ON. Não é validação de todas as armas/obstáculos, efeitos dinâmicos e multiplayer.
- tests/favela_runtime_qa.gd, reuso layout ON: **37 verificações sem falhas, exit 0**, oito veículos sem sobreposição, objetivos e caixas, implantação correta. 225 tiles e 11.624 formas persistiram nas 10 construções A/B.
- tests/ragdoll_contact_stress.gd, flags default OFF: **12 ragdolls, 0 falhas, exit 0**. Velocidade máxima 5,27 m/s, altura máxima 1,90 m, separação máxima 1,12 m. Testa física base, não throughput da fila.
- Godot --check-only para os scripts e novas fixtures: PASS. git diff --check: PASS.

## 6. Decisão / o que NÃO foi resolvido ainda

- As flags continuam **OFF**. Os testes funcionais exercitam casos representativos, mas **nenhum experimento comprova aumento de FPS e redução de P99 do cliente GTX 1650 em multiplayer real**, critério obrigatório para aceitar mudanças em produção.
- O mundo ainda é construído sincronicamente; o trabalho foi REDUZIDO no planejamento, não dividido por quadros. Separar a construção pode alterar colisões, instante de liberação de controles e ordem de carga; fica para arquitetura testada à parte.
- O ragdoll individual ainda monta seus corpos e consulta desobstrução; a fila diminui agrupamento de várias mortes e conserva a experiência do jogador local, mas não otimiza fisicamente o cadáver isolado.
- Não foram feitos cinco pares para as três flags de combate. Não ligar por padrão antes de medir efeitos em hitreg, tráfego real, render e P99.
- Nenhuma alteração em bot_director.gd, step_motion.gd, CollisionRig, hitboxes, servidores Ubuntu ou main.

## 7. Alterações para integração e conflitos

Arquivos de produção tocados: modes/war/scripts/player.gd, scripts/main.gd, modes/war/scripts/projectiles.gd, modes/war/scripts/favela_layout.gd e modes/war/scripts/favela_map.gd.

Adicionados: tests/ia2_entry_combat_qa.gd, tests/ia2_layout_qa.gd, tests/ia2_map_stage_qa.gd e work/ia2-entrada-combate-20261106 (logs, CSV, relatório). IA 1 deve revisar eventuais conflitos em player.gd/main.gd; não houve edição no sistema de movimento ou na autoridade de bots.

**Veredito:** o problema de cálculos de rua duplicados tem uma correção concreta, reproduzível e geometricamente equivalente. Os custos de arma remota, ragdoll e raios visuais têm patches de baixo escopo com flags OFF e testes funcionais, ainda não homologados por FPS/P99. O mapa não foi simplificado e o jogo da main não foi alterado.
