# Fluxo oficial de desenvolvimento — GitHub

Atualizado: 08/11/2026. Fonte central: https://github.com/xyborges/Toque-De-Campo

## Fonte de verdade e princípios

O GitHub é a fonte central de código-fonte, decisões, documentação, benchmarks revisados e histórico de integração. A branch remota origin/main representa a última integração aprovada. A main local de qualquer computador é apenas um espelho e pode estar atrasada.

Todas as instâncias de IA têm o MESMO protocolo; nenhuma precisa ser integradora permanente. Cada tarefa começa com uma branch exclusiva derivada de origin/main e termina com commit, push, Pull Request (PR), testes e um resumo verificável. A IA não integra nem publica uma build sem decisão explícita de integração/publicação.

Não fazer push direto na main, force push, squash indiscriminado de resultados de outras IAs ou copia de snapshots/laboratorios por cima de arquivos recentes. Não reescrever o histórico remoto.

## Procedimento obrigatório, em qualquer computador

1. Conferir repositório e origem: git remote -v (origin deve apontar para xyborges/Toque-De-Campo). Ler AGENTS.md, docs/COORDENACAO-IA.md, docs/GIT-LOCAL-E-IA.md e este documento.
2. Executar git fetch origin e verificar git status -sb. Nunca supor que main local está atualizada; usar origin/main como base. Não descartar alterações locais.
3. Consultar branches e PRs já existentes no GitHub; evitar tarefa duplicada, documentar relações/dependências e citar Issue/PR anterior quando houver.
4. Criar uma branch exclusiva identificada por PC+tarefa, em worktree separada. Preferir python tools/ai_worktree.py create nome-da-tarefa; ele busca origin/main e não altera a main atual.
5. Consultar python tools/ai_coord.py status para verificar reservas LOCAIS da máquina. Reservar arquivos via start, verificar check antes de editar, checkpoint somente para mudanças próprias e finish ao concluir. Em outra máquina esse registro NÃO é compartilhado.
6. Implementar dentro da worktree, com commits pequenos, diff revisado, testes apropriados e evidências de QA. Antes de commitar: git diff --check, python tools/github_preflight.py (quando disponível), git status -sb. Nunca usar --no-verify.
7. Enviar a branch: git push -u origin HEAD. Criar PR para main no GitHub com escopo, SHA da base, testes, hardware/renderizador, riscos, regressões, pendências e link de evidências. Nunca escrever que um teste passou se não foi executado.
8. Após testes automatizados e revisão dos conflitos, integrar via PR. Só então sincronizar as outras cópias locais (git fetch origin; no checkout main LIMPO: git merge --ff-only origin/main ou python tools/ai_worktree.py sync-main).
9. Publicação de servidor/cliente é outro fluxo, não é consequência automática de merge. Usar pipeline oficial de release, hashes e QA específicos do jogo.

## Quando duas IAs modificam os mesmos arquivos

Worktrees isolam o disco, mas não evitam conflitos de Git. O GitHub mostra PRs/branches em revisão; verificar sua existência antes de iniciar. Se a base mudou, buscar origin e reconciliar explicitamente os diffs no branch de trabalho. Não selecionar blindly ours/theirs, não forçar push, não aplicar snapshot inteiro. Se uma IA não concluiu, deixar PR em rascunho; registrar testes que faltam.

O ai_coord.py só coordena worktrees que compartilham o MESMO diretório Git na MESMA máquina. NÃO sincronizar .ai-coord/registry.json pelo GitHub (contém caminhos locais, travas transitórias e backups). Para contexto global persistente, usar Issues, PRs, commits, documentação e relatórios sanitizados no repositório.

## Padrão mínimo de PR

- Título claro e referência a Issue/PR relacionada.
- Base origin/main e commit da branch identificados.
- Arquivos/sistemas impactados; hipóteses, ganhos, limitações e trade-offs.
- Comandos de testes e resultados PASS/FAIL/SKIP, com hardware, Godot, renderizador, resolução, quantidade de bots, mapas, FPS e P95/P99 quando desempenho for relevante.
- Dados brutos pequenos e sanitizados em docs/benchmark-results/ quando necessários; arquivos enormes e temporários permanecem locais, e nenhum dado secreto/pessoal pode ser enviado.
- Riscos, rollback e pendências. Nunca confundir bench headless com FPS gráfico.
- Não aprovar PR apenas pela mensagem da IA: revisar diff, checks, conflitos e impacto.

## Regras administrativas recomendadas no GitHub

Em Settings > Rules > Rulesets (ou Branches), criar proteção para main: exigir PR; bloquear force-push e exclusão; exigir checks de integridade; exigir revisão quando houver revisor independente disponível. Essas opções dependem do plano/permissões e precisam ser confirmadas na interface do repositório. Não presumir que já estão ativas.

O workflow .github/workflows/quality-gates.yml valida scripts auxiliares e tamanho/nome de arquivos versionados. Ele NÃO substitui teste Godot 4.7, FPS GTX 1650, ENet, áudio espacial ou QA de mapas. Checks podem depender de GitHub Actions habilitado.

## Tamanho, segurança e dados

Versionar scripts, cenas, mapas, recursos realmente usados, projetos, relatórios e configurações reprodutíveis. Não versionar work/, builds, caches .godot, distribution/private, tokens, chaves privadas ou arquivos de usuário. O limite defensivo de 50 MiB do git_guard permanece; Git LFS só deve ser adotado para assets específicos após avaliar necessidade, quota e impacto nos dois PCs. Não transformar GitHub em repositório de executáveis e logs gigantes.

## Sincronização sem sobrescritas

- Conferir branch e status antes de atualizar. Em main local limpa, fast-forward somente; se houver divergência, parar e investigar.
- Na worktree de desenvolvimento, fazer fetch; integrar origin/main mediante reconciliação de conflitos e testes. Commit e push da branch, nunca da main.
- Em caso de falha no GitHub/rede, preservar commits localmente e registrar que o push/PR ficou pendente; não afirmar entrega remota.
- O histórico de GitHub é durável para arquivos versionados, mas o jogo em execução, bancos, configurações privadas e cache exigem backup separado.

## Novas instâncias de IA

Instrução curta: "Leia AGENTS.md e docs/FLUXO-GITHUB-OFICIAL.md; obtenha origin/main, crie branch/worktree própria, use coordenação local, execute toda a tarefa até testes/commits/push/PR, sem modificar ou publicar main. Informe pendências reais, nunca apenas resultados parciais."
