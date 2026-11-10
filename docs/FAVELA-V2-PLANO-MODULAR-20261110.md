# Favela V2 — redesenho modular a partir do esboço (10/11/2026)

## Princípio obrigatório do esboço
O morro da esquerda é **um bairro de casas com vielas e escadões**, não uma passagem da base de baixo até a base de cima. Seus caminhos conectam-se somente ao miolo central. A borda laranja dos morros é relevo, **não** circulação; os traços pretos internos são vias; as formas roxas são casas; o círculo azul embaixo e o vermelho acima são bases.

A geometria desta fase é proposta de *blockout*, não a cena final já homologada. Os traços vermelhos internos não receberam automaticamente função de objetivo definitivo: os pontos de interesse serão definidos depois da validação do traçado.

## Base e proteção do projeto
- A Favela atual (1.500 × 1.500 m) e o servidor 1.13.10/build 98 permanecem intactos.
- Branch própria iniciada no commit `da4a711`, que **já retira os 253 caminhos de terra rejeitados**.
- O novo grafo é `modes/war/scripts/favela_v2_topology.gd`; é independente de `WarFavelaMap.PRIMARY`, de regras multiplayer e da lógica dos bots até os gates aprovarem.
- Não mexer nas casas, armas, spawns ou escadões da Favela pública ao desenvolver a V2.
- Respeitar `AGENTS.md`, `docs/COORDENACAO-IA.md`, `docs/GIT-LOCAL-E-IA.md` e o GitHub. Cada fase tem worktree, scripts e QA próprios.

## Fase 1 — malha de circulação e prévia macro (nesta branch)
- Área provisória: 850 × 600 m, em vez de 1.500 × 1.500 m, com contorno natural irregular. A área útil real poderá ficar menor por causa dos morros.
- Duas bases separadas por vários setores e curvas; **sem uma reta dominante de longa visada**.
- 25 âncoras, 29 ligações explícitas entre ruas/escadarias/becos, larguras de 2,0–6,0 m, 7 trechos identificados como escadas. Todos os segmentos têm no máximo 97 m em linha reta; a ligação base–base depende de várias curvas e mudanças de setor.
- **Morro esquerdo**: 10 pontos locais, escadaria sul, escadaria longa, escadaria curta, pátio, platôs, mirante e becos conectados internamente; apenas a aresta `l00` (`central_hub` ↔ `portal_oeste`) conecta esse bairro ao resto. **Nenhuma ligação aos acessos da base norte.** Se o `central_hub` não estiver acessível, o bairro esquerdo fica isolado, sem servir de rota de flanco entre bases.
- **Miolo**: praça, comércio, escada central, cotovelos e percurso curvo rumo à base superior.
- **Direita**: campinho, curva leste, praceta e caminho alternativo reconectando ao miolo; rota base–base continua disponível quando o entroncamento central é retirado.
- Casas roxas na prévia são envelopes de posição/ocupação e não prefabs finais. Laranja é a silhueta do terreno, não uma via.
- Verificações: links válidos, largura por tipo, presença de escadas, ausência de atalho esquerdo, reachability, alternativa à rota central e ausência de retas excessivamente longas.

## Fase 2 — terrenos, bordas e desníveis (depois)
Extrair a topologia para um gerador de terreno próprio que respeite o layout, sem reutilizar o relevo quadrado atual. Perfis de encosta, terra, pedras, retenções e patamares; **não desenhar estrada nas bordas dos morros**. Verificar a mesma malha e colisão física no servidor e cliente.

## Fase 3 — setor morro esquerdo (primeiro setor jogável)
Construir lances de escada como prefabs reaproveitáveis, com patamares e pequenas curvas; vielas de 1,8–3,0 m, casas escalonadas, observação elevada, apoios e coberturas. Provar em teste de cápsula do jogador e bots que há UMA entrada pelo miolo e ZERO saída direta para a base norte; não apenas validar o desenho plano. Evitar sobreposição de lajes, tremor de câmera e obstáculos sem navegação.

## Fase 4 — miolo e objetivos
Praça improvisada com coberturas, barracas e comércios; interligar os bairros por becos com 2+ opções táticas. A ordem exata dos objetivos A/B/C/D/E e o caminho dos NPCs devem seguir os setores e não uma linha reta. Praças e vias alargadas são intencionais; os bolsões de combate são distintos.

## Fase 5 — direita e campinho
Campinho acessível em pelo menos dois corredores; evitar campo de visão de uma ponta até a outra do mapa. Pequenas curvas, rua alargada, muros, escadas e alternativa funcional para avançar, sem conectar o morro esquerdo à base superior.

## Fase 6 — arte, bots e performance
Detalhes modulares (menos scripts por objeto, MultiMesh/LOD, distância de render variável), iluminação e otimizações. Stress real de jogadores e 0/12/22 bots no servidor, Forward+ GTX 1650/1080p, FPS e frametime P95/P99; nenhum mergulho brutal ao entrar no setor ou subir lajes/escadas. Testar navegação bot+bot, colisões, multiplayer e spawn ao longo do mapa.

## Gatilhos para avançar
1. Fase 1 passa o teste topológico e exibe prévia do desenho. **Ela não é gameplay final**.
2. Fase 2 só passa após terreno contínuo, sem barranco intransponível no acesso principal.
3. Fase 3 só passa após caminhar os escadões de ida e volta com jogador e NPC e confirmar o corte do morro.
4. Fases seguintes só entram na `main` depois de benchmark e homologação; sem publicar parcial na build 98.

## Registro de QA
Executar:
- `godot --headless --path . --script res://tests/favela_v2_topology_qa.gd`
- `godot --path . --script res://tests/favela_v2_blockout_preview.gd`
A prévia PNG é armazenada apenas em `work/favela-v2-phase1-macro.png`. **Não é imagem final do mapa 3D.**

## Evidência da primeira execução (10/11/2026)
- Godot 4.7.2, editor importado (exit 0) e QA executado novamente limpo.
- `FAVELA_V2_TOPOLOGY_QA` passou **238/238** verificações, com **zero cruzamentos geométricos acidentais** entre corredores sem nó de ligação.
- Uma só entrada `l00` para o bairro oeste; 10 nós internos; sete ligações de tipo escada; nenhuma rua de veículo no oeste.
- Distância reta entre bases: **488,41 m**; percurso de navegação entre bases: **836,41 m** distribuídos em nove nós, sem passar pelo morro oeste; existe alternativa sem `central_hub`.
- Prévia em Forward+ na **GTX 1650** renderizada (exit 0): `work/favela-v2-phase1-macro.png`, 1280×825 px. **237 envelopes de casa**, sendo 83 no morro esquerdo, com 29 ligações visíveis e um único portão para o miolo.
- O blockout é **2D para aprovar a topologia**; não alegar FPS, circulação física 3D ou validação de NPC com base nele. A renderização completa 3D será a próxima fase.
