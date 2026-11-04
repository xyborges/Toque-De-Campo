# Inventário modular e corpos saqueáveis

Revisão local de 29/10/2026, Godot 4.7.2. Sem publicação ou alteração do servidor em uso. Complementa `BATTLE-ROYALE-CONCLUSAO.md`, `BR-PAREAMENTO-E-REVISAO.md` e `ACESSORIOS-MODULARES-ARQUITETURA.md`.

## Interface e ações

- Tab/I abre o inventário. Quatro colunas separadas: CHÃO, MOCHILA, ARMAS e EQUIPAMENTO. A mochila é uma lista única por nome, sem seções de munição, acessórios e curativos.
- Clicar num item abre ações contextuais. Curativo oferece Usar/Largar; munição, Recarregar/Largar; acessório, Equipar/Largar. O botão de ação também permanece no rodapé da coluna. Vida cheia e ações incompatíveis desabilitam o uso pertinente.
- Curativo leva três segundos e só é consumido ao terminar. Movimento superior a um metro, dano, troca de arma, recarga, disparo ou morte interrompem a cura. O item não é consumido quando cancelado.
- No chão, o menu oferece Pegar e Usar/Equipar. Com dois espaços ocupados, Trocar arma substitui a arma atual e deixa a anterior no chão com carregador e acessórios preservados. Falha na coleta restaura o inventário anterior.
- As duas posições de arma são genéricas, selecionáveis por 1/2 ou pelo cartão; 3 seleciona os punhos, Backspace larga a arma atual. Continua a regra existente de uma unidade por identificador de arma: FAL+AK, duas classes de arma longa etc. são permitidas, duas AK simultâneas ainda não são representadas pelo inventário.
- Silhuetas foram renderizadas a partir dos seis modelos reais do jogo, com transparência, e carregadas como imagens estáticas. Não existe um viewport por cartão da mochila.
- Cada encaixe mostra o acessório instalado e destaca compatibilidade com o item selecionado. Clicar permite instalar, trocar ou retirar. Instalar tira a instância da lista da mochila; retirar devolve a instância à mochila se houver capacidade.
- Capacete, mochila e colete aparecem na coluna de equipamento; proteção mostra resistência. Tirar uma mochila exige que o conteúdo caiba nos bolsos. Mensagens de falha são curtas e não expõem detalhes de rede.

## Estado, transações e acessórios

`BRInventory` é a fonte de propriedade no servidor. Acessórios soltos têm identificador individual e estado próprio; armas guardam a configuração completa dos módulos. Instalar, remover, trocar, descartar, recolher e morrer conservam estado e munição. Usar acessório diretamente do chão seleciona a instância recém-coletada, mesmo quando já há outro do mesmo modelo na mochila. Arma atual tem prioridade para o uso contextual.

Compatibilidade, montagem por transformação completa, encaixes de módulos filhos, ocupação de trilho, atributos reconstruídos da base e comportamentos extensíveis estão documentados em `ACESSORIOS-MODULARES-ARQUITETURA.md`. A interface consulta esses dados e não enumera apenas lunetas.

O conteúdo jogável desta entrega continua sendo Prismática 4× e PSO 4×. Modelos futuros de lanterna, carregador, supressor etc. precisam de seus recursos e comportamentos próprios antes de entrar no loot. Os módulos adicionais dos testes não entram no jogo público.

Cliente pede a ação; servidor verifica propriedade, distância/linha de visão, capacidade, compatibilidade, vida e geração da rodada. Instalação durante recarga, cura ou disparo é rejeitada. Só a configuração visível é transmitida aos demais; mochila, identificadores dos acessórios soltos e munição permanecem privados. Protocolo BR atualizado conjuntamente para 6 no jogo, roteador e alocador local.

## Corpos

- A morte cria um corpo persistente e um contêiner de loot associado. O corpo continua até a limpeza da rodada, inclusive quando fica vazio ou o dono desconecta. Não há uma segunda mochila visual sobreposta ao cadáver.
- O corpo conserva os equipamentos que realmente sobraram após o dano fatal. Proteção esgotada não deixa uma peça visual sem item correspondente.
- Cada peça original tem um identificador estável. Saquear capacete, colete ou mochila remove somente sua geometria do corpo, nos dois clientes. Equipamento devolvido por uma troca recebe um novo identificador e não restaura a roupa original do cadáver. Eventos antigos não fazem peças reaparecerem.
- O ragdoll movimenta-se inicialmente; após aproximadamente seis segundos, a física congela e as juntas são liberadas. O servidor envia as posições finais e move o ponto de saque para o torso. O corpo permanece visual, sem colisão que bloqueie jogadores e sem simulação física permanente.
- Estado de corpos faz parte do baseline para clientes que ainda estejam recebendo o estado inicial. Isso não reabre admissão de pessoas numa partida BR iniciada.
- Pilhas de munição e curativos de mochilas grandes são divididas nos limites válidos de loot. A coleta parcial preserva o restante; partes legadas inválidas também não são apagadas ao recolher outro item do mesmo contêiner.
- Os modos comuns mantêm o tempo de desaparecimento de seus ragdolls. A persistência por rodada vale para o BR.

## Verificação

| Cenário | Verificações aprovadas | Relatório |
|---|---:|---|
| Interface, menus, encaixes, ações e limites 1280×800/960×640 | 69 | `work/br-inventory-modular-ui-validation.json` |
| Uso real do chão, cura, recarga, substituição com dois espaços, capacidade e estado individual | 38 | `work/br-inventory-actions-validation.json` |
| Acessórios via servidor e dois clientes ENet/DTLS | 82 | `work/br-modular-network.json` |
| Aparência e persistência dos corpos | 12 | `work/br-corpse-appearance-validation.json` |
| Morte real e saque dos corpos via servidor e dois clientes ENet/DTLS | 30 | `work/br-corpse-loot-network.json` |
| Pilhas de corpo: 1.500 cartuchos e 45 curativos, conservação e falhas atômicas | 24 | `work/br-corpse-stack-validation.json` |
| HUD/fila/resultados/foco e pool sem mochila duplicada em cadáver | 41 | `work/br-ui-validation.json` |
| Regressão funcional de combate, postura, equipamento, morte e nova rodada | 60 | `work/br-completion-validation.json` |
| Alocação de salas, limite de entrada e reservas com protocolo atualizado | 37 | `work/br-matchmaking-validation.json` |

Os testes dos corpos incluem remoção seletiva, proteção esgotada no golpe fatal, eventos antigos, posição final, desconexão e limpeza da rodada. Infraestrutura modular: 74 verificações; ópticas gráficas: 54; alinhamento do cano: 490, conforme o relatório específico da arquitetura.

O teste de módulos passou todas as 82 verificações de jogabilidade sem erros de script/RPC, mas registrou duas mensagens nativas mbedTLS -30464 ao encerrar conexões DTLS. Elas constam no relatório; não se afirma que esse encerramento produziu log nativo limpo. O teste separado dos corpos terminou com logs limpos. Testes usam fixtures locais para contas, posições e relógio. Não equivalem a teste em VPN com pessoas, nem a benchmark de FPS. Não foi feita nova bateria de desempenho nesta entrega.

Capturas: `work/br-inventory-use-menu.png`, `work/br-inventory-modular-1280.png` e `work/br-inventory-modular-960.png`.
