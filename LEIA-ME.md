# Toque de Campo — instância Godot

Esta é uma instância separada do jogo, portada para Godot 4. A versão Three.js consultada continua intacta em `../campo-cartunesco-online`.

## Versão atual: 1.5.0 (build 20)

Download: **http://192.168.101.24/**. Contas, salas navais e PvP ficam na VM Ubuntu; o fluxo normal não pede IP ou porta. Consulte [SERVIDOR-UBUNTU.md](SERVIDOR-UBUNTU.md) para jogar, publicar e administrar. O atualizador antigo precisa ser substituído uma vez pelo novo download.

A versão 1.4.0 padroniza menu, salas e HUD com a paleta do login, referências reais do BF2042 e fotografias nos cartões. Detalhes, referências, arquivos e testes: [INTERFACE-VISUAL.md](INTERFACE-VISUAL.md). O login e suas músicas continuam descritos em [LOGIN-INTERFACE.md](LOGIN-INTERFACE.md).

A 1.4.1 corrige o destino de Ver embarcações, mantém as músicas até o fim ao entrar/sair da conta e corrige o gatilho na troca de armas navais e a ordenação das mensagens de parar fogo. Detalhes em [CORRECOES-1.4.1.md](CORRECOES-1.4.1.md). Levantamento dos mapas para extended look: [MAPAS-ESTADO-ATUAL.md](MAPAS-ESTADO-ATUAL.md).

A **1.5.0** reformula os três mapas: complexo industrial com quatro salas, deserto físico de 300 × 300 m e arquipélago com cinco instalações distintas. Adiciona colisão volumétrica da câmera e corrige avatares recriados por snapshots atrasados. Descrição atual em [MAPAS-ESTADO-ATUAL.md](MAPAS-ESTADO-ATUAL.md), imagens em [EXTENDED-LOOK-COMPARACAO.html](EXTENDED-LOOK-COMPARACAO.html) e arquivos/testes em [EXTENDED-LOOK.md](EXTENDED-LOOK.md). O relatório histórico abaixo descreve etapas anteriores; o acesso online atual é o servidor central acima.

O build 20 acrescenta as novidades da versão à página de download e ao instalador. A lista vem de `distribution/release-notes.json` e integra o manifesto assinado. O instalador mantém o painel aberto após atualizar; clique em **Jogar** para iniciar. Para obter essa interface, baixe o novo instalador no site uma vez; atualizadores antigos continuam recebendo o jogo.

## Abrir

1. Abra `JOGAR.bat` para iniciar o jogo ou `ABRIR-EDITOR.bat` para editar o projeto.
2. O editor Godot 4.7.2 está em `C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2`.
3. Os lançadores gravam o log ao lado do projeto para evitar depender da pasta de logs do perfil do usuário.
4. Se mover a pasta para outro computador, instale Godot 4.3 ou mais recente e importe `project.godot`.

## Validação atual — 23/10/2026

- Menu e interfaces da 1.4.0: 40 verificações. Na 1.4.1: login 44; regressões de combate/NPCs/ragdoll/lobby/física naval 196; playlist 16; integração de música 5; navegação/logout 6; armas navais 19. Sem falhas nessas baterias.
- Dois clientes gráficos no naval e no PVP Deserto, conectados à VM Ubuntu real; tiros e áudio naval recebidos e permanência da sala após saída do dono verificada.
- Atualizador real da VM instalou 1.4.1; a segunda execução não baixou novamente. O pacote inclui tema, fotografias, créditos, cinco músicas de login e a música original do menu; cena de QA ausente. Evidência em `tests/ubuntu-distribution-results.json`.
- Capturas e limites de validação: [INTERFACE-VISUAL.md](INTERFACE-VISUAL.md).

## Histórico da validação inicial

- A instalação portátil de Godot 4.7.2 foi iniciada e os recursos de áudio foram importados pelo editor.
- Verificação headless de importação e inicialização executada após as alterações; os scripts carregaram sem erros de sintaxe.
- A cena abriu em modo gráfico usando OpenGL 3.3. Conferi menu, treino no escritório e PvP local no deserto, em TPP e FPP.
- Corrigi a posição inicial do PvP para afastá-la do posto, escureci a luz do deserto, adicionei objetos redondos e detalhes de escritório e redesenhei o avatar em blocos com articulações animáveis.
- A arma agora é filha do encaixe da mão direita, e o ponto de disparo usa o cano desse modelo. O HUD exibe placar, munição, vida e barra de saúde com fundo contrastante.
- Os NPCs não exibem armas e usam desvio local para passar por mesas e coberturas; observei-os contornando o mobiliário no treino. Ainda não fiz um teste prolongado para medir todos os casos de navegação.
- **Limitações visuais restantes:** cenário e avatar continuam procedurais; o modelo de FAL usa uma silhueta de fuzil de madeira CC0 e não representa com precisão um FAL específico. A apresentação ainda precisa de polimento.
- A sessão LAN não foi testada com um segundo cliente. O log gráfico não mostrou erros de script; continua aparecendo o aviso não fatal de cache de shaders em `user://`.
- Para validar localmente, abra `JOGAR.bat`; confira `godot.log` se algo não carregar. O editor fica disponível em `ABRIR-EDITOR.bat`.

## Modos e mecânicas incluídos

