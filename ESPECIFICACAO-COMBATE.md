# ESPECIFICAÇÃO TÉCNICA — SISTEMA DE ARMAS, COMBATE PVP, SINCRONIZAÇÃO MULTIPLAYER E INTERFACES

## 1. Objetivo geral

Implementar, corrigir e padronizar todas as mecânicas de armas, combate, danos, animações e interfaces do jogo, especialmente nos modos PVP e multiplayer online.

O jogo é um FPS com elementos de terceira pessoa, veículos, diferentes tipos de armamentos, física de personagens e personalização.

Embora seja um jogo simples e recreativo, suas mecânicas precisam ser coerentes, previsíveis, funcionais e visualmente convincentes.

**Não quero apenas funcionalidades que aparentemente funcionem. Quero que os sistemas estejam corretamente integrados, sem erros de posicionamento, animação, colisão, sincronização ou interação.**

As regras abaixo devem funcionar tanto para quem está jogando quanto para os demais participantes conectados à mesma partida.

---

# PARTE 1 — POSICIONAMENTO E COMPORTAMENTO DAS ARMAS

## 2. Posicionamento da arma no personagem

Toda arma equipada deve permanecer corretamente posicionada em relação ao corpo do jogador.

### Requisitos obrigatórios

- A arma deve ficar apontada para a frente do personagem.
- O cano precisa acompanhar a direção da mira.
- A arma deve acompanhar os movimentos do personagem sem ficar flutuando.
- O personagem deve segurar a arma com as mãos posicionadas corretamente.
- A arma não pode atravessar o tronco, braços ou cabeça do próprio personagem.
- Ao caminhar, correr, agachar ou girar, a arma deve acompanhar as animações.
- A arma deve permanecer visualmente estável quando o jogador estiver parado.
- O modelo da arma não pode aparecer invertido, deslocado ou com escala incorreta.

### Exemplo prático

Se o jogador estiver olhando diretamente para uma parede, sua arma deve estar orientada para aquela parede.

Se ele girar 90 graus para a direita, a arma deve acompanhar o movimento.

Se olhar para cima, a arma deve se inclinar para cima.

Se olhar para baixo, a arma deve se inclinar para baixo.

A arma não pode continuar apontada horizontalmente enquanto o jogador mira verticalmente.

## 3. Separação entre primeira e terceira pessoa

O jogo deve diferenciar a apresentação da arma para o próprio jogador e para os demais participantes.

### Primeira pessoa

- A arma aparece em posição confortável na tela, normalmente na região inferior direita.
- O cano deve apontar aproximadamente para o centro da mira.
- As mãos devem acompanhar a arma.
- O movimento da arma não pode prejudicar excessivamente a visibilidade.
- O modelo não pode desaparecer ao olhar para cima ou para baixo.
- A animação de disparo deve apresentar recuo visual.

### Terceira pessoa e multiplayer

Os outros jogadores precisam visualizar:

- A arma corretamente posicionada nas mãos.
- A direção em que o personagem está mirando.
- A inclinação vertical da arma.
- A animação de disparo.
- A animação de recarga.
- A troca de armas.
- A posição correta da arma durante o agachamento.

**É proibido que o jogador esteja mirando para uma direção enquanto os demais enxergam sua arma apontada para outra.**

A câmera em primeira pessoa pode usar uma representação visual própria da arma, mas o disparo deve continuar coerente com a arma e o personagem existentes no mundo tridimensional.

---

# PARTE 2 — MECÂNICA DOS DISPAROS

## 4. Origem e trajetória dos tiros

Este é um requisito crítico.

O disparo deve considerar a direção da câmera, o ponto de mira, a posição do personagem e a posição física do cano da arma.

### Funcionamento esperado

1. O jogador posiciona a mira sobre um alvo.
2. O sistema identifica a direção da câmera.
3. Calcula o ponto para onde o jogador está mirando.
4. Verifica a posição física do cano da arma.
5. Calcula uma trajetória compatível com a direção desejada.
6. Verifica se há obstáculos entre o cano e o alvo.
7. Executa o disparo.
8. Aplica dano somente se houver uma colisão válida.

