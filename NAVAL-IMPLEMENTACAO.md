> **Configuração anterior.** A partir de 22/10/2026, downloads, contas e partidas usam a VM Ubuntu `192.168.101.24`. Consulte [SERVIDOR-UBUNTU.md](SERVIDOR-UBUNTU.md) para a configuração atual. Não use os endereços/portas antigos abaixo para jogar.

# Modo Naval — Godot nativo

Implementado em 22/10/2026. A referência Three.js permanece intacta. O naval antigo do monólito Godot não é mais acessível pelo menu: o botão abre `modes/naval/scenes/NavalMode.tscn`. Escritório/NPCs e PVP deserto continuam nos seus sistemas atuais.

## Como jogar — atualizado para hospedagem automática

1. Abra o aplicativo atualizado, entre em **Modo Naval** e clique em **Criar sala neste PC**.
2. Preencha o nome e confirme **Criar**. O jogo inicia seu servidor em outro processo e pede ao sistema uma porta UDP livre. Não é necessário abrir um BAT.
3. Os amigos abrem **Jogar/Procurar salas** na mesma rede. Também podem colar o endereço **IP:porta** mostrado no lobby. Digitar apenas o IP tenta descobrir a porta automaticamente.
4. Com dois a seis participantes, o dono inicia. Se ele sair, a sala continua para os demais. Depois da última conexão sair, o servidor automático encerra.
5. Se o Windows pedir autorização de rede/administrador, permita para hospedar. Em Configurações há uma opção para tentar novamente. Uma porta livre no computador não contorna o Firewall ou o isolamento do Wi-Fi.

W/S acelera/freia/ré, A/D viram o casco, mouse controla mira, clique dispara, botão direito alterna zoom, R recarrega e 1–4/roda trocam arma. Esc abre o menu sem pausar a partida.

Detalhes do fluxo atual: **HOSPEDAGEM-AUTOMATICA.md**. O servidor de porta fixa continua disponível como opção futura; ele não é necessário para criar salas pelo jogo. As seções seguintes registram também os testes da implementação inicial.

## Arquitetura e arquivos

| Arquivo em `modes/naval/scripts/` | Responsabilidade |
| --- | --- |
| `mode.gd` | Fluxo de menus, lobby, HUD, entrada, efeitos e apresentação dos estados recebidos |
| `network.gd` | SceneMultiplayer próprio, autenticação, salas, comandos e snapshots |
| `match.gd` | Simulação autoritativa a 30 Hz; disparos, impactos, dano, placar e respawn |
| `ship.gd` | Aceleração, inércia, ré, curvas, colisões, vida e interpolação |
| `turret.gd` | Suporte → giro horizontal → elevação → cano → marcador físico de saída |
| `ballistics.gd` | Solução de mira e trajetória compartilhadas entre servidor e guia |
| `camera.gd` | Terceira pessoa estável, mouse independente e zoom |
| `catalog.gd` | Atributos, limites, armas, ilhas e ondulação determinística |
| `geometry.gd` | Cinco modelos procedurais, canos e colisores de casco/cabine |
| `world.gd` | Mar, ilhas, iluminação, rastros, efeitos limitados e sons espaciais |
| `storage.gd` | Identidade persistente, contas e gravação atômica |

`scripts/main.gd` recebeu apenas o roteamento e as proteções de entrada necessários para entrar/sair do novo modo e executar o servidor dedicado. `GameUIFocus` existente é reutilizado para impedir cliques e comandos atravessando modais.

## Simulação e rede

- Cada sala possui UUID, UUID de partida e um `SubViewport` com mundo físico próprio no servidor. Navios, disparos e colisões de salas diferentes não se encontram.
- O cliente envia somente comandos limitados: aceleração, direção, ponto de mira, arma e gatilho. Posição, munição, cadência, recarga, colisão, dano e recompensa são calculados pelo servidor.
- Autenticação por desafio assinado com chave RSA persistente do dispositivo. IP não identifica o jogador. O mesmo perfil simultâneo é rejeitado; para testes no mesmo PC use `--naval-data=PASTA-DIFERENTE`.
- Estados explícitos WAITING/STARTING/IN_PROGRESS/FINISHED/CLOSING. Entrada tardia recebe o estado completo. A saída do dono transfere a propriedade, e apenas a sala vazia é removida.
- Snapshots a 10 Hz, interpolação visual e extrapolação limitada a 120 ms. Eventos críticos são confiáveis e identificados. Snapshots comprimidos são divididos em blocos de até 900 bytes; montagens incompletas/antigas são descartadas e a seguinte substitui o estado.
- O relay entre clientes foi desabilitado: toda comunicação de jogo passa pelo servidor. O envio verifica estado/canais do peer para não tentar enviar durante desconexão.
- Cancelamento de gatilho usa sequência confiável para impedir que um comando antigo atrasado volte a ativá-lo. Ausência de comandos por 400 ms também corta gatilho/aceleração/direção.

