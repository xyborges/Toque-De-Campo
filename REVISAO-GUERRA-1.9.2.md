# TOQUE DE CAMPO — Modo Guerra
## Revisão de veículos, mapa, áudio, conquista, spawn e HUD

> **Objetivo:** corrigir problemas reais de jogabilidade observados durante testes do Modo Guerra e, em seguida, melhorar veículos, combate, áudio, mapa, conquista, interface e desempenho.
>
> **Regra geral:** antes de alterar qualquer sistema, verificar o que já existe no projeto e o que já foi implementado. Não duplicar lógica, não substituir sistemas funcionais sem necessidade e não assumir como verdadeira uma informação que precise ser confirmada no código ou no mapa.

---

# 1. Bugs críticos

## 1.1. [BUG] Não foi possível sair do APC

### Problema observado
Durante o teste, o jogador permaneceu bastante tempo dentro do APC e não conseguiu sair do veículo.

### Verificar
- leitura da tecla de saída;
- estado de ocupação do veículo;
- pontos válidos de saída;
- colisões próximas;
- bloqueio indevido do estado do jogador;
- sincronização servidor/cliente;
- possibilidade de todos os pontos de saída estarem sendo considerados inválidos;
- lógica aplicada quando o veículo está muito próximo de paredes, barrancos, objetos ou outros veículos.

### Alteração desejada
Se o ponto principal de saída estiver bloqueado, procurar automaticamente outro ponto seguro ao redor do veículo.

O jogador não pode permanecer preso indefinidamente dentro do APC apenas porque um ponto específico está bloqueado.

### Resultado esperado
O jogador consegue sair normalmente sempre que houver um ponto seguro próximo.

---

## 1.2. [BUG] Reimplantação apareceu inesperadamente no porto

### Problema observado
Enquanto o jogador estava parado no porto, apareceu uma opção de reimplantação sem solicitação. Ao utilizá-la, o jogador voltou para a base.

### Verificar
- zona fora da área jogável;
- timeout de jogador;
- zona de segurança;
- área de spawn;
- trigger invisível;
- lógica de morte;
- lógica de abandono;
- validação de posição;
- interface de implantação;
- comportamento específico daquela região.

### Resultado esperado
Ficar parado em uma região válida do mapa não deve exibir reimplantação indevida nem transportar o jogador para a base sem motivo.

---

## 1.3. [BUG] Câmera pula ao disparar metralhadora dos blindados

### Problema observado
Ao manter a metralhadora do blindado disparando, a câmera sobe verticalmente e depois retorna.

Esse comportamento não parece um recoil intencional.

### Verificar
- posição da câmera;
- recoil;
- `SpringArm3D`;
- atualização da torre;
- interpolação;
- pitch;
- recoil acumulativo;
- conflito entre lógica da câmera e lógica da torre;
- algum valor sendo aplicado diretamente à transformação da câmera.

### Resultado esperado
O recoil pode transmitir impacto, mas sem produzir saltos artificiais ou deslocamentos verticais estranhos.

---

## 1.4. [BUG] Som da metralhadora muda ao olhar para trás

### Problema observado
Enquanto o jogador estava em um blindado no porto, o som da própria metralhadora pareceu ficar abafado quando a câmera foi virada para trás.

Pode ter sido um bug isolado.

### Verificar
- `AudioListener3D`;
- posição da fonte sonora;
- orientação da câmera;
- tratamento de primeira e terceira pessoa;
- oclusão;
- filtros;
- buses;
- lógica relacionada à direção da câmera.

### Resultado esperado
A orientação da câmera não deve fazer o próprio disparo desaparecer ou ficar excessivamente abafado sem motivo.

---

# 2. Combate dos blindados

## 2.1. [MELHORIA] Aumentar dano das munições de 30 mm

### Intenção
O canhão automático de 30 mm está parecendo fraco demais contra infantaria.

### Alteração desejada
Aumentar significativamente o dano direto.

Comportamento esperado:
- impacto direto em infantaria: normalmente eliminação imediata;
- explosão muito próxima: dano extremamente alto;
- distâncias maiores da explosão: dano reduzido progressivamente.

