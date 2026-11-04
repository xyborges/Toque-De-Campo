# Revisão local — ópticas, motos e transições

28/10/2026. **Não publicada.** Nenhum serviço de produção, site, instalador ou manifesto foi atualizado. A Nova Grama está fora desta atualização. O protótipo continua disponível somente por prévia explícita no editor.

## Alterações

- Binóculos: cena reutilizável presa às duas mãos, transição para o rosto, duas ampliações e bordas ópticas próprias, sem retículo de arma. Zoom e equipamento passam pela autoridade e recebem proteção por vida do jogador. Guardar, morrer, nadar, embarcar e sair da cena limpam a apresentação. A pose das mãos usa os pontos do objeto.
- Lunetas opcionais 4× na AK e na FAL: acessório separado dos modelos existentes, configurável no loadout. AK inspirada na fotografia enviada, com montagem lateral, tubo longo e ocular de borracha; FAL com corpo compacto/prismático e base baixa. A cena dentro da lente é uma renderização do mundo, não uma imagem estática. Um clique direito ativa/desativa, preservando a preferência FPP/TPP. A sensibilidade fica reduzida durante a mira.
- Apenas a lente local levantada cria trabalho de uma segunda câmera, em 384 × 384, sem MSAA. Jogadores remotos têm a geometria da luneta, sem câmera extra. Ao guardar/recarregar/morrer/embarcar, a segunda renderização para. As carcaças rígidas usam o agrupamento existente e recursos compartilhados.
- Opcionais de mira usam preferências numéricas por arma no canal existente de configurações por conta. O teste de sincronização usa contas simuladas; não foi acessada uma conta real no servidor central. No Deserto, a seleção validada também tem transmissão confiável e referência para quem entra depois; no Guerra acompanha a identidade/loadout.
- Motos: seis no total, três por base, um operador exposto por veículo, sem armas pessoais ou montadas enquanto pilota. Entrada e saída usam reservas/posições seguras do servidor. Destruição: retorno após 15 s. Abandono fora do estacionamento: retorno após 30 s, sem retirar ocupantes. Se o local estiver bloqueado, tenta outra posição e limita novas tentativas a cada 0,5 s. Podem receber dano de armas de infantaria; a imunidade dos blindados foi preservada. Modelo separado e motor sintetizado próprio, reaproveitando atenuação e controle de volume.
- Noite do Guerra: preenchimento ambiente/lunar e cores do céu/névoa existentes foram ajustados para leitura do solo. Nenhuma luz adicional ou sombra nova; o ciclo permanece em 14 min. Doze comparações de imagem, três regiões e dia/noite.
- Navios: relógio de reprodução não ultrapassa os pacotes recebidos; tangentes de interpolação limitadas para evitar ultrapassar a posição e voltar após uma mudança brusca de velocidade. Sequência e gerações de assento/respawn continuam rejeitando pacotes antigos.
- Rodadas: notificações e snapshots passam a carregar a geração da operação. Atualização antiga não reabre resultado após o reinício; mensagens na saída são descartadas. O intervalo continua sendo de 60 s.

## Desvio do cano com luneta

O teste reproduziu uma diferença entre a cópia desenhada em FPP e a arma real, que continuava deslocada para o ombro. A origem do disparo usa a arma real. A pose óptica agora é calculada do mesmo modo no jogador e na autoridade, a partir do olho, inclinação e postura; não foi movido apenas o traçante. Marcadores de saída dos modelos importados agora também acompanham o próprio modelo durante animações.

A regressão inicial falhou nas 162 combinações, com diferença máxima de 0,81 m incluindo posturas baixas. Após a correção, as 490 verificações passaram; maior erro geométrico observado: aproximadamente 0,00000027 m. Inclui AK/FAL, yaw, pitch, inclinação lateral, de pé/agachado/deitado, personagem remoto e origem de pacotes realmente aceitos pela rotina de disparo. Isso não é garantia de precisão submilimétrica sobre uma rede com atraso: são verificações determinísticas das transformações.

