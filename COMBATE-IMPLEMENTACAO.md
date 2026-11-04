# Combate Godot — implementação e validação

Data: 22/10/2026. Projeto principal desta alteração: `campo-cartunesco-godot`. A versão Three.js continua sendo a referência e não foi modificada.

## Arquitetura aplicada

| Arquivo | Responsabilidade |
|---|---|
| `scripts/combat_rules.gd` | Configuração por arma e modo, multiplicadores, grupos de integridade e transferência de munição |
| `scripts/weapons.gd` | Catálogo existente, dano base, cadência, alcance, velocidades, gravidade e recargas |
| `scripts/player.gd` | Corpo, caixas por região, mãos, arma física, apresentação FPP, pose, movimento e estado de combate |
| `scripts/main.gd` | Autoridade de combate, RPCs, sequência dos tiros, projéteis, impactos confirmados, inventário, compras e sessão |
| `scripts/ui_focus.gd` | Pilha única de modais, camada de bloqueio, teclado, mouse e restauração do painel anterior |
| `scripts/death_ragdoll.gd` | Corpos copiados da pose real, articulações limitadas, amortecimento, fade e remoção |

## Arma, mira e projétil

Os arquivos não possuem todos o eixo indicado no README do pacote: a Glock aponta no -X do modelo, mas os dois rifles apontam no +X. A calibração foi feita por modelo e conferida em renderizações laterais e em FPP/TPP. A escala da pistola também foi reduzida para não ficar com o tamanho de um fuzil.

A arma física fica no personagem, com um marcador no bico calculado a partir do modelo. O braço acompanha o punho, e a outra mão acompanha o apoio. O pitch se aplica ao conjunto da arma independentemente da pose do braço. A apresentação local de FPP usa uma cópia somente visual e mãos/antebraços curtos, com o mesmo referencial do cano físico. Ela não cria hitboxes nem outro projétil.

O servidor usa o raio da câmera para obter o ponto pretendido e calcula a direção a partir do cano. Ele também testa o segmento entre o personagem e o cano para bloquear uma arma que atravesse cobertura. Não há compensação artificial de gravidade: a trajetória usa velocidade inicial e aceleração vertical, com integração `p + v*dt + 0.5*a*dt²`. O alcance e o último passo são limitados mesmo quando um frame é longo.

As três armas atuais usam projéteis simulados. O caminho separado de hitscan também está disponível e foi testado; ele não é executado em conjunto com a simulação da mesma bala. O recuo afeta a câmera e os tiros seguintes, sem alterar um projétil que já existe. Há dispersão centralizada que aumenta com o movimento e diminui agachado.

## Danos e estado

A cápsula de movimento fica na camada 4. Cenário: camada 1; caixas de combate: 2; cadáveres: 8. Os tiros de infantaria consultam apenas cenário e caixas de combate. Não se infere um headshot pela proximidade do ponto à cabeça da cápsula.

Há caixas para cabeça, peito, abdômen, pélvis, braços, antebraços, mãos, pernas e pés, todas filhas das peças que se movimentam. A pélvis recebe a regra de abdômen. O modelo em blocos não tem pescoço separado, portanto não foi inventada uma região de pescoço invisível.

Vida geral: 100. Multiplicadores atuais: cabeça 2,5; peito 1; abdômen 0,9; braços/antebraços 0,65; pernas 0,75; mãos/pés 0,4. A regra anterior de cabeça fatal foi preservada como opção explícita nos modos atuais (`fatal_headshot`), sobrepondo o multiplicador quando habilitada.

A integridade acumula dano base no grupo atingido. Braço direito inutilizado bloqueia armas de fogo; braço esquerdo inutilizado bloqueia as armas de duas mãos. A pose do braço cai e danos nas pernas reduzem a velocidade. Rastejamento não foi habilitado. A separação visual de membros ocorre no ragdoll de morte, apenas em modos que a permitem, quando a integridade zerou e a arma permite separação. No PVP ela está desabilitada. Uma pistola não desmonta o corpo inteiro.

FAL: 30 no carregador, reserva inicial 180, recarga 6 s. Glock: 12, reserva 60, recarga 4 s. Sniper: 5, reserva 25, recarga 4,5 s. A recarga transfere somente o que falta e existe na reserva. Troca de arma ou morte cancela a operação sem transferir munição, incluindo o som da recarga.

## Autoridade e sincronização

Cada tiro tem proprietário, vida do personagem e sequência. O servidor verifica vida, arma equipada e possuída, munição, recarga, cadência, valores finitos, proximidade da câmera e plausibilidade da mira. O cliente não escolhe o cano de origem. Trocas de armas usam comandos confiáveis; snapshots de movimento não podem ultrapassar um tiro e trocar sua arma no servidor.

O cliente pode apresentar o recuo imediatamente; somente tiros aceitos criam a bala compartilhada. A confirmação tem origem e direção únicas, e os clientes deduplicam os efeitos pelo identificador do tiro. Inventário confirmado é reconciliado com pedidos ainda pendentes. O impacto e o dano são confirmados pela autoridade. Morte e ragdoll são limitados a uma ocorrência por vida.

Posições e inclinação de jogadores remotos são interpoladas. Agachamento, arma, mira, recarga, vida e integridade também são replicados. Não há rewind de histórico para hitscan: as armas ativas são físicas e o servidor resolve a colisão no estado atual. Nenhum timestamp antigo fornecido pelo cliente pode escolher um alvo em um estado arbitrário do passado.

