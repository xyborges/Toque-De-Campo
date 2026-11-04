# Toque de Campo 1.6.4 — fogo amigo e confirmação do respawn

**Publicada em 24/10/2026, build 30.** Confirmação em `work/release164-publication.log`. Inclui as melhorias de combate, equipamentos, ópticas, câmeras, HUD e áudio descritas em [ATUALIZACAO-1.6.3.md](ATUALIZACAO-1.6.3.md).

## Regra solicitada de fogo amigo

No modo Guerra, aliados podem causar dano uns aos outros. Um aliado morto por outro gera:

- **−100 pontos de partida para o autor**, uma vez por vítima/vida. A pontuação pode ficar negativa.
- **Uma morte para a vítima**, inclusive no placar e no registro de mortes online da autoridade.
- Nenhum abate, assistência, dano pontuável ou moeda para o autor por esse ataque.
- Um aviso para o autor: **FOGO AMIGO · Você matou [nome]. −100 PONTOS**.
- Um aviso para a vítima: **FOGO AMIGO · Você foi morto por seu aliado [nome]**.

As mensagens são dirigidas pelo servidor aos envolvidos, duram oito segundos e continuam visíveis sobre a câmera de morte e o menu de implantação. Um terceiro jogador não recebe esses avisos privados. A interface usa os estilos e a cor de alerta existentes; não captura controles.

Blindados aliados também recebem dano. Sua destruição não concede bônus de veículo; cada ocupante aliado morto gera sua própria penalidade de 100 pontos e aviso. O escudo temporário de implantação permanece. A vida, as colisões, a validação dos disparos e o respawn continuam no servidor. O treino Guerra offline usa a mesma regra. Deserto todos contra todos e o treino original mantêm suas regras próprias.

Suicídio conta a morte, sem abate, moeda nem penalidade de matar aliado. O teste central da 1.6.3 revelou que a antiga imunidade por equipe também bloqueava o dano da própria granada em Guerra. Esse caminho foi corrigido; uma granada armada permanece letal ao portador após seu pavio de cinco segundos.

## Implementação

- `scripts/main.gd`: hook de relação entre atacante/vítima, preservando os caminhos originais de dano, confirmação e morte; ataques amigos não passam pelos créditos de abate/recompensa.
- `scripts/match_stats.gd`: penalidade idempotente por vida; remove o registro de possíveis assistências da vida encerrada.
- `modes/war/scripts/game.gd`: identifica aliados, registra morte normal, desconta pontos e envia avisos confiáveis aos dois envolvidos.
- `modes/war/scripts/vehicles.gd`: dano em blindados aliados sem pontuação positiva; ocupantes seguem a rotina autoritativa de morte.
- `modes/war/scripts/ui.gd`: aviso reutilizável, temporizado pelo próprio controle, sem callback que sobreviva à partida.
- `modes/war/scripts/rules.gd`: penalidade de 100 pontos e protocolo revisão 4. Todos os clientes precisam atualizar.

## Validação

O teste nativo `tests/war_friendly_fire.gd` aprovou 19 verificações: dano amigo não fatal, headshot, pontuação negativa, morte, mensagens distintas, repetição sem dupla penalidade, recompensa inimiga preservada, escudo, suicídio, destruição de APC aliado/ocupante e visibilidade do aviso no menu. Captura em `work/war-friendly-fire-alert.png`.

Regressões locais após a regra: 91 verificações de tripulação, 41 de retorno de blindados, 79 de sistemas Guerra, 34 de placar/estatísticas, 64 de combate/granadas/dominação, 28 de recarga, 10 de despacho de morte e 28 de respawn/câmera. A sessão anterior de três clientes de Guerra também foi repetida: 25 verificações, com RPG/Stinger, suporte, desconexão e recarga.

O teste com servidor e três clientes ENet aprovou **16 verificações**, incluindo tiros reais pela FAL, −100 pontos replicados, morte sem abate e avisos privados corretos para autor/vítima. Um oponente sem relação com o incidente não recebeu o aviso. Evidências: `work/release164-friendly-network.log` e relatórios `tests/war-friendly-network-*.json`.

Depois da publicação, o download e a atualização pelo launcher passaram, incluindo uma segunda abertura sem download repetido e inspeção dos recursos do pacote. O treino offline exportado iniciou com um humano e onze bots (quatro verificações). Não é necessário baixar novamente o launcher para receber builds posteriores.

**Morte e respawn no Ubuntu publicado:** duas contas reais, sem modo de teste nem token de servidor, aprovaram **19 verificações**. A granada segurada explodiu em **5,021 s**; o respawn ocorreu em **4,050 s**, com a classe Médico e o ponto avançado salvos no M. O outro jogador recebeu a mesma morte, nova vida e corpo/classe restaurados. A câmera TPP voltou ao jogo. A conta registrou exatamente uma morte, sem criar abate ou moeda. Evidência: `work/release164-central-respawn.log`.

**Tripulação no Ubuntu publicado:** três contas reais aprovaram **33 verificações**, com validação normal de movimento/comandos, promoção, saída, câmera independente e recusa de pacotes de controle/disparo enviados por passageiro. Evidência: `work/release164-central-passengers.log`.

As medições de desempenho da 1.6.3 permanecem históricas, descritas em `GUERRA-DESEMPENHO.md`; não foi atribuído um ganho de FPS à adição do fogo amigo.

As seis etapas de pós-publicação passaram sem erros: distribuição/launcher, morte/respawn central, tripulação central, PvP Deserto, Naval e ranking/API. Nas partidas do Deserto e Naval foram usados dois clientes autenticados em cada modo. A API aprovou 11 verificações, incluindo a recusa das quatro ações de autoridade para credenciais de jogador. Resumo: `tests/release164-postpublication.json`.
