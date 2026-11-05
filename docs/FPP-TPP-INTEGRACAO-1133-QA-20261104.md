# FPP/TPP P1 — pré-integração sobre 1.13.3 (QA)

Data: 04/11/2026. **Somente branch de trabalho, sem publicação e sem merge na `main`.**

## Origem e escopo

- Base de produção preservada: `main` em `7357dd3`, Toque de Campo 1.13.3/build 90 já publicada.
- Fonte da P1 validada: `ia/fpp-validacao-rede` em `09162e5`, contendo P1b–P1j e os commits anteriores de P1f/P1g/P1i.
- Destino isolado: `ia/fpp-integracao-1133` na worktree `campo-worktrees/fpp-integracao-1133`.
- Merge de teste `--no-ff --no-commit` sem conflitos. Apenas `scripts/main.gd` e `scripts/player.gd` tiveram alterações dos dois lados; ambas foram mescladas automaticamente e revisadas.
- `scripts/main.gd` mantém a validação da câmera, o raycast a partir do olho lógico, o muzzle físico e a compensação de zeragem da 1.13.3. `scripts/player.gd` mantém o fallback de `CollisionShape3D` com nome gerado.
- O piloto `--true-fpp-p1g-collision` **continua desligado por padrão**. Nenhuma mudança de ótica/asset de outra IA foi sobrescrita.

## Regressão funcional na base 1.13.3

Godot 4.7.2, scripts headless executados nesta worktree após importação da árvore:

| Gate | Resultado |
|---|---|
| P1b arsenal: G3, AK, FAL, Glock, sniper | 50 casos + 30 rejeições, PASS |
| P1b prone e movimento | 25 prone + 60 movimento, PASS |
| P1b pelve após levantar | 2 sequências, PASS |
| P1c mira de ferro | 90 verificações + 10 rejeições, PASS |
| P1d recarga multiarmas | 150 verificações + 10 rejeições, PASS |
| P1e ADS óptico 4×/8× | 120 verificações + 16 rejeições, PASS |
| P1f mira/cobertura FPP/TPP | 27 verificações, PASS |
| P1g autoridade física do proxy | **31 verificações**, PASS |
| P1i dano por membro e ragdoll | 24 verificações, PASS |
| Zeragem de armas da 1.13.3 | 58 verificações, PASS |
| Ópticas universais | 242 verificações, PASS (headless, não renderizado) |

**Rede local ENet/DTLS na própria integração:** `tests/run_true_fpp_p1j_network.py` com servidor + dois clientes reais, todos exit 0. Servidor **15/15**, atirador **2/2**, vítima **2/2**. O tiro do cliente alcançou a autoridade física do proxy no servidor e o dano foi replicado. Usa campo de tiro plano de QA e certificado efêmero localhost; **não** substitui ensaio de mapa completo, clientes exportados ou rede externa.

## Correção adicional de regressão

Na integração foi detectado que o `return` de `WarPlayer._physics_process` havia sido movido para dentro do ramo `vehicle_id` na P1g. Isso fazia um ator **ainda não implantado** cair na física-base apesar do gate de spawn. Restaurado o retorno comum para *não implantado* e *ocupante de veículo*, chamando antes o hook P1g (no-op sem flag). O fixture P1g agora comprova que `fire_cooldown` não avança indevidamente antes do spawn, passando **31/31**.

## Gates ainda fechados

1. **Custo da física com 28 atores/bots.** O ensaio de desempenho da worktree `ia/fpp-p1g-performance` registrou regressão sintética elevada e controle A/A instável; não há aprovação estatística nem teste renderizado de 28 bots. Não ativar P1g por padrão.
2. **Fallback sem stale hitboxes.** Em ações especiais não cobertas pelo solver, o proxy ainda espelha pivôs visuais que podem sofrer LOD; isso não satisfaz independência física plena.
3. **Rede/release.** Faltam listen/dedicated em mapa completo, dois clientes exportados, estabilidade de partida, p95/p99 de frametime, 28 bots e comparação com a versão publicada.
4. **True First Person.** A P2 (câmera sobre corpo real, PiP na arma real, retirada progressiva de `view_root`, depois outras armas/gadgets/BR) ainda não foi implementada.

**Decisão:** manter esta integração como candidata de QA. Não mesclar na `main`, não publicar e não chamar de versão pronta até fechar desempenho e os gates de gameplay.
