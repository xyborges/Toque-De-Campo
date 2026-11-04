# Decisões — Nova Grama

**Diretriz posterior de 28/10: o jogador cancelou a inclusão da Nova Grama nesta atualização. Não aplicar nem publicar.** A integração normal agora exige uma prévia explícita do editor; configurações antigas salvas não a ativam no jogo normal.

Atualizado em 28/10/2026. Trabalho local; não publicar sem aprovação.

## Restrições e estado

- Godot 4.7.2, Compatibility, Jolt e 60 Hz mantidos; não mudar colisões de terreno ou blindados. A destruição de árvores e postes permanece fora deste trabalho; preservar seus testes e índices.
- O PNG de bioma é pintável e continua sendo a fonte autoral. Visual não deve alterar cobertura, colisão, servidor ou regras; servidor headless não gera vegetação visual.
- A Nova Grama tem agora carregamento visual por células ao redor da câmera no mapa real. Foi integrada localmente às opções Antiga/Baixo/Médio/Alto, com padrão Antiga e retorno dos materiais/instâncias originais. O pacote ainda não está aprovado para publicação: faltam a medição comparativa aceitável, validação completa de movimento e multiplayer.
- Grama próxima escura: normais laterais, cor do material e iluminação noturna contribuem; seus efeitos não foram isolados quantitativamente. Não atribuir toda a causa à iluminação.

## Medições anteriores e decisões

- Inventário de renderização da base ainda é necessário; resultados de 20–25 s e câmera parada estão em `NOVA-GRAMA-LAB.md` e não bastam para o novo critério.
- Material de chão isolado apresentou média aproximadamente neutra, mas 1% low oscilou; os resultados não aprovam nem eliminam o material.
- O pacote de detalhes sofreu até ~10% de queda e a versão combinada caiu até ~7,9% nas séries existentes. Ambos permanecem desligados.
- Agrupamento das células de 20 m para 40 m e máscara alternativa com menos nós não mostraram ganho consistente e foram revertidos. Registros de medições descartadas ou contaminadas permanecem documentados; não repetir essas variantes sem uma hipótese nova.
- O piloto de redução da frequência de movimento de bots não foi integrado: o pico de 1,245 s e riscos para acertos/servidor impedem concluir que é seguro. Interpolação seletiva também não foi integrada.
- O computador mostrou variação grande de clocks e FPS. Comparar somente em blocos intercalados de referência repetida, sem processos de teste concorrentes; registrar indisponibilidade da temperatura da CPU em vez de estimá-la.

## Processo atual

1. Inventariar visíveis e materiais por categoria e medir o ruído A/A com trajeto reproduzível, duração 60–120 s e 5–7 pares; registrar mediana, p99, quadros acima de 33 ms/minuto, pior quadro, CPU/GPU e memória. O trajeto de câmera não substitui validação com jogador e blindados realmente se deslocando.
2. Alterar um componente por série, com captura e validação de biomas. Só adotar caso cumpra o orçamento e não agrave a experiência; descartar ou rever quando não cumprir.
3. Implementar presets visuais e rollback, testar visão térmica, chuva, noite, dois clientes/entrada tardia e headless; preparar notas e pacote. Solicitar aprovação somente ao final para publicar.

## Inventário preliminar

Em um enquadramento fixo com 18 participantes, o motor informou 1.546 chamadas de desenho. Ocultar separadamente grama reduziu 87; terreno, 79; malhas compartilhadas de árvores/vegetação, 616; jogadores, 252; veículos, 8; demais objetos, 422. As malhas de árvores também são reutilizadas por outra vegetação. As categorias não são custos isolados de CPU, nem somáveis: o teste interfere em sombras e descarte por câmera, e outros enquadramentos podem mudar completamente os valores. A visibilidade foi restaurada após cada medição. Investigar a categoria ampla de árvores e vegetação tem prioridade sobre assumir que o terreno seja o principal custo. Resultado bruto em `work/nova-render-inventory.json` (nesse primeiro relatório a categoria ampla foi chamada `trees`).

