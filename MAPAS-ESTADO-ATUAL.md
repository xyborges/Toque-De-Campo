# Mapas do Toque de Campo — Godot 1.5.0

Estado implementado em 23/10/2026. Escala aproximada: um metro por unidade. Levantamento anterior preservado em `work/extended-look-before/MAPAS-1.4.1.md`. Imagens: [comparação antes/depois](EXTENDED-LOOK-COMPARACAO.html).

## Visão geral

| Mapa | Uso | Dimensões |
|---|---|---|
| Complexo administrativo industrial | Treino offline contra NPCs | Salão de 22 × 36 m mais anexo de 30 × 16 m; 1.272 m² de piso |
| Posto militar avançado | PVP Deserto e treino offline | Terreno físico de 300 × 300 m; combate concentrado na instalação central |
| Arquipélago militar | PVP Naval | Navegação de ±980 m, água visual de 4,4 × 4,4 km e cinco ilhas |

Os ambientes são geometria 3D modular, com materiais de cor, rugosidade e normal. As fotos dos cartões são ilustrativas. O cenário de apresentação do login permanece separado dos mapas jogáveis.

## 1. Escritório — complexo administrativo industrial

### Planta e circulação

O salão original de 22 × 36 m e teto a 8 m continua principal. A passagem traseira agora tem abertura física de aproximadamente 3,1 m. Conecta um corredor de serviço de 4 × 16 m a quatro salas laterais, cada uma próxima de 13 × 8 m:

- **Recepção:** balcão, computador, cadeiras de espera, avisos e mobiliário de atendimento.
- **Administração:** estações com divisórias, monitores, documentos, armários e cadeiras com encosto e rodízios.
- **Arquivo:** estantes de pastas e caixas etiquetadas, armários e corredores de consulta.
- **Manutenção:** bancada, ferramentas, morsa, motor e peças, armários e equipamentos.

Limites X de −15 a 15 m e Z de −45 a 7 m. Os cantos laterais fora do salão não possuem piso; navegação e spawn respeitam essa planta. Portas internas são aberturas atravessáveis; a porta frontal de serviço permanece fechada.

### Arquitetura, materiais e luz

Vigas, pilares, chapas de ligação, dutos, eletrocalhas e tubos preenchem o pé-direito. Estantes com montantes, travessas e prateleiras; caixas com fitas e etiquetas; pallets, carrinho de carga, extintores, relógio, placas e vasos.

Mesas com tampo e estrutura; cadeiras com assento, encosto, braços e base reconhecível. Telas com linhas e áreas de interface decorativas. Piso com juntas, madeira/laminado, metal pintado, papelão, concreto e reboco texturizados. Luminárias industriais e ambiente quente conservam a leitura dos personagens.

### Colisão e NPCs

Paredes, móveis grandes, prateleiras, caixas e estruturas usam colisores simplificados. Etiquetas, papéis, tubos pequenos e ferramentas não viram obstáculos individuais. A navegação A* cobre quatro salas e corredor. O treino começa com oito NPCs e cresce até dezesseis; os spawns evitam móveis, outros personagens e espaços sem piso.

## 2. Deserto — posto militar avançado

### Terreno

O piso plano de 112 × 112 m foi substituído por terreno físico de **300 × 300 m**. São amostras a cada 2 m, 36 setores e cerca de 45 mil triângulos. A altura usada por spawn e navegação interpola os mesmos triângulos da colisão.

Dunas, pequenas cristas, depressões, trechos planos e caminho compactado. O centro é menos acidentado para acomodar construções. Rochas maiores são cobertura; pedras pequenas e tufos secos completam o solo. Marcas de pneus acompanham a altura, com óleo junto à manutenção.

### Instalação

- **Prédio central:** cerca de 15 × 11 m, concreto, corredor atravessável da frente aos fundos, sala de comunicação e depósito. Portas e janelas reais, venezianas com lâminas físicas, platibanda e ventilação. Sem escada para criar domínio automático do telhado.
- **Logística:** três contêineres corrugados, um aberto, pallets, caixas militares e tambores.
- **Comunicações:** torre treliçada, abrigo de rádio, cabos e equipamentos.
- **Manutenção:** cobertura metálica, bancada, gerador, rodas e caminhão militar estacionado. O caminhão é cenário sólido, sem direção ou compra de veículos.
- **Perímetro:** cercas, vários acessos, duas guaritas, barreiras e sacos de areia arredondados.
- **Armazenagem:** lona e materiais de abastecimento.

