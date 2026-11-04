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

## Integridade do projeto e trabalho simultaneo entre IAs

**Obrigatorio Git local:** ler tambem `docs/GIT-LOCAL-E-IA.md`, executar `git status --short --branch` e preferir uma worktree separada por tarefa (`python tools/ai_worktree.py create <tarefa>` no MAIN limpo). Nao usar a branch `main` como laboratorio de alteracoes concorrentes. Commitar somente arquivos revisados e testados; jamais usar `--no-verify`, `git clean -fdx` ou `git reset --hard` como atalho. Integracao no MAIN apenas por merge revisado. Nenhum remoto Git esta configurado.

**Obrigatório antes de qualquer escrita:** ler `docs/COORDENACAO-IA.md` e executar `python tools/ai_coord.py status`. Toda instância deve reservar os arquivos exatos que pretende modificar com `python tools/ai_coord.py start`, executar `check` antes de cada rodada de escrita, `checkpoint --confirm-own-changes` somente após validar as próprias edições e `finish` com resumo e testes ao concluir. Arquivos novos tambem entram na reserva. Se houver conflito de reserva ou divergencia de hash, interromper a escrita e reconciliar com os trabalhos em andamento; nao aceitar hash novo cegamente.

**Nunca sobrescrever arquivos do MAIN com snapshots, laboratorios de desempenho, arquivos de outros chats ou versoes antigas sem comparacao seletiva.** Nao liberar a reserva de outra IA e nao reverter trabalho alheio. Testes e geradores que escrevem no projeto tambem requerem reserva. O historico compartilhado fica em .ai-coord/registry.json no MAIN (unico para todas as worktrees) e os backups iniciais em .ai-coord/backups/. Usar Git para historico, isolamento por branches e recuperacao; manter o protocolo de reservas inclusive dentro das worktrees.
