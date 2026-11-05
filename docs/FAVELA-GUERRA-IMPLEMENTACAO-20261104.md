# Modo Guerra — Operação Favela (2026-11-04)

## Estado e segurança Git

- Branch isolada: `ia/favela-guerra`, worktree `campo-worktrees/favela-guerra`.
- Baseline da `main` no início: `e4f73fc`, sem alterações locais.
- Regras lidas e seguidas: `AGENTS.md`, `docs/COORDENACAO-IA.md`, `docs/GIT-LOCAL-E-IA.md`.
- Coordenação: sessão principal `20261104-230224-ca870303`; sessões de navegação, minimapa e QA separadas.
- Preservados os arquivos e conteúdo do Afeganistão, Ucrânia e BR.
- Sem merge na `main`, release, build distribuída ou alteração no servidor de produção.

## Escopo implementado

Operação `favela` exclusiva de **Guerra**, com mapa de 1.500 × 1.500 m, seed determinística `241106`.
Ambientação: favela brasileira fictícia com morro e mata ao norte, acesso urbano ao sul,
avenida principal curvilínea e ruas secundárias, microdetalhes, casas densas 1–5 pisos,
lajes (parte delas acessível por escadas), fachadas, obras inacabadas, portões, caixas-d'água,
varais, carros queimados, pneus, entulhos, postes e barricadas.

### Equipes

| Elemento | Equipe 1 — Polícia | Equipe 2 — Bandidos |
| --- | --- | --- |
| Base | Área urbana externa `(-470, 590)` | Na parte alta urbanizada `(280, -500)` |
| Uniforme | Preto/grafite e equipamento tático | Vermelho escuro/preto e roupas casuais |
| Lançador | Nenhum RPG/Stinger | RPG-7 na classe anti-tanque |
| Veículos | 2 Guaranis APC e 3 motos | 3 motos; nenhum blindado |

Os cinco objetivos estão distribuídos entre Entrada, Escadaria, Praça, Lajes e Reservatório.
Mantém-se o sistema já existente de captura, tickets, classes, vida, armas, projéteis,
respawn, veículos, bots, loadout e autoridade de servidor. Restrições são locais à operação.

### Arquitetura técnica

- `modes/war/scripts/favela_map.gd`: terreno determinístico triangulado em 225 blocos de 100 m; amostragem idêntica em física e representação; altitude coerente com base e objetivos.
- `EnvironmentKit`: instanciação visual em células, MultiMesh e colisão categorizada. Cores e detalhes variam segundo seed.
- `modes/war/library/favela_casa_laje.tscn`, `favela_barricada_pneus.tscn`: cenas reutilizáveis com materiais, geometria, colisões, superfície e metadados LOD; registradas no catálogo do editor via `WarPrefabFactory.ITEMS`.
- `modes/war/scripts/favela_uniform.gd`: uniformes por facção, reaproveitando esqueleto e animações sem alterar hitboxes nem rig.
- `WarBotTransit` e `WarBotDirector`: grafo viário exclusivo e grade de navegação regional de 5 m para o mapa, com caminhos de veículos restritos a vias adequadas.
- `WarVehicles`: somente os tipos permitidos; identificadores únicos `v_guarani_0` e `v_guarani_1` para dois APCs.
- `WarTacticalMap`: território e estradas próprios (sem oceanos/estradas da Ucrânia).
- `scripts/main.gd` / `scripts/ui/main_menu.gd`: seleção, transição de carregamento e inicialização da Favela, offline ou conexão à sala do mapa.
- `maps/prepared/favela/manifest.json`: identidade do mapa, versão, limites e SHA-256 calculado das fontes para protocolo de compatibilidade. Porta da operação: `3016`.

### Testes automatizados executados

Godot `4.7.2.stable.official` no Windows, executável de console instalado localmente.

