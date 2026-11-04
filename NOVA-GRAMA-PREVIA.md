# Nova Grama — prévia local

Abra `VER-NOVA-GRAMA.bat` para entrar no Guerra offline com 18 participantes, em um campo com a vegetação nova ligada. A janela tem o nome “Nova Grama · Prévia local”. Não é uma atualização publicada.

No jogo local, **Menu → Configurações → Vídeo → Vegetação** permite alternar entre Antiga, Baixo, Médio e Alto. A opção Antiga continua sendo o padrão enquanto a avaliação estiver pendente. A prévia escolhe Médio ao abrir, sem salvar automaticamente essa escolha.

As lâminas são baixas, com vento e gradação da raiz à ponta. Só o entorno da câmera recebe os detalhes novos. Não há colisão, sombra nem um nó por lâmina. Jogadores, bots e blindados continuam usando o terreno original. O ajuste dos pés corrige a altura visual do corpo quando a personalização encurta ou alonga as pernas; não muda o corpo físico nem a altura do mapa.

O PNG pintável está em `assets/war/biomes/nova_grama.png`. Ele cobre os 3,5 km do mapa:

| Região | Cor |
|---|---|
| Campo | `#309636` |
| Queimada | `#6c4132` |
| Transição | `#b29750` |
| Trilha | `#aea591` |

O PNG controla o chão e onde o capim novo pode aparecer. Ainda não substitui as árvores existentes nem acrescenta os destroços queimados. Estradas, trincheiras e áreas construídas têm exclusões adicionais para não receber capim.

A peça reutilizável está em `modes/war/library/grama_baixa_2m.tscn`, também no catálogo de objetos do editor. Geradores comuns preservam essa cena se ela já existir.

## Verificações concluídas

- Comparações de campo/área queimada a 3, 20 e 60 m: dia, noite, chuva e visão térmica, com 48 capturas em `work/nova-visual-captures/run-2026-10-28T12-10-22/`.
- Proporções de pernas 65%, 85%, 100% e 150%; posturas, caminhada, mãos, câmera e mira de ferro: 288 verificações passaram.
- Contato no Jolt com jogador, bot, Guarani, BMP-2, Abrams e T-90: 75 verificações passaram. A grama não mudou o piso detectado, a altura, o deslocamento nem a quantidade de objetos físicos.
- Teste existente de poses e alinhamento de armas: 2.219 verificações passaram.
- Testes locais de bioma, retorno aos materiais antigos, isolamento de chuva entre mundos e preferências por conta fictícia passaram.
- Servidor headless, dois clientes gráficos e entrada tardia: 96 verificações passaram, incluindo posições, proporções, ausência de colisores e limpeza ao sair. Houve avisos de buffer UDP cheio; esse teste funcional não aprova latência.

## Ainda pendente

A primeira série na mesma instância completou cinco pares com 18 participantes: FPS mediano da grama nova +0,6% contra referências adjacentes, sem perda consistente. Porém houve quadros longos nas duas variantes e ruído elevado no p99; não foi aprovada. Os testes completos de percurso e partida, a investigação dos avisos de rede e a aprovação para publicação permanecem pendentes. As capturas não comprovam fluidez. A visão térmica atual se baseia na luminosidade da cena e ainda precisa de avaliação de leitura noturna. Os dados e as limitações estão em `DECISOES.md` e nos relatórios em `work/`.