Também aumentar moderadamente o dano em área.

### Importante
Não transformar o 30 mm em uma explosão equivalente ao canhão principal de um tanque.

### Verificar
- dano atual;
- raio atual;
- tipo de munição implementada;
- balanceamento atual contra veículos;
- multiplicadores de dano.

Manter o balanceamento contra blindados separado do dano contra infantaria.

---

## 2.2. [MELHORIA] Mira dos blindados

### Problema
A mira atual transmite uma sensação estranha porque a sensibilidade do mouse é mais rápida que a velocidade física da torre.

O jogador move o mouse para um lugar, mas não possui uma referência clara de onde deseja levar o canhão enquanto a torre ainda está girando.

### Referência de comportamento
Basear-se na sensação de controle de veículos dos jogos Battlefield, sem copiar elementos visuais diretamente.

### Lógica desejada

Existem dois conceitos diferentes:

#### Mira real
Representa exatamente para onde o canhão está apontando neste momento.

#### Indicador de intenção
Representa a posição para a qual o jogador está tentando mover a torre com o mouse.

O indicador de intenção:
- não deve permanecer fixo no centro da tela;
- deve responder imediatamente ao movimento do mouse;
- pode se afastar da mira real;
- serve como destino que a torre tentará alcançar.

A torre:
- continua limitada pela própria velocidade de rotação;
- acompanha progressivamente o indicador de intenção;
- não gira instantaneamente junto com o mouse.

### Exemplo
1. Jogador move rapidamente o mouse para a direita.
2. Indicador de intenção se desloca imediatamente para a direita.
3. Mira real continua na posição atual.
4. Torre começa a girar.
5. Mira real se aproxima do indicador.
6. Quando a torre chega à posição desejada, os indicadores praticamente coincidem.

### Resultado esperado
O jogador entende claramente:
- para onde quer mirar;
- para onde o canhão aponta atualmente;
- quanto a torre ainda precisa girar.

Aplicar a lógica às câmeras de primeira e terceira pessoa, adaptando a apresentação visual.

---

## 2.3. [MELHORIA] Disparo do canhão principal

O disparo do tanque precisa transmitir mais força.

### Adicionar ou revisar
- recuo físico/visual do cano para trás;
- retorno mecânico do cano para a posição original;
- possível reação discreta da torre ou suspensão;
- recoil visual da câmera;
- vibração curta;
- som de disparo muito mais forte;
- fumaça/gases saindo do cano;
- efeito visual de disparo proporcional ao calibre.

### Importante
O recoil da câmera deve transmitir força sem impedir completamente a visão.

---

# 3. Física e movimentação dos blindados

## 3.1. [BUG/MELHORIA] Tanque continua acelerando contra obstáculo

### Problema observado
Quando o tanque bate contra uma parede ou obstáculo, parece continuar tentando avançar.

Ao tentar dar ré logo depois, existe sensação de que é necessário esperar a aceleração anterior desaparecer.

### Alteração desejada
Quando houver uma colisão frontal significativa:
- reduzir ou interromper imediatamente o esforço de aceleração para frente;
- permitir resposta rápida ao comando de ré;
- impedir acúmulo de força contra o obstáculo;
- preservar sensação de massa sem criar atraso artificial nos controles.

---

## 3.2. [BUG] Blindados muito sensíveis a pequenas diferenças de terreno

### Exemplo observado
Próximo à base da Equipe 1, ao tentar subir para uma rua asfaltada, o tanque pode parar praticamente ao encontrar a elevação.

### Verificar
- colisão entre terreno e rua;
- altura máxima de degrau;
- suspensão;
- centro de massa;
- rodas/esteiras;
- forças aplicadas;
- formato das colisões;
- transições entre terreno e asfalto.

### Resultado esperado
Blindados devem superar pequenas diferenças de terreno e obstáculos baixos sem parar completamente.

---

## 3.3. [BUG] Pedras pequenas fazem blindados saltarem

### Problema observado
Algumas pedras no caminho conseguem fazer um blindado pesado dar um salto exagerado.