1. `--headless --editor --import`: **PASS**, código compilado sem erros após ajustes na nova branch.
2. `--headless --script res://tests/favela_operation_smoke.gd`: **PASS**.
3. Mesmo teste com `-- --favela-visuals`: **PASS**.
4. `--headless --script res://tests/favela_runtime_qa.gd`: **PASS**, partida offline real, frota completa, suprimentos, implantação de soldado da polícia e verificações de spawn de veículos.
5. Mesmo teste com `-- --favela-bots`: **PASS**, 28 bots existentes e implantados; movimentação observada e nenhuma falha de implantação durante teste curto.
6. `git diff --check`: **PASS**, sem erros de whitespace.
7. Regressão afegã `qa/afghan_spawn_ai_qa.gd`: **1 falha preexistente**, reproduzida também na `main` limpa (`AFGHAN_SPAWN_AI_FAIL: One-seat vehicles require server-validated bot exit`). O teste espera moto monoposto, enquanto a implementação atual de moto tem dois lugares. A Favela não modificou o número de lugares, e não corrigimos a QA alheia nesta branch.

### Métricas aproximadas da revisão

- Terreno: **225 tiles**.
- Casas/modulos edificados: cerca de **3,3 mil**; contagem varia se modificarmos reservas de base.
- Componentes visuais gerados: cerca de **34 mil** (instanciados/agrupados, não draw calls).
- Formas de colisão do EnvironmentKit: mais de **4,4 mil** (além dos colliders de terreno e peças autorais).
- Montagem do mundo em teste headless: aproximadamente **1 s sem renderização**, **3,7 s com visuais construídos**; tempos de preparação de cena, **não FPS**, nem latência em partida real.

## Limites, próximos critérios de validação

**Este é um primeiro mapa funcional e testável, ainda NÃO uma atualização publicada.**
Antes de merge/release ainda são necessários:

- Inspeção visual interativa por jogador em alta e baixa qualidade; correção de interseções, escadas, lajes, eventuais repetições visuais.
- Medição de FPS/p99 frame-time na GTX 1650 em 1080p com 28 bots, inclusive mirantes, variação de LOD e entrada/saída da partida.
- Multiplayer efetivo com cliente/servidor, integridade do manifesto, sync de bots e de veículos, objetivos, morte/respawn, sem perda de estado.
- Rodar veículos por rotas inteiras, avaliar as manobras em becos e capacidade de chegada dos bots nos cinco objetivos; testes curtos não provam AI perfeita.
- Rever o equilíbrio entre dois APCs da polícia e RPG da equipe 2 em uma partida completa.
- Avaliar qualidade artística em comparação com o Afegão, expandindo interiores e detalhes únicos sem sacrificar desempenho.
- Revisão de integração com outras branches em aberto, mantendo `main` intacta até o pipeline de lançamento.

## Uso local

Abra a worktree exclusiva e use o menu **GUERRA · FAVELA** (requer `gameplay/war_enabled`).
Para testar offline: selecione Favela e **JOGAR COM BOTS**. Servidor online precisa suportar a
operação e a porta própria; a execução isolada não hospeda o servidor público.

## Revisão urbana de 05/11/2026

A identidade do manifesto passou para a versão 2. O terreno ganhou mais de 125 m de
desnível entre o acesso e a mata, com lombas no miolo e inclinações menores no
eixo principal. A malha visível passou a mostrar a mesma superfície já usada pela
física. Os portões acompanham a avenida e a casa autoral da Praça saiu do seu leito.

- **3.834 edificações**, incluindo 2.213 casas com volumes escalonados, 66 lajes
  servidas por escadas e 10 passarelas com colisão.
- **Seis mini-ruas** sinuosas de cerca de 2,8 m, ligadas à rede de infantaria e ao
  minimapa. A avenida e as travessas mantêm o corredor de veículos. O miolo usa
  concreto e asfalto com variação de desgaste. A terra se concentra na periferia
  e na transição para a mata.
