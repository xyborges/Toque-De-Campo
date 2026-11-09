# RPG-7 — velocidade, queda progressiva e dots por 100 metros

Data: 2026-11-09. Base: `origin/main` a7b901063073d5db41a801216305b58b33748721.
Branch: `ia/rpg-range-dots-20261109`. Escopo: modo Guerra (inclui Favela).

## Mudança

- Velocidade inicial do RPG: **82 → 160 m/s**. Primeiro trecho permanece rápido; 100 m em aproximadamente **0,63 s**.
- Gravidade do RPG: **5,2 → 9,81 m/s²**, com queda de trajetória mais perceptível conforme a distância.
- Resistência aerodinâmica: arrasto-base 0,016/s até 90 m; rampa suave entre 90 e 140 m; depois `drag = base + 0,00125 * velocidade`. Diminuição de velocidade por distância, não uma desaceleração abrupta num único frame.
- Alcance máximo existente preservado: **650 m**. Mesmos metros reais do mundo virtual em Favela, Afeganistão e demais mapas; não há ajuste arbitrário de velocidade por mapa.
- Seis dots na luneta PGO-7: **100/200/300/400/500/600 m**, com posições derivadas da trajetória real, não espaçamento idêntico em pixels. Centro da cruz continua válido para tiros muito curtos; cada dot inferior aumenta a elevação do disparo.
- IA antitanque utiliza tempo de voo e correção vertical próprios do RPG. Stinger, tanques e armas leves não foram recalibrados.

## Tabela de referência (disparo sem obstáculos e a partir da mesma altitude)

| Distância | Tempo aprox. | Velocidade aprox. | Correção na luneta |
| --- | ---: | ---: | ---: |
| 100 m | 0,63 s | 158 m/s | 19,3 mrad |
| 200 m | 1,29 s | 141 m/s | 39,4 mrad |
| 300 m | 2,05 s | 124 m/s | 62,8 mrad |
| 400 m | 2,93 s | 109 m/s | 91,2 mrad |
| 500 m | 3,94 s | 97 m/s | 126,2 mrad |
| 600 m | 5,11 s | 87 m/s | 170,5 mrad |

As correções representam uma trajetória sem diferenças de altura entre lançador e alvo, e sem colisões. Contra objetivos elevados, móveis ou em movimento lateral, a marca serve como referência, não como garantia de impacto.

## Verificações

- Godot **4.7.2**, importação headless: **exit 0**.
- `tests/rpg_ballistics_range_qa.gd`: **30/30 PASS**, incluindo queda nos seis dots (erro simulado vertical entre **2 mm e 15 mm**) e integração com `WarProjectiles._step` (foguete veloz até 100 m e perda progressiva até 400 m).
- `tests/launcher_realism_qa.gd`: **32/32 PASS**, incluindo disparo autoritativo RPG/Stinger, gasto de cargas e posição da boca do cano.
- `tests/ballistics171.gd`: **não homologado** por falhas alheias à alteração: expectativa antiga de velocidade da sniper e erro em barramento de áudio na fixture (Godot mostrou EXIT_CODE=0 apesar dos erros). Nenhuma alteração feita na sniper ou no áudio.
- `git diff --check`: PASS. Regra `tools/git_guard.py` a executar antes do commit.

## Limites

A validação foi headless. Ainda recomenda-se revisão visual FPP da mira em Forward+ e teste multiplayer com disparos reais e rede antes de homologação/publicação. Nenhuma alteração na `main` ou build de produção faz parte desta branch.
