# Armas brancas e NPCs — Godot

## Causa e correções

Antes, as três ferramentas eram duas caixas semelhantes, e o ataque era um raio instantâneo da câmera. O movimento das mãos não determinava o dano. O treino iniciava quatro NPCs e repunha apenas um a cada 14 segundos, até oito; o deserto iniciava seis sem reposição.

Agora `scripts/melee_rig.gd` constrói modelos distintos, com cabos cilíndricos, encaixes, empunhaduras e marcadores da região de impacto:

- **Vassoura:** base de madeira e 39 feixes de cerdas, segurada com as duas mãos; varredura lateral/diagonal.
- **Rodo:** travessa metálica em T e faixa de borracha; golpe diagonal descendente.
- **Machado:** cabo mais espesso, encaixe, contrapeso e lâmina volumétrica afunilada; preparação acima da cabeça e golpe descendente.

| Arma | Dano base | Limite de alcance* | Duração | Janela de contato |
|---|---:|---:|---:|---:|
| Vassoura | 16 | 2,25 m | 0,86 s | 0,26–0,51 s |
| Rodo | 25 | 2,20 m | 1,00 s | 0,32–0,56 s |
| Machado | 52 | 1,95 m | 1,22 s | 0,40–0,64 s |

*O limite não cria um raio de dano: o inimigo precisa tocar a trajetória real das cerdas, borracha ou lâmina. O alcance efetivo depende do comprimento, da pose, da região corporal e da inclinação do jogador.

Cada ferramenta usa um `AnimationPlayer` com preparação, execução e recuperação. A animação é avançada na física em subpassos de até 1/120 s, divididos nos limites da janela ativa. As posições sucessivas dos marcadores formam cápsulas de colisão pequenas contra as regiões do corpo. O cabo não é usado como lâmina, e a recuperação não causa dano. O dono e as cápsulas de movimentação são excluídos.

O servidor registra os alvos já atingidos por golpe. Raios de obstrução verificam a trajetória e a ligação entre arma, mãos e alvo para impedir dano através de paredes. Os acertos passam pelo mesmo caminho de dano localizado, sangue, morte e ragdoll utilizado pelas armas de fogo. Trocar de arma ou morrer invalida a continuação do golpe anterior.

A cabeça continua recebendo dano multiplicado, mas ferramentas leves não usam o headshot fatal de qualquer bala. O machado pode inutilizar/desmembrar um membro após esgotar sua integridade; vassoura e rodo não seccionam membros. O ragdoll de morte continua com limite de dez corpos, congelamento e remoção gradual.

O modelo do mundo move os braços e o tronco. FPP usa uma cópia visual da mesma pose, com mãos e antebraços ligados às empunhaduras. Online, o evento de ataque aceito inicia a mesma animação nos demais jogadores; apenas o servidor calcula os contatos e confirma o dano. A latência da rede ainda pode produzir diferenças de tempo entre a previsão local e a confirmação, sem delegar dano ao cliente.

## Diretor offline

`scripts/offline_director.gd` lê os colisores estáticos existentes e gera uma grade A* para desviar de mesas, paredes e objetos. A margem considera a largura do personagem; a discretização usa ceil/floor para não fechar corredores fisicamente transitáveis.

- Escritório: **8 NPCs iniciais**, crescendo até **16**.
- Deserto offline: **12 iniciais**, crescendo até **24**.
- Reposição a cada **0,45 s**, enquanto houver déficit e o jogador estiver vivo.
- O número desejado aumenta em um a cada 18 segundos, até o limite do mapa.
- Posições válidas, conectadas à área do jogador, afastadas do jogador e pelo menos 2 m de outro NPC no instante do spawn.
- Evita a parte frontal central visível da câmera. Se não houver uma posição adequada, adia a tentativa em vez de criar dentro de uma parede.
- Recalcula direções em intervalos escalonados e armazena caminhos por aproximadamente 0,65–0,85 s; mantém gravidade e movimentação física em todos os ticks.
- Separação entre NPCs, reação a impactos, redução de velocidade por lesão nas pernas e perseguição após dano não fatal.
- Ataque desarmado animado: preparação antes de aplicar dano, distância verificada no contato e bloqueio por paredes. Sem armas de fogo para NPCs.

Não foi adicionado reaproveitamento de NPCs nesta etapa: as medições com 16 inimigos não mostraram necessidade. Formas de consulta dos golpes são reutilizadas, e cadáveres continuam limitados.

## Validação

- `tests/melee_offline_integration.gd`: animações reais contra NPCs parados e em movimento, mãos nas empunhaduras, janela ativa, erros físicos, região do braço, reações, paredes, ausência de duplicação, spawn e reposição.
- `tests/melee_visual.gd`: executa a versão gráfica e captura modelos, golpes e FPP para inspeção.
- `tests/run_melee_network.py`: duas instâncias Godot conectadas; confirma animação do jogador remoto e o mesmo contato no servidor e cliente.
- `tests/combat_integration.gd`: 86 verificações anteriores do combate com armas de fogo continuam passando.
- `tests/run_network_tests.py`: regressão com servidor e dois clientes, atraso de 20–70 ms por sentido e aproximadamente 8% de perda UDP; dano, morte, áudio, recarga e reconexão.
- `tests/offline_performance.gd`: amostra gráfica de 9 s, com 16 NPCs, movimentação e ataques. Na GTX 1650 desta máquina, em 1280×800: mediana e p95 de quadro de 16,67 ms (60 FPS), p95 de física de 3,75 ms, 317 draw calls; todos os 16 se moveram e sete alcançaram o jogador durante a amostra. Não é garantia para outras máquinas nem teste prolongado.

O ambiente continua registrando bloqueio da pasta de cache de shaders e duas texturas pendentes no encerramento de capturas gráficas; não ocorreram erros de script nesses testes. Não atribuí esses avisos à lógica dos golpes.

Referências: [AnimationPlayer](https://docs.godotengine.org/en/stable/classes/class_animationplayer.html), [AStarGrid2D](https://docs.godotengine.org/en/stable/classes/class_astargrid2d.html).
