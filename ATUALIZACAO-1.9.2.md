# Toque de Campo 1.9.2 — revisão do Guerra

## Problemas encontrados e alterações

| Área | Causa verificada / comportamento anterior | Alteração |
|---|---|---|
| Disparo sem projétil | Durante a espera por outra equipe, o cliente podia consumir munição prevista e apresentar recoil/som, enquanto a autoridade recusava o tiro antes de confirmar o inventário. | O cliente aplica a mesma condição antes da apresentação; a autoridade confirma também os disparos recusados dessa forma. Aviso de espera no HUD. |
| Troca Deserto → Guerra | Era necessário testar o descarte do estado de granada, gatilho, transporte e ocupação, em vez de supor uma causa. | Teste real no mesmo processo, com dois clientes, passagem pelo APC, FAL, Glock, Stinger e morte/implantação. Não foi necessário remover o DTLS. |
| Stinger | A regra existente exige travar um drone inimigo por 1,25 s; não dispara livremente contra o chão. | Mantida a regra, com enquadramento do alvo e progresso de aquisição. Validado míssil e traçante após o travamento real. |
| Saída do APC | Procurar a altura apenas no terreno colocava a cápsula abaixo de pisos elevados de cais/estradas. | Apoio no piso de colisão real, mais alternativas ao redor, teste de espaço e percurso; sem teleporte através de paredes. |
| Implantação inesperada | Recuperação genérica por altura absoluta não distinguia regiões costeiras válidas e o terreno de cada modo. | O Guerra utiliza sua altura de terreno e recuperação própria. Permanecer vivo no porto não aciona implantação. |
| Câmera do blindado | A posição da óptica acompanhava a translação produzida pela elevação do cano. | Posição ligada à base da torre; orientação continua acompanhando a óptica. Rajada de metralhadora não acumula deslocamento vertical. |
| Mira da torre | Intenção do mouse e orientação atual da arma precisavam de referências distintas. | Losango de intenção imediato e indicação do cano real; velocidade física da torre e origem do disparo preservadas. |
| Ré / pequenos obstáculos | A velocidade comandada podia permanecer alta apesar do bloqueio; recuperação de degrau mantinha velocidade vertical positiva. | Velocidade ajustada ao deslocamento efetivo, frenagem ao inverter o comando e contenção do impulso vertical após degraus. |
| Som próprio | Raios de oclusão podiam considerar o casco ocupado como parede entre a câmera e a própria arma. | Exclusão do próprio casco/ocupantes, mantendo o orçamento existente de verificações e a oclusão por paredes externas. |

## Combate, efeitos e ambiente

- 30 mm: dano à infantaria separado do dano à blindagem. Contato direto normalmente elimina; queda do dano por distância e exposição à explosão continuam validadas na autoridade. Guarani: 150 contra infantaria, 52 contra blindagem, raio 4,3 m. BMP-2: 155 / 55, raio 4,5 m.
- Abrams/T-90: recuo visual do cano de 34 cm, retorno mecânico, reação curta da câmera e novo corpo/grave do disparo. A metralhadora coaxial não acompanha o recuo do canhão.
- Explosões pesadas: fumaça maior e mais duradoura usando o pool existente de 256 efeitos; menos cartões à distância e limite de transparências grandes. Não foram acrescentadas centenas de partículas por explosão.
- Alcance sonoro por categoria: granada 900 m, 30 mm 1.800 m, TV/drone/RPG/míssil 3.200 m e tanque/destruição 4.200 m. Distância, atraso de propagação e oclusão continuam atuando.
- Confirmação de eliminação positiva/negativa somente para o responsável, em áudio 2D; deduplicação de eventos e quatro vozes reutilizadas. Sons reais de morte/impacto permanecem separados.
- Mais tentativas de distribuição de grama, com reforço perto dos portos, respeitando lotes e piso. Instanciamento e distância de exibição de 70 m preservados.
- O clima existente agora também pode escolher chuva diurna; não foi criado um segundo sistema climático. Ciclo de dia/noite de 14 minutos preservado.
- Postes destrutíveis existentes recebem impactos de blindados. A parte inferior continua sólida; construções e grandes rochas continuam bloqueando.

## Estradas dos portos

As vias foram redesenhadas com largura de 12 m, curvas arredondadas, perfil longitudinal contínuo e transição de corte/aterro para o barranco. A estrada oeste contorna silos/cargas; a leste termina alinhada ao portão existente, sem editar a cena de autoria do porto.

Foi necessário corrigir também a colocação dos postes gerados: perto de cruzamentos, apenas empurrar alternadamente o poste para fora de cada rua podia deixá-lo entre duas pistas sobrepostas. A busca agora verifica o conjunto das vias e os lotes.

Guarani, BMP-2, Abrams e T-90 percorreram os dois acessos nos dois sentidos, com todas as colisões reais do mapa. Nenhum cenário final ficou preso, tombou ou recebeu lançamento vertical. A maior inclinação longitudinal medida ficou abaixo de 8%; os números e posições estão em `work/review192-roads-verified.json`.

`modes/war/scenes/east_port.tscn` foi preservado: SHA-256 `69158EBE35AD7A932894EC978ED70663205EF1303BD95962E96F4777DB79B1CB`.

## Conquista, mapa e morte