Os seis sons de morte da versão de consulta foram recuperados. O servidor escolhe um índice e todos reproduzem o mesmo áudio 3D na origem da morte. Disparo, impacto e recarga também possuem apresentação remota. Sons de recarga acompanham o ator; há limite de vozes e limiter no Master.

## Interfaces

Pausa, arsenal, personalização, configurações e confirmação de compra usam a mesma pilha de modais. Só a camada superior recebe interação. O modal possui bloqueador cobrindo o fundo e conteúdo com rolagem. Um painel não pode entrar duas vezes na pilha.

Abrir um modal libera o cursor e limpa o gatilho. Movimento, câmera, disparo e seleção de arma verificam o mesmo bloqueio. Fechar deixa o cursor livre: clique no cenário para retomar o foco. Escape fecha o painel superior. O jogo online não é pausado e o personagem continua recebendo dano.

A carteira online é validada por sessão no anfitrião e começa com 30.000 moedas; o abate concede 30 pelo servidor. O cliente usa o saldo confirmado no mesmo perfil/HUD/loja. Não há uma conta permanente autenticada entre anfitriões diferentes.

Compras usam identificador de operação, bloqueiam nova submissão pendente, validam saldo/nível/propriedade no servidor e guardam o resultado para impedir desconto duplicado. As configurações atuais incluem volume e resolução. Listas nativas do Godot ficam acima do modal.

## Evidências de execução

Os resultados estão nos JSONs de `tests/`, e os logs de execução em `work/`.

- `combat_integration.gd`: 86 verificações, com raios físicos por região, multiplicadores, cabeça fatal, escala/agachamento, orientação dos modelos em três inclinações, transferência/cancelamento de recarga, duplicata e falta de munição, origem inválida, cobertura junto ao cano, tiros a 20/60 m, alvo em movimento, hitscan, queda da sniper, limite de alcance, dano acumulado, estado embarcado e deduplicação de morte.
- `ui_integration.gd`: 13 verificações na janela renderizada. Cliques e teclas são enviados pela árvore real de entrada do Godot. Inclui texto, bloqueio de movimento/câmera/tiro, pilha de modais, seletor de resolução, Escape e repetição de uma compra. O caminho automatizado do dropdown emite a ação `index_pressed` do próprio PopupMenu; o caminho `--native-input` permite a seleção na janela nativa e também foi executado.
- `ragdoll_stability.gd`: 4 verificações. Mede velocidade máxima, penetração no piso, duplicação e remoção por tempo. O resultado medido está em `ragdoll-results.json`.
- `network_combat.gd`, `network_fixture.gd`, `run_network_tests.py`: servidor e DOIS clientes em processos Godot separados, conectados por ENet. Um proxy UDP introduz 20–70 ms por sentido e descarta aproximadamente 8% dos datagramas. Verifica tiro duplicado, dano, headshot, morte/ragdoll únicos, respawn, recarga, cancelamento por troca de arma, estado remoto, saída e reconexão. O relatório de transporte guarda a contagem real de pacotes. A prova adicional confere o identificador novo após reconectar, a remoção do avatar antigo em todos os clientes, a pose de mira elevada/agachada em movimento e dano recebido com Configurações aberto. Também compara o índice do áudio de morte nos três processos.
- `visual_combat.gd`: capturas da renderização real em FPP, TPP, mira de ferro, luneta e vista lateral das mãos. Imagens em `tests/screens/`.

Os executáveis de teste usam a versão **console** do Godot e aguardam a execução. Os relatórios não dependem apenas de um código de saída do editor, que pode ser zero mesmo havendo erro de script.

## Limites do que está validado

A integração foi feita nos modos de infantaria que existem nesta instância Godot: escritório/NPCs, deserto/NPCs e PVP LAN. O Modo Guerra com equipes e blindados, listas públicas de salas e inventário completo ainda não existem nesta instância; os módulos compartilhados podem ser usados quando esses modos forem portados. A navegação e o arsenal naval continuam separados do combate de infantaria; a auditoria naval completa não faz parte desta validação.

Veículos comuns continuam desabilitados. Foi validado o bloqueio de arma pessoal pelo estado embarcado, sem afirmar que um ciclo real de entrar/sair de veículo foi testado. Os testes de rede usam processos reais no mesmo PC, não dois computadores físicos nem internet pública. O terreno da prova de rede é plano para tornar os impactos repetíveis.

Ragdolls são efeitos físicos locais a partir da morte confirmada, da pose e da direção do impacto; não são corpos autoritativos de gameplay, não recebem dano e não bloqueiam balas. Não há garantia de posições idênticas de cada membro depois de colidir com o chão em máquinas diferentes.

A renderização pela execução contida deste ambiente ainda registra avisos do Godot sobre diretório de shader cache `user://` indisponível e duas texturas OpenGL pendentes ao encerrar o teste com capturas. Eles não apareceram como falha de script nos testes de combate/rede. O perfil tem caminho alternativo local se o diretório de usuário não puder ser resolvido. Esses avisos do renderizador não foram apresentados como corrigidos.

## Como experimentar

Reabra `JOGAR.bat` para carregar o código novo. V alterna FPP/TPP; botão direito alterna mira; um segundo clique rápido abre mira de ferro/luneta. R recarrega; Ctrl agacha; Shift corre; 1–6 escolhem arma. Escape abre o menu sem pausar o multiplayer. Ao fechar um menu, clique no cenário para capturar o mouse novamente.

`TESTAR-COMBATE.bat` executa as verificações reproduzíveis. Os testes não gravam progresso do usuário e usam as portas UDP temporárias 39122–39124; a partida normal permanece na 3010.
