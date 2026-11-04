# Correção de lag do Guerra — 29/10/2026

**Atualização:** a etapa mais recente está publicada como **1.10.4/build 78**, com o protocolo 33. A correção adicional de ordenação dos estados, a validação e as medições finais, incluindo os picos restantes e a ausência de ganho gráfico estável, estão em [ATUALIZACAO-1.10.4.md](ATUALIZACAO-1.10.4.md). Este documento conserva os ensaios da otimização de CPU e a publicação intermediária 1.10.3.

Correção aplicada às fontes e **publicada como 1.10.3/build 77 na VM Ubuntu**, às 19h40 de 29/10/2026, horário de São Paulo. A investigação anterior está em [INVESTIGACAO-LAG-GUERRA-2026-10-29.md](INVESTIGACAO-LAG-GUERRA-2026-10-29.md). A publicação e a medição final da autoridade são registradas ao final deste documento.

## Alterações

- Corpo, pernas e postura são finalizados antes da arma e dos braços. O Guerra deixava a postura alterar a altura do corpo depois de resolver os braços e precisava calcular arma e braços novamente. O cálculo duplicado foi removido.
- A arma e as mãos compartilham o resultado da mesma recarga. O cache usa arma, tempo restante e duração exatos: não reduz a frequência da animação nem atrasa uma mudança de equipamento.
- O apoio dos pés calcula diretamente o ponto inferior do mesmo volume, em vez de transformar seus oito cantos a cada consulta. Testes conferem a equivalência numérica em várias fases da caminhada.
- O cálculo dos braços reutiliza a transformação inversa e evita uma escrita redundante de escala.
- Hitboxes continuam com suas formas, camadas e consultas de tiro; foi desativado o monitor de sobreposições, cujos sinais e listas não eram consumidos pelo combate.
- O terreno reutiliza o passo de amostragem de cada célula. As alturas, colisões e invalidação de escavações permanecem no caminho existente.
- O envio das posições dos bots usa o agendador compartilhado. Antes, zerar o acumulador a cada envio perdia a fração de tempo e podia transformar o intervalo nominal de 100 ms em cerca de 117 ms a 60 Hz.

Os **28 bots foram mantidos**. Não foi introduzido LOD de movimento, retirada de colisão distante ou paralelismo sobre a árvore de cenas. A correção reduz trabalho repetido na thread principal; não divide toda a simulação automaticamente entre os oito núcleos da VM.

Arquivos de jogo alterados: `scripts/player.gd`, `modes/war/scripts/player.gd`, `stance.gd`, `human_rig.gd`, `terrain.gd` e `bot_director.gd`. As alterações de diagnóstico e de entrada/placar já presentes no projeto foram preservadas. Não foram sobrescritas cenas de mapa.

## Comparação na VM

Sequência **A1/B1/A2**, sendo A a fonte salva antes da correção e B a corrigida. Mesmo runtime Linux protegido, projeto isolado com cena de teste incorporada, mapa completo, autoridade com um humano parado e **28 bots realmente implantados**. Nenhuma mudança no serviço de produção durante essas rodadas. Cada amostra mede 24 segundos após o preenchimento e aquecimento. Há dois tiros em cada rodada; não representa combate intenso ou 12 humanos.

| Medida | Antes A1 | Corrigido B1 | Antes A2 |
|---|---:|---:|---:|
| Quadro médio | 39,32 ms | **16,68 ms** | 25,46 ms |
| P95 de quadro | 99,88 ms | **20,67 ms** | 64,34 ms |
| Pior quadro | 131,68 ms | **28,46 ms** | 90,37 ms |
| FPS pela média dos intervalos | 25,43 | **59,96** | 39,28 |
| Simulação / tempo real | 23,967 / 24,027 s | **24,000 / 24,016 s** | 24,000 / 24,008 s |
| Atualização inclusiva por personagem | 0,343 ms | **0,244 ms** | 0,340 ms |
| Pose inclusiva por personagem | 0,298 ms | **0,195 ms** | 0,295 ms |
| Bots implantados / falhas de implantação | 28 / 0 | **28 / 0** | 28 / 0 |

A atualização dos personagens ficou aproximadamente **28% mais barata** que ambas as referências; a pose, cerca de **34%**. Os tempos são inclusivos e não devem ser somados. A variação entre A1 e A2 exige cautela ao atribuir um percentual exato ao ganho de FPS. O resultado de B1 comprova melhora nesta amostra curta, não 60 FPS garantidos em qualquer cenário.

O relógio de simulação das referências também acompanhou aproximadamente o tempo real neste fixture: o ensaio isolado não reproduziu toda a desaceleração de 4,4% medida anteriormente no servidor online. Ele reproduziu o custo dos personagens e os picos entre quadros. A medição online após a publicação deve ser usada para avaliar a autoridade real com ENet e clientes.