- Minimapa no HUD, mapa ampliado em **N** e mapa de implantação em **M**, utilizando o mesmo componente.
- Territórios por proximidade de bases/objetivos, recortados pelo litoral. Cores derivadas do estado já replicado; aliados visíveis, sem revelar inimigos pelo mapa.
- Clique em base/objetivo válido escolhe o ponto de implantação. Base continua disponível; objetivo perdido exige nova escolha explícita.
- Após morrer, aguarda os oito segundos e abre implantação. **O jogador confirma o retorno** depois de revisar local, classe e equipamento. Não há retorno humano automático nesse fluxo.
- A escolha feita enquanto vivo é recuperada na implantação seguinte. Bots mantêm seu fluxo automático.
- Captura mostra progresso real, neutralização, perda/controle e contestação. Superioridade numérica já existia e foi preservada/testada, com aceleração limitada.
- A/C afastados simetricamente para as extremidades da trincheira; B/C passam de cerca de 241 para 328 m. Coberturas existentes acompanham os objetivos.
- Avaliado o sexto objetivo urbano próximo a D: a cidade principal está a cerca de 195 m do porto e já há cinco objetivos para 12 jogadores. Mantidos cinco nesta revisão, evitando dois setores de captura praticamente vizinhos.
- Rodapé de confirmação permanece visível em 1024×768, 1280×800 e 1920×1080; conteúdo maior pode rolar.

## Validação

| Teste | Resultado |
|---|---|
| Casos de saída, bloqueio/ré, câmera, dano 30 mm, morte manual, seleção no mapa, captura e espera | 27 verificações aprovadas |
| Mobilidade: degraus, rampas, rochas, paredes, tetos e outros veículos | 353 verificações, 88 cenários aprovados |
| Estradas completas, quatro blindados, dois sentidos, dois portos | 36 verificações aprovadas; relatório final combina oeste e leste após a revisão da entrada |
| Deserto → Guerra no mesmo cliente, autoridade e dois jogadores reais por DTLS | 25 verificações aprovadas; cliente nativo com traçantes, rajada FAL, Glock, recargas, Stinger e implantação manual |
| Interface/áudio/efeitos no cliente nativo | Três resoluções; confirmação visível, recuo, pool de fumaça, exclusão do casco, confirmação sonora privada e perfis de explosão verificados |
| Carga com 12 clientes reais, quatro blindados, dois drones, explosões e desconexão | Executada antes/depois; detalhes e limites em `BENCHMARK-1.9.2.md` |
| Profiler nativo do Godot | Mais de 880 quadros por processo, com assinaturas de funções, no servidor e renderizador por depuração remota local |

As capturas estão em `work/review192-visual/` e `work/review192-net/`. Os testes são de desenvolvimento; não acrescentam comandos de teste à distribuição pública.

## Limitações registradas

- O objeto amarelo mencionado no porto D não foi identificado com segurança. A resposta do jogador foi “outro objeto / não lembro”. Não está sendo declarado corrigido; uma localização/captura específica permitirá investigar a peça certa.
- As medições não demonstram 60 FPS estáveis em combate com 12 jogadores. Há ganho médio no ensaio local, mas ainda existem picos; o relatório inclui os resultados desfavoráveis.
- A captura do Profiler indica colisão/movimento dos blindados, envio de estados e animação dos personagens como trabalho relevante no servidor. O renderizador também paga o custo da própria medição e dos efeitos. Não são tempos independentes que possam ser somados como CPU total.
- O ensaio de 12 conexões ocorre inteiro neste PC e não equivale a 12 computadores distintos. Clientes de carga sem renderização usam um recorte de colisão; autoridade e cliente visual utilizam o mapa completo.

## Publicação concluída

**1.9.2 / build 63**, cliente Windows e servidor Linux ativados juntos em `https://192.168.101.24/`. Os três serviços estão ativos; Guerra utiliza protocolo 24. O publicador confirmou servidores vazios antes da ativação.

Após publicar, duas contas reais conectaram ao Ubuntu com HTTPS/DTLS e concluíram 21 verificações sem falhas: FAL e AK automáticas, Glock e recargas nos dois times; drone; morte por granada; espera de oito segundos; implantação manual na base; APC disparando após essa sequência e saída restaurando câmera/controle.

RTT ENet observado: média 18,8 ms em uma conta e 21,3 ms na outra; p95 de 19 e 23 ms. São medidas desta conexão durante o teste, incluindo processamento/polling; não garantem a mesma latência em outras redes ou sessões maiores.

O download HTTPS foi verificado contra os arquivos assinados, o atualizador instalou a versão e uma segunda consulta não baixou novamente. Diretório PCK criptografado, rejeição de sobrescritas externas e bloqueio de arquivos privados no site também foram verificados. O executável protegido foi aberto visualmente, implantou no treino, disparou e iniciou recarga.

## Arquivos principais

- Combate/estado: `modes/war/scripts/{game,player,projectiles,rules,vehicles}.gd` e `scripts/player.gd`.
- Câmeras/modelo: `modes/war/scripts/{vehicle,vehicle_view,vehicle_reticle,render_batch}.gd`.
- Áudio/efeitos: `modes/war/scripts/{audio,soundscape,effects}.gd`, `scripts/{weapon_audio,explosion_audio}.gd` e três amostras em `audio/war/`.
- Mundo: `modes/war/scripts/{roads,terrain,power_grid,city_life,districts,vegetation,weather,world}.gd` e `scripts/environment/environment_kit.gd`.
- Interface: `modes/war/scripts/ui.gd` e novo `tactical_map.gd`.
- Publicação: `distribution/release-notes.json`; testes e relatórios locais em `tests/`, `tools/report_review192.py` e `work/`.