### Exemplo

O jogador aponta a mira para o peito de um adversário a 30 metros.

O tiro deve atingir aproximadamente o peito, considerando a precisão da arma, o movimento, o recuo e a trajetória do projétil.

Não pode acontecer de a mira estar no peito e a bala sair acima da cabeça por um erro de cálculo.

Também não pode acontecer de o projétil sair de uma posição distante da arma.

### Obstáculos próximos

Se o jogador estiver encostado em uma parede, o cano não poderá disparar através dela.

Se a câmera conseguir enxergar um inimigo, mas o cano estiver bloqueado por uma parede, o disparo deverá atingir a parede.

Isso evita que jogadores atirem através de obstáculos usando diferenças entre a posição da câmera e a posição da arma.

## 5. Projéteis e gravidade

O sistema deve permitir dois comportamentos, conforme a arma:

**Armas de projétil simulado:** o tiro possui velocidade, trajetória, gravidade e tempo de deslocamento.

**Armas com detecção instantânea (hitscan):** o sistema calcula o impacto imediatamente, respeitando a direção, a precisão, os obstáculos e a distância máxima.

Não misturar os dois sistemas incorretamente.

### Exemplo com sniper

Ao disparar uma sniper:

- O projétil sai na direção correta.
- Percorre uma trajetória previsível.
- Sofre influência gradual da gravidade.
- Em distâncias maiores, pode atingir abaixo do ponto originalmente visado.
- A queda precisa ser progressiva, não um movimento artificial para cima ou para baixo.

A bala nunca deve subir imediatamente após sair da arma por um erro de orientação dos eixos.

## 6. Recuo das armas

Cada arma deve possuir recuo próprio.

Exemplos:

- Pistola: recuo leve a moderado.
- Submetralhadora: recuo pequeno por disparo, mas acumulativo em rajadas.
- Fuzil: recuo moderado, com recuperação gradual.
- Metralhadora: recuo acumulativo mais forte.
- Sniper: recuo elevado por disparo.

O recuo deve afetar a câmera e a direção de disparos subsequentes de maneira controlada.

Não permitir que a câmera fique permanentemente desalinhada depois de atirar.

O recuo visual não deve modificar arbitrariamente a trajetória de um projétil que já foi disparado.

## 7. Munição, recarga e modos de tiro

Cada arma deve possuir configurações próprias:

- Capacidade do carregador.
- Munição de reserva.
- Cadência de tiro.
- Tempo de recarga.
- Dano.
- Alcance efetivo.
- Precisão.
- Recuo.
- Tipo de projétil.
- Modo de disparo.

Exemplo de funcionamento de uma pistola com 15 munições:

1. O jogador começa com 15/60.
2. Cada disparo reduz uma munição do carregador.
3. Quando chegar a zero, a arma não poderá disparar.
4. Pressionar R inicia a recarga.
5. A animação de recarga deve ser reproduzida.
6. A munição é transferida da reserva para o carregador no momento correto.
7. O jogador volta a disparar quando a recarga termina.

Não permitir munição negativa, disparos infinitos ou recargas duplicadas.

Se o jogador morrer, trocar de arma ou sair da partida durante uma recarga, o sistema precisa cancelar ou concluir a operação conforme uma regra definida, sem duplicar munição.

---

# PARTE 3 — HITBOXES E DANOS LOCALIZADOS

## 8. Divisão do corpo em regiões

Cada personagem deve possuir regiões de colisão específicas para o combate.

Não utilizar uma única caixa de colisão para representar todos os impactos.

As principais regiões são:

- Cabeça.
- Pescoço, quando o modelo permitir.
- Peito.
- Abdômen.
- Braço esquerdo.
- Braço direito.
- Antebraços e mãos, quando possível.
- Perna esquerda.
- Perna direita.
- Pés, quando possível.

Essas hitboxes precisam acompanhar as animações e a posição real do personagem.

