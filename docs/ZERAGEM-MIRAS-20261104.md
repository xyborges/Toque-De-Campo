# Zeragem balística de miras — 04/11/2026

## Objetivo

Substituir a ideia de retículas/dots específicos por arma por um sistema leve de **zeragem da mira** (*sight zeroing*). O jogador escolhe a distância de referência da arma e a balística eleva o disparo o suficiente para a trajetória cruzar a linha de visada naquela distância.

Não há textura, shader ou retícula diferente para cada arma.

## Controle e HUD

- Enquanto estiver em ADS/mira (`iron_sights`), **scroll para cima** aumenta a zeragem.
- **Scroll para baixo** reduz a zeragem.
- Passo fixo: **50 m**.
- Estado inicial: **0 m**, que significa nenhuma compensação adicional.
- O HUD de infantaria mostra `ZERAGEM · <distância> m · SCROLL AO MIRAR`.
- A zeragem é guardada separadamente para cada arma equipada durante a vida da instância do jogador. Trocar de AK para sniper e voltar não mistura os valores.

Limites atuais:
- Glock: até 150 m, respeitando o alcance de 160 m.
- AK: até 900 m.
- G3: até 1050 m.
- FAL: até 1100 m.
- Sniper: até 1200 m (cap defensivo do sistema).
- Armas sem gravidade balística, como o lançador guiado configurado com gravidade zero, não recebem zeragem.

## Cálculo

`scripts/weapon_zeroing.gd` usa os mesmos parâmetros oficiais do projétil:
- velocidade inicial;
- gravidade;
- arrasto linear;
- alcance máximo.

A solução calcula o ângulo de elevação de baixa trajetória usando o mesmo modelo de integração linear de arrasto usado por `GameBulletPhysics`. Cada combinação arma/distância é calculada uma vez e armazenada em cache.

Portanto, `300 m` no G3 e `300 m` na sniper não usam o mesmo ângulo. A compensação deriva automaticamente da balística da arma, sem tabelas de dots por modelo.

## Autoridade e rede

O cliente **não envia o ângulo compensado como autoridade**. Ele envia:
- direção normal de visada;
- estado de mira já existente;
- distância de zeragem escolhida.

O servidor:
1. valida a arma e o tiro pelo pipeline existente;
2. aceita zeragem somente no nível ADS correspondente;
3. faz snap/clamp da distância conforme a arma;
4. recalcula o ângulo usando os parâmetros oficiais;
5. aplica a elevação antes do spread;
6. replica o projétil já com a direção autoritativa.

Valores forjados acima do limite são reduzidos ao máximo permitido. Valores inválidos/negativos convergem para uma faixa válida.

Os overrides de tiro do Modo Guerra e Battle Royale propagam o novo parâmetro sem alterar suas regras próprias de elegibilidade, água, prone, round ou inventário.

## Desempenho

O sistema não cria recursos por arma nem por disparo. Durante o jogo:
- cada arma mantém apenas um inteiro de distância;
- o HUD atualiza texto existente;
- a solução angular fica cacheada por combinação de velocidade/gravidade/arrasto/distância.

Não há viewport extra, material extra, dot extra, nó por tiro ou loop de simulação para calcular zeragem em tempo real.

## Validação

`tests/weapon_zeroing_20261104.gd`:
- 58/58 verificações PASS;
- Glock, AK, G3, FAL e sniper;
- 50/100/300/600 m quando aplicável;
- trajetória cruza a linha de visada dentro de tolerância de 4,5 cm (amostras medidas ficaram praticamente em zero);
- 0 m mantém a direção original;
- passos de scroll de 50 m;
- estado separado por arma;
- HUD mostra a distância;
- servidor limita valor forjado;
- projétil autoritativo recebe a elevação calculada pelo servidor.

Regressões:
- `tests/optic_preferences.gd`: 9/9 PASS.
- `tests/br_optic_duel.gd`: bloqueado no ambiente local pela ausência de `/etc/toque-de-campo/game-tls/server.crt`; o runtime BR compila após propagação da assinatura.
- `tests/ballistics171.gd`: teste legado possui expectativa antiga da velocidade da sniper e tenta acessar um bus de áudio indisponível em headless; as verificações de integração de gravidade/arrasto executadas antes desse ponto passaram.
- `tests/war_benchmark_fixture.gd`: atualizado para assinaturas atuais e parse headless PASS.
- varredura `Godot --headless --editor --quit`: PASS / exit 0.

## Escopo

Nenhuma atualização foi publicada e nenhuma alteração foi integrada à branch `main`. A entrega permanece na branch de trabalho da tarefa para revisão/merge posterior.