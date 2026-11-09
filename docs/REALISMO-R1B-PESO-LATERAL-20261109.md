# Realismo R1B — peso lateral e curvas

**Data:** 09/11/2026
**Branch:** `ia/realismo-r1b-lateral-curves-20261109`
**Base:** R1A em `f3b24d2`

## Objetivo

Segundo passo pequeno do plano de realismo. A R1B adiciona leitura de massa em strafe e mudança de direção sem alterar movimento real, câmera, cápsula, hitboxes, IA, rede ou origem balística.

A implementação continua dentro de `WarLocomotion`. Não foi criado outro controlador.

## Contrato

- strafe reage ao delta da velocidade lateral real;
- a arma visual FPP atrasa no sentido oposto à aceleração lateral;
- velocidade lateral constante converge para neutro;
- curvas usam o yaw real do ator somente quando existe deslocamento longitudinal;
- girar parado não gera inércia lateral;
- a R1B atua somente em `view_root` do ator local;
- `weapon_root`, câmera e estado replicado permanecem fora do efeito;
- ADS, tiro, recarga, granada, gadget e melee continuam protegidos pelos retornos existentes;
- a mesma flag experimental da R1A controla o conjunto: `TDC_TACTICAL_MOTION_PILOT=1` ou `--tactical-motion-pilot`.

## Limites iniciais

- deslocamento lateral estrutural máximo: **2,2 cm**;
- contribuição de curva limitada a **0,4** do peso lateral;
- escala de aceleração lateral: `2,4 × move_speed`;
- entrada: `20/s`;
- retorno: `3,2/s`;
- curva normalizada por `2,2 rad/s`.

## Calibração final G3

A calibração foi executada renderizada em Forward+ / GTX 1650 e confirmada visualmente em FPP. O primeiro passe numérico revelou que a fixture havia permanecido em TPP; isso foi detectado pela inspeção das capturas, o teste foi corrigido para entrar em FPP uma única vez e o gate final foi repetido.

Resultado final:

- strafe para esquerda/direita: **±7,33 mm** no pico;
- curva sustentada de 90°/s: **±8,8 mm** no pico;
- strafe retorna abaixo de 0,5 mm em **100 ms**;
- curva retorna abaixo de 0,5 mm em **133,33 ms** após o giro cessar;
- deslocamento da arma mundial/autoritativa: **0,0 mm**;
- deriva vertical ou longitudinal causada pela R1B: **0,0 mm**;
- câmera FPP: transform inalterado.

A revisão visual mostrou deslocamento lateral perceptível, porém menor que a R1A longitudinal, evitando aparência de arma solta ou efeito de mola. Os limites iniciais foram mantidos sem nova amplificação.

## Gates

`tests/realismo_r1b_lateral_weight.gd` valida sinal, neutralidade, curva em movimento, giro parado, composição com R1A e invariância da arma física/câmera. Resultado final: **13/13 PASS**.

`tests/realismo_r1b_g3_calibration.gd` valida o comportamento renderizado da G3 em FPP, simetria, janelas de pico/retorno e invariância física. Resultado final: **16/16 PASS**.

Regressões finais: R1A **8/8 PASS** e ópticas universais com o piloto ativo **242/242 PASS** (AK, FAL, G3 e sniper; 4x/8x).

## Fora de escopo

Sem inclinação de câmera, sem roll da arma, sem quadril/tronco, sem alteração da física de aceleração, sem TPP, sem animação esquelética e sem integração na `main` nesta etapa.