<text><escape>Exemplo: se um jogador estiver agachado atrás de uma parede e somente sua cabeça estiver visível, o adversário poderá acertar a cabeça, mas não poderá atingir o tronco através da parede.</escape></text>

## 9. Multiplicadores de dano por região

Implementar uma configuração centralizada para permitir balanceamento.

Valores iniciais sugeridos:

| Região | Multiplicador |
|---|---|
| Cabeça | 2,5x |
| Pescoço | 2,0x |
| Peito | 1,0x |
| Abdômen | 0,9x |
| Braços | 0,65x |
| Mãos | 0,4x |
| Pernas | 0,75x |
| Pés | 0,4x |

Esses valores são apenas exemplos para o jogo e devem ser ajustáveis por arma ou modo.

### Exemplo

Um fuzil causa 30 pontos de dano base.

- Acerto no peito: 30 de dano.
- Acerto na cabeça: 75 de dano.
- Acerto no braço: 19,5 de dano.
- Acerto na perna: 22,5 de dano.

O sistema deve calcular o dano com base na região realmente atingida.

Não pode aplicar dano de cabeça quando o projétil atingiu o ombro.

## 10. Danos acumulativos nos membros

Além da vida geral, o personagem pode possuir integridade individual dos membros.

Exemplo de estrutura lógica:

```javascript
player.health = 100;

player.limbs = {
  head: 100,
  torso: 100,
  leftArm: 100,
  rightArm: 100,
  leftLeg: 100,
  rightLeg: 100
};
```

Esses valores são conceituais. Adaptar à estrutura real do jogo.

Cada impacto deve atualizar tanto a vida geral quanto a integridade da região atingida, conforme as regras da arma.

### Exemplo: tiros no braço

Um jogador recebe vários tiros no braço esquerdo.

- Primeiro tiro: o braço recebe dano localizado.
- Segundo tiro: sua integridade diminui novamente.
- Terceiro tiro: pode atingir o limite de inutilização do membro.
- Se o modo permitir desmembramento, o braço poderá ser separado do corpo.

Não permitir que um tiro comum de pistola desmembre automaticamente o personagem inteiro.

## 11. Consequências dos danos

As consequências devem ser proporcionais ao dano e configuráveis por modo.

### Braços

Se um braço ficar inutilizado:

- A animação deve refletir a condição.
- O personagem não pode continuar segurando uma arma de duas mãos normalmente se o sistema de dano permitir essa incapacidade.
- O comportamento da arma deve ser atualizado.

### Pernas

Se uma perna ficar inutilizada:

- Reduzir a capacidade de movimentação.
- Adaptar a animação.
- Impedir que o personagem continue correndo normalmente.

Se as duas pernas ficarem inutilizadas e o personagem continuar vivo, poderá rastejar, desde que essa mecânica esteja habilitada no modo.

### Cabeça

Acertos na cabeça devem causar dano elevado.

Armas de alto calibre podem produzir efeitos visuais mais intensos, respeitando a configuração de violência do jogo.

### Tronco

Acertos no tronco reduzem a vida geral e podem produzir reações de impacto.

Não devem causar a separação arbitrária de braços ou pernas que não foram atingidos.

## 12. Desmembramento e morte

Preservar a mecânica de dano localizado e desmembramento já prevista no projeto.

Entretanto, separar três conceitos:

1. **Dano:** redução da vida ou integridade do membro.
2. **Inutilização:** perda funcional de um membro.
3. **Desmembramento:** separação visual e física do membro.

Nem toda inutilização precisa provocar desmembramento.

Armas comuns devem exigir danos acumulados e condições específicas.

Armas de alto calibre podem ter limites diferentes.

No PVP, os efeitos não podem comprometer o balanceamento. O jogador deve ter regras claras de sobrevivência, morte e respawn.

A separação de partes do corpo deve ocorrer apenas quando a configuração do modo permitir.

---

# PARTE 4 — REAÇÃO AOS IMPACTOS E RAGDOLL