- Treino offline no escritório procedural, com NPCs, dano por regiões e reaparecimento.
- PvP offline no deserto e PvP por ENet na rede local, com host para até seis jogadores e partidas isoladas por processo/sala.
- Modo naval em mapa de mar aberto, com cinco cascos selecionáveis (patrulheiro leve, corveta, destróier, navio de assalto e submarino), classes de armas permitidas por casco, projéteis com queda, guia de trajetória, vida proporcional ao barco e replicação de barcos/disparos na LAN.
- Avatares cartunescos blocados construídos com peças 3D e juntas animadas, alternância FPP/TPP em `V`, mira/zoom, recuo, agachamento e pulo. A arma fica presa ao encaixe da mão; a visibilidade em TPP varia com o ângulo da câmera.
- Vassoura, rodo, machado, Glock, FAL e sniper. Glock: 12; FAL: 30; sniper: 5. Projéteis têm velocidade e gravidade configuradas por arma.
- Dano fatal na cabeça, dano reduzido em braços/pernas, vida de 100, feedback de dano, morte, respawn, ragdoll simples por partes, abates, mortes e moedas salvas localmente.
- Som espacial 3D; arquivos que existiam na versão de referência foram copiados para `audio/`.
- Perfil local com apelido, cor da camiseta, proporções de cabeça/tronco/braços/pernas, moedas, armas compradas, abates e mortes.

## Atualização Godot — câmera, respawn, armas e morte

- A mira recebe movimento do mouse no início do ciclo de entrada, antes de a interface consumir eventos. FPP fica à altura dos olhos e TPP permanece sobre o ombro direito.
- Respawn usa pontos seguros dentro do escritório ou nas bordas do deserto, escolhe o ponto mais distante dos jogadores ativos e zera velocidade, agachamento, recuo e rotação. No online, o servidor confirma o reaparecimento e replica o novo estado.
- Glock, FAL e sniper usam modelos GLB CC0 carregados pelo importador glTF do Godot. A orientação de cano do pacote foi convertida ao eixo -Z do jogo; cada modelo recebe um marcador de boca para a origem do projétil. A licença e a fonte estão em `assets/weapons/LICENSE.md`.
- Na morte, o avatar é substituído por um ragdoll de peças articuladas por juntas. Uma peça só se separa se o golpe fatal atingir a cabeça ou aquele membro; o impulso é baixo e os restos somem após 10 segundos. NPCs agora avançam o braço ao atacar.

## Controles

`WASD` mover · mouse olhar · clique esquerdo disparar/atacar · botão direito mirar · `V` FPP/TPP · `1–6` selecionar arma · `R` recarregar · `Ctrl` agachar · `Espaço` pular · `Esc` liberar o cursor.

No naval: selecione o casco antes de entrar · `W/S` acelerar/recuar · `A/D` virar · mouse apontar · clique esquerdo disparar · `Q/E` alternar as armas permitidas para o casco · botão direito alternar zoom 5× · `Esc` liberar o cursor.

Para hospedar, use **Hospedar PvP** ou **Hospedar Naval**; amigos na mesma rede informam o IP do anfitrião e entram pela opção correspondente. A porta UDP `3010` precisa estar liberada no firewall do anfitrião.

## Organização

- `scripts/main.gd`: menus, mapas procedurais, salas ENet, sincronização, projéteis, HUD e modo naval.
- `scripts/player.gd`: movimento, avatar, câmera, armas, hitboxes, recarga e dano.
- `scripts/weapons.gd`: configuração de armas terrestres e navais.
- `scenes/main.tscn`: cena de entrada.
- `audio/`: sons reaproveitados da instância Three.js.

## Limites desta primeira instância

Os mapas e os modelos 3D são recriados proceduralmente para manter o estilo e não dependem de arquivos Three.js. Os cinco cascos e suas regras de armamento estão disponíveis para seleção; compra de cascos com moedas ainda não foi portada. A personalização por imagem, edição detalhada de cada parte com a prévia original, veículos (que continuam desativados conforme a decisão anterior), conjunto completo de gore/sons e a descoberta pública de salas ainda não foram portados. O online usa conexão direta por IP na LAN; não inclui um serviço central de lista pública nem substitui a arquitetura de salas Socket.IO da versão web.



## Atualização de combate — 22/10/2026

Armas físicas e apresentação FPP, mira por clique/duplo clique, reserva e recarga autoritativas, regiões de dano, integridade de membros, ragdoll limitado e pilha de menus foram integrados. A execução e os limites de validação estão detalhados em [COMBATE-IMPLEMENTACAO.md](COMBATE-IMPLEMENTACAO.md). Use [TESTAR-COMBATE.bat](TESTAR-COMBATE.bat) para reproduzir os testes e reabra JOGAR.bat para carregar os scripts novos.

## Executável e atualizações — 22/10/2026

O launcher Windows fica em `distribution/published/ToqueDeCampo.exe`. Ele consulta `http://192.168.101.227:8088`, compara o número da versão, valida assinatura e arquivos e baixa apenas versões novas. Use `HOSPEDAR-ATUALIZACOES.bat` para servir os downloads e `PUBLICAR-ATUALIZACAO.bat` para publicar mudanças. Instruções em [EXECUTAVEL-E-ATUALIZACOES.md](EXECUTAVEL-E-ATUALIZACOES.md).

## Armas brancas e pressão offline

Machado, vassoura e rodo possuem modelos e animações próprios. O dano acompanha a região de impacto da ferramenta durante a janela ativa, com validação do servidor no online. Escritório começa com oito NPCs e cresce até dezesseis; deserto começa com doze e cresce até vinte e quatro, com reposição rápida e navegação ao redor dos obstáculos. Detalhes e testes em [ARMAS-BRANCAS-E-NPCS.md](ARMAS-BRANCAS-E-NPCS.md).