O runtime Linux suprime as mensagens durante a amostra; o coletor baseado nessa mensagem não coletou CPU por processo nas rodadas A/B/A. Portanto, **não há percentual de CPU inferido desses ensaios**. Os resultados, os timers e os contadores de implantação vieram dos JSONs gravados pela cena de teste.

Evidência: `work/war-lag-vm-comparison.json`, `work/war-lag-vm-{A1,B1,A2}.log`. Os hashes dos pacotes de teste e das fontes estão em `work/war-lag-fix-artifacts.json`.

## Regressões e pacote

- **4.548 verificações** de comparação com a fonte anterior: 216 combinações de armas, postura, inclinação, mira vertical e recarga; posições finais de arma e hitboxes, contato das mãos, consultas de tiros e apoio da sola.
- **2.196** de mira/corpo, **56** de recarga, **1.126** de postura deitada e troca de arma no rig compartilhado do BR, **36** de cadência: total de **7.962 verificações**, sem falhas.
- Autoridade e dois clientes independentes em ENet/DTLS: **15 verificações** sem falhas, 28 bots, implantação, equilíbrio, entrada durante criação, confirmação gradual dos modelos, placar de 30 participantes, movimento e disparos reais. Teste local com mapa de fixture; não é um benchmark da rede física.
- **20 testes** da política de publicação e rollback passaram.
- **13 verificações** de instalação do build 77 assinado passaram, seguidas de boot do cliente protegido e carregamento da DLL de voz.
- **111 verificações** do pacote Linux passaram: 103 recursos de navegação declarados no manifesto preparado, ausência de arquivos de trabalho/teste, chaves privadas e extensão de voz no servidor. O teste foi executado fora da pasta do projeto para evitar misturar recursos soltos com o PCK.

Evidências: `work/war-lag-fix-validation.json`, `work/war-lag-signed-install-77.json`, `work/war-lag-server-pack77.json`, `work/war-lag-release-prepare.log`. O teste antigo do pacote esperava 88 células de navegação; foi atualizado para conferir todos os recursos declarados pelo manifesto atual, preservando a validação de cada recurso.

## Publicação e verificação online

O publicador confirmou `VERIFIED_READY build=77` e `DEPLOYED build=77 version=1.10.3`. A consulta posterior confirmou `/opt/toque-de-campo/releases/build-77`, versão 1.10.3, 28 bots em equipes de 14, um humano, nenhum carregamento pendente e zero reinícios por falha. A ativação usou a verificação de salas vazias, backup e rollback existentes. Não foi necessário alterar os oito processadores da VM.

Uma nova sessão autenticada de 45 segundos, com cliente headless e a autoridade publicada, produziu:

| Medida | Antes, build 74 | Depois, build 77 |
|---|---:|---:|
| CPU da thread principal, % de um núcleo | 98,88% | **82,29%** |
| CPU do processo Guerra, % de um núcleo | 111,07% | **87,54%** |
| Relógio autoritativo / tempo real recebido | 42,80 / 44,750 s | **44,80 / 44,801 s** |
| Ritmo do relógio autoritativo | 95,64% | **100,00%** |
| Intervalo médio / P95 do snapshot geral | 209,11 / 238,75 ms | **200,01 / 203,83 ms** |
| RTT médio / P95 | 65,16 / 88 ms | **25,61 / 28 ms** |
| Quadro do cliente, média / P95 | 16,85 / 24,16 ms | **16,67 / 20,42 ms** |
| Pior quadro do cliente | 156,64 ms | **31,50 ms** |

O ritmo do relógio usa os timestamps autoritativos de snapshots e o intervalo monotônico entre seus recebimentos. Não mede todo tick individual do servidor. O RTT inclui atendimento e agendamento dos dois processos, além do transporte; as sessões aconteceram em horários diferentes e isso não isola a contribuição da rede física ou de uma VPN. A comparação isolada A/B/A complementa essa observação online.

O cliente de diagnóstico usou as fontes atuais e o Godot de desenvolvimento com autenticação normal; não foi o EXE assinado instalado dos jogadores. O pacote assinado teve instalação e boot verificados separadamente. A sessão final headless terminou sem falhas, erros de script ou avisos de buffer cheio. São amostras curtas com um humano e pouco combate; não comprovam capacidade de 12 humanos nem ausência de qualquer pausa em uma sessão longa.

Evidências da autoridade real: `work/war-lag-production-build77-headless.json`, `work/war-lag-live74-build77-headless.json` e `work/war-lag-summary.json`. O prefixo legado `live74` pertence ao nome do coletor; o campo de versão desses relatórios confirma **1.10.3**, e a coleta da VM confirma **build 77**.

Para receber a correção, fechar e abrir novamente o launcher. O build novo usa o protocolo 32 do Guerra; o cliente anterior deve atualizar antes de reconectar.