## 13. Reação aos tiros

Quando um personagem recebe um tiro, o jogo deve identificar:

- Local do impacto.
- Direção do projétil.
- Intensidade do impacto.
- Tipo de arma.
- Estado atual do personagem.

A animação de reação deve ser coerente.

Exemplos:

- Tiro no ombro direito: pequena reação localizada no lado direito.
- Tiro na perna: reação compatível com o membro atingido.
- Tiro no peito: reação no tronco.
- Tiro fatal: transição para animação de morte ou ragdoll.

Evitar que todo disparo faça o personagem inteiro girar, voar ou cair de maneira exagerada.

## 14. Física de morte

Quando a vida chegar a zero:

1. O servidor confirma a morte.
2. O personagem deixa de aceitar comandos de movimentação.
3. A arma deixa de disparar.
4. A animação de morte ou ragdoll é ativada.
5. A física recebe um impulso compatível com o impacto.
6. O corpo interage com o terreno.
7. O jogador entra no estado de respawn, quando aplicável.

O ragdoll deve respeitar articulações e limites físicos.

Não permitir:

- Membros esticando infinitamente.
- Corpo atravessando o chão.
- Ossos explodindo por instabilidade física.
- Cadáver permanecendo suspenso sem suporte.
- Corpos sendo duplicados.
- Ragdolls consumindo recursos indefinidamente.

Os cadáveres devem ser removidos gradualmente conforme limites de quantidade, distância e tempo.

---

# PARTE 5 — COMBATE ONLINE E SINCRONIZAÇÃO

## 15. O servidor deve validar os disparos

Nos modos PVP online, o cliente não pode ser a autoridade final sobre dano e morte.

O cliente envia a intenção de disparar.

O servidor verifica:

- Se o jogador está vivo.
- Se possui a arma.
- Se existe munição.
- Se a arma pode disparar naquele momento.
- Se o intervalo entre tiros é válido.
- Se a direção da mira é plausível.
- Se a origem do tiro corresponde à posição do jogador.
- Se o projétil ou raio atingiu o alvo.
- Se algum obstáculo bloqueou o disparo.
- Qual região do corpo foi atingida.
- Quanto dano deve ser aplicado.

Somente após a validação o dano é confirmado.

## 16. Todos precisam enxergar o mesmo combate

Exemplo com dois jogadores:

Jogador A dispara contra o jogador B.

Na tela do jogador A:

- A arma dispara.
- O recuo aparece.
- O efeito do disparo é reproduzido.
- O impacto é apresentado após a confirmação adequada.

Na tela do jogador B:

- O jogador A aparece segurando a arma corretamente.
- A animação do disparo é visível.
- A direção do tiro é coerente.
- O dano recebido corresponde ao resultado validado pelo servidor.

Na tela de um terceiro jogador:

- O disparo deve partir visualmente da arma do jogador A.
- O projétil ou efeito deve seguir uma trajetória coerente.
- O jogador B deve reagir ao impacto confirmado.

**Não pode acontecer de cada jogador enxergar uma origem de tiro completamente diferente.**

## 17. Correção de latência

Implementar mecanismos apropriados de interpolação e compensação de latência.

Os jogadores remotos devem se mover suavemente, mesmo quando os dados de rede chegarem em intervalos.

Evitar:

- Teletransporte constante.
- Personagens tremendo.
- Armas apontadas para direções erradas.
- Tiros duplicados.
- Dano aplicado duas vezes.
- Mortes confirmadas mais de uma vez.
- Personagens mortos continuando a disparar.

Se for utilizada compensação de latência para validar tiros, limitar o histórico considerado pelo servidor e impedir que clientes escolham arbitrariamente estados antigos para obter vantagem.

## 18. Identificação dos disparos

Cada disparo deve possuir identificação única.

Exemplo conceitual:

```javascript
shot = {
  shotId: "unique-id",
  playerId: "player-123",
  weaponId: "rifle-01",
  sequence: 142,
  origin: { x: 0, y: 0, z: 0 },
  direction: { x: 0, y: 0, z: -1 }
};
```