### Verificar
- colisão das pedras;
- colisão do veículo;
- suspensão;
- centro de massa;
- forças verticais;
- velocidade de aproximação.

### Resultado esperado
Pequenos obstáculos podem:
- gerar vibração;
- reduzir velocidade;
- deslocar levemente o veículo.

Mas não devem lançar um blindado pesado para cima de forma artificial.

---

## 3.4. [MELHORIA] Objetos quebráveis e tolerância a impactos

Alguns objetos do mapa podem ser mais tolerantes à passagem de veículos pesados.

### Possíveis objetos
- árvores menores;
- postes;
- cercas;
- pequenas barreiras;
- objetos urbanos leves.

### Possíveis comportamentos
- quebrar;
- tombar;
- deslocar;
- sofrer impacto;
- reduzir parcialmente a velocidade do veículo.

### Não aplicar indiscriminadamente
Verificar tamanho, tipo e função do objeto.

Construções, pedras grandes e estruturas pesadas podem continuar bloqueando os veículos.

### Objetivo
Diminuir situações em que um pequeno objeto decorativo consegue parar completamente um tanque.

---

# 4. Explosões, fumaça e efeitos

## 4.1. [MELHORIA] TV Missile, drone e canhão de tanque

A explosão do TV Missile pode utilizar o mesmo som-base da explosão do drone, caso isso seja compatível com o sistema existente.

### Melhorar efeitos de
- TV Missile;
- drone explosivo;
- projéteis de tanque;
- destruição de veículos pesados.

### Visual
Adicionar ou revisar:
- nuvem de fumaça maior;
- fumaça permanecendo por mais tempo;
- expansão inicial mais agressiva;
- poeira;
- resíduos;
- efeito proporcional à força da explosão.

### Desempenho
Não compensar tamanho visual usando quantidade excessiva de partículas.

Verificar:
- pooling;
- duração;
- transparência;
- quantidade de partículas;
- overdraw;
- distância de renderização;
- redução de qualidade em distância.

---

# 5. Áudio

## 5.1. [MELHORIA] Explosões grandes devem percorrer distâncias maiores

Aumentar o alcance sonoro das explosões de grande porte.

### Exemplos
- tanque destruído;
- blindado destruído;
- TV Missile;
- drone explosivo;
- projéteis pesados.

### Comportamento desejado
Uma explosão grande deve continuar perceptível para jogadores relativamente distantes.

O volume diminui progressivamente com a distância.

### Exceção
Explosões pequenas, como granadas de mão, podem possuir alcance menor.

Não utilizar a mesma distância máxima para todos os tipos de explosão.

---

## 5.2. [MELHORIA] Disparo de tanque

O disparo do tanque deve possuir:
- volume alto;
- corpo/grave;
- impacto perceptível;
- propagação a longa distância;
- tratamento sonoro coerente quando ouvido de longe.

Não utilizar apenas a mesma gravação com volume reduzido.

---

## 5.3. [MELHORIA] Feedback sonoro de eliminação

Adicionar feedback sonoro exclusivo para quem realizou a eliminação.

### Eliminação de inimigo
Tocar um som curto e positivo.

Regras:
- somente o jogador responsável ouve;
- não reproduzir como áudio 3D no mapa;
- não tocar para outros jogadores;
- não substituir áudio real de tiros, impactos ou morte.

### Eliminação de aliado
Caso friendly fire exista e seja possível matar um aliado:
- tocar som curto negativo;
- somente para o responsável.

---

# 6. Região portuária

## 6.1. [PERFORMANCE] Lag ao se aproximar do porto próximo ao ponto E

### Problema observado
Foi percebida queda de desempenho ao se aproximar dessa região.

### Investigar com profiler
- draw calls;
- quantidade de objetos;
- quantidade de materiais;
- sombras;
- iluminação;
- partículas;
- fumaça;
- colisões;
- vegetação;
- transparências;
- scripts;
- física;
- streaming;
- LOD;
- occlusion culling;
- objetos repetidos;
- possibilidade de `MultiMeshInstance3D`.

