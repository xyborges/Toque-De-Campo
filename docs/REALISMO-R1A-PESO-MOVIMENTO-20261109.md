# Realismo R1A — peso longitudinal de movimento

**Data:** 09/11/2026
**Branch:** `ia/realismo-r1a-motion-weight-20261109`
**Base:** `origin/main` em `a7b9010` (1.13.9)

## Objetivo

Primeiro passo deliberadamente pequeno do plano de realismo: dar leitura de peso à aceleração e à frenagem sem alterar movimento real, hitboxes, câmera, IA, rede ou origem balística.

A implementação reaproveita `WarLocomotion`, que já deriva a apresentação da distância realmente percorrida. Não foi criado outro controlador de movimento.

## Implementação

- `presentation_longitudinal` representa apenas a resposta visual longitudinal, limitada a `[-1, 1]`.
- aceleração gera resposta positiva; velocidade constante converge para neutro; frenagem gera resposta negativa;
- a resposta possui entrada e retorno suavizados;
- deslocamento máximo da apresentação FPP: **2,8 cm** no eixo longitudinal;
- o efeito é aplicado exclusivamente a `view_root`, a cópia visual local de primeira pessoa;
- `weapon_root` continua sendo a arma física/autoritativa e não recebe o deslocamento R1A;
- câmera, corpo, pernas, torso, cápsula, hitboxes e estado replicado não são modificados;
- ADS, iron sight, recarga, disparo, granada, gadget e melee continuam usando os retornos antecipados existentes e não recebem o efeito.

## Ativação

O piloto fica **OFF por padrão**.

Pode ser ativado para QA por:

```
TDC_TACTICAL_MOTION_PILOT=1
```

ou:

```
--tactical-motion-pilot
```

Mesmo com a flag ligada, o cálculo adicional roda apenas para o ator local. Bots e atores remotos não recebem custo ou estado visual R1A.

## Validação

### Fixture isolada R1A

`tests/realismo_r1a_motion_weight.gd`

Resultado: **8/8 PASS**, exit code 0.

Cobertura:
- aceleração positiva;
- velocidade constante neutra;
- frenagem negativa;
- limite físico de apresentação <= 3 cm;
- arma mundial/autoritativa inalterada;
- zero drift lateral/vertical introduzido;
- deslocamento somente longitudinal na cópia FPP;
- nenhuma dependência ou mutação de câmera.

### Ópticas com piloto ligado

`tests/optics_universal_validation_20261103.gd` executado com `TDC_TACTICAL_MOTION_PILOT=1`.

Resultado: **242/242 PASS**, exit code 0.

Cobriu AK, FAL, G3 e sniper com `prism4x`, `pso4x`, `hensoldt4x` e `precision8x`.

### Fixture histórica de locomoção

A fixture `tests/war_locomotion.gd` não foi usada como gate desta entrega porque seu baseline ficou desatualizado na 1.13.9: ela ainda espera 12 atores, não obteve input no cenário atual, tenta capturas gráficas em headless e terminou em erro próprio do pool de passos. Antes de retirar os checks temporários, os **6 checks específicos do R1A passaram**, mas o resultado geral da fixture é inválido para homologar esta etapa. O teste original foi restaurado sem mudanças.

## Calibração visual G3

Foi feito um passe renderizado em Forward+ / GTX 1650 usando a G3 em FPP e a resposta física real do jogo, que hoje muda de 0 para `WarRules.WALK_SPEED` (4,8 m/s) praticamente em um frame.

A primeira versão (`response in = 12/s`, `return = 7/s`) entregava apenas **5,6 mm** de deslocamento por **50 ms**. Nas capturas a diferença era correta, mas pequena demais para comunicar peso.

A calibração final mantém o limite estrutural de **2,8 cm**, mas usa `response in = 24/s` e `return = 3,2/s`. No degrau real 0 → 4,8 → 0, o efeito observado ficou em:

- pico de aceleração: **+11,2 mm**;
- pico de frenagem: **-11,2 mm**;
- retorno a menos de 0,5 mm: **150 ms**;
- deslocamento da arma mundial/autoritativa durante as três capturas: **0,0 mm**.

A fixture `tests/realismo_r1a_g3_calibration.gd` mantém como gate pico entre **8 e 14 mm** e retorno entre **100 e 180 ms**.

## Limites desta etapa

R1A não adiciona ainda inclinação de quadril, giro de tronco, peso lateral em curvas, contato de calcanhar/ponta, aterrissagem, TPP ou Skeleton3D. Também não tenta corrigir a fixture histórica de locomoção.

O playtest/calibração FPP/G3 desta etapa está concluído. O próximo passo deve continuar pequeno: uma R1B lateral/curvas, ainda somente de apresentação, sem alterar velocidade, cápsula, hitboxes, IA ou rede.