O trajeto A/A é uma câmera programada, com 18 participantes locais. O mecanismo de teste usa desenho forçado e mede o intervalo entre quadros nesse laço; não representa perfeitamente apresentação na tela nem um jogador atravessando o mapa. É necessário confrontar a medição com o laço normal e movimentação real antes de afirmar que não há travadas no jogo. O plano de energia ativo já era Desempenho; a sessão não tem privilégios de administrador para fixar clocks. As medições não alteram esse plano.

Em `nova-route-aa-20261028-095058`, cinco pares de 120 s foram executados, mas somente dois ficaram válidos após excluir processos externos em pelo menos uma amostra. Mesmo nesses dois, o p99 divergiu até 15,1% e os quadros acima de 33 ms/minuto até 50,6%; o piso de ruído é alto e a série não aprova alterações. A referência já teve piores quadros de 76,5–126,3 ms, inclusive em execuções sem carga externa detectada. Os tempos e a invalidade dos pares estão em `work/nova-route-aa-20261028-095058-summary.md`. A coleta de processos é amostrada e não identifica todas as interferências possíveis. Próxima etapa: comparar com o ciclo normal de renderização e investigar os picos da CPU antes de uma nova série controlada.

Após a referência enviada pelo jogador, a aparência desejada foi esclarecida: campo visualmente coberto por grama volumosa, não tufos isolados. `tests/nova_grass_carpet.gd` e o shader associado são um protótipo local em área de 100 × 100 m: 25 células, 2.500 placas de 2 × 2 m, 64 lâminas por placa e 256 triângulos por placa, antes do descarte de visão/distância; total máximo gerado nessa amostra de 160 mil lâminas e 640 mil triângulos. Não há colisão nem sombras por lâmina. A captura `work/nova-carpet-prototype.png` mostra o efeito, ainda com transição à distância e aparência a refinar. A amostra não mede desempenho e pode esconder jogadores; não atende ainda ao requisito de paridade entre presets. Não integrar, aumentar para o mapa ou publicar sem testes, orçamento e solução de visibilidade. A documentação do Godot 4.7 indica que o fade automático de faixas de visibilidade não funciona no Compatibility; o protótipo experimenta reduzir a altura à distância em shader, a ser validado visualmente e medido.

`tests/nova_grass_stream.gd` é uma primeira implementação de laboratório para carregar e liberar no máximo uma célula por quadro em volta da câmera; ainda não foi executada nem medida. Seu objetivo é limitar o custo ao entorno, sem criar três milhões de placas para a ilha. O teste de desempenho separado `tests/nova_carpet_benchmark.gd` também não foi executado. Não se deve assumir que a ativação por quadro evita picos: é necessário medi-los, bem como cobrir zonas queimadas e limite da cobertura visual no PvP.

## Integração local de 28/10 — prévia jogável

- O jogador confirmou grama baixa e volumosa primeiro. A versão de produção local usa `biome_map.gd`, `grass_assets.gd`, `grass_stream.gd` e `vegetation_visuals.gd`, separados dos protótipos antigos em `tests/`. Mantém somente até 25 células de 20 m, placas de 2 m e 12 candidatos processados por quadro. Lâminas têm 18–28 cm; os presets usam 75/147/243 lâminas por placa e 225/441/729 triângulos, antes do descarte. Não há sombra, colisão ou script por lâmina. Isso é orçamento de geração, não comprovação do orçamento de FPS.
- O chão usa quatro misturas pelo PNG e normais apenas visuais. A seleção de árvores pelo mapa de bioma e novos resíduos queimados ainda não foram entregues. Índices, colisores e modelos de árvores existentes foram preservados.
- As faces traseiras da grama ficavam escuras mesmo com normais de vértice para cima. A normal final de iluminação foi corrigida no fragmento, sem emissão; materiais mutáveis são isolados por mundo. A iluminação noturna e a térmica existentes ainda limitam a leitura em algumas capturas.
- Passaram testes locais de bioma, ciclo de vida, retorno à vegetação antiga, isolamento de material e preferências numéricas por contas fictícias. A checagem gráfica no mapa real manteve os 18 participantes e as 18.883 formas estáticas; restaurou visibilidade das instâncias antigas. Isso não substitui teste multiplayer nem acesso real ao servidor de contas.
- A série natural `nova-natural-aa-20261028-103339` foi encerrada após cinco pares e A6. Não houve trio adjacente inteiramente válido segundo a regra de carga externa, portanto não aprovou desempenho. Foi corrigido um arredondamento no monitor: `Math.Max(0, ...)` selecionava uma sobrecarga inteira; agora usa `0.0`. Valores históricos de carga externa não têm precisão suficiente para interpretar núcleos exatos.
- O novo ensaio `nova_session_benchmark.gd` alterna na mesma instância, resetando a rodada, semente e bots. Uma execução curta apenas verificou o funcionamento da troca; não é evidência de ganho nem atende ao mínimo de duração e repetições.
- A prévia `tests/nova_grass_play.tscn` foi aberta com nível Médio e confirmada visualmente na janela “Nova Grama · Prévia local”. Ela é uma amostra jogável temporária; não altera a versão publicada. Capturas completas anteriores e uma captura rápida da geometria mais recente estão em `work/nova-visual-captures/`.

