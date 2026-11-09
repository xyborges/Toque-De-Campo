# Homologação focada RPG-7 — multiplayer, 09/11/2026

Branch de trabalho: `ia/rpg-range-dots-20261109`. Referência inicial de `origin/main`: `a7b9010`.

## Objetivo e teste decisivo

O teste `tests/rpg_range_multiplayer_qa.gd`, com a fixture
`tests/rpg_range_multiplayer_fixture.gd`, é executado em **dois processos
Godot 4.7.2 distintos**, via conexão local real **ENet/DTLS**. A fixture é
isolada, mas utiliza as classes reais de jogo `WarGame`, `WarPlayer`,
`WarVehicles`, `WarProjectiles` e `GameSecureTransport`.

O servidor cria um personagem antitanque válido; envia uma solicitação de
teste ao cliente; o cliente executa o caminho nativo
`WarVehicles.request_command("gadget", {})`; o servidor recebe a RPC
`command`, executa `command_for/use_gadget`, valida o jogador, consome
uma carga e cria o foguete autoritativo. A autoridade transmite o RPC
`projectile_event`; o cliente reconstrói a réplica visual e reporta de volta
o mesmo foguete. As duas instâncias integram independentemente a física real,
comparando velocidades em 100, 200, 400 e 600 m.

**Resultado registrado:** servidor **17/17 PASS**, cliente **4/4 PASS**,
exits 0, zero falhas, com velocidade inicial 160 m/s, gravidade 9,81,
alcance 650 m, carga consumida uma única vez e paridade de trajetória.

## Reprodução

`python tests/run_rpg_range_multiplayer.py`

Alternativamente, `python tests/run_rpg_range_multiplayer.py --engine <godot>`.
Exige certificado e chave locais de QA em
`work/security182/test.crt` e `work/security182/test.key` — não são
artefatos de produção e **não devem ser versionados**. Usa porta UDP 39612,
perfis de cliente/servidor isolados e gera:
`work/rpg-range-qa/multiplayer-gate.json` e logs por processo.

## Testes complementares

- `tests/rpg_ballistics_range_qa.gd`: **36/36 PASS**. Seis impactos reais
  nos dots de 100 a 600 m, erros verticais inferiores a 2 cm, em ambiente
  controlado.
- `tests/rpg_range_visual_qa.gd`: **19/19 PASS** no Forward+ em
  1920×1080 com GTX 1650; todos os dots presentes no shader FPP.
- `tests/launcher_realism_qa.gd`: **32/32 PASS**, regressão de RPG/Stinger.
- `tests/rpg_range_dtls_probe.gd`: **8/8 PASS** com pacote criptografado.

## Limite explícito

Este gate confirma **cliente e servidor reais em processos separados**, RPC
nativa de disparo e réplica, mas usa **fixture controlada**: não substitui
um smoke test da partida pública completa, com contas, carregamento de mapa
e entrada normal de jogadores. A tentativa desse smoke test mais abrangente
não concluiu a entrada de três processos no ambiente local (timeout durante
carregamento). Nenhuma alteração de transporte ou segurança foi feita.
O resultado não comprova acerto em alvo móvel, atravessamento de obstáculos
nem desempenho com 28 ou mais bots.

Os testes acima cobrem o novo comportamento solicitado para o RPG e não
são autorização para publicar build de produção sem gate de release.
