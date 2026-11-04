# Git local do jogo — manual para todas as IAs
Instalacao inicial: 04/11/2026. SEM GitHub, sem remoto configurado.

## Fonte de verdade e estrutura
- MAIN: pasta original campo-cartunesco-godot/campo-cartunesco-godot (projeto de producao).
- main: branch principal de integracao. A versao-base representa um snapshot do projeto no momento da criacao do Git; NAO e uma nova build publicada.
- ia/<tarefa>: branch de trabalho individual.
- campo-worktrees/<tarefa>: pasta fisica separada do MAIN, ao lado do diretorio externo do projeto, para cada IA.
- .ai-coord/: registro local compartilhado POR TODAS AS WORKTREES, localizado na raiz do MAIN. Reservas protegem arquivos dentro da MESMA worktree; worktrees diferentes sao integradas via merge Git.
- AGENTS.md e docs/COORDENACAO-IA.md: regras obrigatorias.
- tools/git_guard.py e .githooks/pre-commit: bloqueios de segredos evidentes, arquivos privados e binarios acima de 50 MiB.
- distribution/build, distribution/published, distribution/private, work, user_data, cache .godot e registro .ai-coord: ignorados SEM serem apagados. O conteudo de distribution/ubuntu e launcher (codigo-fonte) permanece versionado.

## Rotina OBRIGATORIA — novo chat que pretende modificar jogo
1. Ler AGENTS.md, docs/COORDENACAO-IA.md, este documento e os planos da sua area.
2. Abrir a pasta de worktree dedicada a SUA tarefa; nao presumir que esta na raiz MAIN.
3. Executar git status --short --branch e python tools/ai_coord.py status. Verificar se existe trabalho nao commitado e o estado das demais IAs.
4. Reservar os ARQUIVOS na worktree: python tools/ai_coord.py start --agent "chat-armas" --task "Oticas G3" modes/.../file.gd (exemplo ilustrativo).
5. Fazer check antes de cada edicao, checkpoint --confirm-own-changes apenas apos revisar as suas mudancas e finish --notes ao concluir. Verificar hashes inesperados antes de checkpoint.
6. git diff --check; rodar testes relevantes; git status --short; git diff e revisar ANTES do stage.
7. git add -- <arquivos revisados> (NAO use git add -f, git add . em massa ou --no-verify). Fazer commit claro e pequeno.
8. Comunicar ao integrador: branch, worktree, objetivo, arquivos, testes, riscos, hash do commit e pendencias. NAO publicar build automaticamente.

## Criar e listar uma worktree (a partir do MAIN LIMPO)
No PowerShell dentro do MAIN:
    python tools/ai_worktree.py create audio
    python tools/ai_worktree.py create mapas
    python tools/ai_worktree.py list

Isso cria branches ia/audio ou ia/mapas e pastas irmas isoladas. Informar ao novo chat o caminho exato da pasta da SUA area. Nunca compartilhar uma unica worktree entre duas IAs que editam os mesmos arquivos.

Se o MAIN tem mudancas nao commitadas, a criacao e bloqueada: nao limpar a forca. Verificar e integrar/salvar as mudancas antes.

## Integracao segura ao MAIN (feito pelo integrador)
Antes: garantir que a branch tenha commits revisados, nenhum trabalho em andamento nessa worktree e o MAIN esteja limpo. Verificar git status --short --branch, git log --oneline --decorate -8 e git diff main..ia/<nome> --stat.

No MAIN, integrar uma branch por vez:
    git merge --no-ff ia/audio

Se houver conflito, NAO usar git checkout --theirs . ou sobrescrever snapshot inteiro. Comparar as duas versoes, resolver cirurgicamente, rodar validacoes e concluir o merge. Se necessario interromper antes da conclusao: git merge --abort (somente se houver merge em andamento).
Executar preflight, regressao e validacao multiplayer/desempenho conforme o escopo. Nao declarar publicacao sem seguir o pipeline de release existente.

## Comandos uteis (na pasta da worktree)
- git status --short --branch: veja alteracoes pendentes e branch.
- git diff: revise o que ainda NAO foi adicionado ao stage.
- git diff --cached: revise o que entrara no commit.
- git log --oneline -10: historico.
- git restore --source=HEAD -- <arquivo>: ATENCAO, pode descartar alteracoes; so usar com revisao/autorizacao.
- git show HEAD:<caminho>: consulte versao anterior sem tocar no arquivo atual.
- git worktree list: veja pastas/branches.

## Politica de seguranca e tamanho
- Git e LOCAL: git remote -v deve permanecer vazio ate autorizacao expressa; nenhuma conta online necessaria.
- A lista .gitignore deve ser revisada quando entrarem tipos novos de output ou segredos; git status e pre-commit complementam, mas nao substituem auditoria.
- .githooks/pre-commit so verifica staged. Evitar commits indiscriminados e jamais usar --no-verify para burlar falha.
- Nunca versionar chaves privadas, credenciais, segredos de deploy, dados de usuario ou material de assinatura. Certificados publicos requeridos pelo jogo podem ser incluidos.
- Arquivos grandes necessarios ao runtime podem ficar no Git local; limite defensivo de 50 MiB no hook evita incluir builds/logs acidentalmente. Discutir excecoes conscientemente.
- NUNCA executar git clean -fdx: esse comando pode apagar work/, builds/publicados e estados ignorados. NUNCA executar git reset --hard em workspace com trabalho nao revisado.
- Git LOCAL NAO e backup externo: pane/perda do SSD pode levar o codigo e historico. Replicar depois em disco/NAS separado ou servidor Git privado, SEM enviar para GitHub por padrao.

## Estado inicial conhecido
- Documento de release mais recente: ATUALIZACAO-1.13.1.md indica build 87 publicada em 04/11/2026.
- Alguns trabalhos (como mixer global e mudancas FPP/TPP) estao documentados como incompletos; verificar arquivos e testes reais.
- O primeiro commit do Git apenas registra a base EXISTENTE. Ele nao muda o jogo nem prova que todo o multiplayer passou nos testes.
- Trabalho de chats anteriores a essas regras nao foi automaticamente capturado na coordenacao; realizar inventario/revisao antes de mesclar.
