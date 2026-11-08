# Git local e worktrees — complemento ao fluxo GitHub

Atualizado: 08/11/2026. **O GitHub é a fonte central**: https://github.com/xyborges/Toque-De-Campo. Leia antes docs/FLUXO-GITHUB-OFICIAL.md.

## O que é local e o que é central

- Git local: guarda commits, branches e worktrees independentes para executar o Godot e benchmarks.
- origin/main no GitHub: versão principal aprovada. A main local pode estar atrasada. Nunca assumir que a cópia local é a fonte oficial.
- Branch da IA: derivada de origin/main. Usar nome exclusivo incluindo a máquina e tarefa.
- Reservas .ai-coord/: compartilhadas SOMENTE entre worktrees do mesmo repositório Git local. Não são sincronizadas entre dois PCs.
- PRs, Issues, diffs e commits GitHub: rastreabilidade e coordenação ENTRE máquinas.
- Arquivos ignorados (work/, caches, builds, segredos): permanecem no disco, não são enviados ao GitHub. Nunca usar git clean -fdx.

## Iniciar uma tarefa

Na pasta do jogo (checkout correto, nunca no diretório de build):

    git remote -v
    git fetch origin
    git status -sb
    python tools/ai_worktree.py list
    python tools/ai_worktree.py create favela-lajes-20261108

O programa cria worktree isolada e branch ia/<computador>-<tarefa> partindo de origin/main, mesmo se a main local estiver atrasada. A criação não altera os arquivos da main. Se GitHub estiver indisponível, a criação falha em vez de usar base antiga silenciosamente.

Abrir a NOVA pasta gerada, executar python tools/ai_coord.py status e reservar os arquivos que serão editados. Use start / check / checkpoint / finish conforme docs/COORDENACAO-IA.md. Não compartilhar a mesma worktree entre duas IAs com escrita simultânea.

## Comitar e enviar ao GitHub

Dentro da worktree:
    git diff --check
    python tools/github_preflight.py
    git status -sb
    git diff -- <arquivo>
    git add -- <arquivos-revisados>
    git diff --cached
    git commit -m "tipo(escopo): resumo curto"
    git push -u origin HEAD

Depois, abrir PR da branch para main no GitHub. Não publicar a build automaticamente, não fazer push direto para main, nem usar --no-verify, --force ou reset --hard como atalho. O git_guard permanece ativo no pre-commit.

## Atualizar o checkout principal APÓS merge de PR

Somente na main local sem alterações pendentes:
    python tools/ai_worktree.py sync-main

Esse comando usa git fetch origin + merge --ff-only. Se estiver em outra branch, houver arquivos modificados ou história divergente, interrompe sem sobrescrever. Em outra máquina, repetir a sincronização no clone correspondente; commits locais não aparecem magicamente em outro PC.

## Revisão e trabalho em paralelo

Antes de iniciar, consultar PRs/Issues/branches do GitHub para verificar se outra IA já trabalha no mesmo assunto. Mudanças sobrepostas em arquivos de diferentes worktrees são conciliadas por merge/revisão de PR, não pelo sistema local de locks. Se a branch ficou antiga, sincronizar a base de maneira explícita e repetir testes.

Comandos úteis: git log --oneline -10, git worktree list, git status -sb, git diff, git diff --cached, git show HEAD:<caminho>. Consultas são seguras; restauração ou limpeza podem descartar trabalhos e exigem revisão.

## Regras permanentes de proteção

- Preservar scripts, assets e cenas ajustados por outras IAs. Não copiar snapshots ou laboratórios sobre o código atual.
- Versionar somente arquivos necessários e revisados, sem chaves privadas ou configurações secretas. Repositório pode ser público; não presumir privacidade.
- Não apagar caches/builds por engano. O projeto é grande e esses arquivos podem ser necessários para os testes.
- GitHub não armazena dados ignorados, configurações privadas, builds locais nem backups automáticos do servidor. Preservar cópias separadas.
- O hook local e o gate de GitHub são proteções complementares, não garantem cobertura integral de segredos ou bugs.

## Histórico

A instalação inicial do Git local foi feita em 04/11/2026; descrições antigas que diziam "SEM GitHub" pertencem àquela fase, não ao fluxo atual. A fonte oficial agora é origin/main.