- **66 frentes comerciais**, com portas de aço, toldos, placas e caixotes.
  Há 322 postes, 322 vãos de seis cabos e 14 motos estacionadas com colisão.
  Comércios, postes, vãos e motos estão disponíveis como cenas no catálogo do editor.
- Casas com reboco gasto, tijolo, sacadas, tubulações, medidores, antenas e caixas
  d'água. Os elementos de rua usam recursos compartilhados e agrupamento visual
  por setor. As colisões são construídas também na autoridade headless.
- O diretor de bots reconhece os dois IDs dos Guaranis e usa motos para os
  bandidos. Os seis veículos operáveis do tipo moto continuam separados das motos
  estáticas de cenário.

Os testes de construção com e sem visuais passaram no Godot 4.7.2, incluindo a
checagem física da avenida e das seis mini-ruas. A partida offline passou nas
39 verificações com 28 bots, dois Guaranis e seis motos operáveis.

A sessão local DTLS passou em 15 verificações entre cliente e servidor. O cliente
aceitou a identidade da Favela e recebeu os cinco objetivos e os oito veículos.
A autoridade recusou um pedido forjado de RPG policial e replicou a ocupação
validada de um Guarani. A duração e a carga desse teste cobrem apenas a entrada,
a implantação e a ocupação do veículo.

Em uma passagem de câmera de 30 s por preset, na GTX 1650 com saída 1080p e
28 bots, o Alto registrou 24,1 FPS médios e p99 de 120,9 ms. O Baixo, com escala
de renderização de 75%, registrou 32,4 FPS e p99 de 104,1 ms. Ambos excederam
o limite de 50 ms para o pior quadro previsto no manifesto.

Ficam para a aceitação de lançamento a navegação prolongada de veículos e bots
entre os objetivos, a travessia de todas as lajes em partida, o equilíbrio entre
facções e a estabilidade de FPS em combate completo.

## Revisão de superfícies de 05/11/2026 — versão 3

As fachadas receberam materiais compartilhados com áreas irregulares de reboco
perdido, juntas de alvenaria, umidade, rachaduras e normais de superfície. Foram
removidos os antigos retângulos de tijolo colados sobre algumas paredes.
As vias usam remendos e fissuras mipmapeados com redução de detalhe à distância.

Há 1.276 marcas de parede em quatro variantes autorais e 482 conjuntos de resíduos
(sacos, papelão, papel e garrafas), apoiados conforme a inclinação e a altura do
pavimento. Pixação e lixo têm cenas reutilizáveis no catálogo. Os detalhes pequenos
não criam colisores, usam recursos compartilhados, alcance limitado e agrupamento.
O terreno, as 3.834 edificações e as coberturas físicas permanecem nesta revisão.

Validação desta versão no Godot 4.7.2:
- Smoke com e sem representação visual passou, incluindo identidade das fontes e
  amostras físicas da avenida e das seis mini-ruas.
- Partida offline com 28 bots passou nas 39 verificações, com oito veículos.
- Shaders compilaram na GTX 1650. Capturas reais Alto/Baixo do comércio, avenida,
  beco, viela, encosta e asfalto confirmaram os elementos em execução.
- Passagem de câmera de 30 s por preset, 1080p e 28 bots, registrou Alto 52,8 FPS,
  p99 48,4 ms e pior quadro 75,7 ms. Baixo com escala 75% registrou 59,4 FPS,
  p99 69,1 ms e pior quadro 138,4 ms. São medições curtas e variáveis, sem combate
  efetivo registrado; não demonstram 60 FPS estáveis nem aprovação de lançamento.
- Capturas e logs em
  `C:/Users/Joao Borges/AppData/Local/Temp/favela-qa-26454181a19a4b398fd236193fe76830/desgaste-entrega/`.

O teste visual ainda mostra recuos excessivos, fachadas simplificadas e fiação
muito paralela. A próxima etapa autorizada é arquitetônica e por quadras, com
repetição das mesmas câmeras, aproximação das frentes, módulos de fachada e laje
e validação de acessos. Esta etapa de superfícies não encerra o trabalho solicitado.

