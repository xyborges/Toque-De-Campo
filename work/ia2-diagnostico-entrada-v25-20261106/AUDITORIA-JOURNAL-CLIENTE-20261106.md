# Auditoria somente leitura — journal Ubuntu, combate no servidor e custo do cliente

**Data da consulta:** 2026-11-06, 22:41 UTC / 19:41 BRT (aproximadamente).
**Escopo:** leitura de `journalctl` no Ubuntu 192.168.101.24, auditoria estática do código Favela v25, correlação cuidadosa com benchmark offline anterior. **Nenhuma alteração, reinício, novo teste de desempenho ou publicação de build.**

## 1. Serviço remoto confirmado

Consulta SSH autenticada como usuário `microgate`, usando host key previamente conhecida (sem copiar credenciais). Serviço `toque-war-favela.service` estava `active (running)`, PID **525809**, ativado em **2026-11-06 16:10:50 UTC** (13:10:50 BRT). `ExecStart` executa Godot headless com `--max-fps 60 --war-server --war-map=favela`, em `/opt/toque-de-campo/current/ToqueDeCampo.x86_64`. A resolução do symlink `current` apontou para **`/opt/toque-de-campo/releases/build-95`**. Isso **não comprova** que o código publicado é o commit de desenvolvimento `5fceacc` ou que a Favela v25 foi publicada.

**Journal bruto do dia 6:** `JOURNAL-TOQUE-WAR-FAVELA-20261106.log`, 23 linhas, horários originais UTC, extraído com `journalctl -u toque-war-favela.service --no-pager --since '2026-11-06 00:00:00' -o short-iso`.

| Hora UTC em 06/11 | Evento observado |
|---|---|
| 00:48:57 | Serviço parado e iniciado novamente de modo controlado; uso acumulado anterior 36m46,842s de CPU, pico 304,9 MB |
| 01:05:48 | Outro stop/start controlado; uso anterior 2m30,903s de CPU, pico 296,5 MB |
| 16:10:50 | Outro stop/start controlado; uso anterior 1h41m31,742s de CPU, pico 307,2 MB |
| 20:25:47; 20:26:10; 20:26:11; 20:26:22 | Quatro erros de configuração RPC: `gadget_selected` no nó `/root/ToqueDeCampo/WarGame` |

A amostra do journal **não registra** `war_world_ready`, `war_bots_prepared` nem `war_simulation`. A busca no journal desde 2026-11-01 para esses nomes retornou **zero linhas**. No dia 5, apareceram pelo menos seis erros `Condition "!is_inside_tree()" is true. Returning: Transform3D()`; são registros anteriores, de outro PID, e não foram atribuídos ao serviço ativo hoje.

### Por que as métricas não estão no journal

Em `scripts/diagnostics_api.gd`, `GameDiagnostics.record()` encaminha para `scripts/diagnostics.gd`, que grava JSONL por sessão em **`NavalStorage.folder()/diagnostics/`**, não no stdout de `systemd`. O serviço usa `--naval-data=/var/lib/toque-de-campo/game`, portanto espera-se `/var/lib/toque-de-campo/game/diagnostics`. A pasta de dados pertence ao usuário `toque-server` e tem modo `750`; a conta SSH `microgate` não consegue listar/ler os JSONL. `sudo -n` solicita senha para leitura desses arquivos; somente o helper de implantação tem exceção NOPASSWD, que não foi usado. **Não contornei permissões, não alterei ACL, não li chaves ou tokens, não parei serviços.**

Portanto, **não há números reais de `war_simulation` ou `war_world_ready` disponíveis nesta consulta**. O journal não permite concluir duração dos ticks ou carga de 28 bots no servidor real. Os eventos privados, quando acessíveis por um caminho autorizado, permitiriam obter `mean_ms`, `peak_ms`, `engine_physics_ms`, população, `tick_hz`, `max_tick_gap_ms`, intervalo máximo de snapshots, e RTT. O evento não inclui uma série integral de todos os ticks nem P99 real por tick; essa métrica não pode ser reconstruída exatamente de médias/picos de 10 s.

## 2. Erro RPC concreto — verificar em tarefa isolada

No código-base `5fceacc`, `modes/war/scripts/bot_director.gd` envia `game._broadcast("gadget_selected", [...])` ao desativar/ativar o lançador do bot, nos trechos próximos às linhas **396** e **551**. Isso tenta chamar a RPC do nó **`WarGame`**. Entretanto, a função `@rpc func gadget_selected(...)` está declarada em **`modes/war/scripts/vehicles.gd`**, perto da linha **731**, no nó `WarVehicles`. O próprio `WarVehicles` usa `_broadcast("gadget_selected", [...])` no seu escopo.