### Importante
Não assumir que o problema é necessariamente gráfico.

Comparar frame time:
1. antes da aproximação;
2. durante a entrada no porto;
3. parado dentro da área;
4. saindo novamente da região.

---

## 6.2. [MAPA] Acesso ao porto próximo ao ponto E

### Problema
O acesso está ruim para veículos.

Existe um barranco/declive e a estrada não parece adequada.

### Alteração
Revisar:
- relevo;
- inclinação;
- raio de curva;
- largura;
- conexão com outras vias;
- passagem de blindados.

Uma estrada em curva pode ser utilizada se necessário, porém deve parecer uma via real.

Evitar curvas exageradas.

---

## 6.3. [MAPA] Estradas dos portos parecem artificiais

### Problema observado
Algumas vias de acesso possuem curvas exageradas e passam sensação de pista artificial.

### Revisar
- raio das curvas;
- inclinação;
- largura;
- continuidade;
- transição entre estrada e terreno;
- passagem de veículos pesados.

### Resultado esperado
Estradas com geometria plausível para circulação urbana, industrial ou portuária.

---

## 6.4. [BUG VISUAL] Objeto amarelo entrando no asfalto no porto do ponto D

### Verificar
Pode ser:
- mesh;
- decal;
- objeto industrial;
- material;
- geometria sobreposta;
- objeto mal posicionado.

### Resultado esperado
Nenhum objeto deve atravessar visualmente o asfalto sem intenção.

---

# 7. Vegetação e clima

## 7.1. [MELHORIA] Mais grama e vegetação

O mapa está parecendo pouco vegetado em diversas regiões.

Adicionar ou melhorar, conforme região:
- grama;
- vegetação rasteira;
- arbustos;
- árvores;
- vegetação em terrenos abandonados;
- vegetação junto de casas;
- vegetação próxima de margens e áreas úmidas.

### Direção visual
Manter coerência com a ambientação inspirada na Ucrânia.

Evitar:
- vegetação tropical;
- campo verde uniforme;
- distribuição aleatória sem relação com terreno e construções.

### Performance
Verificar uso de:
- LOD;
- `MultiMeshInstance3D`;
- visibility ranges;
- culling;
- densidade por distância.

---

## 7.2. [MELHORIA] Chuva durante o dia

Adicionar possibilidade de chuva em período diurno.

### Possíveis estados
- dia nublado;
- chuva fraca;
- chuva mais intensa;
- transição entre chuva e tempo seco.

### Verificar
O sistema climático já existente antes de criar nova lógica.

---

# 8. Objetivos e conquista

## 8.1. [MAPA] Pontos B e C estão próximos demais

### Problema
Os pontos B e C parecem muito próximos.

### Alteração
Reavaliar a posição dos objetivos e aumentar a distância se isso melhorar o fluxo da partida.

### Antes de mover
Verificar:
- relevo;
- cobertura;
- rotas;
- bases;
- outros objetivos;
- tempo de deslocamento;
- balanceamento entre equipes.

---

## 8.2. [MAPA] Possível novo ponto de domínio na cidade próxima ao porto D

A região urbana próxima ao porto D parece justificar um objetivo adicional.

### Importante
**Verificar primeiro**:
- tamanho da região;
- distribuição atual dos objetivos;
- distância entre pontos;
- fluxo de jogadores;
- balanceamento.

Se fizer sentido, adicionar um novo ponto de domínio que incentive combate dentro da cidade e não apenas no porto.

---

## 8.3. [GAMEPLAY] Cobertura dentro das zonas de domínio

Os centros das áreas de captura precisam oferecer alguma proteção.

### Possíveis coberturas
- sacos de areia;
- destroços;
- veículos destruídos;
- muros baixos;
- caixas;
- concreto;
- barricadas;
- pequenas estruturas.

### Objetivo
Evitar que o jogador precise permanecer completamente exposto para capturar um objetivo.

---

## 8.4. [UI/GAMEPLAY] Captura atualmente pouco clara

### Problema
O jogador entra na área, permanece parado e o ponto simplesmente muda de controle.

Falta feedback.

