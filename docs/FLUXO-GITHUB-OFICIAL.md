# Fluxo oficial de desenvolvimento — GitHub

Status: proposta normativa para revisao via Pull Request. Data: 2026-11-06.

## Fonte central

O repositorio GitHub `xyborges/Toque-De-Campo` e a fonte central de codigo, documentacao, decisoes, resultados e historico. A branch `main` representa a integracao aprovada, nao um laboratorio de desenvolvimento. O computador local executa Godot, testes e commits; cada instancia de IA trabalha em branch e worktree proprias.

## Fluxo obrigatorio

1. Fazer `git fetch origin` e verificar `git status --short --branch` antes de iniciar.
2. Criar branch exclusiva a partir de `origin/main`, com nome `ia/<tarefa>` ou `perf/<tarefa>`, preferencialmente em worktree separada.
3. Ler `AGENTS.md`, `docs/COORDENACAO-IA.md` e `docs/GIT-LOCAL-E-IA.md`. Respeitar reservas de arquivos e nao sobrescrever trabalho de outras IAs. Se o Python ou o coordenador estiver indisponivel, nao editar arquivos compartilhados sem resolver a limitacao; trabalhos documentais isolados podem ser preparados para revisao.
4. Alterar somente os arquivos da tarefa. Testar, revisar `git diff`, executar `git diff --check` e commitar apenas arquivos revisados. Nunca contornar hooks.
5. Enviar a branch ao GitHub e abrir Pull Request com objetivo, arquivos, riscos, testes executados e pendencias. Nao fazer push direto para `main` como rotina de desenvolvimento.
6. Revisar o diff e conflitos do PR. Integrar na `main` somente apos validacao e aprovacao; exigir checks automatizados quando configurados.
7. Sincronizar outras maquinas com `git fetch` e `git pull --ff-only` na `main` limpa. Nao sobrescrever modificacoes locais.

## Benchmarks e evidencias

Versionar configuracao, commit exato, versao do Godot, hardware, parametros, dados brutos de frametime, logs, telemetria pertinente e relatorio de interpretacao. Preservar coletas invalidas com rotulo explicito. Comparar desempenho somente em protocolos equivalentes; nao declarar melhoria sem medir FPS, 1% low, P95/P99 e travamentos. Nao publicar credenciais, tokens, identificadores pessoais desnecessarios, caches, executaveis de build ou arquivos privados.

## Protecao de main

Configurar no GitHub regras de branch para exigir PR, ao menos uma aprovacao independente, checks de teste e bloqueio de force-push e exclusao da `main`. Essas protecoes dependem de configuracao administrativa no GitHub e nao sao ativadas por este documento.

## Migracao dos documentos antigos

Trechos antigos que afirmam 'Git local sem remoto' ou proíbem remoto estao desatualizados desde a autorizacao expressa do GitHub em 2026-11-06. Atualiza-los em PR separado, sem descartar as regras ainda validas de integridade, coordenacao, revisao e preservacao de worktrees.