## Correção do apoio visual dos pés

- O relato de andar nas pontas da grama foi reproduzido sem nenhuma grama: com pernas em 85%, a sola ficava 10,8 cm acima do plano físico; com 65%, cerca de 28,3 cm. A personalização encurtava as pernas mantendo o quadril na mesma altura. O balanço das pernas também alterava o apoio durante a passada.
- `WarStance` agora calcula uma vez o alcance real das botas e solas, ajusta a altura visual do corpo conforme a proporção, mantém pelo menos uma sola apoiada durante a passada em solo e acompanha a altura visual da cabeça com a câmera. Agachar respeita o comprimento das pernas; deitar e nadar mantêm seus movimentos próprios. O ajuste de caminhada não move a câmera a cada passada.
- Arma e mãos são recalculadas no mesmo quadro quando a altura do corpo muda, evitando afastamento momentâneo dos punhos. Isso também usa o ponto de apoio correto da FAL nas posturas baixas. Nenhum corpo físico, máscara, altura de terreno, velocidade ou regra de rede foi alterado.
- `nova_grass_contact.gd`: a versão anterior falhou em 30 verificações de apoio. A versão corrigida passou 288 verificações de proporções, posturas, caminhada, câmera, mãos, mira de ferro e ausência de colisores na grama. `pose189_validation.gd` passou as 2.219 verificações existentes.
- `nova_grass_contact_physics.gd`: 75 verificações passaram com jogador, bot e Guarani/BMP-2/Abrams/T-90. A grama real foi adicionada sob os seis corpos; apoio, altura, deslocamento e normal permaneceram iguais antes/depois. O número de objetos físicos permaneceu em 122. É teste de contato no Jolt, não benchmark, teste de rede ou prova de circulação em todo o mapa.

## Série comparativa na mesma instância

`nova-session-ab-20261028-121234` completou cinco pares de 60 s e a referência A6 final, todos com 18 participantes e textura de 1920 × 1080, usando o laço normal de desenho. Houve aquecimento das duas variantes antes da série. Pela telemetria amostrada, os cinco trios A/B/A ficaram sem carga externa acima do limite; clocks da GPU variaram em média por execução de 768 a 815 MHz, GPU de 62 a 64 °C, CPU estimada de 3.632 a 3.712 MHz. A temperatura da CPU continuou indisponível.

- Contra as referências adjacentes, a mediana dos pares foi +0,6% de FPS mediano para a grama nova; p99 -16,6%; quadros acima de 33 ms/minuto -8,6%. São diferenças observadas nesta série, não uma garantia de ganho.
- O pico de chamadas de desenho foi de 1.975 na referência e 1.868 na variante; a diferença da mediana de memória estática foi aproximadamente +1 MiB. A VRAM global amostrada ficou entre 1.202 e 1.216 MiB em média por execução; inclui outros aplicativos.
- Os próprios A variaram até 4,3% em FPS mediano, 37,9% no p99 e 50,8% nos quadros acima de 33 ms/minuto. O pior quadro foi 99,6 ms na referência e 128,9 ms na variante. Houve quadros acima de 50 ms nas duas condições. Portanto a série **não aprova desempenho**, apesar de não mostrar perda consistente de FPS. Não atribuir isoladamente o pico de 128,9 ms à grama.
- O percurso foi feito por câmera programada e cada trecho medido durou 60 s; ainda não cobre o trajeto físico de dois minutos com jogador/blindado, a rodada completa ou suavidade real sob controle humano. A versão nova permanece opcional e Antiga continua sendo o padrão. Não publicar.