O perímetro construído fica próximo de 74 × 68 m. Coberturas e aproximações concentram o combate para que seis jogadores não precisem procurar adversários em todo o terreno.

### Atmosfera e regras

Sol forte, sombras definidas, céu claro, névoa leve, vento ambiente e até 36 partículas de poeira próximas da câmera. Sem tempestade constante.

O PVP continua **cada um por si**, de dois a seis jogadores. Oito posições de spawn no entorno do centro; seleção considera adversários vivos. O servidor valida altura relativa ao terreno e confirma a posição inicial do cliente. Treino com doze NPCs iniciais, até vinte e quatro. Navegação considera altura, inclinação, sólidos e passagens; NPCs surgem perto da ação.

## 3. Naval — arquipélago militar

### Escala e ilhas

Navegação de aproximadamente 1,96 × 1,96 km e oceano visual de 4,4 × 4,4 km. Água aberta na periferia; ilhas centrais oferecem abrigo e rotas.

| Ilha | Centro X/Z | Raio nominal | Identidade implementada |
|---|---|---|---|
| Farol | −260 / −180 m | 52 m | Torre de alvenaria, faixas, varanda, lanterna, facho giratório, prédio de apoio e escadaria |
| Radar | 290 / 230 m | 65 m | Torre treliçada, parábola, prédio técnico, plataforma e cercamento |
| Costa selvagem | 100 / −340 m | 42 m | Penhascos, fissuras, rochas, praia e vegetação esparsa |
| Fortificação | −390 / 390 m | 78 m | Bunker com aberturas, muros partidos, escombros e observação |
| Porto abandonado | 430 / −410 m | 50 m | Armazém, cais sobre estacas, guindaste com cabo/gancho, carga, boias e lancha cenográfica |

Silhuetas e costas variadas; uma ilha recebe montanha mais alta conforme a semente compartilhada. Estruturas ficam dentro da região de segurança das ilhas. Spawn procura água livre, afastado de obstáculos e outros navios.

### Água e iluminação

As duas ondas físicas originais continuam com amplitudes de 0,22 e 0,11 m. Flutuação e inclinação não foram recalibradas. Normais de ondulação, Fresnel, brilho solar, variação de cor e espuma costeira aproximada melhoram a superfície. Esteiras, respingos, traçantes e explosões continuam ativos.

Camada leve de nuvens e céu procedural. Ciclo original de 900 segundos, noite navegável com lua, farol e iluminação costeira. Embarcações com luzes de posição vermelha, verde e branca.

### Colisões, balística e fundo

Servidor e clientes constroem as mesmas colisões das ilhas e instalações. A parábola do radar tem malha física correspondente. Construções e rochas grandes bloqueiam tiros; vegetação e cabos finos são decorativos.

Canos, limites das torretas, gravidade, velocidade herdada X/Z e previsão de impacto continuam no sistema compartilhado. A guia e o projétil foram comparados com navio em movimento nas quatro classes de arma.

Fundo oceânico físico de aproximadamente 2,2 × 2,2 km, profundidades variadas, encostas e 25 rochas submersas. Visibilidade e cor reagem à profundidade da câmera. **É preparação do cenário: o submarino continua na superfície. Mergulho jogável e combate subaquático não foram implementados nesta atualização.**

## 4. Câmera

Uma esfera varre o espaço entre personagem e câmera TPP. Paredes, portas fechadas, armários, teto e chão encurtam a distância imediatamente; ao liberar o caminho, a câmera retorna suavemente ao ombro. Muito perto do corpo, usa a apresentação de mãos FPP para evitar ver o interior do avatar, preservando a escolha TPP e o cano físico.

A câmera naval testa volume contra sólidos e permanece acima do mar. A posição inicial evita mostrar a parte inferior da água antes do primeiro estado da partida.

## 5. Recursos e otimização

Onze famílias de materiais próprios, 33 texturas PBR de 256 × 256 pixels. Materiais compartilhados e MultiMesh por setor; distância limitada de microdetalhes, LOD geométrico de rochas e oclusão no escritório coerente com portas. Resultados e limites das medições: [EXTENDED-LOOK.md](EXTENDED-LOOK.md).
