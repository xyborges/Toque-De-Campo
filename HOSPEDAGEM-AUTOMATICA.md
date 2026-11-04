> **Configuração anterior.** A partir de 22/10/2026, downloads, contas e partidas usam a VM Ubuntu `192.168.101.24`. Consulte [SERVIDOR-UBUNTU.md](SERVIDOR-UBUNTU.md) para a configuração atual. Não use os endereços/portas antigos abaixo para jogar.

# Hospedagem automática — Naval 1.1.2

## Para jogar

**Quem cria:** abra o aplicativo atualizado → Modo Naval → **Criar sala neste PC** → preencha e confirme **Criar**. A hospedagem inicia pelo próprio jogo. Não abra HOSPEDAR-NAVAL.bat para esse fluxo.

**Quem entra:** abra **Jogar/Procurar salas** no Modo Naval e clique em **Entrar** na sala desejada. Conectar manualmente ao servidor agora abre a lista de salas; isso não é confundido com ter entrado numa sala. A entrada só é confirmada após a resposta autoritativa com os participantes.

**Por convite:** quem já está no lobby clica em **Copiar convite completo**. O amigo abre **Entrar por código**, cola o convite `IP:porta#código` e informa a senha, se privada. Assim o jogo conecta ao servidor correto, mesmo se o usuário estiver conectado a outro. Um código de 32 caracteres sem endereço também é procurado na rede local, incluindo uma consulta exata para salas privadas; códigos em maiúsculas são aceitos. Se a descoberta estiver bloqueada, use o convite completo.

**No lobby:** aparece **Conectado à sala**, nome da sala, quantidade e nomes dos jogadores, identificação de você e do dono. Apenas o dono vê **Iniciar partida**; o botão fica desativado até pelo menos duas pessoas entrarem. O servidor também rejeita iniciar com um jogador.

Fechem o jogo e abram o atualizador para receber a versão nova. Todos devem usar a mesma versão: o protocolo naval agora é 2. O endereço antigo com porta implícita fixa não é o único fluxo disponível.

## Como funciona

- A própria biblioteca ENet solicita ao sistema operacional uma porta UDP livre (`create_server(0)`). A porta é obtida do socket que já foi vinculado, evitando a corrida de procurar/liberar uma porta antes de iniciar.
- Um processo independente do mesmo jogo funciona como servidor autoritativo. O anfitrião também entra como cliente; não existem regras de dano/munição diferentes para ele.
- A inicialização só é confirmada depois de receber um arquivo local com token, PID, porta real e versão do protocolo. Há prazo de inicialização e heartbeat para rejeitar registros antigos.
- O lobby mostra um convite copiável com endereço, porta e código da sala. Se o PC tiver Ethernet e Wi-Fi, o servidor escuta nas interfaces disponíveis e mostra os endereços alternativos.
- A descoberta usa UDP 3013 como canal auxiliar de consulta, e responde com a porta aleatória real do jogo. Os clientes usam sockets de consulta efêmeros. A porta do combate não é fixada em 3012.
- A descoberta pode ser limitada por isolamento de Wi-Fi, Firewall, VPN ou pela porta auxiliar já estar ocupada. A conexão direta IP:porta continua disponível.
- As salas privadas ficam fora da lista pública. O convite completo encaminha para o anfitrião; a senha é validada pelo servidor. A consulta LAN de código privado revela somente a existência daquele código, sem listar nome/senha publicamente.
- Quando o criador sai da sala ou fecha o aplicativo, o processo servidor continua para os demais, transfere o dono e mantém a partida. O PC que hospeda precisa continuar ligado e conectado.
- O servidor automático encerra depois que salas e conexões ficam vazias. Um processo iniciado sem nenhum cliente também tem prazo de limpeza. Abrir somente a frota/loja mantém a conexão enquanto o menu estiver em uso.
- A hospedagem automática usa os mesmos módulos de combate, projéteis, torretas e replicação. As partidas dos outros modos não foram redirecionadas.

## Firewall e alcance

Uma porta UDP livre não significa que o Windows já permita conexões externas. Ao hospedar, o jogo verifica a permissão do **executável atual**. Se necessário, pede autorização do Windows para uma regra de entrada **UDP, limitada a esse executável e à rede local (LocalSubnet)**. O Firewall não é desativado e regras explícitas de bloqueio não são apagadas.

Se o Windows pedir autorização de administrador/rede, o usuário precisa aprovar. Se não aprovar, o jogo informa a pendência. Em Configurações há **Permitir conexões na rede (Windows)** para tentar novamente. Não há como prometer acesso dos amigos sem essa permissão ou se o roteador isolar os dispositivos.

Isto atende à rede local. Não foi implementado encaminhamento automático de portas no roteador, relay na internet ou servidor global de salas. Um IP fixo de hospedagem poderá usar posteriormente a conexão direta; o servidor fixo anterior continua como opção técnica.

## Identidade e frota

A identidade do dispositivo permanece persistente, fora das pastas versionadas do atualizador. As contas, frota e moedas são autoritativas no PC que hospeda; não se tornam uma carteira global entre PCs anfitriões diferentes. A futura hospedagem central pode concentrar essa persistência. Não foram importados saldos não verificados de outros anfitriões.

## Arquivos