As 48 capturas com a geometria atual passaram em `work/nova-visual-captures/run-2026-10-28T12-10-22/`. A cena reutilizável de grama foi atualizada para as mesmas 147 lâminas/441 triângulos do preset Médio mediante substituição explícita do hash do arquivo gerado; a geração normal continua sem sobrescrever cenas existentes. `VER-NOVA-GRAMA.bat` abre a prévia local sem tempo limite.

## Rede local com entrada tardia

`nova-grass-network-20261028-122725-324218` passou 25 verificações no servidor headless, 35 no primeiro cliente gráfico e 36 no segundo, que entrou depois. Usou a conexão DTLS, implantação, aparências, posições e saída reais do Guerra, com certificados e contas locais de teste. Os dois clientes mantiveram 25 células e 2.500 placas, sem colisores de grama; posições e altura do terreno concordaram com a autoridade. O servidor não criou controlador nem células visuais. Trocar para Antiga e sair liberou o mundo e o grupo de vegetação nos dois clientes.

Houve avisos de buffer UDP cheio durante o teste nos clientes; a convergência funcional passou, mas isso não certifica latência ou ausência de perda durante carregamento. Os avisos precisam permanecer no registro e ser investigados separadamente. O teste não acessou o servidor de produção, não fez partida completa, e não autoriza publicação. A primeira tentativa não iniciou a sessão por erro de tipagem no roteiro de teste, corrigido antes da execução válida.

## Continuação — binóculos, lunetas e correções

Estado local em `REVISAO-LOCAL-OPTICAS-E-MOTOS.md`. Binóculos refeitos, seis motos, noite do Guerra, movimento de navios e proteção da transição de rodada implementados/testados localmente. Lunetas opcionais 4× têm modelos separados inspirados nas duas fotos do jogador e renderizam o mundo na lente. Preferências numéricas seguem o sincronizador por conta existente. Não foi publicado nem alterado o servidor de produção.

O teste multiplayer com servidor headless DTLS e dois clientes gráficos passou 20/18/15 verificações, com entrada tardia, motos, movimento naval e intervalo completo de 60 s. Isso não reproduziu o fechamento nativo relatado. A corrida de snapshots entre operações foi reproduzida/corrigida, sem alegar que todo crash tenha sido resolvido.

O teste de custo da lente foi invalidado porque a janela congelada ainda recebia mouse; não citar esses FPS. Foi corrigido somente o roteiro de medição. A prévia interativa `tests/optical_play.gd` mantém a simulação normal. A lente normal atualiza por quadro; 35 verificações gráficas confirmaram mudança de imagem e alinhamento ao olhar para ambos os lados e cima/baixo.

Depois do relato de tiro lateral, uma regressão reproduziu diferenças entre arma real e cópia FPP. A pose óptica passou a ser compartilhada com o cano físico/servidor, sem mera compensação visual de traçante. Marcadores dos modelos importados acompanham suas animações. Passaram 490 verificações, incluindo posturas e origem de disparos aceitos. A prévia interativa foi reaberta com essa correção (`work/optical-interactive-fixed.log`). A nova correção do cano ainda não teve uma segunda sessão WAN/multiplayer completa. Preservar esta limitação.

Afeganistão/Battle Royale e voz são a próxima etapa, com requisitos originais em `docs/AFEGANISTAO-BR-PENDENTE.md` e adições técnicas posteriores a registrar. Godotopus e TwoVoip precisam de comparação em laboratório isolado; nenhum addon de voz está instalado no jogo nem o microfone foi ligado. `work/voice-lab/` tem `.gdignore` para impedir carregamento pelo projeto principal. Godotopus v0.0.2 sem DNN carregou no Windows/Godot 4.7.2 e codificou/decodificou 100 quadros por taxa (16/24 kHz, mono, 20 ms), com DTX e quadros FEC/PLC; DRED indisponível nesse build. Ainda não é teste de microfone, jitter real, exportação release ou chat integrado. O ramo main atual já usa API 4.7; não confundir suas classes novas com a versão v0.0.2 testada.