Isso **explica de forma plausível e diretamente verificável** os erros no journal (método RPC ausente no nó escolhido). Antes de corrigir, comparar o código do build 95 com o da branch, porque não há prova de identidade binária. Falha de RPC pode impedir atualização visual do estado de lançadores em clientes; **não há evidência de que cause os 24 quadros com quatro ticks acumulados**. Não foi feita correção de gameplay.

## 3. Quem paga pelo custo dos 28 bots?

Auditoria estática da branch Favela v25 baseada em `5fceacc`:

- `WarBotDirector.setup()`, por volta da linha 117: `enabled` exige `game.multiplayer.is_server()` e modo offline ou `online_fill`; cliente remoto não executa o diretor.
- `WarBotDirector._physics_process()`, por volta da linha 313: a autoridade intercala aproximadamente **40 decisões/s** compartilhadas, executa movimentação dos bots ativos por tick físico e transmite estados online a **10 Hz**, em lotes de até 4 por RPC.
- `scripts/player.gd::_physics_process()`, por volta da linha 660: ator remoto não local recebe alvo de rede, interpola `global_position`, rotação e pitch, atualiza animação/postura e retorna **antes de `GameStepMotion.move()`**. O próprio `war_bot_states()` no cliente encaminha os pacotes para `remote_player_state()`.
- `modes/war/scripts/player.gd::_animate_walk()`, perto da linha 205: há LOD visual para atores não locais com observador — intervalos aproximados de **33, 67 e 125 ms** segundo distância; **hitboxes `Area3D` seguem pivôs visuais** (ver `scripts/player.gd::_add_hit_region()`). Reduzir pose sem CollisionRig autoritativo independente é arriscado.
- O cliente continua criando `WarPlayer` / `CharacterBody3D`, processando posturas, animação, IK, materiais, apresentações, interpolação e possíveis consultas/corpos de colisão. Não afirmar que não exista custo físico algum do cliente. No ramo aquático, personagens marcados `war_bot` podem entrar numa condição específica, mas a metadata é posta pelo diretor do servidor e não foi encontrada aplicação equivalente ao receber identidade no cliente; confirmar comportamento no binário antes de afirmar exceções.

**Veredito:** o cliente online **não paga** a navegação/decisão e movimento autoritativo de 28 bots em `_move()`, nem deve ser tratado como igual ao benchmark offline que acumula autoridade + apresentação em um processo. Priorizar renderização, apresentação/IK, estados recebidos e memória/instanciação do lado cliente. Não realizar LOD de pose autoritativa antes de resolver a dependência das regiões de dano.

## 4. Interpretação correta dos 24 quadros com 4+ ticks

Os **24 quadros com ≥4 ticks físicos** são de **uma medição offline/headless na DESKTOP-R0I0NQG**, **Afeganistão**, 120 segundos com 28 bots (`headless-afghan-28bots-first-stable-20261106-192004.json`). Não são eventos medidos no servidor Ubuntu Favela. Nesse cenário foram observados 968 disparos, 50 recargas, uma granada, 40 quadros de processo >50 ms e 4 >100 ms; média de 60,01 ticks/s, P99 do intervalo entre quadros de 38,30 ms. O JSON não possui associação por timestamp de cada disparo com o intervalo de quadro específico; a causa dos 24 acúmulos **não está demonstrada**, só há concomitância de maior atividade de combate.

O custo fixo de construção de mapa em headless offline foi aproximadamente **5,1 s na Favela** e **5,4 s no Afeganistão**, praticamente sem diferença entre 0/28 bots. Não extrapolar para travada do cliente após liberar controle sem medir estágio de carregamento, shaders e baseline de rede.

## 5. Decisão e próximos passos para revisão

- **Custo do cliente:** premissa confirmada em código — bot remoto não executa o diretor/locomoção autoritativa. Não extrapolar ganho de física offline para FPS online.
- **Combate no servidor:** registrar como principal hipótese para os picos, mas **sem evidência temporal do servidor real** no journal disponível. Não iniciar novos benchmarks agora.
- **Entrada:** custo fixo de construção já identificado na R0I, mas não corrigir o mapa antes de decompor onde esse custo ocorre e seu impacto no usuário.
- **Problema concreto adicional:** erro `gadget_selected` que parece chamar a RPC no nó incorreto; encaminhar para correção/regressão em branch distinta, sem misturar com desempenho.
- **Pendência objetiva de acesso:** leitura autorizada dos JSONL do serviço `toque-server`. Não usar helper de deploy, grupo LXD, alteração de permissões ou credenciais privadas para contornar a política de leitura atual.

**Arquivos alterados:** somente este relatório e cópia do journal em `work/`. Nenhum arquivo de gameplay, testes, serviço, configuração ou `main` alterado.