- `modes/naval/scripts/hosting.gd`: criação/reuso do processo local, confirmação de início, heartbeat e solicitação da permissão de rede.
- `modes/naval/scripts/discovery.gd`: descoberta UDP com validação de tamanho, protocolo, consulta e expiração; salas privadas omitidas.
- `modes/naval/tools/allow-lan.ps1`: verificação da regra atual e solicitação de autorização do Windows quando necessária.
- `modes/naval/scripts/network.gd`: porta real após bind, leitura/validação de IP:porta e IPv6 entre colchetes.
- `modes/naval/scripts/mode.gd`: novo fluxo de criação/conexão, lista LAN, endereço copiável, mensagens úteis e encerramento do servidor automático.
- `modes/naval/scripts/catalog.gd`: protocolo 2.
- `export_presets.cfg` / `project.godot`: inclusão do auxiliar de rede e preset QA separado. As cenas de QA não são incluídas na publicação normal.
- `distribution/update_server.py`: instruções da página de download atualizadas.

## Correções do lobby em 1.1.2

- Distinção entre conexão ao servidor e entrada confirmada na sala. A conexão comum abre a lista de salas.
- Navegação pendente é encerrada ao receber a confirmação de sala; a intenção de entrada é preservada até confirmação/erro/timeout.
- Botões da lista usam argumentos vinculados explicitamente. Atualizações de descoberta não removem o controle entre pressionar e soltar o mouse; uma assinatura também evita reconstruções idênticas.
- Convites completos resolvem o servidor correto. Códigos simples não são mais enviados cegamente ao servidor atual. Busca, erros de senha, código inválido e timeout possuem feedback e permitem nova tentativa.
- Lobby compacto: participantes e espera primeiro, depois compartilhamento e ações, com interfaces de rede alternativas selecionáveis. A interface local configurada 192.168.101.227 é priorizada quando existe neste PC.
- A lista recebida do servidor anterior é limpa ao trocar de conexão.

## Validação realizada

- **21 verificações de entrada** com dois servidores ENet reais: conexão ao servidor errado, troca via convite, código em maiúsculas, sala privada, senha inválida/correta, tentativa novamente, ausência na lista pública, saída e código inexistente. Sem falhas.
- Dois clientes gráficos separados repetidos no projeto e no executável Windows QA. Os testes clicam os botões reais de conexão, sala descoberta, sair, entrar por código e iniciar. Uma atualização da lista foi forçada entre mouse-down e mouse-up. O convidado confirmou o lobby sem botão de início; o dono confirmou o botão desativado sozinho. Os clientes depois jogaram, e o convidado continuou após o criador encerrar o aplicativo.
- **15 verificações gráficas de regressão** passaram nesta execução, com frota previamente comprada: loja, criação, início com dois, modais e retorno ao escritório. Os testes antigos de lobby (18), física naval (15), combate (86), NPCs/armas brancas (73) e ragdoll (4) também passaram. A saída da regressão gráfica do escritório mantém dois avisos de texturas OpenGL pendentes já existentes.

### Validações anteriores da hospedagem

- **16 verificações de autohost**: criar pelo jogo, processo separado, porta efêmera, descoberta, conexão só com IP, dois navios, movimento/disparo autoritativos, transferência do dono, entrada tardia e encerramento sem clientes.
- **16 verificações gráficas de interface**: cliques reais dentro do runtime, compra, criação automática, início com dois jogadores, modais, saída e volta ao escritório.
- Dois clientes em processos separados e um servidor criado automaticamente, com janelas gráficas. Executado no projeto e no preset **Windows QA**, com o mesmo template nativo de release e os módulos de produção. O criador encerrou seu próprio aplicativo; o convidado continuou recebendo estados, tiros e eventos de áudio. Depois da saída final, o servidor encerrou.
- O preset QA possui somente um ponto de entrada de testes, porque o template normal de release ignora `--script`. O controle externo do aplicativo pela ferramenta de computador foi recusado pelas permissões; não foi alegado um teste manual de clique nessa ferramenta.
- Repetidos os testes de rede com atraso/perda, lobby (18), física naval (15), combate de infantaria (86), NPCs/armas brancas (73) e ragdoll (4).
- A verificação do Firewall identificou regras existentes para o executável nativo deste PC e retornou `allowed`, sem alterar essas regras. A confirmação UAC de uma regra nova não foi automatizada.
- Não houve teste a partir de um segundo computador físico ou através da internet. As instâncias locais validam a implementação, mas não provam que o Wi-Fi dos amigos permita tráfego entre dispositivos.

Relatórios: `tests/naval-join-flow-results.json`, `tests/naval-autohost-results.json`, `tests/naval-autohost-host.json`, `tests/naval-autohost-guest.json` e `tests/naval-ui-results.json`. Capturas: `tests/screens/autohost-*.png`.

## Publicação verificada

Versão **1.1.2, build 9**, publicada em `C:/xampp/htdocs/toque-de-campo`. A página respondeu HTTP 200. O atualizador real instalou o build novo pelo Apache e a segunda execução não baixou novamente. O SHA-256 do pacote foi conferido. O executável normal iniciou e encerrou com código 0; a inspeção do PCK confirmou a cena principal normal, a presença do auxiliar de rede e a ausência da cena QA. Os sete cenários do atualizador também passaram.
