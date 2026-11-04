# Login nativo — versão 1.3.1, build 16

Em 1.4.0/build 17, este login passou a consumir o Theme compartilhado sem mudar sua paleta e playlist. Consulte [INTERFACE-VISUAL.md](INTERFACE-VISUAL.md) para a padronização dos demais menus e HUD.

## Entrega

Nova entrada do aplicativo em Godot, usando o serviço de contas já instalado no Ubuntu. Não há WebView, novo banco, novas tabelas, novas senhas ou servidor paralelo. O arquivo PHP do serviço de contas não foi alterado nesta entrega. O fluxo continua usando `sign_in`, `call_api("profile")`, `logout` e o mesmo arquivo de sessão criptografado.

## Apresentação e navegação

- Formulário à esquerda, cenário militar 3D à direita, gradiente escuro para leitura, tipografia de sistema e destaque verde militar.
- Personagem construído pelo mesmo construtor do avatar do jogo, com pose de apresentação segurando a FAL já existente, colete e capacete. O rig de gameplay não foi alterado. Terreno, trincheira, bunker, árvores queimadas, fumaça e poeira pertencem a um `SubViewport` com mundo próprio; não participam das partidas.
- Cenário renderizado com metade da resolução por eixo, 28 partículas de poeira em um MultiMesh e 12 volumes leves de fumaça. Renderização e animação param quando a tela fica oculta.
- Login e cadastro usam o mesmo painel e cenário; transição de 0,25 segundo e câmera quase estática. Abertura em fade curto. O menu principal recebe outro fade curto após a autenticação.
- O cadastro pede somente usuário, senha e confirmação. E-mail e recuperação de senha não foram oferecidos, pois não existem no serviço atual.
- Olho para mostrar/ocultar senha, foco e texto preservados ao alternar. Tab/Shift+Tab, Enter e Escape funcionam; o fundo não intercepta cliques nem controla a câmera de gameplay.
- Erros locais não limpam a senha. Depois de uma resposta real de autenticação, a senha e a confirmação são apagadas, preservando a política anterior.
- Mensagens e indicador de conexão têm posições fixas. O indicador usa um GET com TLS validado no endpoint de saúde existente; não anuncia disponibilidade sem uma resposta válida.
- Campos e botões ficam bloqueados durante autenticação, verificação e transição. Os botões do menu principal também ficam bloqueados enquanto a conta é desconectada.
- O layout compacto de 800×600 mantém entrada, cadastro e mensagens visíveis; cadastro pode rolar em alturas reduzidas. O foco acompanha a rolagem.

## Integração

Ao abrir o jogo, a sessão salva é validada no servidor. Um perfil em cache, sozinho, não abre o menu. Se a validação falhar, a tela permanece no login com aviso de sessão expirada ou de conexão. Após sucesso, o menu recebe nome, saldo, estatísticas e frota reais. Preferências locais de aparência continuam sendo carregadas pelo sistema existente.

`Manter conectado` utiliza a propriedade `persist_session` já existente. Desmarcada, mantém a sessão apenas em memória. A mesma instância de contas é compartilhada entre o menu e o modo naval, evitando perder a autenticação ao trocar de modo sem salvar a sessão.

A música enviada (`audio/naval-menu.mp3`) foi preservada. Menu principal e naval compartilham o mesmo player, sem reiniciar a música ao concluir o login; o volume configurado continua sendo respeitado. Efeitos discretos de interface são sintetizados localmente, com limite para repetição de hover.

Novas contas continuam com zero moedas e o navio leve gratuito. Saldos e compras anteriores são preservados.

## Cenas e scripts

| Arquivo | Responsabilidade |
|---|---|
| `scenes/ui/LoginScreen.tscn` | Cena reutilizável do formulário |
| `scripts/ui/login_screen.gd` | Layout, estados, validação local, teclado, feedback, sessão e transições |
| `scripts/ui/login_backdrop.gd` | Cenário militar de apresentação e limite de renderização |
| `scripts/ui_focus.gd` | Suporte opcional a painel em tela inteira, mantendo os demais modais |
| `modes/naval/scripts/mode.gd` | Liga o formulário ao serviço existente e aos menus navais |
| `scripts/main.gd` | Login na abertura, perfil real, logout e compartilhamento de conta/música |
| `modes/naval/scripts/accounts.gd` | Acrescenta somente um sinal de diagnóstico de transporte HTTP/TLS para a interface distinguir timeout e falha de conexão; rotas, autenticação, assinatura e salvamento permanecem os mesmos |