### Interface de captura
Mostrar:
- nome/letra do ponto;
- estado;
- equipe controladora;
- progresso;
- situação de contestação;
- indicação visual da captura.

### Exemplo

```text
PONTO C

CAPTURANDO
████████░░ 72%
```

Quando houver forças equivalentes:

```text
PONTO C

CONTESTADO
```

### Autoridade
A barra deve refletir o valor real validado pelo servidor.

---

## 8.5. [GAMEPLAY] Captura por superioridade numérica

Manter a lógica de domínio baseada na quantidade de jogadores presentes na área.

### Exemplos
- 3 aliados × 1 inimigo → aliados avançam captura;
- 2 × 2 → contestado;
- apenas aliados → captura;
- apenas inimigos → captura adversária.

### Verificar
Se já existe aceleração proporcional à superioridade numérica.

Se não existir, avaliar se uma aceleração moderada melhora o sistema sem tornar capturas instantâneas.

---

# 9. Minimapa e controle territorial

## 9.1. [NOVO/VERIFICAR] Minimapa no Modo Guerra

Adicionar minimapa caso ainda não exista sistema equivalente.

### Informações úteis
- posição do jogador;
- orientação;
- objetivos;
- objetivos aliados;
- objetivos inimigos;
- objetivos neutros;
- aliados;
- áreas importantes.

Manter cores consistentes entre HUD, mapa e objetivos.

---

## 9.2. [NOVO] Territórios no estilo "gang zone"

Além dos marcadores individuais de objetivos, representar visualmente regiões controladas pelas equipes.

A ideia é semelhante ao conceito de territórios das gangues de GTA San Andreas, sem copiar o visual.

### Representação conceitual
- território da equipe aliada → cor aliada translúcida;
- território inimigo → cor inimiga translúcida;
- território neutro → sem preenchimento ou cor neutra;
- território contestado → indicação própria.

### Objetivo
Permitir que o jogador entenda rapidamente a situação territorial geral da partida.

### Verificar
Como dividir as regiões do mapa de maneira lógica.

Não criar fronteiras arbitrárias sem relação com objetivos e geografia.

---

## 9.3. [HUD] Minimapa pequeno durante gameplay

Adicionar uma versão compacta do minimapa ao HUD do personagem.

### Mostrar
- posição;
- direção;
- objetivos;
- situação territorial essencial.

Evitar excesso de informação.

---

## 9.4. [HUD] Mapa ampliado de acesso rápido

Adicionar opção para abrir rapidamente uma versão maior do mapa.

### Verificar
Qual tecla ou botão está livre antes de definir um novo atalho.

---

# 10. Spawn e implantação

## 10.1. [UI] Mapa na tela de spawn

A tela de implantação deve utilizar uma versão ampliada do mapa.

### Mostrar
- bases;
- objetivos;
- territórios;
- pontos válidos de spawn;
- aliados, quando apropriado.

O jogador escolhe o ponto de spawn diretamente pelo mapa.

---

## 10.2. [GAMEPLAY] Morte retorna à tela de implantação

Quando o jogador morrer:
1. executar câmera de morte;
2. respeitar o tempo de morte existente;
3. abrir automaticamente a tela de implantação;
4. mostrar mapa;
5. mostrar pontos de spawn;
6. permitir alteração de classe/loadout;
7. permitir escolha de spawn;
8. reimplantar.

Não realizar respawn automático sem respeitar essa lógica.

---

## 10.3. [GAMEPLAY] Definir previamente o próximo ponto de spawn

Durante a partida, permitir que o jogador indique antecipadamente onde gostaria de reaparecer.

### Fluxo
1. jogador está vivo;
2. abre a opção adequada;
3. escolhe o próximo ponto;
4. retorna ao jogo;
5. ao morrer, a tela de implantação abre;
6. o ponto previamente escolhido aparece destacado/selecionado.

### Importante
Não realizar spawn automaticamente sem permitir revisão.

Se o ponto deixar de estar disponível:
- invalidar a seleção;
- solicitar outro ponto.

### Modos
Aplicar aos modos online e offline quando fizer sentido para a estrutura de cada modo.