## Torretas, disparos e linha

Todas as montagens calculam individualmente uma solução para o ponto de mira. A direção global é convertida pela base completa do casco para giro/elevação locais. O giro respeita velocidade e limites de cada suporte. Um raio físico bloqueia disparos que atravessariam a própria superestrutura.

O projétil nasce no `Marker3D` do cano/um tubo visível e segue a orientação real desse marcador. A velocidade inicial soma **X e Z do movimento do navio**, além da velocidade da arma. Não existe impulso artificial para cima. A solução balística compensa a queda quando há alcance e elevação disponíveis.

A linha e a simulação chamam **as mesmas funções de posição e varredura de colisão**, com gravidade, velocidade herdada, tempo de voo, alcance, vida, superfície da água e exclusão do casco de origem. A linha segue a orientação efetiva do cano enquanto a torreta ainda gira: não finge já estar alinhada ao alvo. Obstáculos/outros navios podem interrompê-la antes do mar.

A previsão usa o estado atualmente apresentado no cliente; latência e o movimento futuro de um alvo não são conhecidos antecipadamente. Ela não é uma promessa de acerto em um alvo que se mover depois do disparo.

Mísseis possuem modelo, rastro e impacto; torpedos acompanham a superfície, têm corpo próprio, marca superficial e esteira visível. Tiros são únicos por ID; um impacto impede que snapshots atrasados recriem a mesma munição. Os sons são disparados por evento de projétil, com atenuação 3D e polifonia limitada. Fontes dos jogadores que saem são liberadas.

## Embarcações e combate

| Classe | HP | Velocidade | Preço | Armamentos |
| --- | ---: | ---: | ---: | --- |
| Patrulheiro | 100 | 28 m/s | Grátis | Leve |
| Corveta | 160 | 22 m/s | 1.200 | Leve, pesada, míssil |
| Destróier | 240 | 16 m/s | 2.600 | Todos |
| Assalto | 320 | 12 m/s | 3.900 | Todos |
| Submarino | 210 | 18 m/s | 5.200 | Todos |

Os modelos possuem dimensões e montagens próprias, cabine e casco colidíveis. O submarino tem casco arredondado, vela, periscópios, planos de mergulho, leme e hélice. Nesta versão ele navega **na superfície**; não existe mergulho ou guiagem automática.

| Arma | Dano | Intervalo | Munição | Recarga |
| --- | ---: | ---: | ---: | ---: |
| Leve | 4 | 0,105 s | 600 | 3 s |
| Pesada | 9 | 0,34 s | 240 | 5 s |
| Míssil | 55 | 10 s | 6 | 10 s |
| Torpedo | 70 | 8 s | 8 | 8 s |

Dano confirmado uma vez por impacto. Destruição desativa controles/colisão, registra abate/morte e recompensa, apresenta afundamento e renasce após cinco segundos com estado completo. Spawn procura posições livres de ilhas e afastadas pelo menos 160 m dos vivos.

A integridade geral está funcional. Os campos de motor/direção/torretas estão preparados, mas **falhas localizadas de componentes não estão habilitadas**, conforme a etapa inicial permitida pela especificação. Recarregar repõe o carregador; não há estoque de reserva finito neste naval.

## Economia e persistência

Cada identidade nova começa com **30.000 moedas navais** e patrulheiro gratuito. Cada abate concede 100. Preço, saldo, propriedade e transação são validados no servidor; repetir a mesma compra não cobra novamente. Seleção é permitida no lobby e reaparece ao reconectar.

A carteira naval é autoritativa e separada do saldo local antigo de infantaria. Não foi importado um saldo editável do cliente para compras online. Os preços/campos ficam em `catalog.gd` e a conta em `accounts/<identidade>.json` no diretório do servidor.

`HOSPEDAR-NAVAL.bat` usa `user_data/naval-server`. Clientes usam a pasta de usuário do Godot ou o fallback gravável documentado pelo aplicativo. Na instalação portátil do atualizador, o fallback é `ToqueDeCampo-data/profiles/naval`, fora das pastas versionadas de executáveis, para preservar a identidade entre atualizações. Guarde a chave `device-private.pem` do cliente e a pasta `accounts` do servidor: apagar a identidade local cria outro perfil. Não existe recuperação por e-mail ou conta em nuvem.

