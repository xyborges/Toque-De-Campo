# 1.10.2 — Multiplayer, Battle Royale e controles

**Publicada em 29/10/2026 — build 74.** Cliente Windows, servidor Linux dedicado, API e site de atualização foram ativados juntos. Atualize pelo launcher ou baixe-o em [Toque de Campo](https://192.168.101.24/).

## Verificação da publicação

- Instalação do ZIP assinado: 13 verificações; o executável Windows protegido iniciou sem erros e carregou a DLL Opus incluída no pacote.
- O artefato Linux assinado iniciou uma sala BR isolada, carregando o mapa e a navegação em aproximadamente 8,51 s antes da ativação.
- O helper autenticou os artefatos e criou o backup de contas antes de ativar o build. A versão anterior foi preservada para reversão.
- HTTPS verificado pela CA do projeto; manifesto público idêntico ao preparado, launcher e download completo com hashes conferidos. API saudável e histórico de versões presente.
- Naval, PvP, Guerra e broker BR ativos na pasta `build-74`, sem erros nos respectivos logs na consulta inicial após a ativação.
- Evidências: `work/signed-install-validation.json`, `work/br74-linux-preflight.json`, `work/publication1102-verified.json`, `work/activate-publication1102.log`.

O primeiro pacote local foi bloqueado pelo smoke de inicialização por uma leitura de `ui_fade` inexistente ao fechar um painel pela primeira vez. O acesso foi protegido e o pacote final reexportado e verificado. A tentativa anterior não chegou a ser enviada ao servidor.

## Alterações entregues

| Área | Comportamento nesta revisão |
| --- | --- |
| Personagem | Modelo corporal padronizado; controles de proporções removidos. Cores independentes de pele, camisa, calça e botas, salvas na conta. Valores antigos de proporção são normalizados para 1. A troca de conta não herda as cores da anterior. |
| Diagnóstico | Logs automáticos em JSONL no cliente e no servidor, com sessão, horário UTC, peer, versão, entrada, desconexão, rejeição de autenticação/protocolo, preparação e confirmação do BR, timeouts, erros de script e eventos de curativo. O servidor mantém arquivos separados por peer. |
| BR online | O cliente prepara o mapa antes de abrir a conexão da sala. A lista mostra os participantes e a preparação; o servidor exige confirmação de prontidão do grupo. Reservas emitidas durante o pareamento têm uma janela de preparação limitada. Erros e desconexões mantêm uma tela com saída disponível. Um cliente desconectado não passa a simular uma partida como autoridade offline. |
| Rede | Cache seguro de peers elimina consultas a peers já removidos. A carga inicial do Guerra é distribuída em pequenos grupos; posições substituíveis aguardam essa carga. O placar completo é enviado uma vez por entrada, em vez de uma vez por personagem. |
| Bots online | 28 bots de autoridade no Guerra e no BR, além de até 12 humanos. Movimento, combate e inventário usam a autoridade existente. No Guerra, distribuem-se pelos cinco objetivos, dão rajadas, procuram posições de cobertura e preservam as verificações de aliados/veículos. No BR, seguem navegação preparada, procuram recursos, equipam itens, combatem e priorizam a zona. Procurar um item através de uma parede não faz o bot abandonar imediatamente a rota pela porta. |
| Custo dos bots | Decisões escalonadas, cache de rotas e orçamento global para consultas de cobertura. A apresentação dos personagens remotos do BR usa intervalos por distância; movimento, tiros e dano continuam na física normal. Corrigida a execução duplicada do controlador de locomoção no Guerra. |
| Objetivos do Guerra | A, B e C passam a aproximadamente (-625,-610), (-125,165) e (795,615), separados por cerca de 922 m, 1.024 m e 1.875 m. Os portos continuam como objetivos D/E. |
| Afegão | 101 construções distribuídas por 15 núcleos, com propriedades e vegetação contextual; mais detalhes curtos em células, recursos compartilhados e LOD. Neblina de profundidade, céu, cores quentes e iluminação noturna revisados. Malhas estáticas e material do chão foram preparados novamente. |
| Apoio no terreno | Varais, caixas, lenha, feno e poços verificam a área da base. Uma peça rígida não é colocada em um apoio desnivelado demais. Os pontos de loot das caixas usam a mesma transformação e a mesma rejeição de posicionamento. |
| Nascimentos do BR | Permanecem em posições navegáveis e separadas, com preferência por áreas a até 120 m de locais de loot preparados, evitando privilegiar cantos vazios do mapa. Não foi criado loot aleatório em plantações. |
| Motos | 13 motos no mapa atual, próximas de casas e estradas. Reutilizam condução, colisões e assento existentes, com som espacial e rotação do motor variando com aceleração/velocidade. Estado de rede compacto, controle vinculado à ocupação atual, saída com verificação de espaço e liberação ao morrer/desconectar. O volume respeita a categoria Veículos. |
| Curativo | Aplicação de 4 s, independente da mochila. O personagem mantém a posição e pode olhar ao redor. Depois, recupera até 50 HP em parcelas de 2 HP a cada 0,4 s, limitadas a 100 HP. Dano/mudança de vida interrompem a aplicação; dano novo interrompe a recuperação restante. Há temporizador e retorno visível com a mochila fechada. Um pedido atrasado/rejeitado de tiro não cancela o curativo. |
| Locomoção e passos | O BR usa o balanço da arma do controlador compartilhado do Guerra. A câmera de mira continua estável; a animação é aplicada à arma e às mãos. Passos usam contato real com o chão, superfície e reprodução 3D; os próprios passos receberam +4 dB. Ctrl alterna agachar/levantar por clique; Z continua alternando deitar. |
| Mochila e armas iguais | Duas AKs, por exemplo, ocupam slots independentes, com carregadores e acessórios próprios. Munição solta permanece compartilhada por calibre, sem duplicação ao recarregar. Largar/recolher preserva a configuração da arma escolhida. Modelo, animação, traçante e sensibilidade usam o tipo real da arma. |
| Binóculos e precisão | Binóculos são loot utilizável, também acessível pelo slot 4 quando possuído. Não disparam nem criam projéteis. Sniper e munição de precisão permanecem nas tabelas de loot. |
| VoIP | X fica reservado à voz; T permanece para térmica. O mesmo transporte seguro com canal não confiável é usado nos modos online. Alcance padrão máximo de 24 m, voz próxima em 6 m, posição 3D, seleção de dispositivo, volume, silenciamento e teste de microfone. Bots não aparecem na lista de voz. Morte, saída e troca de sala limpam captura/reprodução/estado da sessão. |
| Interface | Entrada de painéis em 0,16 s, saída em 0,10 s e transição de cenário em 0,22 s. Reabertura cancela a animação anterior e restaura o processamento. O bloqueio de entrada é liberado ao fechar, sem esperar o fim visual. |

Os protocolos locais passam a BR 8, Guerra 31, implantação 12 e Naval 9. Cliente, servidor e API de aparência precisam ser publicados juntos quando houver autorização; esta alteração ainda não está no executável instalado dos amigos.

## Como coletar os logs

Em **Configurações → Exportar diagnóstico**, o jogo cria um ZIP e abre sua localização. Enviar esse ZIP é a forma preferida; copiar o executável não traz os registros da sessão do jogador.

Os arquivos ficam em `diagnostics/` dentro da pasta de dados do jogo. O cliente registra seu peer e a porta ao conectar, permitindo relacionar seu arquivo com o servidor. Em servidores com `--naval-data`, a pasta fica dentro desse diretório; cada sala BR tem seus próprios dados. O identificador da conta é resumido por hash nos eventos de admissão.

A retenção mantém oito sessões, com limites de tamanho e limitação de erros repetidos. Escrita periódica ocorre em uma thread, com descarga imediata solicitada em erros e desconexões. O relatório contém apenas os JSONL sanitizados: não inclui senha, token, prova de dispositivo, chave privada ou gravações de voz. O log nativo do Godot também está habilitado. Um encerramento nativo abrupto ainda pode impedir a gravação dos últimos eventos; não se promete um dump completo de todo tipo de crash.

## Validações locais anteriores à publicação

- 29 verificações com um servidor ENet/DTLS e três clientes: entrada do terceiro, barreira de prontidão, 28 bots, bloqueio de entrada tardia, cancelamento ao sair o último humano e curativo iniciado pelo cliente com a mochila fechada. Um tiro com vida antiga não cancela a aplicação.
- Broker com provas de dispositivo assinadas: 13 verificações, dois processos reais de sala carregando o Afegão, salas independentes e rejeição de prova inválida. Autoridade de testes isolada; não usa contas reais nem altera a VM.
- Guerra com servidor e dois clientes: 28 bots implantados, identidades/posições replicadas, distribuição por cinco objetivos, movimento e disparos aceitos. A execução final não apresentou os avisos de fila UDP cheia vistos antes do parcelamento da carga inicial.
- BR no mapa completo: 31 participantes, 28 bots movimentando-se, quatro armados após 45 s e 13 motos. Houve 2.700 ticks de física nesse intervalo. Isso valida o fluxo funcional; não representa benchmark de FPS da GTX 1650 ou capacidade garantida para duas salas na VM.
- Inventário, duas armas iguais, munição, acessórios, binóculos, cura gradual e ZIP sanitizado: 39 verificações, além de 38 ações de inventário.
- Controle real do BR em Compatibility: nove verificações de Ctrl por clique, corrida, balanço da arma e cura após fechar a mochila. Sete passos foram reproduzidos e houve sinal no barramento Passos.
- Motos com dois clientes: 17 verificações de entrada/saída, condução, ocupação contestada, rejeição de controle antigo, troca e desconexão do piloto. A validação física específica também cobriu saída bloqueada e restauração da câmera/cápsula.
- Navegação regenerada: 339 verificações; 645 candidatos conectados, 117 marcadores de interior e 52 de telhado acessíveis. Marcadores não acessíveis ficam fora da geração de loot.
- Aparência na API isolada: 12 verificações de cores, persistência por conta, permissões e proteção contra alterações de carteira/compras.
- Entrada/saída pelo menu real: 35 verificações em Compatibility, incluindo falhas de perfil/ticket, cancelamento e descarte dos roteadores.
- Codec Opus, ciclo de vida, quatro clientes de voz e cache de peers foram verificados nesta revisão. O adaptador naval passou nove verificações de contexto, posição, isolamento entre salas, morte e limpeza.

## Limites observados

O microfone integrado Realtek foi enumerado e recebeu 374.880 quadros no teste do Windows; a amostra teve nível zero. As permissões consultadas estavam em Allow. Isso comprova o caminho de captura, mas não que a fala esteja chegando com inteligibilidade. O teste da interface agora conserva a mensagem de ausência de sinal e oferece acesso às permissões. Nenhuma gravação foi guardada ou transmitida.

A fixture que encerra três conexões DTLS ainda emite mensagens nativas mbedTLS -30464 no teardown, após as verificações passarem. Capturas que desmontam o mapa também registram avisos nativos de dois recursos/duas formas Jolt na saída. Não houve erro de script na importação final. Esses resultados não são descritos como logs nativos inteiramente limpos, nem provam a causa exata da desconexão histórica do amigo; os novos registros permitem correlacionar a próxima ocorrência.

A medição curta do servidor local manteve a cadência de física, mas apresentou picos no monitor. O contador TIME_PHYSICS_PROCESS da engine registra o máximo da janela, não uma média por tick; os tempos de script foram medidos separadamente. Não foi feita uma nova campanha A/B de FPS nem teste de carga da VM nesta entrega. [Implementação do monitor no Godot 4.7](https://github.com/godotengine/godot/blob/4.7/main/main.cpp#L4757).