## Validação concluída

| Ensaio | Resultado |
|---|---|
| Binóculos: estados, mãos, classes, morte, limpeza e zoom | 272 verificações, sem erros |
| Acessórios e motos: seleção, entrada/saída, vulnerabilidade, bloqueio de disparo e temporizadores | 55 verificações, sem erros |
| Preferências de óptica: duas contas simuladas e sincronizador existente | 7 verificações, sem erros |
| Capturas de equipamento e atualização contínua da lente | 35 verificações, oito imagens; imagens mudam ao olhar horizontal/verticalmente |
| Câmera/lente: ampliação em pixels | 4×, erro abaixo de 0,03× nos enquadramentos testados |
| Transições e pacotes de rodada antigos | 15 verificações, sem erros |
| Reprodução de movimento com jitter/perda simulados | 3.807 verificações; 1.800 passos, nenhum retorno ou quadro parado na série |
| Receptores reais dos quatro navios | 32 verificações, sem erros |
| Regressões de pose anteriores | 2.219 verificações, sem erros |
| Noite: campo, região queimada e estrada | 12 capturas; solo noturno mais claro e dia preservado |
| Servidor local DTLS e dois clientes gráficos, com entrada tardia | 20 + 18 + 15 verificações, sem erros |

A sessão multiplayer percorreu loadouts com óptica, binóculos/zoom, entrada, deslocamento e saída de moto, navio em movimento por snapshots normais, resultado, intervalo **real de 60 s** e nova rodada. Os clientes coletaram 241 e 240 deslocamentos do navio sem retorno horizontal. O percurso do navio foi um autopiloto roteirizado, não teste humano de embarque no mar. O teste de rede terminou antes da última correção da pose do cano; essa correção tem a regressão determinística adicional de 490 verificações, não uma nova certificação WAN.

O fechamento nativo relatado no fim de uma partida **não foi reproduzido** e não foi encontrado dump que confirme sua causa. A corrida de estado foi corrigida e dois clientes permaneceram abertos no ciclo completo; isso não prova que todo possível fechamento esteja resolvido.

## Desempenho e pendências

A primeira sondagem A/B/A/B/A da lente foi invalidada: o cenário estava congelado para medição, mas ainda aceitava mouse; a câmera mudou durante a série. Não usar seus FPS como resultado ou aprovação. O roteiro agora bloqueia entrada e identifica a janela como medição automática. A janela `optical_play.gd` mantém simulação e controles normais e não é um benchmark. Ainda falta um comparativo de custo válido em cena estável e teste mais longo de combate; nenhuma promessa de 60 FPS ou aprovação de desempenho foi feita.

Relatórios e capturas: `work/equipment-visual/`, `work/night-visibility-*/`, `work/equipment-network-{server,first,late}.json`, `work/scoped-muzzle-regression.json`. As tentativas que revelaram perda de material em cópias de cenas herdadas foram guardadas antes da correção em `work/equipment-network-before-lens-fix-*`. A cópia FPP agora preserva o subgrafo e isola o material da lente.

A publicação futura deve atualizar cliente e servidor juntos: Guerra protocolo 29 e loadout protocolo 11. **Não publicar sem aprovação.**

Reabastecimento existente: caixas reais nos pontos A–E, habilitadas ao time proprietário. H a pé a até 4 m; blindado terrestre operado a até 24 m. Intervalo de 20 s por jogador/veículo. Reposição de reserva, sem cura ou carregador automático; continuar usando R. Binóculos não gastam munição. Nenhuma dessas regras foi alterada nesta revisão.

Documentação técnica da lente: [SubViewport 4.7](https://docs.godotengine.org/en/4.7/classes/class_subviewport.html) e [textura de Viewport em objetos](https://docs.godotengine.org/en/4.7/tutorials/shaders/using_viewport_as_texture.html).