O servidor deve validar e calcular os dados relevantes, sem confiar cegamente nos valores recebidos.

Isso evita duplicação de efeitos e facilita a identificação de erros.

---

# PARTE 6 — MOVIMENTAÇÃO E COMBATE

## 19. Integração com movimento

As armas precisam funcionar corretamente em diferentes estados do personagem.

### Parado

- Maior estabilidade.
- Arma apontada corretamente.
- Animação de respiração ou movimento leve.

### Caminhando

- Pequena oscilação visual.
- Precisão compatível com o movimento.
- Arma acompanhando a direção da mira.

### Correndo

- Animação própria.
- Arma posicionada de maneira natural.
- Precisão reduzida ou disparo limitado, conforme a arma.

### Agachado

- Modelo e câmera abaixam corretamente.
- Hitboxes acompanham a postura.
- A arma continua alinhada.
- O jogador pode disparar sem que o tiro saia da posição antiga do personagem.

### Pulando

- Arma acompanha o personagem.
- Precisão pode ser reduzida.
- O disparo não pode usar uma posição de origem desatualizada.

### Dentro de veículos

Preservar a regra já definida para os veículos comuns: jogadores embarcados não podem utilizar suas armas pessoais.

Armas instaladas em veículos militares devem possuir um sistema próprio de mira, munição, disparo e sincronização.

---

# PARTE 7 — MENUS E INTERFACES SEM BUGS

## 20. Sistema de menus organizado

Todos os menus devem utilizar um sistema consistente de gerenciamento de interface.

Isso inclui:

- Menu principal.
- Configurações.
- Personalização de personagem.
- Seleção de armas.
- Loja.
- Inventário.
- Seleção de equipes.
- Lista de salas.
- Criação de salas.
- Menu de pausa.
- Interface de respawn.
- Menus específicos dos modos PVP.

Cada interface deve possuir uma hierarquia visual e de interação bem definida.

## 21. Impedir cliques através dos menus

**Este é um requisito obrigatório e deve ser tratado como um problema de funcionamento, não apenas de aparência.**

Quando um menu estiver aberto sobre outro, os cliques devem atingir somente os elementos interativos da camada superior.

### Exemplo do bug que deve ser evitado

O jogador abre Configurações.

Dentro de Configurações, abre a seleção de resolução.

A lista de resoluções aparece sobre o botão de áudio.

Ao clicar em 1920×1080, o sistema não pode selecionar a resolução e simultaneamente ativar o botão de áudio que estava atrás.

O clique deve ser consumido exclusivamente pelo elemento superior.

### Implementação esperada

- Utilizar hierarquia de camadas.
- Controlar corretamente o `z-index` ou equivalente.
- Gerenciar eventos de ponteiro.
- Bloquear a interação com menus inferiores quando houver um modal.
- Impedir propagação indevida dos eventos.
- Garantir que elementos invisíveis não capturem cliques.
- Garantir que elementos cobertos não sejam acionados.
- Impedir que um único clique execute duas ações incompatíveis.

A solução precisa funcionar com mouse, teclado e outros métodos de entrada suportados.

## 22. Menus modais

Quando uma janela modal estiver aberta, ela deve assumir o foco da interface.

Exemplo:

O jogador abre a confirmação de compra de uma arma.

Aparece uma janela com:

- Nome da arma.
- Preço.
- Botão Confirmar.
- Botão Cancelar.

Enquanto essa janela estiver aberta:

- O jogador não pode clicar na loja que está atrás.
- Não pode comprar outro item acidentalmente.
- Não pode selecionar uma arma atrás da janela.
- O teclado deve respeitar o foco do modal.
- Escape deve fechar ou cancelar a janela, conforme a função definida.

Se houver um segundo modal sobre o primeiro, somente o modal superior deve receber comandos.

## 23. Controle de foco

Implementar um gerenciador centralizado de foco da interface.

Ao abrir um menu:

