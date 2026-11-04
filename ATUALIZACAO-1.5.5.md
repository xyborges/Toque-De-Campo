# 1.5.5 — Dominação individual e granadas

## Controles e regras

- **G ou 7:** equipa uma granada desarmada, que permanece na mão. Não consome carga e não inicia o pavio.
- **Segurar clique esquerdo:** arma e inicia os **5 segundos**. Soltar lança com o tempo restante. Chegar a zero explode na mão. Morrer ou desconectar solta a mesma granada, com o pavio preservado.
- Lançamento de 18 para **18,9 m/s** (+5%). Guia simples até primeiro contato, sem desenhar os quiques posteriores. A velocidade herdada do jogador, gravidade, quique e cobertura continuam compartilhados e validados no servidor.
- A referência do braço foi corrigida: o modelo cresce no eixo local -Y; a rotação anterior colocava a mão atrás do torso. A pose agora resolve o braço até um ponto diante do corpo, conforme inclinação e rotação do personagem. Modelo, posição de pegada e ponto de lançamento são comuns a FPP, TPP e apresentação remota.

## Deserto: Dominação da casinha

- Cada jogador por si; mínimo de dois participantes, máximo de seis.
- Permanecer sozinho **6 segundos dentro da casa** captura o objetivo. O controlador ganha **1 ponto por segundo** enquanto continuar sozinho no interior.
- Dois adversários no interior contestam: captura e pontuação ficam suspensas. Sair sozinho da casa mantém a indicação de controle, mas não gera pontos.
- Telhado, posições enterradas, jogadores mortos e NPCs não contam como ocupantes.
- Vitória aos **120 pontos** ou maior pontuação após **10 minutos**; empate se os melhores tiverem o mesmo valor. Intervalo de 12 segundos, novas vidas, munição e reinício da rodada. Abates não substituem pontos de controle.
- Saída do controlador remove o controle. Menos de dois participantes pausa o relógio e mostra a espera existente. Não há concessão de moedas enviada pelo cliente a partir da pontuação do objetivo.

## Caixa de munição

- Modelo físico na sala à esquerda do posto, com identificação de munição. Use **E** próximo à caixa.
- Repõe os carregadores e reservas de Glock, FAL e sniper e as duas granadas se estiverem habilitadas no equipamento. Não concede uma arma que a conta não possui e não restaura vida.
- Alcance de interação de 2,6 m, dentro da casa, com verificação física de obstáculo. Parede bloqueia a interação. Intervalo de **20 segundos por jogador**, no servidor.
- Reabastecer cancela a recarga existente. Não é permitido durante preparo armado ou arremesso de granada. A mesma caixa está disponível no treino offline do Deserto, sem iniciar uma partida de Dominação.

## Balística e spawn

- Velocidades iniciais: Glock **157,5**, FAL **273**, sniper **168 m/s**, todas +5% sobre 1.5.4.
- Arrasto linear leve: 0,08/s, 0,06/s e 0,035/s respectivamente. A perda de velocidade e a gravidade são efeitos separados. Integração exata dos dois termos, comum ao cliente e servidor, com coeficientes reaproveitados e cache limitado a 64 entradas.
- Sem impulso vertical de compensação; o vetor inicial segue o disparo existente. Todos os tiros continuam físicos, incluindo os que não exibem traçante. Velocidades e guia do Naval permanecem preservadas.
- O cliente podia enviar a posição provisória antes de receber a posição inicial do servidor. Esse envio foi bloqueado até a confirmação. Movimento inclui a vida atual, impedindo pacotes atrasados de desfazer um respawn.
- Pads consideram a altura sob toda a base da cápsula e checam sobreposição com o cenário. Movimentos abaixo do terreno são corrigidos no servidor; há recuperação local para penetração acidental. A versão do mapa passa a 3, obrigando servidor e cliente a usar as mesmas colisões.

## Validação local

- `tests/combat_155.gd`: **64 verificações aprovadas**, incluindo as três velocidades exatas, arrasto, integração independente do passo, dunas físicas, recuperação abaixo do chão, G desarmado, quatro rotações e três inclinações da granada em FPP/TPP, pavio de cinco segundos, caixa, paredes, captura, contestação, vitória, reinício e pausa.
- `tests/domination_network.gd`: servidor e **dois clientes com renderização no mapa real**, 16 verificações aprovadas. Foram testados estado de vida antigo, posição enterrada, captura em tempo real, HUD sincronizado, reposição e cooldown na autoridade, contestação, troca de controlador e saída do adversário. As posições dos cenários foram controladas pelo fixture; não são clientes humanos.
- Regressões de granada e reconexão: 12 verificações de preparo/pavio compartilhado/morte, mais rodada anterior de disparo e recarga de FAL e sniper após desconexão, sem falhas.
- Regressões de lobby naval (18), física naval (15), combate (86), armas brancas e NPCs (73), ragdoll (4), feedback de combate (12), dano naval (10) e cenários visuais anteriores aprovados.
- Capturas: `work/update-155-grenade-tpp.png`, `work/update-155-domination.png` e `work/update-155-domination-network-*.png`.

## Publicação

**Publicada em 23/10/2026: 1.5.5, build 25**, em http://192.168.101.24/.

- Ativação assinada aprovada com as salas vazias: `work/update-155-deploy.log`.
- Dois clientes autenticados com renderização no PVP da VM, preparo e explosão de granada e corpo remoto: `work/update-155-central-pvp.log`, sem falhas.
- Substituição de sessão e reconexão autenticada, com granada e explosão replicadas: `work/update-155-central-reconnect.log`, sem falhas.
- Dois executáveis nativos no Naval, movimento/disparo/áudio remoto e continuidade após saída do criador: `work/update-155-central-naval.log`, sem falhas.
- Login e menus no executável final de QA: 44 verificações aprovadas em `work/update-155-final-login-native.log`.
- Download real, assinatura, instalação, ausência de novo download na segunda execução, inspeção de recursos e boot público: `work/update-155-distribution.log` e `tests/ubuntu-distribution-results.json`, build 25.

Todos devem atualizar para usar o mesmo protocolo e a mesma revisão do mapa.
