# Coordenação multi-IA — regras locais e globais

Atualizado: 08/11/2026. Ler em conjunto com AGENTS.md, docs/FLUXO-GITHUB-OFICIAL.md e docs/GIT-LOCAL-E-IA.md.

## Dois níveis de coordenação (não confundir)

1. **Global, entre computadores:** GitHub xyborges/Toque-De-Campo, branch origin/main, Issues, branches, PRs, checks e relatórios versionados. É a fonte de verdade durável. Nenhum chat possui prioridade nem responsabilidade permanente sobre os demais.
2. **Local, entre worktrees do MESMO Git:** tools/ai_coord.py e .ai-coord/registry.json, copiados no próprio computador. Esse registro NÃO é compartilhado com outro PC e NÃO impede conflitos cross-host. As outras máquinas precisam consultar o GitHub.

O sistema local registra reservas, hashes SHA-256, snapshots de até 64 MiB por arquivo e estados de tarefas; se alguma IA o ignorar, não há bloqueio universal. Uma reserva antiga com ALERTA HASH exige auditoria, mas não autoriza apagar ou encerrar trabalhos alheios. Nenhuma reserva local equivale a aprovação de PR.

## Procedimento obrigatório

1. Ler AGENTS.md e documentos indicados; executar git remote -v, git fetch origin, git status -sb. Inspecionar PRs e branches em andamento no GitHub antes de escolher tarefa.
2. Criar worktree e branch exclusivas partindo de origin/main (python tools/ai_worktree.py create nome-da-tarefa). Nunca editar o checkout main como laboratório.
3. Na NOVA worktree: executar python tools/ai_coord.py status, identificar arquivos exatos e reservar:
   python tools/ai_coord.py start --agent "ia-favela" --task "Corrigir acesso as lajes" modes/war/scripts/favela_layout.gd
   Exemplo ilustrativo; conferir nomes reais. Arquivos novos, cenas e recursos também entram na reserva.
4. ANTES de cada rodada de escrita, executar python tools/ai_coord.py check ID. Se hash divergir, parar e apurar a origem; não aceitar cegamente as alterações como próprias.
5. Após suas alterações e testes, usar python tools/ai_coord.py checkpoint ID --confirm-own-changes --note "Resumo e testes". A flag confirma que a IA verificou todas as diferenças como suas.
6. Quando terminar, python tools/ai_coord.py check ID; python tools/ai_coord.py finish ID --notes "Arquivos, testes, resultados, riscos". Se abortar, usar abort --notes; abort não reverte arquivo algum.
7. Conferir git diff --check, guard de segurança, revisão do stage, commits pequenos e push na SUA branch. Abrir PR e registrar evidências; não integrar ou publicar automaticamente.

Se houver conflito de reserva na mesma worktree, não editar; separar o trabalho. Conflitos entre worktrees/PCs são tratados no GitHub por branches e PRs, não por hashes locais.

## Riscos e restrições

- Um editor externo que não use o protocolo pode alterar arquivos; os hashes ajudam a detectar, mas não impedir fisicamente.
- Snapshot/backup local não deve ser restaurado indiscriminadamente por cima de melhorias recentes. Revisar diff arquivo a arquivo.
- Arquivos maiores que 64 MiB podem não ter snapshot automático; confirmar backup dedicado se necessário.
- Não remover registry.lock sem validar que o processo responsável já terminou. Não apagar .ai-coord ou enviar esse diretório ao GitHub.
- Ferramentas, geradores e testes que alteram arquivos também precisam usar reserva.
- Não usar git clean -fdx, force push, merge/checkout --theirs indiscriminado ou reset --hard em cópia com trabalho pendente.
- Publicação do cliente/servidor requer QA e processo de release específicos; PR merge NÃO publica build.
- Dados brutos grandes de benchmarks não devem ser empurrados para o GitHub sem avaliar tamanho, segredos e utilidade. Relatórios devem indicar SHA, Godot, hardware, parâmetros, FPS/P95/P99 e falhas, quando relevantes.

## Estado e contexto

O estado do jogo muda com novos PRs. Não usar notas de release antigas como versão atual sem comparar com origin/main. Para estado atual, examinar commits/PRs de origin/main e relatórios ligados à versão pretendida.

Os registros .ai-coord/ de máquinas diferentes não são mesclados automaticamente. Para continuidade de trabalho, registrar decisões e resultados em commits/documentos/PRs que sejam acessíveis a todos.
