# Coordenacao entre IAs e protecao do projeto Godot
Data de introducao: 04/11/2026

## Objetivo e limite importante
Varias IAs/chats podem trabalhar no MESMO projeto sem substituir silenciosamente uma alteracao de outra. Preferir pastas Git worktree independentes por tarefa (veja docs/GIT-LOCAL-E-IA.md); o protocolo de hashes coordena edicoes que ocorram no mesmo workspace. O projeto ja possuia AGENTS.md (regras de criacao do jogo), mas nao tinha registro de reservas nem historico de hashes por tarefa.

O contexto compartilhado REAL fica no disco, nao dentro da memoria de um chat: AGENTS.md, este documento e o registro em .ai-coord/registry.json. Toda IA que atua neste diretorio deve reler esses arquivos ou executar o comando de status no inicio da tarefa. O registro nao enxerga automaticamente chats que nao usem o protocolo.

O guardiao nao impede um editor externo que deliberadamente ignore as regras de sobrescrever arquivos. Ele detecta divergencias de hash entre checkpoints e bloqueia reservas conflitantes de IAs que seguem o protocolo. Os backups sao parciais, nao substituem Git nem backup completo.

## Caminho e fontes de verdade
Projeto principal: C:/Users/Joao Borges/Documents/campo-cartunesco-godot/campo-cartunesco-godot/
Manual de regras: AGENTS.md
Registro compartilhado de tarefas: .ai-coord/registry.json na raiz do MAIN, acessado por TODAS as worktrees
Copias anteriores a edicao: .ai-coord/backups/<sessao>/... na raiz do MAIN
Programa: tools/ai_coord.py
Documentos de release: ATUALIZACAO-1.13.1.md e futuros documentos de release

Nao confundir os laboratorios de performance com a copia principal. NUNCA copiar um laboratorio, ZIP, mapa ou snapshot inteiro sobre o MAIN sem comparacao arquivo a arquivo, revisao de diffs e autorizacao explicita.

## Procedimento obrigatorio de toda instancia de IA

1. Abrir AGENTS.md, este documento e executar no terminal da raiz:
   python tools/ai_coord.py status

2. Identificar todos os ARQUIVOS exatos a serem editados, incluindo cenas, scripts, assets, configs, testes e arquivos novos. Para cada conjunto, reservar:
   python tools/ai_coord.py start --agent "chat-audio" --task "Mixer dinamico" audio/game_weapon_audio.gd audio/game_explosion_audio.gd
   O exemplo contem caminhos ilustrativos; conferir os caminhos reais antes de reservar.

3. Se aparecer CONFLITO na mesma worktree, NAO editar os arquivos; coordenar com a outra sessao, esperar sua conclusao ou trabalhar em uma worktree Git separada. Modificacoes em worktrees distintas requerem integracao/merge revisado. Nao cancelar uma sessao de outro chat por conveniencia.

4. Imediatamente ANTES de cada rodada de edicao, executar:
   python tools/ai_coord.py check ID-DA-SESSAO
   Se o hash estiver diferente, parar e investigar QUEM mudou e O QUE mudou. Nao adotar diferenca externa como propria.

5. Depois de editar SO os arquivos reservados, verificar sintaxe/regressao apropriada e fazer checkpoint:
   python tools/ai_coord.py checkpoint ID-DA-SESSAO --confirm-own-changes --note "Etapa implementada e testes efetuados"
   A flag confirma que a IA reconhece todas as diferencas como suas. Se houver duvida, nao executar checkpoint: fazer comparacao com o backup primeiro.

6. Antes de concluir, executar check de novo, registrar testes/limites e encerrar:
   python tools/ai_coord.py finish ID-DA-SESSAO --notes "Mudancas, testes, pendencias e arquivos afetados"
   Sem conclusao comprovada usar:
   python tools/ai_coord.py abort ID-DA-SESSAO --notes "Motivo, arquivos possivelmente alterados, proximo passo"
   ATENCAO: abort NAO reverte arquivos.

7. Nova etapa ou arquivo adicional? Abrir nova reserva. Nao editar arquivo nao reservado. Nao usar um arquivo amplo como "project.godot" sem antes verificar quem o reservou.

## Casos especiais
- Modificacoes anteriores a instalacao: NAO estao rastreadas retroativamente. Conferir com os planos e arquivos recentes antes de editar.
- Um arquivo mudou inesperadamente: o check falha. Reabrir o arquivo atual, comparar com .ai-coord/backups/<sessao>, integrar manualmente SEM apagar alteracoes alheias e so entao resolver o estado. Nao usar checkpoint apenas para fazer o alerta desaparecer.
- Arquivos maiores que 64 MiB: hash e reserva funcionam, mas a copia local automatica e ignorada para nao estourar o disco. Fazer backup dedicado quando necessario.
- A estrutura .ai-coord/ tem .gdignore para nao importar arquivos de controle no Godot. Nao apaga-la, nem mover o registro durante uma tarefa.
- Se registry.lock persistir por falha, verificar primeiro se existe processo executando o programa. Remover lock apenas se tiver certeza de que ficou orfao.
- Arquivos criados por outra IA fora do programa: podem ser detectados por hash de arquivos ja reservados; NOVOS arquivos nao reservados nao sao detectados automaticamente.
- O script nao bloqueia testes de apenas leitura. Se testes/geradores reescreverem arquivos, eles tambem precisam de reservas.
- Geradores e formatadores que alteram varios arquivos devem declarar todos os caminhos previamente. Nao fazer operacoes em lote sem inventario.

## Politica de publicacao e recuperacao
- Publicacao so a partir do projeto principal, com tarefas conflitantes concluidas, versao coerente, preflight e testes. Um "finish" nao publica nada.
- Nao trocar, reduzir ou ignorar verificacao de hash/manifestos de release como atalho para erros.
- Nao sobrescrever o MAIN com artefatos de build, perf-labs ou snapshots antigos.
- As copias em .ai-coord/backups servem para comparacao e recuperacao SELETIVA, nunca restauracao automatica por cima de mudancas novas.
- Git local e worktrees ja foram adotados. Regras de branches, revisao, commits, integracao e protecao contra segredos: docs/GIT-LOCAL-E-IA.md. Git LFS nao e necessario para este baseline; reconsiderar somente se necessario.
- Mesmo com Git, manter este quadro de contexto/ownership e usar merge consciente.

## Estado de referencia em 04/11/2026
A fonte mais recente lida, ATUALIZACAO-1.13.1.md, informa que 1.13.1/build 87 foi publicada. O relatorio antigo de 1.13.0 fala de bloqueio de build 85 e e historico, nao o estado atual de release.

O plano docs/PLANO-MESTRE-AUDIO-20261104.md informa mixer dinamico/ducking e validacao de partida pendentes nessa revisao. docs/FPP-TPP-CORPO-UNICO-PLANO-20261104.md e documentos derivados registram trabalho de camera/corpo; nao assumir que todas as etapas estao prontas. Verificar os arquivos reais antes de declarar implementado.

As reservas comecam a valer SOMENTE apos a instalacao deste protocolo. O comando status e a referencia para trabalhos que passaram a usa-lo.
