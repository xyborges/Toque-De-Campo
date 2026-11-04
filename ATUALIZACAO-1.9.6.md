# 1.9.6 — Guerra com bots e Javelin

Publicada no Ubuntu em 27/10/2026, build 68.

- Guerra online começa com um jogador humano implantado. Bots completam até seis por equipe; jogadores adicionais substituem bots. Os APCs de transporte ficam disponíveis para jogadores, enquanto bots podem operar outros blindados.
- O antigo lançador exibido como Stinger passa a se chamar Javelin. Preserva o modelo anterior e o identificador interno usado por inventário e rede; não é uma nova modelagem. Adquire drones e blindados terrestres inimigos visíveis, sem trava em veículos aliados, embarcações ou alvos cobertos.
- O servidor confirma a trava no instante do disparo. O projétil persegue o centro do blindado e usa as regras de colisão e dano existentes. Não foi implementado ataque por cima nem modelagem física fiel de uma Javelin real.
- Página de atualizações: versão atual em destaque e histórico das versões documentadas, com adições e correções em colunas separadas. A versão 1.6.2 foi incorporada à 1.6.3 e não teve lançamento separado.

## Verificações

- `tests/javelin196.gd`: aquisição, trava, lançamento, impacto físico em tanque, bloqueio por cobertura e recusa de alvos aliados.
- `tests/run_bots195_network.py`: um jogador inicia, equipes são preenchidas, APCs ficam disponíveis, novos jogadores substituem bots e rodada reinicia; transporte DTLS com três clientes.
- O teste publicado da 1.9.5 identificou falha ao entrar no APC depois que bots já o haviam levado; esta versão reserva os APCs aos humanos durante as partidas online. A repetição em produção é necessária após publicar.