## Verificações efetivamente executadas

- **44 verificações na interface do executável Windows exportado**, com eventos reais de teclado e mouse injetados no viewport: digitação, olho, Tab e Shift+Tab, Enter, botão, campos vazios, senha incorreta, cliques repetidos, alternância login/cadastro, confirmação divergente, recusa real do servidor, criação real de conta com zero moedas, sessão persistida, sessão sem persistência, sessão expirada e logout.
- Uma conexão real a uma porta indisponível e uma conexão HTTPS a um fixture TCP que retém a negociação TLS até ocorrer o timeout de oito segundos. Confirmados desbloqueio dos controles e mensagens distintas.
- Layouts e capturas de **800×600, 1280×720 e 1920×1080**. Mensagens permanecem em área fixa; botões alcançáveis por foco/rolagem.
- Aplicação completa: a sessão é verificada antes do menu principal; o perfil é o da conta autenticada; naval e menu compartilham sessão e música; logout reabre o login e bloqueia o menu anterior.
- Fundo parado em aproximadamente **60 FPS**, limitado a 60, na GTX 1650, em um teste curto. A cena deixa de renderizar ao ser ocultada. Isso não mede todos os computadores ou sessões prolongadas.
- **18 verificações HTTPS das contas**, com perfil assinado, prova de dispositivo, preço/saldo manipulados rejeitados, sessão revogada e mesma conta em outro dispositivo/servidor. Os fixtures foram atualizados para o saldo inicial zero; não há concessão de moedas em produção.
- Regressões: 18 de lobby naval, 15 de física naval, 86 de combate, 73 de armas brancas/NPCs e quatro de ragdoll. O teste de compras do lobby usa saldo explicitamente criado no fixture local.
- Dois clientes Windows exportados na VM: autenticação, seleção persistida, sala, início com dois, movimento, tiro, áudio remoto e continuidade após saída do criador. Dois clientes PvP de infantaria também carregaram suas contas e receberam o disparo autoritativo.

Relatórios: `tests/login-ui-results.json`, `tests/naval-accounts-results.json`, `tests/naval-autohost-*.json` e `tests/ubuntu-pvp-*.json`. Capturas em `tests/screens/login-*.png` e `register-desktop.png`.

O pacote 1.3.1/build 16 foi baixado da VM pelo atualizador real: instalação e segunda execução sem download repetido passaram. A inspeção do PCK de produção confirmou os cinco MP3 reproduzíveis e a ausência da cena de QA.

O driver de captura foi ajustado para forçar um frame e usar caminhos absolutos; uma espera por frame de desenho ficava pendente no executável durante a mudança de resolução. O teste de entrada passou após a correção. O driver OpenGL ainda informa duas texturas de atlas pendentes ao encerrar a bateria gráfica; não houve erro de script, falha de autenticação ou interrupção durante os testes. Não foi feito teste prolongado de memória.

## Distribuição

Download em **http://192.168.101.24/**. Quem já usa o atualizador da VM pode fechar o jogo e abri-lo novamente para receber 1.3.1. A VM precisa estar acessível pela rede/VPN.


## Playlist do login — 1.3.1

Foram incluídos, sem transcodificação, os cinco MP3 enviados: `musica2.mp3`, `musica3.mp3`, `musica4.mp3`, `musica5.mp3` e `musica6.mp3`. As cópias tiveram SHA-256 comparado com os originais.

Desde 1.4.1, o controlador `scripts/ui/menu_music.gd` usa uma lista compartilhada entre login e menus: os cinco MP3 do login e a música original do menu, seis faixas por ciclo. A ordem é embaralhada com RNG local, sem repetição imediata na virada de ciclo. Cada faixa termina antes da próxima; há fade curto na entrada e no fim natural.

Autenticar ou deslogar preserva a faixa atual e sua posição. A próxima música só é escolhida ao terminar a atual. A música permanece local, sem sincronização entre jogadores.

Os testes de música em `tests/login_music.gd` passaram em 16 verificações, incluindo seis MP3, 120 seleções em vinte ciclos, ausência de repetição adjacente, avanço pelo término, reprodução avançando, continuidade após login/logout e liberação do bus privado. Os cinco testes de integração musical também passaram. Detalhes em [CORRECOES-1.4.1.md](CORRECOES-1.4.1.md).
