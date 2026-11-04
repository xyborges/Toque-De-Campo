# BR — pareamento, mochila e personagem

Atualização posterior de interface e saque: [Inventário modular e corpos saqueáveis](INVENTARIO-MODULAR-E-CORPOS.md). A mochila atual substitui o layout antigo descrito nesta revisão.

Revisão local de 29/10/2026. Substitui as regras anteriores de início em 15 segundos e entrada tardia como espectador. Nenhuma publicação, instalação ou alteração no servidor/VPN foi realizada.

## Partidas

- INICIAR abre a busca e encaminha o jogador para uma sala disponível. O encaminhador e cada partida utilizam conexões ENet/DTLS próprias.
- A sala mostra nomes dos humanos e bots, contador e SAIR. O primeiro humano admitido inicia uma janela fixa de 30 segundos; novas entradas ou saídas parciais não a reiniciam. Preparação/carregamento e conexão precedem essa contagem.
- Online: até 12 participantes, com bots do servidor preenchendo vagas. Humanos substituem bots durante o pareamento. Não é mais necessário aguardar um segundo humano. Offline: jogador e sete bots, também com os 30 segundos.
- Ao iniciar, a sala é fechada. Uma entrada posterior é recusada antes da criação de personagem/inventário; o cliente refaz a busca de forma limitada. Outro grupo recebe outra partida, com processo, porta e dados separados.
- Quando o último humano sai, bots não mantêm a partida viva: contagem/reinício são cancelados, os bots são liberados e o processo daquela sala encerra. Reservas não utilizadas têm validade e salas vazias/carregamentos travados são recolhidos.
- O grupo que permanece após o resultado tem 60 segundos de intervalo, seguido de nova espera de 30 segundos. A sala continua fechada para participantes de fora desse grupo.
- Limite operacional padrão: quatro partidas simultâneas, configurável até 16. Isso é um limite de alocação, não uma certificação de desempenho do servidor. Serviço local preparado e detalhes de implantação em `BR-PARTIDAS-SERVIDOR.md`.

Reservas são descartáveis, vinculadas à conta e verificadas junto do ticket, desafio novo e prova da chave do dispositivo. O servidor verifica a janela de admissão novamente, mesmo que o cliente já tenha recebido uma reserva. Repetir uma busca limpa geração, snapshot, inventário, posições, câmeras e transporte da sala anterior.

## Mochila

Três painéis com bordas e linhas divisórias: CHÃO, MOCHILA e EQUIPAMENTO. Munição e acessórios carregados ficam na coluna central; cada arma e a sua luneta ficam juntas na direita, com o cartão atual destacado. Proteção corporal tem uma seção separada.

Slots 1 e 2 são genéricos e clicáveis. Não existe uma exigência de fuzil mais pistola: combinações de fuzis, sniper, pistola e lançadores permitidos funcionam conforme os itens coletados. Permanecem as regras de dois itens de arma e de não duplicar o mesmo identificador de arma. Os punhos ficam disponíveis à parte, pela tecla 3.

Capturas em Compatibility/GTX 1650, 1280 × 800: `work/br-backpack-layout-1280x800.png` e `work/br-waiting-layout-1280x800.png`.

## Combate com lunetas

Teste realizado com servidor headless e dois clientes gráficos simultâneos, ENet/DTLS, usando FAL/AK e Prismática/PSO nas quatro combinações. São disparos reais aceitos pelo servidor, projéteis, colisões e dano nos dois sentidos, além de movimentação da câmera, recuo, troca de luneta, mira de ferro, recarga, morte e espectador. A fixture fornece conta, itens e posições de teste; não simula o serviço real de contas.

O teste encontrou uma defasagem de aproximadamente 12,8 mm entre cano e apresentação FPP quando o recuo alterava a câmera antes de atualizar a pose da arma. A pose agora acompanha o recuo imediatamente no personagem compartilhado, em todos os modos. Não foi necessário mudar a câmera para uma implementação exclusiva do BR.

Repetição final: 368 verificações aprovadas, incluindo em pé, agachado e deitado, já com a nova AK animada. Relatório detalhado: `work/br-optic-duel.json` e `REVISAO-DUELO-LUNETAS-RECARGA-AK.md`.

## AK e ombros — todos os modos

A AK agora usa o seu carregador original separado em uma peça móvel. A mão esquerda solta e retira o carregador, busca o novo, aproxima e encaixa; a direita aciona o ferrolho antes do retorno à empunhadura. FPP e TPP seguem o mesmo temporizador, sem alterar a duração autoritativa de seis segundos nem as regras de munição. A cópia FPP não recria um carregador estático duplicado.

As superfícies abertas de mangas e antebraços foram fechadas na própria malha, com arredondamento e pequena sobreposição junto ao tronco. Isso remove os buracos vistos na imagem do personagem sem colete. A correção é compartilhada com Guerra e os demais modos de infantaria; não há uma recarga ou um corpo alternativo criado só para o BR.

Validação: 1.101 verificações de recarga/ombros, 2.196 de poses compartilhadas e 490 de origem do tiro, aprovadas. Capturas inspecionadas em `work/ak-reload-*.png`, incluindo encaixe do carregador e personagem com roupa simples.

## Validação do pareamento

| Ensaio | Resultado | Relatório |
|---|---:|---|
| Alocação, limite, reservas, conta, validade e limpeza | 37 verificações aprovadas | `work/br-matchmaking-validation.json` |
| Encaminhador por DTLS e dois processos filhos reais com mapa/navegação | 13 aprovadas | `work/br-broker-network.json` |
| Fila, bots, relógio, saída e rematch | 39 aprovadas | `work/br-queue-lifecycle-validation.json` |
| Entrada por RPC, roster, início, recusa tardia e cancelamento | 21 aprovadas | `work/br-queue-network.json` |
| Ciclo de combate/resultados atualizado | 28 aprovadas | `work/br-round-flow-validation.json` |
| Interface da mochila/espera | 52 aprovadas | `work/br-ui-validation.json` |
| Inventário/ópticas e reinício multiplayer após a nova fila | 54 aprovadas | `work/br-loot-network.json` |
| Duelo gráfico com duas instâncias e posturas | 368 aprovadas | `work/br-optic-duel.json` |
| Recarga/ombros compartilhados | 1.101 aprovadas | `work/ak-reload-shoulders-validation.json` |

O teste de entrada por RPC usa três clientes independentes em conexões reais, cenário plano e relógio controlado. A autenticação de conta é substituída nessa fixture; o teste do encaminhador verifica separadamente assinatura com autoridade exclusiva de QA e prova de posse real da chave, sem acessar contas de produção. O mapa completo offline também passou pela espera real de aproximadamente 30 segundos e iniciou oito participantes/151 loots.

Durante a saída das conexões dos testes de rede, permanecem mensagens nativas de fechamento/handshake de DTLS. Não ocorreram falhas de script/RPC no ensaio final da fila; as mensagens nativas estão preservadas no relatório, sem serem ocultadas. Corrigidos envios de voz a canais já fechados e consultas a transporte inativo durante a saída. Não houve nova série de benchmarks ou afirmação de FPS/latência pela VPN.
