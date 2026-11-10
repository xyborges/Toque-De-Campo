# R01 — QA de explosões por ENet com 28 bots (09/11/2026)

## Objetivo

Homologar a atualização de dinâmica das explosões **além** do A/B offline: confirmar a transmissão real dos eventos do servidor dedicado para o cliente, o posicionamento, a propagação, a deduplicação e o áudio final quando há 28 bots ativos. A revisão anterior ficou em `ia/r01-explosion-dynamics-20261109`, baseada na atualização de presença global `ia/audio-presenca-global-1108`.

## Ambiente e método

- R01 `DESKTOP-R0I0NQG`, Windows, GTX 1650, Godot 4.7.2, cliente nativo Forward+, render de 1920 × 1080, perfil Médio (100%), servidor headless.
- Dois processos independentes, DTLS/ENet local por porta UDP efêmera, contas de QA e diretórios `APPDATA` separados; nenhum servidor de produção foi alterado.
- Servidor: `WarGame`/bot director reais, 28 bots ativos, `WarVehicles._broadcast("explosion_event",...)` usando o RPC de produção. Os eventos são injetados controladamente **após a criação da partida**, em vez de depender de acertos randômicos: o teste cobre entrega e áudio, mas **não** a validação do dano causado pelo projétil.
- Cliente: `WarVehicles.explosion_event` real recebe, cancela o projétil associado, filtra IDs já vistos, aciona `WarAudio.explosion`, e `GameExplosionAudio` aplica delay a 343 m/s e os buses de efeitos. As medidas vêm de `AudioEffectCapture` no bus de explosões e no Master.
- Matriz: tanque a 50 m (1, 2, 4 detonações), 400 m, 600 m; granada a 35 m; drone a 160 m; impacto 30 mm em metal a 150 m; tentativa deliberada de repetir o ID de detonação.
- Fontes `tests/r01_explosion_enet_28bots_20261109.gd` e `tests/run_r01_explosion_enet_28bots_20261109.py`. Resultados completos em `work/r01-explosion-enet-20261109/` (primeira execução) ou subdiretórios específicos do mapa (segunda rodada).

## Rodada 1 — Ucrânia (modo Guerra)

**Servidor 13/13 checks PASS; cliente 59/59 checks PASS.**
**13/13 eventos originais entregues, nove cenários, 28 bots no servidor e 28 entidades bot replicadas no cliente, sem clipping PCM no Master.** Ambos os processos encerraram com exit code 0.

| Cenário | Pico Master (dBFS) | RMS Master (dBFS) | Quadros próximos ao teto | Clips |
|---|---:|---:|---:|---:|
| Tanque 50 m, 1 | −1,00 | −15,61 | 0,204% | 0 |
| Tanque 50 m, 2 | −1,00 | −14,88 | 0,345% | 0 |
| Tanque 50 m, 4 | −1,00 | −16,01 | 0,387% | 0 |
| Tanque 400 m | −2,34 | −23,13 | 0% | 0 |
| Tanque 600 m | −4,02 | −25,46 | 0% | 0 |
| Granada 35 m | −1,00 | −18,43 | 0,026% | 0 |
| Drone 160 m | −1,00 | −19,45 | 0,012% | 0 |
| 30 mm em metal, 150 m | −5,62 | −25,05 | 0% | 0 |
| Tanque com ID duplicado | −1,00 | −16,03 | 0,170% | 0 |

Os 600 m registraram queda de intensidade relativa aos 400 m; o evento duplicado recebeu apenas **uma** reprodução lógica, com um único player principal. Camadas duplas a 150–400 m correspondem ao crossfade intencional entre WAVs perto/longe, e não a duplicações do RPC.

## Rodada 2 — Favela (modo Guerra)

**Servidor 13/13 checks PASS; cliente 59/59 checks PASS.** A rodada passou com o cliente nativo Forward+/GTX 1650 a 1080p, **28 bots no servidor e 28 avatares replicados no cliente**, 13 explosões originais entregues e nove cenários com áudio reproduzido. Os processos encerraram com código 0. Nenhum cenário teve clipping no Master.

| Cenário | Pico Master (dBFS) | RMS Master (dBFS) | Quadros próximos ao teto | Clips |
|---|---:|---:|---:|---:|
| Tanque 50 m, 2 explosões | −1,00 | −13,72 | 0,350% | 0 |
| Tanque 50 m, 4 explosões | −1,00 | −14,88 | 0,380% | 0 |
| Tanque 400 m | −5,96 | −23,92 | 0% | 0 |
| Tanque 600 m | −7,70 | −26,26 | 0% | 0 |
| Tanque 50 m, ID duplicado | −1,00 | −15,42 | 0,153% | 0 |

Granada a 35 m, drone a 160 m e impacto de APC 30 mm em metal a 150 m também passaram. A proteção contra duplicação de eventos funcionou, assim como o atraso de propagação e as verificações de voz no mixer. Detalhes em `work/r01-explosion-enet-20261109-favela/client.json` e `server.json`.

**Bloqueio anterior investigado:** o manifesto Favela versão 28 estava obsoleto em relação aos 68 arquivos de origem. `tools/prepare_favela_manifest.py` retornou `FAVELA_MANIFEST STALE` tanto na worktree de QA quanto na `main` da R01; a tentativa anterior de conexão falhou antes de enviar áudio. Foi gerado **somente para QA** um manifesto candidato v29 (`status=testing`), cujo hash passou em verificação e cujo `favela_operation_smoke.gd` terminou sem erro. Usando esse candidato, o teste ENet Favela 72/72 foi aprovado. Não é prova isolada de causalidade da desconexão, mas a intervenção permitiu completar a mesma bateria. O manifesto temporário foi restaurado ao original após as medições e **não integra o commit nem a atualização de produção**. A atualização oficial do manifesto exige fluxo de revisão específico de mapas.

**Veredito por mapa:** Ucrânia 72/72 e Favela 72/72 aprovados. Total: **144/144 verificações**, 26/26 eventos originais e 56/56 bots contados nas duas sessões independentes.

## Restrições e próximos passos

- O QA valida **sinal PCM e lógica ENet**, não julgamento subjetivo humano da textura/realismo; recomenda-se ouvir num cliente publicado com fones e caixas habituais a volume confortável.
- O cenário não percorre uma rodada inteira até encerrar objetivos, nem mede FPS A/B. Verificou **28 bots presentes no servidor e 28 replicados no cliente**, mas não quantificou movimento, combates ou estabilidade de quadros dos bots durante uma partida longa.
- A atualização permanece na branch de QA, sem integrar `main` nem publicar build por conta deste teste.