## Testes realmente executados

- Lobby: **18 verificações** — identidades separadas, salas isoladas, permissões, compra idempotente, persistência, senha, transferência do dono e limpeza.
- Física: **15 verificações** — aceleração, arrasto, ré, curvas, compensação de rotação, saída pelo cano, velocidade X/Z, colisões com ilhas/navios e solução balística.
- Arsenal: **100 verificações** — cinco classes, cabine do destróier de 240 HP, quatro armas, quatro orientações, movimento herdado, previsão versus impacto, vazio/recarga, interrupção e câmera.
- Interface naval: **16 verificações** com janela gráfica e cliques — configurações, compra, cancelamento, criação de sala, início com dois jogadores, HUD, modais e troca de modo. Na reexecução com perfil já comprado, o caminho de persistência substitui as duas verificações de primeira compra.
- **Servidor e dois clientes em três processos**, incluindo execução com duas janelas gráficas: disparo/dano/morte/respawn, placar único, saída do dono sem encerrar partida, entrada tardia e reconexão sem navio fantasma. Transporte com 20–65 ms de atraso por direção e 5% de descarte simulado.
- **Servidor e seis clientes em sete processos locais**: cinco classes navegando, seis navios replicados para cada cliente e eventos dos quatro tipos de disparo. É um teste curto local; não mede capacidade de produção ou internet real.
- Regressões de infantaria: **86 verificações de combate**, **73 de armas brancas/NPCs**, **4 de estabilidade de ragdoll**, dois processos de combate corpo a corpo e três processos PVP com atraso/perda. Áudio de morte coincidiu nos clientes. Mais **13 verificações** gráficas do sistema de foco/compras existente passaram.
- Inspeção de capturas reais: menu, loja, frota de cinco modelos, câmera, zoom e duas perspectivas online, em `tests/screens/naval-*.png`.

- Executável exportado: dois clientes autenticaram, criaram/iniciaram sala e receberam movimento/disparos do servidor da versão distribuída. A navegação percorreu aproximadamente 23 m no cenário automatizado; foram consumidos 33 disparos.
- Atualizador XAMPP: **sete cenários** — instalação, sem repetição de download, funcionamento com versão já instalada sem servidor, assinatura inválida, pacote corrompido, atualização e rejeição de downgrade. Repetição adicional contra o Apache real instalou 1.1.0 e depois confirmou nenhum novo download. O ZIP publicado teve SHA-256 conferido.

Relatórios JSON e scripts reproduzíveis estão em `tests/naval*` e `tests/run_naval*`. Logs ficam em `work`.

O ambiente gráfico deste teste informa falta de permissão para cache de shaders em `user://`. Alguns encerramentos gráficos do projeto também apontam duas texturas pendentes no driver; os testes funcionais passam, mas esse diagnóstico de encerramento permanece registrado. Não foi constatada queda do jogo nesses testes.

## Publicação e limites

`distribution/publish.py` exporta o jogo, gera pacote com SHA-256 e manifesto assinado e publica a variante XAMPP do atualizador. A configuração `distribution/deploy-config.json` copia apenas arquivos públicos para `C:/xampp/htdocs/toque-de-campo`, com ZIP antes do manifesto. Chaves privadas, código e perfis não são enviados ao Apache.

O atualizador XAMPP precisa ser baixado uma vez por quem ainda usa o executável antigo configurado para 8088. Depois compara a versão antes de baixar novamente. O Apache precisa estar ativo para distribuir os arquivos; o servidor naval é independente dele.

Ainda não foi validada uma partida com seis computadores físicos ou fora da rede local. Modelos são procedurais, não modelos externos fotorrealistas. Simulação de inundação detalhada, submersão, guiagem e avarias de componentes não foram adicionadas como funcionalidades falsas.

Publicação final: **1.1.0, build 5**, cerca de 39,7 MB. O executável do servidor desta publicação foi validado com dois clientes e o atualizador real instalou o build 5 pelo Apache.

## Correção do atalho de hospedagem

`HOSPEDAR-NAVAL.bat` agora chama `distribution/start-naval-server.ps1`. O script reconhece o servidor deste projeto já ativo, serializa inicializações simultâneas e aguarda a confirmação de bind antes de anunciar sucesso. Uma porta ocupada por outro programa é informada sem encerrar esse programa. Não altera salas em andamento.

Validação: cinco cenários passaram (servidor existente, inicialização limpa, segunda abertura, encerramento e conflito com outro programa), além da execução do próprio BAT. A instância original na UDP 3012 foi preservada. Relatório: `tests/naval-startup-results.json`.
