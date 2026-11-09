# Gate de rede R2C â€” diagnÃ³stico isolado ENet/DTLS (09/11/2026)

**Branch:** `ia/realismo-r2c-poseframe-resume-20261109`
**MÃ¡quina:** DESKTOP-JJ7U3G3, Godot 4.7.2, cliente observador na GTX 1650.
**Escopo:** servidor dedicado local + cliente mÃ³vel + observador, trÃ¡fego ENet com DTLS e certificados *somente de QA*. Nenhum arquivo de produÃ§Ã£o, `main`, build ou parÃ¢metro persistente do jogo foi alterado.

## DiagnÃ³stico de admissÃ£o

1. O primeiro runner falhava com certificado de produÃ§Ã£o Linux (`/etc/toque-de-campo/game-tls/server.crt`) ausente no Windows. Usar os certificados de QA por opÃ§Ãµes prÃ³prias do editor resolveu o estabelecimento DTLS; a fixture de RPG existente passou **17/17 servidor e 4/4 cliente**, `exit 0`.
2. Na Guerra, a RPC `server_join_request` chegava de fato ao servidor. A rejeiÃ§Ã£o era `MapDefinition.compatible("ukraine", identidade)` = `false`.
3. O manifesto da UcrÃ¢nia, versÃ£o 23, lista **173 fontes** sem arquivos ausentes, mas o `source_hash` registrado (`23301a19fbedb2a7dc22395af169265aa22273fc7751605efa98e8b3ca94a360`) nÃ£o confere com o SHA256 recalculado pelas mesmas fontes (`72d76259c7a9dd1638de037d44ae24b00b1d069900aee5d064822a459d5f192b`). O `content_hash` anunciado era `867b642b6f17f3a69753d095156b597939516611bfaa1169dff24a34fa6eab3e`.
4. **Apenas na fixture temporÃ¡ria de QA**, `MapDefinition.checked["ukraine"] = true` permitiu exercitar o multiplayer sem alterar a validaÃ§Ã£o de produÃ§Ã£o. O ID, versÃ£o e hash enviados pelo cliente continuaram sendo comparados normalmente. NÃ£o considerar isso homologaÃ§Ã£o do mapa.
5. A fixture antiga tambÃ©m precisava aguardar `loading_baselines.is_empty()` antes de implantar ambos, usar **FAL na equipe 0 / G3 na equipe 1** e transmitir `state_sequence` estritamente crescente em `server_player_state`. Sem sequÃªncia, `GameNetworkGuard.movement()` rejeita os pacotes (`sequence < 1`).

## Testes reais com 3 processos apÃ³s corrigir somente a fixture

- **Servidor: 5/5 PASS**. Ambos os clientes conectados e implantados, 4 segundos a 8,4 m/s, distÃ¢ncia autoritativa final **33,60 m**, nenhuma perda dos dois peers no congelamento dos snapshots.
- **Observador: 12/12 PASS** na rodada com velocidade residual de **8,4 m/s injetada explicitamente apÃ³s a interrupÃ§Ã£o dos snapshots**. Observou sprint remoto, peso de sprint 1,0, passada mÃ¡xima 0,6699 rad, **17 contatos/passos**, Ã¡udio 3D ancorado, corpo/arma visÃ­veis, cÃ¢mera estÃ¡vel, **deriva 0,0 m**, nenhuma animaÃ§Ã£o/passo fantasma e pool limitado a **24 vozes**. Isso testa o caso extremo de velocidade antiga mesmo que o runtime normalmente jÃ¡ a tenha zerado.
- **Mover: 0/1 FAIL intermitente na rodada final**: o teste exige estritamente zero correÃ§Ãµes autoritativas; houve pelo menos uma (quantidade e magnitude ainda nÃ£o instrumentadas), embora o servidor tenha aceitado o percurso completo. Na rodada imediatamente anterior, mover **1/1 PASS** e servidor **5/5 PASS**, com 33,46 m. NÃ£o atribuir essa correÃ§Ã£o ao PoseFrame sem medir seu delta, instante e causa.
- Observador grÃ¡fico em `gl_compatibility`: **13 erros de inicializaÃ§Ã£o OpenGL** (`drivers/gles3/shader_gles3.cpp:802`); a rodada nÃ£o qualifica como QA grÃ¡fica limpa. NÃ£o sÃ£o erros de PCM/Ã¡udio. Inspecionar renderizaÃ§Ã£o e cache de shaders em rodada separada.
- Os runners Python temporÃ¡rios terminam com cÃ³digo 0 mesmo quando papÃ©is Godot falham; a aceitaÃ§Ã£o deve usar `work/r2c-v3-enet-summary.json`, conferindo saÃ­da, falhas e erros por papel.

## Artefatos locais (ignorados pelo Git)

- `work/r2c-v3-enet-fixture.gd`, `work/r2c-v3-enet-test.gd` â€” somente QA; jamais lanÃ§ar na build.
- `work/r2c-v3-enet-{server,mover,observer}.stdout.log`
- `work/r2c-v3-enet-{server,mover,observer}.json`
- `work/r2c-v3-enet-summary.json`
- `work/war-locomotion-network-observer.png`, quando gerado.

## Gates ainda abertos

1. Auditar a divergÃªncia dos 173 arquivos-fonte e **regerar/homologar o manifesto pelo pipeline oficial de mapas**, sem desativar `MapDefinition.current()` na produÃ§Ã£o e sem sobrescrever branches/reservas de outras IAs.
2. Instrumentar a quantidade, magnitude e tempo das correÃ§Ãµes de posiÃ§Ã£o do mover com sequÃªncias vÃ¡lidas. Fazer repetiÃ§Ã£o pareada sob carga controlada antes de concluir sobre regressÃ£o.
3. Corrigir/validar os erros GLES3 e realizar observador grÃ¡fico sem erro de inicializaÃ§Ã£o, preferencialmente tambÃ©m em Forward+.
4. Homologar tiros, dano/regiÃµes autoritativas e caso de morte/respawn em uma sessÃ£o de rede completa; separar do teste jÃ¡ aprovado de RPG/DTLS.
5. Fazer benchmark A/A e A/B com 0/12/22/28 bots, 1080p MÃ©dio 100%, GTX 1650, janela em foco e sem outro Godot concorrente.

**DecisÃ£o:** o transporte DTLS, os eventos de movimento/sprint e a reaÃ§Ã£o a velocidade residual estÃ£o comprovados nesta fixture; **gate multiplayer R2C integral continua aberto** pela correÃ§Ã£o intermitente e pelos erros de renderizaÃ§Ã£o/manifesto. PoseFrame permanece somente no piloto local/offline/TPP, **OFF por padrÃ£o**, sem merge em `main`.
