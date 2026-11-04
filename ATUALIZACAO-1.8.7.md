# Toque de Campo 1.8.7

## Causas e alterações

- **Câmera após morte no APC:** reproduzido com a equipe 2. A câmera do veículo era selecionada por uma transição de assento enquanto o personagem estava morto; a devolução só acontecia se estivesse vivo naquele mesmo frame. O respawn passava a permitir combate, mas o viewport podia continuar na câmera antiga. A nova vida agora seleciona explicitamente a câmera pessoal; o gerenciador também recupera uma câmera de veículo que permaneça ativa sem ocupação.
- **Recarga durante o drone:** o lançamento não cancelava a recarga no servidor, embora o cliente a cancelasse ao receber a identidade. A física do personagem é suspensa enquanto opera o drone, congelando aquele temporizador. Lançamento e saída agora encerram recarga, golpe, gatilho e mira de maneira consistente e reenviam o inventário. Pedidos de recarga rejeitados também confirmam o inventário real. A proteção por revisão de recarga reinicia somente na mudança de vida.
- **Corpo e drone:** proteção de spawn é retirada ao lançar o drone. O corpo mantém hitboxes; tiros e explosões podem atingi-lo. Dano confirmado corta o controle, limpa o assento remoto e inicia queda por gravidade onde o drone realmente está. O estado de queda é replicado. Na colisão, a carga usa o dano em área e as verificações de cobertura existentes. Um drone abatido é destruído imediatamente.
- **TV:** volume físico esférico de 0,38 m de raio, 25 de vida, somente no servidor, reaproveitado por slot do pool. O próprio míssil exclui seu volume. Tiros e explosões verificam contato e encerram o projétil e sua guiagem ao destruí-lo; a interceptação produz efeito pequeno sem detonar a ogiva inteira contra tropas ao redor.
- **Movimento online:** o servidor recebia a posição, validava e aguardava o próximo lote de 50 ms. O Guerra agora encaminha a posição no mesmo tick da validação, removendo essa espera adicional. O lote antigo não duplica essas mensagens. Física, limites de velocidade, colisões e autoridade continuam ativos.
- **Perfil:** uma consulta de perfil que falhe no transporte é repetida uma única vez. Compras, login e recompensas não são repetidos automaticamente. Uma mudança de sessão cancela a repetição.
- **Publicação:** protocolo Guerra 19; o publicador promove os servidores, verifica sua saúde e só então publica o manifesto assinado de download. Rollback conjunto preservado.

## Verificação

- Servidor ENet/DTLS e dois clientes reais, um nativo e um headless: equipe 2 com AK; equipe 1 com FAL. Ciclos de Glock e fuzil, recarga iniciada antes do drone, dano no operador, queda, morte, respawn, disparo no BMP-2, TV interceptado, destruição e novo respawn. O teste verifica a câmera realmente ativa, os disparos aceitos na autoridade e a remoção do míssil nos dois clientes. **40 verificações passaram.** Código: `tests/bugs187_network.gd`.
- **15 verificações** de colisão real do corpo, drone e TV, dano, queda, replicação, interceptação, área de explosão e reaproveitamento do volume físico: `tests/bugs187_air.gd`.
- **5 verificações** de repetição limitada e descarte de sessão antiga: `tests/bugs187_accounts.gd`.
- Regressão de combate/granada: **15 verificações** passaram em `tests/rifles185_state_regression.gd`.
- Duas contas reais por HTTPS com certificado verificado, partida no Ubuntu por DTLS, sem RPC de depuração de dano ou teleporte: `tests/ubuntu_war187.gd`. Testa os fuzis das duas equipes, Glock, drone, morte por granada, respawn, caminhada até o Guarani, disparo e saída. Os relatórios distinguem baseline e servidor atualizado.

## Latência: medições e limites

Na VPN, oito amostras ICMP: **5–10 ms**. Na sessão inicial do Ubuntu, RTT ENet mediano: **24 ms** no cliente nativo e **26 ms** no cliente headless; p95: 36 e 27 ms. Em loopback, mantendo os mesmos dados, cadência e polling, 650 trocas por caso deram 13,792 ms sem criptografia e 13,793 ms com DTLS. A diferença de processamento por troca foi aproximadamente **0,036 ms**. O caso sem criptografia existe somente no benchmark, vinculado a 127.0.0.1; a conexão do jogo continua protegida.

Essas medidas não demonstram que qualquer conexão remota terá o mesmo resultado. O benchmark de transporte não mede renderização, interpolação, outras máquinas ou saturação com 12 jogadores. A retirada da fila de até 50 ms foi uma mudança na aplicação, não uma alteração da criptografia.

O cliente nativo da sessão inicial apresentou mediana de frame de 16,651 ms, p95 de 17,249 ms e um pico de 270,363 ms durante a sequência de morte/retorno. Portanto não se afirma ausência de travadas nem 60 FPS constantes em todas as transições. Consulte os JSONs e logs de QA para os resultados após publicação.

## Publicação e repetição no Ubuntu

**1.8.7 build 58 publicada**, incluindo os três serviços de jogo, API, página de download e manifesto assinado. O atualizador real instalou o pacote e, na segunda execução, confirmou que não havia novo download. Pacote cifrado e bloqueio de overrides externos passaram nas cinco verificações de segurança.

Na repetição com o servidor atualizado, o cliente nativo completou as 13 verificações de login, FAL/Glock, drone, morte por granada, respawn na base, caminhada e uso real do Guarani. RTT mediano: **25 ms**, p95: **27 ms**, máximo: **27 ms**. Frame mediano: **16,661 ms**, p95: **17,344 ms**, pico: **80,461 ms**. A primeira e a segunda passagem podem ter diferenças de cache de shaders; o pico menor não é atribuído isoladamente à alteração de rede. O RTT de rede praticamente igual era esperado: a fila removida era de replicação de movimento, não do ENet.

Os dois clientes usam o jogo e o login reais; apenas o cliente headless permite entrada simulada sem captura de mouse. Nenhuma validação de vida, assento, dano, munição, classe, autenticação ou DTLS é desativada nesses testes no Ubuntu. Resultados completos: `tests/ubuntu-war187-updated-host.json` e `tests/ubuntu-war187-updated-guest.json`.
