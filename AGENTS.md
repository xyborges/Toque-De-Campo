# Diretrizes permanentes do projeto

## Biblioteca de objetos de cenário

Todo novo objeto de cenário solicitado deve ser entregue primeiro como uma cena reutilizável em `modes/war/library/`, ou na biblioteca equivalente do modo quando for específico dele. Acrescentar o objeto ao catálogo do editor; quando o pedido indicar um local, integrar também ao mapa.

Cada peça deve incluir modelo, escala/origem coerentes, materiais compartilhados, colisão apropriada e metadados de superfície. Configurar LOD, agrupamento/instanciamento e propriedades de destruição/resistência quando aplicáveis. Peças modulares devem ter pontos de encaixe compatíveis. Instâncias reutilizam os mesmos recursos.

Mover, girar, duplicar e salvar uma peça deve manter aparência, colisões e comportamento juntos. Elementos que alteram terreno ou jogabilidade precisam produzir o mesmo resultado no offline e na autoridade multiplayer. Não criar objetos exclusivamente visuais quando o pedido exige contato ou interação.

### Padrão de carregamento e LOD de novos objetos

Tratar LOD, recursos compartilhados e alcance como parte obrigatória da entrega de qualquer objeto novo. A cena da biblioteca deve declarar seu perfil/alcances; a integração usa agrupamento estático ou MultiMesh por célula quando houver repetição, evitando um script por detalhe. Folhagem e pequenos detalhes decorativos não recebem colisão nem sombras individuais por padrão. Cobertura física conserva colisão e bloqueio de tiros mesmo quando o modelo visual distante é simplificado; a qualidade gráfica não pode retirar proteção de um jogador. Objetos que alteram caminhos precisam entrar também na navegação preparada. Escolher os alcances pela escala e função da peça e verificar os três casos: perto, transição e longe.

Preservar cenas modificadas pelo usuário. Geradores normais não podem sobrescrever essas cenas silenciosamente. Preferir edições pontuais e migrações que preservem nós existentes.

## Escopo

O Guerra é um modo do jogo existente. Reutilizar seus sistemas de personagem, combate, contas, interface e rede. Considerar offline e multiplayer em todas as alterações pertinentes. Preservar o projeto Three.js de referência.

## Composição do mapa afegão

Planejar cursos d'água, rede viária, canais, campos e acessos às propriedades antes de posicionar construções e detalhes. Reservar essas áreas na mesma fonte de dados usada pela autoridade e pelo cliente. Priorizar conjuntos coerentes e transições entre povoado, agricultura e terreno natural; não preencher vazios com objetos aleatórios como substituto de composição. Manter interiores e caminhos de acesso livres.

## Interface

Seguir `DIRETRIZES-INTERFACE.md`; usar nomes curtos, ícones e estados visuais, sem explicações óbvias ou mensagens internas de implementação.

## Áudio criado com IA

Antes de gerar, importar ou substituir áudio do jogo, seguir `docs/INSTRUCOES-AUDIO-IA.md`. Não gerar nem alterar assets de áudio quando o pedido for apenas análise, planejamento ou orientação. Preservar o original e validar qualquer variante dentro do mixer real do jogo antes de propor substituição.

## Integridade do projeto e trabalho simultaneo entre IAs

**Fonte central: GitHub `xyborges/Toque-De-Campo`, branch `origin/main`.** Antes de qualquer tarefa, ler `docs/FLUXO-GITHUB-OFICIAL.md`, `docs/GIT-LOCAL-E-IA.md` e `docs/COORDENACAO-IA.md`; executar `git fetch origin` e consultar `git status --short --branch`. Cada IA usa branch e worktree exclusivas derivadas de `origin/main` atualizado; para criar uma, usar `python tools/ai_worktree.py create <tarefa>`. NUNCA editar ou enviar diretamente para `main`, nem fazer merge local como forma de integrar. Enviar a branch ao GitHub, abrir Pull Request e integrar somente apos revisao, testes e aprovacao. Nunca usar `--no-verify`, `git clean -fdx`, `git reset --hard`, force push ou restauracao de snapshot como atalho.

**Obrigatório antes de qualquer escrita:** ler `docs/COORDENACAO-IA.md` e executar `python tools/ai_coord.py status`. Toda instância deve reservar os arquivos exatos que pretende modificar com `python tools/ai_coord.py start`, executar `check` antes de cada rodada de escrita, `checkpoint --confirm-own-changes` somente após validar as próprias edições e `finish` com resumo e testes ao concluir. Arquivos novos tambem entram na reserva. Se houver conflito de reserva ou divergencia de hash, interromper a escrita e reconciliar com os trabalhos em andamento; nao aceitar hash novo cegamente.

**Nunca sobrescrever arquivos do MAIN com snapshots, laboratorios de desempenho, arquivos de outros chats ou versoes antigas sem comparacao seletiva.** Nao liberar a reserva de outra IA e nao reverter trabalho alheio. Testes e geradores que escrevem no projeto tambem requerem reserva. O historico local de reservas fica em `.ai-coord/registry.json` no checkout principal DE CADA MAQUINA; ele e compartilhado entre worktrees do mesmo repositorio local, **NAO entre computadores**. Para coordenacao global, consultar branches/PRs/Issues no GitHub e atualizar os registros versionados. Nao afirmar que o `ai_coord.py` bloqueia alteracoes em outro computador. Os backups iniciais sao locais em `.ai-coord/backups/`; commits e PRs sao o historico duravel. Nenhuma atualizacao do jogo sera publicada automaticamente ao integrar codigo.