1. O jogo identifica o menu ativo.
2. Define qual interface pode receber comandos.
3. Libera ou captura o cursor conforme necessário.
4. Bloqueia comandos de jogo incompatíveis.
5. Direciona teclado e mouse para a interface correta.

Ao fechar:

1. Remove o menu da pilha de interfaces.
2. Restaura o foco da interface anterior.
3. Reativa os controles apropriados.
4. Atualiza o estado do cursor.

### Exemplo

Se o jogador estiver em uma partida FPS e pressionar Escape:

- O menu de pausa aparece.
- O cursor fica disponível.
- Movimentar o mouse não gira a câmera.
- Clicar em Configurações não dispara a arma.
- Pressionar W enquanto digita em um campo não movimenta o personagem.

Ao fechar todos os menus, os controles de combate são restaurados corretamente.

## 24. Evitar menus duplicados

Não permitir que o mesmo menu seja aberto várias vezes simultaneamente por cliques rápidos.

Exemplo:

O jogador clica cinco vezes no botão Configurações.

O sistema deve abrir uma única instância do menu, e não cinco janelas sobrepostas.

O mesmo vale para:

- Loja.
- Inventário.
- Seleção de equipes.
- Confirmação de compra.
- Criação de salas.
- Personalização.

## 25. Botões e ações assíncronas

Operações que dependem do servidor precisam evitar duplicações.

### Exemplo: comprar uma arma

1. O jogador clica em Comprar.
2. O botão entra em estado de processamento.
3. A interface impede outra compra idêntica enquanto aguarda.
4. O servidor valida saldo e disponibilidade.
5. A operação é registrada uma única vez.
6. O menu apresenta o resultado.

Não permitir que vários cliques rápidos provoquem compras duplicadas ou descontos repetidos.

Utilizar identificadores de operação e validação no servidor quando necessário.

## 26. Organização visual e responsividade

Os menus devem:

- Ter alinhamento consistente.
- Possuir textos legíveis.
- Evitar elementos sobrepostos.
- Adaptar-se à resolução da tela.
- Manter botões dentro da área visível.
- Ter rolagem quando necessário.
- Preservar proporções.
- Evitar cortes em listas e caixas de seleção.
- Possuir indicadores visuais de seleção.
- Diferenciar elementos habilitados e desabilitados.

Uma janela não pode ficar maior que a tela sem oferecer uma forma de acessar seu conteúdo.

## 27. Menus durante partidas online

Abrir um menu não deve desconectar o jogador.

O servidor deve continuar mantendo seu personagem na partida.

O menu de pausa não deve pausar a simulação multiplayer para todos.

Exemplo:

Jogador A abre Configurações.

Jogador B continua se movimentando e jogando normalmente.

O personagem A continua existindo no servidor e pode receber dano, conforme as regras do modo.

Ao fechar o menu, o jogador A recebe o estado atualizado da partida.

---

# PARTE 8 — CASOS DE TESTE OBRIGATÓRIOS

## 28. Testes de armas

Validar pelo menos:

1. Atirar parado.
2. Atirar caminhando.
3. Atirar correndo, quando permitido.
4. Atirar agachado.
5. Atirar olhando para cima.
6. Atirar olhando para baixo.
7. Atirar próximo de uma parede.
8. Atirar em diferentes distâncias.
9. Recarregar com carregador parcialmente vazio.
10. Tentar disparar sem munição.
11. Trocar de arma durante a recarga.
12. Morrer durante o disparo.
13. Entrar e sair de um veículo.
14. Disparar contra jogadores em movimento.
15. Disparar contra jogadores agachados.
16. Verificar o alinhamento das armas na tela dos outros jogadores.

## 29. Testes de danos

Testar individualmente:

- Cabeça.
- Peito.
- Abdômen.
- Braço esquerdo.
- Braço direito.
- Perna esquerda.
- Perna direita.
- Mãos e pés, quando implementados.

Verificar se cada região recebe o multiplicador correto.

Testar danos acumulativos e condições de inutilização ou desmembramento.