### Verificar
A opção correta dentro do menu atual. Não assumir que o menu de equipamento já possui exatamente essa função.

---

# 11. Relação entre spawn e território

O mapa utilizado no spawn deve utilizar o mesmo sistema visual territorial do minimapa.

O jogador deve conseguir identificar:
- território aliado;
- território inimigo;
- regiões contestadas;
- pontos perdidos;
- pontos disponíveis;
- zonas estratégicas.

Objetivo: tornar a escolha do spawn mais estratégica e compreensível.

---

# 12. Desempenho

Todas as alterações deste documento precisam considerar o problema atual de FPS.

### Atenção especial
- porto próximo ao ponto E;
- partículas;
- fumaça prolongada;
- vegetação;
- minimapa;
- mapa ampliado;
- objetos destrutíveis;
- física dos veículos;
- áudio 3D;
- novos elementos de HUD.

### Não fazer
Não adicionar sistemas pesados executando lógica complexa em todos os frames sem necessidade.

### Medir
- FPS médio;
- 1% low;
- frame time;
- CPU;
- GPU;
- física;
- draw calls;
- memória.

Comparar antes e depois.

---

# 13. Ordem recomendada de implementação

## Etapa 1 — Bugs críticos
- saída do APC;
- reimplantação inesperada;
- câmera pulando ao disparar;
- áudio estranho do blindado.

## Etapa 2 — Física dos blindados
- colisões;
- aceleração;
- ré;
- pequenas elevações;
- pedras;
- objetos quebráveis.

## Etapa 3 — Combate veicular
- dano de 30 mm;
- mira;
- indicador de intenção;
- recoil do canhão;
- efeitos de disparo;
- explosões.

## Etapa 4 — Áudio
- disparos;
- explosões;
- alcance sonoro;
- feedback de eliminação.

## Etapa 5 — Mapa
- desempenho do porto E;
- acesso aos portos;
- estrada;
- bug visual no porto D;
- possível novo objetivo;
- vegetação;
- chuva.

## Etapa 6 — Conquista
- distância entre B e C;
- cobertura;
- feedback visual;
- barra de captura;
- contestação.

## Etapa 7 — Minimapa e spawn
- minimapa;
- territórios;
- mapa ampliado;
- seleção de spawn;
- retorno após morte;
- preferência de próximo spawn.

## Etapa 8 — Validação
- multiplayer;
- FPS;
- interface;
- veículos;
- áudio;
- conquista;
- spawn;
- reconexão.

---

# 14. Critérios de conclusão

Não considerar um item concluído apenas porque existe código.

Cada alteração deve ser:
1. implementada;
2. testada dentro do jogo;
3. testada em multiplayer quando aplicável;
4. validada visualmente;
5. validada em desempenho quando puder afetar FPS.

Ao finalizar, apresentar claramente:
- o que já existia;
- o que foi corrigido;
- o que foi alterado;
- o que foi testado;
- o que ainda permanece pendente.

---

# Resultado esperado

## Veículos
Blindados pesados, previsíveis e utilizáveis, sem comportamento estranho ao tocar pequenos obstáculos.

## Combate
30 mm realmente perigoso contra infantaria, mira veicular clara, canhões convincentes, recoil adequado e explosões fortes.

## Mapa
Portos acessíveis, estradas naturais, objetivos melhor distribuídos, mais vegetação e regiões sem quedas injustificadas de FPS.

## Conquista
O jogador entende claramente quando está capturando, perdendo ou contestando uma área.

## Interface
Minimapa, territórios, spawn e feedback visual ajudam a entender a partida sem excesso de textos.

---

# Regra final para a IA

> **Sempre verificar o estado atual do projeto antes de assumir detalhes como verdadeiros.**
>
> Quando este documento disser **"pode"**, **"talvez"**, **"se fizer sentido"** ou **"verificar"**, isso significa que a implementação deve primeiro analisar o mapa, o código e os sistemas atuais.
>
> Não transformar sugestões em requisitos rígidos sem confirmar que são compatíveis com o projeto existente.
