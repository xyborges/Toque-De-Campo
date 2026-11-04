# Correções 1.4.1 — menus, músicas e disparos navais

## Loja de embarcações

O menu principal abria a loja antes de terminar a restauração assíncrona da sessão. Ao concluir, `_account_ready()` abria a página inicial naval por cima da loja. O destino agora é passado ao `NavalMode` antes da inicialização e consumido somente após validar a sessão. O mesmo tratamento atende a entrada direta nas configurações. Abrir normalmente o modo naval continua mostrando sua página inicial.

Arquivos: `scripts/main.gd`, `modes/naval/scripts/mode.gd`.

## Música contínua

Entrar ou sair da conta não muda mais a faixa nem a posição de reprodução. Login, menu principal e menus navais usam o mesmo player e a mesma playlist: os cinco MP3 do login e a música original do menu. Cada faixa termina antes da próxima; a lista é embaralhada por ciclo, sem repetição consecutiva na virada de ciclo. As músicas continuam sendo locais e respeitando o volume configurado. O áudio de menu continua sendo interrompido ao entrar no combate.

Antes, retornar ao login durante a música original acionava um fade e a substituição antecipada da faixa. Esse comando de troca foi removido do tratamento de autenticação.

Arquivo: `scripts/ui/menu_music.gd`.

## Troca de armas e disparos navais

- Trocar por número ou rolagem preserva um gatilho que já estava pressionado. A arma selecionada e a intenção de disparar seguem juntas no controle sequenciado enviado à autoridade.
- A soltura do botão é observada em `_input`, antes de um botão ou painel consumir o evento. Isso evita perder a soltura sobre a interface.
- O servidor descarta mensagens antigas de parar fogo, usando a mesma sequência dos controles de movimento/arma. Uma soltura atrasada de um estado anterior não pode cancelar um novo disparo.
- O HUD recebe a espera real de cadência do servidor. Míssil e torpedo, por exemplo, continuam respeitando seus intervalos mesmo ao trocar e voltar à arma; o tempo restante aparece no HUD.
- Sem munição ou durante a recarga, não são criados projéteis nem eventos de tiro. Recarga, bloqueio pelo casco e limites das torretas continuam validados pela autoridade.

Arquivos: `modes/naval/scripts/mode.gd`, `network.gd`, `match.gd`, `ship.gd`, `scripts/ui/naval_hud.gd`.

## Validação

- `tests/naval_menu_fixes.gd`: 6 verificações, conta real na VM, clique em Ver embarcações, manutenção do destino depois da restauração, configurações, entrada normal e logout com música contínua. Executado também com janela gráfica; capturas `tests/screens/menu-fixes-shop.png` e `menu-fixes-login.png`.
- `tests/login_music.gd`: 16 verificações; seis MP3, 120 seleções em vinte ciclos, ausência de repetição adjacente, término/avanço, continuidade de login e logout, música original e liberação do bus.
- `tests/menu_music.gd`: 5 verificações de integração entre menu, combate offline e modo naval.
- `tests/naval_weapon_switch.gd`: 19 verificações com servidor ENet e dois clientes. Trocas entre as quatro armas, gatilho mantido, mensagem antiga de parar fogo, soltura, cadência preservada e replicada, munição vazia, recarga e pausa. Executado com janela gráfica e repetido sem renderização. A bateria controla o relógio de entrada para não depender do foco do desktop; não representa uma medição de latência na internet.
- Regressões existentes: lobby naval 18, física naval 15, combate 86, armas brancas/NPCs 73 e ragdoll 4: 196 verificações sem falhas.

Relatórios em `tests/*-results.json` e logs em `work/`. Durante encerramento de algumas baterias, Godot/OpenGL ainda informa recursos pendentes; os testes funcionais acima passaram. Não foi feito teste prolongado de memória.

### Publicação e conferência final

Publicado no Ubuntu como **1.4.1, build 18**, em http://192.168.101.24/. Cliente Windows, servidor Linux e manifesto assinado foram atualizados juntos.

- Login do executável de QA: 44 verificações com a API real, sem falhas.
- Dois executáveis de QA conectados ao servidor naval real: movimento, disparos, áudio remoto, entrada por código, mínimo de dois jogadores e continuidade após a saída do criador. A primeira execução falhou nas verificações temporizadas de movimento/continuidade; a repetição passou sem alterar os critérios nem o produto. Não foi determinada a causa dessa falha isolada. Os logs da primeira execução foram preservados em `work/fixes-central-naval-test.log`; repetição em `work/fixes-central-naval-repeat.log`.
- Atualizador baixado da VM instalou 1.4.1; a segunda execução não baixou novamente. Hash, assinatura, TLS, proteção dos caminhos privados, presença dos recursos e ausência de QA no pacote de produção foram conferidos. Inicialização do executável de produção passou. Resultado: `tests/ubuntu-distribution-results.json`.

## Mapas

O levantamento do cenário atual está em [MAPAS-ESTADO-ATUAL.md](MAPAS-ESTADO-ATUAL.md), com dimensões, construção, objetos e limitações de cada mapa, mais sugestões identificadas separadamente para o extended look.