Confirmar que o personagem não recebe dano quando o projétil é bloqueado por um obstáculo.

## 30. Testes multiplayer

Executar testes com pelo menos dois clientes reais conectados.

Validar:

- Posição das armas.
- Direção das miras.
- Origem dos disparos.
- Efeitos visuais.
- Dano recebido.
- Reações aos impactos.
- Morte.
- Ragdoll.
- Respawn.
- Recarga.
- Troca de armas.
- Reconexão.
- Saída durante o combate.

Testar também condições de latência e perda de pacotes.

Não considerar o multiplayer validado apenas porque funciona com dois personagens simulados no mesmo cliente.

## 31. Testes de menus

Validar:

1. Abrir e fechar menus repetidamente.
2. Abrir um menu sobre outro.
3. Clicar em opções que cobrem botões inferiores.
4. Abrir listas suspensas.
5. Selecionar itens de listas.
6. Digitar em campos de texto.
7. Pressionar Escape.
8. Clicar rapidamente em botões.
9. Comprar itens.
10. Trocar de resolução.
11. Abrir menus durante partidas.
12. Abrir o menu após morrer.
13. Reconectar enquanto um menu estiver aberto.
14. Alternar entre menus sem deixar interfaces invisíveis capturando eventos.
15. Verificar que cliques na interface não disparam armas ou movimentam o personagem.

---

# PARTE 9 — ARQUITETURA E CRITÉRIOS DE CONCLUSÃO

## 32. Centralização dos sistemas

Evitar implementar versões independentes e incompatíveis da mesma mecânica para cada modo.

Preferencialmente, utilizar módulos compartilhados para:

- Armas.
- Munição.
- Disparos.
- Hitboxes.
- Dano.
- Ragdoll.
- Animações.
- Sincronização multiplayer.
- Gerenciamento de menus.
- Controle de foco.
- Captura de entradas.

Cada modo poderá possuir configurações próprias sem precisar duplicar toda a lógica.

O Modo Guerra, o PVP do deserto e outros modos online devem compartilhar a base funcional de combate, respeitando suas diferenças.

O modo offline poderá reutilizar os sistemas de armas, colisão e dano, com tratamento próprio para NPCs.

## 33. Não substituir funcionalidades existentes desnecessariamente

Antes de modificar o código:

1. Inspecionar a arquitetura atual.
2. Identificar os sistemas já existentes.
3. Verificar quais componentes podem ser reaproveitados.
4. Identificar as causas reais dos bugs.
5. Corrigir os componentes necessários.
6. Preservar funcionalidades que já funcionam.
7. Validar a integração entre os sistemas.

Não criar sistemas paralelos desnecessários que disputem o controle de câmera, armas, movimento ou interface.

## 34. Critérios para considerar o trabalho concluído

A implementação somente poderá ser considerada concluída quando:

- As armas estiverem corretamente posicionadas.
- Os disparos saírem de uma origem física coerente.
- A direção dos tiros corresponder à mira.
- Os projéteis respeitarem obstáculos.
- As hitboxes acompanharem as animações.
- Os danos forem calculados pela região atingida.
- O recuo e a recarga funcionarem.
- O ragdoll apresentar comportamento estável.
- Os demais jogadores visualizarem corretamente os disparos.
- O servidor validar os danos.
- Não ocorrerem tiros ou mortes duplicadas.
- Os menus respeitarem a hierarquia de interação.
- Nenhum clique atravessar uma janela e acionar elementos atrás dela.
- Abrir um menu não provocar disparos ou movimentação involuntária.
- Os testes de multiplayer forem executados com clientes separados.

**Instrução final:** implemente essas correções como sistemas funcionais e integrados, não apenas como elementos visuais. Não marque uma funcionalidade como concluída sem testar seu comportamento real. Caso alguma mecânica dependa de uma estrutura que ainda não existe no projeto, identifique essa dependência, implemente-a na ordem correta e explique o que foi efetivamente concluído e o que ainda falta.