## Revisão de quadras e circulação vertical — versão 4

O desenho de lotes reserva a largura das vias primeiro. As frentes viáveis
ganham prioridade, com afastamentos calculados a partir da borda e um índice
espacial que impede a sobreposição de lotes. Perfis de volume, altura,
acabamento e recuo variam por quadra. O mapa de 1,5 km × 1,5 km tem 3.845 casas,
1.071 frentes deslocadas, 955 fachadas a menos de 1 m da via e 133 recuos de
2,2 a 3,0 m preservados junto a trechos de comércio e estacionamento.

- Nove cenas novas no catálogo, com janelas gradeadas e com venezianas, porta
  com soleira, sacada, duas composições de laje, escada externa, carro compacto
  e puxadinho de chapa. Os módulos usam malhas compartilhadas, instâncias
  agrupadas por setor e alcance por porte. Os elementos de cobertura têm
  colisão na autoridade e no cliente.
- Há 432 puxadinhos de chapa, 1.024 conjuntos de objetos de laje e 105 frentes
  comerciais. O entorno ganhou seis carros compactos nos recuos, 23 motos
  estacionadas e 107 ramais individuais de fiação. Reboco, alvenaria e sinais
  de desgaste variam por trecho. A luz direcional usa duas divisões de sombras
  com alcance de 135 m.
- As 126 lajes ligadas a escadas, 12 passarelas e 54 passagens cobertas ampliam
  as alternativas de infantaria. A rede de rua usa cruzamentos geométricos
  explícitos. A Favela tem grade local de 3 m e um grafo tridimensional para
  escadas e lajes. Atiradores podem buscar um ponto de observação próximo ao
  objetivo em uma laje alcançável.

As imagens `rua-antes.png` e `rua-depois.png` foram capturadas no mesmo
enquadramento a partir de (-200, -15). Elas mostram a mudança do recuo das
fachadas e a profundidade dos elementos de janela e sacada. Também foram
inspecionados comércio, viela, escada, passarela e encosta. A composição foi
comparada às escadarias entre edificações de
[Santa Marta](https://brasil.elpais.com/brasil/2017/09/22/politica/1506096531_079176.html)
e às cenas de rua da
[Rocinha fotografadas por Julian Machado Rigg](https://www.julianmachadorigg.com/rocinha).
O panorama ainda evidencia a malha de quadras mais regular que as referências.

- Smoke de layout e regras passou com visuais, incluindo a avenida e as seis
  mini-ruas. O grafo viário alcança a vizinhança dos cinco objetivos.
- O QA de arquitetura passou em 9.133 amostras de piso e folga das escadas e
  passarelas. Com `--favela-bot-traversal`, um bot do WarGame subiu uma
  escada e cruzou uma passarela em dois percursos controlados.
- Partida offline passou nas 39 verificações, com 28 bots implantados e oito
  veículos. O smoke DTLS entre cliente e servidor local passou em 15
  verificações de identidade, objetivos, frota, regras e ocupação de veículo.

A GTX 1650 registrou 73,2 FPS médios no Alto nativo em 1080p e 28 bots durante
120 s. O p99 foi 30,5 ms e o pior quadro, 77,5 ms. O Baixo, com saída em
1080p e escala interna de 75%, registrou 82,6 FPS durante 45 s, p99 de 32,8 ms
e pior quadro de 79,5 ms. Os dois trechos automatizados tiveram bots em
movimento, sem disparos registrados. A média no Alto supera a meta de 60 FPS,
mas o pior quadro ficou acima do limite de 50 ms do manifesto. A estabilidade
em combate completo, o equilíbrio e uma travessia de veículos em partida longa
continuam pendentes para aceitação de lançamento.

As capturas, o roteiro de câmera e o log estão em
`C:/Users/Joao Borges/.codex/visualizations/2026/11/05/01a1ab1b-38f6-7f83-afa8-697ff50a81ac/Favela/`.
