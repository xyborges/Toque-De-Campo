# Manutenção após a publicação da 1.10.6

30/10/2026. Ações feitas depois de publicar a 1.10.6/build 81, para o próximo build não herdar defeitos. **Nada disto está dentro do build 81**, que continua sendo a fonte congelada em `work/release1106-microstutter/project`.

## 1. Bloqueio de compilação no checkout principal

`scripts/main.gd` não compilava: em `remote_position_correction` a linha `if is_instance_valid(local_player):` havia ficado sem corpo, com as cinco linhas seguintes desindentadas.

```
Parse Error: Expected indented block after "if" block.  (res://scripts/main.gd:2698)
```

O erro se propagava como `Could not parse global class "WarGame" from res://modes/war/scripts/game.gd` e derrubava `options.gd`, `player.gd`, `bot_director.gd` e o adaptador dos mapas. Ou seja: qualquer exportação a partir do checkout principal falharia, e a validação dos mapas terminava com código 2. A indentação foi restaurada exatamente igual à versão que está no ar.

Verificado depois da correção: `--check-only` aprovado em `main.gd`, `game.gd` e `bot_director.gd`; importação completa do editor (`--editor --quit`) com código 0 e nenhuma linha de `Parse Error`, `Compile Error` ou `Failed to load script`.

## 2. Conteúdo preparado do mapa ukraine

O `ukraine` reprovava com `Prepared content is missing or stale` porque o `source_hash` gravado não correspondia às fontes atuais: o prepare dele rodou às 08:55 enquanto arquivos de `modes/war` ainda estavam sendo editados. Os outros quatro mapas já estavam consistentes.

O conteúdo foi regenerado pela via oficial (`python tools/maps.py prepare --map ukraine`), agora sobre fontes estáveis: identidade **versão 3**, hash `762f4c80…`, sem erros nas 15 verificações e sem avisos. Em seguida `python tools/maps.py validate` passou nos cinco mapas com zero erros e código 0 (ukraine 11, afghan 10, desert 11, office 8, naval 24 verificações). Os artefatos preparados conferem com os hashes do manifesto em todos os cinco.

## 3. Estado de publicação local alinhado ao servidor

O checkout principal tinha `distribution/published/manifest.json` em build 79, então o próximo prepare geraria 80 — exatamente o número do diretório residual que travou a publicação de hoje. Foram copiados do release congelado o manifesto assinado do build 81, o launcher e o pacote `game-81-07c778021c4d.zip`. Agora o próximo prepare a partir do checkout principal gera **build 82** e o launcher local é o mesmo que os clientes baixam.

## 4. Barreira de pré-publicação

`distribution/ubuntu/preflight.py` roda antes do envio e recusa, sem transferir byte algum, os dois casos que o helper root recusaria depois de centenas de MB enviados:

- build que não aumenta em relação ao manifesto no ar (código 3);
- `/opt/toque-de-campo/releases/build-N` já existente com conteúdo diferente do release autenticado (código 4), comparando os mesmos três arquivos que o helper confere.

Release idêntico já presente continua liberado, porque repetir o envio é um caminho legítimo. A consulta ao servidor usa a CA privada embutida; se o servidor não responder, a barreira avisa e deixa o envio seguir, para não transformar indisponibilidade em bloqueio.

Testes: estágio real do 1.10.6 recusado por não aumentar (código 3); estágio de teste com build 82 aceito (`PREFLIGHT_OK`); estágio com build 79 recusado; publicado com a barreira recusa em 1,3 s e imprime "Nada foi enviado"; 5/5 verificações isoladas da comparação de hashes, incluindo arquivo ausente e hash vazio.

## 5. Resíduo do build 80 removido na VM

Com acesso root, `/opt/toque-de-campo/releases/build-80` foi removido: **252 MB liberados**. Depois da remoção, `current` continua em `build-81`, os quatro serviços seguem ativos, o manifesto no ar continua `1.10.6 / build 81` e a listagem de releases ficou `77, 78, 79, 81`. Nenhum outro artefato foi alterado na VM.

Com o mesmo acesso foi conferida a operação real do build 81:

- **Escritor de status em segundo plano funcionando**: `war-status.json`, `pvp-status.json`, `naval-status.json` e `br-broker-status.json` foram reescritos entre 1 e 3 segundos antes da consulta. O de Guerra dizia `bots 28, humans 2, connections 2, phase active, version 1.10.6` — ou seja, a escrita periódica que motivou a entrega está operante, incluindo a troca atômica do arquivo.
- **Logs limpos**: zero linhas `ERROR` ou `SCRIPT ERROR` em `toque-war`, `toque-br`, `toque-naval` e `toque-pvp` desde a ativação às 13:11 UTC.
- **Snapshot de rollback presente**: `before-build-81.sqlite` (270.336 bytes, 13:11 UTC).

Observação registrada: no momento da verificação havia 2 jogadores humanos conectados ao Guerra (28 bots). Não é defeito nem exige ação; apenas confirma que a verificação rodou com o servidor em uso, e nada foi reiniciado para isso.

## Pendências

- O trabalho de mapas (identidade/admissão, spawn por exposição, grama e navegação preparadas, conteúdo do ukraine v3) segue fora de qualquer build publicado; ele entra no próximo.
- A pausa periódica de ~1 s no Guerra e o benchmark de 28 bots continuam sem comprovação de melhoria.

## Evidências

`work/check-all-scripts.log` (importação limpa), `work/maps/20261030-102329` (prepare do ukraine), `work/maps/20261030-102710` (validate dos cinco), `work/maps-identity-check.py`, `work/preflight-selftest.py`, `work/preflight-tests/`, `work/ukraine-prepare-fix.log`, `work/release81-production-verify.json` (remoção do resíduo e verificação com root), `work/remove-build80.py`, `work/root-verify-81b.py`.
